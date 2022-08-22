struct SYZ {
    int x;
    this(int x) { this.x = x; }
    ~this() {}
    // @disable this(this);
}

SYZ moveOnReturn1(SYZ s) {
    return s;                   // TODO: should move
}
// SYZ moveOnReturn2(SYZ s) {
//     SYZ t = s;
//     return t;                   // TODO: should move
// }

// void moveOnAssign0() {
//     SYZ s;
//     SYZ t = s;                    // TODO: `s` should move here
// }
void moveOnAssign1(SYZ s) {
    SYZ t = s;                    // `s` is moved
}
// void moveOnAssign2(SYZ s) {
//     SYZ t = s;                    // `s` is moved
//     SYZ u = t;                    // TODO: `t` should move here
// }

// void moveOnCall1(SYZ s) {
//     static f(SYZ s) {}
//     f(s);                       // TODO: `s` should move here
// }

// struct S2 { @disable this(this); }
// version(none)
// void moveOnDisabledPostblit(S2 s) {
//     S2 t = s;                   // TODO: should not error and `s` is moved
// }

// void moveOff(SYZ s) {
//     SYZ t = s;                    // `s` is not moved here because
//     s.x = 42;                   // `s` is referenced in another type of Expression here
// }
