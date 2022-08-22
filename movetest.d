struct SYZ {
    int x;
    this(int x) @safe pure nothrow @nogc { this.x = x; }
    ~this() @safe pure nothrow @nogc {}
    // TODO: enable when Errors are avoided @disable this(this);
}

// void moveOnAssign0() @safe pure nothrow @nogc {
//     SYZ s;
//     SYZ t = s;                    // TODO: `s` should move here
// }
void moveOnAssign1(SYZ s) @safe pure nothrow @nogc {
    SYZ t = s;                    // `s` is moved
}
// void moveOnAssign2(SYZ s) @safe pure nothrow @nogc {
//     SYZ t = s;                    // `s` is moved
//     SYZ u = t;                    // TODO: `t` should move here
// }

// void moveOnCall1(SYZ s) @safe pure nothrow @nogc {
//     static f(SYZ s) {}
//     f(s);                       // TODO: `s` should move here
// }

// struct S2 { @disable this(this); }
// version(none)
// void moveOnDisabledPostblit(S2 s) @safe pure nothrow @nogc {
//     S2 t = s;                   // TODO: should not error and `s` is moved
// }

// void moveOff(SYZ s) @safe pure nothrow @nogc {
//     SYZ t = s;                    // `s` is not moved here because
//     s.x = 42;                   // `s` is referenced in another type of Expression here
// }

// SYZ moveOnReturn1(SYZ s) @safe pure nothrow @nogc {
//     return s;                   // TODO: should move
// }

// SYZ moveOnReturn2(SYZ s) @safe pure nothrow @nogc {
//     SYZ t = s;
//     return t;                   // TODO: should move
// }
