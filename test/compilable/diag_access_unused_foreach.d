// REQUIRED_ARGS: -wi -vcolumns -unittest -diagnose=access

/*
TEST_OUTPUT:
---
compilable/diag_access_unused_foreach.d(25,5): Warning: unused public variable `n` of foreach, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_foreach.d(25,5): Warning: unmodified public variable `n` of foreach should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_foreach.d(29,5): Warning: unused constant `n` of foreach, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_foreach.d(32,5): Warning: unused immutable `n` of foreach, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_foreach.d(48,5): Warning: unused public variable `pool` of foreach, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_foreach.d(48,5): Warning: unmodified public variable `pool` of foreach should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_foreach.d(47,14): Warning: unused public variable `pools` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_foreach.d(47,14): Warning: unmodified public variable `pools` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_foreach.d(29,5): Warning: unused constant `n` of foreach, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_foreach.d(32,5): Warning: unused immutable `n` of foreach, rename to `_` or prepend `_` to name to silence
---
*/

void g(size_t) @safe pure
{
}

void f() @safe pure
{
    foreach (n; 0 .. 10)
    {
        n = 1;
    }
    foreach (const n; 0 .. 10)  // warn, unused
    {
    }
    foreach (immutable n; 0 .. 10)  // warn, unused
    {
    }
    foreach (const n; 0 .. 10)  // no warn
    {
        g(n);                   // because used here
    }
    foreach (immutable n; 0 .. 10)  // no warn
    {
        g(n);                   // because used here
    }

    static void x(void* p) pure nothrow
    {
    }
    ubyte*[] pools;             // TODO: no warn
    foreach (pool; pools)       // TODO: no warn
    {
        x(pool);                // because maybe modified here
    }
}
