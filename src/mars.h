
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
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
        linux           Linux
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
        TARGET_NET      Covers .Net

    It is expected that the compiler for each platform will be able
    to generate 32 and 64 bit code from the same compiler binary.

    Target object module format:
        OMFOBJ          Intel Object Module Format, used on Windows
        ELFOBJ          Elf Object Module Format, used on linux, FreeBSD, OpenBSD and Solaris
        MACHOBJ         Mach-O Object Module Format, used on Mac OSX

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

#ifdef DEBUG
#define UNITTEST 1
#endif
void unittests();

#ifdef IN_GCC
/* Changes for the GDC compiler by David Friedman */
#endif

#define DMDV1   1
#define DMDV2   0       // Version 2.0 features
#define STRUCTTHISREF DMDV2     // if 'this' for struct is a reference, not a pointer
#define SNAN_DEFAULT_INIT DMDV2 // if floats are default initialized to signalling NaN
#define SARRAYVALUE DMDV2       // static arrays are value types
#define MODULEINFO_IS_STRUCT DMDV2   // if ModuleInfo is a struct rather than a class

// Set if C++ mangling is done by the front end
#define CPP_MANGLE (DMDV2 && (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS))

/* Other targets are TARGET_LINUX, TARGET_OSX, TARGET_FREEBSD, TARGET_OPENBSD and
 * TARGET_SOLARIS, which are
 * set on the command line via the compiler makefile.
 */

#if _WIN32
#ifndef TARGET_WINDOS
#define TARGET_WINDOS 1         // Windows dmd generates Windows targets
#endif
#ifndef OMFOBJ
#define OMFOBJ TARGET_WINDOS
#endif
#endif

#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
#ifndef ELFOBJ
#define ELFOBJ 1
#endif
#endif

#if TARGET_OSX
#ifndef MACHOBJ
#define MACHOBJ 1
#endif
#endif


struct Array;
struct OutBuffer;

// Can't include arraytypes.h here, need to declare these directly.
template <typename TYPE> struct ArrayBase;
typedef ArrayBase<struct Identifier> Identifiers;
typedef ArrayBase<char> Strings;

// -v2 hint support

enum V2MODE
{
   V2MODEnone        = 0,
   V2MODEoverride    = 1 << 0,
   V2MODEsyntax      = 1 << 1,
   V2MODEoctal       = 1 << 2,
   V2MODEconst       = 1 << 3,
   V2MODEswitch      = 1 << 4,
   V2MODEvolatile    = 1 << 5,
   V2MODEstaticarr   = 1 << 6,
   V2MODEall         = 0xFFFFFFFF,
   V2MODEdefault     = V2MODEall,
};

const char* V2MODE_name(V2MODE mode);

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
    char symdebug;      // insert debug symbolic information
    bool alwaysframe;   // always emit standard stack frame
    bool optimize;      // run optimizer
    char map;           // generate linker .map file
    char cpu;           // target CPU
    char is64bit;       // generate 64 bit code
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
    char cov;           // generate code coverage data
    bool nofloat;       // code should not pull in floating point support
    char Dversion;      // D version number
    unsigned enabledV2hints; // bitflags for enabled hints for -v2
    char ignoreUnsupportedPragmas;      // rather than error on them
    char safe;          // enforce safe memory model
    char betterC;       // be a "better C" compiler; no dependency on D runtime

    const char *argv0;    // program name
    Strings *imppath;     // array of char*'s of where to look for import modules
    Strings *fileImppath; // array of char*'s of where to look for file import modules
    char *objdir;       // .obj/.lib file output directory
    char *objname;      // .obj file output name
    char *libname;      // .lib file output name

    char doDocComments; // process embedded documentation comments
    char *docdir;       // write documentation file to docdir directory
    char *docname;      // write documentation file to docname
    Strings *ddocfiles;   // macro include files for Ddoc

    char doHdrGeneration;       // process embedded documentation comments
    char *hdrdir;               // write 'header' file to docdir directory
    char *hdrname;              // write 'header' file to docname

    char doXGeneration;         // write JSON file
    char *xfilename;            // write JSON file to xfilename

    unsigned debuglevel;        // debug level
    Strings *debugids;     // debug identifiers

    unsigned versionlevel;      // version level
    Strings *versionids;   // version identifiers

    bool dump_source;

    const char *defaultlibname; // default library for non-debug builds
    const char *debuglibname;   // default library for debug builds

    char *moduleDepsFile;       // filename for deps output
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
    char *deffile;
    char *resfile;
    char *exefile;
    char *mapfile;
};

