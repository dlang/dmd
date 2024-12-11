/* TEST_OUTPUT:
---
fail_compilation/test18708.d(32): Error: one path skips field `s`
        i || bar(s = t);
        ^
fail_compilation/test18708.d(37): Error: one path skips field `s`
        i && bar(s = t);
        ^
fail_compilation/test18708.d(42): Error: one path skips field `s`
        i ? bar(s = t) : i;
        ^
fail_compilation/test18708.d(47): Error: one path skips field `s`
        i ? i : bar(s = t);
        ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=18708

struct S { int y; @disable this(); }

class C
{
    S s;

    this(S t)
    {
        if (bar(s = t)) foo(); // OK
    }

    this(S t, int i)
    {
        i || bar(s = t);
    }

    this(S t, int i, int j)
    {
        i && bar(s = t);
    }

    this(S t, int i, long j)
    {
        i ? bar(s = t) : i;
    }

    this(S t, int i, byte j)
    {
        i ? i : bar(s = t);
    }
}

int bar(S s);
int foo();

/***********************************/

class E : Exception
{
    this(string msg, int line = 0, int pos = 0) pure nothrow @safe
    {
        if (line)
            super("hello");
        else
            super(msg);
    }

    this(string msg, string file, size_t line) pure nothrow @safe
    {
        super(msg, file, line);
    }
}
