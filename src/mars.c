
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/mars.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <assert.h>
#include <limits.h>
#include <string.h>

#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
#include <errno.h>
#endif

#include "rmem.h"
#include "root.h"
#include "async.h"
#include "target.h"
#include "file.h"
#include "filename.h"
#include "stringtable.h"

#include "mars.h"
#include "module.h"
#include "scope.h"
#include "mtype.h"
#include "id.h"
#include "cond.h"
#include "expression.h"
#include "parse.h"
#include "lib.h"
#include "json.h"
#include "declaration.h"
#include "hdrgen.h"
#include "doc.h"
#include "objc.h"

bool response_expand(Strings *arguments);


void browse(const char *url);
void getenv_setargv(const char *envvalue, Strings *args);

void printCtfePerformanceStats();

static const char* parse_arch_arg(Strings *args, const char* arch);
static const char* parse_conf_arg(Strings *args);

void inlineScan(Module *m);

// in traits.c
void initTraitsStringTable();

int runLINK();
void deleteExeFile();
int runProgram();

// inifile.c
const char *findConfFile(const char *argv0, const char *inifile);
const char *readFromEnv(StringTable *environment, const char *name);
void updateRealEnvironment(StringTable *environment);
void parseConfFile(StringTable *environment, const char *path, size_t len, unsigned char *buffer, Strings *sections);

void genObjFile(Module *m, bool multiobj);
void genhelpers(Module *m, bool iscomdat);

/** Normalize path by turning forward slashes into backslashes */
const char * toWinPath(const char *src)
{
    if (src == NULL)
        return NULL;

    char *result = strdup(src);
    char *p = result;
    while (*p != '\0')
    {
        if (*p == '/')
            *p = '\\';
        p++;
    }
    return result;
}

void readFile(Loc loc, File *f)
{
    if (f->read())
    {
        error(loc, "Error reading file '%s'", f->name->toChars());
        fatal();
    }
}

void writeFile(Loc loc, File *f)
{
    if (f->write())
    {
        error(loc, "Error writing file '%s'", f->name->toChars());
        fatal();
    }
}

void ensurePathToNameExists(Loc loc, const char *name)
{
    const char *pt = FileName::path(name);
    if (*pt)
    {
        if (FileName::ensurePathExists(pt))
        {
            error(loc, "cannot create directory %s", pt);
            fatal();
        }
    }
    FileName::free(pt);
}

extern void backend_init();
extern void backend_term();

static void logo()
{
    printf("DMD%llu D Compiler %s\n%s %s\n",
           (unsigned long long) sizeof(size_t) * 8,
        global.version, global.copyright, global.written);
}

static void usage()
{
#if TARGET_LINUX
    const char fpic[] ="\
  -fPIC          generate position independent code\n\
";
#else
    const char fpic[] = "";
#endif
    logo();
    printf("\
Documentation: http://dlang.org/\n\
Config file: %s\n\
Usage:\n\
  dmd files.d ... { -switch }\n\
\n\
  files.d        D source files\n\
  @cmdfile       read arguments from cmdfile\n\
  -allinst       generate code for all template instantiations\n\
  -boundscheck=[on|safeonly|off]   bounds checks on, in @safe only, or off\n\
  -c             do not link\n\
  -color[=on|off]   force colored console output on or off\n\
  -conf=path     use config file at path\n\
  -cov           do code coverage analysis\n\
  -cov=nnn       require at least nnn%% code coverage\n\
  -D             generate documentation\n\
  -Dddocdir      write documentation file to docdir directory\n\
  -Dffilename    write documentation file to filename\n\
  -d             silently allow deprecated features\n\
  -dw            show use of deprecated features as warnings (default)\n\
  -de            show use of deprecated features as errors (halt compilation)\n\
  -debug         compile in debug code\n\
  -debug=level   compile in debug code <= level\n\
  -debug=ident   compile in debug code identified by ident\n\
  -debuglib=name    set symbolic debug library to name\n\
  -defaultlib=name  set default library to name\n\
  -deps          print module dependencies (imports/file/version/debug/lib)\n\
  -deps=filename write module dependencies to filename (only imports)\n%s\
  -dip25         implement http://wiki.dlang.org/DIP25 (experimental)\n\
  -g             add symbolic debug info\n\
  -gc            add symbolic debug info, optimize for non D debuggers\n\
  -gs            always emit stack frame\n\
  -gx            add stack stomp code\n\
  -H             generate 'header' file\n\
  -Hddirectory   write 'header' file to directory\n\
  -Hffilename    write 'header' file to filename\n\
  --help         print help and exit\n\
  -Ipath         where to look for imports\n\
  -ignore        ignore unsupported pragmas\n\
  -inline        do function inlining\n\
  -Jpath         where to look for string imports\n\
  -Llinkerflag   pass linkerflag to link\n\
  -lib           generate library rather than object files\n\
  -m32           generate 32 bit code\n\
  -m64           generate 64 bit code\n\
  -main          add default main() (e.g. for unittesting)\n\
  -man           open web browser on manual page\n\
  -map           generate linker .map file\n\
  -noboundscheck no array bounds checking (deprecated, use -boundscheck=off)\n\
  -O             optimize\n\
  -o-            do not write object file\n\
  -odobjdir      write object & library files to directory objdir\n\
  -offilename    name output file to filename\n\
  -op            preserve source path for output files\n\
  -profile       profile runtime performance of generated code\n\
  -profile=gc    profile runtime allocations\n\
  -property      enforce property syntax\n\
  -release       compile release version\n\
  -run srcfile args...   run resulting program, passing args\n\
  -shared        generate shared library (DLL)\n\
  -transition=id show additional info about language change identified by 'id'\n\
  -transition=?  list all language changes\n\
  -unittest      compile in unit tests\n\
  -v             verbose\n\
  -vcolumns      print character (column) numbers in diagnostics\n\
  -verrors=num   limit the number of error messages (0 means unlimited)\n\
  -vgc           list all gc allocations including hidden ones\n\
  -vtls          list all variables going into thread local storage\n\
  --version      print compiler version and exit\n\
  -version=level compile in version code >= level\n\
  -version=ident compile in version code identified by ident\n\
  -w             warnings as errors (compilation will halt)\n\
  -wi            warnings as messages (compilation will continue)\n\
  -X             generate JSON file\n\
  -Xffilename    write JSON file to filename\n\
", FileName::canonicalName(global.inifilename), fpic);
}