typedef unsigned structalign_t;
#define STRUCTALIGN_DEFAULT ~0  // magic value means "match whatever the underlying C compiler does"
// other values are all powers of 2

struct Global
{
    const char *inifilename;
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
    const char *copyright;
    const char *written;
    Strings *path;        // Array of char*'s which form the import lookup path
    Strings *filePath;    // Array of char*'s which form the file import lookup path

    structalign_t structalign;       // default alignment for struct fields

    const char *version;

    Param params;
    unsigned errors;       // number of errors reported so far
    unsigned warnings;     // number of warnings reported so far
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

    Global();
};

extern Global global;

/* Set if Windows Structured Exception Handling C extensions are supported.
 * Apparently, VC has dropped support for these?
 */
#define WINDOWS_SEH     (_WIN32 && __DMC__)

#include "longdouble.h"

#ifdef __DMC__
 #include  <complex.h>
 typedef _Complex long double complex_t;
#else
 #ifndef IN_GCC
  #include "complex_t.h"
 #endif
 #ifdef __APPLE__
  //#include "complex.h"//This causes problems with include the c++ <complex> and not the C "complex.h"
 #endif
#endif

// Be careful not to care about sign when using dinteger_t
//typedef uint64_t integer_t;
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
typedef long double             d_float80;

typedef d_uns8                  d_char;
typedef d_uns16                 d_wchar;
typedef d_uns32                 d_dchar;

#ifdef IN_GCC
#include "d-gcc-real.h"
#else
typedef long double real_t;
#endif

#ifdef IN_GCC
#include "d-gcc-complex_t.h"
#endif

struct Module;

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

    Loc(int x)
    {
        linnum = x;
        filename = NULL;
    }

    Loc(Module *mod, unsigned linnum);

    char *toChars();
    bool equals(const Loc& loc);
};

#ifndef GCC_SAFE_DMD
#define TRUE    1
#define FALSE   0
#endif

#define INTERFACE_OFFSET        0       // if 1, put classinfo as first entry
                                        // in interface vtbl[]'s
#define INTERFACE_VIRTUAL       0       // 1 means if an interface appears
                                        // in the inheritance graph multiple
                                        // times, only one is used

enum LINK
{
    LINKdefault,
    LINKd,
    LINKc,
    LINKcpp,
    LINKwindows,
    LINKpascal,
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
#if DMDV2
    MATCHconst,         // match with conversion to const
#endif
    MATCHexact          // exact match
};

typedef uint64_t StorageClass;


void warning(Loc loc, const char *format, ...);
void deprecation(Loc loc, const char *format, ...);
void error(Loc loc, const char *format, ...);
void errorSupplemental(Loc loc, const char *format, ...);
void verror(Loc loc, const char *format, va_list ap, const char *p1 = NULL, const char *p2 = NULL, const char *header = "Error: ");
void vwarning(Loc loc, const char *format, va_list);
void verrorSupplemental(Loc loc, const char *format, va_list ap);
void verrorPrint(Loc loc, const char *header, const char *format, va_list ap, const char *p1 = NULL, const char *p2 = NULL);
void vdeprecation(Loc loc, const char *format, va_list ap, const char *p1 = NULL, const char *p2 = NULL);

#if defined(__GNUC__) || defined(__clang__)
__attribute__((noreturn))
#endif
void fatal();

void err_nomem();
int runLINK();
void deleteExeFile();
int runProgram();
void halt();
void util_progress();

/*** Where to send error messages ***/
extern FILE *stdmsg;

struct Dsymbol;
class Library;
struct File;
void obj_start(char *srcfile);
void obj_end(Library *library, File *objfile);
void obj_append(Dsymbol *s);
void obj_write_deferred(Library *library);

const char *importHint(const char *s);

#endif /* DMD_MARS_H */
