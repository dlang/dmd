
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_MARS_H
#define DMD_MARS_H

#ifdef __DMC__
#pragma once
#endif

/*
It is very important to use version control macros correctly - the
idea is that host and target are independent. If these are done
correctly, cross compilers can be built.
The host compiler and host operating system are also different,
and are predefined by the host compiler. The ones used in
dmd are:

Macros defined by the compiler, not the code:

    Compiler:
        __DMC__         Digital Mars compiler
        _MSC_VER        Microsoft compiler
        __GNUC__        Gnu compiler
        __clang__       Clang compiler

    Host operating system:
        _WIN32          Microsoft NT, Windows 95, Windows 98, Win32s,
                        Windows 2000, Win XP, Vista
        _WIN64          Windows for AMD64
        __linux__       Linux
        __APPLE__       Mac OSX
        __FreeBSD__     FreeBSD
        __OpenBSD__     OpenBSD
        __sun           Solaris, OpenSolaris, SunOS, OpenIndiana, etc

For the target systems, there are the target operating system and
the target object file format:

    Target operating system:
        TARGET_WINDOS   Covers 32 bit windows and 64 bit windows
        TARGET_LINUX    Covers 32 and 64 bit linux
        TARGET_OSX      Covers 32 and 64 bit Mac OSX
        TARGET_FREEBSD  Covers 32 and 64 bit FreeBSD
        TARGET_OPENBSD  Covers 32 and 64 bit OpenBSD
        TARGET_SOLARIS  Covers 32 and 64 bit Solaris

    It is expected that the compiler for each platform will be able
    to generate 32 and 64 bit code from the same compiler binary.

    There are currently no macros for byte endianness order.
 */


#include <stdio.h>
#include <stdint.h>
#include <stdarg.h>

#ifdef __DMC__
#ifdef DEBUG
#undef assert
#define assert(e) (static_cast<void>((e) || (printf("assert %s(%d) %s\n", __FILE__, __LINE__, #e), halt())))
#endif
#endif

void unittests();

#define DMDV1   0
#define DMDV2   1       // Version 2.0 features

// Objective-C Support
#define DMD_OBJC (DMDV2 && TARGET_OSX && D_OBJC)

struct OutBuffer;

// Can't include arraytypes.h here, need to declare these directly.
template <typename TYPE> struct Array;
typedef Array<class Identifier *> Identifiers;
typedef Array<const char *> Strings;

// Put command line switches in here
struct Param
{
    char obj;           // write object file
    char link;          // perform link
    char dll;           // generate shared dynamic library
    char lib;           // write library file instead of object file(s)
    char multiobj;      // break one object file into multiple ones
    char oneobj;        // write one object file instead of multiple ones
    bool trace;         // insert profiling hooks
    char quiet;         // suppress non-error messages
    char verbose;       // verbose compile
    char vtls;          // identify thread local variables
    char vfield;        // identify non-mutable field variables
    char symdebug;      // insert debug symbolic information
    bool alwaysframe;   // always emit standard stack frame
    bool optimize;      // run optimizer
    char map;           // generate linker .map file
    bool is64bit;       // generate 64 bit code
    char isLP64;        // generate code for LP64
    char isLinux;       // generate code for linux
    char isOSX;         // generate code for Mac OSX
    char isWindows;     // generate code for Windows
    char isFreeBSD;     // generate code for FreeBSD
    char isOpenBSD;     // generate code for OpenBSD
    char isSolaris;     // generate code for Solaris
    char scheduler;     // which scheduler to use
    char useDeprecated; // 0: don't allow use of deprecated features
                        // 1: silently allow use of deprecated features
                        // 2: warn about the use of deprecated features
    char useAssert;     // generate runtime code for assert()'s
    char useInvariants; // generate class invariant checks
    char useIn;         // generate precondition checks
    char useOut;        // generate postcondition checks
    char useArrayBounds; // 0: no array bounds checks
                         // 1: array bounds checks for safe functions only
                         // 2: array bounds checks for all functions
    char noboundscheck; // no array bounds checking at all
    bool stackstomp;    // add stack stomping code
    char useSwitchError; // check for switches without a default
    char useUnitTests;  // generate unittest code
    char useInline;     // inline expand functions
    char release;       // build release version
    char preservePaths; // !=0 means don't strip path from source file
    char warnings;      // 0: enable warnings
                        // 1: warnings as errors
                        // 2: informational warnings (no errors)
    bool pic;           // generate position-independent-code for shared libs
    bool cov;           // generate code coverage data
    unsigned char covPercent;   // 0..100 code coverage percentage required
    bool nofloat;       // code should not pull in floating point support
    char ignoreUnsupportedPragmas;      // rather than error on them
    char enforcePropertySyntax;
    char betterC;       // be a "better C" compiler; no dependency on D runtime
    bool addMain;       // add a default main() function
    bool allInst;       // generate code for all template instantiations

