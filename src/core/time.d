//Written in the D programming language

/++
    Module containing core time functionality, such as Duration (which
    represents a duration of time).

    Various functions take a string (or strings) to represent a unit of time
    (e.g. $(D convert!("days", "hours")(numDays))). The valid strings to use
    with such functions are "years", "months", "weeks", "days", "hours",
    "minutes", "seconds", "msecs" (milliseconds), "usecs" (microseconds),
    "hnsecs" (hecto-nanoseconds - i.e. 100 ns) or some subset thereof. There
    are a few functions that also allow "nsecs", but very little actually
    has precision greater than hnsecs.

    Copyright: Copyright 2010 - 2011
    License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis and Kato Shoichi
    Source:    $(DRUNTIMESRC core/_time.d)
 +/
module core.time;

import core.exception;
import core.stdc.time;
import core.stdc.stdio;

version(Windows)
{
import core.sys.windows.windows;
}
else version(Posix)
{
import core.sys.posix.time;
import core.sys.posix.sys.time;
}

//This probably should be moved somewhere else in druntime which
//is OSX-specific.
version(OSX)
{

public import core.sys.osx.mach.kern_return;

extern(C)
{

struct mach_timebase_info_data_t
{
    uint numer;
    uint denom;
}

alias mach_timebase_info_data_t* mach_timebase_info_t;

kern_return_t mach_timebase_info(mach_timebase_info_t);

ulong mach_absolute_time();

}

}


/++
    Represents a duration of time of weeks or less (kept internally as hnsecs).
    (e.g. 22 days or 700 seconds).

    It is used when representing a duration of time - such as how long to
    sleep with $(CXREF Thread, sleep).

    In std.datetime, it is also used as the result of various arithmetic
    operations on time points.

    Use the $(D dur) function to create Durations.

    You cannot create a duration of months or years because the variable number
    of days in a month or a year makes it so that you cannot convert between
    months or years and smaller units without a specific date. Any type or
    function which handles months or years has other functions for handling
    those rather than using durations. For instance, $(XREF datetime, Date) has
    $(D addYears) and $(D addMonths) for adding years and months, rather than
    creating a duration of years or months and adding that to a
    $(XREF datetime, Date). If you're dealing with weeks or smaller, however,
    durations are what you use.

    Examples:
--------------------
assert(dur!"days"(12) == Duration(10_368_000_000_000L));
assert(dur!"hnsecs"(27) == Duration(27));
assert(std.datetime.Date(2010, 9, 7) + dur!"days"(5) ==
       std.datetime.Date(2010, 9, 12));

assert(dur!"days"(-12) == Duration(-10_368_000_000_000L));
assert(dur!"hnsecs"(-27) == Duration(-27));
assert(std.datetime.Date(2010, 9, 7) - std.datetime.Date(2010, 10, 3) ==
       dur!"days"(-26));
--------------------
 +/
struct Duration
{
    //Verify Examples.
    unittest
    {
        assert(dur!"days"(12) == Duration(10_368_000_000_000L));
        assert(dur!"hnsecs"(27) == Duration(27));
        assert(dur!"days"(-12) == Duration(-10_368_000_000_000L));
        assert(dur!"hnsecs"(-27) == Duration(-27));
    }

public:

    /++
        Compares this Duration with the given Duration.

        Returns:
            $(TABLE
            $(TR $(TD this &lt; rhs) $(TD &lt; 0))
            $(TR $(TD this == rhs) $(TD 0))
            $(TR $(TD this &gt; rhs) $(TD &gt; 0))
            )
     +/
    int opCmp(in Duration rhs) @safe const pure nothrow
    {
        if(_hnsecs < rhs._hnsecs)
            return -1;
        if(_hnsecs > rhs._hnsecs)
            return 1;

        return 0;
    }

