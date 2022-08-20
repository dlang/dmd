struct S
{
    int x;
    ~this() @safe pure nothrow @nogc
    {
        // import std.stdio;
        // debug writeln(__FUNCTION__);
    }
}

void moveOnAssign1(S s) @safe pure nothrow @nogc
{
    S t = s;                    // s is moved
}

void moveOnAssign2(S s) @safe pure nothrow @nogc
{
    S t = s;                    // s is moved
    S u = t;                    // TODO: t should move here
}

void moveOff(S s) @safe pure nothrow @nogc
{
    S t = s; // is not moved here because
    s.x = 42; // it's reference here
}
