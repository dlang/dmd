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

    Copyright: Copyright 2010 - 2012
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

    Use the $(D dur) function to create $(D Duration)s.

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
        Compares this $(D Duration) with the given $(D Duration).

        Returns:
            $(TABLE
            $(TR $(TD this &lt; rhs) $(TD &lt; 0))
            $(TR $(TD this == rhs) $(TD 0))
            $(TR $(TD this &gt; rhs) $(TD &gt; 0))
            )
     +/
    int opCmp(Duration rhs) @safe const pure nothrow
    {
        if(_hnsecs < rhs._hnsecs)
            return -1;
        if(_hnsecs > rhs._hnsecs)
            return 1;

        return 0;
    }

    unittest
    {
        //To verify that an lvalue isn't required.
        T copy(T)(T duration)
        {
            return duration;
        }

        foreach(T; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            foreach(U; _TypeTuple!(Duration, const Duration, immutable Duration))
            {
                T t = 42;
                U u = t;
                assert(t == u);
                assert(copy(t) == u);
                assert(t == copy(u));
            }
        }

        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            foreach(E; _TypeTuple!(Duration, const Duration, immutable Duration))
            {
                assert((cast(D)Duration(12)).opCmp(cast(E)Duration(12)) == 0);
                assert((cast(D)Duration(-12)).opCmp(cast(E)Duration(-12)) == 0);

                assert((cast(D)Duration(10)).opCmp(cast(E)Duration(12)) < 0);
                assert((cast(D)Duration(-12)).opCmp(cast(E)Duration(12)) < 0);

                assert((cast(D)Duration(12)).opCmp(cast(E)Duration(10)) > 0);
                assert((cast(D)Duration(12)).opCmp(cast(E)Duration(-12)) > 0);

                assert(copy(cast(D)Duration(12)).opCmp(cast(E)Duration(12)) == 0);
                assert(copy(cast(D)Duration(-12)).opCmp(cast(E)Duration(-12)) == 0);

                assert(copy(cast(D)Duration(10)).opCmp(cast(E)Duration(12)) < 0);
                assert(copy(cast(D)Duration(-12)).opCmp(cast(E)Duration(12)) < 0);

                assert(copy(cast(D)Duration(12)).opCmp(cast(E)Duration(10)) > 0);
                assert(copy(cast(D)Duration(12)).opCmp(cast(E)Duration(-12)) > 0);

                assert((cast(D)Duration(12)).opCmp(copy(cast(E)Duration(12))) == 0);
                assert((cast(D)Duration(-12)).opCmp(copy(cast(E)Duration(-12))) == 0);

                assert((cast(D)Duration(10)).opCmp(copy(cast(E)Duration(12))) < 0);
                assert((cast(D)Duration(-12)).opCmp(copy(cast(E)Duration(12))) < 0);

                assert((cast(D)Duration(12)).opCmp(copy(cast(E)Duration(10))) > 0);
                assert((cast(D)Duration(12)).opCmp(copy(cast(E)Duration(-12))) > 0);
            }
        }
    }


    /++
        Adds or subtracts two durations.

        The legal types of arithmetic for $(D Duration) using this operator are

        $(TABLE
        $(TR $(TD Duration) $(TD +) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD +) $(TD TickDuration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD TickDuration) $(TD -->) $(TD Duration))
        )

        Params:
            rhs = The duration to add to or subtract from this $(D Duration).
      +/
    Duration opBinary(string op, D)(D rhs) @safe const pure nothrow
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
        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            foreach(E; _TypeTuple!(Duration, const Duration, immutable Duration))
            {
                assert((cast(D)Duration(5)) + (cast(E)Duration(7)) == Duration(12));
                assert((cast(D)Duration(5)) - (cast(E)Duration(7)) == Duration(-2));
                assert((cast(D)Duration(7)) + (cast(E)Duration(5)) == Duration(12));
                assert((cast(D)Duration(7)) - (cast(E)Duration(5)) == Duration(2));

                assert((cast(D)Duration(5)) + (cast(E)Duration(-7)) == Duration(-2));
                assert((cast(D)Duration(5)) - (cast(E)Duration(-7)) == Duration(12));
                assert((cast(D)Duration(7)) + (cast(E)Duration(-5)) == Duration(2));
                assert((cast(D)Duration(7)) - (cast(E)Duration(-5)) == Duration(12));

                assert((cast(D)Duration(-5)) + (cast(E)Duration(7)) == Duration(2));
                assert((cast(D)Duration(-5)) - (cast(E)Duration(7)) == Duration(-12));
                assert((cast(D)Duration(-7)) + (cast(E)Duration(5)) == Duration(-2));
                assert((cast(D)Duration(-7)) - (cast(E)Duration(5)) == Duration(-12));

                assert((cast(D)Duration(-5)) + (cast(E)Duration(-7)) == Duration(-12));
                assert((cast(D)Duration(-5)) - (cast(E)Duration(-7)) == Duration(2));
                assert((cast(D)Duration(-7)) + (cast(E)Duration(-5)) == Duration(-12));
                assert((cast(D)Duration(-7)) - (cast(E)Duration(-5)) == Duration(-2));
            }

            foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
            {
                assertApprox((cast(D)Duration(5)) + cast(T)TickDuration.from!"usecs"(7), Duration(70), Duration(80));
                assertApprox((cast(D)Duration(5)) - cast(T)TickDuration.from!"usecs"(7), Duration(-70), Duration(-60));
                assertApprox((cast(D)Duration(7)) + cast(T)TickDuration.from!"usecs"(5), Duration(52), Duration(62));
                assertApprox((cast(D)Duration(7)) - cast(T)TickDuration.from!"usecs"(5), Duration(-48), Duration(-38));

                assertApprox((cast(D)Duration(5)) + cast(T)TickDuration.from!"usecs"(-7), Duration(-70), Duration(-60));
                assertApprox((cast(D)Duration(5)) - cast(T)TickDuration.from!"usecs"(-7), Duration(70), Duration(80));
                assertApprox((cast(D)Duration(7)) + cast(T)TickDuration.from!"usecs"(-5), Duration(-48), Duration(-38));
                assertApprox((cast(D)Duration(7)) - cast(T)TickDuration.from!"usecs"(-5), Duration(52), Duration(62));

                assertApprox((cast(D)Duration(-5)) + cast(T)TickDuration.from!"usecs"(7), Duration(60), Duration(70));
                assertApprox((cast(D)Duration(-5)) - cast(T)TickDuration.from!"usecs"(7), Duration(-80), Duration(-70));
                assertApprox((cast(D)Duration(-7)) + cast(T)TickDuration.from!"usecs"(5), Duration(38), Duration(48));
                assertApprox((cast(D)Duration(-7)) - cast(T)TickDuration.from!"usecs"(5), Duration(-62), Duration(-52));

                assertApprox((cast(D)Duration(-5)) + cast(T)TickDuration.from!"usecs"(-7), Duration(-80), Duration(-70));
                assertApprox((cast(D)Duration(-5)) - cast(T)TickDuration.from!"usecs"(-7), Duration(60), Duration(70));
                assertApprox((cast(D)Duration(-7)) + cast(T)TickDuration.from!"usecs"(-5), Duration(-62), Duration(-52));
                assertApprox((cast(D)Duration(-7)) - cast(T)TickDuration.from!"usecs"(-5), Duration(38), Duration(48));
            }
        }
    }


    /++
        Adds or subtracts two durations.

        The legal types of arithmetic for $(D Duration) using this operator are

        $(TABLE
        $(TR $(TD TickDuration) $(TD +) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD TickDuration) $(TD -) $(TD Duration) $(TD -->) $(TD Duration))
        )

        Params:
            lhs = The $(D TickDuration) to add to this $(D Duration) or to
                  subtract this $(D Duration) from.
      +/
    Duration opBinaryRight(string op, D)(D lhs) @safe const pure nothrow
        if((op == "+" || op == "-") &&
            is(_Unqual!D == TickDuration))
    {
        return Duration(mixin("lhs.hnsecs " ~ op ~ " _hnsecs"));
    }

    unittest
    {
        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
            {
                assertApprox((cast(T)TickDuration.from!"usecs"(7)) + cast(D)Duration(5), Duration(70), Duration(80));
                assertApprox((cast(T)TickDuration.from!"usecs"(7)) - cast(D)Duration(5), Duration(60), Duration(70));
                assertApprox((cast(T)TickDuration.from!"usecs"(5)) + cast(D)Duration(7), Duration(52), Duration(62));
                assertApprox((cast(T)TickDuration.from!"usecs"(5)) - cast(D)Duration(7), Duration(38), Duration(48));

                assertApprox((cast(T)TickDuration.from!"usecs"(-7)) + cast(D)Duration(5), Duration(-70), Duration(-60));
                assertApprox((cast(T)TickDuration.from!"usecs"(-7)) - cast(D)Duration(5), Duration(-80), Duration(-70));
                assertApprox((cast(T)TickDuration.from!"usecs"(-5)) + cast(D)Duration(7), Duration(-48), Duration(-38));
                assertApprox((cast(T)TickDuration.from!"usecs"(-5)) - cast(D)Duration(7), Duration(-62), Duration(-52));

                assertApprox((cast(T)TickDuration.from!"usecs"(7)) + (cast(D)Duration(-5)), Duration(60), Duration(70));
                assertApprox((cast(T)TickDuration.from!"usecs"(7)) - (cast(D)Duration(-5)), Duration(70), Duration(80));
                assertApprox((cast(T)TickDuration.from!"usecs"(5)) + (cast(D)Duration(-7)), Duration(38), Duration(48));
                assertApprox((cast(T)TickDuration.from!"usecs"(5)) - (cast(D)Duration(-7)), Duration(52), Duration(62));

                assertApprox((cast(T)TickDuration.from!"usecs"(-7)) + cast(D)Duration(-5), Duration(-80), Duration(-70));
                assertApprox((cast(T)TickDuration.from!"usecs"(-7)) - cast(D)Duration(-5), Duration(-70), Duration(-60));
                assertApprox((cast(T)TickDuration.from!"usecs"(-5)) + cast(D)Duration(-7), Duration(-62), Duration(-52));
                assertApprox((cast(T)TickDuration.from!"usecs"(-5)) - cast(D)Duration(-7), Duration(-48), Duration(-38));
            }
        }
    }


    /++
        Adds or subtracts two durations as well as assigning the result to this
        $(D Duration).

        The legal types of arithmetic for $(D Duration) using this operator are

        $(TABLE
        $(TR $(TD Duration) $(TD +) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD Duration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD +) $(TD TickDuration) $(TD -->) $(TD Duration))
        $(TR $(TD Duration) $(TD -) $(TD TickDuration) $(TD -->) $(TD Duration))
        )

        Params:
            rhs = The duration to add to or subtract from this $(D Duration).
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
        static void test1(string op, E)(Duration actual, in E rhs, Duration expected, size_t line = __LINE__)
        {
            if(mixin("actual " ~ op ~ " rhs") != expected)
                throw new AssertError("op failed", __FILE__, line);

            if(actual != expected)
                throw new AssertError("op assign failed", __FILE__, line);
        }

        static void test2(string op, E)
                         (Duration actual, in E rhs, Duration lower, Duration upper, size_t line = __LINE__)
        {
            assertApprox(mixin("actual " ~ op ~ " rhs"), lower, upper, "op failed", line);
            assertApprox(actual, lower, upper, "op assign failed", line);
        }

        foreach(E; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            test1!"+="(Duration(5), (cast(E)Duration(7)), Duration(12));
            test1!"-="(Duration(5), (cast(E)Duration(7)), Duration(-2));
            test1!"+="(Duration(7), (cast(E)Duration(5)), Duration(12));
            test1!"-="(Duration(7), (cast(E)Duration(5)), Duration(2));

            test1!"+="(Duration(5), (cast(E)Duration(-7)), Duration(-2));
            test1!"-="(Duration(5), (cast(E)Duration(-7)), Duration(12));
            test1!"+="(Duration(7), (cast(E)Duration(-5)), Duration(2));
            test1!"-="(Duration(7), (cast(E)Duration(-5)), Duration(12));

            test1!"+="(Duration(-5), (cast(E)Duration(7)), Duration(2));
            test1!"-="(Duration(-5), (cast(E)Duration(7)), Duration(-12));
            test1!"+="(Duration(-7), (cast(E)Duration(5)), Duration(-2));
            test1!"-="(Duration(-7), (cast(E)Duration(5)), Duration(-12));

            test1!"+="(Duration(-5), (cast(E)Duration(-7)), Duration(-12));
            test1!"-="(Duration(-5), (cast(E)Duration(-7)), Duration(2));
            test1!"+="(Duration(-7), (cast(E)Duration(-5)), Duration(-12));
            test1!"-="(Duration(-7), (cast(E)Duration(-5)), Duration(-2));
        }

        foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
        {
            test2!"+="(Duration(5), cast(T)TickDuration.from!"usecs"(7), Duration(70), Duration(80));
            test2!"-="(Duration(5), cast(T)TickDuration.from!"usecs"(7), Duration(-70), Duration(-60));
            test2!"+="(Duration(7), cast(T)TickDuration.from!"usecs"(5), Duration(52), Duration(62));
            test2!"-="(Duration(7), cast(T)TickDuration.from!"usecs"(5), Duration(-48), Duration(-38));

            test2!"+="(Duration(5), cast(T)TickDuration.from!"usecs"(-7), Duration(-70), Duration(-60));
            test2!"-="(Duration(5), cast(T)TickDuration.from!"usecs"(-7), Duration(70), Duration(80));
            test2!"+="(Duration(7), cast(T)TickDuration.from!"usecs"(-5), Duration(-48), Duration(-38));
            test2!"-="(Duration(7), cast(T)TickDuration.from!"usecs"(-5), Duration(52), Duration(62));

            test2!"+="(Duration(-5), cast(T)TickDuration.from!"usecs"(7), Duration(60), Duration(70));
            test2!"-="(Duration(-5), cast(T)TickDuration.from!"usecs"(7), Duration(-80), Duration(-70));
            test2!"+="(Duration(-7), cast(T)TickDuration.from!"usecs"(5), Duration(38), Duration(48));
            test2!"-="(Duration(-7), cast(T)TickDuration.from!"usecs"(5), Duration(-62), Duration(-52));

            test2!"+="(Duration(-5), cast(T)TickDuration.from!"usecs"(-7), Duration(-80), Duration(-70));
            test2!"-="(Duration(-5), cast(T)TickDuration.from!"usecs"(-7), Duration(60), Duration(70));
            test2!"+="(Duration(-7), cast(T)TickDuration.from!"usecs"(-5), Duration(-62), Duration(-52));
            test2!"-="(Duration(-7), cast(T)TickDuration.from!"usecs"(-5), Duration(38), Duration(48));
        }

        foreach(D; _TypeTuple!(const Duration, immutable Duration))
        {
            foreach(E; _TypeTuple!(Duration, const Duration, immutable Duration,
                                   TickDuration, const TickDuration, immutable TickDuration))
            {
                D lhs = D(120);
                E rhs = E(120);
                static assert(!__traits(compiles, lhs += rhs), D.stringof ~ " " ~ E.stringof);
            }
        }
    }


    /++
        The legal types of arithmetic for $(D Duration) using this operator
        overload are

        $(TABLE
        $(TR $(TD Duration) $(TD *) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to multiply this $(D Duration) by.
      +/
    Duration opBinary(string op)(long value) @safe const pure nothrow
        if(op == "*")
    {
        return Duration(_hnsecs * value);
    }

    unittest
    {
        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            assert((cast(D)Duration(5)) * 7 == Duration(35));
            assert((cast(D)Duration(7)) * 5 == Duration(35));

            assert((cast(D)Duration(5)) * -7 == Duration(-35));
            assert((cast(D)Duration(7)) * -5 == Duration(-35));

            assert((cast(D)Duration(-5)) * 7 == Duration(-35));
            assert((cast(D)Duration(-7)) * 5 == Duration(-35));

            assert((cast(D)Duration(-5)) * -7 == Duration(35));
            assert((cast(D)Duration(-7)) * -5 == Duration(35));

            assert((cast(D)Duration(5)) * 0 == Duration(0));
            assert((cast(D)Duration(-5)) * 0 == Duration(0));
        }
    }


    /++
        The legal types of arithmetic for $(D Duration) using this operator
        overload are

        $(TABLE
        $(TR $(TD Duration) $(TD *) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to multiply this $(D Duration) by.
      +/
    ref Duration opOpAssign(string op)(long value) @safe pure nothrow
        if(op == "*")
    {
        _hnsecs *= value;

       return this;
    }

    unittest
    {
        static void test(D)(D actual, long value, Duration expected, size_t line = __LINE__)
        {
            if((actual *= value) != expected)
                throw new AssertError("op failed", __FILE__, line);

            if(actual != expected)
                throw new AssertError("op assign failed", __FILE__, line);
        }

        test(Duration(5), 7, Duration(35));
        test(Duration(7), 5, Duration(35));

        test(Duration(5), -7, Duration(-35));
        test(Duration(7), -5, Duration(-35));

        test(Duration(-5), 7, Duration(-35));
        test(Duration(-7), 5, Duration(-35));

        test(Duration(-5), -7, Duration(35));
        test(Duration(-7), -5, Duration(35));

        test(Duration(5), 0, Duration(0));
        test(Duration(-5), 0, Duration(0));

        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(!__traits(compiles, cdur *= 12));
        static assert(!__traits(compiles, idur *= 12));
    }


    /++
        The legal types of arithmetic for $(D Duration) using this operator
        overload are

        $(TABLE
        $(TR $(TD Duration) $(TD /) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to divide from this duration.

        Throws:
            $(D TimeException) if an attempt to divide by $(D 0) is made.
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
        //Unfortunately, putting these inside of the foreach loop results in
        //linker errors regarding multiple definitions and the lambdas.
        _assertThrown!TimeException((){Duration(5) / 0;}());
        _assertThrown!TimeException((){Duration(-5) / 0;}());
        _assertThrown!TimeException((){(cast(const Duration)Duration(5)) / 0;}());
        _assertThrown!TimeException((){(cast(const Duration)Duration(-5)) / 0;}());
        _assertThrown!TimeException((){(cast(immutable Duration)Duration(5)) / 0;}());
        _assertThrown!TimeException((){(cast(immutable Duration)Duration(-5)) / 0;}());

        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            assert((cast(D)Duration(5)) / 7 == Duration(0));
            assert((cast(D)Duration(7)) / 5 == Duration(1));

            assert((cast(D)Duration(5)) / -7 == Duration(0));
            assert((cast(D)Duration(7)) / -5 == Duration(-1));

            assert((cast(D)Duration(-5)) / 7 == Duration(0));
            assert((cast(D)Duration(-7)) / 5 == Duration(-1));

            assert((cast(D)Duration(-5)) / -7 == Duration(0));
            assert((cast(D)Duration(-7)) / -5 == Duration(1));
        }
    }


    /++
        The legal types of arithmetic for $(D Duration) using this operator
        overload are

        $(TABLE
        $(TR $(TD Duration) $(TD /) $(TD long) $(TD -->) $(TD Duration))
        )

        Params:
            value = The value to divide from this $(D Duration).

        Throws:
            $(D TimeException) if an attempt to divide by $(D 0) is made.
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

        static void test(Duration actual, long value, Duration expected, size_t line = __LINE__)
        {
            if((actual /= value) != expected)
                throw new AssertError("op failed", __FILE__, line);

            if(actual != expected)
                throw new AssertError("op assign failed", __FILE__, line);
        }

        test(Duration(5), 7, Duration(0));
        test(Duration(7), 5, Duration(1));

        test(Duration(5), -7, Duration(0));
        test(Duration(7), -5, Duration(-1));

        test(Duration(-5), 7, Duration(0));
        test(Duration(-7), 5, Duration(-1));

        test(Duration(-5), -7, Duration(0));
        test(Duration(-7), -5, Duration(1));

        const cdur = Duration(12);
        immutable idur = Duration(12);
        static assert(!__traits(compiles, cdur /= 12));
        static assert(!__traits(compiles, idur /= 12));
    }


    /++
        Multiplies an integral value and a $(D Duration).

        The legal types of arithmetic for $(D Duration) using this operator
        overload are

        $(TABLE
        $(TR $(TD long) $(TD *) $(TD Duration) $(TD -->) $(TD Duration))
        )

        Params:
            value = The number of units to multiply this $(D Duration) by.
      +/
    Duration opBinaryRight(string op)(long value) @safe const pure nothrow
        if(op == "*")
    {
        return opBinary!op(value);
    }

    unittest
    {
        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            assert(5 * cast(D)Duration(7) == Duration(35));
            assert(7 * cast(D)Duration(5) == Duration(35));

            assert(5 * cast(D)Duration(-7) == Duration(-35));
            assert(7 * cast(D)Duration(-5) == Duration(-35));

            assert(-5 * cast(D)Duration(7) == Duration(-35));
            assert(-7 * cast(D)Duration(5) == Duration(-35));

            assert(-5 * cast(D)Duration(-7) == Duration(35));
            assert(-7 * cast(D)Duration(-5) == Duration(35));

            assert(0 * cast(D)Duration(-5) == Duration(0));
            assert(0 * cast(D)Duration(5) == Duration(0));
        }
    }


    /++
        Returns the negation of this $(D Duration).
      +/
    Duration opUnary(string op)() @safe const pure nothrow
        if(op == "-")
    {
        return Duration(-_hnsecs);
    }

    unittest
    {
        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            assert(-(cast(D)Duration(7)) == Duration(-7));
            assert(-(cast(D)Duration(5)) == Duration(-5));
            assert(-(cast(D)Duration(-7)) == Duration(7));
            assert(-(cast(D)Duration(-5)) == Duration(5));
            assert(-(cast(D)Duration(0)) == Duration(0));
        }
    }


    /++
        Returns a $(LREF TickDuration) with the same number of hnsecs as this
        $(D Duration).
      +/
    TickDuration opCast(T)() @safe const pure nothrow
        if(is(_Unqual!T == TickDuration))
    {
        return TickDuration.from!"hnsecs"(_hnsecs);
    }

    unittest
    {
        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            foreach(units; _TypeTuple!("seconds", "msecs", "usecs", "hnsecs"))
            {
                enum unitsPerSec = convert!("seconds", units)(1);

                if(TickDuration.ticksPerSec >= unitsPerSec)
                {
                    foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
                    {
                        auto t = TickDuration.from!units(1);
                        assert(cast(T)cast(D)dur!units(1) == t, units);
                        t = TickDuration.from!units(2);
                        assert(cast(T)cast(D)dur!units(2) == t, units);
                    }
                }
                else
                {
                    auto t = TickDuration.from!units(1);
                    assert(t.to!(units, long)() == 0, units);
                    t = TickDuration.from!units(1_000_000);
                    assert(t.to!(units, long)() >= 900_000, units);
                    assert(t.to!(units, long)() <= 1_100_000, units);
                }
            }
        }
    }


    //Temporary hack until bug http://d.puremagic.com/issues/show_bug.cgi?id=5747 is fixed.
    Duration opCast(T)() @safe const pure nothrow
        if(is(_Unqual!T == Duration))
    {
        return this;
    }


    /++
        Returns the number of the given units in this $(D Duration)
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

    //Verify Examples
    unittest
    {
        assert(dur!"weeks"(12).get!"weeks"() == 12);
        assert(dur!"weeks"(12).get!"days"() == 0);

        assert(dur!"days"(13).get!"weeks"() == 1);
        assert(dur!"days"(13).get!"days"() == 6);

        assert(dur!"hours"(49).get!"days"() == 2);
        assert(dur!"hours"(49).get!"hours"() == 1);
    }

    unittest
    {
        foreach(D; _TypeTuple!(const Duration, immutable Duration))
        {
            assert((cast(D)dur!"weeks"(12)).get!"weeks"() == 12);
            assert((cast(D)dur!"weeks"(12)).get!"days"() == 0);

            assert((cast(D)dur!"days"(13)).get!"weeks"() == 1);
            assert((cast(D)dur!"days"(13)).get!"days"() == 6);

            assert((cast(D)dur!"hours"(49)).get!"days"() == 2);
            assert((cast(D)dur!"hours"(49)).get!"hours"() == 1);
        }
    }


    /++
        Returns the number of weeks in this $(D Duration)
        (minus the larger units).

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

    //Verify Examples
    unittest
    {
        assert(dur!"weeks"(12).weeks == 12);
        assert(dur!"days"(13).weeks == 1);
    }

    unittest
    {
        foreach(D; _TypeTuple!(const Duration, immutable Duration))
        {
            assert((cast(D)dur!"weeks"(12)).weeks == 12);
            assert((cast(D)dur!"days"(13)).weeks == 1);
        }
    }


    /++
        Returns the number of days in this $(D Duration)
        (minus the larger units).

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

    //Verify Examples.
    unittest
    {
        assert(dur!"weeks"(12).days == 0);
        assert(dur!"days"(13).days == 6);
        assert(dur!"hours"(49).days == 2);
    }

    unittest
    {
        foreach(D; _TypeTuple!(const Duration, immutable Duration))
        {
            assert((cast(D)dur!"weeks"(12)).days == 0);
            assert((cast(D)dur!"days"(13)).days == 6);
            assert((cast(D)dur!"hours"(49)).days == 2);
        }
    }


    /++
        Returns the number of hours in this $(D Duration)
        (minus the larger units).

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

    //Verify Examples.
    unittest
    {
        assert(dur!"days"(8).hours == 0);
        assert(dur!"hours"(49).hours == 1);
        assert(dur!"minutes"(121).hours == 2);
    }

    unittest
    {
        foreach(D; _TypeTuple!(const Duration, immutable Duration))
        {
            assert((cast(D)dur!"days"(8)).hours == 0);
            assert((cast(D)dur!"hours"(49)).hours == 1);
            assert((cast(D)dur!"minutes"(121)).hours == 2);
        }
    }


    /++
        Returns the number of minutes in this $(D Duration)
        (minus the larger units).

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

    //Verify Examples.
    unittest
    {
        assert(dur!"hours"(47).minutes == 0);
        assert(dur!"minutes"(127).minutes == 7);
        assert(dur!"seconds"(121).minutes == 2);
    }

    unittest
    {
        foreach(D; _TypeTuple!(const Duration, immutable Duration))
        {
            assert((cast(D)dur!"hours"(47)).minutes == 0);
            assert((cast(D)dur!"minutes"(127)).minutes == 7);
            assert((cast(D)dur!"seconds"(121)).minutes == 2);
        }
    }


    /++
        Returns the number of seconds in this $(D Duration)
        (minus the larger units).

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

    //Verify Examples.
    unittest
    {
        assert(dur!"minutes"(47).seconds == 0);
        assert(dur!"seconds"(127).seconds == 7);
        assert(dur!"msecs"(1217).seconds == 1);
    }

    unittest
    {
        foreach(D; _TypeTuple!(const Duration, immutable Duration))
        {
            assert((cast(D)dur!"minutes"(47)).seconds == 0);
            assert((cast(D)dur!"seconds"(127)).seconds == 7);
            assert((cast(D)dur!"msecs"(1217)).seconds == 1);
        }
    }


    /++
        Returns the fractional seconds passed the second in this $(D Duration).

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
        foreach(D; _TypeTuple!(const Duration, immutable Duration))
        {
            assert((cast(D)dur!"msecs"(1000)).fracSec == FracSec.from!"msecs"(0));
            assert((cast(D)dur!"msecs"(1217)).fracSec == FracSec.from!"msecs"(217));
            assert((cast(D)dur!"usecs"(43)).fracSec == FracSec.from!"usecs"(43));
            assert((cast(D)dur!"hnsecs"(50_007)).fracSec == FracSec.from!"hnsecs"(50_007));
            assert((cast(D)dur!"nsecs"(62_127)).fracSec == FracSec.from!"nsecs"(62_100));

            assert((cast(D)dur!"msecs"(-1000)).fracSec == FracSec.from!"msecs"(-0));
            assert((cast(D)dur!"msecs"(-1217)).fracSec == FracSec.from!"msecs"(-217));
            assert((cast(D)dur!"usecs"(-43)).fracSec == FracSec.from!"usecs"(-43));
            assert((cast(D)dur!"hnsecs"(-50_007)).fracSec == FracSec.from!"hnsecs"(-50_007));
            assert((cast(D)dur!"nsecs"(-62_127)).fracSec == FracSec.from!"nsecs"(-62_100));
        }
    }


    /++
        Returns the total number of the given units in this $(D Duration).
        So, unlike $(D get), it does not strip out the larger units.

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

    //Verify Examples.
    unittest
    {
        assert(dur!"weeks"(12).total!"weeks" == 12);
        assert(dur!"weeks"(12).total!"days" == 84);

        assert(dur!"days"(13).total!"weeks" == 1);
        assert(dur!"days"(13).total!"days" == 13);

        assert(dur!"hours"(49).total!"days" == 2);
        assert(dur!"hours"(49).total!"hours" == 49);

        assert(dur!"nsecs"(2007).total!"hnsecs" == 20);
        assert(dur!"nsecs"(2007).total!"nsecs" == 2000);
    }

    unittest
    {
        foreach(D; _TypeTuple!(const Duration, immutable Duration))
        {
            assert((cast(D)dur!"weeks"(12)).total!"weeks" == 12);
            assert((cast(D)dur!"weeks"(12)).total!"days" == 84);

            assert((cast(D)dur!"days"(13)).total!"weeks" == 1);
            assert((cast(D)dur!"days"(13)).total!"days" == 13);

            assert((cast(D)dur!"hours"(49)).total!"days" == 2);
            assert((cast(D)dur!"hours"(49)).total!"hours" == 49);

            assert((cast(D)dur!"nsecs"(2007)).total!"hnsecs" == 20);
            assert((cast(D)dur!"nsecs"(2007)).total!"nsecs" == 2000);
        }
    }


    /+
        Converts this $(D Duration) to a $(D string).
      +/
    //Due to bug http://d.puremagic.com/issues/show_bug.cgi?id=3715 , we can't
    //have versions of toString() with extra modifiers, so we define one version
    //with modifiers and one without.
    string toString()
    {
        return _toStringImpl();
    }


    /++
        Converts this $(D Duration) to a $(D string).
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
        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            assert((cast(D)Duration(0)).toString() == "0 hnsecs");
            assert((cast(D)Duration(1)).toString() == "1 hnsec");
            assert((cast(D)Duration(7)).toString() == "7 hnsecs");
            assert((cast(D)Duration(10)).toString() == "1 μs");
            assert((cast(D)Duration(20)).toString() == "2 μs");
            assert((cast(D)Duration(10_000)).toString() == "1 ms");
            assert((cast(D)Duration(20_000)).toString() == "2 ms");
            assert((cast(D)Duration(10_000_000)).toString() == "1 sec");
            assert((cast(D)Duration(20_000_000)).toString() == "2 secs");
            assert((cast(D)Duration(600_000_000)).toString() == "1 minute");
            assert((cast(D)Duration(1_200_000_000)).toString() == "2 minutes");
            assert((cast(D)Duration(36_000_000_000)).toString() == "1 hour");
            assert((cast(D)Duration(72_000_000_000)).toString() == "2 hours");
            assert((cast(D)Duration(864_000_000_000)).toString() == "1 day");
            assert((cast(D)Duration(1_728_000_000_000)).toString() == "2 days");
            assert((cast(D)Duration(6_048_000_000_000)).toString() == "1 week");
            assert((cast(D)Duration(12_096_000_000_000)).toString() == "2 weeks");

            assert((cast(D)Duration(12)).toString() == "1 μs and 2 hnsecs");
            assert((cast(D)Duration(120_795)).toString() == "12 ms, 79 μs, and 5 hnsecs");
            assert((cast(D)Duration(12_096_020_900_003)).toString() == "2 weeks, 2 secs, 90 ms, and 3 hnsecs");

            assert((cast(D)Duration(-1)).toString() == "-1 hnsecs");
            assert((cast(D)Duration(-7)).toString() == "-7 hnsecs");
            assert((cast(D)Duration(-10)).toString() == "-1 μs");
            assert((cast(D)Duration(-20)).toString() == "-2 μs");
            assert((cast(D)Duration(-10_000)).toString() == "-1 ms");
            assert((cast(D)Duration(-20_000)).toString() == "-2 ms");
            assert((cast(D)Duration(-10_000_000)).toString() == "-1 secs");
            assert((cast(D)Duration(-20_000_000)).toString() == "-2 secs");
            assert((cast(D)Duration(-600_000_000)).toString() == "-1 minutes");
            assert((cast(D)Duration(-1_200_000_000)).toString() == "-2 minutes");
            assert((cast(D)Duration(-36_000_000_000)).toString() == "-1 hours");
            assert((cast(D)Duration(-72_000_000_000)).toString() == "-2 hours");
            assert((cast(D)Duration(-864_000_000_000)).toString() == "-1 days");
            assert((cast(D)Duration(-1_728_000_000_000)).toString() == "-2 days");
            assert((cast(D)Duration(-6_048_000_000_000)).toString() == "-1 weeks");
            assert((cast(D)Duration(-12_096_000_000_000)).toString() == "-2 weeks");

            assert((cast(D)Duration(-12)).toString() == "-1 μs and -2 hnsecs");
            assert((cast(D)Duration(-120_795)).toString() == "-12 ms, -79 μs, and -5 hnsecs");
            assert((cast(D)Duration(-12_096_020_900_003)).toString() == "-2 weeks, -2 secs, -90 ms, and -3 hnsecs");
        }
    }


    /++
        Returns whether this $(D Duration) is negative.
      +/
    @property bool isNegative() @safe const pure nothrow
    {
        return _hnsecs < 0;
    }

    unittest
    {
        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            assert(!(cast(D)Duration(100)).isNegative);
            assert(!(cast(D)Duration(1)).isNegative);
            assert(!(cast(D)Duration(0)).isNegative);
            assert((cast(D)Duration(-1)).isNegative);
            assert((cast(D)Duration(-100)).isNegative);
        }
    }