    unittest
    {
        assert(Duration(12).opCmp(Duration(12)) == 0);
        assert(Duration(-12).opCmp(Duration(-12)) == 0);

        assert(Duration(10).opCmp(Duration(12)) < 0);
        assert(Duration(-12).opCmp(Duration(12)) < 0);

        assert(Duration(12).opCmp(Duration(10)) > 0);
        assert(Duration(12).opCmp(Duration(-12)) > 0);

        auto dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur.opCmp(dur)));
        static assert(__traits(compiles, cdur.opCmp(dur)));
        static assert(__traits(compiles, idur.opCmp(dur)));
        static assert(__traits(compiles, dur.opCmp(cdur)));
        static assert(__traits(compiles, cdur.opCmp(cdur)));
        static assert(__traits(compiles, idur.opCmp(cdur)));
        static assert(__traits(compiles, dur.opCmp(idur)));
        static assert(__traits(compiles, cdur.opCmp(idur)));
        static assert(__traits(compiles, idur.opCmp(idur)));
    }


    /++
        Adds or subtracts two Durations.

        The legal types of arithmetic for Duration using this operator are

        $(TABLE
        $(TR $(TD Duration) $(TD +) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD +) $(TD TickDuration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD TickDuration) $(TD -->) $(TD Duration))
        )

        Params:
            duration = The duration to add to or subtract from this duration.
      +/
    Duration opBinary(string op, D)(in D rhs) @safe const pure nothrow
        if((op == "+" || op == "-") &&
           (is(_Unqual!D == Duration) ||
           is(_Unqual!D == TickDuration)))
    {
        static if(is(_Unqual!D == Duration))
            return Duration(mixin("_hnsecs " ~ op ~ " rhs._hnsecs"));
        else if(is(_Unqual!D == TickDuration))
            return Duration(mixin("_hnsecs " ~ op ~ " rhs.hnsecs"));
    }

    unittest
    {
        assert(Duration(5) + Duration(7) == Duration(12));
        assert(Duration(5) - Duration(7) == Duration(-2));
        assert(Duration(7) + Duration(5) == Duration(12));
        assert(Duration(7) - Duration(5) == Duration(2));

        assert(Duration(5) + Duration(-7) == Duration(-2));
        assert(Duration(5) - Duration(-7) == Duration(12));
        assert(Duration(7) + Duration(-5) == Duration(2));
        assert(Duration(7) - Duration(-5) == Duration(12));

        assert(Duration(-5) + Duration(7) == Duration(2));
        assert(Duration(-5) - Duration(7) == Duration(-12));
        assert(Duration(-7) + Duration(5) == Duration(-2));
        assert(Duration(-7) - Duration(5) == Duration(-12));

        assert(Duration(-5) + Duration(-7) == Duration(-12));
        assert(Duration(-5) - Duration(-7) == Duration(2));
        assert(Duration(-7) + Duration(-5) == Duration(-12));
        assert(Duration(-7) - Duration(-5) == Duration(-2));

        //This should run the test on Linux systems (I don't know about other Posix systems),
        //but Windows doesn't seem to have a very round number for ticks per second
        //(1_193_182 in wine on my Linux box), so testing on Windows is harder.
        if(TickDuration.ticksPerSec == 1_000_000)
        {
            assert(Duration(5) + TickDuration.from!"usecs"(7) == Duration(75));
            assert(Duration(5) - TickDuration.from!"usecs"(7) == Duration(-65));
            assert(Duration(7) + TickDuration.from!"usecs"(5) == Duration(57));
            assert(Duration(7) - TickDuration.from!"usecs"(5) == Duration(-43));

            assert(Duration(5) + TickDuration.from!"usecs"(-7) == Duration(-65));
            assert(Duration(5) - TickDuration.from!"usecs"(-7) == Duration(75));
            assert(Duration(7) + TickDuration.from!"usecs"(-5) == Duration(-43));
            assert(Duration(7) - TickDuration.from!"usecs"(-5) == Duration(57));

            assert(Duration(-5) + TickDuration.from!"usecs"(7) == Duration(65));
            assert(Duration(-5) - TickDuration.from!"usecs"(7) == Duration(-75));
            assert(Duration(-7) + TickDuration.from!"usecs"(5) == Duration(43));
            assert(Duration(-7) - TickDuration.from!"usecs"(5) == Duration(-57));

            assert(Duration(-5) + TickDuration.from!"usecs"(-7) == Duration(-75));
            assert(Duration(-5) - TickDuration.from!"usecs"(-7) == Duration(65));
            assert(Duration(-7) + TickDuration.from!"usecs"(-5) == Duration(-57));
            assert(Duration(-7) - TickDuration.from!"usecs"(-5) == Duration(43));
        }

        auto hnsdur = Duration(12);
        const chnsdur = Duration(12);
        immutable ihnsdur = Duration(12);
        auto tdur = TickDuration.from!"usecs"(12);
        const ctdur = TickDuration.from!"usecs"(12);
        immutable itdur = TickDuration.from!"usecs"(12);
        static assert(__traits(compiles, hnsdur + hnsdur));
        static assert(__traits(compiles, chnsdur + hnsdur));
        static assert(__traits(compiles, ihnsdur + hnsdur));
        static assert(__traits(compiles, hnsdur + chnsdur));
        static assert(__traits(compiles, chnsdur + chnsdur));
        static assert(__traits(compiles, ihnsdur + chnsdur));
        static assert(__traits(compiles, hnsdur + ihnsdur));
        static assert(__traits(compiles, chnsdur + ihnsdur));
        static assert(__traits(compiles, ihnsdur + ihnsdur));

        static assert(__traits(compiles, hnsdur + tdur));
        static assert(__traits(compiles, chnsdur + tdur));
        static assert(__traits(compiles, ihnsdur + tdur));
        static assert(__traits(compiles, hnsdur + ctdur));
        static assert(__traits(compiles, chnsdur + ctdur));
        static assert(__traits(compiles, ihnsdur + ctdur));
        static assert(__traits(compiles, hnsdur + itdur));
        static assert(__traits(compiles, chnsdur + itdur));
        static assert(__traits(compiles, ihnsdur + itdur));

        static assert(__traits(compiles, hnsdur - hnsdur));
        static assert(__traits(compiles, chnsdur - hnsdur));
        static assert(__traits(compiles, ihnsdur - hnsdur));
        static assert(__traits(compiles, hnsdur - chnsdur));
        static assert(__traits(compiles, chnsdur - chnsdur));
        static assert(__traits(compiles, ihnsdur - chnsdur));
        static assert(__traits(compiles, hnsdur - ihnsdur));
        static assert(__traits(compiles, chnsdur - ihnsdur));
        static assert(__traits(compiles, ihnsdur - ihnsdur));

        static assert(__traits(compiles, hnsdur - tdur));
        static assert(__traits(compiles, chnsdur - tdur));
        static assert(__traits(compiles, ihnsdur - tdur));
        static assert(__traits(compiles, hnsdur - ctdur));
        static assert(__traits(compiles, chnsdur - ctdur));
        static assert(__traits(compiles, ihnsdur - ctdur));
        static assert(__traits(compiles, hnsdur - itdur));
        static assert(__traits(compiles, chnsdur - itdur));
        static assert(__traits(compiles, ihnsdur - itdur));
    }


    /++
        Adds or subtracts two Durations as well as assigning the result
        to this Duration.

        The legal types of arithmetic for Duration using this operator are

        $(TABLE
        $(TR $(TD Duration) $(TD +) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD +) $(TD TickDuration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD TickDuration) $(TD -->) $(TD Duration))
        )

        Params:
            rhs = The duration to add to or subtract from this DateTime.
      +/
    ref Duration opOpAssign(string op, D)(in D rhs) @safe pure nothrow
        if((op == "+" || op == "-") &&
           (is(_Unqual!D == Duration) ||
            is(_Unqual!D == TickDuration)))
    {
        static if(is(_Unqual!D == Duration))
            mixin("_hnsecs " ~ op ~ "= rhs._hnsecs;");
        else if(is(_Unqual!D == TickDuration))
            mixin("_hnsecs " ~ op ~ "= rhs.hnsecs;");

        return this;
    }

    unittest
    {
        static void testDur(string op, D)(Duration dur, in D rhs, in Duration expected, size_t line = __LINE__)
        {
            if(mixin("dur " ~ op ~ " rhs") != expected)
                throw new AssertError("op failed", __FILE__, line);

            if(dur != expected)
                throw new AssertError("op assign failed", __FILE__, line);
        }

        testDur!"+="(Duration(5), Duration(7), Duration(12));
        testDur!"-="(Duration(5), Duration(7), Duration(-2));
        testDur!"+="(Duration(7), Duration(5), Duration(12));
        testDur!"-="(Duration(7), Duration(5), Duration(2));

        testDur!"+="(Duration(5), Duration(-7), Duration(-2));
        testDur!"-="(Duration(5), Duration(-7), Duration(12));
        testDur!"+="(Duration(7), Duration(-5), Duration(2));
        testDur!"-="(Duration(7), Duration(-5), Duration(12));

        testDur!"+="(Duration(-5), Duration(7), Duration(2));
        testDur!"-="(Duration(-5), Duration(7), Duration(-12));
        testDur!"+="(Duration(-7), Duration(5), Duration(-2));
        testDur!"-="(Duration(-7), Duration(5), Duration(-12));

        testDur!"+="(Duration(-5), Duration(-7), Duration(-12));
        testDur!"-="(Duration(-5), Duration(-7), Duration(2));
        testDur!"+="(Duration(-7), Duration(-5), Duration(-12));
        testDur!"-="(Duration(-7), Duration(-5), Duration(-2));

        //This should run the test on Linux systems (I don't know about other Posix systems),
        //but Windows doesn't seem to have a very round number for ticks per second
        //(1_193_182 in wine on my Linux box), so testing on Windows is harder.
        if(TickDuration.ticksPerSec == 1_000_000)
        {
            testDur!"+="(Duration(5), TickDuration.from!"usecs"(7), Duration(75));
            testDur!"-="(Duration(5), TickDuration.from!"usecs"(7), Duration(-65));
            testDur!"+="(Duration(7), TickDuration.from!"usecs"(5), Duration(57));
            testDur!"-="(Duration(7), TickDuration.from!"usecs"(5), Duration(-43));

            testDur!"+="(Duration(5), TickDuration.from!"usecs"(-7), Duration(-65));
            testDur!"-="(Duration(5), TickDuration.from!"usecs"(-7), Duration(75));
            testDur!"+="(Duration(7), TickDuration.from!"usecs"(-5), Duration(-43));
            testDur!"-="(Duration(7), TickDuration.from!"usecs"(-5), Duration(57));

            testDur!"+="(Duration(-5), TickDuration.from!"usecs"(7), Duration(65));
            testDur!"-="(Duration(-5), TickDuration.from!"usecs"(7), Duration(-75));
            testDur!"+="(Duration(-7), TickDuration.from!"usecs"(5), Duration(43));
            testDur!"-="(Duration(-7), TickDuration.from!"usecs"(5), Duration(-57));

            testDur!"+="(Duration(-5), TickDuration.from!"usecs"(-7), Duration(-75));
            testDur!"-="(Duration(-5), TickDuration.from!"usecs"(-7), Duration(65));
            testDur!"+="(Duration(-7), TickDuration.from!"usecs"(-5), Duration(-57));
            testDur!"-="(Duration(-7), TickDuration.from!"usecs"(-5), Duration(43));
        }

        auto hnsdur = Duration(12);
        const chnsdur = Duration(12);
        immutable ihnsdur = Duration(12);
        auto tdur = TickDuration.from!"usecs"(12);
        const ctdur = TickDuration.from!"usecs"(12);
        immutable itdur = TickDuration.from!"usecs"(12);
        static assert(__traits(compiles, hnsdur += hnsdur));
        static assert(!__traits(compiles, chnsdur += hnsdur));
        static assert(!__traits(compiles, ihnsdur += hnsdur));
        static assert(__traits(compiles, hnsdur += chnsdur));
        static assert(!__traits(compiles, chnsdur += chnsdur));
        static assert(!__traits(compiles, ihnsdur += chnsdur));
        static assert(__traits(compiles, hnsdur += ihnsdur));
        static assert(!__traits(compiles, chnsdur += ihnsdur));
        static assert(!__traits(compiles, ihnsdur += ihnsdur));

        static assert(__traits(compiles, hnsdur += tdur));
        static assert(!__traits(compiles, chnsdur += tdur));
        static assert(!__traits(compiles, ihnsdur += tdur));
        static assert(__traits(compiles, hnsdur += ctdur));
        static assert(!__traits(compiles, chnsdur += ctdur));
        static assert(!__traits(compiles, ihnsdur += ctdur));
        static assert(__traits(compiles, hnsdur += itdur));
        static assert(!__traits(compiles, chnsdur += itdur));
        static assert(!__traits(compiles, ihnsdur += itdur));

        static assert(__traits(compiles, hnsdur -= hnsdur));
        static assert(!__traits(compiles, chnsdur -= hnsdur));
        static assert(!__traits(compiles, ihnsdur -= hnsdur));
        static assert(__traits(compiles, hnsdur -= chnsdur));
        static assert(!__traits(compiles, chnsdur -= chnsdur));
        static assert(!__traits(compiles, ihnsdur -= chnsdur));
        static assert(__traits(compiles, hnsdur -= ihnsdur));
        static assert(!__traits(compiles, chnsdur -= ihnsdur));
        static assert(!__traits(compiles, ihnsdur -= ihnsdur));

        static assert(__traits(compiles, hnsdur -= tdur));
        static assert(!__traits(compiles, chnsdur -= tdur));
        static assert(!__traits(compiles, ihnsdur -= tdur));
        static assert(__traits(compiles, hnsdur -= ctdur));
        static assert(!__traits(compiles, chnsdur -= ctdur));
        static assert(!__traits(compiles, ihnsdur -= ctdur));
        static assert(__traits(compiles, hnsdur -= itdur));
        static assert(!__traits(compiles, chnsdur -= itdur));
        static assert(!__traits(compiles, ihnsdur -= itdur));
    }


    /++
        The legal types of arithmetic for Duration using this operator overload are

        $(TABLE
        $(TR $(TD Duration) $(TD *) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to multiply this duration by.
      +/
    Duration opBinary(string op)(long value) @safe const pure nothrow
        if(op == "*")
    {
        return Duration(_hnsecs * value);
    }

    unittest
    {
        assert(Duration(5) * 7 == Duration(35));
        assert(Duration(7) * 5 == Duration(35));

        assert(Duration(5) * -7 == Duration(-35));
        assert(Duration(7) * -5 == Duration(-35));

        assert(Duration(-5) * 7 == Duration(-35));
        assert(Duration(-7) * 5 == Duration(-35));

        assert(Duration(-5) * -7 == Duration(35));
        assert(Duration(-7) * -5 == Duration(35));

        assert(Duration(5) * 0 == Duration(0));
        assert(Duration(-5) * 0 == Duration(0));

        auto dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur * 12));
        static assert(__traits(compiles, cdur * 12));
        static assert(__traits(compiles, idur * 12));
    }


    /++
        The legal types of arithmetic for Duration using this operator overload are

        $(TABLE
        $(TR $(TD Duration) $(TD *) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to multiply this duration by.
      +/
    ref Duration opOpAssign(string op)(long value) @safe pure nothrow
        if(op == "*")
    {
        _hnsecs *= value;

       return this;
    }

    unittest
    {
        static void testDur(Duration dur, long value, in Duration expected, size_t line = __LINE__)
        {
            if((dur *= value) != expected)
                throw new AssertError("op failed", __FILE__, line);

            if(dur != expected)
                throw new AssertError("op assign failed", __FILE__, line);
        }

        testDur(Duration(5), 7, Duration(35));
        testDur(Duration(7), 5, Duration(35));

        testDur(Duration(5), -7, Duration(-35));
        testDur(Duration(7), -5, Duration(-35));

        testDur(Duration(-5), 7, Duration(-35));
        testDur(Duration(-7), 5, Duration(-35));

        testDur(Duration(-5), -7, Duration(35));
        testDur(Duration(-7), -5, Duration(35));

        testDur(Duration(5), 0, Duration(0));
        testDur(Duration(-5), 0, Duration(0));

        auto dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur *= 12));
        static assert(!__traits(compiles, cdur *= 12));
        static assert(!__traits(compiles, idur *= 12));
    }


    /++
        The legal types of arithmetic for Duration using this operator overload are

        $(TABLE
        $(TR $(TD Duration) $(TD /) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to divide from this duration.

        Throws:
            TimeException if an attempt to divide by 0 is made.
      +/
    Duration opBinary(string op)(long value) @safe pure const
        if(op == "/")
    {
        if(value == 0)
            throw new TimeException("Attempted division by 0.");

        return Duration(_hnsecs / value);
    }

    unittest
    {
        _assertThrown!TimeException((){Duration(5) / 0;}());
        _assertThrown!TimeException((){Duration(-5) / 0;}());

        assert(Duration(5) / 7 == Duration(0));
        assert(Duration(7) / 5 == Duration(1));

        assert(Duration(5) / -7 == Duration(0));
        assert(Duration(7) / -5 == Duration(-1));

        assert(Duration(-5) / 7 == Duration(0));
        assert(Duration(-7) / 5 == Duration(-1));

        assert(Duration(-5) / -7 == Duration(0));
        assert(Duration(-7) / -5 == Duration(1));

        auto dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur / 12));
        static assert(__traits(compiles, cdur / 12));
        static assert(__traits(compiles, idur / 12));
    }


    /++
        The legal types of arithmetic for Duration using this operator overload are

        $(TABLE
        $(TR $(TD Duration) $(TD /) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to divide from this duration.

        Throws:
            TimeException if an attempt to divide by 0 is made.
      +/
    ref Duration opOpAssign(string op)(long value) @safe pure
        if(op == "/")
    {
        if(value == 0)
            throw new TimeException("Attempted division by 0.");

        _hnsecs /= value;

        return this;
    }

    unittest
    {
        _assertThrown!TimeException((){Duration(5) /= 0;}());
        _assertThrown!TimeException((){Duration(-5) /= 0;}());

        static void testDur(Duration dur, long value, in Duration expected, size_t line = __LINE__)
        {
            if((dur /= value) != expected)
                throw new AssertError("op failed", __FILE__, line);

            if(dur != expected)
                throw new AssertError("op assign failed", __FILE__, line);
        }

        testDur(Duration(5), 7, Duration(0));
        testDur(Duration(7), 5, Duration(1));

        testDur(Duration(5), -7, Duration(0));
        testDur(Duration(7), -5, Duration(-1));

        testDur(Duration(-5), 7, Duration(0));
        testDur(Duration(-7), 5, Duration(-1));

        testDur(Duration(-5), -7, Duration(0));
        testDur(Duration(-7), -5, Duration(1));

        auto dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur /= 12));
        static assert(!__traits(compiles, cdur /= 12));
        static assert(!__traits(compiles, idur /= 12));
    }


    /++
        Multiplies an integral value and a Duration.

        The legal types of arithmetic for Duration using this operator overload are

        $(TABLE
        $(TR $(TD long) $(TD *) $(TD Duration) $(TD -->) $(TD Duration))
        )

        Params:
            value = The number of units to multiply this duration by.
      +/
    Duration opBinaryRight(string op)(long value) @safe const pure nothrow
        if(op == "*")
    {
        return opBinary!op(value);
    }

    unittest
    {
        assert(5 * Duration(7) == Duration(35));
        assert(7 * Duration(5) == Duration(35));

        assert(5 * Duration(-7) == Duration(-35));
        assert(7 * Duration(-5) == Duration(-35));

        assert(-5 * Duration(7) == Duration(-35));
        assert(-7 * Duration(5) == Duration(-35));

        assert(-5 * Duration(-7) == Duration(35));
        assert(-7 * Duration(-5) == Duration(35));

        assert(0 * Duration(5) == Duration(0));
        assert(0 * Duration(-5) == Duration(0));

        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, 12 * cdur));
        static assert(__traits(compiles, 12 * idur));
    }


    /++
        Returns the negation of this Duration.
      +/
    Duration opUnary(string op)() @safe const pure nothrow
        if(op == "-")
    {
        return Duration(-_hnsecs);
    }

    unittest
    {
        assert(-Duration(7) == Duration(-7));
        assert(-Duration(5) == Duration(-5));
        assert(-Duration(-7) == Duration(7));
        assert(-Duration(-5) == Duration(5));
        assert(-Duration(0) == Duration(0));

        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, -cdur));
        static assert(__traits(compiles, -idur));
    }


    /++
        Returns a $(LREF TickDuration) with the same number of hnsecs as this
        $(LREF Duration).
      +/
    TickDuration opCast(T)() @safe const pure nothrow
        if(is(T == TickDuration))
    {
        return TickDuration.from!"hnsecs"(_hnsecs);
    }

    //Skipping tests on Windows until properly robust tests
    //can be devised and tested on a Windows box.
    //The differences in ticksPerSec on Windows makes testing
    //exact values a bit precarious.
    version(Posix) unittest
    {
        if(TickDuration.ticksPerSec == 1_000_000)
        {
            foreach(units; _TypeTuple!("seconds", "msecs", "usecs"))
            {
                auto t = TickDuration.from!units(1);
                assert(cast(TickDuration)dur!units(1) == t, units);
                t = TickDuration.from!units(2);
                assert(cast(TickDuration)dur!units(2) == t, units);
            }

            auto t = TickDuration.from!"hnsecs"(19_999_990);
            assert(cast(TickDuration)dur!"hnsecs"(19_999_990) == t);
            t = TickDuration.from!"hnsecs"(70);
            assert(cast(TickDuration)dur!"hnsecs"(70) == t);
            t = TickDuration.from!"hnsecs"(0);
            assert(cast(TickDuration)dur!"hnsecs"(7) == t);
        }

        if(TickDuration.ticksPerSec >= 10_000_000)
        {
            auto t = TickDuration.from!"hnsecs"(19_999_999);
            assert(cast(TickDuration)dur!"hnsecs"(19_999_999) == t);
            t = TickDuration.from!"hnsecs"(70);
            assert(cast(TickDuration)dur!"hnsecs"(70) == t);
            t = TickDuration.from!"hnsecs"(7);
            assert(cast(TickDuration)dur!"hnsecs"(7) == t);
        }
    }


    /++
        Returns the number of the given units in the duration
        (minus the larger units).

        Examples:
