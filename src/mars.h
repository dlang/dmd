
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
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
#endif /* __DMC__ */

#include <stdint.h>
#include <stdarg.h>

#ifdef __DMC__
#ifdef DEBUG
#undef assert
#define assert(e) (static_cast<void>((e) || (printf("assert %s(%d) %s\n", __FILE__, __LINE__, #e), halt())))
#endif
#endif

#ifdef IN_GCC
/* Changes for the GDC compiler by David Friedman */
#endif

#define V1	1
#define V2	0	// Version 2.0 features
#define BREAKABI 1	// 0 if not ready to break the ABI just yet

struct Array;

// Put command line switches in here
struct Param
{
    char obj;		// write object file
    char link;		// perform link
    char lib;		// write library file instead of object file(s)
    char multiobj;	// break one object file into multiple ones
    char oneobj;	// write one object file instead of multiple ones
    char trace;		// insert profiling hooks
    char quiet;		// suppress non-error messages
    char verbose;	// verbose compile
    char symdebug;	// insert debug symbolic information
    char optimize;	// run optimizer
    char cpu;		// target CPU
    char isX86_64;	// generate X86_64 bit code
    char isLinux;	// generate code for linux
    char isWindows;	// generate code for Windows
    char scheduler;	// which scheduler to use
    char useDeprecated;	// allow use of deprecated features
    char useAssert;	// generate runtime code for assert()'s
    char useInvariants;	// generate class invariant checks
    char useIn;		// generate precondition checks
    char useOut;	// generate postcondition checks
    char useArrayBounds; // generate array bounds checks
    char useSwitchError; // check for switches without a default
    char useUnitTests;	// generate unittest code
    char useInline;	// inline expand functions
    char release;	// build release version
    char preservePaths;	// !=0 means don't strip path from source file
    char warnings;	// enable warnings
    char pic;		// generate position-independent-code for shared libs
    char cov;		// generate code coverage data
    char nofloat;	// code should not pull in floating point support
    char Dversion;	// D version number
    char ignoreUnsupportedPragmas;	// rather than error on them

    char *argv0;	// program name
    Array *imppath;	// array of char*'s of where to look for import modules
    Array *fileImppath;	// array of char*'s of where to look for file import modules
    char *objdir;	// .obj/.lib file output directory
    char *objname;	// .obj file output name
    char *libname;	// .lib file output name

    char doDocComments;	// process embedded documentation comments
    char *docdir;	// write documentation file to docdir directory
    char *docname;	// write documentation file to docname
    Array *ddocfiles;	// macro include files for Ddoc

    char doHdrGeneration;	// process embedded documentation comments
    char *hdrdir;		// write 'header' file to docdir directory
    char *hdrname;		// write 'header' file to docname

    unsigned debuglevel;	// debug level
    Array *debugids;		// debug identifiers

    unsigned versionlevel;	// version level
    Array *versionids;		// version identifiers

    bool dump_source;

    char *defaultlibname;	// default library for non-debug builds
    char *debuglibname;		// default library for debug builds

    char *xmlname;		// filename for XML output

    // Hidden debug switches
    char debuga;
    char debugb;
    char debugc;
    char debugf;
    char debugr;
    char debugw;
    char debugx;
    char debugy;

    char run;		// run resulting executable
    size_t runargs_length;
    char** runargs;	// arguments for executable

    // Linker stuff
    Array *objfiles;
    Array *linkswitches;
    Array *libfiles;
    char *deffile;
    char *resfile;
    char *exefile;
};

struct Global
{
    char *mars_ext;
    char *sym_ext;
    char *obj_ext;
    char *lib_ext;
    char *doc_ext;	// for Ddoc generated files
    char *ddoc_ext;	// for Ddoc macro include files
    char *hdr_ext;	// for D 'header' import files
    char *copyright;
    char *written;
    Array *path;	// Array of char*'s which form the import lookup path
    Array *filePath;	// Array of char*'s which form the file import lookup path
    int structalign;
    char *version;

    Param params;
    unsigned errors;	// number of errors reported so far
    unsigned gag;	// !=0 means gag reporting of errors

    Global();
};

extern Global global;

#if __GNUC__
//#define memicmp strncasecmp
//#define stricmp strcasecmp
#endif

#ifdef __DMC__
 typedef _Complex long double complex_t;
#else
 #ifndef IN_GCC
  #include "complex_t.h"
 #endif
 #ifdef __APPLE__
  //#include "complex.h"//This causes problems with include the c++ <complex> and not the C "complex.h"
  #define integer_t dmd_integer_t
 #endif
#endif

// Be careful not to care about sign when using integer_t
typedef uint64_t integer_t;

// Signed and unsigned variants
typedef int64_t sinteger_t;
typedef uint64_t uinteger_t;

typedef int8_t			d_int8;
typedef uint8_t			d_uns8;
typedef int16_t			d_int16;
typedef uint16_t		d_uns16;
typedef int32_t			d_int32;
typedef uint32_t		d_uns32;
typedef int64_t			d_int64;
typedef uint64_t		d_uns64;

typedef float			d_float32;
typedef double			d_float64;
typedef long double		d_float80;

typedef d_uns8			d_char;
typedef d_uns16			d_wchar;
typedef d_uns32			d_dchar;

#ifdef IN_GCC
#include "d-gcc-real.h"
#else
typedef long double real_t;
#endif

// Modify OutBuffer::writewchar to write the correct size of wchar
#if _WIN32
#define writewchar writeword
#else
// This needs a configuration test...
#define writewchar write4
#endif

#ifdef IN_GCC
#include "d-gcc-complex_t.h"
#endif

struct Module;

//typedef unsigned Loc;		// file location
struct Loc
{
    char *filename;
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
};

#ifndef GCC_SAFE_DMD
#define TRUE	1
#define FALSE	0
#endif

#define INTERFACE_OFFSET	0	// if 1, put classinfo as first entry
					// in interface vtbl[]'s
#define INTERFACE_VIRTUAL	0	// 1 means if an interface appears
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
};

enum MATCH
{
    MATCHnomatch,	// no match
    MATCHconvert,	// match with conversions
#if V2
    MATCHconst,		// match with conversion to const
#endif
    MATCHexact		// exact match
};

void error(Loc loc, const char *format, ...);
void verror(Loc loc, const char *format, va_list);
void fatal();
void err_nomem();
int runLINK();
void deleteExeFile();
int runProgram();
void inifile(char *argv0, char *inifile);
void halt();

/*** Where to send error messages ***/
#if IN_GCC
#define stdmsg stderr
#else
#define stdmsg stdout
#endif

struct Dsymbol;
struct Library;
struct File;
void obj_start(char *srcfile);
void obj_end(Library *library, File *objfile);
void obj_append(Dsymbol *s);
void obj_write_deferred(Library *library);

#endif /* DMD_MARS_H */
