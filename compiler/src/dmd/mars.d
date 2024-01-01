
/**
 * This modules defines related
 * utilities needed for arguments parsing, path manipulation, etc...
 * This file is not shared with other compilers which use the DMD front-end.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/mars.d, _mars.d)
 * Documentation:  https://dlang.org/phobos/dmd_mars.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/mars.d
 */

module dmd.mars;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.arraytypes;
import dmd.astenums;
import dmd.cond;
import dmd.console;
import dmd.compiler;
import dmd.cpreprocess;
import dmd.dmdparams;
import dmd.dinifile;
import dmd.dinterpret;
import dmd.dmodule;
import dmd.doc;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dtemplate;
import dmd.dtoh;
import dmd.errors;
import dmd.expression;
import dmd.globals;
import dmd.hdrgen;
import dmd.id;
import dmd.identifier;
import dmd.inline;
import dmd.location;
import dmd.json;
import dmd.mtype;
import dmd.objc;
import dmd.root.array;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.man;
import dmd.common.outbuffer;
import dmd.root.response;
import dmd.root.rmem;
import dmd.root.string;
import dmd.root.stringtable;
import dmd.semantic2;
import dmd.semantic3;
import dmd.target;
import dmd.utils;

/**
 * Print DMD's logo on stdout
 */
void logo()
{
    printf("DMD%llu D Compiler %.*s\n%.*s %.*s\n",
        cast(ulong)size_t.sizeof * 8,
        cast(int) global.versionString().length, global.versionString().ptr,
        cast(int)global.copyright.length, global.copyright.ptr,
        cast(int)global.written.length, global.written.ptr
    );
}

/**
Print DMD's logo with more debug information and error-reporting pointers.

Params:
    stream = output stream to print the information on
*/
void printInternalFailure(FILE* stream)
{
    fputs(("---\n" ~
    "ERROR: This is a compiler bug.\n" ~
            "Please report it via https://issues.dlang.org/enter_bug.cgi\n" ~
            "with, preferably, a reduced, reproducible example and the information below.\n" ~
    "DustMite (https://github.com/CyberShadow/DustMite/wiki) can help with the reduction.\n" ~
    "---\n").ptr, stream);
    stream.fprintf("DMD %.*s\n", cast(int) global.versionString().length, global.versionString().ptr);
    stream.printPredefinedVersions;
    stream.printGlobalConfigs();
    fputs("---\n".ptr, stream);
}

/**
 * Print DMD's usage message on stdout
 */