private:

    /++
        Since we have two versions of toString, we have _toStringImpl
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

            static string unitsToPrint(string units, bool plural)
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


    /++
        Params:
            hnsecs = The total number of hecto-nanoseconds in this $(D Duration).
      +/
    @safe pure nothrow this(long hnsecs)
    {
        _hnsecs = hnsecs;
    }


    long _hnsecs;
}


/++
    This allows you to construct a $(D Duration) from the given time units
    with the given length.

    The possible values for units are $(D "weeks"), $(D "days"), $(D "hours"),
    $(D "minutes"), $(D "seconds"), $(D "msecs") (milliseconds), $(D "usecs"),
    (microseconds), $(D "hnsecs") (hecto-nanoseconds, i.e. 100 ns), and
    $(D "nsecs").

    Params:
        units  = The time units of the $(D Duration) (e.g. $(D "days")).
        length = The number of units in the $(D Duration).
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
    foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
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
}


/++
   Represents a duration of time in system clock ticks.

   The system clock ticks are the ticks of the system clock at the highest
   precision that the system provides.
  +/
struct TickDuration
{
    /++
       The number of ticks that the system clock has in one second.

       If $(D ticksPerSec) is $(D 0), then then $(D TickDuration) failed to
       get the value of $(D ticksPerSec) on the current system, and
       $(D TickDuration) is not going to work. That would be highly abnormal
       though.
      +/
    static immutable long ticksPerSec;