--------------------
assert(dur!"weeks"(12).get!"weeks"() == 12);
assert(dur!"weeks"(12).get!"days"() == 0);

assert(dur!"days"(13).get!"weeks"() == 1);
assert(dur!"days"(13).get!"days"() == 6);

assert(dur!"hours"(49).get!"days"() == 2);
assert(dur!"hours"(49).get!"hours"() == 1);
--------------------
      +/
    long get(string units)() @safe const pure nothrow
        if(units == "weeks" ||
           units == "days" ||
           units == "hours" ||
           units == "minutes" ||
           units == "seconds")
    {
        static if(units == "weeks")
            return getUnitsFromHNSecs!"weeks"(_hnsecs);
        else
        {
            immutable hnsecs = removeUnitsFromHNSecs!(nextLargerTimeUnits!units)(_hnsecs);

            return getUnitsFromHNSecs!units(hnsecs);
        }
    }

    unittest
    {
        //Verify Examples.
        assert(dur!"weeks"(12).get!"weeks"() == 12);
        assert(dur!"weeks"(12).get!"days"() == 0);

        assert(dur!"days"(13).get!"weeks"() == 1);
        assert(dur!"days"(13).get!"days"() == 6);

        assert(dur!"hours"(49).get!"days"() == 2);
        assert(dur!"hours"(49).get!"hours"() == 1);

        const dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur.get!"days"()));
        static assert(__traits(compiles, cdur.get!"days"()));
        static assert(__traits(compiles, idur.get!"days"()));
    }


    /++
        Returns the number of weeks in the duration.

        Examples:
--------------------
assert(dur!"weeks"(12).weeks == 12);
assert(dur!"days"(13).weeks == 1);
--------------------
      +/
    @property long weeks() @safe const pure nothrow
    {
        return get!"weeks"();
    }

    unittest
    {
        //Verify Examples.
        assert(dur!"weeks"(12).weeks == 12);
        assert(dur!"days"(13).weeks == 1);

        const dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur.weeks));
        static assert(__traits(compiles, cdur.weeks));
        static assert(__traits(compiles, idur.weeks));
    }


    /++
        Returns the number of days in the duration (minus the larger units).

        Examples:
--------------------
assert(dur!"weeks"(12).days == 0);
assert(dur!"days"(13).days == 6);
assert(dur!"hours"(49).days == 2);
--------------------
      +/
    @property long days() @safe const pure nothrow
    {
        return get!"days"();
    }

    unittest
    {
        //Verify Examples.
        assert(dur!"weeks"(12).days == 0);
        assert(dur!"days"(13).days == 6);
        assert(dur!"hours"(49).days == 2);

        const dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur.days));
        static assert(__traits(compiles, cdur.days));
        static assert(__traits(compiles, idur.days));
    }


    /++
        Returns the number of hours in the duration (minus the larger units).

        Examples:
--------------------
assert(dur!"days"(8).hours == 0);
assert(dur!"hours"(49).hours == 1);
assert(dur!"minutes"(121).hours == 2);
--------------------
      +/
    @property long hours() @safe const pure nothrow
    {
        return get!"hours"();
    }

    unittest
    {
        //Verify Examples.
        assert(dur!"days"(8).hours == 0);
        assert(dur!"hours"(49).hours == 1);
        assert(dur!"minutes"(121).hours == 2);

        const dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur.hours));
        static assert(__traits(compiles, cdur.hours));
        static assert(__traits(compiles, idur.hours));
    }


    /++
        Returns the number of minutes in the duration (minus the larger units).

        Examples:
--------------------
assert(dur!"hours"(47).minutes == 0);
assert(dur!"minutes"(127).minutes == 7);
assert(dur!"seconds"(121).minutes == 2);
--------------------
      +/
    @property long minutes() @safe const pure nothrow
    {
        return get!"minutes"();
    }

    unittest
    {
        //Verify Examples.
        assert(dur!"hours"(47).minutes == 0);
        assert(dur!"minutes"(127).minutes == 7);
        assert(dur!"seconds"(121).minutes == 2);

        const dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur.minutes));
        static assert(__traits(compiles, cdur.minutes));
        static assert(__traits(compiles, idur.minutes));
    }


    /++
        Returns the number of seconds in the duration (minus the larger units).

        Examples:
--------------------
assert(dur!"minutes"(47).seconds == 0);
assert(dur!"seconds"(127).seconds == 7);
assert(dur!"msecs"(1217).seconds == 1);
--------------------
      +/
    @property long seconds() @safe const pure nothrow
    {
        return get!"seconds"();
    }

    unittest
    {
        //Verify Examples.
        assert(dur!"minutes"(47).seconds == 0);
        assert(dur!"seconds"(127).seconds == 7);
        assert(dur!"msecs"(1217).seconds == 1);

        const dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur.seconds));
        static assert(__traits(compiles, cdur.seconds));
        static assert(__traits(compiles, idur.seconds));
    }


    /++
        Returns the fractional seconds passed the second.

        Examples:
--------------------
assert(dur!"msecs"(1000).fracSec == FracSec.from!"msecs"(0));
assert(dur!"msecs"(1217).fracSec == FracSec.from!"msecs"(217));
assert(dur!"usecs"(43).fracSec == FracSec.from!"usecs"(43));
assert(dur!"hnsecs"(50_007).fracSec == FracSec.from!"hnsecs"(50_007));
assert(dur!"nsecs"(62_127).fracSec == FracSec.from!"nsecs"(62_100));

assert(dur!"msecs"(-1000).fracSec == FracSec.from!"msecs"(-0));
assert(dur!"msecs"(-1217).fracSec == FracSec.from!"msecs"(-217));
assert(dur!"usecs"(-43).fracSec == FracSec.from!"usecs"(-43));
assert(dur!"hnsecs"(-50_007).fracSec == FracSec.from!"hnsecs"(-50_007));
assert(dur!"nsecs"(-62_127).fracSec == FracSec.from!"nsecs"(-62_100));
--------------------
     +/
    @property FracSec fracSec() @safe const pure nothrow
    {
        try
        {
            immutable hnsecs = removeUnitsFromHNSecs!("seconds")(_hnsecs);

            return FracSec.from!"hnsecs"(hnsecs);
        }
        catch(Exception e)
            assert(0, "FracSec.from!\"hnsecs\"() threw.");
    }

    //Verify Examples.
    unittest
    {
        assert(dur!"msecs"(1000).fracSec == FracSec.from!"msecs"(0));
        assert(dur!"msecs"(1217).fracSec == FracSec.from!"msecs"(217));
        assert(dur!"usecs"(43).fracSec == FracSec.from!"usecs"(43));
        assert(dur!"hnsecs"(50_007).fracSec == FracSec.from!"hnsecs"(50_007));
        assert(dur!"nsecs"(62_127).fracSec == FracSec.from!"nsecs"(62_100));

        assert(dur!"msecs"(-1000).fracSec == FracSec.from!"msecs"(-0));
        assert(dur!"msecs"(-1217).fracSec == FracSec.from!"msecs"(-217));
        assert(dur!"usecs"(-43).fracSec == FracSec.from!"usecs"(-43));
        assert(dur!"hnsecs"(-50_007).fracSec == FracSec.from!"hnsecs"(-50_007));
        assert(dur!"nsecs"(-62_127).fracSec == FracSec.from!"nsecs"(-62_100));
    }

    unittest
    {
        auto mdur = dur!"hnsecs"(12);
        const cdur = dur!"hnsecs"(12);
        immutable idur = dur!"hnsecs"(12);

        assert(mdur.fracSec == FracSec.from!"hnsecs"(12));
        assert(cdur.fracSec == FracSec.from!"hnsecs"(12));
        assert(idur.fracSec == FracSec.from!"hnsecs"(12));
    }


    /++
        Returns the total number of the given units in the duration.
        So, unlike $(D get()), it does not strip out the larger
        units.

        Examples:
--------------------
assert(dur!"weeks"(12).total!"weeks"() == 12);
assert(dur!"weeks"(12).total!"days"() == 84);

assert(dur!"days"(13).total!"weeks"() == 1);
assert(dur!"days"(13).total!"days"() == 13);

assert(dur!"hours"(49).total!"days"() == 2);
assert(dur!"hours"(49).total!"hours"() == 49);

assert(dur!"nsecs"(2007).total!"hnsecs"() == 20);
assert(dur!"nsecs"(2007).total!"nsecs"() == 2000);
--------------------
      +/
    @property long total(string units)() @safe const pure nothrow
        if(units == "weeks" ||
           units == "days" ||
           units == "hours" ||
           units == "minutes" ||
           units == "seconds" ||
           units == "msecs" ||
           units == "usecs" ||
           units == "hnsecs" ||
           units == "nsecs")
    {
        static if(units == "nsecs")
            return convert!("hnsecs", "nsecs")(_hnsecs);
        else
            return getUnitsFromHNSecs!units(_hnsecs);
    }

    unittest
    {
        //Verify Examples.
        assert(dur!"weeks"(12).total!"weeks" == 12);
        assert(dur!"weeks"(12).total!"days" == 84);

        assert(dur!"days"(13).total!"weeks" == 1);
        assert(dur!"days"(13).total!"days" == 13);

        assert(dur!"hours"(49).total!"days" == 2);
        assert(dur!"hours"(49).total!"hours" == 49);

        assert(dur!"nsecs"(2007).total!"hnsecs" == 20);
        assert(dur!"nsecs"(2007).total!"nsecs" == 2000);

        const dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        dur.total!"days"; // just check that it compiles
        cdur.total!"days"; // just check that it compiles
        idur.total!"days"; // just check that it compiles
    }


    /+
        Converts this duration to a string.
      +/
    //Due to bug http://d.puremagic.com/issues/show_bug.cgi?id=3715 , we can't
    //have versions of toString() with extra modifiers, so we define one version
    //with modifiers and one without.
    string toString()
    {
        return _toStringImpl();
    }


    /++
        Converts this duration to a string.
      +/
    //Due to bug http://d.puremagic.com/issues/show_bug.cgi?id=3715 , we can't
    //have versions of toString() with extra modifiers, so we define one version
    //with modifiers and one without.
    string toString() @safe const pure nothrow
    {
        return _toStringImpl();
    }

    unittest
    {
        const dur = Duration(12);
        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(__traits(compiles, dur.toString()));
        static assert(__traits(compiles, cdur.toString()));
        static assert(__traits(compiles, idur.toString()));
    }


    @property bool isNegative() @safe const pure nothrow
    {
        return _hnsecs < 0;
    }

    unittest
    {
        assert(!Duration(100).isNegative);
        assert(!Duration(1).isNegative);
        assert(!Duration(0).isNegative);
        assert(Duration(-1).isNegative);
        assert(Duration(-100).isNegative);
    }


