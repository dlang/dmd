// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.globals;

import core.stdc.stdint;
import core.stdc.stdio;
import core.stdc.string;
import ddmd.root.array;
import ddmd.root.filename;
import ddmd.root.outbuffer;

template xversion(string s)
{
    enum xversion = mixin(`{ version (` ~ s ~ `) return true; else return false; }`)();
}

private string stripRight(string s)
{
    while (s.length && (s[$ - 1] == ' ' || s[$ - 1] == '\n' || s[$ - 1] == '\r'))
        s = s[0 .. $ - 1];
    return s;
}

enum __linux__ = xversion!`linux`;
enum __APPLE__ = xversion!`OSX`;
enum __FreeBSD__ = xversion!`FreeBSD`;
enum __OpenBSD__ = xversion!`OpenBSD`;
enum __sun = xversion!`Solaris`;

enum IN_GCC = xversion!`IN_GCC`;

enum TARGET_LINUX = xversion!`linux`;
enum TARGET_OSX = xversion!`OSX`;
enum TARGET_FREEBSD = xversion!`FreeBSD`;
enum TARGET_OPENBSD = xversion!`OpenBSD`;
enum TARGET_SOLARIS = xversion!`Solaris`;
enum TARGET_WINDOS = xversion!`Windows`;

enum BOUNDSCHECK : int
{
    BOUNDSCHECKdefault, // initial value
    BOUNDSCHECKoff, // never do bounds checking
    BOUNDSCHECKon, // always do bounds checking
    BOUNDSCHECKsafeonly, // do bounds checking only in @safe functions
}

alias BOUNDSCHECKdefault = BOUNDSCHECK.BOUNDSCHECKdefault;
alias BOUNDSCHECKoff = BOUNDSCHECK.BOUNDSCHECKoff;
alias BOUNDSCHECKon = BOUNDSCHECK.BOUNDSCHECKon;
alias BOUNDSCHECKsafeonly = BOUNDSCHECK.BOUNDSCHECKsafeonly;

// Put command line switches in here
struct Param
{
    bool obj; // write object file
    bool link; // perform link
    bool dll; // generate shared dynamic library
    bool lib; // write library file instead of object file(s)
    bool multiobj; // break one object file into multiple ones
    bool oneobj; // write one object file instead of multiple ones
    bool trace; // insert profiling hooks
    bool tracegc; // instrument calls to 'new'
    bool verbose; // verbose compile
    bool showColumns; // print character (column) numbers in diagnostics
    bool vtls; // identify thread local variables
    char vgc; // identify gc usage
    bool vfield; // identify non-mutable field variables
    bool vcomplex; // identify complex/imaginary type usage
    char symdebug; // insert debug symbolic information
    bool alwaysframe; // always emit standard stack frame
    bool optimize; // run optimizer
    bool map; // generate linker .map file
    bool is64bit; // generate 64 bit code
    bool isLP64; // generate code for LP64
    bool isLinux; // generate code for linux
    bool isOSX; // generate code for Mac OSX
    bool isWindows; // generate code for Windows
    bool isFreeBSD; // generate code for FreeBSD
    bool isOpenBSD; // generate code for OpenBSD
    bool isSolaris; // generate code for Solaris
    bool mscoff; // for Win32: write COFF object files instead of OMF
    // 0: don't allow use of deprecated features
    // 1: silently allow use of deprecated features
    // 2: warn about the use of deprecated features
    char useDeprecated;
    bool useAssert; // generate runtime code for assert()'s
    bool useInvariants; // generate class invariant checks
    bool useIn; // generate precondition checks
    bool useOut; // generate postcondition checks
    bool stackstomp; // add stack stomping code
    bool useSwitchError; // check for switches without a default
    bool useUnitTests; // generate unittest code
    bool useInline; // inline expand functions
    bool useDIP25; // implement http://wiki.dlang.org/DIP25
    bool release; // build release version
    bool preservePaths; // true means don't strip path from source file
    // 0: disable warnings
    // 1: warnings as errors
    // 2: informational warnings (no errors)
    char warnings;
    bool pic; // generate position-independent-code for shared libs
    bool color; // use ANSI colors in console output
    bool cov; // generate code coverage data
    ubyte covPercent; // 0..100 code coverage percentage required
    bool nofloat; // code should not pull in floating point support
    bool ignoreUnsupportedPragmas; // rather than error on them
    bool enforcePropertySyntax;
    bool betterC; // be a "better C" compiler; no dependency on D runtime
    bool addMain; // add a default main() function
    bool allInst; // generate code for all template instantiations
    BOUNDSCHECK useArrayBounds;
    const(char)* argv0; // program name
    Array!(const(char)*)* imppath; // array of char*'s of where to look for import modules
    Array!(const(char)*)* fileImppath; // array of char*'s of where to look for file import modules
    const(char)* objdir; // .obj/.lib file output directory
    const(char)* objname; // .obj file output name
    const(char)* libname; // .lib file output name
    bool doDocComments; // process embedded documentation comments
    const(char)* docdir; // write documentation file to docdir directory
    const(char)* docname; // write documentation file to docname
    Array!(const(char)*)* ddocfiles; // macro include files for Ddoc
    bool doHdrGeneration; // process embedded documentation comments
    const(char)* hdrdir; // write 'header' file to docdir directory
    const(char)* hdrname; // write 'header' file to docname
    bool doJsonGeneration; // write JSON file
    const(char)* jsonfilename; // write JSON file to jsonfilename
    uint debuglevel; // debug level
    Array!(const(char)*)* debugids; // debug identifiers
    uint versionlevel; // version level
    Array!(const(char)*)* versionids; // version identifiers
    const(char)* defaultlibname; // default library for non-debug builds
    const(char)* debuglibname; // default library for debug builds
    const(char)* moduleDepsFile; // filename for deps output
    OutBuffer* moduleDeps; // contents to be written to deps file
    // Hidden debug switches
    bool debugb;
    bool debugc;
    bool debugf;
    bool debugr;
    bool debugx;
    bool debugy;
    bool run; // run resulting executable
    Strings runargs; // arguments for executable
    // Linker stuff
    Array!(const(char)*)* objfiles;
    Array!(const(char)*)* linkswitches;
    Array!(const(char)*)* libfiles;
    Array!(const(char)*)* dllfiles;
    const(char)* deffile;
    const(char)* resfile;
    const(char)* exefile;
    const(char)* mapfile;
}