extern signed char tyalignsize[];

static Module *entrypoint = NULL;
static Module *rootHasMain = NULL;

/************************************
 * Generate C main() in response to seeing D main().
 * This used to be in druntime, but contained a reference to _Dmain
 * which didn't work when druntime was made into a dll and was linked
 * to a program, such as a C++ program, that didn't have a _Dmain.
 */

void genCmain(Scope *sc)
{
    if (entrypoint)
        return;

    /* The D code to be generated is provided as D source code in the form of a string.
     * Note that Solaris, for unknown reasons, requires both a main() and an _main()
     */
    static const utf8_t cmaincode[] = "extern(C) {\n\
        int _d_run_main(int argc, char **argv, void* mainFunc);\n\
        int _Dmain(char[][] args);\n\
        int main(int argc, char **argv) { return _d_run_main(argc, argv, &_Dmain); }\n\
        version (Solaris) int _main(int argc, char** argv) { return main(argc, argv); }\n\
        }\n\
        ";

    Identifier *id = Id::entrypoint;
    Module *m = new Module("__entrypoint.d", id, 0, 0);

    Parser p(m, cmaincode, strlen((const char *)cmaincode), 0);
    p.scanloc = Loc();
    p.nextToken();
    m->members = p.parseModule();
    assert(p.token.value == TOKeof);
    assert(!p.errors);                  // shouldn't have failed to parse it

    bool v = global.params.verbose;
    global.params.verbose = false;
    m->importedFrom = m;
    m->importAll(NULL);
    m->semantic();
    m->semantic2();
    m->semantic3();
    global.params.verbose = v;

    entrypoint = m;
    rootHasMain = sc->module;
}