private:

    /++
        Since we have two versions of toString(), we have _toStringImpl()
        so that they can share implementations.
      +/
    string _toStringImpl() @safe const pure nothrow
    {
        long hnsecs = _hnsecs;

        immutable weeks = splitUnitsFromHNSecs!"weeks"(hnsecs);
        immutable days = splitUnitsFromHNSecs!"days"(hnsecs);
        immutable hours = splitUnitsFromHNSecs!"hours"(hnsecs);
        immutable minutes = splitUnitsFromHNSecs!"minutes"(hnsecs);
        immutable seconds = splitUnitsFromHNSecs!"seconds"(hnsecs);
        immutable milliseconds = splitUnitsFromHNSecs!"msecs"(hnsecs);
        immutable microseconds = splitUnitsFromHNSecs!"usecs"(hnsecs);

        try
        {
            auto totalUnits = 0;

            if(weeks != 0)
                ++totalUnits;
            if(days != 0)
                ++totalUnits;
            if(hours != 0)
                ++totalUnits;
            if(minutes != 0)
                ++totalUnits;
            if(seconds != 0)
                ++totalUnits;
            if(milliseconds != 0)
                ++totalUnits;
            if(microseconds != 0)
                ++totalUnits;
            if(hnsecs != 0)
                ++totalUnits;

            string retval;
            auto unitsUsed = 0;

            string unitsToPrint(string units, bool plural)
            {
                if(units == "seconds")
                    return plural ? "secs" : "sec";
                else if(units == "msecs")
                    return "ms";
                else if(units == "usecs")
                    return "μs";
                else
                    return plural ? units : units[0 .. $-1];
            }

            void addUnitStr(string units, long value)
            {
                if(value != 0)
                {
                    auto utp = unitsToPrint(units, value != 1);
                    auto valueStr = numToString(value);

                    if(unitsUsed == 0)
                        retval ~= valueStr ~ " " ~ utp;
                    else if(unitsUsed == totalUnits - 1)
                    {
                        if(totalUnits == 2)
                            retval ~= " and " ~ valueStr ~ " " ~ utp;
                        else
                            retval ~= ", and " ~ valueStr ~ " " ~ utp;
                    }
                    else
                        retval ~= ", " ~ valueStr ~ " " ~ utp;

                    ++unitsUsed;
                }
            }

            addUnitStr("weeks", weeks);
            addUnitStr("days", days);
            addUnitStr("hours", hours);
            addUnitStr("minutes", minutes);
            addUnitStr("seconds", seconds);
            addUnitStr("msecs", milliseconds);
            addUnitStr("usecs", microseconds);
            addUnitStr("hnsecs", hnsecs);

            if(retval.length == 0)
                return "0 hnsecs";

            return retval;
        }
        catch(Exception e)
            assert(0, "Something threw when nothing can throw.");
    }

    unittest
    {
        assert(Duration(0).toString() == "0 hnsecs");
        assert(Duration(1).toString() == "1 hnsec");
        assert(Duration(7).toString() == "7 hnsecs");
        assert(Duration(10).toString() == "1 μs");
        assert(Duration(20).toString() == "2 μs");
        assert(Duration(10_000).toString() == "1 ms");
        assert(Duration(20_000).toString() == "2 ms");
        assert(Duration(10_000_000).toString() == "1 sec");
        assert(Duration(20_000_000).toString() == "2 secs");
        assert(Duration(600_000_000).toString() == "1 minute");
        assert(Duration(1_200_000_000).toString() == "2 minutes");
        assert(Duration(36_000_000_000).toString() == "1 hour");
        assert(Duration(72_000_000_000).toString() == "2 hours");
        assert(Duration(864_000_000_000).toString() == "1 day");
        assert(Duration(1_728_000_000_000).toString() == "2 days");
        assert(Duration(6_048_000_000_000).toString() == "1 week");
        assert(Duration(12_096_000_000_000).toString() == "2 weeks");

        assert(Duration(12).toString() == "1 μs and 2 hnsecs");
        assert(Duration(120_795).toString() == "12 ms, 79 μs, and 5 hnsecs");
        assert(Duration(12_096_020_900_003).toString() == "2 weeks, 2 secs, 90 ms, and 3 hnsecs");

        assert(Duration(-1).toString() == "-1 hnsecs");
        assert(Duration(-7).toString() == "-7 hnsecs");
        assert(Duration(-10).toString() == "-1 μs");
        assert(Duration(-20).toString() == "-2 μs");
        assert(Duration(-10_000).toString() == "-1 ms");
        assert(Duration(-20_000).toString() == "-2 ms");
        assert(Duration(-10_000_000).toString() == "-1 secs");
        assert(Duration(-20_000_000).toString() == "-2 secs");
        assert(Duration(-600_000_000).toString() == "-1 minutes");
        assert(Duration(-1_200_000_000).toString() == "-2 minutes");
        assert(Duration(-36_000_000_000).toString() == "-1 hours");
        assert(Duration(-72_000_000_000).toString() == "-2 hours");
        assert(Duration(-864_000_000_000).toString() == "-1 days");
        assert(Duration(-1_728_000_000_000).toString() == "-2 days");
        assert(Duration(-6_048_000_000_000).toString() == "-1 weeks");
        assert(Duration(-12_096_000_000_000).toString() == "-2 weeks");

        assert(Duration(-12).toString() == "-1 μs and -2 hnsecs");
        assert(Duration(-120_795).toString() == "-12 ms, -79 μs, and -5 hnsecs");
        assert(Duration(-12_096_020_900_003).toString() == "-2 weeks, -2 secs, -90 ms, and -3 hnsecs");
    }


    /++
        Params:
            hnsecs = The total number of hecto-nanoseconds in this duration.
      +/
    @safe pure nothrow this(long hnsecs)
    {
        _hnsecs = hnsecs;
    }


    long _hnsecs;
}


/++
    This allows you to construct a Duration from the given time units
    with the given length.

    The possible values for units are "weeks", "days", "hours", "minutes",
    "seconds", "msecs" (milliseconds), "usecs", (microseconds),
    "hnsecs" (hecto-nanoseconds, i.e. 100 ns), and "nsecs".

    Params:
        units  = The time units of the duration (e.g. "days").
        length = The number of units in the duration.
  +/
Duration dur(string units)(long length) @safe pure nothrow
    if(units == "weeks" ||
       units == "days" ||
       units == "hours" ||
       units == "minutes" ||
       units == "seconds" ||
       units == "msecs" ||
       units == "usecs" ||
       units == "hnsecs" ||
       units == "nsecs")
{
    return Duration(convert!(units, "hnsecs")(length));
}

unittest
{
    assert(dur!"weeks"(7).total!"weeks"() == 7);
    assert(dur!"days"(7).total!"days"() == 7);
    assert(dur!"hours"(7).total!"hours"() == 7);
    assert(dur!"minutes"(7).total!"minutes"() == 7);
    assert(dur!"seconds"(7).total!"seconds"() == 7);
    assert(dur!"msecs"(7).total!"msecs"() == 7);
    assert(dur!"usecs"(7).total!"usecs"() == 7);
    assert(dur!"hnsecs"(7).total!"hnsecs"() == 7);
    assert(dur!"nsecs"(7).total!"nsecs"() == 0);
}


/++
   Duration in system clock ticks.

   This type maintains the most high precision ticks of system clock in each
   environment.
  +/
struct TickDuration
{
    /++
       The number of ticks that the system clock has in one second.

       Confirm that it is not 0, to examine whether you can use TickDuration.
      +/
    static immutable long ticksPerSec;


    /++
       TickDuration when application begins.
      +/
    static immutable TickDuration appOrigin;


    @trusted shared static this()
    {
        version(Windows)
        {
            if(QueryPerformanceFrequency(cast(long*)&ticksPerSec) == 0)
                ticksPerSec = 0;
        }
        else version(OSX)
        {
            static if(is(typeof(mach_absolute_time)))
            {
                mach_timebase_info_data_t info;

                if(mach_timebase_info(&info))
                    ticksPerSec = 0;
                else
                    ticksPerSec = (1_000_000_000 * info.numer) / info.denom;
            }
            else
                ticksPerSec = 1_000_000;
        }
        else version(Posix)
        {
            static if(is(typeof(clock_gettime)))
            {
                timespec ts;

                if(clock_getres(CLOCK_MONOTONIC, &ts) != 0)
                    ticksPerSec = 0;
                else
                    ticksPerSec = 1_000_000_000 / ts.tv_nsec;
            }
            else
                ticksPerSec = 1_000_000;
        }

        if(ticksPerSec != 0)
            appOrigin = TickDuration.currSystemTick;
    }

    unittest
    {
        assert(ticksPerSec);
    }


    /++
       The number of ticks.

       You can convert this length into number of seconds by dividing it
       by ticksPerSec.
      +/
    long length;


    /++
        Converts TickDuration to the given units as an integral value.

        Params:
            units = The units to convert to. "seconds" and smaller only.
            T     = The integral type to convert to.
      +/
    T to(string units, T)() @safe const pure nothrow
        if((units == "seconds" ||
            units == "msecs" ||
            units == "usecs" ||
            units == "hnsecs" ||
            units == "nsecs") &&
           (__traits(isIntegral, T) && T.sizeof >= 4))
    {
        enum unitsPerSec = convert!("seconds", units)(1);

        if(ticksPerSec >= unitsPerSec)
            return cast(T)(length / (ticksPerSec / unitsPerSec));
        else
            return cast(T)(length * (unitsPerSec / ticksPerSec));
    }


    /++
        Converts TickDuration to the given units as a floating point value.

        Params:
            units = The units to convert to. "seconds" and smaller only.
            T     = The floating point type to convert to.
      +/
    T to(string units, T)() @safe const pure nothrow
        if((units == "seconds" ||
            units == "msecs" ||
            units == "usecs" ||
            units == "hnsecs" ||
            units == "nsecs") &&
           __traits(isFloating, T))
    {
        static if(units == "seconds")
            return length / cast(T)ticksPerSec;
        else
        {
            enum unitsPerSec = convert!("seconds", units)(1);

            return to!("seconds", T) * unitsPerSec;
        }
   }

    /++
        Alias for converting TickDuration to seconds.
      +/
    @property long seconds() @safe const pure nothrow
    {
        return to!("seconds", long)();
    }

    unittest
    {
        auto t = TickDuration(ticksPerSec);
        assert(t.seconds == 1);
        t = TickDuration(ticksPerSec-1);
        assert(t.seconds == 0);
        t = TickDuration(ticksPerSec*2);
        assert(t.seconds == 2);
        t = TickDuration(ticksPerSec*2-1);
        assert(t.seconds == 1);
        t = TickDuration(-1);
        assert(t.seconds == 0);
        t = TickDuration(-ticksPerSec-1);
        assert(t.seconds == -1);
        t = TickDuration(-ticksPerSec);
        assert(t.seconds == -1);
    }

    /++
        Alias for converting TickDuration to milliseconds.
      +/
    @property long msecs() @safe const pure nothrow
    {
        return to!("msecs", long)();
    }


    /++
        Alias for converting TickDuration to microseconds.
      +/
    @property long usecs() @safe const pure nothrow
    {
        return to!("usecs", long)();
    }


    /++
        Alias for converting TickDuration to hecto-nanoseconds (100 ns).
      +/
    @property long hnsecs() @safe const pure nothrow
    {
        return to!("hnsecs", long)();
    }


    /++
        Alias for converting TickDuration to nanoseconds.
      +/
    @property long nsecs() @safe const pure nothrow
    {
        return to!("nsecs", long)();
    }


    /++
        Creates a TickDuration from the number of the given units.

        Params:
            units = The units to convert from. "seconds" and smaller.
            value = The number of the units to convert from.
      +/
    static TickDuration from(string units)(long value) @safe pure nothrow
        if(units == "seconds" ||
           units == "msecs" ||
           units == "usecs" ||
           units == "hnsecs" ||
           units == "nsecs")
    {
        enum unitsPerSec = convert!("seconds", units)(1);

        if(ticksPerSec >= unitsPerSec)
            return TickDuration(value * (ticksPerSec / unitsPerSec));
        else
            return TickDuration(value / (unitsPerSec / ticksPerSec));
    }

    //test from!"seconds"().
    unittest
    {
        auto t = TickDuration.from!"seconds"(1_000_000);
        assert(t.seconds == 1_000_000);
        t = TickDuration.from!"seconds"(2_000_000);
        assert(t.seconds == 2_000_000);

        if(ticksPerSec >= 1)
        {
            t.length -= 1;
            assert(t.seconds == 1_999_999);
        }

        if(ticksPerSec >= 1)
            assert(TickDuration.from!"seconds"(7).seconds == 7);
    }

    //test from!"msecs"().
    unittest
    {
        auto t = TickDuration.from!"msecs"(1_000_000);
        assert(t.msecs == 1_000_000);
        t = TickDuration.from!"msecs"(2_000_000);
        assert(t.msecs == 2_000_000);

        if(ticksPerSec >= 1000)
        {
            t.length -= 1;
            assert(t.msecs == 1_999_999);
        }

        if(ticksPerSec >= 1_000)
            assert(TickDuration.from!"msecs"(7).msecs == 7);
    }

    //test from!"usecs"().
    unittest
    {
        auto t = TickDuration.from!"usecs"(1_000_000);
        assert(t.usecs == 1_000_000);
        t = TickDuration.from!"usecs"(2_000_000);
        assert(t.usecs == 2_000_000);

        if(ticksPerSec >= 1_000_000)
        {
            t.length -= 1;
            assert(t.usecs == 1_999_999);
        }

        if(ticksPerSec >= 1_000_000)
            assert(TickDuration.from!"usecs"(7).usecs == 7);
    }

