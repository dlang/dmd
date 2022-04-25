/**
 * DMD-specific parameters.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/dmdparams.d, _dmdparams.d)
 * Documentation:  https://dlang.org/phobos/dmd_dmdparams.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/dmdparams.d
 */

module dmd.dmdparams;

import dmd.target;

/// Position Indepent Code setting
enum PIC : ubyte
{
    fixed,              /// located at a specific address
    pic,                /// Position Independent Code
    pie,                /// Position Independent Executable
}

struct DMDparams
{
    bool alwaysframe;       // always emit standard stack frame
    ubyte dwarf;            // DWARF version
    bool map;               // generate linker .map file
    bool vasm;              // print generated assembler for each function

    bool dll;               // generate shared dynamic library
    bool lib;               // write library file instead of object file(s)
    bool link = true;       // perform link
    bool oneobj;            // write one object file instead of multiple ones

    bool optimize;          // run optimizer
    bool nofloat;           // code should not pull in floating point support
    PIC pic = PIC.fixed;    // generate fixed, pic or pie code
    bool stackstomp;        // add stack stomping code

    ubyte symdebug;         // insert debug symbolic information
    bool symdebugref;       // insert debug information for all referenced types, too

    const(char)[] defaultlibname;   // default library for non-debug builds
    const(char)[] debuglibname;     // default library for debug builds
    const(char)[] mscrtlib;         // MS C runtime library

    // Hidden debug switches
    bool debugb;
    bool debugc;
    bool debugf;
    bool debugr;
    bool debugx;
    bool debugy;
}

/**
 Sets CPU Operating System, and optionally C/C++ runtime environment from the given triple
 e.g.
    x86_64+avx2-apple-darwin20.3.0
    x86-unknown-linux-musl-clang
    x64-windows-msvc
    x64-pc-windows-msvc
 */
struct Triple
{
    private const(char)[] source;
    CPU               cpu;
    bool              is64bit;
    bool              isLP64;
    Target.OS         os;
    ubyte             osMajor;
    TargetC.Runtime   cenv;
    TargetCPP.Runtime cppenv;

    this(const(char)* _triple)
    {
        import dmd.root.string : toDString, toCStringThen;
        const(char)[] triple = _triple.toDString();
        const(char)[] next()
        {
            size_t i = 0;
            const tmp = triple;
            while (triple.length && triple[0] != '-')
            {
                triple = triple[1 .. $];
                ++i;
            }
            if (triple.length && triple[0] == '-')
            {
                triple = triple[1 .. $];
            }
            return tmp[0 .. i];
        }

        parseArch(next);
        const(char)[] vendorOrOS = next();
        const(char)[] _os;
        if (tryParseVendor(vendorOrOS))
            _os = next();
        else
            _os = vendorOrOS;
        os = parseOS(_os, osMajor);

        const(char)[] _cenv = next();
        if (_cenv.length)
            cenv = parseCEnv(_cenv);
        else if (this.os == Target.OS.Windows)
            cenv = TargetC.Runtime.Microsoft;
        const(char)[] _cppenv = next();
        if (_cppenv.length)
            cppenv = parseCPPEnv(_cppenv);
        else if (this.os == Target.OS.Windows)
            cppenv = TargetCPP.Runtime.Microsoft;
    }
    private extern(D):

    void unknown(const(char)[] unk, const(char)* what)
    {
        import dmd.errors : error;
        import dmd.root.string : toCStringThen;
        import dmd.globals : Loc;
        unk.toCStringThen!(p => error(Loc.initial,"unknown %s `%s` for `-target`", what, p.ptr));
    }

    void parseArch(const(char)[] arch)
    {
        bool matches(const(char)[] str)
        {
            import dmd.root.string : startsWith;
            if (!arch.ptr.startsWith(str))
                return false;
            arch = arch[str.length .. $];
            return true;
        }

        if (matches("x86_64"))
            is64bit = true;
        else if (matches("x86"))
            is64bit = false;
        else if (matches("x64"))
            is64bit = true;
        else if (matches("x32"))
        {
            is64bit = true;
            isLP64 = false;
        }
        else
            return unknown(arch, "architecture");

        if (!arch.length)
            return;

        switch (arch)
        {
            case "+sse2": cpu = CPU.sse2; break;
            case "+avx":  cpu = CPU.avx;  break;
            case "+avx2": cpu = CPU.avx2; break;
            default:
                unknown(arch, "architecture feature");
        }
    }

