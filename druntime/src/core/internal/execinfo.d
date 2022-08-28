/**
 * This module helps to decide whether an appropriate execinfo implementation
 * is available in the underling C runtime or in an external library. In the
 * latter case exactly one of the following version identifiers should be
 * set at the time of building druntime.
 *
 * Possible external execinfo version IDs based on possible backtrace output
 * formats:
 * $(TABLE
 * $(THEAD Version ID, Backtrace format)
 * $(TROW $(B ExtExecinfo_BSDFmt), 0x00000000 <_D6module4funcAFZv+0x78> at module)
 * $(TROW $(B ExtExecinfo_DarwinFmt), 1  module    0x00000000 D6module4funcAFZv + 0)
 * $(TROW $(B ExtExecinfo_GNUFmt), module(_D6module4funcAFZv) [0x00000000] $(B or)
 * module(_D6module4funcAFZv+0x78) [0x00000000] $(B or) module(_D6module4funcAFZv-0x78) [0x00000000])
 * $(TROW $(B ExtExecinfo_SolarisFmt), object'symbol+offset [pc])
 * )
 *
 * The code also ensures that at most one format is selected (either by automatic
 * C runtime detection or by $(B ExtExecinfo_) version IDs) and stores the
 * corresponding values in $(LREF BacktraceFmt).
 *
 * With $(LREF getMangledSymbolName) we can get the original mangled symbol name
 * from `backtrace_symbols` output of any supported version.
 *
 * Copyright: Copyright Digital Mars 2019.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Source: $(DRUNTIMESRC core/internal/_execinfo.d)
 */

module core.internal.execinfo;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (ExtExecinfo_BSDFmt)
    version = _extExecinfo;
else version (ExtExecinfo_DarwinFmt)
    version = _extExecinfo;
else version (ExtExecinfo_GNUFmt)
    version = _extExecinfo;
else version (ExtExecinfo_SolarisFmt)
    version = _extExecinfo;

version (linux)
{
    version (CRuntime_Glibc)
        import _execinfo = core.sys.linux.execinfo;
    else version (CRuntime_UClibc)
        import _execinfo = core.sys.linux.execinfo;
    else version (_extExecinfo)
        import _execinfo = core.sys.linux.execinfo;
}
else version (Darwin)
    import _execinfo = core.sys.darwin.execinfo;
else version (FreeBSD)
    import _execinfo = core.sys.freebsd.execinfo;
else version (NetBSD)
    import _execinfo = core.sys.netbsd.execinfo;
else version (OpenBSD)
    import _execinfo = core.sys.openbsd.execinfo;
else version (DragonFlyBSD)
    import _execinfo = core.sys.dragonflybsd.execinfo;
else version (Solaris)
    import _execinfo = core.sys.solaris.execinfo;

/// Indicates the availability of backtrace functions
enum bool hasExecinfo = is(_execinfo == module);

static if (hasExecinfo)
{
    /// Always points to the platform's backtrace function.
    alias backtrace = _execinfo.backtrace;

    /// Always points to the platform's backtrace_symbols function. The
    /// supported output format can be obtained by testing
    /// $(LREF BacktraceFmt) enum values.
    alias backtrace_symbols = _execinfo.backtrace_symbols;

    /// Always points to the platform's backtrace_symbols_fd function.
    alias backtrace_symbols_fd = _execinfo.backtrace_symbols_fd;
}

// Inspect possible backtrace formats
private
{
    version (FreeBSD)
        enum _BTFmt_BSD = true;
    else version (DragonFlyBSD)
        enum _BTFmt_BSD = true;
    else version (NetBSD)
        enum _BTFmt_BSD = true;
    else version (OpenBSD)
        enum _BTFmt_BSD = true;
    else version (ExtExecinfo_BSDFmt)
        enum _BTFmt_BSD = true;
    else
        enum _BTFmt_BSD = false;

    version (Darwin)
        enum _BTFmt_Darwin = true;
    else version (ExtExecinfo_DarwinFmt)
        enum _BTFmt_Darwin = true;
    else
        enum _BTFmt_Darwin = false;

    version (CRuntime_Glibc)
        enum _BTFmt_GNU = true;
    else version (CRuntime_UClibc)
        enum _BTFmt_GNU = true;
    else version (ExtExecinfo_GNUFmt)
        enum _BTFmt_GNU = true;
    else
        enum _BTFmt_GNU = false;

    version (Solaris)
        enum _BTFmt_Solaris = true;
    else version (ExtExecinfo_SolarisFmt)
        enum _BTFmt_Solaris = true;
    else
        enum _BTFmt_Solaris = false;
}

/**
 * Indicates the backtrace format of the actual execinfo implementation.
 * At most one of the values is allowed to be set to `true` the
 * others should be `false`.
 */
enum BacktraceFmt : bool
{
    /// 0x00000000 <_D6module4funcAFZv+0x78> at module
    BSD = _BTFmt_BSD,

    /// 1  module    0x00000000 D6module4funcAFZv + 0
    Darwin = _BTFmt_Darwin,

