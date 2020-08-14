/*
TEST_OUTPUT:
---
fail_compilation/diag_self_assign.d(26): Warning: assignment of `x` from itself has no side effect
fail_compilation/diag_self_assign.d(28): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(29): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(30): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(34): Error: construction of member `this._xp` from itself
fail_compilation/diag_self_assign.d(40): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(41): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(42): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(62): Warning: assignment of `s._x` from itself has no side effect
fail_compilation/diag_self_assign.d(66): Warning: assignment of `x` from itself has no side effect
fail_compilation/diag_self_assign.d(72): Warning: assignment of `xp` from itself has no side effect
fail_compilation/diag_self_assign.d(74): Warning: assignment of `*xp` from itself has no side effect
fail_compilation/diag_self_assign.d(76): Warning: assignment of `*& x` from itself has no side effect
fail_compilation/diag_self_assign.d(78): Warning: assignment of `*& x` from itself has no side effect
---
*/
struct S
{
@safe pure nothrow @nogc:

    this(float x)
    {
        x = x;                  // warning

        _x = _x;                // error
        this._x = _x;           // error
        _x = this._x;           // error

        _x = _y;

        _xp = _xp;              // warning
        _xp = _yp;
    }

    void foo()
    {
        _x = _x;                // error
        this._x = _x;           // error
        _x = this._x;           // error
    }

    this(this) { count += 1;}   // posblit

    int count;

    float _x;
    float _y;

    float* _xp;
    float* _yp;
}

pure nothrow @nogc unittest
{
    S s;
    s = s;

    S t;
    s._x = s._x;                // warning
    s._x = t._x;

    int x;
    x = x;                      // warning

    int y;
    y = x;

    int* xp;
    xp = xp;                    // warning

    *xp = *xp;                  // warning

    (*&x) = (*&x);              // warning

    (*&*&x) = (*&*&x);          // warning

    static assert(__traits(compiles, { int t; t = t; }));
}

int x;                          // global?

/**
 * See_Also: https://forum.dlang.org/post/cjccfvhbtbgnajplrvbd@forum.dlang.org
 */
void test() @safe nothrow @nogc
{
    int x = x;          // x is in another scope so this doesn't cause shadowing
}