    /++
        The tick of the system clock (as a $(D TickDuration)) when the
        application started.
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
                {
                    //For some reason, on some systems, clock_getres returns
                    //a resolution which is clearly wrong (it's a millisecond
                    //or worse, but the time is updated much more frequently
                    //than that). In such cases, we'll just use nanosecond
                    //resolution.
                    ticksPerSec = ts.tv_nsec >= 1000 ? 1_000_000_000
                                                     : 1_000_000_000 / ts.tv_nsec;
                }
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
       The number of system ticks in this $(D TickDuration).

       You can convert this $(D length) into the number of seconds by dividing
       it by $(D ticksPerSec) (or using one the appropriate property function
       to do it).
      +/
    long length;


    /++
        Converts this $(D TickDuration) to the given units as either an integral
        value or a floating point value.

        Params:
            units = The units to convert to. Accepts $(D "seconds") and smaller
                    only.
            T     = The type to convert to (either an integral type or a
                    floating point type).
      +/
    T to(string units, T)() @safe const pure nothrow
        if((units == "seconds" ||
            units == "msecs" ||
            units == "usecs" ||
            units == "hnsecs" ||
            units == "nsecs") &&
           ((__traits(isIntegral, T) && T.sizeof >= 4) || __traits(isFloating, T)))
    {
        static if(__traits(isIntegral, T) && T.sizeof >= 4)
        {
            enum unitsPerSec = convert!("seconds", units)(1);

            return cast(T)(length / (ticksPerSec / cast(real)unitsPerSec));
        }
        else static if(__traits(isFloating, T))
        {
            static if(units == "seconds")
                return length / cast(T)ticksPerSec;
            else
            {
                enum unitsPerSec = convert!("seconds", units)(1);

                return to!("seconds", T) * unitsPerSec;
            }
        }
        else
            static assert(0, "Incorrect template constraint.");
    }


