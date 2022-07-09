
/**
 * Entry point for DMD.
 *
 * This modules defines the entry point (main) for DMD, as well as related
 * utilities needed for arguments parsing, path manipulation, etc...
 * This file is not shared with other compilers which use the DMD front-end.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/mars.d, _mars.d)
 * Documentation:  https://dlang.org/phobos/dmd_mars.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/mars.d
 */

module dmd.mars;

import core.stdc.ctype;
import core.stdc.limits;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.arraytypes;
import dmd.astcodegen;
import dmd.astenums;
import dmd.builtin;
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
import dmd.file_manager;
import dmd.globals;
import dmd.hdrgen;
import dmd.id;
import dmd.identifier;
import dmd.inline;
import dmd.json;
version (NoMain) {} else
{
    import dmd.glue : generateCodeAndWrite;
    import dmd.dmsc : backend_init, backend_term;
    import dmd.link;
    import dmd.vsoptions;
}
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
private void logo()
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
private void printInternalFailure(FILE* stream)
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
private void usage()
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
version (NoMain) {} else
private int tryMain(size_t argc, const(char)** argv, ref Param params)
{
    Strings files;
    Strings libmodules;
    global._init();

    if (parseCommandlineAndConfig(argc, argv, params, files))
        return EXIT_FAILURE;

    if (params.usage)
    {
        usage();
        return EXIT_SUCCESS;
    }

    if (params.logo)
    {
        logo();
        return EXIT_SUCCESS;
    }

    /*
    Prints a supplied usage text to the console and
    returns the exit code for the help usage page.

    Returns:
        `EXIT_SUCCESS` if no errors occurred, `EXIT_FAILURE` otherwise
    */
    static int printHelpUsage(string help)
    {
        printf("%.*s", cast(int)help.length, &help[0]);
        return global.errors ? EXIT_FAILURE : EXIT_SUCCESS;
    }

    /*
    Print a message to make it clear when warnings are treated as errors.
    */
    static void errorOnWarning()
    {
        error(Loc.initial, "warnings are treated as errors");
        errorSupplemental(Loc.initial, "Use -wi if you wish to treat warnings only as informational.");
    }

    /*
    Generates code to check for all `params` whether any usage page
    has been requested.
    If so, the generated code will print the help page of the flag
    and return with an exit code.

    Params:
        params = parameters with `Usage` suffices in `params` for which
        their truthness should be checked.

    Returns: generated code for checking the usage pages of the provided `params`.
    */
    static string generateUsageChecks(string[] params)
    {
        string s;
        foreach (n; params)
        {
            s ~= q{
                if (params.}~n~q{Usage)
                    return printHelpUsage(CLIUsage.}~n~q{Usage);
            };
        }
        return s;
    }
    import dmd.cli : CLIUsage;
    mixin(generateUsageChecks(["mcpu", "transition", "check", "checkAction",
        "preview", "revert", "externStd", "hc"]));

    if (params.manual)
    {
        version (Windows)
        {
            browse("https://dlang.org/dmd-windows.html");
        }
        version (linux)
        {
            browse("https://dlang.org/dmd-linux.html");
        }
        version (OSX)
        {
            browse("https://dlang.org/dmd-osx.html");
        }
        version (FreeBSD)
        {
            browse("https://dlang.org/dmd-freebsd.html");
        }
        /*NOTE: No regular builds for openbsd/dragonflybsd (yet) */
        /*
        version (OpenBSD)
        {
            browse("https://dlang.org/dmd-openbsd.html");
        }
        version (DragonFlyBSD)
        {
            browse("https://dlang.org/dmd-dragonflybsd.html");
        }
        */
        return EXIT_SUCCESS;
    }

    if (params.color)
        global.console = cast(void*) createConsole(core.stdc.stdio.stderr);

    target.setCPU();

    if (global.errors)
    {
        fatal();
    }
    if (files.dim == 0)
    {
        if (params.jsonFieldFlags)
        {
            generateJson(null);
            return EXIT_SUCCESS;
        }
        usage();
        return EXIT_FAILURE;
    }

    reconcileCommands(params, target);

    // Add in command line versions
    if (params.versionids)
        foreach (charz; *params.versionids)
            VersionCondition.addGlobalIdent(charz.toDString());
    if (params.debugids)
        foreach (charz; *params.debugids)
            DebugCondition.addGlobalIdent(charz.toDString());

    setDefaultLibrary(params, target);

    // Initialization
    target._init(params);
    Type._init();
    Id.initialize();
    Module._init();
    Expression._init();
    Objc._init();

    reconcileLinkRunLib(params, files.dim, target.obj_ext);
    version(CRuntime_Microsoft)
    {
        import dmd.root.longdouble;
        initFPU();
    }
    import dmd.root.ctfloat : CTFloat;
    CTFloat.initialize();

    // Predefined version identifiers
    addDefaultVersionIdentifiers(params, target);

    if (params.verbose)
    {
        stdout.printPredefinedVersions();
        stdout.printGlobalConfigs();
    }
    //printf("%d source files\n", cast(int) files.dim);

    // Build import search path

    static Strings* buildPath(Strings* imppath)
    {
        Strings* result = null;
        if (imppath)
        {
            foreach (const path; *imppath)
            {
                Strings* a = FileName.splitPath(path);
                if (a)
                {
                    if (!result)
                        result = new Strings();
                    result.append(a);
                }
            }
        }
        return result;
    }

    if (params.mixinOut.doOutput)
    {
        params.mixinOut.buffer = cast(OutBuffer*)Mem.check(calloc(1, OutBuffer.sizeof));
        atexit(&flushMixins); // see comment for flushMixins
    }
    scope(exit) flushMixins();
    global.path = buildPath(params.imppath);
    global.filePath = buildPath(params.fileImppath);

    // Create Modules
    Modules modules = createModules(files, libmodules, target);
    // Read files
    foreach (m; modules)
    {
        m.read(Loc.initial);
    }

    // Parse files
    bool anydocfiles = false;
    size_t filecount = modules.dim;
    for (size_t filei = 0, modi = 0; filei < filecount; filei++, modi++)
    {
        Module m = modules[modi];
        if (params.verbose)
            message("parse     %s", m.toChars());
        if (!Module.rootModule)
            Module.rootModule = m;
        m.importedFrom = m; // m.isRoot() == true
//        if (!driverParams.oneobj || modi == 0 || m.isDocFile)
//            m.deleteObjFile();

        m.parse();
        if (m.filetype == FileType.dhdr)
        {
            // Remove m's object file from list of object files
            for (size_t j = 0; j < params.objfiles.length; j++)
            {
                if (m.objfile.toChars() == params.objfiles[j])
                {
                    params.objfiles.remove(j);
                    break;
                }
            }
            if (params.objfiles.length == 0)
                driverParams.link = false;
        }
        if (m.filetype == FileType.ddoc)
        {
            anydocfiles = true;
            gendocfile(m);
            // Remove m from list of modules
            modules.remove(modi);
            modi--;
            // Remove m's object file from list of object files
            for (size_t j = 0; j < params.objfiles.length; j++)
            {
                if (m.objfile.toChars() == params.objfiles[j])
                {
                    params.objfiles.remove(j);
                    break;
                }
            }
            if (params.objfiles.length == 0)
                driverParams.link = false;
        }
    }

    if (anydocfiles && modules.dim && (driverParams.oneobj || params.objname))
    {
        error(Loc.initial, "conflicting Ddoc and obj generation options");
        fatal();
    }
    if (global.errors)
        fatal();

    if (params.dihdr.doOutput)
    {
        /* Generate 'header' import files.
         * Since 'header' import files must be independent of command
         * line switches and what else is imported, they are generated
         * before any semantic analysis.
         */
        foreach (m; modules)
        {
            if (m.filetype == FileType.dhdr)
                continue;
            if (params.verbose)
                message("import    %s", m.toChars());
            genhdrfile(m);
        }
    }
    if (global.errors)
        removeHdrFilesAndFail(params, modules);

    // load all unconditional imports for better symbol resolving
    foreach (m; modules)
    {
        if (params.verbose)
            message("importall %s", m.toChars());
        m.importAll(null);
    }
    if (global.errors)
        removeHdrFilesAndFail(params, modules);

    backend_init();

    // Do semantic analysis
    foreach (m; modules)
    {
        if (params.verbose)
            message("semantic  %s", m.toChars());
        m.dsymbolSemantic(null);
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
    foreach (m; modules)
    {
        if (params.verbose)
            message("semantic2 %s", m.toChars());
        m.semantic2(null);
    }
    Module.runDeferredSemantic2();
    if (global.errors)
        removeHdrFilesAndFail(params, modules);

    // Do pass 3 semantic analysis
    foreach (m; modules)
    {
        if (params.verbose)
            message("semantic3 %s", m.toChars());
        m.semantic3(null);
    }
    if (includeImports)
    {
        // Note: DO NOT USE foreach here because Module.amodules.dim can
        //       change on each iteration of the loop
        for (size_t i = 0; i < compiledImports.dim; i++)
        {
            auto m = compiledImports[i];
            assert(m.isRoot);
            if (params.verbose)
                message("semantic3 %s", m.toChars());
            m.semantic3(null);
            modules.push(m);
        }
    }
    Module.runDeferredSemantic3();
    if (global.errors)
        removeHdrFilesAndFail(params, modules);

    // Scan for functions to inline
    foreach (m; modules)
    {
        if (params.useInline || m.hasAlwaysInlines)
        {
            if (params.verbose)
                message("inline scan %s", m.toChars());
            inlineScanModule(m);
        }
    }

    if (global.warnings)
        errorOnWarning();

    // Do not attempt to generate output files if errors or warnings occurred
    if (global.errors || global.warnings)
        removeHdrFilesAndFail(params, modules);

    // inlineScan incrementally run semantic3 of each expanded functions.
    // So deps file generation should be moved after the inlining stage.
    if (OutBuffer* ob = params.moduleDeps.buffer)
    {
        foreach (i; 1 .. modules[0].aimports.dim)
            semantic3OnDependencies(modules[0].aimports[i]);
        Module.runDeferredSemantic3();

        const data = (*ob)[];
        if (params.moduleDeps.name)
            writeFile(Loc.initial, params.moduleDeps.name, data);
        else
            printf("%.*s", cast(int)data.length, data.ptr);
    }

    printCtfePerformanceStats();
    printTemplateStats();

    // Generate output files
    if (params.json.doOutput)
    {
        generateJson(&modules);
    }
    if (!global.errors && params.ddoc.doOutput)
    {
        foreach (m; modules)
        {
            gendocfile(m);
        }
    }
    if (params.vcg_ast)
    {
        import dmd.hdrgen;
        foreach (mod; modules)
        {
            auto buf = OutBuffer();
            buf.doindent = 1;
            moduleToBuffer(&buf, mod);

            // write the output to $(filename).cg
            auto cgFilename = FileName.addExt(mod.srcfile.toString(), "cg");
            File.write(cgFilename.ptr, buf[]);
        }
    }

    if (global.params.cxxhdr.doOutput)
        genCppHdrFiles(modules);

    if (global.errors)
        fatal();

    if (driverParams.lib && params.objfiles.length == 0)
    {
        error(Loc.initial, "no input files");
        return EXIT_FAILURE;
    }

    if (params.addMain && !global.hasMainFunction)
    {
        auto mainModule = moduleWithEmptyMain();
        modules.push(mainModule);
        if (!driverParams.oneobj || modules.length == 1)
            params.objfiles.push(mainModule.objfile.toChars());
    }

    generateCodeAndWrite(modules[], libmodules[], params.libname, params.objdir,
                         driverParams.lib, params.obj, driverParams.oneobj, params.multiobj,
                         params.verbose);

    backend_term();

    if (global.errors)
        fatal();
    int status = EXIT_SUCCESS;
    if (!params.objfiles.length)
    {
        if (driverParams.link)
            error(Loc.initial, "no object files to link");
    }
    else
    {
        if (driverParams.link)
            status = runLINK();
        if (params.run)
        {
            if (!status)
            {
                status = runProgram();
                /* Delete .obj files and .exe file
                 */
                foreach (m; modules)
                {
                    m.deleteObjFile();
                    if (driverParams.oneobj)
                        break;
                }
                params.exefile.toCStringThen!(ef => File.remove(ef.ptr));
            }
        }
    }

    // Output the makefile dependencies
    if (params.makeDeps.doOutput)
        emitMakeDeps(params);

    if (global.warnings)
        errorOnWarning();

    if (global.errors || global.warnings)
        removeHdrFilesAndFail(params, modules);

    return status;
}

/**
 * Parses the command line arguments and configuration files
 *
 * Params:
 *   argc = Number of arguments passed via command line
 *   argv = Array of string arguments passed via command line
 *   params = parametes from argv
 *   files = files from argv
 * Returns: true on faiure
 */
version(NoMain) {} else
bool parseCommandlineAndConfig(size_t argc, const(char)** argv, ref Param params, ref Strings files)
{
    // Detect malformed input
    static bool badArgs()
    {
        error(Loc.initial, "missing or null command line arguments");
        return true;
    }

    if (argc < 1 || !argv)
        return badArgs();
    // Convert argc/argv into arguments[] for easier handling
    Strings arguments = Strings(argc);
    for (size_t i = 0; i < argc; i++)
    {
        if (!argv[i])
            return badArgs();
        arguments[i] = argv[i];
    }
    if (const(char)* missingFile = responseExpand(arguments)) // expand response files
        error(Loc.initial, "cannot open response file '%s'", missingFile);
    //for (size_t i = 0; i < arguments.dim; ++i) printf("arguments[%d] = '%s'\n", i, arguments[i]);
    files.reserve(arguments.dim - 1);
    // Set default values
    params.argv0 = arguments[0].toDString;

    version (Windows)
        enum iniName = "sc.ini";
    else version (Posix)
        enum iniName = "dmd.conf";
    else
        static assert(0, "fix this");

    global.inifilename = parse_conf_arg(&arguments);
    if (global.inifilename)
    {
        // can be empty as in -conf=
        if (global.inifilename.length && !FileName.exists(global.inifilename))
            error(Loc.initial, "config file '%.*s' does not exist.",
                  cast(int)global.inifilename.length, global.inifilename.ptr);
    }
    else
    {
        global.inifilename = findConfFile(params.argv0, iniName);
    }
    // Read the configuration file
    const iniReadResult = File.read(global.inifilename);
    const inifileBuffer = iniReadResult.buffer.data;
    /* Need path of configuration file, for use in expanding @P macro
     */
    const(char)[] inifilepath = FileName.path(global.inifilename);
    Strings sections;
    StringTable!(char*) environment;
    environment._init(7);
    /* Read the [Environment] section, so we can later
     * pick up any DFLAGS settings.
     */
    sections.push("Environment");
    parseConfFile(environment, global.inifilename, inifilepath, inifileBuffer, &sections);

    const(char)[] arch = target.is64bit ? "64" : "32"; // use default
    arch = parse_arch_arg(&arguments, arch);

    // parse architecture from DFLAGS read from [Environment] section
    {
        Strings dflags;
        getenv_setargv(readFromEnv(environment, "DFLAGS"), &dflags);
        environment.reset(7); // erase cached environment updates
        arch = parse_arch_arg(&dflags, arch);
    }

    bool is64bit = arch[0] == '6';

    version(Windows) // delete LIB entry in [Environment] (necessary for optlink) to allow inheriting environment for MS-COFF
    if (arch != "32omf")
        environment.update("LIB", 3).value = null;

    // read from DFLAGS in [Environment{arch}] section
    char[80] envsection = void;
    sprintf(envsection.ptr, "Environment%.*s", cast(int) arch.length, arch.ptr);
    sections.push(envsection.ptr);
    parseConfFile(environment, global.inifilename, inifilepath, inifileBuffer, &sections);
    getenv_setargv(readFromEnv(environment, "DFLAGS"), &arguments);
    updateRealEnvironment(environment);
    environment.reset(1); // don't need environment cache any more

    if (parseCommandLine(arguments, argc, params, files, target))
    {
        Loc loc;
        errorSupplemental(loc, "run `dmd` to print the compiler manual");
        errorSupplemental(loc, "run `dmd -man` to open browser on manual");
        return true;
    }

    if (target.is64bit != is64bit)
        error(Loc.initial, "the architecture must not be changed in the %s section of %.*s",
              envsection.ptr, cast(int)global.inifilename.length, global.inifilename.ptr);

    global.preprocess = &preprocess;
    return false;
}
/// Emit the makefile dependencies for the -makedeps switch
version (NoMain) {} else
{
    void emitMakeDeps(ref Param params)
    {
        assert(params.makeDeps.doOutput);

        OutBuffer buf;

        // start by resolving and writing the target (which is sometimes resolved during link phase)
        if (driverParams.link && params.exefile)
        {
            buf.writeEscapedMakePath(&params.exefile[0]);
        }
        else if (driverParams.lib)
        {
            const(char)[] libname = params.libname ? params.libname : FileName.name(params.objfiles[0].toDString);
            libname = FileName.forceExt(libname,target.lib_ext);

            buf.writeEscapedMakePath(&libname[0]);
        }
        else if (params.objname)
        {
            buf.writeEscapedMakePath(&params.objname[0]);
        }
        else if (params.objfiles.length)
        {
            buf.writeEscapedMakePath(params.objfiles[0]);
            foreach (of; params.objfiles[1 .. $])
            {
                buf.writestring(" ");
                buf.writeEscapedMakePath(of);
            }
        }
        else
        {
            assert(false, "cannot resolve makedeps target");
        }

        buf.writestring(":");

        // then output every dependency
        foreach (dep; params.makeDeps.files)
        {
            buf.writestringln(" \\");
            buf.writestring("  ");
            buf.writeEscapedMakePath(dep);
        }
        buf.writenl();

        const data = buf[];
        if (params.makeDeps.name)
            writeFile(Loc.initial, params.makeDeps.name, data);
        else
            printf("%.*s", cast(int) data.length, data.ptr);
    }
}

extern (C++) void generateJson(Modules* modules)
{
    OutBuffer buf;
    json_generate(&buf, modules);

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
        writeFile(Loc.initial, jsonfilename, buf[]);
    }
}