    //test from!"hnsecs"().
    //Skipping tests on Windows until properly robust tests
    //can be devised and tested on a Windows box.
    //The differences in ticksPerSec on Windows makes testing
    //exact values a bit precarious.
    version(Posix) unittest
    {
        auto t = TickDuration.from!"hnsecs"(10_000_000);
        assert(t.hnsecs == 10_000_000);
        t = TickDuration.from!"hnsecs"(20_000_000);
        assert(t.hnsecs == 20_000_000);

        if(ticksPerSec == 1_000_000)
        {
            t.length -= 1;
            assert(t.hnsecs == 19999990);
            assert(TickDuration.from!"hnsecs"(70).hnsecs == 70);
            assert(TickDuration.from!"hnsecs"(7).hnsecs == 0);
        }

        if(ticksPerSec >= 10_000_000)
        {
            t.length -= 1;
            assert(t.hnsecs == 19999999);
            assert(TickDuration.from!"hnsecs"(70).hnsecs == 70);
            assert(TickDuration.from!"hnsecs"(7).hnsecs == 7);
        }
    }

    //test from!"nsecs"().
    //Skipping tests everywhere except for Linux until properly robust tests
    //can be devised.
    version(Linux) unittest
    {
        auto t = TickDuration.from!"nsecs"(1_000_000_000);
        assert(t.nsecs == 1_000_000_000);
        t = TickDuration.from!"nsecs"(2_000_000_000);
        assert(t.nsecs == 2_000_000_000);

        if(ticksPerSec == 1_000_000)
        {
            t.length -= 1;
            assert(t.nsecs == 1999999000);
        }

        if(ticksPerSec >= 1_000_000_000)
        {
            t.length -= 1;
            assert(t.nsecs == 1999999999);
        }
    }


    /++
        Returns a $(LREF Duration) with the same number of hnsecs as this
        $(LREF TickDuration).
      +/
    Duration opCast(T)() @safe const pure nothrow
        if(is(T == Duration))
    {
        return Duration(hnsecs);
    }

    //Skipping tests on Windows until properly robust tests
    //can be devised and tested on a Windows box.
    //The differences in ticksPerSec on Windows makes testing
    //exact values a bit precarious.
    version(linux) unittest
    {
        foreach(units; _TypeTuple!("seconds", "msecs", "usecs"))
        {
            auto d = dur!units(1);
            assert(cast(Duration)TickDuration.from!units(1) == d, units);
            d = dur!units(2);
            assert(cast(Duration)TickDuration.from!units(2) == d, units);
        }

        if(ticksPerSec == 1_000_000)
        {
            auto d = dur!"hnsecs"(19_999_990);
            assert(cast(Duration)TickDuration.from!"hnsecs"(19_999_990) == d);
            d = dur!"hnsecs"(70);
            assert(cast(Duration)TickDuration.from!"hnsecs"(70) == d);
            d = dur!"hnsecs"(0);
            assert(cast(Duration)TickDuration.from!"hnsecs"(7) == d);
        }

        if(ticksPerSec >= 10_000_000)
        {
            auto d = dur!"hnsecs"(19_999_990);
            assert(cast(Duration)TickDuration.from!"hnsecs"(19_999_990) == d);
            d = dur!"hnsecs"(70);
            assert(cast(Duration)TickDuration.from!"hnsecs"(70) == d);
            d = dur!"hnsecs"(7);
            assert(cast(Duration)TickDuration.from!"hnsecs"(7) == d);
        }
    }


    /++
       operator overloading "-=, +="
      +/
    ref TickDuration opOpAssign(string op)(in TickDuration rhs) @safe pure nothrow
        if(op == "+" || op == "-")
    {
        mixin("length " ~ op ~ "= rhs.length;");
        return this;
    }

    unittest
    {
        TickDuration a = TickDuration.currSystemTick, b = TickDuration.currSystemTick;
        a += TickDuration.currSystemTick;
        assert(a.to!("seconds", real)() >= 0);
        b -= TickDuration.currSystemTick;
        assert(b.to!("seconds", real)() <= 0);
    }


    /++
       operator overloading "-, +"
      +/
    TickDuration opBinary(string op)(in TickDuration rhs) @safe const pure nothrow
        if(op == "-" || op == "+")
    {
        return TickDuration(mixin("length " ~ op ~ " rhs.length"));
    }

    unittest
    {
        auto a = TickDuration.currSystemTick;
        auto b = TickDuration.currSystemTick;
        assert((a + b).to!("seconds", real)() > 0);
        assert((a - b).to!("seconds", real)() <= 0);
    }


    /++
        Returns the negation of this TickDuration.
      +/
    TickDuration opUnary(string op)() @safe const pure nothrow
        if(op == "-")
    {
        return TickDuration(-length);
    }

    unittest
    {
        assert(-TickDuration(7) == TickDuration(-7));
        assert(-TickDuration(5) == TickDuration(-5));
        assert(-TickDuration(-7) == TickDuration(7));
        assert(-TickDuration(-5) == TickDuration(5));
        assert(-TickDuration(0) == TickDuration(0));

        const cdur = TickDuration(12);
        immutable idur = TickDuration(12);
        static assert(__traits(compiles, -cdur));
        static assert(__traits(compiles, -idur));
    }


    /++
       operator overloading "=="
      +/
    bool opEquals(ref const TickDuration rhs) @safe const pure nothrow
    {
        return length == rhs.length;
    }

    unittest
    {
        auto t1 = TickDuration.currSystemTick;
        assert(t1 == t1);
    }


    /++
       operator overloading "<, >, <=, >="
      +/
    int opCmp(ref const TickDuration rhs) @safe const pure nothrow
    {
        return length < rhs.length ? -1 : (length == rhs.length ? 0 : 1);
    }

    unittest
    {
        auto t1 = TickDuration.currSystemTick;
        auto t2 = TickDuration.currSystemTick;
        assert(t1 <= t2);
        assert(t2 >= t1);
    }


    /++
        The legal types of arithmetic for TickDuration using this operator overload are

        $(TABLE
        $(TR $(TD TickDuration) $(TD *) $(TD long) $(TD -->) $(TD TickDuration))
        $(TR $(TD TickDuration) $(TD *) $(TD floating point) $(TD -->) $(TD TickDuration))
        )

        Params:
            value = The value to divide from this duration.
      +/
    void opOpAssign(string op, T)(T value) @safe pure nothrow
        if(op == "*" &&
           (__traits(isIntegral, T) || __traits(isFloating, T)))
    {
        length *= value;
    }

    unittest
    {
        immutable t = TickDuration.currSystemTick;
        TickDuration t1 = t, t2 = t;
        t1 /= 2;
        assert(t1 < t);
        t2 /= 2.1L;
        assert(t2 < t1);
    }


    /++
        The legal types of arithmetic for TickDuration using this operator overload are

        $(TABLE
        $(TR $(TD TickDuration) $(TD /) $(TD long) $(TD -->) $(TD TickDuration))
        $(TR $(TD TickDuration) $(TD /) $(TD floating point) $(TD -->) $(TD TickDuration))
        )

        Params:
            value = The value to divide from this duration.

        Throws:
            TimeException if an attempt to divide by 0 is made.
      +/
    void opOpAssign(string op, T)(T value) @safe pure
        if(op == "/" &&
           (__traits(isIntegral, T) || __traits(isFloating, T)))
    {
        if(value == 0)
            throw new TimeException("Attempted division by 0.");

        length /= value;
    }

    unittest
    {
        immutable t = TickDuration.currSystemTick;
        TickDuration t1 = t, t2 = t;
        t1 /= 2;
        assert(t1 < t);
        t2 /= 2.1L;
        assert(t2 < t1);
    }


    /++
        The legal types of arithmetic for TickDuration using this operator overload are

        $(TABLE
        $(TR $(TD TickDuration) $(TD *) $(TD long) $(TD -->) $(TD TickDuration))
        $(TR $(TD TickDuration) $(TD *) $(TD floating point) $(TD -->) $(TD TickDuration))
        )

        Params:
            value = The value to divide from this duration.
      +/
    TickDuration opBinary(string op, T)(T value) @safe const pure nothrow
        if(op == "*" &&
           (__traits(isIntegral, T) || __traits(isFloating, T)))
    {
        return TickDuration(cast(long)(length * value));
    }

    unittest
    {
        auto t = TickDuration.currSystemTick;
        auto t2 = t*2;
        assert(t < t2);
        assert(t*3.5 > t2);
    }


    /++
        The legal types of arithmetic for TickDuration using this operator overload are

        $(TABLE
        $(TR $(TD TickDuration) $(TD /) $(TD long) $(TD -->) $(TD TickDuration))
        $(TR $(TD TickDuration) $(TD /) $(TD floating point) $(TD -->) $(TD TickDuration))
        )

        Params:
            value = The value to divide from this duration.

        Throws:
            TimeException if an attempt to divide by 0 is made.
      +/
    TickDuration opBinary(string op, T)(T value) @safe const pure
        if(op == "/" &&
           (__traits(isIntegral, T) || __traits(isFloating, T)))
    {
        if(value == 0)
            throw new TimeException("Attempted division by 0.");

        return TickDuration(cast(long)(length / value));
    }


    /++
        Params:
            ticks = The number of ticks in the TickDuration.
      +/
    @safe pure nothrow this(long ticks)
    {
        this.length = ticks;
    }


    /++
        The current system tick. The number of ticks per second varies from
        system to system. This uses a monotonic clock, so it's intended for
        precision timing by comparing relative time values, not for getting
        the current system time.

        On Windows, QueryPerformanceCounter() is used. On Mac OS X,
        mach_absolute_time() is used, while on other Posix systems,
        clock_gettime() is used. If mach_absolute_time() or clock_gettime()
        is unavailable, then Posix systems use gettimeofday(), which
        unfortunately, is not monotonic, but without
        mach_absolute_time()/clock_gettime() available, gettimeofday() is the
        the best that you can do.

        Warning:
            On some systems, the monotonic clock may stop counting when
            the computer goes to sleep or hibernates. So, the monotonic
            clock could be off if that occurs. This is known to happen
            on Mac OS X. It has not been tested whether it occurs on
            either Windows or on Linux.

        Throws:
            TimeException if it fails to get the time.
      +/
    static @property TickDuration currSystemTick() @trusted
    {
        version(Windows)
        {
            ulong ticks;

            if(QueryPerformanceCounter(cast(long*)&ticks) == 0)
                // This probably cannot happen on Windows 95 or later
                throw new TimeException("Failed in QueryPerformanceCounter().");

            return TickDuration(ticks);
        }
        else version(OSX)
        {
            static if(is(typeof(mach_absolute_time)))
                return TickDuration(cast(long)mach_absolute_time());
            else
            {
                timeval tv;
                if(gettimeofday(&tv, null) != 0)
                    throw new TimeException("Failed in gettimeofday().");

                return TickDuration(tv.tv_sec * TickDuration.ticksPerSec +
                                    tv.tv_usec * TickDuration.ticksPerSec / 1000 / 1000);
            }
        }
        else version(Posix)
        {
            static if(is(typeof(clock_gettime)))
            {
                timespec ts;

                if(clock_gettime(CLOCK_MONOTONIC, &ts) != 0)
                    throw new TimeException("Failed in clock_gettime().");

                return TickDuration(ts.tv_sec * TickDuration.ticksPerSec +
                                    ts.tv_nsec * TickDuration.ticksPerSec / 1000 / 1000 / 1000);
            }
            else
            {
                timeval tv;
                if(gettimeofday(&tv, null) != 0)
                    throw new TimeException("Failed in gettimeofday().");

                return TickDuration(tv.tv_sec * TickDuration.ticksPerSec +
                                    tv.tv_usec * TickDuration.ticksPerSec / 1000 / 1000);
            }
        }
    }

    unittest
    {
        assert(TickDuration.currSystemTick.length > 0);
    }
}


/++
    Generic way of converting between two time units. Conversions to smaller
    units use truncating division.

    Params:
        tuFrom = The units of time to covert from.
        tuFrom = The units of time to covert type.
        value  = The value to convert.

    Examples:
--------------------
assert(convert!("years", "months")(1) == 12);
assert(convert!("months", "years")(12) == 1);
--------------------
  +/
long convert(string from, string to)(long value) @safe pure nothrow
    if((from == "years" || from == "months") &&
       (to == "years" || to == "months"))
{
    static if(from == "years")
    {
        static if(to == "years")
            return value;
        else static if(to == "months")
            return value * 12;
        else
            static assert(0, "A generic month or year cannot be converted to or from smaller units.");
    }
    else static if(from == "months")
    {
        static if(to == "years")
            return value / 12;
        else static if(to == "months")
            return value;
        else
            static assert(0, "A generic month or year cannot be converted to or from smaller units.");
    }
    else
        static assert(0, "Template constraint broken. Invalid time unit string.");
}