    /++
        Returns the total number of seconds in this $(D TickDuration).
      +/
    @property long seconds() @safe const pure nothrow
    {
        return to!("seconds", long)();
    }

    unittest
    {
        foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
        {
            assert((cast(T)TickDuration(ticksPerSec)).seconds == 1);
            assert((cast(T)TickDuration(ticksPerSec - 1)).seconds == 0);
            assert((cast(T)TickDuration(ticksPerSec * 2)).seconds == 2);
            assert((cast(T)TickDuration(ticksPerSec * 2 - 1)).seconds == 1);
            assert((cast(T)TickDuration(-1)).seconds == 0);
            assert((cast(T)TickDuration(-ticksPerSec - 1)).seconds == -1);
            assert((cast(T)TickDuration(-ticksPerSec)).seconds == -1);
        }
    }


    /++
        Returns the total number of milliseconds in this $(D TickDuration).
      +/
    @property long msecs() @safe const pure nothrow
    {
        return to!("msecs", long)();
    }


    /++
        Returns the total number of microseconds in this $(D TickDuration).
      +/
    @property long usecs() @safe const pure nothrow
    {
        return to!("usecs", long)();
    }


    /++
        Returns the total number of hecto-nanoseconds in this $(D TickDuration).
      +/
    @property long hnsecs() @safe const pure nothrow
    {
        return to!("hnsecs", long)();
    }


