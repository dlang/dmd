@safe pure nothrow @nogc:

struct S {
    int x;
    this(int x) @safe pure nothrow @nogc { this.x = x; }
    ~this() @safe pure nothrow @nogc {}
}

void moveOnAssign1(S s) {
    S t = s;                    // `s` is moved
}
void moveOnAssign2(S s) {
    S t = s;                    // `s` is moved
    S u = t;                    // TODO: `t` should move here
}

void moveOnCall1(S s) {
    static f(S s) {}
    f(s);                       // TODO: `s` should move here
}

struct S2 { @disable this(this); }
version(none)
void moveOnDisabledPostblit(S2 s) {
    S2 t = s;                   // TODO: should not error and `s` is moved
}

void moveOff(S s) {
    S t = s;                    // `s` is not moved here because
    s.x = 42;                   // `s` is referenced in another type of Expression here
}

S moveOnReturn1(S s) {
    return s;                   // TODO: should move
}

S moveOnReturn2(S s) {
    S t = s;
    return t;                   // TODO: should move
}