//Verify Examples
unittest
{
    assert(convert!("years", "months")(1) == 12);
    assert(convert!("months", "years")(12) == 1);
}

unittest
{
    foreach(units; _TypeTuple!("weeks", "days", "hours", "seconds", "msecs", "usecs", "hnsecs"))
    {
        static assert(!__traits(compiles, convert!("years", units)(12)), units);
        static assert(!__traits(compiles, convert!(units, "years")(12)), units);
    }

    assert(convert!("years", "years")(12) == 12);
    assert(convert!("months", "months")(12) == 12);
}


/++
    Generic way of converting between two time units. Conversions to smaller
    units use truncating division.

    Params:
        tuFrom = The units of time to covert from.
        tuFrom = The units of time to covert type.
        value  = The value to convert.

    Examples:
--------------------
assert(convert!("weeks", "days")(1) == 7);
assert(convert!("hours", "seconds")(1) == 3600);
assert(convert!("seconds", "days")(1) == 0);
assert(convert!("seconds", "days")(86_400) == 1);
--------------------
  +/
static long convert(string from, string to)(long value) @safe pure nothrow
    if((from == "weeks" ||
        from == "days" ||
        from == "hours" ||
        from == "minutes" ||
        from == "seconds" ||
        from == "msecs" ||
        from == "usecs" ||
        from == "hnsecs") &&
       (to == "weeks" ||
        to == "days" ||
        to == "hours" ||
        to == "minutes" ||
        to == "seconds" ||
        to == "msecs" ||
        to == "usecs" ||
        to == "hnsecs"))
{
    return (hnsecsPer!from * value) / hnsecsPer!to;
}


//Verify Examples.
unittest
{
    assert(convert!("weeks", "days")(1) == 7);
    assert(convert!("hours", "seconds")(1) == 3600);
    assert(convert!("seconds", "days")(1) == 0);
    assert(convert!("seconds", "days")(86_400) == 1);
}

unittest
{
    assert(convert!("weeks", "hnsecs")(1) == 6_048_000_000_000L);
    assert(convert!("days", "hnsecs")(1) == 864_000_000_000L);
    assert(convert!("hours", "hnsecs")(1) == 36_000_000_000L);
    assert(convert!("minutes", "hnsecs")(1) == 600_000_000L);
    assert(convert!("seconds", "hnsecs")(1) == 10_000_000L);
    assert(convert!("msecs", "hnsecs")(1) == 10_000);
    assert(convert!("usecs", "hnsecs")(1) == 10);

    assert(convert!("hnsecs", "weeks")(6_048_000_000_000L) == 1);
    assert(convert!("hnsecs", "days")(864_000_000_000L) == 1);
    assert(convert!("hnsecs", "hours")(36_000_000_000L) == 1);
    assert(convert!("hnsecs", "minutes")(600_000_000L) == 1);
    assert(convert!("hnsecs", "seconds")(10_000_000L) == 1);
    assert(convert!("hnsecs", "msecs")(10_000) == 1);
    assert(convert!("hnsecs", "usecs")(10) == 1);

    foreach(units; _TypeTuple!("weeks", "days", "hours", "seconds", "msecs", "usecs", "hnsecs"))
        assert(convert!(units, units)(12) == 12);

    assert(convert!("weeks", "days")(1) == 7);
    assert(convert!("days", "weeks")(7) == 1);

    assert(convert!("days", "hours")(1) == 24);
    assert(convert!("hours", "days")(24) == 1);

    assert(convert!("hours", "minutes")(1) == 60);
    assert(convert!("minutes", "hours")(60) == 1);

    assert(convert!("minutes", "seconds")(1) == 60);
    assert(convert!("seconds", "minutes")(60) == 1);

    assert(convert!("seconds", "msecs")(1) == 1000);
    assert(convert!("msecs", "seconds")(1000) == 1);

    assert(convert!("msecs", "usecs")(1) == 1000);
    assert(convert!("usecs", "msecs")(1000) == 1);

    assert(convert!("usecs", "hnsecs")(1) == 10);
    assert(convert!("hnsecs", "usecs")(10) == 1);

    assert(convert!("hnsecs", "hnsecs")(10) == 10);
}


/++
    Generic way of converting between two time units. Conversions to smaller
    units use truncating division.

    Params:
        tuFrom = The units of time to covert from.
        tuFrom = The units of time to covert type.
        value  = The value to convert.

    Examples:
--------------------
assert(convert!("nsecs", "nsecs")(1) == 1);
assert(convert!("nsecs", "hnsecs")(1) == 0);
assert(convert!("hnsecs", "nsecs")(1) == 100);
assert(convert!("nsecs", "seconds")(1) == 0);
assert(convert!("seconds", "nsecs")(1) == 1_000_000_000);
--------------------
  +/
static long convert(string from, string to)(long value) @safe pure nothrow
    if((from == "nsecs" &&
        (to == "weeks" ||
         to == "days" ||
         to == "hours" ||
         to == "minutes" ||
         to == "seconds" ||
         to == "msecs" ||
         to == "usecs" ||
         to == "hnsecs" ||
         to == "nsecs")) ||
       (to == "nsecs" &&
        (from == "weeks" ||
         from == "days" ||
         from == "hours" ||
         from == "minutes" ||
         from == "seconds" ||
         from == "msecs" ||
         from == "usecs" ||
         from == "hnsecs" ||
         from == "nsecs")))
{
    static if(from == "nsecs" && to == "nsecs")
        return value;
    else static if(from == "nsecs")
        return convert!("hnsecs", to)(value / 100);
    else static if(to == "nsecs")
        return convert!(from, "hnsecs")(value) * 100;
    else
        static assert(0);
}

//Verify Examples
unittest
{
    assert(convert!("nsecs", "nsecs")(1) == 1);
    assert(convert!("nsecs", "hnsecs")(1) == 0);
    assert(convert!("hnsecs", "nsecs")(1) == 100);
    assert(convert!("nsecs", "seconds")(1) == 0);
    assert(convert!("seconds", "nsecs")(1) == 1_000_000_000);
}

unittest
{
    assert(convert!("weeks", "nsecs")(1) == 604_800_000_000_000L);
    assert(convert!("days", "nsecs")(1) == 86_400_000_000_000L);
    assert(convert!("hours", "nsecs")(1) == 3_600_000_000_000L);
    assert(convert!("minutes", "nsecs")(1) == 60_000_000_000L);
    assert(convert!("seconds", "nsecs")(1) == 1_000_000_000L);
    assert(convert!("msecs", "nsecs")(1) == 1_000_000);
    assert(convert!("usecs", "nsecs")(1) == 1000);
    assert(convert!("hnsecs", "nsecs")(1) == 100);

    assert(convert!("nsecs", "weeks")(604_800_000_000_000L) == 1);
    assert(convert!("nsecs", "days")(86_400_000_000_000L) == 1);
    assert(convert!("nsecs", "hours")(3_600_000_000_000L) == 1);
    assert(convert!("nsecs", "minutes")(60_000_000_000L) == 1);
    assert(convert!("nsecs", "seconds")(1_000_000_000L) == 1);
    assert(convert!("nsecs", "msecs")(1_000_000) == 1);
    assert(convert!("nsecs", "usecs")(1000) == 1);
    assert(convert!("nsecs", "hnsecs")(100) == 1);

    assert(convert!("nsecs", "nsecs")(1) == 1);
}


/++
    Represents fractional seconds.

    This is the portion of the time which is smaller than a second and cannot
    hold values which would greater than or equal to a second (or less than or
    equal to a negative second).

    It holds hnsecs internally, but you can create it using either milliseconds,
    microseconds, or hnsecs. What it does is allow for a simple way to set or
    adjust the fractional seconds portion of a $(D Duration) or a
    $(XREF datetime, SysTime) without having to worry about whether you're
    dealing with milliseconds, microseconds, or hnsecs.

    $(D FracSec)'s functions which take time unit strings do accept
    $(D "nsecs"), but the because the resolution for $(D Duration) and
    $(XREF datetime, SysTime) is hnsecs, you don't actually get precision higher
    than hnsecs. $(D "nsecs") is accepted merely for convenience. Any values
    given as nsecs will be converted to hnsecs using $(D convert) (which uses
    truncation when converting to smaller units).
  +/
struct FracSec
{
public:

    /++
        Create a $(D FracSec) from the given units ($(D "msecs"), $(D "usecs"),
        or $(D "hnsecs")).

        Params:
            units = The units to create a FracSec from.
            value = The number of the given units passed the second.

        Throws:
            $(D TimeException) if the given value would result in a $(D FracSec)
            greater than or equal to $(D 1) second or less than or equal to
            $(D -1) seconds.
      +/
    static FracSec from(string units)(long value) @safe pure
        if(units == "msecs" ||
           units == "usecs" ||
           units == "hnsecs" ||
           units == "nsecs")
    {
        return FracSec(cast(int)convert!(units, "hnsecs")(value));
    }

    unittest
    {
        assert(FracSec.from!"msecs"(0) == FracSec(0));
        assert(FracSec.from!"usecs"(0) == FracSec(0));
        assert(FracSec.from!"hnsecs"(0) == FracSec(0));

        foreach(sign; [1, -1])
        {
            _assertThrown!TimeException(from!"msecs"(1000 * sign));

            assert(FracSec.from!"msecs"(1 * sign) == FracSec(10_000 * sign));
            assert(FracSec.from!"msecs"(999 * sign) == FracSec(9_990_000 * sign));

            _assertThrown!TimeException(from!"usecs"(1_000_000 * sign));

            assert(FracSec.from!"usecs"(1 * sign) == FracSec(10 * sign));
            assert(FracSec.from!"usecs"(999 * sign) == FracSec(9990 * sign));
            assert(FracSec.from!"usecs"(999_999 * sign) == FracSec(9999_990 * sign));

            _assertThrown!TimeException(from!"hnsecs"(10_000_000 * sign));

            assert(FracSec.from!"hnsecs"(1 * sign) == FracSec(1 * sign));
            assert(FracSec.from!"hnsecs"(999 * sign) == FracSec(999 * sign));
            assert(FracSec.from!"hnsecs"(999_999 * sign) == FracSec(999_999 * sign));
            assert(FracSec.from!"hnsecs"(9_999_999 * sign) == FracSec(9_999_999 * sign));

            assert(FracSec.from!"nsecs"(1 * sign) == FracSec(0));
            assert(FracSec.from!"nsecs"(10 * sign) == FracSec(0));
            assert(FracSec.from!"nsecs"(99 * sign) == FracSec(0));
            assert(FracSec.from!"nsecs"(100 * sign) == FracSec(1 * sign));
            assert(FracSec.from!"nsecs"(99_999 * sign) == FracSec(999 * sign));
            assert(FracSec.from!"nsecs"(99_999_999 * sign) == FracSec(999_999 * sign));
            assert(FracSec.from!"nsecs"(999_999_999 * sign) == FracSec(9_999_999 * sign));
        }
    }


    /++
        Returns the negation of this FracSec.
      +/
    FracSec opUnary(string op)() @safe const nothrow
        if(op == "-")
    {
        try
            return FracSec(-_hnsecs);
        catch(Exception e)
            assert(0, "FracSec's constructor threw.");
    }

    unittest
    {
        foreach(val; [-7, -5, 0, 5, 7])
        {
            auto fs = FracSec(val);
            const cfs = FracSec(val);
            immutable ifs = FracSec(val);
            assert(-fs == FracSec(-val));
            assert(-cfs == FracSec(-val));
            assert(-ifs == FracSec(-val));
        }
    }


    /++
        The value of this FracSec as milliseconds.
      +/
    @property int msecs() @safe const pure nothrow
    {
        return cast(int)convert!("hnsecs", "msecs")(_hnsecs);
    }

    unittest
    {
        assert(FracSec(0).msecs == 0);

        foreach(sign; [1, -1])
        {
            assert(FracSec(1 * sign).msecs == 0);
            assert(FracSec(999 * sign).msecs == 0);
            assert(FracSec(999_999 * sign).msecs == 99 * sign);
            assert(FracSec(9_999_999 * sign).msecs == 999 * sign);
        }

        auto fs = FracSec(1234567);
        const cfs = FracSec(1234567);
        immutable ifs = FracSec(1234567);
        assert(fs.msecs == 123);
        assert(cfs.msecs == 123);
        assert(ifs.msecs == 123);
    }


    /++
        The value of this FracSec as milliseconds.

        Params:
            milliseconds = The number of milliseconds passed the second.

        Throws:
            TimeException if the given value is not less than one second.
      +/
    @property void msecs(int milliseconds) @safe pure
    {
        immutable hnsecs = cast(int)convert!("msecs", "hnsecs")(milliseconds);

        _enforceValid(hnsecs);
        _hnsecs = hnsecs;
    }