    /++
        Returns the total number of nanoseconds in this $(D TickDuration).
      +/
    @property long nsecs() @safe const pure nothrow
    {
        return to!("nsecs", long)();
    }


    /++
        This allows you to construct a $(D TickDuration) from the given time
        units with the given length.

        Params:
            units  = The time units of the $(D TickDuration) (e.g. $(D "msecs")).
            length = The number of units in the $(D TickDuration).
      +/
    static TickDuration from(string units)(long length) @safe pure nothrow
        if(units == "seconds" ||
           units == "msecs" ||
           units == "usecs" ||
           units == "hnsecs" ||
           units == "nsecs")
    {
        enum unitsPerSec = convert!("seconds", units)(1);

        return TickDuration(cast(long)(length * (ticksPerSec / cast(real)unitsPerSec)));
    }

    unittest
    {
        foreach(units; _TypeTuple!("seconds", "msecs", "usecs", "nsecs"))
        {
            foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
            {
                assertApprox((cast(T)TickDuration).from!units(1000).to!(units, long)(),
                             500, 1500, units);
                assertApprox((cast(T)TickDuration).from!units(1_000_000).to!(units, long)(),
                             900_000, 1_100_000, units);
                assertApprox((cast(T)TickDuration).from!units(2_000_000).to!(units, long)(),
                             1_900_000, 2_100_000, units);
            }
        }
    }


    /++
        Returns a $(LREF Duration) with the same number of hnsecs as this
        $(D TickDuration).
      +/
    Duration opCast(T)() @safe const pure nothrow
        if(is(_Unqual!T == Duration))
    {
        return Duration(hnsecs);
    }

    unittest
    {
        foreach(D; _TypeTuple!(Duration, const Duration, immutable Duration))
        {
            foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
            {
                auto expected = dur!"seconds"(1);
                assert(cast(D)cast(T)TickDuration.from!"seconds"(1) == expected);

                foreach(units; _TypeTuple!("msecs", "usecs", "hnsecs"))
                {
                    D actual = cast(D)cast(T)TickDuration.from!units(1_000_000);
                    assertApprox(actual, dur!units(900_000), dur!units(1_100_000));
                }
            }
        }
    }


    //Temporary hack until bug http://d.puremagic.com/issues/show_bug.cgi?id=5747 is fixed.
    TickDuration opCast(T)() @safe const pure nothrow
        if(is(_Unqual!T == TickDuration))
    {
        return this;
    }


    /++
        Adds or subtracts two $(D TickDuration)s as well as assigning the result
        to this $(D TickDuration).

        The legal types of arithmetic for $(D TickDuration) using this operator
        are

        $(TABLE
        $(TR $(TD TickDuration) $(TD +=) $(TD TickDuration) $(TD -->) $(TD TickDuration))
        $(TR $(TD TickDuration) $(TD -=) $(TD TickDuration) $(TD -->) $(TD TickDuration))
        )

        Params:
            rhs = The $(D TickDuration) to add to or subtract from this
                  $(D $(D TickDuration)).
      +/
    ref TickDuration opOpAssign(string op)(TickDuration rhs) @safe pure nothrow
        if(op == "+" || op == "-")
    {
        mixin("length " ~ op ~ "= rhs.length;");
        return this;
    }

    unittest
    {
        foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
        {
            auto a = TickDuration.currSystemTick;
            auto result = a += cast(T)TickDuration.currSystemTick;
            assert(a == result);
            assert(a.to!("seconds", real)() >= 0);

            auto b = TickDuration.currSystemTick;
            result = b -= cast(T)TickDuration.currSystemTick;
            assert(b == result);
            assert(b.to!("seconds", real)() <= 0);

            foreach(U; _TypeTuple!(const TickDuration, immutable TickDuration))
            {
                U u = TickDuration(12);
                static assert(!__traits(compiles, u += cast(T)TickDuration.currSystemTick));
                static assert(!__traits(compiles, u -= cast(T)TickDuration.currSystemTick));
            }
        }
    }


    /++
        Adds or subtracts two $(D TickDuration)s.

        The legal types of arithmetic for $(D TickDuration) using this operator
        are

        $(TABLE
        $(TR $(TD TickDuration) $(TD +) $(TD TickDuration) $(TD -->) $(TD TickDuration))
        $(TR $(TD TickDuration) $(TD -) $(TD TickDuration) $(TD -->) $(TD TickDuration))
        )

        Params:
            rhs = The $(D TickDuration) to add to or subtract from this
                  $(D TickDuration).
      +/
    TickDuration opBinary(string op)(TickDuration rhs) @safe const pure nothrow
        if(op == "+" || op == "-")
    {
        return TickDuration(mixin("length " ~ op ~ " rhs.length"));
    }

    unittest
    {
        foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
        {
            T a = TickDuration.currSystemTick;
            T b = TickDuration.currSystemTick;
            assert((a + b).seconds > 0);
            assert((a - b).seconds <= 0);
        }
    }


    /++
        Returns the negation of this $(D TickDuration).
      +/
    TickDuration opUnary(string op)() @safe const pure nothrow
        if(op == "-")
    {
        return TickDuration(-length);
    }

    unittest
    {
        foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
        {
            assert(-(cast(T)TickDuration(7)) == TickDuration(-7));
            assert(-(cast(T)TickDuration(5)) == TickDuration(-5));
            assert(-(cast(T)TickDuration(-7)) == TickDuration(7));
            assert(-(cast(T)TickDuration(-5)) == TickDuration(5));
            assert(-(cast(T)TickDuration(0)) == TickDuration(0));
        }
    }


    /++
       operator overloading "<, >, <=, >="
      +/
    int opCmp(TickDuration rhs) @safe const pure nothrow
    {
        return length < rhs.length ? -1 : (length == rhs.length ? 0 : 1);
    }

