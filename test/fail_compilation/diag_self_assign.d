// REQUIRED_ARGS: -w

/*
TEST_OUTPUT:
---
fail_compilation/diag_self_assign.d(36): Warning: assignment of `x` from itself has no side effect
fail_compilation/diag_self_assign.d(37): Warning: assignment of `t` from itself has no side effect
fail_compilation/diag_self_assign.d(39): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(40): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(41): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(45): Error: construction of member `this._xp` from itself
fail_compilation/diag_self_assign.d(48): Error: construction of member `this._t` from itself
fail_compilation/diag_self_assign.d(49): Error: construction of member `this._t._z` from itself
fail_compilation/diag_self_assign.d(54): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(55): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(56): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(78): Warning: assignment of `s._x` from itself has no side effect
fail_compilation/diag_self_assign.d(82): Warning: assignment of `x` from itself has no side effect
fail_compilation/diag_self_assign.d(88): Warning: assignment of `xp` from itself has no side effect
fail_compilation/diag_self_assign.d(90): Warning: assignment of `*xp` from itself has no side effect
fail_compilation/diag_self_assign.d(92): Warning: assignment of `*& x` from itself has no side effect
fail_compilation/diag_self_assign.d(94): Warning: assignment of `*& x` from itself has no side effect
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

int x;                          // global?

/**
 * See_Also: https://forum.dlang.org/post/cjccfvhbtbgnajplrvbd@forum.dlang.org
 */
void test2() @safe nothrow @nogc
{
    int x = x;          // x is in another scope so this doesn't cause shadowing
}