    unittest
    {
        static void testFS(int ms, in FracSec expected = FracSec.init, size_t line = __LINE__)
        {
            FracSec fs;
            fs.msecs = ms;

            if(fs != expected)
                throw new AssertError("", __FILE__, line);
        }

        _assertThrown!TimeException(testFS(-1000));
        _assertThrown!TimeException(testFS(1000));

        testFS(0, FracSec(0));

        foreach(sign; [1, -1])
        {
            testFS(1 * sign, FracSec(10_000 * sign));
            testFS(999 * sign, FracSec(9_990_000 * sign));
        }

        const cfs = FracSec(1234567);
        immutable ifs = FracSec(1234567);
        static assert(!__traits(compiles, cfs.msecs = 54));
        static assert(!__traits(compiles, ifs.msecs = 54));
    }


    /++
        The value of this FracSec as microseconds.
      +/
    @property int usecs() @safe const pure nothrow
    {
        return cast(int)convert!("hnsecs", "usecs")(_hnsecs);
    }

    unittest
    {
        assert(FracSec(0).usecs == 0);

        foreach(sign; [1, -1])
        {
            assert(FracSec(1 * sign).usecs == 0);
            assert(FracSec(999 * sign).usecs == 99 * sign);
            assert(FracSec(999_999 * sign).usecs == 99_999 * sign);
            assert(FracSec(9_999_999 * sign).usecs == 999_999 * sign);
        }

        auto fs = FracSec(1234567);
        const cfs = FracSec(1234567);
        immutable ifs = FracSec(1234567);
        assert(fs.usecs == 123456);
        assert(cfs.usecs == 123456);
        assert(ifs.usecs == 123456);
    }


    /++
        The value of this FracSec as microseconds.

        Params:
            microseconds = The number of microseconds passed the second.

        Throws:
            TimeException if the given value is not less than one second.
      +/
    @property void usecs(int microseconds) @safe pure
    {
        immutable hnsecs = cast(int)convert!("usecs", "hnsecs")(microseconds);

        _enforceValid(hnsecs);
        _hnsecs = hnsecs;
    }

    unittest
    {
        static void testFS(int ms, in FracSec expected = FracSec.init, size_t line = __LINE__)
        {
            FracSec fs;
            fs.usecs = ms;

            if(fs != expected)
                throw new AssertError("", __FILE__, line);
        }

        _assertThrown!TimeException(testFS(-1_000_000));
        _assertThrown!TimeException(testFS(1_000_000));

        testFS(0, FracSec(0));

        foreach(sign; [1, -1])
        {
            testFS(1 * sign, FracSec(10 * sign));
            testFS(999 * sign, FracSec(9990 * sign));
            testFS(999_999 * sign, FracSec(9_999_990 * sign));
        }

        const cfs = FracSec(1234567);
        immutable ifs = FracSec(1234567);
        static assert(!__traits(compiles, cfs.usecs = 54));
        static assert(!__traits(compiles, ifs.usecs = 54));
    }


    /++
        The value of this FracSec as hnsecs.
      +/
    @property int hnsecs() @safe const pure nothrow
    {
        return _hnsecs;
    }

    unittest
    {
        assert(FracSec(0).hnsecs == 0);

        foreach(sign; [1, -1])
        {
            assert(FracSec(1 * sign).hnsecs == 1 * sign);
            assert(FracSec(999 * sign).hnsecs == 999 * sign);
            assert(FracSec(999_999 * sign).hnsecs == 999_999 * sign);
            assert(FracSec(9_999_999 * sign).hnsecs == 9_999_999 * sign);
        }

        auto fs = FracSec(1234567);
        const cfs = FracSec(1234567);
        immutable ifs = FracSec(1234567);
        assert(fs.hnsecs == 1234567);
        assert(cfs.hnsecs == 1234567);
        assert(ifs.hnsecs == 1234567);
    }


    /++
        The value of this FracSec as hnsecs.

        Params:
            hnsecs = The number of hnsecs passed the second.

        Throws:
            TimeException if the given value is not less than one second.
      +/
    @property void hnsecs(int hnsecs) @safe pure
    {
        _enforceValid(hnsecs);
        _hnsecs = hnsecs;
    }

    unittest
    {
        static void testFS(int hnsecs, in FracSec expected = FracSec.init, size_t line = __LINE__)
        {
            FracSec fs;
            fs.hnsecs = hnsecs;

            if(fs != expected)
                throw new AssertError("", __FILE__, line);
        }

        _assertThrown!TimeException(testFS(-10_000_000));
        _assertThrown!TimeException(testFS(10_000_000));

        testFS(0, FracSec(0));

        foreach(sign; [1, -1])
        {
            testFS(1 * sign, FracSec(1 * sign));
            testFS(999 * sign, FracSec(999 * sign));
            testFS(999_999 * sign, FracSec(999_999 * sign));
            testFS(9_999_999 * sign, FracSec(9_999_999 * sign));
        }

        const cfs = FracSec(1234567);
        immutable ifs = FracSec(1234567);
        static assert(!__traits(compiles, cfs.hnsecs = 54));
        static assert(!__traits(compiles, ifs.hnsecs = 54));
    }


    /++
        The value of this FracSec as nsecs.

        Note that this does not give you any greater precision
        than getting the value of this FracSec as hnsecs.
      +/
    @property int nsecs() @safe const pure nothrow
    {
        return cast(int)convert!("hnsecs", "nsecs")(_hnsecs);
    }

    unittest
    {
        assert(FracSec(0).nsecs == 0);

        foreach(sign; [1, -1])
        {
            assert(FracSec(1 * sign).nsecs == 100 * sign);
            assert(FracSec(999 * sign).nsecs == 99_900 * sign);
            assert(FracSec(999_999 * sign).nsecs == 99_999_900 * sign);
            assert(FracSec(9_999_999 * sign).nsecs == 999_999_900 * sign);
        }

        auto fs = FracSec(1234567);
        const cfs = FracSec(1234567);
        immutable ifs = FracSec(1234567);
        assert(fs.nsecs == 123456700);
        assert(cfs.nsecs == 123456700);
        assert(ifs.nsecs == 123456700);
    }


    /++
        The value of this FracSec as nsecs.

        Note that this does not give you any greater precision
        than setting the value of this FracSec as hnsecs.

        Params:
            nsecs = The number of nsecs passed the second.

        Throws:
            TimeException if the given value is not less than one second.
      +/
    @property void nsecs(long nsecs) @safe pure
    {
        //So that -99 through -1 throw instead of result in FracSec(0).
        if(nsecs < 0)
            _enforceValid(-1);

        immutable hnsecs = cast(int)convert!("nsecs", "hnsecs")(nsecs);

        _enforceValid(hnsecs);
        _hnsecs = hnsecs;
    }

    unittest
    {
        static void testFS(long nsecs, in FracSec expected = FracSec.init, size_t line = __LINE__)
        {
            FracSec fs;
            fs.nsecs = nsecs;

            if(fs != expected)
                throw new AssertError("", __FILE__, line);
        }

        _assertThrown!TimeException(testFS(-1_000_000_000));
        _assertThrown!TimeException(testFS(1_000_000_000));

        testFS(0, FracSec(0));

        foreach(sign; [1, -1])
        {
            testFS(1 * sign, FracSec(0));
            testFS(10 * sign, FracSec(0));
            testFS(100 * sign, FracSec(1 * sign));
            testFS(999 * sign, FracSec(9 * sign));
            testFS(999_999 * sign, FracSec(9999 * sign));
            testFS(9_999_999 * sign, FracSec(99_999 * sign));
        }

        const cfs = FracSec(1234567);
        immutable ifs = FracSec(1234567);
        static assert(!__traits(compiles, cfs.nsecs = 54));
        static assert(!__traits(compiles, ifs.nsecs = 54));
    }


    /+
        Converts this duration to a string.
      +/
    //Due to bug http://d.puremagic.com/issues/show_bug.cgi?id=3715 , we can't
    //have versions of toString() with extra modifiers, so we define one version
    //with modifiers and one without.
    string toString()
    {
        return _toStringImpl();
    }


    /++
        Converts this duration to a string.
      +/
    //Due to bug http://d.puremagic.com/issues/show_bug.cgi?id=3715 , we can't
    //have versions of toString() with extra modifiers, so we define one version
    //with modifiers and one without.
    string toString() @safe const pure nothrow
    {
        return _toStringImpl();
    }

    unittest
    {
        auto fs = FracSec(12);
        const cfs = FracSec(12);
        immutable ifs = FracSec(12);
        assert(fs.toString == "12 hnsecs");
        assert(cfs.toString == "12 hnsecs");
        assert(ifs.toString == "12 hnsecs");
    }


private:

    /++
        Since we have two versions of toString(), we have _toStringImpl()
        so that they can share implementations.
      +/
    string _toStringImpl() @safe const pure nothrow
    {
        try
        {
            long hnsecs = _hnsecs;

            immutable milliseconds = splitUnitsFromHNSecs!"msecs"(hnsecs);
            immutable microseconds = splitUnitsFromHNSecs!"usecs"(hnsecs);

            if(hnsecs == 0)
            {
                if(microseconds == 0)
                {
                    if(milliseconds == 0)
                        return "0 hnsecs";
                    else
                    {
                        if(milliseconds == 1)
                            return "1 ms";
                        else
                            return numToString(milliseconds) ~ " ms";
                    }
                }
                else
                {
                    immutable fullMicroseconds = getUnitsFromHNSecs!"usecs"(_hnsecs);

                    if(fullMicroseconds == 1)
                        return "1 μs";
                    else
                        return numToString(fullMicroseconds) ~ " μs";
                }
            }
            else
            {
                if(_hnsecs == 1)
                    return "1 hnsec";
                else
                    return numToString(_hnsecs) ~ " hnsecs";
            }
        }
        catch(Exception e)
            assert(0, "Something threw when nothing can throw.");
    }

    unittest
    {
        assert(FracSec.from!"msecs"(0).toString() == "0 hnsecs");
        assert(FracSec.from!"msecs"(1).toString() == "1 ms");
        assert(FracSec.from!"msecs"(2).toString() == "2 ms");
        assert(FracSec.from!"msecs"(100).toString() == "100 ms");
        assert(FracSec.from!"msecs"(999).toString() == "999 ms");

        assert(FracSec.from!"usecs"(0).toString() == "0 hnsecs");
        assert(FracSec.from!"usecs"(1).toString() == "1 μs");
        assert(FracSec.from!"usecs"(2).toString() == "2 μs");
        assert(FracSec.from!"usecs"(100).toString() == "100 μs");
        assert(FracSec.from!"usecs"(999).toString() == "999 μs");
        assert(FracSec.from!"usecs"(1000).toString() == "1 ms");
        assert(FracSec.from!"usecs"(2000).toString() == "2 ms");
        assert(FracSec.from!"usecs"(9999).toString() == "9999 μs");
        assert(FracSec.from!"usecs"(10_000).toString() == "10 ms");
        assert(FracSec.from!"usecs"(20_000).toString() == "20 ms");
        assert(FracSec.from!"usecs"(100_000).toString() == "100 ms");
        assert(FracSec.from!"usecs"(100_001).toString() == "100001 μs");
        assert(FracSec.from!"usecs"(999_999).toString() == "999999 μs");

        assert(FracSec.from!"hnsecs"(0).toString() == "0 hnsecs");
        assert(FracSec.from!"hnsecs"(1).toString() == "1 hnsec");
        assert(FracSec.from!"hnsecs"(2).toString() == "2 hnsecs");
        assert(FracSec.from!"hnsecs"(100).toString() == "10 μs");
        assert(FracSec.from!"hnsecs"(999).toString() == "999 hnsecs");
        assert(FracSec.from!"hnsecs"(1000).toString() == "100 μs");
        assert(FracSec.from!"hnsecs"(2000).toString() == "200 μs");
        assert(FracSec.from!"hnsecs"(9999).toString() == "9999 hnsecs");
        assert(FracSec.from!"hnsecs"(10_000).toString() == "1 ms");
        assert(FracSec.from!"hnsecs"(20_000).toString() == "2 ms");
        assert(FracSec.from!"hnsecs"(100_000).toString() == "10 ms");
        assert(FracSec.from!"hnsecs"(100_001).toString() == "100001 hnsecs");
        assert(FracSec.from!"hnsecs"(200_000).toString() == "20 ms");
        assert(FracSec.from!"hnsecs"(999_999).toString() == "999999 hnsecs");
        assert(FracSec.from!"hnsecs"(1_000_001).toString() == "1000001 hnsecs");
        assert(FracSec.from!"hnsecs"(9_999_999).toString() == "9999999 hnsecs");
    }


    /++
        Returns whether the given number of hnsecs fits within the range of FracSec.