    // try parsing vendor if present
    bool tryParseVendor(const(char)[] vendor)
    {
        switch (vendor)
        {
            case "unknown": return true;
            case "apple":   return true;
            case "pc":      return true;
            case "amd":     return true;
            default:        return false;
        }
    }

    /********************************
     * Parse OS and osMajor version number.
     * Params:
     *  _os = string to check for operating system followed by version number
     *  osMajor = set to version number (if any), otherwise set to 0.
     *            Set to 255 if version number is 255 or larger and error is generated
     * Returns:
     *  detected operating system, Target.OS.none if none
     */
    Target.OS parseOS(const(char)[] _os, out ubyte osMajor)
    {
        import dmd.errors : error;
        import dmd.globals : Loc;

        bool matches(const(char)[] str)
        {
            import dmd.root.string : startsWith;
            if (!_os.ptr.startsWith(str))
                return false;
            _os = _os[str.length .. $];
            return true;
        }
        Target.OS os;
        if (matches("darwin"))
            os = Target.OS.OSX;
        else if (matches("dragonfly"))
            os =  Target.OS.DragonFlyBSD;
        else if (matches("freebsd"))
            os =  Target.OS.FreeBSD;
        else if (matches("openbsd"))
            os =  Target.OS.OpenBSD;
        else if (matches("linux"))
            os =  Target.OS.linux;
        else if (matches("windows"))
            os =  Target.OS.Windows;
        else
        {
            unknown(_os, "operating system");
            return Target.OS.none;
        }

        bool overflow;
        auto major = parseNumber(_os, overflow);
        if (overflow || major >= 255)
        {
            error(Loc.initial, "OS version overflowed max of 254");
            major = 255;
        }
        osMajor = cast(ubyte)major;

        /* Note that anything after the number up to the end or '-',
         * such as '.3.4.hello.betty', is ignored
         */

        return os;
    }

    /*******************************
     * Parses a decimal number out of the str and returns it.
     * Params:
     *  str = string to parse the number from, updated to text after the number
     *  overflow = set to true iff an overflow happens
     * Returns:
     *  parsed number
     */
    private pure static
    uint parseNumber(ref const(char)[] str, ref bool overflow)
    {
        auto s = str;
        ulong n;
        while (s.length)
        {
            const c = s[0];
            if (c < '0' || '9' < c)
                break;
            n = n * 10 + (c - '0');
            overflow |= (n > uint.max); // sticky overflow check
            s = s[1 .. $];              // consume digit
        }
        str = s;
        return cast(uint)n;
    }

    TargetC.Runtime parseCEnv(const(char)[] cenv)
    {
        with (TargetC.Runtime) switch (cenv)
        {
            case "musl":         return Musl;
            case "msvc":         return Microsoft;
            case "bionic":       return Bionic;
            case "digital_mars": return DigitalMars;
            case "newlib":       return Newlib;
            case "uclibc":       return UClibc;
            case "glibc":        return Glibc;
            default:
            {
                unknown(cenv, "C runtime environment");
                return Unspecified;
            }
        }
    }

    TargetCPP.Runtime parseCPPEnv(const(char)[] cppenv)
    {
        with (TargetCPP.Runtime) switch (cppenv)
        {
            case "clang":        return Clang;
            case "gcc":          return Gcc;
            case "msvc":         return Microsoft;
            case "sun":          return Sun;
            case "digital_mars": return DigitalMars;
            default:
            {
                unknown(cppenv, "C++ runtime environment");
                return Unspecified;
            }
        }
    }
}

void setTriple(ref Target target, const ref Triple triple)
{
    target.cpu     = triple.cpu;
    target.is64bit = triple.is64bit;
    target.isLP64  = triple.isLP64;
    target.os      = triple.os;
    target.osMajor = triple.osMajor;
    target.c.runtime   = triple.cenv;
    target.cpp.runtime = triple.cppenv;
}

/**
Returns: the final defaultlibname based on the command-line parameters
*/
extern (D) const(char)[] finalDefaultlibname()
{
    import dmd.globals : global;
    return global.params.betterC ? null :
        driverParams.symdebug ? driverParams.debuglibname : driverParams.defaultlibname;
}

__gshared DMDparams driverParams = DMDparams.init;