    const char *argv0;    // program name
    Strings *imppath;     // array of char*'s of where to look for import modules
    Strings *fileImppath; // array of char*'s of where to look for file import modules
    const char *objdir;   // .obj/.lib file output directory
    const char *objname;  // .obj file output name
    const char *libname;  // .lib file output name

    char doDocComments;  // process embedded documentation comments
    const char *docdir;  // write documentation file to docdir directory
    const char *docname; // write documentation file to docname
    Strings *ddocfiles;  // macro include files for Ddoc

    char doHdrGeneration;  // process embedded documentation comments
    const char *hdrdir;    // write 'header' file to docdir directory
    const char *hdrname;   // write 'header' file to docname

    char doXGeneration;    // write JSON file
    const char *xfilename; // write JSON file to xfilename

    unsigned debuglevel;   // debug level
    Strings *debugids;     // debug identifiers

    unsigned versionlevel; // version level
    Strings *versionids;   // version identifiers

    const char *defaultlibname; // default library for non-debug builds
    const char *debuglibname;   // default library for debug builds

    const char *moduleDepsFile; // filename for deps output
    OutBuffer *moduleDeps;      // contents to be written to deps file

    // Hidden debug switches
    char debuga;
    char debugb;
    char debugc;
    char debugf;
    char debugr;
    char debugw;
    char debugx;
    char debugy;

    char run;           // run resulting executable
    size_t runargs_length;
    const char** runargs; // arguments for executable

    // Linker stuff
    Strings *objfiles;
    Strings *linkswitches;
    Strings *libfiles;
    const char *deffile;
    const char *resfile;
    const char *exefile;
    const char *mapfile;
};

struct Compiler
{
    const char *vendor;     // Compiler backend name
};

typedef unsigned structalign_t;
#define STRUCTALIGN_DEFAULT ((structalign_t) ~0)  // magic value means "match whatever the underlying C compiler does"
// other values are all powers of 2

struct Ungag
{
    unsigned oldgag;

    Ungag(unsigned old) : oldgag(old) {}
    ~Ungag();
};

struct Global
{
    const char *mars_ext;
    const char *sym_ext;
    const char *obj_ext;
    const char *lib_ext;
    const char *dll_ext;
    const char *doc_ext;        // for Ddoc generated files
    const char *ddoc_ext;       // for Ddoc macro include files
    const char *hdr_ext;        // for D 'header' import files
    const char *json_ext;       // for JSON files
    const char *map_ext;        // for .map files
    bool run_noext;             // allow -run sources without extensions.

    const char *copyright;
    const char *written;
    const char *main_d;         // dummy filename for dummy main()
    Strings *path;        // Array of char*'s which form the import lookup path
    Strings *filePath;    // Array of char*'s which form the file import lookup path

    const char *version;

    Compiler compiler;
    Param params;
    unsigned errors;       // number of errors reported so far
    unsigned warnings;     // number of warnings reported so far
    FILE *stdmsg;          // where to send verbose messages
    unsigned gag;          // !=0 means gag reporting of errors & warnings
    unsigned gaggedErrors; // number of errors reported while gagged

    /* Gagging can either be speculative (is(typeof()), etc)
     * or because of forward references
     */
    unsigned speculativeGag; // == gag means gagging is for is(typeof);
    bool isSpeculativeGagging();