int tryMain(size_t argc, const char *argv[])
{
    Strings files;
    Strings libmodules;
    size_t argcstart = argc;
    bool setdebuglib = false;
#if TARGET_WINDOS
    bool setdefaultlib = false;
#endif
    global.init();

#ifdef DEBUG
    printf("DMD %s DEBUG\n", global.version);
#endif

    unittests();

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

    if (response_expand(&arguments))   // expand response files
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
    global.params.useArrayBounds = BOUNDSCHECKdefault;   // set correct value later
    global.params.useSwitchError = true;
    global.params.useInline = false;
    global.params.obj = true;
    global.params.useDeprecated = 2;

    global.params.linkswitches = new Strings();
    global.params.libfiles = new Strings();
    global.params.dllfiles = new Strings();
    global.params.objfiles = new Strings();
    global.params.ddocfiles = new Strings();

    // Default to -m32 for 32 bit dmd, -m64 for 64 bit dmd
    global.params.is64bit = (sizeof(size_t) == 8);

#if TARGET_WINDOS
    global.params.mscoff = false;
    global.params.is64bit = false;
    global.params.defaultlibname = "phobos";
#elif TARGET_LINUX
    global.params.defaultlibname = "libphobos2.a";
#elif TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    global.params.defaultlibname = "phobos2";
#else
#error "fix this"
#endif

    // Predefine version identifiers
    VersionCondition::addPredefinedGlobalIdent("DigitalMars");

#if TARGET_WINDOS
    VersionCondition::addPredefinedGlobalIdent("Windows");
    global.params.isWindows = true;
#elif TARGET_LINUX
    VersionCondition::addPredefinedGlobalIdent("Posix");
    VersionCondition::addPredefinedGlobalIdent("linux");
    VersionCondition::addPredefinedGlobalIdent("ELFv1");
    global.params.isLinux = true;
#elif TARGET_OSX
    VersionCondition::addPredefinedGlobalIdent("Posix");
    VersionCondition::addPredefinedGlobalIdent("OSX");
    VersionCondition::addPredefinedGlobalIdent("ELFv1");
    global.params.isOSX = true;

    // For legacy compatibility
    VersionCondition::addPredefinedGlobalIdent("darwin");
#elif TARGET_FREEBSD
    VersionCondition::addPredefinedGlobalIdent("Posix");
    VersionCondition::addPredefinedGlobalIdent("FreeBSD");
    VersionCondition::addPredefinedGlobalIdent("ELFv1");
    global.params.isFreeBSD = true;
#elif TARGET_OPENBSD
    VersionCondition::addPredefinedGlobalIdent("Posix");
    VersionCondition::addPredefinedGlobalIdent("OpenBSD");
    VersionCondition::addPredefinedGlobalIdent("ELFv1");
    global.params.isFreeBSD = true;
#elif TARGET_SOLARIS
    VersionCondition::addPredefinedGlobalIdent("Posix");
    VersionCondition::addPredefinedGlobalIdent("Solaris");
    VersionCondition::addPredefinedGlobalIdent("ELFv1");
    global.params.isSolaris = true;
#else
#error "fix this"
#endif

    VersionCondition::addPredefinedGlobalIdent("LittleEndian");
    VersionCondition::addPredefinedGlobalIdent("D_Version2");
    VersionCondition::addPredefinedGlobalIdent("all");

    global.inifilename = parse_conf_arg(&arguments);
    if (global.inifilename)
    {
        // can be empty as in -conf=
        if (strlen(global.inifilename) && !FileName::exists(global.inifilename))
            error(Loc(), "Config file '%s' does not exist.", global.inifilename);
    }
    else
    {
#if _WIN32
        global.inifilename = findConfFile(global.params.argv0, "sc.ini");
#elif __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
        global.inifilename = findConfFile(global.params.argv0, "dmd.conf");
#else
#error "fix this"
#endif
    }

    // Read the configurarion file
    File inifile(global.inifilename);
    inifile.read();

    /* Need path of configuration file, for use in expanding @P macro
     */
    const char *inifilepath = FileName::path(global.inifilename);

    Strings sections;

    StringTable environment;
    environment._init(7);

    /* Read the [Environment] section, so we can later
     * pick up any DFLAGS settings.
     */
    sections.push("Environment");
    parseConfFile(&environment, inifilepath, inifile.len, inifile.buffer, &sections);

    Strings dflags;
    getenv_setargv(readFromEnv(&environment, "DFLAGS"), &dflags);
    environment.reset(7);               // erase cached environment updates

    const char *arch = global.params.is64bit ? "64" : "32"; // use default
    arch = parse_arch_arg(&arguments, arch);
    arch = parse_arch_arg(&dflags, arch);
    bool is64bit = arch[0] == '6';

    char envsection[80];
    sprintf(envsection, "Environment%s", arch);
    sections.push(envsection);
    parseConfFile(&environment, inifilepath, inifile.len, inifile.buffer, &sections);

    getenv_setargv(readFromEnv(&environment, "DFLAGS"), &arguments);

    updateRealEnvironment(&environment);
    environment.reset(1);               // don't need environment cache any more

#if 0
    for (size_t i = 0; i < arguments.dim; i++)
    {
        printf("arguments[%d] = '%s'\n", i, arguments[i]);
    }
#endif

    for (size_t i = 1; i < arguments.dim; i++)
    {
        const char *p = arguments[i];
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
            else if (memcmp(p + 1, "color", 5) == 0)
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
            else if (memcmp(p + 1, "conf=", 5) == 0)
            {
                // ignore, already handled above
            }
            else if (memcmp(p + 1, "cov", 3) == 0)
            {
                global.params.cov = true;
                // Parse:
                //      -cov
                //      -cov=nnn
                if (p[4] == '=')
                {
                    if (isdigit((utf8_t)p[5]))
                    {   long percent;

                        errno = 0;
                        percent = strtol(p + 5, (char **)&p, 10);
                        if (*p || errno || percent > 100)
                            goto Lerror;
                        global.params.covPercent = (unsigned char)percent;
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
#if TARGET_OSX
                warning(Loc(), "use -shared instead of -dylib");
                global.params.dll = true;
#else
                goto Lerror;
#endif
            }
            else if (strcmp(p + 1, "fPIC") == 0)
            {
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
                global.params.pic = 1;
#else
                goto Lerror;
#endif
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
            {   error(Loc(), "use -profile instead of -gt");
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
                global.params.mscoff = true;
            }
            else if (strcmp(p + 1, "m32mscoff") == 0)
            {
            #if TARGET_WINDOS
                global.params.is64bit = 0;
                global.params.mscoff = true;
            #else
                error(Loc(), "-m32mscoff can only be used on windows");
            #endif
            }
            else if (memcmp(p + 1, "profile", 7) == 0)
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
            else if (memcmp(p + 1, "verrors", 7) == 0)
            {
                if (p[8] == '=' && isdigit((utf8_t)p[9]))
                {
                    long num;
                    errno = 0;
                    num = strtol(p + 9, (char **)&p, 10);
                    if (*p || errno || num > INT_MAX)
                        goto Lerror;
                    // Bugzilla issue number
                    global.errorLimit = (unsigned) num;
                }
                else
                    goto Lerror;
            }
            else if (memcmp(p + 1, "transition", 10) == 0)
            {
                // Parse:
                //      -transition=number
                if (p[11] == '=')
                {
                    if (strcmp(p + 12, "?") == 0)
                    {
                        printf("\
Language changes listed by -transition=id:\n\
  =all           list information on all language changes\n\
  =complex,14488 list all usages of complex or imaginary types\n\
  =field,3449    list all non-mutable fields which occupy an object instance\n\
  =tls           list all variables going into thread local storage\n\
");
                        return EXIT_FAILURE;
                    }
                    if (isdigit((utf8_t)p[12]))
                    {   long num;

                        errno = 0;
                        num = strtol(p + 12, (char **)&p, 10);
                        if (*p || errno || num > INT_MAX)
                            goto Lerror;
                        // Bugzilla issue number
                        switch (num)
                        {
                            case 3449:
                                global.params.vfield = true;
                                break;
                            case 14488:
                                global.params.vcomplex = true;
                                break;
                            default:
                                goto Lerror;
                        }
                    }
                    else if (Lexer::isValidIdentifier(p + 12))
                    {
                        const char *ident = p + 12;
                        switch (strlen(ident))
                        {
                            case 3:
                                if (strcmp(ident, "all") == 0)
                                {
                                    global.params.vtls = true;
                                    global.params.vfield = true;
                                    global.params.vcomplex = true;
                                    break;
                                }
                                if (strcmp(ident, "tls") == 0)
                                {
                                    global.params.vtls = true;
                                    break;
                                }
                                goto Lerror;

                            case 5:
                                if (strcmp(ident, "field") == 0)
                                {
                                    global.params.vfield = true;
                                    break;
                                }
                                goto Lerror;

                            case 7:
                                if (strcmp(ident, "complex") == 0)
                                {
                                    global.params.vcomplex = true;
                                    break;
                                }
                                goto Lerror;

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
                const char *path;
                switch (p[2])
                {
                    case '-':
                        global.params.obj = false;
                        break;

                    case 'd':
                        if (!p[3])
                            goto Lnoarg;
                        path = p + 3;
#if _WIN32
                        path = toWinPath(path);
#endif
                        global.params.objdir = path;
                        break;

                    case 'f':
                        if (!p[3])
                            goto Lnoarg;
                        path = p + 3;
#if _WIN32
                        path = toWinPath(path);
#endif
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
                        global.params.docdir = p + 3;
                        break;
                    case 'f':
                        if (!p[3])
                            goto Lnoarg;
                        global.params.docname = p + 3;
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
                        global.params.hdrdir = p + 3;
                        break;

                    case 'f':
                        if (!p[3])
                            goto Lnoarg;
                        global.params.hdrname = p + 3;
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
                        global.params.jsonfilename = p + 3;
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
                global.params.useInline = true;
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
            else if (memcmp(p + 1, "boundscheck", 11) == 0)
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
                global.params.imppath->push(p + 2);
            }
            else if (p[1] == 'J')
            {
                if (!global.params.fileImppath)
                    global.params.fileImppath = new Strings();
                global.params.fileImppath->push(p + 2);
            }
            else if (memcmp(p + 1, "debug", 5) == 0 && p[6] != 'l')
            {
                // Parse:
                //      -debug
                //      -debug=number
                //      -debug=identifier
                if (p[6] == '=')
                {
                    if (isdigit((utf8_t)p[7]))
                    {   long level;

                        errno = 0;
                        level = strtol(p + 7, (char **)&p, 10);
                        if (*p || errno || level > INT_MAX)
                            goto Lerror;
                        DebugCondition::setGlobalLevel((int)level);
                    }
                    else if (Lexer::isValidIdentifier(p + 7))
                        DebugCondition::addGlobalIdent(p + 7);
                    else
                        goto Lerror;
                }
                else if (p[6])
                    goto Lerror;
                else
                    global.params.debuglevel = 1;
            }
            else if (memcmp(p + 1, "version", 7) == 0)
            {
                // Parse:
                //      -version=number
                //      -version=identifier
                if (p[8] == '=')
                {
                    if (isdigit((utf8_t)p[9]))
                    {   long level;

                        errno = 0;
                        level = strtol(p + 9, (char **)&p, 10);
                        if (*p || errno || level > INT_MAX)
                            goto Lerror;
                        VersionCondition::setGlobalLevel((int)level);
                    }
                    else if (Lexer::isValidIdentifier(p + 9))
                        VersionCondition::addGlobalIdent(p + 9);
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
            else if (strcmp(p + 1, "-help") == 0)
            {   usage();
                exit(EXIT_SUCCESS);
            }
            else if (strcmp(p + 1, "-r") == 0)
                global.params.debugr = true;
            else if (strcmp(p + 1, "-version") == 0)
            {   logo();
                exit(EXIT_SUCCESS);
            }
            else if (strcmp(p + 1, "-x") == 0)
                global.params.debugx = true;
            else if (strcmp(p + 1, "-y") == 0)
                global.params.debugy = true;
            else if (p[1] == 'L')
            {
                global.params.linkswitches->push(p + 2);
            }
            else if (memcmp(p + 1, "defaultlib=", 11) == 0)
            {
#if TARGET_WINDOS
                setdefaultlib = true;
#endif
                global.params.defaultlibname = p + 1 + 11;
            }
            else if (memcmp(p + 1, "debuglib=", 9) == 0)
            {
                setdebuglib = true;
                global.params.debuglibname = p + 1 + 9;
            }
            else if (memcmp(p + 1, "deps", 4) == 0)
            {
                if(global.params.moduleDeps)
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
                else if (p[5]!='\0')
                {
                    // Else output to stdout.
                    goto Lerror;
                }
                global.params.moduleDeps = new OutBuffer;
            }
            else if (strcmp(p + 1, "main") == 0)
            {
                global.params.addMain = true;
            }
            else if (memcmp(p + 1, "man", 3) == 0)
            {
#if _WIN32
                browse("http://dlang.org/dmd-windows.html");
#endif
#if __linux__
                browse("http://dlang.org/dmd-linux.html");
#endif
#if __APPLE__
                browse("http://dlang.org/dmd-osx.html");
#endif
#if __FreeBSD__
                browse("http://dlang.org/dmd-freebsd.html");
#endif
#if __OpenBSD__
                browse("http://dlang.org/dmd-openbsd.html");
#endif
                exit(EXIT_SUCCESS);
            }
            else if (strcmp(p + 1, "run") == 0)
            {
                global.params.run = true;
                size_t length = ((i >= argcstart) ? argc : argcstart) - i - 1;
                if (length)
                {
                    const char *ext = FileName::ext(arguments[i + 1]);
                    if (ext && FileName::equals(ext, "d") == 0
                            && FileName::equals(ext, "di") == 0)
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
#if TARGET_WINDOS
            const char *ext = FileName::ext(p);
            if (ext && FileName::compare(ext, "exe") == 0)
            {
                global.params.objname = p;
                continue;
            }
#endif
            files.push(p);
        }
    }

    if(global.params.is64bit != is64bit)
        error(Loc(), "the architecture must not be changed in the %s section of %s",
              envsection, global.inifilename);

    // Target uses 64bit pointers.
    global.params.isLP64 = global.params.is64bit;

    if (global.errors)
    {
        fatal();
    }
    if (files.dim == 0)
    {   usage();
        return EXIT_FAILURE;
    }

    if (!setdebuglib)
        global.params.debuglibname = global.params.defaultlibname;

#if TARGET_OSX
    global.params.pic = 1;
#endif

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    if (global.params.lib && global.params.dll)
        error(Loc(), "cannot mix -lib and -shared");
#endif

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
            global.params.objname = const_cast<char *>(FileName::forceExt(global.params.objname, global.obj_ext));

            /* If output directory is given, use that path rather than
             * the exe file path.
             */
            if (global.params.objdir)
            {   const char *name = FileName::name(global.params.objname);
                global.params.objname = (char *)FileName::combine(global.params.objdir, name);
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
        global.params.objname = NULL;

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
    if (global.params.is64bit)
    {
        VersionCondition::addPredefinedGlobalIdent("D_InlineAsm_X86_64");
        VersionCondition::addPredefinedGlobalIdent("X86_64");
        VersionCondition::addPredefinedGlobalIdent("D_SIMD");
#if TARGET_WINDOS
        VersionCondition::addPredefinedGlobalIdent("Win64");
        if (!setdefaultlib)
        {   global.params.defaultlibname = "phobos64";
            if (!setdebuglib)
                global.params.debuglibname = global.params.defaultlibname;
        }
#endif
    }
    else
    {
        VersionCondition::addPredefinedGlobalIdent("D_InlineAsm"); //legacy
        VersionCondition::addPredefinedGlobalIdent("D_InlineAsm_X86");
        VersionCondition::addPredefinedGlobalIdent("X86");
#if TARGET_OSX
        VersionCondition::addPredefinedGlobalIdent("D_SIMD");
#endif
#if TARGET_WINDOS
        VersionCondition::addPredefinedGlobalIdent("Win32");
        if (!setdefaultlib && global.params.mscoff)
        {
            global.params.defaultlibname = "phobos32mscoff";
            if (!setdebuglib)
                global.params.debuglibname = global.params.defaultlibname;
        }
#endif
    }
#if TARGET_WINDOS
    if (global.params.mscoff)
        VersionCondition::addPredefinedGlobalIdent("CRuntime_Microsoft");
    else
        VersionCondition::addPredefinedGlobalIdent("CRuntime_DigitalMars");
#elif TARGET_LINUX
    VersionCondition::addPredefinedGlobalIdent("CRuntime_Glibc");
#endif
    if (global.params.isLP64)
        VersionCondition::addPredefinedGlobalIdent("D_LP64");
    if (global.params.doDocComments)
        VersionCondition::addPredefinedGlobalIdent("D_Ddoc");
    if (global.params.cov)
        VersionCondition::addPredefinedGlobalIdent("D_Coverage");
    if (global.params.pic)
        VersionCondition::addPredefinedGlobalIdent("D_PIC");
    if (global.params.useUnitTests)
        VersionCondition::addPredefinedGlobalIdent("unittest");
    if (global.params.useAssert)
        VersionCondition::addPredefinedGlobalIdent("assert");
    if (global.params.useArrayBounds == BOUNDSCHECKoff)
        VersionCondition::addPredefinedGlobalIdent("D_NoBoundsChecks");

    VersionCondition::addPredefinedGlobalIdent("D_HardFloat");
    objc_tryMain_dObjc();

    // Initialization
    Lexer::initLexer();
    Type::init();
    Id::initialize();
    Module::init();
    Target::init();
    Expression::init();
    objc_tryMain_init();
    initPrecedence();
    builtin_init();
    initTraitsStringTable();

    if (global.params.verbose)
    {   fprintf(global.stdmsg, "binary    %s\n", global.params.argv0);
        fprintf(global.stdmsg, "version   %s\n", global.version);
        fprintf(global.stdmsg, "config    %s\n", global.inifilename ? global.inifilename
                                                                    : "(none)");
    }

    //printf("%d source files\n",files.dim);

    // Build import search path
    if (global.params.imppath)
    {
        for (size_t i = 0; i < global.params.imppath->dim; i++)
        {
            const char *path = (*global.params.imppath)[i];
            Strings *a = FileName::splitPath(path);

            if (a)
            {
                if (!global.path)
                    global.path = new Strings();
                global.path->append(a);
            }
        }
    }

    // Build string import search path
    if (global.params.fileImppath)
    {
        for (size_t i = 0; i < global.params.fileImppath->dim; i++)
        {
            const char *path = (*global.params.fileImppath)[i];
            Strings *a = FileName::splitPath(path);

            if (a)
            {
                if (!global.filePath)
                    global.filePath = new Strings();
                global.filePath->append(a);
            }
        }
    }

    if (global.params.addMain)
    {
        files.push(const_cast<char*>(global.main_d)); // a dummy name, we never actually look up this file
    }

    // Create Modules
    Modules modules;
    modules.reserve(files.dim);
    bool firstmodule = true;
    for (size_t i = 0; i < files.dim; i++)
    {
        const char *name;

#if _WIN32
        files[i] = toWinPath(files[i]);
#endif

        const char *p = files[i];

        p = FileName::name(p);          // strip path
        const char *ext = FileName::ext(p);
        char *newname;
        if (ext)
        {   /* Deduce what to do with a file based on its extension
             */
            if (FileName::equals(ext, global.obj_ext))
            {
                global.params.objfiles->push(files[i]);
                libmodules.push(files[i]);
                continue;
            }

            if (FileName::equals(ext, global.lib_ext))
            {
                global.params.libfiles->push(files[i]);
                libmodules.push(files[i]);
                continue;
            }

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
            if (FileName::equals(ext, global.dll_ext))
            {
                global.params.dllfiles->push(files[i]);
                libmodules.push(files[i]);
                continue;
            }
#endif

            if (strcmp(ext, global.ddoc_ext) == 0)
            {
                global.params.ddocfiles->push(files[i]);
                continue;
            }

            if (FileName::equals(ext, global.json_ext))
            {
                global.params.doJsonGeneration = true;
                global.params.jsonfilename = files[i];
                continue;
            }

            if (FileName::equals(ext, global.map_ext))
            {
                global.params.mapfile = files[i];
                continue;
            }

#if TARGET_WINDOS
            if (FileName::equals(ext, "res"))
            {
                global.params.resfile = files[i];
                continue;
            }

            if (FileName::equals(ext, "def"))
            {
                global.params.deffile = files[i];
                continue;
            }

            if (FileName::equals(ext, "exe"))
            {
                assert(0);      // should have already been handled
            }
#endif

            /* Examine extension to see if it is a valid
             * D source file extension
             */
            if (FileName::equals(ext, global.mars_ext) ||
                FileName::equals(ext, global.hdr_ext) ||
                FileName::equals(ext, "dd"))
            {
                ext--;                  // skip onto '.'
                assert(*ext == '.');
                newname = (char *)mem.xmalloc((ext - p) + 1);
                memcpy(newname, p, ext - p);
                newname[ext - p] = 0;              // strip extension
                name = newname;

                if (name[0] == 0 ||
                    strcmp(name, "..") == 0 ||
                    strcmp(name, ".") == 0)
                {
                Linvalid:
                    error(Loc(), "invalid file name '%s'", files[i]);
                    fatal();
                }
            }
            else
            {   error(Loc(), "unrecognized file extension %s", ext);
                fatal();
            }
        }
        else
        {   name = p;
            if (!*name)
                goto Linvalid;
        }

        /* At this point, name is the D source file name stripped of
         * its path and extension.
         */

        Identifier *id = Identifier::idPool(name);
        Module *m = new Module(files[i], id, global.params.doDocComments, global.params.doHdrGeneration);
        modules.push(m);

        if (firstmodule)
        {   global.params.objfiles->push(m->objfile->name->str);
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
            Module *m = modules[i];
            if (strcmp(m->srcfile->name->str, global.main_d) == 0)
            {
                static const char buf[] = "int main(){return 0;}";
                m->srcfile->setbuffer((void *)buf, sizeof(buf));
                m->srcfile->ref = 1;
                break;
            }
        }
    }

#define ASYNCREAD 1
#if ASYNCREAD
    // Multi threaded
    AsyncRead *aw = AsyncRead::create(modules.dim);
    for (size_t i = 0; i < modules.dim; i++)
    {
        Module *m = modules[i];
        aw->addFile(m->srcfile);
    }
    aw->start();
#else
    // Single threaded
    for (size_t i = 0; i < modules.dim; i++)
    {
        Module *m = modules[i];
        m->read(Loc());
    }
#endif

    // Parse files
    bool anydocfiles = false;
    size_t filecount = modules.dim;
    for (size_t filei = 0, modi = 0; filei < filecount; filei++, modi++)
    {
        Module *m = modules[modi];
        if (global.params.verbose)
            fprintf(global.stdmsg, "parse     %s\n", m->toChars());
        if (!Module::rootModule)
            Module::rootModule = m;
        m->importedFrom = m;    // m->isRoot() == true
        if (!global.params.oneobj || modi == 0 || m->isDocFile)
            m->deleteObjFile();
#if ASYNCREAD
        if (aw->read(filei))
        {
            error(Loc(), "cannot read file %s", m->srcfile->name->toChars());
            fatal();
        }
#endif
        m->parse();
        if (m->isDocFile)
        {
            anydocfiles = true;
            gendocfile(m);

            // Remove m from list of modules
            modules.remove(modi);
            modi--;

            // Remove m's object file from list of object files
            for (size_t j = 0; j < global.params.objfiles->dim; j++)
            {
                if (m->objfile->name->str == (*global.params.objfiles)[j])
                {
                    global.params.objfiles->remove(j);
                    break;
                }
            }

            if (global.params.objfiles->dim == 0)
                global.params.link = false;
        }
    }
#if ASYNCREAD
    AsyncRead::dispose(aw);
#endif

    if (anydocfiles && modules.dim &&
        (global.params.oneobj || global.params.objname))
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
            Module *m = modules[i];
            if (global.params.verbose)
                fprintf(global.stdmsg, "import    %s\n", m->toChars());
            genhdrfile(m);
        }
    }
    if (global.errors)
        fatal();

    // load all unconditional imports for better symbol resolving
    for (size_t i = 0; i < modules.dim; i++)
    {
       Module *m = modules[i];
       if (global.params.verbose)
           fprintf(global.stdmsg, "importall %s\n", m->toChars());
       m->importAll(NULL);
    }
    if (global.errors)
        fatal();

    backend_init();

    // Do semantic analysis
    for (size_t i = 0; i < modules.dim; i++)
    {
        Module *m = modules[i];
        if (global.params.verbose)
            fprintf(global.stdmsg, "semantic  %s\n", m->toChars());
        m->semantic();
    }
    if (global.errors)
        fatal();

    Module::dprogress = 1;
    Module::runDeferredSemantic();
    if (Module::deferred.dim)
    {
        for (size_t i = 0; i < Module::deferred.dim; i++)
        {
            Dsymbol *sd = Module::deferred[i];
            sd->error("unable to resolve forward reference in definition");
        }
        fatal();
    }

    // Do pass 2 semantic analysis
    for (size_t i = 0; i < modules.dim; i++)
    {
        Module *m = modules[i];
        if (global.params.verbose)
            fprintf(global.stdmsg, "semantic2 %s\n", m->toChars());
        m->semantic2();
    }
    if (global.errors)
        fatal();

    // Do pass 3 semantic analysis
    for (size_t i = 0; i < modules.dim; i++)
    {
        Module *m = modules[i];
        if (global.params.verbose)
            fprintf(global.stdmsg, "semantic3 %s\n", m->toChars());
        m->semantic3();
    }
    Module::runDeferredSemantic3();
    if (global.errors)
        fatal();

    // Scan for functions to inline
    if (global.params.useInline)
    {
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module *m = modules[i];
            if (global.params.verbose)
                fprintf(global.stdmsg, "inline scan %s\n", m->toChars());
            inlineScan(m);
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
            File deps(global.params.moduleDepsFile);
            deps.setbuffer((void*)ob->data, ob->offset);
            writeFile(Loc(), &deps);
        }
        else
            printf("%.*s", (int)ob->offset, ob->data);
    }

    printCtfePerformanceStats();

    Library *library = NULL;
    if (global.params.lib)
    {
        library = Library::factory();
        library->setFilename(global.params.objdir, global.params.libname);

        // Add input object and input library files to output library
        for (size_t i = 0; i < libmodules.dim; i++)
        {
            const char *p = libmodules[i];
            library->addObject(p, NULL, 0);
        }
    }

    // Generate output files

    if (global.params.doJsonGeneration)
    {
        OutBuffer buf;
        json_generate(&buf, &modules);

        // Write buf to file
        const char *name = global.params.jsonfilename;

        if (name && name[0] == '-' && name[1] == 0)
        {   // Write to stdout; assume it succeeds
            size_t n = fwrite(buf.data, 1, buf.offset, stdout);
            assert(n == buf.offset);        // keep gcc happy about return values
        }
        else
        {
            /* The filename generation code here should be harmonized with Module::setOutfile()
             */

            const char *jsonfilename;

            if (name && *name)
            {
                jsonfilename = FileName::defaultExt(name, global.json_ext);
            }
            else
            {
                // Generate json file name from first obj name
                const char *n = (*global.params.objfiles)[0];
                n = FileName::name(n);

                //if (!FileName::absolute(name))
                    //name = FileName::combine(dir, name);

                jsonfilename = FileName::forceExt(n, global.json_ext);
            }

            ensurePathToNameExists(Loc(), jsonfilename);

            File *jsonfile = new File(jsonfilename);

            jsonfile->setbuffer(buf.data, buf.offset);
            jsonfile->ref = 1;
            writeFile(Loc(), jsonfile);
        }
    }

    if (!global.errors && global.params.doDocComments)
    {
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module *m = modules[i];
            gendocfile(m);
        }
    }

    if (!global.params.obj)
    {
    }
    else if (global.params.oneobj)
    {
        if (modules.dim)
            obj_start(modules[0]->srcfile->toChars());
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module *m = modules[i];
            if (global.params.verbose)
                fprintf(global.stdmsg, "code      %s\n", m->toChars());
            genObjFile(m, false);
            if (entrypoint && m == rootHasMain)
                genObjFile(entrypoint, false);
        }
        for (size_t i = 0; i < Module::amodules.dim; i++)
        {
            Module *m = Module::amodules[i];
            if (!m->isRoot() && (m->marray || m->massert || m->munittest))
                genhelpers(m, true);
        }
        if (!global.errors && modules.dim)
        {
            obj_end(library, modules[0]->objfile);
        }
    }
    else
    {
        for (size_t i = 0; i < modules.dim; i++)
        {
            Module *m = modules[i];
            if (global.params.verbose)
                fprintf(global.stdmsg, "code      %s\n", m->toChars());

            obj_start(m->srcfile->toChars());
            genObjFile(m, global.params.multiobj);
            if (entrypoint && m == rootHasMain)
                genObjFile(entrypoint, global.params.multiobj);
            for (size_t j = 0; j < Module::amodules.dim; j++)
            {
                Module *mx = Module::amodules[j];
                if (mx != m && mx->importedFrom == m && (mx->marray || mx->massert || mx->munittest))
                    genhelpers(mx, true);
            }
            obj_end(library, m->objfile);
            obj_write_deferred(library);

            if (global.errors && !global.params.lib)
                m->deleteObjFile();
        }
    }

    if (global.params.lib && !global.errors)
        library->write();

    backend_term();
    if (global.errors)
        fatal();

    int status = EXIT_SUCCESS;
    if (!global.params.objfiles->dim)
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
                    modules[i]->deleteObjFile();
                    if (global.params.oneobj)
                        break;
                }
                deleteExeFile();
            }
        }
    }

    return status;
}

int main(int argc, const char *argv[])
{
    int status = -1;

    status = tryMain(argc, argv);

    return status;
}


/***********************************
 * Parse and append contents of command line string envvalue to args[].
 * The string is separated into arguments, processing \ and ".
 */

void getenv_setargv(const char *envvalue, Strings *args)
{
    if (!envvalue)
        return;

    char *p;

    int instring;
    int slash;
    char c;

    char *env = mem.xstrdup(envvalue);      // create our own writable copy
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
                args->push(env);                // append
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
                            {   p--;
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
                                //wildcardexpand();     // not implemented
                            break;

                        case '\\':
                            slash++;
                            *p++ = c;
                            continue;

                        case 0:
                            *p = 0;
                            //if (wildcard)
                                //wildcardexpand();     // not implemented
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

void escapePath(OutBuffer *buf, const char *fname)
{
    while (1)
    {
        switch (*fname)
        {
            case 0:
                return;
            case '(':
            case ')':
            case '\\':
                buf->writeByte('\\');
            default:
                buf->writeByte(*fname);
                break;
        }
        fname++;
    }
}


/***********************************
 * Parse command line arguments for -m32 or -m64
 * to detect the desired architecture.
 */

static const char* parse_arch_arg(Strings *args, const char* arch)
{
    for (size_t i = 0; i < args->dim; ++i)
    {
        const char* p = (*args)[i];
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

/***********************************
 * Parse command line arguments for -conf=path.
 */

static const char* parse_conf_arg(Strings *args)
{
    const char *conf=NULL;
    for (size_t i = 0; i < args->dim; ++i)
    {
        const char* p = (*args)[i];
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

Dsymbols *Dsymbols_create() { return new Dsymbols(); }
VarDeclarations *VarDeclarations_create() { return new VarDeclarations(); }
Expressions *Expressions_create() { return new Expressions(); }
