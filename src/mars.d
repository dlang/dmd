/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 * Entry point for DMD.
 *
 * This modules defines the entry point (main) for DMD, as well as related
 * utilities needed for arguments parsing, path manipulation, etc...
 * This file is not shared with other compilers which use the DMD front-end.
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _mars.d)
 */

module ddmd.mars;

import core.stdc.ctype;
import core.stdc.errno;
import core.stdc.limits;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import ddmd.arraytypes;
import ddmd.gluelayer;
import ddmd.builtin;
import ddmd.cond;
import ddmd.dinifile;
import ddmd.dinterpret;
import ddmd.dmodule;
import ddmd.doc;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.expression;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.inline;
import ddmd.json;
import ddmd.lib;
import ddmd.link;
import ddmd.mtype;
import ddmd.objc;
import ddmd.parse;
import ddmd.root.file;
import ddmd.root.filename;
import ddmd.root.man;
import ddmd.root.outbuffer;
import ddmd.root.response;
import ddmd.root.rmem;
import ddmd.root.stringtable;
import ddmd.target;
import ddmd.tokens;
import ddmd.utils;


/**
 * Print DMD's logo on stdout
 */
private void logo()
{
    printf("DMD%llu D Compiler %s\n%s %s\n", cast(ulong)size_t.sizeof * 8, global._version, global.copyright, global.written);
}


/**
 * Print DMD's usage message on stdout
 */