    // Start gagging. Return the current number of gagged errors
    unsigned startGagging();

    /* End gagging, restoring the old gagged state.
     * Return true if errors occured while gagged.
     */
    bool endGagging(unsigned oldGagged);

    /*  Increment the error count to record that an error
     *  has occured in the current context. An error message
     *  may or may not have been printed.
     */
    void increaseErrorCount();

    void init();
};

extern Global global;

#include "longdouble.h"

#include "complex_t.h"

// Be careful not to care about sign when using dinteger_t
typedef uint64_t dinteger_t;    // use this instead of integer_t to
                                // avoid conflicts with system #include's

// Signed and unsigned variants
typedef int64_t sinteger_t;
typedef uint64_t uinteger_t;

typedef int8_t                  d_int8;
typedef uint8_t                 d_uns8;
typedef int16_t                 d_int16;
typedef uint16_t                d_uns16;
typedef int32_t                 d_int32;
typedef uint32_t                d_uns32;
typedef int64_t                 d_int64;
typedef uint64_t                d_uns64;

typedef float                   d_float32;
typedef double                  d_float64;
typedef longdouble              d_float80;

typedef d_uns8                  d_char;
typedef d_uns16                 d_wchar;
typedef d_uns32                 d_dchar;

typedef longdouble real_t;


class Module;

//typedef unsigned Loc;         // file location
struct Loc
{
    const char *filename;
    unsigned linnum;

    Loc()
    {
        linnum = 0;
        filename = NULL;
    }

    Loc(Module *mod, unsigned linnum);

    char *toChars();
    bool equals(const Loc& loc);
};

enum LINK
{
    LINKdefault,
    LINKd,
    LINKc,
    LINKcpp,
    LINKwindows,
    LINKpascal,
    LINKobjc,
};

enum DYNCAST
{
    DYNCAST_OBJECT,
    DYNCAST_EXPRESSION,
    DYNCAST_DSYMBOL,
    DYNCAST_TYPE,
    DYNCAST_IDENTIFIER,
    DYNCAST_TUPLE,
    DYNCAST_PARAMETER,
};

enum MATCH
{
    MATCHnomatch,       // no match
    MATCHconvert,       // match with conversions
    MATCHconst,         // match with conversion to const
    MATCHexact          // exact match
};

typedef uint64_t StorageClass;


void warning(Loc loc, const char *format, ...);
void deprecation(Loc loc, const char *format, ...);
void error(Loc loc, const char *format, ...);
void errorSupplemental(Loc loc, const char *format, ...);
extern "C" {
void verror(Loc loc, const char *format, va_list ap, const char *p1 = NULL, const char *p2 = NULL, const char *header = "Error: ");
}
void vwarning(Loc loc, const char *format, va_list);
void verrorSupplemental(Loc loc, const char *format, va_list ap);
void verrorPrint(Loc loc, const char *header, const char *format, va_list ap, const char *p1 = NULL, const char *p2 = NULL);
void vdeprecation(Loc loc, const char *format, va_list ap, const char *p1 = NULL, const char *p2 = NULL);

#if defined(__GNUC__) || defined(__clang__)
__attribute__((noreturn))
void fatal();
#elif _MSC_VER
__declspec(noreturn)
void fatal();
#else
void fatal();
#endif

void err_nomem();
int runLINK();
void deleteExeFile();
int runProgram();
const char *inifile(const char *argv0, const char *inifile, const char* envsectionname);
void halt();

class Dsymbol;
class Library;
struct File;
void obj_start(char *srcfile);
void obj_end(Library *library, File *objfile);
void obj_append(Dsymbol *s);
void obj_write_deferred(Library *library);

void readFile(Loc loc, File *f);
void writeFile(Loc loc, File *f);
void ensurePathToNameExists(Loc loc, const char *name);

const char *importHint(const char *s);
/// Little helper function for writting out deps.
void escapePath(OutBuffer *buf, const char *fname);

#endif /* DMD_MARS_H */
