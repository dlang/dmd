// REQUIRED_ARGS: -wi -unittest -diagnose=access -debug

/*
TEST_OUTPUT:
---
compilable/diag_class_member_escaped.d(32): Warning: value assigned to public variable `c` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_class_member_escaped.d(37): Warning: unmodified public variable `c` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
---
*/

@safe:

C _g_m;

class C {
    int x;                      // no warn
    int y;                      // no warn
    void yesLeak() { _g_m = this; }
    scope void noLeak() {}
    scope void noLeakConst() const {}
}

unittest
{
    C c;                        // no warn
    c.yesLeak();                // because may leak here
}

unittest
{
    C c;                        // warn
    c.noLeak();
}

unittest
{
    C c;                        // warn
    c.noLeakConst();
}