private  void usage()
{
    static if (TARGET_LINUX)
    {
        const(char)* fpic = "\n  -fPIC            generate position independent code";
    }
    else
    {
        const(char)* fpic = "";
    }
    static if (TARGET_WINDOS)
    {
        const(char)* m32mscoff = "\n  -m32mscoff       generate 32 bit code and write MS-COFF object files";
    }
    else
    {
        const(char)* m32mscoff = "";
    }
    logo();
    printf("
Documentation: http://dlang.org/
Config file: %s
Usage:
  dmd [<option>...] <file>...
  dmd [<option>...] -run <file> [<arg>...]

Where:
  <file>           D source file
  <arg>            Argument to pass when running the resulting program

<option>:
  @<cmdfile>       read arguments from cmdfile
  -allinst         generate code for all template instantiations
  -betterC         omit generating some runtime information and helper functions
  -boundscheck=[on|safeonly|off]   bounds checks on, in @safe only, or off
  -c               do not link
  -color           turn colored console output on
  -color=[on|off]  force colored console output on or off
  -conf=<filename> use config file at filename
  -cov             do code coverage analysis
  -cov=<nnn>       require at least nnn%% code coverage
  -D               generate documentation
  -Dd<directory>   write documentation file to directory
  -Df<filename>    write documentation file to filename
  -d               silently allow deprecated features
  -dw              show use of deprecated features as warnings (default)
  -de              show use of deprecated features as errors (halt compilation)
  -debug           compile in debug code
  -debug=<level>   compile in debug code <= level
  -debug=<ident>   compile in debug code identified by ident
  -debuglib=<name> set symbolic debug library to name
  -defaultlib=<name>
                   set default library to name
  -deps            print module dependencies (imports/file/version/debug/lib)
  -deps=<filename> write module dependencies to filename (only imports)" ~
  "%s" /* placeholder for fpic */ ~ "
  -dip25           implement http://wiki.dlang.org/DIP25 (experimental)
  -g               add symbolic debug info
  -gc              add symbolic debug info, optimize for non D debuggers
  -gs              always emit stack frame
  -gx              add stack stomp code
  -H               generate 'header' file
  -Hd=<directory>  write 'header' file to directory
  -Hf=<filename>   write 'header' file to filename
  --help           print help and exit
  -I=<directory>   look for imports also in directory
  -ignore          ignore unsupported pragmas
  -inline          do function inlining
  -J=<directory>   look for string imports also in directory
  -L=<linkerflag>  pass linkerflag to link
  -lib             generate library rather than object files
  -m32             generate 32 bit code" ~
  "%s" /* placeholder for m32mscoff */ ~ "
  -m64             generate 64 bit code
  -main            add default main() (e.g. for unittesting)
  -man             open web browser on manual page
  -map             generate linker .map file
  -noboundscheck   no array bounds checking (deprecated, use -boundscheck=off)
  -O               optimize
  -o-              do not write object file
  -od=<directory>  write object & library files to directory
  -of=<filename>   name output file to filename
  -op              preserve source path for output files
  -profile         profile runtime performance of generated code
  -profile=gc      profile runtime allocations
  -release         compile release version
  -shared          generate shared library (DLL)
  -transition=<id> help with language change identified by 'id'
  -transition=?    list all language changes
  -unittest        compile in unit tests
  -v               verbose
  -vcolumns        print character (column) numbers in diagnostics
  -verrors=<num>   limit the number of error messages (0 means unlimited)
  -verrors=spec    show errors from speculative compiles such as __traits(compiles,...)
  -vgc             list all gc allocations including hidden ones
  -vtls            list all variables going into thread local storage
  --version        print compiler version and exit
  -version=<level> compile in version code >= level
  -version=<ident> compile in version code identified by ident
  -w               warnings as errors (compilation will halt)
  -wi              warnings as messages (compilation will continue)
  -X               generate JSON file
  -Xf=<filename>   write JSON file to filename
", FileName.canonicalName(global.inifilename), fpic, m32mscoff);
}

/// DMD-generated module `__entrypoint` where the C main resides
extern (C++) __gshared Module entrypoint = null;
/// Module in which the D main is
extern (C++) __gshared Module rootHasMain = null;


/**
 * Generate C main() in response to seeing D main().
 *
 * This function will generate a module called `__entrypoint`,
 * and set the globals `entrypoint` and `rootHasMain`.
 *
 * This used to be in druntime, but contained a reference to _Dmain
 * which didn't work when druntime was made into a dll and was linked
 * to a program, such as a C++ program, that didn't have a _Dmain.
 *
 * Params:
 *   sc = Scope which triggered the generation of the C main,
 *        used to get the module where the D main is.
 */
extern (C++) void genCmain(Scope* sc)
{
    if (entrypoint)
        return;
    /* The D code to be generated is provided as D source code in the form of a string.
     * Note that Solaris, for unknown reasons, requires both a main() and an _main()
     */
    immutable cmaincode =
    q{
        extern(C)
        {
            int _d_run_main(int argc, char **argv, void* mainFunc);
            int _Dmain(char[][] args);
            int main(int argc, char **argv)
            {
                return _d_run_main(argc, argv, &_Dmain);
            }
            version (Solaris) int _main(int argc, char** argv) { return main(argc, argv); }
        }
    };
    Identifier id = Id.entrypoint;
    auto m = new Module("__entrypoint.d", id, 0, 0);
    scope Parser p = new Parser(m, cmaincode, false);
    p.scanloc = Loc();
    p.nextToken();
    m.members = p.parseModule();
    assert(p.token.value == TOKeof);
    assert(!p.errors); // shouldn't have failed to parse it
    bool v = global.params.verbose;
    global.params.verbose = false;
    m.importedFrom = m;
    m.importAll(null);
    m.semantic(null);
    m.semantic2(null);
    m.semantic3(null);
    global.params.verbose = v;
    entrypoint = m;
    rootHasMain = sc._module;
}


/**
 * DMD's real entry point
 *
 * Parses command line arguments and config file, open and read all
 * provided source file and do semantic analysis on them.
 *
 * Params:
 *   argc = Number of arguments passed via command line
 *   argv = Array of string arguments passed via command line
 *
 * Returns:
 *   Application return code
 */
private int tryMain(size_t argc, const(char)** argv)
{
    Strings files;
    Strings libmodules;
    global._init();
    debug
    {
        printf("DMD %s DEBUG\n", global._version);
        fflush(stdout); // avoid interleaving with stderr output when redirecting
    }
    // Check for malformed input
    if (argc < 1 || !argv)
    {
    Largs:
        error(Loc(), "missing or null command line arguments");
        fatal();
    }
    // Convert argc/argv into arguments[] for easier handling
    Strings arguments;
    arguments.setDim(argc);
    for (size_t i = 0; i < argc; i++)
    {
        if (!argv[i])
            goto Largs;
        arguments[i] = argv[i];
    }
    if (response_expand(&arguments)) // expand response files
        error(Loc(), "can't open response file");
    //for (size_t i = 0; i < arguments.dim; ++i) printf("arguments[%d] = '%s'\n", i, arguments[i]);
    files.reserve(arguments.dim - 1);
    // Set default values
    global.params.argv0 = arguments[0];
    global.params.color = isConsoleColorSupported();
    global.params.link = true;
    global.params.useAssert = true;
    global.params.useInvariants = true;
    global.params.useIn = true;
    global.params.useOut = true;
    global.params.useArrayBounds = BOUNDSCHECKdefault; // set correct value later
    global.params.useSwitchError = true;
    global.params.useInline = false;
    global.params.obj = true;
    global.params.useDeprecated = 2;
    global.params.hdrStripPlainFunctions = true;
    global.params.linkswitches = new Strings();
    global.params.libfiles = new Strings();
    global.params.dllfiles = new Strings();
    global.params.objfiles = new Strings();
    global.params.ddocfiles = new Strings();
    // Default to -m32 for 32 bit dmd, -m64 for 64 bit dmd
    global.params.is64bit = (size_t.sizeof == 8);
    global.params.mscoff = false;

    // Temporary: Use 32 bits as the default on Windows, for config parsing
    static if (TARGET_WINDOS)
        global.params.is64bit = false;

    global.inifilename = parse_conf_arg(&arguments);
    if (global.inifilename)
    {
        // can be empty as in -conf=
        if (strlen(global.inifilename) && !FileName.exists(global.inifilename))
            error(Loc(), "Config file '%s' does not exist.", global.inifilename);
    }
    else
    {
        version (Windows)
        {
            global.inifilename = findConfFile(global.params.argv0, "sc.ini");
        }
        else version (Posix)
        {
            global.inifilename = findConfFile(global.params.argv0, "dmd.conf");
        }
        else
        {
            static assert(0, "fix this");
        }
    }
    // Read the configurarion file
    auto inifile = File(global.inifilename);
    inifile.read();
    /* Need path of configuration file, for use in expanding @P macro
     */
    const(char)* inifilepath = FileName.path(global.inifilename);
    Strings sections;
    StringTable environment;
    environment._init(7);
    /* Read the [Environment] section, so we can later
     * pick up any DFLAGS settings.
     */
    sections.push("Environment");
    parseConfFile(&environment, global.inifilename, inifilepath, inifile.len, inifile.buffer, &sections);
    Strings dflags;
    getenv_setargv(readFromEnv(&environment, "DFLAGS"), &dflags);
    environment.reset(7); // erase cached environment updates
    const(char)* arch = global.params.is64bit ? "64" : "32"; // use default
    arch = parse_arch_arg(&arguments, arch);
    arch = parse_arch_arg(&dflags, arch);
    bool is64bit = arch[0] == '6';
    char[80] envsection;
    sprintf(envsection.ptr, "Environment%s", arch);
    sections.push(envsection.ptr);
    parseConfFile(&environment, global.inifilename, inifilepath, inifile.len, inifile.buffer, &sections);
    getenv_setargv(readFromEnv(&environment, "DFLAGS"), &arguments);
    updateRealEnvironment(&environment);
    environment.reset(1); // don't need environment cache any more
    version (none)
    {
        for (size_t i = 0; i < arguments.dim; i++)
        {
            printf("arguments[%d] = '%s'\n", i, arguments[i]);
        }
    }
    for (size_t i = 1; i < arguments.dim; i++)
    {
        const(char)* p = arguments[i];
        if (*p == '-')
        {
            if (strcmp(p + 1, "allinst") == 0)
                global.params.allInst = true;
            else if (strcmp(p + 1, "de") == 0)
                global.params.useDeprecated = 0;
            else if (strcmp(p + 1, "d") == 0)
                global.params.useDeprecated = 1;
            else if (strcmp(p + 1, "dw") == 0)
                global.params.useDeprecated = 2;
            else if (strcmp(p + 1, "c") == 0)
                global.params.link = false;
            else if (memcmp(p + 1, cast(char*)"color", 5) == 0)
            {
                global.params.color = true;
                // Parse:
                //      -color
                //      -color=on|off
                if (p[6] == '=')
                {
                    if (strcmp(p + 7, "off") == 0)
                        global.params.color = false;
                    else if (strcmp(p + 7, "on") != 0)
                        goto Lerror;
                }
                else if (p[6])
                    goto Lerror;
            }
            else if (memcmp(p + 1, cast(char*)"conf=", 5) == 0)
            {
                // ignore, already handled above
            }
            else if (memcmp(p + 1, cast(char*)"cov", 3) == 0)
            {
                global.params.cov = true;
                // Parse:
                //      -cov
                //      -cov=nnn
                if (p[4] == '=')
                {
                    if (isdigit(cast(char)p[5]))
                    {
                        long percent;
                        errno = 0;
                        percent = strtol(p + 5, cast(char**)&p, 10);
                        if (*p || errno || percent > 100)
                            goto Lerror;
                        global.params.covPercent = cast(ubyte)percent;
                    }
                    else
                        goto Lerror;
                }
                else if (p[4])
                    goto Lerror;
            }
            else if (strcmp(p + 1, "shared") == 0)
                global.params.dll = true;
            else if (strcmp(p + 1, "dylib") == 0)
            {
                static if (TARGET_OSX)
                {
                    Loc loc;
                    deprecation(loc, "use -shared instead of -dylib");
                    global.params.dll = true;
                }
                else
                {
                    goto Lerror;
                }
            }
            else if (strcmp(p + 1, "fPIC") == 0)
            {
                static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
                {
                    global.params.pic = 1;
                }
                else
                {
                    goto Lerror;
                }
            }
            else if (strcmp(p + 1, "map") == 0)
                global.params.map = true;
            else if (strcmp(p + 1, "multiobj") == 0)
                global.params.multiobj = true;
            else if (strcmp(p + 1, "g") == 0)
                global.params.symdebug = 1;
            else if (strcmp(p + 1, "gc") == 0)
                global.params.symdebug = 2;
            else if (strcmp(p + 1, "gs") == 0)
                global.params.alwaysframe = true;
            else if (strcmp(p + 1, "gx") == 0)
                global.params.stackstomp = true;
            else if (strcmp(p + 1, "gt") == 0)
            {
                error(Loc(), "use -profile instead of -gt");
                global.params.trace = true;
            }
            else if (strcmp(p + 1, "m32") == 0)
            {
                global.params.is64bit = false;
                global.params.mscoff = false;
            }
            else if (strcmp(p + 1, "m64") == 0)
            {
                global.params.is64bit = true;
                static if (TARGET_WINDOS)
                {
                    global.params.mscoff = true;
                }
            }
            else if (strcmp(p + 1, "m32mscoff") == 0)
            {
                static if (TARGET_WINDOS)
                {
                    global.params.is64bit = 0;
                    global.params.mscoff = true;
                }
                else
                {
                    error(Loc(), "-m32mscoff can only be used on windows");
                }
            }
            else if (memcmp(p + 1, cast(char*)"profile", 7) == 0)
            {
                // Parse:
                //      -profile
                //      -profile=gc
                if (p[8] == '=')
                {
                    if (strcmp(p + 9, "gc") == 0)
                        global.params.tracegc = true;
                    else
                        goto Lerror;
                }
                else if (p[8])
                    goto Lerror;
                else
                    global.params.trace = true;
            }
            else if (strcmp(p + 1, "v") == 0)
                global.params.verbose = true;
            else if (strcmp(p + 1, "vtls") == 0)
                global.params.vtls = true;
            else if (strcmp(p + 1, "vcolumns") == 0)
                global.params.showColumns = true;
            else if (strcmp(p + 1, "vgc") == 0)
                global.params.vgc = true;
            else if (memcmp(p + 1, cast(char*)"verrors", 7) == 0)
            {
                if (p[8] == '=' && isdigit(cast(char)p[9]))
                {
                    long num;
                    errno = 0;
                    num = strtol(p + 9, cast(char**)&p, 10);
                    if (*p || errno || num > INT_MAX)
                        goto Lerror;
                    global.errorLimit = cast(uint)num;
                }
                else if (memcmp(p + 9, cast(char*)"spec", 4) == 0)
                {
                    global.params.showGaggedErrors = true;
                }
                else
                    goto Lerror;
            }
            else if (memcmp(p + 1, cast(char*)"transition", 10) == 0)
            {
                // Parse:
                //      -transition=number
                if (p[11] == '=')
                {
                    if (strcmp(p + 12, "?") == 0)
                    {
                        printf("
Language changes listed by -transition=id:
  =all           list information on all language changes
  =checkimports  give deprecation messages about 10378 anomalies
  =complex,14488 list all usages of complex or imaginary types
  =field,3449    list all non-mutable fields which occupy an object instance
  =import,10378  revert to single phase name lookup
  =safe          shows places with hidden change in semantics needed for better @safe checking
  =tls           list all variables going into thread local storage
");
                        exit(EXIT_SUCCESS);
                    }
                    if (isdigit(cast(char)p[12]))
                    {
                        long num;
                        errno = 0;
                        num = strtol(p + 12, cast(char**)&p, 10);
                        if (*p || errno || num > INT_MAX)
                            goto Lerror;
                        // Bugzilla issue number
                        switch (num)
                        {
                        case 3449:
                            global.params.vfield = true;
                            break;
                        case 10378:
                            global.params.bug10378 = true;
                            break;
                        case 14488:
                            global.params.vcomplex = true;
                            break;
                        default:
                            goto Lerror;
                        }
                    }
                    else if (Identifier.isValidIdentifier(p + 12))
                    {
                        const ident = p + 12;
                        switch (ident[0 .. strlen(ident)])
                        {
                        case "all":
                            global.params.vtls = true;
                            global.params.vfield = true;
                            global.params.vcomplex = true;
                            break;
                        case "checkimports":
                            global.params.check10378 = true;
                            break;
                        case "complex":
                            global.params.vcomplex = true;
                            break;
                        case "field":
                            global.params.vfield = true;
                            break;
                        case "import":
                            global.params.bug10378 = true;
                            break;
                        case "safe":
                            global.params.safe = true;
                            global.params.useDIP25 = true;
                            break;
                        case "tls":
                            global.params.vtls = true;
                            break;
                        default:
                            goto Lerror;
                        }
                    }
                    else
                        goto Lerror;
                }
                else
                    goto Lerror;
            }
            else if (strcmp(p + 1, "w") == 0)
                global.params.warnings = 1;
            else if (strcmp(p + 1, "wi") == 0)
                global.params.warnings = 2;
            else if (strcmp(p + 1, "O") == 0)
                global.params.optimize = true;
            else if (p[1] == 'o')
            {
                const(char)* path;
                switch (p[2])
                {
                case '-':
                    global.params.obj = false;
                    break;
                case 'd':
                    if (!p[3])
                        goto Lnoarg;
                    path = p + 3 + (p[3] == '=');
                    version (Windows)
                    {
                        path = toWinPath(path);
                    }
                    global.params.objdir = path;
                    break;
                case 'f':
                    if (!p[3])
                        goto Lnoarg;
                    path = p + 3 + (p[3] == '=');
                    version (Windows)
                    {
                        path = toWinPath(path);
                    }
                    global.params.objname = path;
                    break;
                case 'p':
                    if (p[3])
                        goto Lerror;
                    global.params.preservePaths = true;
                    break;
                case 0:
                    error(Loc(), "-o no longer supported, use -of or -od");
                    break;
                default:
                    goto Lerror;
                }
            }
            else if (p[1] == 'D')
            {
                global.params.doDocComments = true;
                switch (p[2])
                {
                case 'd':
                    if (!p[3])
                        goto Lnoarg;
                    global.params.docdir = p + 3 + (p[3] == '=');
                    break;
                case 'f':
                    if (!p[3])
                        goto Lnoarg;
                    global.params.docname = p + 3 + (p[3] == '=');
                    break;
                case 0:
                    break;
                default:
                    goto Lerror;
                }
            }
            else if (p[1] == 'H')
            {
                global.params.doHdrGeneration = true;
                switch (p[2])
                {
                case 'd':
                    if (!p[3])
                        goto Lnoarg;
                    global.params.hdrdir = p + 3 + (p[3] == '=');
                    break;
                case 'f':
                    if (!p[3])
                        goto Lnoarg;
                    global.params.hdrname = p + 3 + (p[3] == '=');
                    break;
                case 0:
                    break;
                default:
                    goto Lerror;
                }
            }
            else if (p[1] == 'X')
            {
                global.params.doJsonGeneration = true;
                switch (p[2])
                {
                case 'f':
                    if (!p[3])
                        goto Lnoarg;
                    global.params.jsonfilename = p + 3 + (p[3] == '=');
                    break;
                case 0:
                    break;
                default:
                    goto Lerror;
                }
            }
            else if (strcmp(p + 1, "ignore") == 0)
                global.params.ignoreUnsupportedPragmas = true;
            else if (strcmp(p + 1, "property") == 0)
                global.params.enforcePropertySyntax = true;
            else if (strcmp(p + 1, "inline") == 0)
            {
                global.params.useInline = true;
                global.params.hdrStripPlainFunctions = false;
            }
            else if (strcmp(p + 1, "dip25") == 0)
                global.params.useDIP25 = true;
            else if (strcmp(p + 1, "lib") == 0)
                global.params.lib = true;
            else if (strcmp(p + 1, "nofloat") == 0)
                global.params.nofloat = true;
            else if (strcmp(p + 1, "quiet") == 0)
            {
                // Ignore
            }
            else if (strcmp(p + 1, "release") == 0)
                global.params.release = true;
            else if (strcmp(p + 1, "betterC") == 0)
                global.params.betterC = true;
            else if (strcmp(p + 1, "noboundscheck") == 0)
            {
                global.params.useArrayBounds = BOUNDSCHECKoff;
            }
            else if (memcmp(p + 1, cast(char*)"boundscheck", 11) == 0)
            {
                // Parse:
                //      -boundscheck=[on|safeonly|off]
                if (p[12] == '=')
                {
                    if (strcmp(p + 13, "on") == 0)
                    {
                        global.params.useArrayBounds = BOUNDSCHECKon;
                    }
                    else if (strcmp(p + 13, "safeonly") == 0)
                    {
                        global.params.useArrayBounds = BOUNDSCHECKsafeonly;
                    }
                    else if (strcmp(p + 13, "off") == 0)
                    {
                        global.params.useArrayBounds = BOUNDSCHECKoff;
                    }
                    else
                        goto Lerror;
                }
                else
                    goto Lerror;
            }
            else if (strcmp(p + 1, "unittest") == 0)
                global.params.useUnitTests = true;
            else if (p[1] == 'I')
            {
                if (!global.params.imppath)
                    global.params.imppath = new Strings();
                global.params.imppath.push(p + 2 + (p[2] == '='));
            }
            else if (p[1] == 'J')
            {
                if (!global.params.fileImppath)
                    global.params.fileImppath = new Strings();
                global.params.fileImppath.push(p + 2 + (p[2] == '='));
            }
            else if (memcmp(p + 1, cast(char*)"debug", 5) == 0 && p[6] != 'l')
            {
                // Parse:
                //      -debug
                //      -debug=number
                //      -debug=identifier
                if (p[6] == '=')
                {
                    if (isdigit(cast(char)p[7]))
                    {
                        long level;
                        errno = 0;
                        level = strtol(p + 7, cast(char**)&p, 10);
                        if (*p || errno || level > INT_MAX)
                            goto Lerror;
                        DebugCondition.setGlobalLevel(cast(int)level);
                    }
                    else if (Identifier.isValidIdentifier(p + 7))
                        DebugCondition.addGlobalIdent(p[7 .. p.strlen]);
                    else
                        goto Lerror;
                }
                else if (p[6])
                    goto Lerror;
                else
                    DebugCondition.setGlobalLevel(1);
            }
            else if (memcmp(p + 1, cast(char*)"version", 7) == 0)
            {
                // Parse:
                //      -version=number
                //      -version=identifier
                if (p[8] == '=')
                {
                    if (isdigit(cast(char)p[9]))
                    {
                        long level;
                        errno = 0;
                        level = strtol(p + 9, cast(char**)&p, 10);
                        if (*p || errno || level > INT_MAX)
                            goto Lerror;
                        VersionCondition.setGlobalLevel(cast(int)level);
                    }
                    else if (Identifier.isValidIdentifier(p + 9))
                        VersionCondition.addGlobalIdent(p[9 .. p.strlen]);
                    else
                        goto Lerror;
                }
                else
                    goto Lerror;
            }
            else if (strcmp(p + 1, "-b") == 0)
                global.params.debugb = true;
            else if (strcmp(p + 1, "-c") == 0)
                global.params.debugc = true;
            else if (strcmp(p + 1, "-f") == 0)
                global.params.debugf = true;
            else if (strcmp(p + 1, "-help") == 0 || strcmp(p + 1, "h") == 0)
            {
                usage();
                exit(EXIT_SUCCESS);
            }
            else if (strcmp(p + 1, "-r") == 0)
                global.params.debugr = true;
            else if (strcmp(p + 1, "-version") == 0)
            {
                logo();
                exit(EXIT_SUCCESS);
            }
            else if (strcmp(p + 1, "-x") == 0)
                global.params.debugx = true;
            else if (strcmp(p + 1, "-y") == 0)
                global.params.debugy = true;
            else if (p[1] == 'L')
            {
                global.params.linkswitches.push(p + 2 + (p[2] == '='));
            }
            else if (memcmp(p + 1, cast(char*)"defaultlib=", 11) == 0)
            {
                global.params.defaultlibname = p + 1 + 11;
            }
            else if (memcmp(p + 1, cast(char*)"debuglib=", 9) == 0)
            {
                global.params.debuglibname = p + 1 + 9;
            }
            else if (memcmp(p + 1, cast(char*)"deps", 4) == 0)
            {
                if (global.params.moduleDeps)
                {
                    error(Loc(), "-deps[=file] can only be provided once!");
                    break;
                }
                if (p[5] == '=')
                {
                    global.params.moduleDepsFile = p + 1 + 5;
                    if (!global.params.moduleDepsFile[0])
                        goto Lnoarg;
                }
                else if (p[5] != '\0')
                {
                    // Else output to stdout.
                    goto Lerror;
                }
                global.params.moduleDeps = new OutBuffer();
            }
            else if (strcmp(p + 1, "main") == 0)
            {
                global.params.addMain = true;
            }
            else if (memcmp(p + 1, cast(char*)"man", 3) == 0)
            {
                version (Windows)
                {
                    browse("http://dlang.org/dmd-windows.html");
                }
                version (linux)
                {
                    browse("http://dlang.org/dmd-linux.html");
                }
                version (OSX)
                {
                    browse("http://dlang.org/dmd-osx.html");
                }
                version (FreeBSD)
                {
                    browse("http://dlang.org/dmd-freebsd.html");
                }
                version (OpenBSD)
                {
                    browse("http://dlang.org/dmd-openbsd.html");
                }
                exit(EXIT_SUCCESS);
            }
            else if (strcmp(p + 1, "run") == 0)
            {
                global.params.run = true;
                size_t length = argc - i - 1;
                if (length)
                {
                    const(char)* ext = FileName.ext(arguments[i + 1]);
                    if (ext && FileName.equals(ext, "d") == 0 && FileName.equals(ext, "di") == 0)
                    {
                        error(Loc(), "-run must be followed by a source file, not '%s'", arguments[i + 1]);
                        break;
                    }
                    files.push(arguments[i + 1]);
                    global.params.runargs.setDim(length - 1);
                    for (size_t j = 0; j < length - 1; ++j)
                    {
                        global.params.runargs[j] = arguments[i + 2 + j];
                    }
                    i += length;
                }
                else
                {
                    global.params.run = false;
                    goto Lnoarg;
                }
            }
            else
            {
            Lerror:
                error(Loc(), "unrecognized switch '%s'", arguments[i]);
                continue;
            Lnoarg:
                error(Loc(), "argument expected for switch '%s'", arguments[i]);
                continue;
            }
        }
        else
        {
            static if (TARGET_WINDOS)
            {
                const(char)* ext = FileName.ext(p);
                if (ext && FileName.compare(ext, "exe") == 0)
                {
                    global.params.objname = p;
                    continue;
                }
                if (strcmp(p, `/?`) == 0)
                {
                    usage();
                    exit(EXIT_SUCCESS);
                }
            }
            files.push(p);
        }
    }
    if (global.params.is64bit != is64bit)
        error(Loc(), "the architecture must not be changed in the %s section of %s", envsection.ptr, global.inifilename);
    if (global.params.enforcePropertySyntax)
    {
        /*NOTE: -property used to disallow calling non-properties
         without parentheses. This behaviour has fallen from grace.
         Phobos dropped support for it while dmd still recognized it, so
         that the switch has effectively not been supported. Time to
         remove it from dmd.
         Step 1 (2.069): Deprecate -property and ignore it. */
        Loc loc;
        deprecation(loc, "The -property switch is deprecated and has no " ~
            "effect anymore.");
        /* Step 2: Remove -property. Throw an error when it's set.
         Do this by removing global.params.enforcePropertySyntax and the code
         above that sets it. Let it be handled as an unrecognized switch.
         Step 3: Possibly reintroduce -property with different semantics.
         Any new semantics need to be decided on first. */
    }
    // Target uses 64bit pointers.
    global.params.isLP64 = global.params.is64bit;
    if (global.errors)
    {
        fatal();
    }
    if (files.dim == 0)
    {
        usage();
        return EXIT_FAILURE;
    }
    static if (TARGET_OSX)
    {
        global.params.pic = 1;
    }
    static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
    {
        if (global.params.lib && global.params.dll)
            error(Loc(), "cannot mix -lib and -shared");
    }
    if (global.params.useArrayBounds == BOUNDSCHECKdefault)
    {
        // Set the real default value
        global.params.useArrayBounds = global.params.release ? BOUNDSCHECKsafeonly : BOUNDSCHECKon;
    }
    if (global.params.release)
    {
        global.params.useInvariants = false;
        global.params.useIn = false;
        global.params.useOut = false;
        global.params.useAssert = false;
        global.params.useSwitchError = false;
    }
    if (global.params.useUnitTests)
        global.params.useAssert = true;
    if (!global.params.obj || global.params.lib)
        global.params.link = false;
    if (global.params.link)
    {
        global.params.exefile = global.params.objname;
        global.params.oneobj = true;
        if (global.params.objname)
        {
            /* Use this to name the one object file with the same
             * name as the exe file.
             */
            global.params.objname = cast(char*)FileName.forceExt(global.params.objname, global.obj_ext);
            /* If output directory is given, use that path rather than
             * the exe file path.
             */
            if (global.params.objdir)
            {
                const(char)* name = FileName.name(global.params.objname);
                global.params.objname = cast(char*)FileName.combine(global.params.objdir, name);
            }
        }
    }
    else if (global.params.run)
    {
        error(Loc(), "flags conflict with -run");
        fatal();
    }
    else if (global.params.lib)
    {
        global.params.libname = global.params.objname;
        global.params.objname = null;
        // Haven't investigated handling these options with multiobj
        if (!global.params.cov && !global.params.trace)
            global.params.multiobj = true;
    }
    else
    {
        if (global.params.objname && files.dim > 1)
        {
            global.params.oneobj = true;
            //error("multiple source files, but only one .obj name");
            //fatal();
        }
    }

    // Predefined version identifiers
    addDefaultVersionIdentifiers();
    objc_tryMain_dObjc();

    setDefaultLibrary();

    // Initialization
    Type._init();
    Id.initialize();
    Module._init();
    Target._init();
    Expression._init();
    objc_tryMain_init();
    builtin_init();

    if (global.params.verbose)
    {
        fprintf(global.stdmsg, "binary    %s\n", global.params.argv0);
        fprintf(global.stdmsg, "version   %s\n", global._version);
        fprintf(global.stdmsg, "config    %s\n", global.inifilename ? global.inifilename : "(none)");
    }
    //printf("%d source files\n",files.dim);
    // Build import search path
    if (global.params.imppath)
    {
        for (size_t i = 0; i < global.params.imppath.dim; i++)
        {
            const(char)* path = (*global.params.imppath)[i];
            Strings* a = FileName.splitPath(path);
            if (a)
            {
                if (!global.path)
                    global.path = new Strings();
                global.path.append(a);
            }
        }
    }
    // Build string import search path
    if (global.params.fileImppath)
    {
        for (size_t i = 0; i < global.params.fileImppath.dim; i++)
        {
            const(char)* path = (*global.params.fileImppath)[i];
            Strings* a = FileName.splitPath(path);
            if (a)
            {
                if (!global.filePath)
                    global.filePath = new Strings();
                global.filePath.append(a);
            }
        }
    }
    if (global.params.addMain)
    {
        files.push(cast(char*)global.main_d); // a dummy name, we never actually look up this file
    }
    // Create Modules
    Modules modules;
    modules.reserve(files.dim);
    bool firstmodule = true;
    for (size_t i = 0; i < files.dim; i++)
    {
        const(char)* name;
        version (Windows)
        {
            files[i] = toWinPath(files[i]);
        }
        const(char)* p = files[i];
        p = FileName.name(p); // strip path
        const(char)* ext = FileName.ext(p);
        char* newname;
        if (ext)
        {
            /* Deduce what to do with a file based on its extension
             */
            if (FileName.equals(ext, global.obj_ext))
            {
                global.params.objfiles.push(files[i]);
                libmodules.push(files[i]);
                continue;
            }
            if (FileName.equals(ext, global.lib_ext))
            {
                global.params.libfiles.push(files[i]);
                libmodules.push(files[i]);
                continue;
            }
            static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
            {
                if (FileName.equals(ext, global.dll_ext))
                {
                    global.params.dllfiles.push(files[i]);
                    libmodules.push(files[i]);
                    continue;
                }
            }
            if (strcmp(ext, global.ddoc_ext) == 0)
            {
                global.params.ddocfiles.push(files[i]);
                continue;
            }
            if (FileName.equals(ext, global.json_ext))
            {
                global.params.doJsonGeneration = true;
                global.params.jsonfilename = files[i];
                continue;
            }
            if (FileName.equals(ext, global.map_ext))
            {
                global.params.mapfile = files[i];
                continue;
            }
            static if (TARGET_WINDOS)
            {
                if (FileName.equals(ext, "res"))
                {
                    global.params.resfile = files[i];
                    continue;
                }
                if (FileName.equals(ext, "def"))
                {
                    global.params.deffile = files[i];
                    continue;
                }
                if (FileName.equals(ext, "exe"))
                {
                    assert(0); // should have already been handled
                }
            }
            /* Examine extension to see if it is a valid
             * D source file extension
             */
            if (FileName.equals(ext, global.mars_ext) || FileName.equals(ext, global.hdr_ext) || FileName.equals(ext, "dd"))
            {
                ext--; // skip onto '.'
                assert(*ext == '.');
                newname = cast(char*)mem.xmalloc((ext - p) + 1);
                memcpy(newname, p, ext - p);
                newname[ext - p] = 0; // strip extension
                name = newname;
                if (name[0] == 0 || strcmp(name, "..") == 0 || strcmp(name, ".") == 0)
                {
                Linvalid:
                    error(Loc(), "invalid file name '%s'", files[i]);
                    fatal();
                }
            }
            else
            {
                error(Loc(), "unrecognized file extension %s", ext);
                fatal();
            }
        }
        else
        {
            name = p;
            if (!*name)
                goto Linvalid;
        }
        /* At this point, name is the D source file name stripped of
         * its path and extension.
         */
        auto id = Identifier.idPool(name, strlen(name));
        auto m = new Module(files[i], id, global.params.doDocComments, global.params.doHdrGeneration);
        modules.push(m);
        if (firstmodule)
        {
            global.params.objfiles.push(m.objfile.name.str);
            firstmodule = false;
        }
    }
    // Read files
    /* Start by "reading" the dummy main.d file
     */
    if (global.params.addMain)
    {
        for (size_t i = 0; 1; i++)
        {
            assert(i != modules.dim);
            Module m = modules[i];
            if (strcmp(m.srcfile.name.str, global.main_d) == 0)
            {
                static __gshared const(char)* buf = "int main(){return 0;}";
                m.srcfile.setbuffer(cast(void*)buf, buf.sizeof);
                m.srcfile._ref = 1;
                break;
            }
        }
    }
    enum ASYNCREAD = false;
    static if (ASYNCREAD)
    {
        // Multi threaded
        AsyncRead* aw = AsyncRead.create(modules.dim);
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module m = modules[i];
            aw.addFile(m.srcfile);
        }
        aw.start();
    }
    else
    {
        // Single threaded
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module m = modules[i];
            m.read(Loc());
        }
    }
    // Parse files
    bool anydocfiles = false;
    size_t filecount = modules.dim;
    for (size_t filei = 0, modi = 0; filei < filecount; filei++, modi++)
    {
        Module m = modules[modi];
        if (global.params.verbose)
            fprintf(global.stdmsg, "parse     %s\n", m.toChars());
        if (!Module.rootModule)
            Module.rootModule = m;
        m.importedFrom = m; // m->isRoot() == true
        if (!global.params.oneobj || modi == 0 || m.isDocFile)
            m.deleteObjFile();
        static if (ASYNCREAD)
        {
            if (aw.read(filei))
            {
                error(Loc(), "cannot read file %s", m.srcfile.name.toChars());
                fatal();
            }
        }
        m.parse();
        if (m.isDocFile)
        {
            anydocfiles = true;
            gendocfile(m);
            // Remove m from list of modules
            modules.remove(modi);
            modi--;
            // Remove m's object file from list of object files
            for (size_t j = 0; j < global.params.objfiles.dim; j++)
            {
                if (m.objfile.name.str == (*global.params.objfiles)[j])
                {
                    global.params.objfiles.remove(j);
                    break;
                }
            }
            if (global.params.objfiles.dim == 0)
                global.params.link = false;
        }
    }
    static if (ASYNCREAD)
    {
        AsyncRead.dispose(aw);
    }
    if (anydocfiles && modules.dim && (global.params.oneobj || global.params.objname))
    {
        error(Loc(), "conflicting Ddoc and obj generation options");
        fatal();
    }
    if (global.errors)
        fatal();

    if (global.params.doHdrGeneration)
    {
        /* Generate 'header' import files.
         * Since 'header' import files must be independent of command
         * line switches and what else is imported, they are generated
         * before any semantic analysis.
         */
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module m = modules[i];
            if (global.params.verbose)
                fprintf(global.stdmsg, "import    %s\n", m.toChars());
            genhdrfile(m);
        }
    }
    if (global.errors)
        fatal();

    // load all unconditional imports for better symbol resolving
    for (size_t i = 0; i < modules.dim; i++)
    {
        Module m = modules[i];
        if (global.params.verbose)
            fprintf(global.stdmsg, "importall %s\n", m.toChars());
        m.importAll(null);
    }
    if (global.errors)
        fatal();

    backend_init();

    // Do semantic analysis
    for (size_t i = 0; i < modules.dim; i++)
    {
        Module m = modules[i];
        if (global.params.verbose)
            fprintf(global.stdmsg, "semantic  %s\n", m.toChars());
        m.semantic(null);
    }
    //if (global.errors)
    //    fatal();
    Module.dprogress = 1;
    Module.runDeferredSemantic();
    if (Module.deferred.dim)
    {
        for (size_t i = 0; i < Module.deferred.dim; i++)
        {
            Dsymbol sd = Module.deferred[i];
            sd.error("unable to resolve forward reference in definition");
        }
        //fatal();
    }

    // Do pass 2 semantic analysis
    for (size_t i = 0; i < modules.dim; i++)
    {
        Module m = modules[i];
        if (global.params.verbose)
            fprintf(global.stdmsg, "semantic2 %s\n", m.toChars());
        m.semantic2(null);
    }
    Module.runDeferredSemantic2();
    if (global.errors)
        fatal();

    // Do pass 3 semantic analysis
    for (size_t i = 0; i < modules.dim; i++)
    {
        Module m = modules[i];
        if (global.params.verbose)
            fprintf(global.stdmsg, "semantic3 %s\n", m.toChars());
        m.semantic3(null);
    }
    Module.runDeferredSemantic3();
    if (global.errors)
        fatal();

    // Scan for functions to inline
    if (global.params.useInline)
    {
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module m = modules[i];
            if (global.params.verbose)
                fprintf(global.stdmsg, "inline scan %s\n", m.toChars());
            inlineScanModule(m);
        }
    }
    // Do not attempt to generate output files if errors or warnings occurred
    if (global.errors || global.warnings)
        fatal();

    // inlineScan incrementally run semantic3 of each expanded functions.
    // So deps file generation should be moved after the inlinig stage.
    if (global.params.moduleDeps)
    {
        OutBuffer* ob = global.params.moduleDeps;
        if (global.params.moduleDepsFile)
        {
            auto deps = File(global.params.moduleDepsFile);
            deps.setbuffer(cast(void*)ob.data, ob.offset);
            writeFile(Loc(), &deps);
        }
        else
            printf("%.*s", cast(int)ob.offset, ob.data);
    }

    printCtfePerformanceStats();

    Library library = null;
    if (global.params.lib)
    {
        library = Library.factory();
        library.setFilename(global.params.objdir, global.params.libname);
        // Add input object and input library files to output library
        for (size_t i = 0; i < libmodules.dim; i++)
        {
            const(char)* p = libmodules[i];
            library.addObject(p, null);
        }
    }
    // Generate output files
    if (global.params.doJsonGeneration)
    {
        OutBuffer buf;
        json_generate(&buf, &modules);
        // Write buf to file
        const(char)* name = global.params.jsonfilename;
        if (name && name[0] == '-' && name[1] == 0)
        {
            // Write to stdout; assume it succeeds
            size_t n = fwrite(buf.data, 1, buf.offset, stdout);
            assert(n == buf.offset); // keep gcc happy about return values
        }
        else
        {
            /* The filename generation code here should be harmonized with Module::setOutfile()
             */
            const(char)* jsonfilename;
            if (name && *name)
            {
                jsonfilename = FileName.defaultExt(name, global.json_ext);
            }
            else
            {
                // Generate json file name from first obj name
                const(char)* n = (*global.params.objfiles)[0];
                n = FileName.name(n);
                //if (!FileName::absolute(name))
                //    name = FileName::combine(dir, name);
                jsonfilename = FileName.forceExt(n, global.json_ext);
            }
            ensurePathToNameExists(Loc(), jsonfilename);
            auto jsonfile = new File(jsonfilename);
            jsonfile.setbuffer(buf.data, buf.offset);
            jsonfile._ref = 1;
            writeFile(Loc(), jsonfile);
        }
    }
    if (!global.errors && global.params.doDocComments)
    {
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module m = modules[i];
            gendocfile(m);
        }
    }
    if (!global.params.obj)
    {
    }
    else if (global.params.oneobj)
    {
        if (modules.dim)
            obj_start(cast(char*)modules[0].srcfile.toChars());
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module m = modules[i];
            if (global.params.verbose)
                fprintf(global.stdmsg, "code      %s\n", m.toChars());
            genObjFile(m, false);
            if (entrypoint && m == rootHasMain)
                genObjFile(entrypoint, false);
        }
        if (!global.errors && modules.dim)
        {
            obj_end(library, modules[0].objfile);
        }
    }
    else
    {
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module m = modules[i];
            if (global.params.verbose)
                fprintf(global.stdmsg, "code      %s\n", m.toChars());
            obj_start(cast(char*)m.srcfile.toChars());
            genObjFile(m, global.params.multiobj);
            if (entrypoint && m == rootHasMain)
                genObjFile(entrypoint, global.params.multiobj);
            obj_end(library, m.objfile);
            obj_write_deferred(library);
            if (global.errors && !global.params.lib)
                m.deleteObjFile();
        }
    }
    if (global.params.lib && !global.errors)
        library.write();
    backend_term();
    if (global.errors)
        fatal();
    int status = EXIT_SUCCESS;
    if (!global.params.objfiles.dim)
    {
        if (global.params.link)
            error(Loc(), "no object files to link");
    }
    else
    {
        if (global.params.link)
            status = runLINK();
        if (global.params.run)
        {
            if (!status)
            {
                status = runProgram();
                /* Delete .obj files and .exe file
                 */
                for (size_t i = 0; i < modules.dim; i++)
                {
                    modules[i].deleteObjFile();
                    if (global.params.oneobj)
                        break;
                }
                remove(global.params.exefile);
            }
        }
    }
    return status;
}