    unittest
    {
        //To verify that an lvalue isn't required.
        T copy(T)(T duration)
        {
            return duration;
        }

        foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
        {
            foreach(U; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
            {
                T t = TickDuration.currSystemTick;
                U u = t;
                assert(t == u);
                assert(copy(t) == u);
                assert(t == copy(u));
            }
        }

        foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
        {
            foreach(U; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
            {
                T t = TickDuration.currSystemTick;
                U u = t + t;
                assert(t < u);
                assert(t <= t);
                assert(u > t);
                assert(u >= u);

                assert(copy(t) < u);
                assert(copy(t) <= t);
                assert(copy(u) > t);
                assert(copy(u) >= u);

                assert(t < copy(u));
                assert(t <= copy(t));
                assert(u > copy(t));
                assert(u >= copy(u));
            }
        }
    }


    /++
        The legal types of arithmetic for $(D TickDuration) using this operator
        overload are

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
        immutable curr = TickDuration.currSystemTick;
        TickDuration t1 = curr;
        immutable t2 = curr + curr;
        t1 *= 2;
        assert(t1 == t2);

        t1 = curr;
        t1 *= 2.0;
        immutable tol = TickDuration(cast(long)(_abs(t1.length) * double.epsilon * 2.0));
        assertApprox(t1, t2 - tol, t2 + tol);

        t1 = curr;
        t1 *= 2.1;
        assert(t1 > t2);

        foreach(T; _TypeTuple!(const TickDuration, immutable TickDuration))
        {
            T t = TickDuration.currSystemTick;
            assert(!__traits(compiles, t *= 12));
            assert(!__traits(compiles, t *= 12.0));
        }
    }


    /++
        The legal types of arithmetic for $(D TickDuration) using this operator
        overload are

        $(TABLE
        $(TR $(TD TickDuration) $(TD /) $(TD long) $(TD -->) $(TD TickDuration))
        $(TR $(TD TickDuration) $(TD /) $(TD floating point) $(TD -->) $(TD TickDuration))
        )

        Params:
            value = The value to divide from this $(D TickDuration).

        Throws:
            $(D TimeException) if an attempt to divide by $(D 0) is made.
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
        immutable curr = TickDuration.currSystemTick;
        immutable t1 = curr;
        TickDuration t2 = curr + curr;
        t2 /= 2;
        assert(t1 == t2);

        t2 = curr + curr;
        t2 /= 2.0;
        immutable tol = TickDuration(cast(long)(_abs(t2.length) * double.epsilon / 2.0));
        assertApprox(t1, t2 - tol, t2 + tol);

        t2 = curr + curr;
        t2 /= 2.1;
        assert(t1 > t2);

        _assertThrown!TimeException(t2 /= 0);

        foreach(T; _TypeTuple!(const TickDuration, immutable TickDuration))
        {
            T t = TickDuration.currSystemTick;
            assert(!__traits(compiles, t /= 12));
            assert(!__traits(compiles, t /= 12.0));
        }
    }


    /++
        The legal types of arithmetic for $(D TickDuration) using this operator
        overload are

        $(TABLE
        $(TR $(TD TickDuration) $(TD *) $(TD long) $(TD -->) $(TD TickDuration))
        $(TR $(TD TickDuration) $(TD *) $(TD floating point) $(TD -->) $(TD TickDuration))
        )

        Params:
            value = The value to divide from this $(D TickDuration).
      +/
    TickDuration opBinary(string op, T)(T value) @safe const pure nothrow
        if(op == "*" &&
           (__traits(isIntegral, T) || __traits(isFloating, T)))
    {
        return TickDuration(cast(long)(length * value));
    }

    unittest
    {
        foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
        {
            T t1 = TickDuration.currSystemTick;
            T t2 = t1 + t1;
            assert(t1 * 2 == t2);
            immutable tol = TickDuration(cast(long)(_abs(t1.length) * double.epsilon * 2.0));
            assertApprox(t1 * 2.0, t2 - tol, t2 + tol);
            assert(t1 * 2.1 > t2);
        }
    }


    /++
        The legal types of arithmetic for $(D TickDuration) using this operator
        overload are

        $(TABLE
        $(TR $(TD TickDuration) $(TD /) $(TD long) $(TD -->) $(TD TickDuration))
        $(TR $(TD TickDuration) $(TD /) $(TD floating point) $(TD -->) $(TD TickDuration))
        )

        Params:
            value = The value to divide from this $(D TickDuration).

        Throws:
            $(D TimeException) if an attempt to divide by $(D 0) is made.
      +/
    TickDuration opBinary(string op, T)(T value) @safe const pure
        if(op == "/" &&
           (__traits(isIntegral, T) || __traits(isFloating, T)))
    {
        if(value == 0)
            throw new TimeException("Attempted division by 0.");

        return TickDuration(cast(long)(length / value));
    }

    unittest
    {
        foreach(T; _TypeTuple!(TickDuration, const TickDuration, immutable TickDuration))
        {
            T t1 = TickDuration.currSystemTick;
            T t2 = t1 + t1;
            assert(t2 / 2 == t1);
            immutable tol = TickDuration(cast(long)(_abs(t2.length) * double.epsilon / 2.0));
            assertApprox(t2 / 2.0, t1 - tol, t1 + tol);
            assert(t2 / 2.1 < t1);

            _assertThrown!TimeException(t2 / 0);
        }
    }


    /++
        Params:
            ticks = The number of ticks in the TickDuration.
      +/
    @safe pure nothrow this(long ticks)
    {
        this.length = ticks;
    }

    unittest
    {
        foreach(i; [-42, 0, 42])
            assert(TickDuration(i).length == i);
    }


    /++
        The current system tick. The number of ticks per second varies from
        system to system. $(D currSystemTick) uses a monotonic clock, so it's
        intended for precision timing by comparing relative time values, not for
        getting the current system time.

        On Windows, $(D QueryPerformanceCounter) is used. On Mac OS X,
        $(D mach_absolute_time) is used, while on other Posix systems,
        $(D clock_gettime) is used. If $(D mach_absolute_time) or
        $(D clock_gettime) is unavailable, then Posix systems use
        $(D gettimeofday) (the decision is made when $(D TickDuration) is
        compiled), which unfortunately, is not monotonic, but if
        $(D mach_absolute_time) and $(D clock_gettime) aren't available, then
        $(D gettimeofday) is the the best that there is.

        $(RED Warning):
            On some systems, the monotonic clock may stop counting when
            the computer goes to sleep or hibernates. So, the monotonic
            clock could be off if that occurs. This is known to happen
            on Mac OS X. It has not been tested whether it occurs on
            either Windows or on Linux.

        Throws:
            $(D TimeException) if it fails to get the time.
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
    units use truncating division. Years and months can be converted to each
    other, small units can be converted to each other, but years and months
    cannot be converted to or from smaller units (due to the varying number
    of days in a month or year).

    Params:
        tuFrom = The units of time to covert from.
        tuFrom = The units of time to covert type.
        value  = The value to convert.

    Examples:
--------------------
assert(convert!("years", "months")(1) == 12);
assert(convert!("months", "years")(12) == 1);

assert(convert!("weeks", "days")(1) == 7);
assert(convert!("hours", "seconds")(1) == 3600);
assert(convert!("seconds", "days")(1) == 0);
assert(convert!("seconds", "days")(86_400) == 1);

assert(convert!("nsecs", "nsecs")(1) == 1);
assert(convert!("nsecs", "hnsecs")(1) == 0);
assert(convert!("hnsecs", "nsecs")(1) == 100);
assert(convert!("nsecs", "seconds")(1) == 0);
assert(convert!("seconds", "nsecs")(1) == 1_000_000_000);
--------------------
  +/
long convert(string from, string to)(long value) @safe pure nothrow
    if(((from == "weeks" ||
         from == "days" ||
         from == "hours" ||
         from == "minutes" ||
         from == "seconds" ||
         from == "msecs" ||
         from == "usecs" ||
         from == "hnsecs" ||
         from == "nsecs") &&
        (to == "weeks" ||
         to == "days" ||
         to == "hours" ||
         to == "minutes" ||
         to == "seconds" ||
         to == "msecs" ||
         to == "usecs" ||
         to == "hnsecs" ||
         to == "nsecs")) ||
       ((from == "years" || from == "months") && (to == "years" || to == "months")))
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
    else static if(from == "nsecs" && to == "nsecs")
        return value;
    else static if(from == "nsecs")
        return convert!("hnsecs", to)(value / 100);
    else static if(to == "nsecs")
        return convert!(from, "hnsecs")(value) * 100;
    else
        return (hnsecsPer!from * value) / hnsecsPer!to;
}

//Verify Examples
unittest
{
    assert(convert!("years", "months")(1) == 12);
    assert(convert!("months", "years")(12) == 1);

    assert(convert!("weeks", "days")(1) == 7);
    assert(convert!("hours", "seconds")(1) == 3600);
    assert(convert!("seconds", "days")(1) == 0);
    assert(convert!("seconds", "days")(86_400) == 1);

    assert(convert!("nsecs", "nsecs")(1) == 1);
    assert(convert!("nsecs", "hnsecs")(1) == 0);
    assert(convert!("hnsecs", "nsecs")(1) == 100);
    assert(convert!("nsecs", "seconds")(1) == 0);
    assert(convert!("seconds", "nsecs")(1) == 1_000_000_000);
}