version (DigitalMars)
{
    private void installMemErrHandler()
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
else
{
    // in druntime:
    alias MainFunc = extern(C) int function(char[][] args);
    extern (C) int _d_run_main(int argc, char** argv, MainFunc dMain);


    // When using a C main, host DMD may not link against host druntime by default.
    version (DigitalMars)
    {
        version (Win64)
            pragma(lib, "phobos64");
        else version (Win32)
        {
            version (CRuntime_Microsoft)
                pragma(lib, "phobos32mscoff");
            else
                pragma(lib, "phobos");
        }
    }

    extern extern(C) __gshared string[] rt_options;

    /**
     * DMD's entry point, C main.
     *
     * Without `-lowmem`, we need to switch to the bump-pointer allocation scheme
     * right from the start, before any module ctors are run, so we need this hook
     * before druntime is initialized and `_Dmain` is called.
     *
     * Returns:
     *   Return code of the application
     */
    extern (C) int main(int argc, char** argv)
    {
        bool lowmem = false;
        foreach (i; 1 .. argc)
        {
            if (strcmp(argv[i], "-lowmem") == 0)
            {
                lowmem = true;
                break;
            }
        }
        if (!lowmem)
        {
            __gshared string[] disable_options = [ "gcopt=disable:1" ];
            rt_options = disable_options;
            mem.disableGC();
        }

        // initialize druntime and call _Dmain() below
        return _d_run_main(argc, argv, &_Dmain);
    }

    /**
     * Manual D main (for druntime initialization), which forwards to `tryMain`.
     *
     * Returns:
     *   Return code of the application
     */
    extern (C) int _Dmain(char[][])
    {
        // possibly install memory error handler
        version (DigitalMars)
        {
            installMemErrHandler();
        }

        import core.runtime;

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
                enum sourcePath = dirName(dirName(dirName(__FILE_FULL_PATH__, '\\'), '\\'), '\\');
            else
                enum sourcePath = dirName(dirName(dirName(__FILE_FULL_PATH__, '/'), '/'), '/');

            dmd_coverSourcePath(sourcePath);
            dmd_coverDestPath(sourcePath);
            dmd_coverSetMerge(true);
        }

        scope(failure) stderr.printInternalFailure;

        auto args = Runtime.cArgs();
        return tryMain(args.argc, cast(const(char)**)args.argv, global.params);
    }
} // !NoMain

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
private void setDefaultLibrary(ref Param params, const ref Target target)
{
    if (driverParams.defaultlibname is null)
    {
        if (target.os == Target.OS.Windows)
        {
            if (target.is64bit)
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
}

/**
 * Add default `version` identifier for dmd, and set the
 * target platform in `params`.
 * https://dlang.org/spec/version.html#predefined-versions
 *
 * Needs to be run after all arguments parsing (command line, DFLAGS environment
 * variable and config file) in order to add final flags (such as `X86_64` or
 * the `CRuntime` used).
 *
 * Params:
 *      params = which target to compile for (set by `setTarget()`)
 *      tgt    = target
 */
public
void addDefaultVersionIdentifiers(const ref Param params, const ref Target tgt)
{
    VersionCondition.addPredefinedGlobalIdent("DigitalMars");
    VersionCondition.addPredefinedGlobalIdent("LittleEndian");
    VersionCondition.addPredefinedGlobalIdent("D_Version2");
    VersionCondition.addPredefinedGlobalIdent("all");

    addPredefinedGlobalIdentifiers(tgt);

    if (params.ddoc.doOutput)
        VersionCondition.addPredefinedGlobalIdent("D_Ddoc");
    if (params.cov)
        VersionCondition.addPredefinedGlobalIdent("D_Coverage");
    if (driverParams.pic != PIC.fixed)
        VersionCondition.addPredefinedGlobalIdent(driverParams.pic == PIC.pic ? "D_PIC" : "D_PIE");
    if (params.useUnitTests)
        VersionCondition.addPredefinedGlobalIdent("unittest");
    if (params.useAssert == CHECKENABLE.on)
        VersionCondition.addPredefinedGlobalIdent("assert");
    if (params.useIn == CHECKENABLE.on)
        VersionCondition.addPredefinedGlobalIdent("D_PreConditions");
    if (params.useOut == CHECKENABLE.on)
        VersionCondition.addPredefinedGlobalIdent("D_PostConditions");
    if (params.useInvariants == CHECKENABLE.on)
        VersionCondition.addPredefinedGlobalIdent("D_Invariants");
    if (params.useArrayBounds == CHECKENABLE.off)
        VersionCondition.addPredefinedGlobalIdent("D_NoBoundsChecks");
    if (params.betterC)
    {
        VersionCondition.addPredefinedGlobalIdent("D_BetterC");
    }
    else
    {
        VersionCondition.addPredefinedGlobalIdent("D_ModuleInfo");
        VersionCondition.addPredefinedGlobalIdent("D_Exceptions");
        VersionCondition.addPredefinedGlobalIdent("D_TypeInfo");
    }

    VersionCondition.addPredefinedGlobalIdent("D_HardFloat");

    if (params.tracegc)
        VersionCondition.addPredefinedGlobalIdent("D_ProfileGC");
}

/**
 * Add predefined global identifiers that are determied by the target
 */
private
void addPredefinedGlobalIdentifiers(const ref Target tgt)
{
    import dmd.cond : VersionCondition;

    alias predef = VersionCondition.addPredefinedGlobalIdent;
    if (tgt.cpu >= CPU.sse2)
    {
        predef("D_SIMD");
        if (tgt.cpu >= CPU.avx)
            predef("D_AVX");
        if (tgt.cpu >= CPU.avx2)
            predef("D_AVX2");
    }

    with (Target)
    {
        if (tgt.os & OS.Posix)
            predef("Posix");
        if (tgt.os & (OS.linux | OS.FreeBSD | OS.OpenBSD | OS.DragonFlyBSD | OS.Solaris))
            predef("ELFv1");
        switch (tgt.os)
        {
            case OS.none:         { predef("FreeStanding"); break; }
            case OS.linux:        { predef("linux");        break; }
            case OS.OpenBSD:      { predef("OpenBSD");      break; }
            case OS.DragonFlyBSD: { predef("DragonFlyBSD"); break; }
            case OS.Solaris:      { predef("Solaris");      break; }
            case OS.Windows:
            {
                 predef("Windows");
                 VersionCondition.addPredefinedGlobalIdent(tgt.is64bit ? "Win64" : "Win32");
                 break;
            }
            case OS.OSX:
            {
                predef("OSX");
                // For legacy compatibility
                predef("darwin");
                break;
            }
            case OS.FreeBSD:
            {
                predef("FreeBSD");
                switch (tgt.osMajor)
                {
                    case 10: predef("FreeBSD_10");  break;
                    case 11: predef("FreeBSD_11"); break;
                    case 12: predef("FreeBSD_12"); break;
                    case 13: predef("FreeBSD_13"); break;
                    default: predef("FreeBSD_11"); break;
                }
                break;
            }
            default: assert(0);
        }
    }

    addCRuntimePredefinedGlobalIdent(tgt.c);
    addCppRuntimePredefinedGlobalIdent(tgt.cpp);

    if (tgt.is64bit)
    {
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86_64");
        VersionCondition.addPredefinedGlobalIdent("X86_64");
    }
    else
    {
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm"); //legacy
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86");
        VersionCondition.addPredefinedGlobalIdent("X86");
    }
    if (tgt.isLP64)
        VersionCondition.addPredefinedGlobalIdent("D_LP64");
    else if (tgt.is64bit)
        VersionCondition.addPredefinedGlobalIdent("X32");
}

private
void addCRuntimePredefinedGlobalIdent(const ref TargetC c)
{
    import dmd.cond : VersionCondition;

    alias predef = VersionCondition.addPredefinedGlobalIdent;
    with (TargetC.Runtime) switch (c.runtime)
    {
    default:
    case Unspecified: return;
    case Bionic:      return predef("CRuntime_Bionic");
    case DigitalMars: return predef("CRuntime_DigitalMars");
    case Glibc:       return predef("CRuntime_Glibc");
    case Microsoft:   return predef("CRuntime_Microsoft");
    case Musl:        return predef("CRuntime_Musl");
    case Newlib:      return predef("CRuntime_Newlib");
    case UClibc:      return predef("CRuntime_UClibc");
    case WASI:        return predef("CRuntime_WASI");
    }
}

private
void addCppRuntimePredefinedGlobalIdent(const ref TargetCPP cpp)
{
    import dmd.cond : VersionCondition;

    alias predef = VersionCondition.addPredefinedGlobalIdent;
    with (TargetCPP.Runtime) switch (cpp.runtime)
    {
    default:
    case Unspecified: return;
    case Clang:       return predef("CppRuntime_Clang");
    case DigitalMars: return predef("CppRuntime_DigitalMars");
    case Gcc:         return predef("CppRuntime_Gcc");
    case Microsoft:   return predef("CppRuntime_Microsoft");
    case Sun:         return predef("CppRuntime_Sun");
    }
}

private void printPredefinedVersions(FILE* stream)
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
            final switch (checkOptions(arg[len - 1 .. $], params.}~usageFlag~","~
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
        for (size_t i = 0; i < arguments.dim; i++)
        {
            printf("arguments[%d] = '%s'\n", i, arguments[i]);
        }
    }
    for (size_t i = 1; i < arguments.dim; i++)
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
                    params.usage = true;
                    return false;
                }
            }
            files.push(p);
            continue;
        }

        if (arg == "-allinst")               // https://dlang.org/dmd.html#switch-allinst
            params.allInst = true;
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
            mixin(checkOptionsMixin("checkActionUsage",
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
                params.checkActionUsage = true;
                return false;
            }
        }
        else if (startsWith(p + 1, "check")) // https://dlang.org/dmd.html#switch-check
        {
            enum len = "-check=".length;
            mixin(checkOptionsMixin("checkUsage",
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
                params.checkUsage = true;
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
                    params.color = true;
                    break;
                case "off":
                    params.color = false;
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
                params.color = true;
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
            driverParams.symdebug = 1;
        else if (startsWith(p + 1, "gdwarf")) // https://dlang.org/dmd.html#switch-gdwarf
        {
            if (driverParams.dwarf)
            {
                error("`-gdwarf=<version>` can only be provided once");
                break;
            }
            driverParams.symdebug = 1;

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
            if (!driverParams.symdebug)
                driverParams.symdebug = 1;
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
            target.is64bit = false;
            target.omfobj = false;
        }
        else if (arg == "-m64") // https://dlang.org/dmd.html#switch-m64
        {
            target.is64bit = true;
            target.omfobj = false;
        }
        else if (arg == "-m32mscoff") // https://dlang.org/dmd.html#switch-m32mscoff
        {
            target.is64bit = false;
            target.omfobj = false;
        }
        else if (arg == "-m32omf") // https://dlang.org/dmd.html#switch-m32omfobj
        {
            target.is64bit = false;
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
            params.verbose = true;
        else if (arg == "-vcg-ast")
            params.vcg_ast = true;
        else if (arg == "-vasm") // https://dlang.org/dmd.html#switch-vasm
            driverParams.vasm = true;
        else if (arg == "-vtls") // https://dlang.org/dmd.html#switch-vtls
            params.vtls = true;
        else if (startsWith(p + 1, "vtemplates")) // https://dlang.org/dmd.html#switch-vtemplates
        {
            params.vtemplates = true;
            if (p[1 + "vtemplates".length] == '=')
            {
                const(char)[] style = arg[1 + "vtemplates=".length .. $];
                switch (style)
                {
                case "list-instances":
                    params.vtemplatesListInstances = true;
                    break;
                default:
                    error("unknown vtemplates style '%.*s', must be 'list-instances'", cast(int) style.length, style.ptr);
                }
            }
        }
        else if (arg == "-vcolumns") // https://dlang.org/dmd.html#switch-vcolumns
            params.showColumns = true;
        else if (arg == "-vgc") // https://dlang.org/dmd.html#switch-vgc
            params.vgc = true;
        else if (startsWith(p + 1, "verrors")) // https://dlang.org/dmd.html#switch-verrors
        {
            if (p[8] != '=')
            {
                errorInvalidSwitch(p, "Expected argument following `-verrors , e.g. `-verrors=100`");
                return true;
            }
            if (startsWith(p + 9, "spec"))
            {
                params.showGaggedErrors = true;
            }
            else if (startsWith(p + 9, "context"))
            {
                params.printErrorContext = true;
            }
            else if (!params.errorLimit.parseDigits(p.toDString()[9 .. $]))
            {
                errorInvalidSwitch(p, "Only number, `spec`, or `context` are allowed for `-verrors`");
                return true;
            }
        }
        else if (startsWith(p + 1, "verror-style="))
        {
            const(char)[] style = arg["verror-style=".length + 1 .. $];

            switch (style)
            {
            case "digitalmars":
                params.messageStyle = MessageStyle.digitalmars;
                break;
            case "gnu":
                params.messageStyle = MessageStyle.gnu;
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
            mixin(checkOptionsMixin("mcpuUsage",
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
                    params.mcpuUsage = true;
                    return false;
                }
            }
            else
            {
                errorInvalidSwitch(p, "Only `baseline`, `avx`, `avx2` or `native` are allowed for `-mcpu`");
                params.mcpuUsage = true;
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
            mixin(checkOptionsMixin("externStdUsage",
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
                params.externStdUsage = true;
                return false;
            }
        }
        else if (startsWith(p + 1, "transition")) // https://dlang.org/dmd.html#switch-transition
        {
            enum len = "-transition=".length;
            // Parse:
            //      -transition=number
            mixin(checkOptionsMixin("transitionUsage",
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
                            params.vfield = true;
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
                            params.transitionUsage = true;
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
                            params.transitionUsage = true;
                            return false;
                    }
                }
                errorInvalidSwitch(p);
                params.transitionUsage = true;
                return false;
            }
        }
        else if (startsWith(p + 1, "preview") ) // https://dlang.org/dmd.html#switch-preview
        {
            enum len = "-preview=".length;
            // Parse:
            //      -preview=name
            mixin(checkOptionsMixin("previewUsage",
                "`-preview=<name>` requires a name"));

            if (!parseCLIOption!("preview", Usage.previews)(params, arg))
            {
                error("preview `%s` is invalid", p);
                params.previewUsage = true;
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
            mixin(checkOptionsMixin("revertUsage",
                "`-revert=<name>` requires a name"));

            if (!parseCLIOption!("revert", Usage.reverts)(params, arg))
            {
                error("revert `%s` is invalid", p);
                params.revertUsage = true;
                return false;
            }
        }
        else if (arg == "-w")   // https://dlang.org/dmd.html#switch-w
            params.warnings = DiagnosticReporting.error;
        else if (arg == "-wi")  // https://dlang.org/dmd.html#switch-wi
            params.warnings = DiagnosticReporting.inform;
        else if (arg == "-O")   // https://dlang.org/dmd.html#switch-O
            driverParams.optimize = true;
        else if (p[1] == 'o')
        {
            const(char)* path;
            switch (p[2])
            {
            case '-':                       // https://dlang.org/dmd.html#switch-o-
                params.obj = false;
                break;
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
                mixin(checkOptionsMixin("hcUsage", "`-HC=<mode>` requires a valid mode"));
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
                        params.hcUsage = true;
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
            params.useDIP25 =  FeatureState.enabled;
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
            params.betterC = true;
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
                }
                else if (Identifier.isValidIdentifier(p + 7))
                {
                    if (!params.debugids)
                        params.debugids = new Array!(const(char)*);
                    params.debugids.push(p + 7);
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
                }
                else if (Identifier.isValidIdentifier(p + 9))
                {
                    if (!params.versionids)
                        params.versionids = new Array!(const(char)*);
                    params.versionids.push(p + 9);
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
            params.usage = true;
            return false;
        }
        else if (arg == "--r")
            driverParams.debugr = true;
        else if (arg == "--version")
        {
            params.logo = true;
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
            params.manual = true;
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

/***********************************************
 * Adjust gathered command line switches and reconcile them.
 * Params:
 *      params = switches gathered from command line,
 *               and update in place
 *      target = more switches from the command line,
 *               update in place
 *      numSrcFiles = number of source files
 */
version (NoMain) {} else
private void reconcileCommands(ref Param params, ref Target target)
{
    if (target.os == Target.OS.OSX)
    {
        driverParams.pic = PIC.pic;
    }
    else if (target.os == Target.OS.Windows)
    {
        if (driverParams.pic)
            error(Loc.initial, "`-fPIC` and `-fPIE` cannot be used when targetting windows");
        if (driverParams.dwarf)
            error(Loc.initial, "`-gdwarf` cannot be used when targetting windows");
    }
    else if (target.os == Target.OS.DragonFlyBSD)
    {
        if (!target.is64bit)
            error(Loc.initial, "`-m32` is not supported on DragonFlyBSD, it is 64-bit only");
    }

    if (target.os & (Target.OS.linux | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.Solaris | Target.OS.DragonFlyBSD))
    {
        if (driverParams.lib && driverParams.dll)
            error(Loc.initial, "cannot mix `-lib` and `-shared`");
    }
    if (target.os == Target.OS.Windows)
    {
        foreach(b; params.linkswitchIsForCC[])
        {
            if (b)
            {
                // Linking code is guarded by version (Posix):
                error(Loc.initial, "`Xcc=` link switches not available for this operating system");
                break;
            }
        }

        if (!driverParams.mscrtlib)
        {
            version (Windows)
            {
                VSOptions vsopt;
                vsopt.initialize();
                driverParams.mscrtlib = vsopt.defaultRuntimeLibrary(target.is64bit).toDString;
            }
            else
                error(Loc.initial, "must supply `-mscrtlib` manually when cross compiling to windows");
        }
    }
    else
    {
        if (target.omfobj)
            error(Loc.initial, "`-m32omf` can only be used when targetting windows");
        if (driverParams.mscrtlib)
            error(Loc.initial, "`-mscrtlib` can only be used when targetting windows");
    }

    if (params.boundscheck != CHECKENABLE._default)
    {
        if (params.useArrayBounds == CHECKENABLE._default)
            params.useArrayBounds = params.boundscheck;
    }

    if (params.useUnitTests)
    {
        if (params.useAssert == CHECKENABLE._default)
            params.useAssert = CHECKENABLE.on;
    }

    if (params.release)
    {
        if (params.useInvariants == CHECKENABLE._default)
            params.useInvariants = CHECKENABLE.off;

        if (params.useIn == CHECKENABLE._default)
            params.useIn = CHECKENABLE.off;

        if (params.useOut == CHECKENABLE._default)
            params.useOut = CHECKENABLE.off;

        if (params.useArrayBounds == CHECKENABLE._default)
            params.useArrayBounds = CHECKENABLE.safeonly;

        if (params.useAssert == CHECKENABLE._default)
            params.useAssert = CHECKENABLE.off;

        if (params.useSwitchError == CHECKENABLE._default)
            params.useSwitchError = CHECKENABLE.off;
    }
    else
    {
        if (params.useInvariants == CHECKENABLE._default)
            params.useInvariants = CHECKENABLE.on;

        if (params.useIn == CHECKENABLE._default)
            params.useIn = CHECKENABLE.on;

        if (params.useOut == CHECKENABLE._default)
            params.useOut = CHECKENABLE.on;

        if (params.useArrayBounds == CHECKENABLE._default)
            params.useArrayBounds = CHECKENABLE.on;

        if (params.useAssert == CHECKENABLE._default)
            params.useAssert = CHECKENABLE.on;

        if (params.useSwitchError == CHECKENABLE._default)
            params.useSwitchError = CHECKENABLE.on;
    }

    if (params.betterC)
    {
        if (params.checkAction != CHECKACTION.halt)
            params.checkAction = CHECKACTION.C;

        params.useModuleInfo = false;
        params.useTypeInfo = false;
        params.useExceptions = false;
    }
}

/***********************************************
 * Adjust link, run and lib line switches and reconcile them.
 * Params:
 *      params = switches gathered from command line,
 *               and update in place
 *      numSrcFiles = number of source files
 *      obj_ext = object file extension
 */
version (NoMain) {} else
private void reconcileLinkRunLib(ref Param params, size_t numSrcFiles, const char[] obj_ext)
{
    if (!params.obj || driverParams.lib)
        driverParams.link = false;
    if (driverParams.link)
    {
        params.exefile = params.objname;
        driverParams.oneobj = true;
        if (params.objname)
        {
            /* Use this to name the one object file with the same
             * name as the exe file.
             */
            params.objname = FileName.forceExt(params.objname, obj_ext);
            /* If output directory is given, use that path rather than
             * the exe file path.
             */
            if (params.objdir)
            {
                const(char)[] name = FileName.name(params.objname);
                params.objname = FileName.combine(params.objdir, name);
            }
        }
    }
    else if (params.run)
    {
        error(Loc.initial, "flags conflict with -run");
        fatal();
    }
    else if (driverParams.lib)
    {
        params.libname = params.objname;
        params.objname = null;
        // Haven't investigated handling these options with multiobj
        if (!params.cov && !params.trace)
            params.multiobj = true;
    }
    else
    {
        if (params.objname && numSrcFiles)
        {
            driverParams.oneobj = true;
            //error("multiple source files, but only one .obj name");
            //fatal();
        }
    }
}

/// Sets the boolean for a flag with the given name
private static void setFlagFor(string name, ref bool b)
{
    b = name != "revert";
}

/// Sets the FeatureState for a flag with the given name
private static void setFlagFor(string name, ref FeatureState s)
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
private
Modules createModules(ref Strings files, ref Strings libmodules, const ref Target target)
{
    Modules modules;
    modules.reserve(files.dim);
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
