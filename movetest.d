struct S {
    int x;
    ~this() @safe pure nothrow @nogc {}
}

void moveOnAssign1(S s) @safe pure nothrow @nogc {
    S t = s;                    // s is moved
}
void moveOnAssign2(S s) @safe pure nothrow @nogc {
    S t = s;                    // s is moved
    S u = t;                    // TODO: t should move here
}

struct S2 { @disable this(this); }
void moveOnDisabledPostblit(S2 s) @safe pure nothrow @nogc {
    S2 t = s;                   // TODO: should not error and s is moved
}

void moveOff(S s) @safe pure nothrow @nogc {
    S t = s; // is not moved here because
    s.x = 42; // it's reference here
}