unittest
{
    foreach(units; _TypeTuple!("weeks", "days", "hours", "seconds", "msecs", "usecs", "hnsecs", "nsecs"))
    {
        static assert(!__traits(compiles, convert!("years", units)(12)), units);
        static assert(!__traits(compiles, convert!(units, "years")(12)), units);
    }

    foreach(units; _TypeTuple!("years", "months", "weeks", "days",
                               "hours", "seconds", "msecs", "usecs", "hnsecs", "nsecs"))
    {
        assert(convert!(units, units)(12) == 12);
    }

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
}


/++
    Represents fractional seconds.

    This is the portion of the time which is smaller than a second and it cannot
    hold values which would be greater than or equal to a second (or less than
    or equal to a negative second).

    It holds hnsecs internally, but you can create it using either milliseconds,
    microseconds, or hnsecs. What it does is allow for a simple way to set or
    adjust the fractional seconds portion of a $(D Duration) or a
    $(XREF datetime, SysTime) without having to worry about whether you're
    dealing with milliseconds, microseconds, or hnsecs.

    $(D FracSec)'s functions which take time unit strings do accept
    $(D "nsecs"), but because the resolution of $(D Duration) and
    $(XREF datetime, SysTime) is hnsecs, you don't actually get precision higher
    than hnsecs. $(D "nsecs") is accepted merely for convenience. Any values
    given as nsecs will be converted to hnsecs using $(D convert) (which uses
    truncating division when converting to smaller units).
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
        Returns the negation of this $(D FracSec).
      +/
    FracSec opUnary(string op)() @safe const pure nothrow
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
            foreach(F; _TypeTuple!(FracSec, const FracSec, immutable FracSec))
            {
                F fs = FracSec(val);
                assert(-fs == FracSec(-val));
            }
        }
    }


    /++
        The value of this $(D FracSec) as milliseconds.
      +/
    @property int msecs() @safe const pure nothrow
    {
        return cast(int)convert!("hnsecs", "msecs")(_hnsecs);
    }

    unittest
    {
        foreach(F; _TypeTuple!(FracSec, const FracSec, immutable FracSec))
        {
            assert(FracSec(0).msecs == 0);

            foreach(sign; [1, -1])
            {
                assert((cast(F)FracSec(1 * sign)).msecs == 0);
                assert((cast(F)FracSec(999 * sign)).msecs == 0);
                assert((cast(F)FracSec(999_999 * sign)).msecs == 99 * sign);
                assert((cast(F)FracSec(9_999_999 * sign)).msecs == 999 * sign);
            }
        }
    }


    /++
        The value of this $(D FracSec) as milliseconds.

        Params:
            milliseconds = The number of milliseconds passed the second.

        Throws:
            $(D TimeException) if the given value is not less than $(D 1) second
            and greater than a $(D -1) seconds.
      +/
    @property void msecs(int milliseconds) @safe pure
    {
        immutable hnsecs = cast(int)convert!("msecs", "hnsecs")(milliseconds);

        _enforceValid(hnsecs);
        _hnsecs = hnsecs;
    }

    unittest
    {
        static void test(int msecs, FracSec expected = FracSec.init, size_t line = __LINE__)
        {
            FracSec fs;
            fs.msecs = msecs;

            if(fs != expected)
                throw new AssertError("unittest failure", __FILE__, line);
        }

        _assertThrown!TimeException(test(-1000));
        _assertThrown!TimeException(test(1000));

        test(0, FracSec(0));

        foreach(sign; [1, -1])
        {
            test(1 * sign, FracSec(10_000 * sign));
            test(999 * sign, FracSec(9_990_000 * sign));
        }

        foreach(F; _TypeTuple!(const FracSec, immutable FracSec))
        {
            F fs = FracSec(1234567);
            static assert(!__traits(compiles, fs.msecs = 12), F.stringof);
        }
    }


    /++
        The value of this $(D FracSec) as microseconds.
      +/
    @property int usecs() @safe const pure nothrow
    {
        return cast(int)convert!("hnsecs", "usecs")(_hnsecs);
    }

    unittest
    {
        foreach(F; _TypeTuple!(FracSec, const FracSec, immutable FracSec))
        {
            assert(FracSec(0).usecs == 0);

            foreach(sign; [1, -1])
            {
                assert((cast(F)FracSec(1 * sign)).usecs == 0);
                assert((cast(F)FracSec(999 * sign)).usecs == 99 * sign);
                assert((cast(F)FracSec(999_999 * sign)).usecs == 99_999 * sign);
                assert((cast(F)FracSec(9_999_999 * sign)).usecs == 999_999 * sign);
            }
        }
    }


    /++
        The value of this $(D FracSec) as microseconds.

        Params:
            microseconds = The number of microseconds passed the second.

        Throws:
            $(D TimeException) if the given value is not less than $(D 1) second
            and greater than a $(D -1) seconds.
      +/
    @property void usecs(int microseconds) @safe pure
    {
        immutable hnsecs = cast(int)convert!("usecs", "hnsecs")(microseconds);

        _enforceValid(hnsecs);
        _hnsecs = hnsecs;
    }

    unittest
    {
        static void test(int usecs, FracSec expected = FracSec.init, size_t line = __LINE__)
        {
            FracSec fs;
            fs.usecs = usecs;

            if(fs != expected)
                throw new AssertError("unittest failure", __FILE__, line);
        }

        _assertThrown!TimeException(test(-1_000_000));
        _assertThrown!TimeException(test(1_000_000));

        test(0, FracSec(0));

        foreach(sign; [1, -1])
        {
            test(1 * sign, FracSec(10 * sign));
            test(999 * sign, FracSec(9990 * sign));
            test(999_999 * sign, FracSec(9_999_990 * sign));
        }

        foreach(F; _TypeTuple!(const FracSec, immutable FracSec))
        {
            F fs = FracSec(1234567);
            static assert(!__traits(compiles, fs.usecs = 12), F.stringof);
        }
    }


    /++
        The value of this $(D FracSec) as hnsecs.
      +/
    @property int hnsecs() @safe const pure nothrow
    {
        return _hnsecs;
    }

    unittest
    {
        foreach(F; _TypeTuple!(FracSec, const FracSec, immutable FracSec))
        {
            assert(FracSec(0).hnsecs == 0);

            foreach(sign; [1, -1])
            {
                assert((cast(F)FracSec(1 * sign)).hnsecs == 1 * sign);
                assert((cast(F)FracSec(999 * sign)).hnsecs == 999 * sign);
                assert((cast(F)FracSec(999_999 * sign)).hnsecs == 999_999 * sign);
                assert((cast(F)FracSec(9_999_999 * sign)).hnsecs == 9_999_999 * sign);
            }
        }
    }


    /++
        The value of this $(D FracSec) as hnsecs.

        Params:
            hnsecs = The number of hnsecs passed the second.

        Throws:
            $(D TimeException) if the given value is not less than $(D 1) second
            and greater than a $(D -1) seconds.
      +/
    @property void hnsecs(int hnsecs) @safe pure
    {
        _enforceValid(hnsecs);
        _hnsecs = hnsecs;
    }

    unittest
    {
        static void test(int hnsecs, FracSec expected = FracSec.init, size_t line = __LINE__)
        {
            FracSec fs;
            fs.hnsecs = hnsecs;

            if(fs != expected)
                throw new AssertError("unittest failure", __FILE__, line);
        }

        _assertThrown!TimeException(test(-10_000_000));
        _assertThrown!TimeException(test(10_000_000));

        test(0, FracSec(0));

        foreach(sign; [1, -1])
        {
            test(1 * sign, FracSec(1 * sign));
            test(999 * sign, FracSec(999 * sign));
            test(999_999 * sign, FracSec(999_999 * sign));
            test(9_999_999 * sign, FracSec(9_999_999 * sign));
        }

        foreach(F; _TypeTuple!(const FracSec, immutable FracSec))
        {
            F fs = FracSec(1234567);
            static assert(!__traits(compiles, fs.hnsecs = 12), F.stringof);
        }
    }


    /++
        The value of this $(D FracSec) as nsecs.

        Note that this does not give you any greater precision
        than getting the value of this $(D FracSec) as hnsecs.
      +/
    @property int nsecs() @safe const pure nothrow
    {
        return cast(int)convert!("hnsecs", "nsecs")(_hnsecs);
    }

    unittest
    {
        foreach(F; _TypeTuple!(FracSec, const FracSec, immutable FracSec))
        {
            assert(FracSec(0).nsecs == 0);

            foreach(sign; [1, -1])
            {
                assert((cast(F)FracSec(1 * sign)).nsecs == 100 * sign);
                assert((cast(F)FracSec(999 * sign)).nsecs == 99_900 * sign);
                assert((cast(F)FracSec(999_999 * sign)).nsecs == 99_999_900 * sign);
                assert((cast(F)FracSec(9_999_999 * sign)).nsecs == 999_999_900 * sign);
            }
        }
    }


    /++
        The value of this $(D FracSec) as nsecs.

        Note that this does not give you any greater precision
        than setting the value of this $(D FracSec) as hnsecs.

        Params:
            nsecs = The number of nsecs passed the second.

        Throws:
            $(D TimeException) if the given value is not less than $(D 1) second
            and greater than a $(D -1) seconds.
      +/
    @property void nsecs(long nsecs) @safe pure
    {
        immutable hnsecs = cast(int)convert!("nsecs", "hnsecs")(nsecs);

        _enforceValid(hnsecs);
        _hnsecs = hnsecs;
    }

    unittest
    {
        static void test(int nsecs, FracSec expected = FracSec.init, size_t line = __LINE__)
        {
            FracSec fs;
            fs.nsecs = nsecs;

            if(fs != expected)
                throw new AssertError("unittest failure", __FILE__, line);
        }

        _assertThrown!TimeException(test(-1_000_000_000));
        _assertThrown!TimeException(test(1_000_000_000));

        test(0, FracSec(0));

        foreach(sign; [1, -1])
        {
            test(1 * sign, FracSec(0));
            test(10 * sign, FracSec(0));
            test(100 * sign, FracSec(1 * sign));
            test(999 * sign, FracSec(9 * sign));
            test(999_999 * sign, FracSec(9999 * sign));
            test(9_999_999 * sign, FracSec(99_999 * sign));
        }

        foreach(F; _TypeTuple!(const FracSec, immutable FracSec))
        {
            F fs = FracSec(1234567);
            static assert(!__traits(compiles, fs.nsecs = 12), F.stringof);
        }
    }


    /+
        Converts this $(D TickDuration) to a string.
      +/
    //Due to bug http://d.puremagic.com/issues/show_bug.cgi?id=3715 , we can't
    //have versions of toString() with extra modifiers, so we define one version
    //with modifiers and one without.
    string toString()
    {
        return _toStringImpl();
    }


    /++
        Converts this $(D TickDuration) to a string.
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
        assert(fs.toString() == "12 hnsecs");
        assert(cfs.toString() == "12 hnsecs");
        assert(ifs.toString() == "12 hnsecs");
    }