struct Compiler
{
    const(char)* vendor; // Compiler backend name
}

alias structalign_t = uint;

// magic value means "match whatever the underlying C compiler does"
// other values are all powers of 2
enum STRUCTALIGN_DEFAULT = (cast(structalign_t)~0);

struct Global
{
    const(char)* inifilename;
    const(char)* mars_ext;
    const(char)* obj_ext;
    const(char)* lib_ext;
    const(char)* dll_ext;
    const(char)* doc_ext; // for Ddoc generated files
    const(char)* ddoc_ext; // for Ddoc macro include files
    const(char)* hdr_ext; // for D 'header' import files
    const(char)* json_ext; // for JSON files
    const(char)* map_ext; // for .map files
    bool run_noext; // allow -run sources without extensions.
    const(char)* copyright;
    const(char)* written;
    const(char)* main_d; // dummy filename for dummy main()
    Array!(const(char)*)* path; // Array of char*'s which form the import lookup path
    Array!(const(char)*)* filePath; // Array of char*'s which form the file import lookup path
    const(char)* _version;
    Compiler compiler;
    Param params;
    uint errors; // number of errors reported so far
    uint warnings; // number of warnings reported so far
    FILE* stdmsg; // where to send verbose messages
    uint gag; // !=0 means gag reporting of errors & warnings
    uint gaggedErrors; // number of errors reported while gagged
    uint errorLimit;

    /* Start gagging. Return the current number of gagged errors
     */
    extern (C++) uint startGagging()
    {
        ++gag;
        return gaggedErrors;
    }

    /* End gagging, restoring the old gagged state.
     * Return true if errors occured while gagged.
     */
    extern (C++) bool endGagging(uint oldGagged)
    {
        bool anyErrs = (gaggedErrors != oldGagged);
        --gag;
        // Restore the original state of gagged errors; set total errors
        // to be original errors + new ungagged errors.
        errors -= (gaggedErrors - oldGagged);
        gaggedErrors = oldGagged;
        return anyErrs;
    }

    /*  Increment the error count to record that an error
     *  has occured in the current context. An error message
     *  may or may not have been printed.
     */
    extern (C++) void increaseErrorCount()
    {
        if (gag)
            ++gaggedErrors;
        ++errors;
    }

    extern (C++) void _init()
    {
        inifilename = null;
        mars_ext = "d";
        hdr_ext = "di";
        doc_ext = "html";
        ddoc_ext = "ddoc";
        json_ext = "json";
        map_ext = "map";
        static if (TARGET_WINDOS)
        {
            obj_ext = "obj";
        }
        else static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
        {
            obj_ext = "o";
        }
        else
        {
            static assert(0, "fix this");
        }
        static if (TARGET_WINDOS)
        {
            lib_ext = "lib";
        }
        else static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
        {
            lib_ext = "a";
        }
        else
        {
            static assert(0, "fix this");
        }
        static if (TARGET_WINDOS)
        {
            dll_ext = "dll";
        }
        else static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
        {
            dll_ext = "so";
        }
        else static if (TARGET_OSX)
        {
            dll_ext = "dylib";
        }
        else
        {
            static assert(0, "fix this");
        }
        static if (TARGET_WINDOS)
        {
            run_noext = false;
        }
        else static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
        {
            // Allow 'script' D source files to have no extension.
            run_noext = true;
        }
        else
        {
            static assert(0, "fix this");
        }
        copyright = "Copyright (c) 1999-2015 by Digital Mars";
        written = "written by Walter Bright";
        _version = ('v' ~ stripRight(import("verstr.h"))[1 .. $ - 1] ~ '\0').ptr;
        compiler.vendor = "Digital Mars D";
        stdmsg = stdout;
        main_d = "__main.d";
        memset(&params, 0, Param.sizeof);
        errorLimit = 20;
    }
}

