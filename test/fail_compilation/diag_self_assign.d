// REQUIRED_ARGS: -w

/*
TEST_OUTPUT:
---
fail_compilation/diag_self_assign.d(39): Deprecation: assignment of `x` from itself has no side effect, to exercise assignment instead use `x = x.init`
fail_compilation/diag_self_assign.d(40): Deprecation: assignment of `t` from itself has no side effect, to exercise assignment instead use `t = t.init`
fail_compilation/diag_self_assign.d(42): Deprecation: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(43): Deprecation: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(44): Deprecation: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(48): Deprecation: construction of member `this._xp` from itself
fail_compilation/diag_self_assign.d(51): Deprecation: construction of member `this._t` from itself
fail_compilation/diag_self_assign.d(52): Deprecation: construction of member `this._t._z` from itself
fail_compilation/diag_self_assign.d(57): Deprecation: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(58): Deprecation: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(59): Deprecation: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(81): Deprecation: assignment of `s._x` from itself has no side effect, to exercise assignment instead use `s._x = s._x.init`
fail_compilation/diag_self_assign.d(85): Deprecation: assignment of `x` from itself has no side effect, to exercise assignment instead use `x = x.init`
fail_compilation/diag_self_assign.d(91): Deprecation: assignment of `xp` from itself has no side effect, to exercise assignment instead use `xp = xp.init`
fail_compilation/diag_self_assign.d(93): Deprecation: assignment of `*xp` from itself has no side effect, to exercise assignment instead use `*xp = *xp.init`
fail_compilation/diag_self_assign.d(95): Deprecation: assignment of `xp` from itself has no side effect, to exercise assignment instead use `xp = xp.init`
fail_compilation/diag_self_assign.d(97): Deprecation: assignment of `*& x` from itself has no side effect, to exercise assignment instead use `*& x = *& x.init`
fail_compilation/diag_self_assign.d(99): Deprecation: assignment of `*& x` from itself has no side effect, to exercise assignment instead use `*& x = *& x.init`
fail_compilation/diag_self_assign.d(115): Deprecation: assignment of `g_x` from itself has no side effect, to exercise assignment instead use `g_x = g_x.init`
fail_compilation/diag_self_assign.d(116): Deprecation: assignment of `g_x` from itself has no side effect, to exercise assignment instead use `g_x = g_x.init`
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

pure nothrow @nogc void test1()
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

    (&*xp) = (&*xp);            // warn

    (*&x) = (*&x);              // warn

    (*&*&x) = (*&*&x);          // warn

    static assert(__traits(compiles, { int t; t = t; }));
}

int g_x;

alias g_y = g_x;

/**
 * See_Also: https://forum.dlang.org/post/cjccfvhbtbgnajplrvbd@forum.dlang.org
 */
@safe nothrow @nogc void test2()
{
    int x;
    x = g_x;          // x is in another scope so this doesn't cause shadowing
    g_x = g_x;        // warn
    g_y = g_y;        // warn
}
