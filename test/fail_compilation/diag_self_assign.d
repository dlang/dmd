// REQUIRED_ARGS: -w

/*
TEST_OUTPUT:
---
fail_compilation/diag_self_assign.d(37): Warning: assignment of `x` from itself has no side effect
fail_compilation/diag_self_assign.d(38): Warning: assignment of `t` from itself has no side effect
fail_compilation/diag_self_assign.d(40): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(41): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(42): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(46): Error: construction of member `this._xp` from itself
fail_compilation/diag_self_assign.d(49): Error: construction of member `this._t` from itself
fail_compilation/diag_self_assign.d(50): Error: construction of member `this._t._z` from itself
fail_compilation/diag_self_assign.d(55): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(56): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(57): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(79): Warning: assignment of `s._x` from itself has no side effect
fail_compilation/diag_self_assign.d(83): Warning: assignment of `x` from itself has no side effect
fail_compilation/diag_self_assign.d(89): Warning: assignment of `xp` from itself has no side effect
fail_compilation/diag_self_assign.d(91): Warning: assignment of `*xp` from itself has no side effect
fail_compilation/diag_self_assign.d(93): Warning: assignment of `*& x` from itself has no side effect
fail_compilation/diag_self_assign.d(95): Warning: assignment of `*& x` from itself has no side effect
fail_compilation/diag_self_assign.d(109): Warning: assignment of `g_x` from itself has no side effect
---
*/
struct S
{
@safe pure nothrow @nogc:

    struct T
    {
        int _z;
    }

    this(float x, T t)
    {
        x = x;                  // warn
        t = t;                  // warn

        _x = _x;                // error
        this._x = _x;           // error
        _x = this._x;           // error

        _x = _y;

        _xp = _xp;              // error
        _xp = _yp;

        _t = _t;                // error
        _t._z = _t._z;          // error (transitive)
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

    T _t;
}

void test1()
{
    S s;
    s = s;

    S t;
    s._x = s._x;                // warn
    s._x = t._x;

    int x;
    x = x;                      // warn

    int y;
    y = x;

    int* xp;
    xp = xp;                    // warn

    *xp = *xp;                  // warn

    (*&x) = (*&x);              // warn

    (*&*&x) = (*&*&x);          // warn

    static assert(__traits(compiles, { int t; t = t; }));
}

int g_x;

/**
 * See_Also: https://forum.dlang.org/post/cjccfvhbtbgnajplrvbd@forum.dlang.org
 */
@safe nothrow @nogc void test2()
{
    int x;
    x = g_x;          // x is in another scope so this doesn't cause shadowing
    g_x = g_x;        // warn
}