// Because int64_t and friends may be any integral type of the
// correct size, we have to explicitly ask for the correct
// integer type to get the correct mangling with ddmd

// Be careful not to care about sign when using dinteger_t
// use this instead of integer_t to
// avoid conflicts with system #include's
alias dinteger_t = ulong;
// Signed and unsigned variants
alias sinteger_t = long;
alias uinteger_t = ulong;

alias d_int8 = int8_t;
alias d_uns8 = uint8_t;
alias d_int16 = int16_t;
alias d_uns16 = uint16_t;
alias d_int32 = int32_t;
alias d_uns32 = uint32_t;
alias d_int64 = int64_t;
alias d_uns64 = uint64_t;
alias d_float32 = float;
alias d_float64 = double;
alias d_float80 = real;
alias d_char = d_uns8;
alias d_wchar = d_uns16;
alias d_dchar = d_uns32;
alias real_t = real;

// file location
struct Loc
{
    const(char)* filename;
    uint linnum;
    uint charnum;

    extern (D) this(const(char)* filename, uint linnum, uint charnum)
    {
        this.linnum = linnum;
        this.charnum = charnum;
        this.filename = filename;
    }

    extern (C++) char* toChars()
    {
        OutBuffer buf;
        if (filename)
        {
            buf.printf("%s", filename);
        }
        if (linnum)
        {
            buf.printf("(%d", linnum);
            if (global.params.showColumns && charnum)
                buf.printf(",%d", charnum);
            buf.writeByte(')');
        }
        return buf.extractString();
    }

    extern (C++) bool equals(ref const(Loc) loc)
    {
        return (!global.params.showColumns || charnum == loc.charnum) && linnum == loc.linnum && FileName.equals(filename, loc.filename);
    }
}

enum LINK : int
{
    LINKdefault,
    LINKd,
    LINKc,
    LINKcpp,
    LINKwindows,
    LINKpascal,
    LINKobjc,
}

alias LINKdefault = LINK.LINKdefault;
alias LINKd = LINK.LINKd;
alias LINKc = LINK.LINKc;
alias LINKcpp = LINK.LINKcpp;
alias LINKwindows = LINK.LINKwindows;
alias LINKpascal = LINK.LINKpascal;
alias LINKobjc = LINK.LINKobjc;

enum DYNCAST : int
{
    DYNCAST_OBJECT,
    DYNCAST_EXPRESSION,
    DYNCAST_DSYMBOL,
    DYNCAST_TYPE,
    DYNCAST_IDENTIFIER,
    DYNCAST_TUPLE,
    DYNCAST_PARAMETER,
}

alias DYNCAST_OBJECT = DYNCAST.DYNCAST_OBJECT;
alias DYNCAST_EXPRESSION = DYNCAST.DYNCAST_EXPRESSION;
alias DYNCAST_DSYMBOL = DYNCAST.DYNCAST_DSYMBOL;
alias DYNCAST_TYPE = DYNCAST.DYNCAST_TYPE;
alias DYNCAST_IDENTIFIER = DYNCAST.DYNCAST_IDENTIFIER;
alias DYNCAST_TUPLE = DYNCAST.DYNCAST_TUPLE;
alias DYNCAST_PARAMETER = DYNCAST.DYNCAST_PARAMETER;

enum MATCH : int
{
    MATCHnomatch, // no match
    MATCHconvert, // match with conversions
    MATCHconst, // match with conversion to const
    MATCHexact, // exact match
}

alias MATCHnomatch = MATCH.MATCHnomatch;
alias MATCHconvert = MATCH.MATCHconvert;
alias MATCHconst = MATCH.MATCHconst;
alias MATCHexact = MATCH.MATCHexact;

enum PINLINE : int
{
    PINLINEdefault, // as specified on the command line
    PINLINEnever, // never inline
    PINLINEalways, // always inline
}

alias PINLINEdefault = PINLINE.PINLINEdefault;
alias PINLINEnever = PINLINE.PINLINEnever;
alias PINLINEalways = PINLINE.PINLINEalways;

alias StorageClass = uinteger_t;

extern (C++) __gshared Global global;
