/**
 * Development utility for tracking the amount of time a section of code takes.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/timeit.d, _timeit.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_timeit.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/timeit.d
 */

module dmd.root.timeit;

/// Accumulates the ticks for this section of code into the provided counter
struct TimeIt
{
    ulong *ticks_var;
    ulong begin;

    this(ulong* var)
    {
        pragma(inline, true);
        ticks_var = var;
        begin = tsc();
    }

    @disable this(this);
    @disable ref @system TimeIt opAssign(TimeIt p) return;

    ~this()
    {
        pragma(inline, true);
        *ticks_var += (tsc() - begin);
    }
}

version (D_InlineAsm_X86_64)
{
    static ulong tsc()
    {
        asm nothrow @nogc
        {
            naked;
            rdtsc;       // EAX = lo, EDX = hi
            shl RDX, 32; // hi <<= 32
            or RAX, RDX; // result = hi | lo
            ret;         // return result(RAX)
        }
    }
}
else
{
    pragma(msg, "TimeIt doesn't know how to time on this platform");
    ulong tsc()
    {
        return 0;
    }
}

///
unittest
{
        import core.stdc.stdlib;
        __gshared ulong section1_ticks;

        // section 1
        {
            foreach(_; 0 .. 4)
            {
                auto timer = TimeIt(&section1_ticks);
                // make sure to assign TimeIt to a variable.
                // the destructor will not run otherwise :-/
                int x = (_*2) / (_ + 1);
                int y = (_*4) / (_ + 2);
                int* p = cast(int*)malloc(int.sizeof);
                foreach(__; 0 .. 1024) { (*p) = x / (y + 1); }
            }
        }
}

unittest
{
    __gshared ulong section1_ticks;
    __gshared uint section1_count;
    __gshared ulong section2_ticks;
    __gshared uint section2_count;

    foreach(_; 0 .. 64)
    {
        import core.stdc.stdlib;
        // section 1
        {
            auto timer = TimeIt(&section1_ticks);
            int x = (_*2) / (_ + 1);
            int y = (_*4) / (_ + 2);
            int* p = cast(int*)malloc(int.sizeof);
            foreach(__; 0 .. 1024) { (*p) = x / (y + 1); }
            section1_count++;
        }

        // section 2
        {
            auto begin = tsc();
            scope(exit)
                section2_ticks += (tsc() - begin);

            int x = (_*2) / (_ + 1);
            int y = (_*4) / (_ + 2);
            int* p = cast(int*)malloc(int.sizeof);
            foreach(__; 0 .. 1024) { (*p) = x / (y + 1); }
            section2_count++;
        }
        import core.stdc.stdio;
    }

    assert(section1_count == 64);
    if (tsc() != 0)
    {
        import core.stdc.stdlib;
        // assumes this takes some cycles at least
        assert(section1_ticks > 8000);
        assert(section2_ticks > 8000);
        auto absdiff = llabs(long(section1_ticks) - long(section2_ticks));
        long max_absdiff = cast(long)(((section1_ticks + section2_ticks) / 2) * 0.3);
        assert(absdiff < max_absdiff, "absolute diffrence between identical code paths too high");
    }
}
