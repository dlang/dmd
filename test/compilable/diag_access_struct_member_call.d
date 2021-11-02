// REQUIRED_ARGS: -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_struct_member_call.d(37): Warning: unmodified public variable `s` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_struct_member_call.d(43): Warning: unmodified public variable `s` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_struct_member_call.d(49): Warning: unmodified public variable `s` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
---
*/

@safe pure:

struct S
{
    int x;                      // no warn
    int y;                      // no warn
scope pure:                     // TODO: do we need `scope` here?
    void reset()
    {
        x = x.init;
        y = y.init;
    }
    int getX() const { return x; }
    int getY() const { return y; }
}

int f1()
{
    S s;                        // no warn
    s.reset();                  // because modified here
    return s.x + s.y;           // read here via fields
}

int f2()
{
    S s;                        // unmodified should be `const`
    return s.x + s.y;           // read here via fields
}

int f3()
{
    S s;                        // warn, unmodified should be `const`
    return s.getX() + s.getY(); // read here via const member
}

int f4()
{
    S s;                        // warn, unmodified should be `const`
    const bool x;
    if (x)
        return s.x + s.y;       // read here via fields
    else
        return s.getX() + s.getY(); // read here via const member
}