        Params:
            hnsecs = The number of hnsecs.
      +/
    static bool _valid(int hnsecs) @safe pure
    {
        enum second = convert!("seconds", "hnsecs")(1);

        return hnsecs > -second && hnsecs < second;
    }


    /++
        Throws:
            TimeException if valid(hnsecs) is false.
      +/
    static void _enforceValid(int hnsecs) @safe pure
    {
        if(!_valid(hnsecs))
            throw new TimeException("FracSec must be greater than equal to 0 and less than 1 second.");
    }


    /++
        Params:
            hnsecs = The number of hnsecs passed the second.

        Throws:
            TimeException if the given hnsecs less than 0 or would result in a
            FracSec greater than or equal to 1 second.
      +/
    @safe pure this(int hnsecs)
    {
        _enforceValid(hnsecs);
        _hnsecs = hnsecs;
    }


    @safe pure invariant()
    {
        if(!_valid(_hnsecs))
            throw new AssertError("Invaliant Failure: hnsecs [" ~ numToString(_hnsecs) ~ "]", __FILE__, __LINE__);
    }


    int _hnsecs;
}


/++
    Exception type used by core.time.
  +/
class TimeException : Exception
{
    /++
        Params:
            msg  = The message for the exception.
            file = The file where the exception occurred.
            line = The line number where the exception occurred.
            next = The previous exception in the chain of exceptions, if any.
      +/
    nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}


//==============================================================================
// Private Section.
//
// Much of this is a copy or simplified copy of what's in std.datetime.
//==============================================================================
private:


/+
    Template to help with converting between time units.
 +/
template hnsecsPer(string units)
    if(units == "weeks" ||
       units == "days" ||
       units == "hours" ||
       units == "minutes" ||
       units == "seconds" ||
       units == "msecs" ||
       units == "usecs" ||
       units == "hnsecs")
{
    static if(units == "hnsecs")
        enum hnsecsPer = 1L;
    else static if(units == "usecs")
        enum hnsecsPer = 10L;
    else static if(units == "msecs")
        enum hnsecsPer = 1000 * hnsecsPer!"usecs";
    else static if(units == "seconds")
        enum hnsecsPer = 1000 * hnsecsPer!"msecs";
    else static if(units == "minutes")
        enum hnsecsPer = 60 * hnsecsPer!"seconds";
    else static if(units == "hours")
        enum hnsecsPer = 60 * hnsecsPer!"minutes";
    else static if(units == "days")
        enum hnsecsPer = 24 * hnsecsPer!"hours";
    else static if(units == "weeks")
        enum hnsecsPer = 7 * hnsecsPer!"days";
}

/+
    Splits out a particular unit from hnsecs and gives you the value for that
    unit and the remaining hnsecs. It really shouldn't be used unless unless
    all units larger than the given units have already been split out.

    Params:
        units  = The units to split out.
        hnsecs = The current total hnsecs. Upon returning, it is the hnsecs left
                 after splitting out the given units.

    Returns:
        The number of the given units from converting hnsecs to those units.

    Examples:
--------------------
auto hnsecs = 2595000000007L;
immutable days = splitUnitsFromHNSecs!"days"(hnsecs);
assert(days == 3);
assert(hnsecs == 3000000007);

immutable minutes = splitUnitsFromHNSecs!"minutes"(hnsecs);
assert(minutes == 5);
assert(hnsecs == 7);
--------------------
  +/
long splitUnitsFromHNSecs(string units)(ref long hnsecs) @safe pure nothrow
    if(units == "weeks" ||
       units == "days" ||
       units == "hours" ||
       units == "minutes" ||
       units == "seconds" ||
       units == "msecs" ||
       units == "usecs" ||
       units == "hnsecs")
{
    immutable value = convert!("hnsecs", units)(hnsecs);
    hnsecs -= convert!(units, "hnsecs")(value);

    return value;
}

unittest
{
    //Verify Example.
    auto hnsecs = 2595000000007L;
    immutable days = splitUnitsFromHNSecs!"days"(hnsecs);
    assert(days == 3);
    assert(hnsecs == 3000000007);

    immutable minutes = splitUnitsFromHNSecs!"minutes"(hnsecs);
    assert(minutes == 5);
    assert(hnsecs == 7);
}


/+
    This function is used to split out the units without getting the remaining
    hnsecs.

    See_Also:
        splitUnitsFromHNSecs()

    Params:
        units  = The units to split out.
        hnsecs = The current total hnsecs.

    Returns:
        The split out value.

    Examples:
--------------------
auto hnsecs = 2595000000007L;
immutable days = getUnitsFromHNSecs!"days"(hnsecs);
assert(days == 3);
assert(hnsecs == 2595000000007L);
--------------------
  +/
long getUnitsFromHNSecs(string units)(long hnsecs) @safe pure nothrow
    if(units == "weeks" ||
       units == "days" ||
       units == "hours" ||
       units == "minutes" ||
       units == "seconds" ||
       units == "msecs" ||
       units == "usecs" ||
       units == "hnsecs")
{
    return convert!("hnsecs", units)(hnsecs);
}

unittest
{
    //Verify Example.
    auto hnsecs = 2595000000007L;
    immutable days = getUnitsFromHNSecs!"days"(hnsecs);
    assert(days == 3);
    assert(hnsecs == 2595000000007L);
}


/+
    This function is used to split out the units without getting the units but
    just the remaining hnsecs.

    See_Also:
        splitUnitsFromHNSecs()

    Params:
        units  = The units to split out.
        hnsecs = The current total hnsecs.

    Returns:
        The remaining hnsecs.

    Examples:
--------------------
auto hnsecs = 2595000000007L;
auto returned = removeUnitsFromHNSecs!"days"(hnsecs);
assert(returned == 3000000007);
assert(hnsecs == 2595000000007L);
--------------------
  +/
long removeUnitsFromHNSecs(string units)(long hnsecs) @safe pure nothrow
    if(units == "weeks" ||
       units == "days" ||
       units == "hours" ||
       units == "minutes" ||
       units == "seconds" ||
       units == "msecs" ||
       units == "usecs" ||
       units == "hnsecs")
{
    immutable value = convert!("hnsecs", units)(hnsecs);

    return hnsecs - convert!(units, "hnsecs")(value);
}

unittest
{
    //Verify Example.
    auto hnsecs = 2595000000007L;
    auto returned = removeUnitsFromHNSecs!"days"(hnsecs);
    assert(returned == 3000000007);
    assert(hnsecs == 2595000000007L);
}


/++
    Whether all of the given strings are valid units of time.
  +/
bool validTimeUnits(string[] units...)
{
    foreach(str; units)
    {
        switch(str)
        {
            case "years", "months", "weeks", "days", "hours", "minutes", "seconds", "msecs", "usecs", "hnsecs":
                return true;
            default:
                return false;
        }
    }

    return false;
}


/+
    The time units which are one step larger than the given units.

    Examples:
--------------------
assert(nextLargerTimeUnits!"minutes" == "hours");
assert(nextLargerTimeUnits!"hnsecs" == "usecs");
--------------------
  +/
template nextLargerTimeUnits(string units)
    if(units == "days" ||
       units == "hours" ||
       units == "minutes" ||
       units == "seconds" ||
       units == "msecs" ||
       units == "usecs" ||
       units == "hnsecs" ||
       units == "nsecs")
{
    static if(units == "days")
        enum nextLargerTimeUnits = "weeks";
    else static if(units == "hours")
        enum nextLargerTimeUnits = "days";
    else static if(units == "minutes")
        enum nextLargerTimeUnits = "hours";
    else static if(units == "seconds")
        enum nextLargerTimeUnits = "minutes";
    else static if(units == "msecs")
        enum nextLargerTimeUnits = "seconds";
    else static if(units == "usecs")
        enum nextLargerTimeUnits = "msecs";
    else static if(units == "hnsecs")
        enum nextLargerTimeUnits = "usecs";
    else static if(units == "nsecs")
        enum nextLargerTimeUnits = "hnsecs";
    else
        static assert(0, "Broken template constraint");
}

unittest
{
    assert(nextLargerTimeUnits!"nsecs" == "hnsecs");
    assert(nextLargerTimeUnits!"hnsecs" == "usecs");
    assert(nextLargerTimeUnits!"usecs" == "msecs");
    assert(nextLargerTimeUnits!"msecs" == "seconds");
    assert(nextLargerTimeUnits!"seconds" == "minutes");
    assert(nextLargerTimeUnits!"minutes" == "hours");
    assert(nextLargerTimeUnits!"hours" == "days");
    assert(nextLargerTimeUnits!"days" == "weeks");

    static assert(!__traits(compiles, nextLargerTimeUnits!"weeks"));
    static assert(!__traits(compiles, nextLargerTimeUnits!"months"));
    static assert(!__traits(compiles, nextLargerTimeUnits!"years"));

    //Verify Examples
    assert(nextLargerTimeUnits!"minutes" == "hours");
    assert(nextLargerTimeUnits!"hnsecs" == "usecs");
}


/++
    Unfortunately, snprintf is not pure, so here's a way to convert
    a number to a string which is.
  +/
string numToString(long value) @safe pure nothrow
{
    try
    {
        immutable negative = value < 0;
        char[25] str;
        size_t i = str.length;

        if(negative)
            value = -value;

        while(1)
        {
            char digit = cast(char)('0' + value % 10);
            value /= 10;

            str[--i] = digit;
            assert(i > 0);

            if(value == 0)
                break;
        }

        if(negative)
            return "-" ~ str[i .. $].idup;
        else
            return str[i .. $].idup;
    }
    catch(Exception e)
        assert(0, "Something threw when nothing can throw.");
}


/+ A copy of std.traits.Unqual. +/
private template _Unqual(T)
{
    version (none) // Error: recursive alias declaration @@@BUG1308@@@
    {
             static if (is(T U ==     const U)) alias _Unqual!U _Unqual;
        else static if (is(T U == immutable U)) alias _Unqual!U _Unqual;
        else static if (is(T U ==    shared U)) alias _Unqual!U _Unqual;
        else                                    alias        T _Unqual;
    }
    else // workaround
    {
             static if (is(T U == shared(const U))) alias U _Unqual;
        else static if (is(T U ==        const U )) alias U _Unqual;
        else static if (is(T U ==    immutable U )) alias U _Unqual;
        else static if (is(T U ==       shared U )) alias U _Unqual;
        else                                        alias T _Unqual;
    }
}

unittest
{
    static assert(is(_Unqual!(int) == int));
    static assert(is(_Unqual!(const int) == int));
    static assert(is(_Unqual!(immutable int) == int));
    static assert(is(_Unqual!(shared int) == int));
    static assert(is(_Unqual!(shared(const int)) == int));
    alias immutable(int[]) ImmIntArr;
    static assert(is(_Unqual!(ImmIntArr) == immutable(int)[]));
}


/+ A copy of std.typecons.TypeTuple. +/
private template _TypeTuple(TList...)
{
    alias TList _TypeTuple;
}


/+ An adjusted copy of std.exception.assertThrown. +/
version(unittest) void _assertThrown(T : Throwable = Exception, E)
                                    (lazy E expression,
                                     string msg = null,
                                     string file = __FILE__,
                                     size_t line = __LINE__)
{
    bool thrown = false;

    try
        expression();
    catch(T t)
        thrown = true;

    if(!thrown)
    {
        immutable tail = msg.length == 0 ? "." : ": " ~ msg;

        throw new AssertError("assertThrown() failed: No " ~ E.stringof ~ " was thrown" ~ tail, file, line);
    }
}

unittest
{
    void throwEx(Throwable t)
    {
        throw t;
    }

    void nothrowEx()
    {}

    try
        _assertThrown!Exception(throwEx(new Exception("It's an Exception")));
    catch(AssertError)
        assert(0);

    try
        _assertThrown!Exception(throwEx(new Exception("It's an Exception")), "It's a message");
    catch(AssertError)
        assert(0);

    try
        _assertThrown!AssertError(throwEx(new AssertError("It's an AssertError", __FILE__, __LINE__)));
    catch(AssertError)
        assert(0);

    try
        _assertThrown!AssertError(throwEx(new AssertError("It's an AssertError", __FILE__, __LINE__)), "It's a message");
    catch(AssertError)
        assert(0);


    {
        bool thrown = false;
        try
            _assertThrown!Exception(nothrowEx());
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }

    {
        bool thrown = false;
        try
            _assertThrown!Exception(nothrowEx(), "It's a message");
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }

    {
        bool thrown = false;
        try
            _assertThrown!AssertError(nothrowEx());
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }

    {
        bool thrown = false;
        try
            _assertThrown!AssertError(nothrowEx(), "It's a message");
        catch(AssertError)
            thrown = true;

        assert(thrown);
    }
}