/**
 * Entry point which forwards to `tryMain`.
 *
 * Returns:
 *   Return code of the application
 */
int main()
{
    import core.memory;
    import core.runtime;

    version (GC)
    {
    }
    else
    {
        GC.disable();
    }
    version(D_Coverage)
    {
        // for now we need to manually set the source path
        string dirName(string path, char separator)
        {
            for (size_t i = path.length - 1; i > 0; i--)
            {
                if (path[i] == separator)
                    return path[0..i];
            }
            return path;
        }
        version (Windows)
            enum sourcePath = dirName(__FILE_FULL_PATH__, `\`);
        else
            enum sourcePath = dirName(__FILE_FULL_PATH__, '/');

        dmd_coverSourcePath(sourcePath);
        dmd_coverDestPath(sourcePath);
        dmd_coverSetMerge(true);
    }

    auto args = Runtime.cArgs();
    return tryMain(args.argc, cast(const(char)**)args.argv);
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
private void getenv_setargv(const(char)* envvalue, Strings* args)
{
    if (!envvalue)
        return;
    char* p;
    int instring;
    int slash;
    char c;
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
            args.push(env); // append
            p = env;
            slash = 0;
            instring = 0;
            c = 0;
            while (1)
            {
                c = *env++;
                switch (c)
                {
                case '"':
                    p -= (slash >> 1);
                    if (slash & 1)
                    {
                        p--;
                        goto Laddc;
                    }
                    instring ^= 1;
                    slash = 0;
                    continue;
                case ' ':
                case '\t':
                    if (instring)
                        goto Laddc;
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
                Laddc:
                    slash = 0;
                    *p++ = c;
                    continue;
                }
                break;
            }
        }
    }
}

/**
 * Parse command line arguments for -m32 or -m64
 * to detect the desired architecture.
 *
 * Params:
 *   args = Command line arguments
 *   arch = Default value to use for architecture.
 *          Should be "32" or "64"
 *
 * Returns:
 *   "32", "64" or "32mscoff" if the "-m32", "-m64", "-m32mscoff" flags were passed,
 *   respectively. If they weren't, return `arch`.
 */
private const(char)* parse_arch_arg(Strings* args, const(char)* arch)
{
    for (size_t i = 0; i < args.dim; ++i)
    {
        const(char)* p = (*args)[i];
        if (p[0] == '-')
        {
            if (strcmp(p + 1, "m32") == 0 || strcmp(p + 1, "m32mscoff") == 0 || strcmp(p + 1, "m64") == 0)
                arch = p + 2;
            else if (strcmp(p + 1, "run") == 0)
                break;
        }
    }
    return arch;
}


/**
 * Parse command line arguments for -conf=path.
 *
 * Params:
 *   args = Command line arguments
 *
 * Returns:
 *   Path to the config file to use
 */
private const(char)* parse_conf_arg(Strings* args)
{
    const(char)* conf = null;
    for (size_t i = 0; i < args.dim; ++i)
    {
        const(char)* p = (*args)[i];
        if (p[0] == '-')
        {
            if (strncmp(p + 1, "conf=", 5) == 0)
                conf = p + 6;
            else if (strcmp(p + 1, "run") == 0)
                break;
        }
    }
    return conf;
}


/**
 * Helper function used by the glue layer
 *
 * Returns:
 *   A new array of Dsymbol
 */
extern (C++) Dsymbols* Dsymbols_create()
{
    return new Dsymbols();
}


/**
 * Helper function used by the glue layer
 *
 * Returns:
 *   A new array of VarDeclaration
 */
extern (C++) VarDeclarations* VarDeclarations_create()
{
    return new VarDeclarations();
}


/**
 * Helper function used by the glue layer
 *
 * Returns:
 *   A new array of Expression
 */
extern (C++) Expressions* Expressions_create()
{
    return new Expressions();
}

/**
 * Set the default and debug libraries to link against, if not already set
 *
 * Must be called after argument parsing is done, as it won't
 * override any value.
 * Note that if `-defaultlib=` or `-debuglib=` was used,
 * we don't override that either.
 */
private void setDefaultLibrary()
{
    if (global.params.defaultlibname is null)
    {
        static if (TARGET_WINDOS)
        {
            if (global.params.is64bit)
                global.params.defaultlibname = "phobos64";
            else if (global.params.mscoff)
                global.params.defaultlibname = "phobos32mscoff";
            else
                global.params.defaultlibname = "phobos";
        }
        else static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
        {
            global.params.defaultlibname = "libphobos2.a";
        }
        else static if (TARGET_OSX)
        {
            global.params.defaultlibname = "phobos2";
        }
        else
        {
            static assert(0, "fix this");
        }
    }
    if (global.params.debuglibname is null)
        global.params.debuglibname = global.params.defaultlibname;
}


/**
 * Add default `version` identifier for ddmd, and set the
 * target platform in `global`.
 *
 * Needs to be run after all arguments parsing (command line, DFLAGS environment
 * variable and config file) in order to add final flags (such as `X86_64` or
 * the `CRuntime` used).
 */
private void addDefaultVersionIdentifiers()
{
    VersionCondition.addPredefinedGlobalIdent("DigitalMars");
    static if (TARGET_WINDOS)
    {
        VersionCondition.addPredefinedGlobalIdent("Windows");
        global.params.isWindows = true;
    }
    else static if (TARGET_LINUX)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("linux");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isLinux = true;
    }
    else static if (TARGET_OSX)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("OSX");
        global.params.isOSX = true;
        // For legacy compatibility
        VersionCondition.addPredefinedGlobalIdent("darwin");
    }
    else static if (TARGET_FREEBSD)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("FreeBSD");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isFreeBSD = true;
    }
    else static if (TARGET_OPENBSD)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("OpenBSD");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isOpenBSD = true;
    }
    else static if (TARGET_SOLARIS)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("Solaris");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isSolaris = true;
    }
    else
    {
        static assert(0, "fix this");
    }
    VersionCondition.addPredefinedGlobalIdent("LittleEndian");
    VersionCondition.addPredefinedGlobalIdent("D_Version2");
    VersionCondition.addPredefinedGlobalIdent("all");

    if (global.params.is64bit)
    {
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86_64");
        VersionCondition.addPredefinedGlobalIdent("X86_64");
        VersionCondition.addPredefinedGlobalIdent("D_SIMD");
        static if (TARGET_WINDOS)
        {
            VersionCondition.addPredefinedGlobalIdent("Win64");
        }
    }
    else
    {
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm"); //legacy
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86");
        VersionCondition.addPredefinedGlobalIdent("X86");
        static if (TARGET_OSX)
        {
            VersionCondition.addPredefinedGlobalIdent("D_SIMD");
        }
        static if (TARGET_WINDOS)
        {
            VersionCondition.addPredefinedGlobalIdent("Win32");
        }
    }
    static if (TARGET_WINDOS)
    {
        if (global.params.mscoff)
            VersionCondition.addPredefinedGlobalIdent("CRuntime_Microsoft");
        else
            VersionCondition.addPredefinedGlobalIdent("CRuntime_DigitalMars");
    }
    else static if (TARGET_LINUX)
    {
        VersionCondition.addPredefinedGlobalIdent("CRuntime_Glibc");
    }

    if (global.params.isLP64)
        VersionCondition.addPredefinedGlobalIdent("D_LP64");
    if (global.params.doDocComments)
        VersionCondition.addPredefinedGlobalIdent("D_Ddoc");
    if (global.params.cov)
        VersionCondition.addPredefinedGlobalIdent("D_Coverage");
    if (global.params.pic)
        VersionCondition.addPredefinedGlobalIdent("D_PIC");
    if (global.params.useUnitTests)
        VersionCondition.addPredefinedGlobalIdent("unittest");
    if (global.params.useAssert)
        VersionCondition.addPredefinedGlobalIdent("assert");
    if (global.params.useArrayBounds == BOUNDSCHECKoff)
        VersionCondition.addPredefinedGlobalIdent("D_NoBoundsChecks");
    VersionCondition.addPredefinedGlobalIdent("D_HardFloat");
}
