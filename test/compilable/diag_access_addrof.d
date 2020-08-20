// REQUIRED_ARGS: -wi -unittest -diagnose=access -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_addrof.d(39): Warning: unused public variable `s1` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(39): Warning: unmodified public variable `s1` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(40): Warning: unused local variable `s2` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(40): Warning: unused public variable `s2` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(40): Warning: unmodified public variable `s2` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(41): Warning: unused local variable `xp` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(41): Warning: unused public variable `xp` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(41): Warning: unmodified public variable `xp` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(52): Warning: unused public variable `t1` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(52): Warning: unmodified public variable `t1` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(53): Warning: unused local variable `t2` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(53): Warning: unused public variable `t2` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(53): Warning: unmodified public variable `t2` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(54): Warning: unused local variable `xp` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(54): Warning: unused public variable `xp` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(54): Warning: unmodified public variable `xp` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(34): Warning: unused public field `y` of private struct, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(40): Warning: unused local variable `s2` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(41): Warning: unused local variable `xp` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(46): Warning: unused public field `x` of private struct, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(53): Warning: unused local variable `t2` of function, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_addrof.d(54): Warning: unused local variable `xp` of function, remove, rename to `_` or prepend `_` to name to silence
---
*/

private struct S
{
    int x;
    int y;                      // warn
}

void f1()
{
    S s1;
    S s2;                       // warn
    int* xp = &(s1.x);          // warn
}

private struct T
{
    int x;                      // warn
    int y;
}

void f2()
{
    T t1;
    T t2;                       // warn
    auto xp = &(t1.y);          // warn
}