void usage()
{
    import dmd.cli : CLIUsage;
    logo();
    auto help = CLIUsage.usage;
    const inifileCanon = FileName.canonicalName(global.inifilename);
    printf("
Documentation: https://dlang.org/
Config file: %.*s
Usage:
  dmd [<option>...] <file>...
  dmd [<option>...] -run <file> [<arg>...]

Where:
  <file>           D source file
  <arg>            Argument to pass when running the resulting program

<option>:
  @<cmdfile>       read arguments from cmdfile
%.*s", cast(int)inifileCanon.length, inifileCanon.ptr, cast(int)help.length, &help[0]);
}

extern (C++) void generateJson(ref Modules modules)
{
    OutBuffer buf;
    json_generate(modules, buf);

    // Write buf to file
    const(char)[] name = global.params.json.name;
    if (name == "-")
    {
        // Write to stdout; assume it succeeds
        size_t n = fwrite(buf[].ptr, 1, buf.length, stdout);
        assert(n == buf.length); // keep gcc happy about return values
    }
    else
    {
        /* The filename generation code here should be harmonized with Module.setOutfilename()
         */
        const(char)[] jsonfilename;
        if (name)
        {
            jsonfilename = FileName.defaultExt(name, json_ext);
        }
        else
        {
            if (global.params.objfiles.length == 0)
            {
                error(Loc.initial, "cannot determine JSON filename, use `-Xf=<file>` or provide a source file");
                fatal();
            }
            // Generate json file name from first obj name
            const(char)[] n = global.params.objfiles[0].toDString;
            n = FileName.name(n);
            //if (!FileName::absolute(name))
            //    name = FileName::combine(dir, name);
            jsonfilename = FileName.forceExt(n, json_ext);
        }
        if (!writeFile(Loc.initial, jsonfilename, buf[]))
            fatal();
    }
}

version (DigitalMars)
{
    void installMemErrHandler()
    {
        // (only available on some platforms on DMD)
        const shouldDoMemoryError = getenv("DMD_INSTALL_MEMERR_HANDLER");
        if (shouldDoMemoryError !is null && *shouldDoMemoryError == '1')
        {
            import etc.linux.memoryerror;
            static if (is(typeof(registerMemoryErrorHandler())))
            {
                registerMemoryErrorHandler();
            }
            else
            {
                printf("**WARNING** Memory error handler not supported on this platform!\n");
            }
        }
    }
}

version (NoMain)
{
    version (DigitalMars)
    {
        shared static this()
        {
            installMemErrHandler();
        }
    }
}

/**
 * Parses an environment variable containing command-line flags
 * and append them to `args`.
 *
 * This function is used to read the content of DFLAGS.
 * Flags are separated based on spaces and tabs.
 *
 * Params:
 *   envvalue = The content of an environment variable
 *   args     = Array to append the flags to, if any.
 */
void getenv_setargv(const(char)* envvalue, Strings* args)
{
    if (!envvalue)
        return;

    char* env = mem.xstrdup(envvalue); // create our own writable copy
    //printf("env = '%s'\n", env);
    while (1)
    {
        switch (*env)
        {
        case ' ':
        case '\t':
            env++;
            break;

        case 0:
            return;

        default:
        {
            args.push(env); // append
            auto p = env;
            auto slash = 0;
            bool instring = false;
            while (1)
            {
                auto c = *env++;
                switch (c)
                {
                case '"':
                    p -= (slash >> 1);
                    if (slash & 1)
                    {
                        p--;
                        goto default;
                    }
                    instring ^= true;
                    slash = 0;
                    continue;

                case ' ':
                case '\t':
                    if (instring)
                        goto default;
                    *p = 0;
                    //if (wildcard)
                    //    wildcardexpand();     // not implemented
                    break;

                case '\\':
                    slash++;
                    *p++ = c;
                    continue;

                case 0:
                    *p = 0;
                    //if (wildcard)
                    //    wildcardexpand();     // not implemented
                    return;

                default:
                    slash = 0;
                    *p++ = c;
                    continue;
                }
                break;
            }
            break;
        }
        }
    }
}

/**
 * Parse command line arguments for the last instance of -m32, -m64, -m32mscoff or -m32omfobj
 * to detect the desired architecture.
 *
 * Params:
 *   args = Command line arguments
 *   arch = Default value to use for architecture.
 *          Should be "32" or "64"
 *
 * Returns:
 *   "32", "64" or "32omf" if the "-m32", "-m64", "-m32omf" flags were passed,
 *   respectively. If they weren't, return `arch`.
 */
const(char)[] parse_arch_arg(Strings* args, const(char)[] arch)
{
    foreach (const p; *args)
    {
        const(char)[] arg = p.toDString;

        if (arg.length && arg[0] == '-')
        {
            if (arg[1 .. $] == "m32" || arg[1 .. $] == "m32omf" || arg[1 .. $] == "m64")
                arch = arg[2 .. $];
            else if (arg[1 .. $] == "m32mscoff")
                arch = "32";
            else if (arg[1 .. $] == "run")
                break;
        }
    }
    return arch;
}


/**
 * Parse command line arguments for the last instance of -conf=path.
 *
 * Params:
 *   args = Command line arguments
 *
 * Returns:
 *   The 'path' in -conf=path, which is the path to the config file to use
 */
const(char)[] parse_conf_arg(Strings* args)
{
    const(char)[] conf;
    foreach (const p; *args)
    {
        const(char)[] arg = p.toDString;
        if (arg.length && arg[0] == '-')
        {
            if(arg.length >= 6 && arg[1 .. 6] == "conf="){
                conf = arg[6 .. $];
            }
            else if (arg[1 .. $] == "run")
                break;
        }
    }
    return conf;
}


/**
 * Set the default and debug libraries to link against, if not already set
 *
 * Must be called after argument parsing is done, as it won't
 * override any value.
 * Note that if `-defaultlib=` or `-debuglib=` was used,
 * we don't override that either.
 */
void setDefaultLibrary(ref Param params, const ref Target target)
{
    if (driverParams.defaultlibname is null)
    {
        if (target.os == Target.OS.Windows)
        {
            if (target.isX86_64)
                driverParams.defaultlibname = "phobos64";
            else if (!target.omfobj)
                driverParams.defaultlibname = "phobos32mscoff";
            else
                driverParams.defaultlibname = "phobos";
        }
        else if (target.os & (Target.OS.linux | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.Solaris | Target.OS.DragonFlyBSD))
        {
            driverParams.defaultlibname = "libphobos2.a";
        }
        else if (target.os == Target.OS.OSX)
        {
            driverParams.defaultlibname = "phobos2";
        }
        else
        {
            assert(0, "fix this");
        }
    }
    else if (!driverParams.defaultlibname.length)  // if `-defaultlib=` (i.e. an empty defaultlib)
        driverParams.defaultlibname = null;

    if (driverParams.debuglibname is null)
        driverParams.debuglibname = driverParams.defaultlibname;
    else if (!driverParams.debuglibname.length)  // if `-debuglib=` (i.e. an empty debuglib)
        driverParams.debuglibname = null;
}

void printPredefinedVersions(FILE* stream)
{
    if (global.versionids)
    {
        OutBuffer buf;
        foreach (const str; *global.versionids)
        {
            buf.writeByte(' ');
            buf.writestring(str.toChars());
        }
        stream.fprintf("predefs  %s\n", buf.peekChars());
    }
}

extern(C) void printGlobalConfigs(FILE* stream)
{
    stream.fprintf("binary    %.*s\n", cast(int)global.params.argv0.length, global.params.argv0.ptr);
    stream.fprintf("version   %.*s\n", cast(int) global.versionString().length, global.versionString().ptr);
    const iniOutput = global.inifilename ? global.inifilename : "(none)";
    stream.fprintf("config    %.*s\n", cast(int)iniOutput.length, iniOutput.ptr);
    // Print DFLAGS environment variable
    {
        StringTable!(char*) environment;
        environment._init(0);
        Strings dflags;
        getenv_setargv(readFromEnv(environment, "DFLAGS"), &dflags);
        environment.reset(1);
        OutBuffer buf;
        foreach (flag; dflags[])
        {
            bool needsQuoting;
            foreach (c; flag.toDString())
            {
                if (!(isalnum(c) || c == '_'))
                {
                    needsQuoting = true;
                    break;
                }
            }

            if (flag.strchr(' '))
                buf.printf("'%s' ", flag);
            else
                buf.printf("%s ", flag);
        }

        auto res = buf[] ? buf[][0 .. $ - 1] : "(none)";
        stream.fprintf("DFLAGS    %.*s\n", cast(int)res.length, res.ptr);
    }
}

/**************************************
 * we want to write the mixin expansion file also on error, but there
 * are too many ways to terminate dmd (e.g. fatal() which calls exit(EXIT_FAILURE)),
 * so we can't rely on scope(exit) ... in tryMain() actually being executed
 * so we add atexit(&flushMixins); for those fatal exits (with the GC still valid)
 */
extern(C) void flushMixins()
{
    if (!global.params.mixinOut.buffer)
        return;

    assert(global.params.mixinOut.name);
    File.write(global.params.mixinOut.name, (*global.params.mixinOut.buffer)[]);

    global.params.mixinOut.buffer.destroy();
    global.params.mixinOut.buffer = null;
}

/****************************************************
 * Parse command line arguments.
 *
 * Prints message(s) if there are errors.
 *
 * Params:
 *      arguments = command line arguments
 *      argc = argument count
 *      params = set to result of parsing `arguments`
 *      files = set to files pulled from `arguments`
 *      target = more things set to result of parsing `arguments`
 * Returns:
 *      true if errors in command line
 */

bool parseCommandLine(const ref Strings arguments, const size_t argc, ref Param params, ref Strings files, ref Target target)
{
    bool errors;

    void error(Args ...)(const(char)* format, Args args)
    {
        dmd.errors.error(Loc.initial, format, args);
        errors = true;
    }

    /**
     * Print an error messsage about an invalid switch.
     * If an optional supplemental message has been provided,
     * it will be printed too.
     *
     * Params:
     *  p = 0 terminated string
     *  availableOptions = supplemental help message listing the available options
     */
    void errorInvalidSwitch(const(char)* p, string availableOptions = null)
    {
        error("switch `%s` is invalid", p);
        if (availableOptions !is null)
            errorSupplemental(Loc.initial, "%.*s", cast(int)availableOptions.length, availableOptions.ptr);
    }

    enum CheckOptions { success, error, help }

    /*
    Checks whether the CLI options contains a valid argument or a help argument.
    If a help argument has been used, it will set the `usageFlag`.

    Params:
        p = string as a D array
        usageFlag = parameter for the usage help page to set (by `ref`)
        missingMsg = error message to use when no argument has been provided

    Returns:
        `success` if a valid argument has been passed and it's not a help page
        `error` if an error occurred (e.g. `-foobar`)
        `help` if a help page has been request (e.g. `-flag` or `-flag=h`)
    */
    CheckOptions checkOptions(const(char)[] p, ref bool usageFlag, string missingMsg)
    {
        // Checks whether a flag has no options (e.g. -foo or -foo=)
        if (p.length == 0 || p == "=")
        {
            .error(Loc.initial, "%.*s", cast(int)missingMsg.length, missingMsg.ptr);
            errors = true;
            usageFlag = true;
            return CheckOptions.help;
        }
        if (p[0] != '=')
            return CheckOptions.error;
        p = p[1 .. $];
        /* Checks whether the option pointer supplied is a request
           for the help page, e.g. -foo=j */
        if ((p == "h" || p == "?") || // -flag=h || -flag=?
             p == "help")
        {
            usageFlag = true;
            return CheckOptions.help;
        }
        return CheckOptions.success;
    }

    static string checkOptionsMixin(string usageFlag, string missingMsg)
    {
        return q{
            final switch (checkOptions(arg[len - 1 .. $], params.help.}~usageFlag~","~
                          `"`~missingMsg~`"`~q{))
            {
                case CheckOptions.error:
                    goto Lerror;
                case CheckOptions.help:
                    return false;
                case CheckOptions.success:
                    break;
            }
        };
    }

    import dmd.cli : Usage;
    bool parseCLIOption(string name, Usage.Feature[] features)(ref Param params, const(char)[] p)
    {
        // Parse:
        //      -<name>=<feature>
        const(char)[] ps = p[name.length + 1 .. $];
        const(char)[] ident = ps[1 .. $];
        if (Identifier.isValidIdentifier(ident))
        {
            string generateTransitionsText()
            {
                import dmd.cli : Usage;
                string buf = `case "all":`;
                foreach (t; features)
                {
                    if (t.deprecated_)
                        continue;

                    buf ~= `setFlagFor(name, params.`~t.paramName~`);`;
                }
                buf ~= "return true;\n";

                foreach (t; features)
                {
                    buf ~= `case "`~t.name~`":`;
                    if (t.deprecated_)
                        buf ~= "deprecation(Loc.initial, \"`-"~name~"="~t.name~"` no longer has any effect.\"); ";
                    buf ~= `setFlagFor(name, params.`~t.paramName~`); return true;`;
                }
                return buf;
            }

            switch (ident)
            {
                mixin(generateTransitionsText());
            default:
                return false;
            }
        }
        return false;
    }

    version (none)
    {
        for (size_t i = 0; i < arguments.length; i++)
        {
            printf("arguments[%d] = '%s'\n", i, arguments[i]);
        }
    }

    files.reserve(arguments.length - 1);

    for (size_t i = 1; i < arguments.length; i++)
    {
        const(char)* p = arguments[i];
        const(char)[] arg = p.toDString();
        if (*p != '-')
        {
            if (target.os == Target.OS.Windows)
            {
                const ext = FileName.ext(arg);
                if (ext.length && FileName.equals(ext, "exe"))
                {
                    params.objname = arg;
                    continue;
                }
                if (arg == "/?")
                {
                    params.help.usage = true;
                    return false;
                }
            }
            files.push(p);
            continue;
        }

        if (arg == "-allinst")               // https://dlang.org/dmd.html#switch-allinst
            params.allInst = true;
        else if (startsWith(p + 1, "cpp="))  // https://dlang.org/dmd.html#switch-cpp
        {
            if (p[5])
            {
                params.cpp = p + 5;
            }
            else
            {
                errorInvalidSwitch(p, "it must be followed by the filename of the desired C preprocessor");
                return false;
            }
        }
        else if (arg == "-de")               // https://dlang.org/dmd.html#switch-de
            params.useDeprecated = DiagnosticReporting.error;
        else if (arg == "-d")                // https://dlang.org/dmd.html#switch-d
            params.useDeprecated = DiagnosticReporting.off;
        else if (arg == "-dw")               // https://dlang.org/dmd.html#switch-dw
            params.useDeprecated = DiagnosticReporting.inform;
        else if (arg == "-c")                // https://dlang.org/dmd.html#switch-c
            driverParams.link = false;
        else if (startsWith(p + 1, "checkaction")) // https://dlang.org/dmd.html#switch-checkaction
        {
            /* Parse:
             *    -checkaction=D|C|halt|context
             */
            enum len = "-checkaction=".length;
            mixin(checkOptionsMixin("checkAction",
                "`-check=<behavior>` requires a behavior"));
            switch (arg[len .. $])
            {
            case "D":
                params.checkAction = CHECKACTION.D;
                break;
            case "C":
                params.checkAction = CHECKACTION.C;
                break;
            case "halt":
                params.checkAction = CHECKACTION.halt;
                break;
            case "context":
                params.checkAction = CHECKACTION.context;
                break;
            default:
                errorInvalidSwitch(p);
                params.help.checkAction = true;
                return false;
            }
        }
        else if (startsWith(p + 1, "check")) // https://dlang.org/dmd.html#switch-check
        {
            enum len = "-check=".length;
            mixin(checkOptionsMixin("check",
                "`-check=<action>` requires an action"));
            /* Parse:
             *    -check=[assert|bounds|in|invariant|out|switch][=[on|off]]
             */

            // Check for legal option string; return true if so
            static bool check(const(char)[] checkarg, string name, ref CHECKENABLE ce)
            {
                if (checkarg.length >= name.length &&
                    checkarg[0 .. name.length] == name)
                {
                    checkarg = checkarg[name.length .. $];

                    if (checkarg.length == 0 ||
                        checkarg == "=on")
                    {
                        ce = CHECKENABLE.on;
                        return true;
                    }
                    else if (checkarg == "=off")
                    {
                        ce = CHECKENABLE.off;
                        return true;
                    }
                }
                return false;
            }

            const(char)[] checkarg = arg[len .. $];
            if (checkarg == "on")
            {
                params.useAssert        = CHECKENABLE.on;
                params.useArrayBounds   = CHECKENABLE.on;
                params.useIn            = CHECKENABLE.on;
                params.useInvariants    = CHECKENABLE.on;
                params.useOut           = CHECKENABLE.on;
                params.useSwitchError   = CHECKENABLE.on;
            }
            else if (checkarg == "off")
            {
                params.useAssert        = CHECKENABLE.off;
                params.useArrayBounds   = CHECKENABLE.off;
                params.useIn            = CHECKENABLE.off;
                params.useInvariants    = CHECKENABLE.off;
                params.useOut           = CHECKENABLE.off;
                params.useSwitchError   = CHECKENABLE.off;
            }
            else if (!(check(checkarg, "assert",    params.useAssert) ||
                  check(checkarg, "bounds",    params.useArrayBounds) ||
                  check(checkarg, "in",        params.useIn         ) ||
                  check(checkarg, "invariant", params.useInvariants ) ||
                  check(checkarg, "out",       params.useOut        ) ||
                  check(checkarg, "switch",    params.useSwitchError)))
            {
                errorInvalidSwitch(p);
                params.help.check = true;
                return false;
            }
        }
        else if (startsWith(p + 1, "color")) // https://dlang.org/dmd.html#switch-color
        {
            // Parse:
            //      -color
            //      -color=auto|on|off
            if (p[6] == '=')
            {
                switch(arg[7 .. $])
                {
                case "on":
                    params.v.color = true;
                    break;
                case "off":
                    params.v.color = false;
                    break;
                case "auto":
                    break;
                default:
                    errorInvalidSwitch(p, "Available options for `-color` are `on`, `off` and `auto`");
                    return true;
                }
            }
            else if (p[6])
                goto Lerror;
            else
                params.v.color = true;
        }
        else if (startsWith(p + 1, "conf=")) // https://dlang.org/dmd.html#switch-conf
        {
            // ignore, already handled above
        }
        else if (startsWith(p + 1, "cov")) // https://dlang.org/dmd.html#switch-cov
        {
            params.cov = true;
            // Parse:
            //      -cov
            //      -cov=ctfe
            //      -cov=nnn
            if (arg == "-cov=ctfe")
            {
                params.ctfe_cov = true;
            }
            else if (p[4] == '=')
            {
                if (!params.covPercent.parseDigits(p.toDString()[5 .. $], 100))
                {
                    errorInvalidSwitch(p, "Only a number between 0 and 100 can be passed to `-cov=<num>`");
                    return true;
                }
            }
            else if (p[4])
                goto Lerror;
        }
        else if (arg == "-shared")
            driverParams.dll = true;
        else if (startsWith(p + 1, "visibility="))
        {
            const(char)[] vis = arg["-visibility=".length .. $];

            switch (vis)
            {
                case "default":
                    driverParams.exportVisibility = ExpVis.default_;
                    break;
                case "hidden":
                    driverParams.exportVisibility = ExpVis.hidden;
                    break;
                case "public":
                    driverParams.exportVisibility = ExpVis.public_;
                    break;
                default:
                    error("unknown visibility '%.*s', must be 'default', 'hidden' or 'public'", cast(int) vis.length, vis.ptr);
            }
        }
        else if (startsWith(p + 1, "dllimport="))
        {
            const(char)[] imp = arg["-dllimport=".length .. $];

            switch (imp)
            {
                case "none":
                    driverParams.symImport = SymImport.none;
                    break;
                case "defaultLibsOnly":
                    driverParams.symImport = SymImport.defaultLibsOnly;
                    break;
                case "all":
                    driverParams.symImport = SymImport.all;
                    break;
                default:
                    error("unknown dllimport '%.*s', must be 'none', 'defaultLibsOnly' or 'all'", cast(int) imp.length, imp.ptr);
            }
        }
        else if (arg == "-fIBT")
        {
            driverParams.ibt = true;
        }
        else if (arg == "-fPIC")
        {
            driverParams.pic = PIC.pic;
        }
        else if (arg == "-fPIE")
        {
            driverParams.pic = PIC.pie;
        }
        else if (arg == "-map") // https://dlang.org/dmd.html#switch-map
            driverParams.map = true;
        else if (arg == "-multiobj")
            params.multiobj = true;
        else if (startsWith(p + 1, "mixin="))
        {
            auto tmp = p + 6 + 1;
            if (!tmp[0])
                goto Lnoarg;
            params.mixinOut.doOutput = true;
            params.mixinOut.name = mem.xstrdup(tmp).toDString;
        }
        else if (arg == "-g") // https://dlang.org/dmd.html#switch-g
            driverParams.symdebug = true;
        else if (startsWith(p + 1, "gdwarf")) // https://dlang.org/dmd.html#switch-gdwarf
        {
            if (driverParams.dwarf)
            {
                error("`-gdwarf=<version>` can only be provided once");
                break;
            }
            driverParams.symdebug = true;

            enum len = "-gdwarf=".length;
            // Parse:
            //      -gdwarf=version
            if (arg.length < len || !driverParams.dwarf.parseDigits(arg[len .. $], 5) || driverParams.dwarf < 3)
            {
                error("`-gdwarf=<version>` requires a valid version [3|4|5]", p);
                return false;
            }
        }
        else if (arg == "-gf")
        {
            driverParams.symdebug = true;
            driverParams.symdebugref = true;
        }
        else if (arg == "-gs")  // https://dlang.org/dmd.html#switch-gs
            driverParams.alwaysframe = true;
        else if (arg == "-gx")  // https://dlang.org/dmd.html#switch-gx
            driverParams.stackstomp = true;
        else if (arg == "-lowmem") // https://dlang.org/dmd.html#switch-lowmem
        {
            // ignore, already handled in C main
        }
        else if (arg.length > 6 && arg[0..6] == "--DRT-")
        {
            continue; // skip druntime options, e.g. used to configure the GC
        }
        else if (arg == "-m32") // https://dlang.org/dmd.html#switch-m32
        {
            target.isX86_64 = false;
            target.omfobj = false;
        }
        else if (arg == "-m64") // https://dlang.org/dmd.html#switch-m64
        {
            target.isX86_64 = true;
            target.omfobj = false;
        }
        else if (arg == "-m32mscoff") // https://dlang.org/dmd.html#switch-m32mscoff
        {
            target.isX86_64 = false;
            target.omfobj = false;
        }
        else if (arg == "-m32omf") // https://dlang.org/dmd.html#switch-m32omfobj
        {
            target.isX86_64 = false;
            target.omfobj = true;
        }
        else if (startsWith(p + 1, "mscrtlib="))
        {
            driverParams.mscrtlib = arg[10 .. $];
        }
        else if (startsWith(p + 1, "profile")) // https://dlang.org/dmd.html#switch-profile
        {
            // Parse:
            //      -profile
            //      -profile=gc
            if (p[8] == '=')
            {
                if (arg[9 .. $] == "gc")
                    params.tracegc = true;
                else
                {
                    errorInvalidSwitch(p, "Only `gc` is allowed for `-profile`");
                    return true;
                }
            }
            else if (p[8])
                goto Lerror;
            else
                params.trace = true;
        }
        else if (arg == "-v") // https://dlang.org/dmd.html#switch-v
            params.v.verbose = true;
        else if (arg == "-vcg-ast")
            params.vcg_ast = true;
        else if (arg == "-vasm") // https://dlang.org/dmd.html#switch-vasm
            driverParams.vasm = true;
        else if (arg == "-vtls") // https://dlang.org/dmd.html#switch-vtls
            params.v.tls = true;
        else if (startsWith(p + 1, "vtemplates")) // https://dlang.org/dmd.html#switch-vtemplates
        {
            params.v.templates = true;
            if (p[1 + "vtemplates".length] == '=')
            {
                const(char)[] style = arg[1 + "vtemplates=".length .. $];
                switch (style)
                {
                case "list-instances":
                    params.v.templatesListInstances = true;
                    break;
                default:
                    error("unknown vtemplates style '%.*s', must be 'list-instances'", cast(int) style.length, style.ptr);
                }
            }
        }
        else if (arg == "-vcolumns") // https://dlang.org/dmd.html#switch-vcolumns
            params.v.showColumns = true;
        else if (arg == "-vgc") // https://dlang.org/dmd.html#switch-vgc
            params.v.gc = true;
        else if (startsWith(p + 1, "verrors")) // https://dlang.org/dmd.html#switch-verrors
        {
            if (p[8] != '=')
            {
                errorInvalidSwitch(p, "Expected argument following `-verrors , e.g. `-verrors=100`");
                return true;
            }
            if (startsWith(p + 9, "spec"))
            {
                params.v.showGaggedErrors = true;
            }
            else if (startsWith(p + 9, "context"))
            {
                params.v.printErrorContext = true;
            }
            else if (!params.v.errorLimit.parseDigits(p.toDString()[9 .. $]))
            {
                errorInvalidSwitch(p, "Only number, `spec`, or `context` are allowed for `-verrors`");
                return true;
            }
        }
        else if (startsWith(p + 1, "verror-supplements"))
        {
            if (!params.v.errorSupplementLimit.parseDigits(p.toDString()[20 .. $]))
            {
                errorInvalidSwitch(p, "Only a number is allowed for `-verror-supplements`");
                return true;
            }
        }
        else if (startsWith(p + 1, "verror-style="))
        {
            const(char)[] style = arg["verror-style=".length + 1 .. $];

            switch (style)
            {
            case "digitalmars":
                params.v.messageStyle = MessageStyle.digitalmars;
                break;
            case "gnu":
                params.v.messageStyle = MessageStyle.gnu;
                break;
            default:
                error("unknown error style '%.*s', must be 'digitalmars' or 'gnu'", cast(int) style.length, style.ptr);
            }
        }
        else if (startsWith(p + 1, "target"))
        {
            enum len = "-target=".length;
            const triple = Triple(p + len);
            target.setTriple(triple);
        }
        else if (startsWith(p + 1, "mcpu")) // https://dlang.org/dmd.html#switch-mcpu
        {
            enum len = "-mcpu=".length;
            // Parse:
            //      -mcpu=identifier
            mixin(checkOptionsMixin("mcpu",
                "`-mcpu=<architecture>` requires an architecture"));
            if (Identifier.isValidIdentifier(p + len))
            {
                const ident = p + len;
                switch (ident.toDString())
                {
                case "baseline":
                    target.cpu = CPU.baseline;
                    break;
                case "avx":
                    target.cpu = CPU.avx;
                    break;
                case "avx2":
                    target.cpu = CPU.avx2;
                    break;
                case "native":
                    target.cpu = CPU.native;
                    break;
                default:
                    errorInvalidSwitch(p, "Only `baseline`, `avx`, `avx2` or `native` are allowed for `-mcpu`");
                    params.help.mcpu = true;
                    return false;
                }
            }
            else
            {
                errorInvalidSwitch(p, "Only `baseline`, `avx`, `avx2` or `native` are allowed for `-mcpu`");
                params.help.mcpu = true;
                return false;
            }
        }
        else if (startsWith(p + 1, "os")) // https://dlang.org/dmd.html#switch-os
        {
            enum len = "-os=".length;
            // Parse:
            //      -os=identifier
            immutable string msg = "Only `host`, `linux`, `windows`, `osx`,`openbsd`, `freebsd`, `solaris`, `dragonflybsd` allowed for `-os`";
            if (Identifier.isValidIdentifier(p + len))
            {
                const ident = p + len;
                switch (ident.toDString())
                {
                case "host":         target.os = defaultTargetOS();      break;
                case "linux":        target.os = Target.OS.linux;        break;
                case "windows":      target.os = Target.OS.Windows;      break;
                case "osx":          target.os = Target.OS.OSX;          break;
                case "openbsd":      target.os = Target.OS.OpenBSD;      break;
                case "freebsd":      target.os = Target.OS.FreeBSD;      break;
                case "solaris":      target.os = Target.OS.Solaris;      break;
                case "dragonflybsd": target.os = Target.OS.DragonFlyBSD; break;
                default:
                    errorInvalidSwitch(p, msg);
                    return false;
                }
            }
            else
            {
                errorInvalidSwitch(p, msg);
                return false;
            }
        }
        else if (startsWith(p + 1, "extern-std")) // https://dlang.org/dmd.html#switch-extern-std
        {
            enum len = "-extern-std=".length;
            // Parse:
            //      -extern-std=identifier
            mixin(checkOptionsMixin("externStd",
                "`-extern-std=<standard>` requires a standard"));
            const(char)[] cpprev = arg[len .. $];

            switch (cpprev)
            {
            case "c++98":
                params.cplusplus = CppStdRevision.cpp98;
                break;
            case "c++11":
                params.cplusplus = CppStdRevision.cpp11;
                break;
            case "c++14":
                params.cplusplus = CppStdRevision.cpp14;
                break;
            case "c++17":
                params.cplusplus = CppStdRevision.cpp17;
                break;
            case "c++20":
                params.cplusplus = CppStdRevision.cpp20;
                break;
            default:
                error("switch `%s` is invalid", p);
                params.help.externStd = true;
                return false;
            }
        }
        else if (startsWith(p + 1, "transition")) // https://dlang.org/dmd.html#switch-transition
        {
            enum len = "-transition=".length;
            // Parse:
            //      -transition=number
            mixin(checkOptionsMixin("transition",
                "`-transition=<name>` requires a name"));
            if (!parseCLIOption!("transition", Usage.transitions)(params, arg))
            {
                // Legacy -transition flags
                // Before DMD 2.085, DMD `-transition` was used for all language flags
                // These are kept for backwards compatibility, but no longer documented
                if (isdigit(cast(char)p[len]))
                {
                    uint num;
                    if (!num.parseDigits(p.toDString()[len .. $]))
                        goto Lerror;

                    // Bugzilla issue number
                    switch (num)
                    {
                        case 3449:
                            params.v.field = true;
                            break;
                        case 14_246:
                            params.dtorFields = FeatureState.enabled;
                            break;
                        case 14_488:
                            break;
                        case 16_997:
                            deprecation(Loc.initial, "`-transition=16997` is now the default behavior");
                            break;
                        default:
                            error("transition `%s` is invalid", p);
                            params.help.transition = true;
                            return false;
                    }
                }
                else if (Identifier.isValidIdentifier(p + len))
                {
                    const ident = p + len;
                    switch (ident.toDString())
                    {
                        case "dtorfields":
                            params.dtorFields = FeatureState.enabled;
                            break;
                        case "intpromote":
                            deprecation(Loc.initial, "`-transition=intpromote` is now the default behavior");
                            break;
                        default:
                            error("transition `%s` is invalid", p);
                            params.help.transition = true;
                            return false;
                    }
                }
                errorInvalidSwitch(p);
                params.help.transition = true;
                return false;
            }
        }
        else if (startsWith(p + 1, "preview") ) // https://dlang.org/dmd.html#switch-preview
        {
            enum len = "-preview=".length;
            // Parse:
            //      -preview=name
            mixin(checkOptionsMixin("preview",
                "`-preview=<name>` requires a name"));

            if (!parseCLIOption!("preview", Usage.previews)(params, arg))
            {
                error("preview `%s` is invalid", p);
                params.help.preview = true;
                return false;
            }

            if (params.useDIP1021)
                params.useDIP1000 = FeatureState.enabled;    // dip1021 implies dip1000

            // copy previously standalone flags from -transition
            // -preview=dip1000 implies -preview=dip25 too
            if (params.useDIP1000 == FeatureState.enabled)
                params.useDIP25 = FeatureState.enabled;
        }
        else if (startsWith(p + 1, "revert") ) // https://dlang.org/dmd.html#switch-revert
        {
            enum len = "-revert=".length;
            // Parse:
            //      -revert=name
            mixin(checkOptionsMixin("revert",
                "`-revert=<name>` requires a name"));

            if (!parseCLIOption!("revert", Usage.reverts)(params, arg))
            {
                error("revert `%s` is invalid", p);
                params.help.revert = true;
                return false;
            }
        }
        else if (arg == "-w")   // https://dlang.org/dmd.html#switch-w
            params.warnings = DiagnosticReporting.error;
        else if (arg == "-wi")  // https://dlang.org/dmd.html#switch-wi
            params.warnings = DiagnosticReporting.inform;
        else if (arg == "-wo")  // https://dlang.org/dmd.html#switch-wo
        {
            // Obsolete features has been obsoleted until a DIP for "additions"
            // has been drafted and ratified in the language spec.
            // Rather, these old features will just be accepted without warning.
        }
        else if (arg == "-O")   // https://dlang.org/dmd.html#switch-O
            driverParams.optimize = true;
        else if (arg == "-o-")  // https://dlang.org/dmd.html#switch-o-
            params.obj = false;
        else if (p[1] == 'o')
        {
            const(char)* path;
            switch (p[2])
            {
            case 'd':                       // https://dlang.org/dmd.html#switch-od
                if (!p[3])
                    goto Lnoarg;
                path = p + 3 + (p[3] == '=');
                version (Windows)
                {
                    path = toWinPath(path);
                }
                params.objdir = path.toDString;
                break;
            case 'f':                       // https://dlang.org/dmd.html#switch-of
                if (!p[3])
                    goto Lnoarg;
                path = p + 3 + (p[3] == '=');
                version (Windows)
                {
                    path = toWinPath(path);
                }
                params.objname = path.toDString;
                break;
            case 'p':                       // https://dlang.org/dmd.html#switch-op
                if (p[3])
                    goto Lerror;
                params.preservePaths = true;
                break;
            case 0:
                error("-o no longer supported, use -of or -od");
                break;
            default:
                goto Lerror;
            }
        }
        else if (p[1] == 'D')       // https://dlang.org/dmd.html#switch-D
        {
            params.ddoc.doOutput = true;
            switch (p[2])
            {
            case 'd':               // https://dlang.org/dmd.html#switch-Dd
                if (!p[3])
                    goto Lnoarg;
                params.ddoc.dir = (p + 3 + (p[3] == '=')).toDString();
                break;
            case 'f':               // https://dlang.org/dmd.html#switch-Df
                if (!p[3])
                    goto Lnoarg;
                params.ddoc.name = (p + 3 + (p[3] == '=')).toDString();
                break;
            case 0:
                break;
            default:
                goto Lerror;
            }
        }
        else if (p[1] == 'H' && p[2] == 'C')  // https://dlang.org/dmd.html#switch-HC
        {
            params.cxxhdr.doOutput = true;
            switch (p[3])
            {
            case 'd':               // https://dlang.org/dmd.html#switch-HCd
                if (!p[4])
                    goto Lnoarg;
                params.cxxhdr.dir = (p + 4 + (p[4] == '=')).toDString;
                break;
            case 'f':               // https://dlang.org/dmd.html#switch-HCf
                if (!p[4])
                    goto Lnoarg;
                params.cxxhdr.name = (p + 4 + (p[4] == '=')).toDString;
                break;
            case '=':
                enum len = "-HC=".length;
                mixin(checkOptionsMixin("hc", "`-HC=<mode>` requires a valid mode"));
                const mode = arg[len .. $];
                switch (mode)
                {
                    case "silent":
                        /* already set above */
                        break;
                    case "verbose":
                        params.cxxhdr.fullOutput = true;
                        break;
                    default:
                        errorInvalidSwitch(p);
                        params.help.hc = true;
                        return false;
                }
                break;
            case 0:
                break;
            default:
                goto Lerror;
            }
        }
        else if (p[1] == 'H')       // https://dlang.org/dmd.html#switch-H
        {
            params.dihdr.doOutput = true;
            switch (p[2])
            {
            case 'd':               // https://dlang.org/dmd.html#switch-Hd
                if (!p[3])
                    goto Lnoarg;
                params.dihdr.dir = (p + 3 + (p[3] == '=')).toDString;
                break;
            case 'f':               // https://dlang.org/dmd.html#switch-Hf
                if (!p[3])
                    goto Lnoarg;
                params.dihdr.name = (p + 3 + (p[3] == '=')).toDString;
                break;
            case 0:
                break;
            default:
                goto Lerror;
            }
        }
        else if (startsWith(p + 1, "Xcc="))
        {
            params.linkswitches.push(p + 5);
            params.linkswitchIsForCC.push(true);
        }
        else if (p[1] == 'X')       // https://dlang.org/dmd.html#switch-X
        {
            params.json.doOutput = true;
            switch (p[2])
            {
            case 'f':               // https://dlang.org/dmd.html#switch-Xf
                if (!p[3])
                    goto Lnoarg;
                params.json.name = (p + 3 + (p[3] == '=')).toDString;
                break;
            case 'i':
                if (!p[3])
                    goto Lnoarg;
                if (p[3] != '=')
                    goto Lerror;
                if (!p[4])
                    goto Lnoarg;

                {
                    auto flag = tryParseJsonField(p + 4);
                    if (!flag)
                    {
                        error("unknown JSON field `-Xi=%s`, expected one of " ~ jsonFieldNames, p + 4);
                        continue;
                    }
                    global.params.jsonFieldFlags |= flag;
                }
                break;
            case 0:
                break;
            default:
                goto Lerror;
            }
        }
        else if (arg == "-ignore")      // https://dlang.org/dmd.html#switch-ignore
            params.ignoreUnsupportedPragmas = true;
        else if (arg == "-inline")      // https://dlang.org/dmd.html#switch-inline
        {
            params.useInline = true;
            params.dihdr.fullOutput = true;
        }
        else if (arg == "-i")
            includeImports = true;
        else if (startsWith(p + 1, "i="))
        {
            includeImports = true;
            if (!p[3])
            {
                error("invalid option '%s', module patterns cannot be empty", p);
            }
            else
            {
                // NOTE: we could check that the argument only contains valid "module-pattern" characters.
                //       Invalid characters doesn't break anything but an error message to the user might
                //       be nice.
                includeModulePatterns.push(p + 3);
            }
        }
        else if (arg == "-dip25")       // https://dlang.org/dmd.html#switch-dip25
        {
            // @@@ DEPRECATION 2.112 @@@
            deprecation(Loc.initial, "`-dip25` no longer has any effect");
            params.useDIP25 =  FeatureState.enabled;
        }
        else if (arg == "-dip1000")
        {
            params.useDIP25 = FeatureState.enabled;
            params.useDIP1000 = FeatureState.enabled;
        }
        else if (arg == "-dip1008")
        {
            params.ehnogc = true;
        }
        else if (arg == "-lib")         // https://dlang.org/dmd.html#switch-lib
            driverParams.lib = true;
        else if (arg == "-nofloat")
            driverParams.nofloat = true;
        else if (arg == "-quiet")
        {
            // Ignore
        }
        else if (arg == "-release")     // https://dlang.org/dmd.html#switch-release
            params.release = true;
        else if (arg == "-betterC")     // https://dlang.org/dmd.html#switch-betterC
        {
            params.betterC = true;
            params.allInst = true;
        }
        else if (arg == "-noboundscheck") // https://dlang.org/dmd.html#switch-noboundscheck
        {
            params.boundscheck = CHECKENABLE.off;
        }
        else if (startsWith(p + 1, "boundscheck")) // https://dlang.org/dmd.html#switch-boundscheck
        {
            // Parse:
            //      -boundscheck=[on|safeonly|off]
            if (p[12] == '=')
            {
                const(char)[] boundscheck = arg[13 .. $];

                switch (boundscheck)
                {
                case "on":
                    params.boundscheck = CHECKENABLE.on;
                    break;
                case "safeonly":
                    params.boundscheck = CHECKENABLE.safeonly;
                    break;
                case "off":
                    params.boundscheck = CHECKENABLE.off;
                    break;
                default:
                    goto Lerror;
                }
            }
            else
                goto Lerror;
        }
        else if (arg == "-nothrow") // https://dlang.org/dmd.html#switch-nothrow
        {
            params.useExceptions = false;
        }
        else if (arg == "-unittest")
            params.useUnitTests = true;
        else if (p[1] == 'I')              // https://dlang.org/dmd.html#switch-I
        {
            if (!params.imppath)
                params.imppath = new Strings();
            params.imppath.push(p + 2 + (p[2] == '='));
        }
        else if (p[1] == 'm' && p[2] == 'v' && p[3] == '=') // https://dlang.org/dmd.html#switch-mv
        {
            if (p[4] && strchr(p + 5, '='))
            {
                params.modFileAliasStrings.push(p + 4);
            }
            else
                goto Lerror;
        }
        else if (p[1] == 'J')             // https://dlang.org/dmd.html#switch-J
        {
            if (!params.fileImppath)
                params.fileImppath = new Strings();
            params.fileImppath.push(p + 2 + (p[2] == '='));
        }
        else if (startsWith(p + 1, "debug") && p[6] != 'l') // https://dlang.org/dmd.html#switch-debug
        {
            // Parse:
            //      -debug
            //      -debug=number
            //      -debug=identifier
            if (p[6] == '=')
            {
                if (isdigit(cast(char)p[7]))
                {
                    if (!params.debuglevel.parseDigits(p.toDString()[7 .. $]))
                        goto Lerror;

                    // @@@DEPRECATED_2.111@@@
                    // Deprecated in 2.101, remove in 2.111
                    deprecation(Loc.initial, "`-debug=number` is deprecated, use debug identifiers instead");
                }
                else if (Identifier.isValidIdentifier(p + 7))
                {
                    DebugCondition.addGlobalIdent((p + 7).toDString());
                }
                else
                    goto Lerror;
            }
            else if (p[6])
                goto Lerror;
            else
                params.debuglevel = 1;
        }
        else if (startsWith(p + 1, "version")) // https://dlang.org/dmd.html#switch-version
        {
            // Parse:
            //      -version=number
            //      -version=identifier
            if (p[8] == '=')
            {
                if (isdigit(cast(char)p[9]))
                {
                    if (!params.versionlevel.parseDigits(p.toDString()[9 .. $]))
                        goto Lerror;

                    // @@@DEPRECATED_2.111@@@
                    // Deprecated in 2.101, remove in 2.111
                    deprecation(Loc.initial, "`-version=number` is deprecated, use version identifiers instead");
                }
                else if (Identifier.isValidIdentifier(p + 9))
                {
                    VersionCondition.addGlobalIdent((p+9).toDString());
                }
                else
                    goto Lerror;
            }
            else
                goto Lerror;
        }
        else if (arg == "--b")
            driverParams.debugb = true;
        else if (arg == "--c")
            driverParams.debugc = true;
        else if (arg == "--f")
            driverParams.debugf = true;
        else if (arg == "--help" ||
                 arg == "-h")
        {
            params.help.usage = true;
            return false;
        }
        else if (arg == "--r")
            driverParams.debugr = true;
        else if (arg == "--version")
        {
            params.v.logo = true;
            return false;
        }
        else if (arg == "--x")
            driverParams.debugx = true;
        else if (arg == "--y")
            driverParams.debugy = true;
        else if (p[1] == 'L')                        // https://dlang.org/dmd.html#switch-L
        {
            params.linkswitches.push(p + 2 + (p[2] == '='));
            params.linkswitchIsForCC.push(false);
        }
        else if (p[1] == 'P')                        // https://dlang.org/dmd.html#switch-P
        {
            params.cppswitches.push(p + 2 + (p[2] == '='));
        }
        else if (startsWith(p + 1, "defaultlib="))   // https://dlang.org/dmd.html#switch-defaultlib
        {
            driverParams.defaultlibname = (p + 1 + 11).toDString;
        }
        else if (startsWith(p + 1, "debuglib="))     // https://dlang.org/dmd.html#switch-debuglib
        {
            driverParams.debuglibname = (p + 1 + 9).toDString;
        }
        else if (startsWith(p + 1, "deps"))          // https://dlang.org/dmd.html#switch-deps
        {
            if (params.moduleDeps.doOutput)
            {
                error("-deps[=file] can only be provided once!");
                break;
            }
            if (p[5] == '=')
            {
                params.moduleDeps.name = (p + 1 + 5).toDString;
                if (!params.moduleDeps.name[0])
                    goto Lnoarg;
            }
            else if (p[5] != '\0')
            {
                // Else output to stdout.
                goto Lerror;
            }
            params.moduleDeps.buffer = new OutBuffer();
        }
        else if (startsWith(p + 1, "makedeps"))          // https://dlang.org/dmd.html#switch-makedeps
        {
            if (params.makeDeps.name)
            {
                error("-makedeps[=file] can only be provided once!");
                break;
            }
            if (p[9] == '=')
            {
                if (p[10] == '\0')
                {
                    error("expected filename after -makedeps=");
                    break;
                }
                params.makeDeps.name = (p + 10).toDString;
            }
            else if (p[9] != '\0')
            {
                goto Lerror;
            }
            // Else output to stdout.
            params.makeDeps.doOutput = true;
        }
        else if (arg == "-main")             // https://dlang.org/dmd.html#switch-main
        {
            params.addMain = true;
        }
        else if (startsWith(p + 1, "man"))   // https://dlang.org/dmd.html#switch-man
        {
            params.help.manual = true;
            return false;
        }
        else if (arg == "-run")              // https://dlang.org/dmd.html#switch-run
        {
            params.run = true;
            size_t length = argc - i - 1;
            if (length)
            {
                const(char)[] runarg = arguments[i + 1].toDString();
                const(char)[] ext = FileName.ext(runarg);
                if (ext &&
                    FileName.equals(ext, mars_ext) == 0 &&
                    FileName.equals(ext, hdr_ext) == 0 &&
                    FileName.equals(ext, i_ext) == 0 &&
                    FileName.equals(ext, c_ext) == 0)
                {
                    error("-run must be followed by a source file, not '%s'", arguments[i + 1]);
                    break;
                }
                if (runarg == "-")
                    files.push("__stdin.d");
                else
                    files.push(arguments[i + 1]);
                params.runargs.setDim(length - 1);
                for (size_t j = 0; j < length - 1; ++j)
                {
                    params.runargs[j] = arguments[i + 2 + j];
                }
                i += length;
            }
            else
            {
                params.run = false;
                goto Lnoarg;
            }
        }
        else if (p[1] == '\0')
            files.push("__stdin.d");
        else
        {
        Lerror:
            error("unrecognized switch '%s'", arguments[i]);
            continue;
        Lnoarg:
            error("argument expected for switch '%s'", arguments[i]);
            continue;
        }
    }
    return errors;
}

/// Sets the boolean for a flag with the given name
private static void setFlagFor(string name, ref bool b) @safe
{
    b = name != "revert";
}

/// Sets the FeatureState for a flag with the given name
private static void setFlagFor(string name, ref FeatureState s) @safe
{
    s = name != "revert" ? FeatureState.enabled : FeatureState.disabled;
}

/**
Creates the module based on the file provided

The file is dispatched in one of the various arrays
(global.params.{ddoc.files,dllfiles,jsonfiles,etc...})
according to its extension.
If it is a binary file, it is added to libmodules.

Params:
  file = File name to dispatch
  libmodules = Array to which binaries (shared/static libs and object files)
               will be appended
  target = target system

Returns:
  A D module
*/
private
Module createModule(const(char)* file, ref Strings libmodules, const ref Target target)
{
    const(char)[] name;
    version (Windows)
    {
        file = toWinPath(file);
    }
    const(char)[] p = file.toDString();
    p = FileName.name(p); // strip path
    const(char)[] ext = FileName.ext(p);
    if (!ext)
    {
        if (!p.length)
        {
            error(Loc.initial, "invalid file name '%s'", file);
            fatal();
        }
        auto id = Identifier.idPool(p);
        return new Module(file.toDString, id, global.params.ddoc.doOutput, global.params.dihdr.doOutput);
    }

    /* Deduce what to do with a file based on its extension
        */
    if (FileName.equals(ext, target.obj_ext))
    {
        global.params.objfiles.push(file);
        libmodules.push(file);
        return null;
    }
    if (FileName.equals(ext, target.lib_ext))
    {
        global.params.libfiles.push(file);
        libmodules.push(file);
        return null;
    }
    if (target.os & (Target.OS.linux | Target.OS.OSX| Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.Solaris | Target.OS.DragonFlyBSD))
    {
        if (FileName.equals(ext, target.dll_ext))
        {
            global.params.dllfiles.push(file);
            libmodules.push(file);
            return null;
        }
    }
    if (FileName.equals(ext, ddoc_ext))
    {
        global.params.ddoc.files.push(file);
        return null;
    }
    if (FileName.equals(ext, json_ext))
    {
        global.params.json.doOutput = true;
        global.params.json.name = file.toDString;
        return null;
    }
    if (FileName.equals(ext, map_ext))
    {
        global.params.mapfile = file.toDString;
        return null;
    }
    if (target.os == Target.OS.Windows)
    {
        if (FileName.equals(ext, "res"))
        {
            global.params.resfile = file.toDString;
            return null;
        }
        if (FileName.equals(ext, "def"))
        {
            global.params.deffile = file.toDString;
            return null;
        }
        if (FileName.equals(ext, "exe"))
        {
            assert(0); // should have already been handled
        }
    }
    /* Examine extension to see if it is a valid
     * D, Ddoc or C source file extension
     */
    if (FileName.equals(ext, mars_ext) ||
        FileName.equals(ext, hdr_ext ) ||
        FileName.equals(ext, dd_ext  ) ||
        FileName.equals(ext, c_ext   ) ||
        FileName.equals(ext, i_ext   ))
    {
        name = FileName.removeExt(p);
        if (!name.length || name == ".." || name == ".")
        {
            error(Loc.initial, "invalid file name '%s'", file);
            fatal();
        }
    }
    else
    {
        error(Loc.initial, "unrecognized file extension %.*s", cast(int)ext.length, ext.ptr);
        fatal();
    }

    /* At this point, name is the D source file name stripped of
     * its path and extension.
     */
    auto id = Identifier.idPool(name);

    return new Module(file.toDString, id, global.params.ddoc.doOutput, global.params.dihdr.doOutput);
}

/**
Creates the list of modules based on the files provided

Files are dispatched in the various arrays
(global.params.{ddocfiles,dllfiles,jsonfiles,etc...})
according to their extension.
Binary files are added to libmodules.

Params:
  files = File names to dispatch
  libmodules = Array to which binaries (shared/static libs and object files)
               will be appended
  target = target system

Returns:
  An array of path to D modules
*/
Modules createModules(ref Strings files, ref Strings libmodules, const ref Target target)
{
    Modules modules;
    modules.reserve(files.length);
    bool firstmodule = true;
    foreach(file; files)
    {
        auto m = createModule(file, libmodules, target);

        if (m is null)
            continue;

        modules.push(m);
        if (firstmodule)
        {
            global.params.objfiles.push(m.objfile.toChars());
            firstmodule = false;
        }
    }
    return modules;
}

/// Returns: a compiled module (semantic3) containing an empty main() function, for the -main flag
Module moduleWithEmptyMain()
{
    auto result = new Module("__main.d", Identifier.idPool("__main"), false, false);
    // need 2 trailing nulls for sentinel and 2 for lexer
    auto data = arraydup("version(D_BetterC)extern(C)int main(){return 0;}else int main(){return 0;}\0\0\0\0");
    result.src = cast(ubyte[]) data[0 .. $-4];
    result.parse();
    result.importedFrom = result;
    result.importAll(null);
    result.dsymbolSemantic(null);
    result.semantic2(null);
    result.semantic3(null);
    return result;
}
