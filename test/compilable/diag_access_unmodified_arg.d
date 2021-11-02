// REQUIRED_ARGS: -wi -unittest -vunused

/*
TEST_OUTPUT:
---
compilable/diag_access_unmodified_arg.d(29): Warning: unmodified public variable `c` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified_arg.d(43): Warning: unmodified public variable `s` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified_arg.d(50): Warning: unmodified public variable `s` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified_arg.d(57): Warning: unmodified public variable `s` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified_arg.d(71): Warning: unmodified public variable `s` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified_arg.d(79): Warning: value assigned to public variable `s` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified_arg.d(94): Warning: unmodified public variable `s` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
---
*/

class C { int x; }
struct S { int x; }

unittest
{
    static void f(C c) {}
    C c;                        // no warn because
    f(c);                       // may be written here
}

unittest
{
    static void f(const C c) {}
    C c;                        // warn unmodified
    f(c);                       // cannot be written
}

unittest
{
    static void f(immutable C c) {}
    immutable C c;              // no warn, already immutable
    f(c);                       // cannot be written
}

unittest
{
    static void f(in S s) {}
    S s;                        // warn
    f(s);
}

unittest
{
    static void f(S s) {}
    S s;                        // warn
    f(s);
}

unittest
{
    static void f(const S s) {}
    S s;                        // warn
    f(s);
}

unittest
{
    static void f(ref S s) {}
    S s;                        // no warn because
    f(s);                       // may be written here
}

unittest
{
    static void f(ref const S s) {}
    S s;                        // warn
    f(s);                       // because can't be changed here
}

unittest
{
    static void f(out S s) {}
    S s;
    f(s);                       // warn, because zero initalized here but not used
}

unittest
{
    static void f(S* s) {}
    S* s;                       // no warn because
    f(s);                       // maybe changed here
    S t;                        // no warn because
    f(&t);                      // maybe changed here
}

unittest
{
    static void f(const S* s) {}
    S* s;                       // warn because
    f(s);                       // can't be changed here
    S t;                        // warn because
    f(&t);                      // can't be changed here
}

unittest
{
    static void f(immutable S* s) {}
    immutable S* s;             // no warn, already immutable
    f(s);                       // cannot be written
    immutable S t;              // no warn, already immutable
    f(&t);                      // cannot be written
}