private:

    /++
        Since we have two versions of $(D toString), we have $(D _toStringImpl)
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
        foreach(sign; [1 , -1])
        {
            immutable signStr = sign == 1 ? "" : "-";

            assert(FracSec.from!"msecs"(0 * sign).toString() == "0 hnsecs");
            assert(FracSec.from!"msecs"(1 * sign).toString() == signStr ~ "1 ms");
            assert(FracSec.from!"msecs"(2 * sign).toString() == signStr ~ "2 ms");
            assert(FracSec.from!"msecs"(100 * sign).toString() == signStr ~ "100 ms");
            assert(FracSec.from!"msecs"(999 * sign).toString() == signStr ~ "999 ms");

            assert(FracSec.from!"usecs"(0* sign).toString() == "0 hnsecs");
            assert(FracSec.from!"usecs"(1* sign).toString() == signStr ~ "1 μs");
            assert(FracSec.from!"usecs"(2* sign).toString() == signStr ~ "2 μs");
            assert(FracSec.from!"usecs"(100* sign).toString() == signStr ~ "100 μs");
            assert(FracSec.from!"usecs"(999* sign).toString() == signStr ~ "999 μs");
            assert(FracSec.from!"usecs"(1000* sign).toString() == signStr ~ "1 ms");
            assert(FracSec.from!"usecs"(2000* sign).toString() == signStr ~ "2 ms");
            assert(FracSec.from!"usecs"(9999* sign).toString() == signStr ~ "9999 μs");
            assert(FracSec.from!"usecs"(10_000* sign).toString() == signStr ~ "10 ms");
            assert(FracSec.from!"usecs"(20_000* sign).toString() == signStr ~ "20 ms");
            assert(FracSec.from!"usecs"(100_000* sign).toString() == signStr ~ "100 ms");
            assert(FracSec.from!"usecs"(100_001* sign).toString() == signStr ~ "100001 μs");
            assert(FracSec.from!"usecs"(999_999* sign).toString() == signStr ~ "999999 μs");

            assert(FracSec.from!"hnsecs"(0* sign).toString() == "0 hnsecs");
            assert(FracSec.from!"hnsecs"(1* sign).toString() == (sign == 1 ? "1 hnsec" : "-1 hnsecs"));
            assert(FracSec.from!"hnsecs"(2* sign).toString() == signStr ~ "2 hnsecs");
            assert(FracSec.from!"hnsecs"(100* sign).toString() == signStr ~ "10 μs");
            assert(FracSec.from!"hnsecs"(999* sign).toString() == signStr ~ "999 hnsecs");
            assert(FracSec.from!"hnsecs"(1000* sign).toString() == signStr ~ "100 μs");
            assert(FracSec.from!"hnsecs"(2000* sign).toString() == signStr ~ "200 μs");
            assert(FracSec.from!"hnsecs"(9999* sign).toString() == signStr ~ "9999 hnsecs");
            assert(FracSec.from!"hnsecs"(10_000* sign).toString() == signStr ~ "1 ms");
            assert(FracSec.from!"hnsecs"(20_000* sign).toString() == signStr ~ "2 ms");
            assert(FracSec.from!"hnsecs"(100_000* sign).toString() == signStr ~ "10 ms");
            assert(FracSec.from!"hnsecs"(100_001* sign).toString() == signStr ~ "100001 hnsecs");
            assert(FracSec.from!"hnsecs"(200_000* sign).toString() == signStr ~ "20 ms");
            assert(FracSec.from!"hnsecs"(999_999* sign).toString() == signStr ~ "999999 hnsecs");
            assert(FracSec.from!"hnsecs"(1_000_001* sign).toString() == signStr ~ "1000001 hnsecs");
            assert(FracSec.from!"hnsecs"(9_999_999* sign).toString() == signStr ~ "9999999 hnsecs");
        }
    }


    /++
        Returns whether the given number of hnsecs fits within the range of
        $(D FracSec).

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
            $(D TimeException) if $(D valid(hnsecs)) is $(D false).
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
            $(D TimeException) if the given hnsecs less than 0 or would result
            in a $(D FracSec) not within the range (-1 second, 1 second).
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



/++
    Returns the absolute value of a duration.
  +/
Duration abs(Duration duration)
{
    return Duration(_abs(duration._hnsecs));
}

/++ Ditto +/
TickDuration abs(TickDuration duration)
{
    return TickDuration(_abs(duration.length));
}

unittest
{
    assert(abs(dur!"msecs"(5)) == dur!"msecs"(5));
    assert(abs(dur!"msecs"(-5)) == dur!"msecs"(5));

    assert(abs(TickDuration(17)) == TickDuration(17));
    assert(abs(TickDuration(-17)) == TickDuration(17));
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
    unit and the remaining hnsecs. It really shouldn't be used unless all units
    larger than the given units have already been split out.

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

//Verify Examples.
unittest
{
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
        $(LREF splitUnitsFromHNSecs)

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

//Verify Examples.
unittest
{
    auto hnsecs = 2595000000007L;
    immutable days = getUnitsFromHNSecs!"days"(hnsecs);
    assert(days == 3);
    assert(hnsecs == 2595000000007L);
}


/+
    This function is used to split out the units without getting the units but
    just the remaining hnsecs.

    See_Also:
        $(LREF splitUnitsFromHNSecs)

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

//Verify Examples.
unittest
{
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

//Verify Examples.
unittest
{
    assert(nextLargerTimeUnits!"minutes" == "hours");
    assert(nextLargerTimeUnits!"hnsecs" == "usecs");
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
}


/++
    Local version of abs, since std.math.abs is in Phobos, not druntime.
  +/
long _abs(long val)
{
    return val >= 0 ? val : -val;
}


/++
    Unfortunately, $(D snprintf) is not pure, so here's a way to convert
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


version(unittest) void assertApprox(D, E)(D actual,
                                          E lower,
                                          E upper,
                                          string msg = "unittest failure",
                                          size_t line = __LINE__)
    if(is(D : const Duration) && is(E : const Duration))
{
    if(actual < lower)
        throw new AssertError(msg ~ ": lower: " ~ actual.toString(), __FILE__, line);
    if(actual > upper)
        throw new AssertError(msg ~ ": upper: " ~ actual.toString(), __FILE__, line);
}

version(unittest) void assertApprox(D, E)(D actual,
                                          E lower,
                                          E upper,
                                          string msg = "unittest failure",
                                          size_t line = __LINE__)
    if(is(D : const TickDuration) && is(E : const TickDuration))
{
    if(actual.length < lower.length || actual.length > upper.length)
    {
        throw new AssertError(msg ~ ": [" ~ numToString(lower.length) ~ "] [" ~
                              numToString(actual.length) ~ "] [" ~
                              numToString(upper.length) ~ "]", __FILE__, line);
    }
}

version(unittest) void assertApprox()(long actual,
                                      long lower,
                                      long upper,
                                      string msg = "unittest failure",
                                      size_t line = __LINE__)
{
    if(actual < lower)
        throw new AssertError(msg ~ ": lower: " ~ numToString(actual), __FILE__, line);
    if(actual > upper)
        throw new AssertError(msg ~ ": upper: " ~ numToString(actual), __FILE__, line);
}