    /// module(_D6module4funcAFZv) [0x00000000]
    /// $(B or) module(_D6module4funcAFZv+0x78) [0x00000000]
    /// $(B or) module(_D6module4funcAFZv-0x78) [0x00000000]
    GNU = _BTFmt_GNU,

    /// object'symbol+offset [pc]
    Solaris = _BTFmt_Solaris
}

private bool atMostOneBTFmt()
{
    size_t trueCnt = 0;

    foreach (fmt; __traits(allMembers, BacktraceFmt))
        if (__traits(getMember, BacktraceFmt, fmt)) ++trueCnt;

    return trueCnt <= 1;
}

static assert(atMostOneBTFmt, "Cannot be set more than one BacktraceFmt at the same time.");

/**
  * Takes a `backtrace_symbols` output and identifies the mangled symbol
  * name in it. Optionally, also sets the begin and end indices of the symbol name in
  * the input buffer.
  *
  * Params:
  *  btBuf = The input buffer containing the output of `backtrace_symbols`
  *  symBeg = Output parameter indexing the first character of the symbol's name
  *  symEnd = Output parameter indexing the first character after the symbol's name
  *
  * Returns:
  *  The name of the symbol
  */
static if (hasExecinfo)
const(char)[] getMangledSymbolName(const(char)[] btBuf, out size_t symBeg,
        out size_t symEnd) @nogc nothrow
{
    static if (BacktraceFmt.Darwin)
    {
        for (size_t i = 0, n = 0; i < btBuf.length; i++)
        {
            if (' ' == btBuf[i])
            {
                n++;
                while (i < btBuf.length && ' ' == btBuf[i])
                    i++;
                if (3 > n)
                    continue;

                symBeg = i;
                while (i < btBuf.length && ' ' != btBuf[i])
                    i++;
                symEnd = i;
                break;
            }
        }
    }
    else
    {
        static if (BacktraceFmt.GNU)
        {
            enum bChar = '(';
            enum eChar = ')';
        }
        else static if (BacktraceFmt.BSD)
        {
            enum bChar = '<';
            enum eChar = '>';
        }
        else static if (BacktraceFmt.Solaris)
        {
            enum bChar = '\'';
            enum eChar = '+';
        }

        foreach (i; 0 .. btBuf.length)
        {
            if (btBuf[i] == bChar)
            {
                foreach (j; i+1 .. btBuf.length)
                {
                    const e = btBuf[j];
                    if (e == eChar || e == '+' || e == '-')
                    {
                        symBeg = i + 1;
                        symEnd = j;
                        break;
                    }
                }
                break;
            }
        }
    }

    assert(symBeg <= symEnd);
    assert(symEnd < btBuf.length);

    return btBuf[symBeg .. symEnd];
}

/// ditto
static if (hasExecinfo)
const(char)[] getMangledSymbolName(const(char)[] btBuf) @nogc nothrow
{
    size_t symBeg, symEnd;
    return getMangledSymbolName(btBuf, symBeg, symEnd);
}

@nogc nothrow unittest
{
    size_t symBeg, symEnd;

    static if (BacktraceFmt.BSD)
    {
        enum bufBSD = "0x00000000 <_D6module4funcAFZv+0x78> at module";
        auto resBSD = getMangledSymbolName(bufBSD, symBeg, symEnd);
        assert("_D6module4funcAFZv" == resBSD);
        assert(12 == symBeg);
        assert(30 == symEnd);
    }
    else static if (BacktraceFmt.Darwin)
    {
        enum bufDarwin = "1  module    0x00000000 D6module4funcAFZv + 0";
        auto resDarwin = getMangledSymbolName(bufDarwin, symBeg, symEnd);
        assert("D6module4funcAFZv" == resDarwin);
        assert(24 == symBeg);
        assert(41 == symEnd);
    }
    else static if (BacktraceFmt.GNU)
    {
        enum bufGNU0 = "module(_D6module4funcAFZv) [0x00000000]";
        auto resGNU0 = getMangledSymbolName(bufGNU0, symBeg, symEnd);
        assert("_D6module4funcAFZv" == resGNU0);
        assert(7 == symBeg);
        assert(25 == symEnd);

        enum bufGNU1 = "module(_D6module4funcAFZv+0x78) [0x00000000]";
        auto resGNU1 = getMangledSymbolName(bufGNU1, symBeg, symEnd);
        assert("_D6module4funcAFZv" == resGNU1);
        assert(7 == symBeg);
        assert(25 == symEnd);

        enum bufGNU2 = "/lib/x86_64-linux-gnu/libc.so.6(__libc_start_main-0x78) [0x00000000]";
        auto resGNU2 = getMangledSymbolName(bufGNU2, symBeg, symEnd);
        assert("__libc_start_main" == resGNU2);
        assert(32 == symBeg);
        assert(49 == symEnd);
    }
    else static if (BacktraceFmt.Solaris)
    {
        enum bufSolaris = "object'symbol+offset [pc]";
        auto resSolaris = getMangledSymbolName(bufSolaris, symBeg, symEnd);
        assert("symbol" == resSolaris);
        assert(7 == symBeg);
        assert(13 == symEnd);
    }
    else
        assert(!__traits(compiles, getMangledSymbolName));
}
