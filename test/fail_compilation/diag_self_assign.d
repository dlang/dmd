// REQUIRED_ARGS: -w -vcolumns

/*
TEST_OUTPUT:
---
fail_compilation/diag_self_assign.d(54,11): Deprecation: assignment of `x` from itself has no side effect, to force assignment use `x = x.init`
fail_compilation/diag_self_assign.d(55,11): Deprecation: assignment of `t` from itself has no side effect, to force assignment use `t = t.init`
fail_compilation/diag_self_assign.d(57,12): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(58,17): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(59,12): Error: construction of member `this._x` from itself
fail_compilation/diag_self_assign.d(63,13): Error: construction of member `this._xp` from itself
fail_compilation/diag_self_assign.d(66,12): Error: construction of member `this._t` from itself
fail_compilation/diag_self_assign.d(67,15): Error: construction of member `this._t._z` from itself
fail_compilation/diag_self_assign.d(72,12): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(73,17): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(74,12): Error: assignment of member `this._x` from itself
fail_compilation/diag_self_assign.d(96,10): Deprecation: assignment of `s._x` from itself has no side effect, to force assignment use `s._x = s._x.init`
fail_compilation/diag_self_assign.d(100,7): Deprecation: assignment of `x` from itself has no side effect, to force assignment use `x = x.init`
fail_compilation/diag_self_assign.d(106,8): Deprecation: assignment of `xp` from itself has no side effect, to force assignment use `xp = xp.init`
fail_compilation/diag_self_assign.d(108,9): Deprecation: assignment of `*xp` from itself has no side effect, to force assignment use `*xp = *xp.init`
fail_compilation/diag_self_assign.d(110,12): Deprecation: assignment of `xp` from itself has no side effect, to force assignment use `xp = xp.init`
fail_compilation/diag_self_assign.d(112,11): Deprecation: assignment of `*& x` from itself has no side effect, to force assignment use `*& x = *& x.init`
fail_compilation/diag_self_assign.d(114,13): Deprecation: assignment of `*& x` from itself has no side effect, to force assignment use `*& x = *& x.init`
fail_compilation/diag_self_assign.d(130,9): Deprecation: assignment of `g_x` from itself has no side effect, to force assignment use `g_x = g_x.init`
fail_compilation/diag_self_assign.d(131,9): Deprecation: assignment of `g_x` from itself has no side effect, to force assignment use `g_x = g_x.init`
fail_compilation/diag_self_assign.d(176,9): Warning: Expression `x & x` is same as `x`
fail_compilation/diag_self_assign.d(183,9): Warning: Expression `x & x` is same as `x`
fail_compilation/diag_self_assign.d(189,9): Warning: Expression `x | x` is same as `x`
fail_compilation/diag_self_assign.d(192,9): Warning: Expression `x & x` is same as `x`
fail_compilation/diag_self_assign.d(193,9): Warning: Expression `x & x` is same as `x`
fail_compilation/diag_self_assign.d(192,9): Warning: Expression `x & x | x & x` is same as `x & x`
fail_compilation/diag_self_assign.d(196,9): Warning: Logical expression `x && x` is same as `x`
fail_compilation/diag_self_assign.d(199,9): Warning: Logical expression `x || x` is same as `x`
fail_compilation/diag_self_assign.d(202,10): Warning: Logical expression `x && x` is same as `x`
fail_compilation/diag_self_assign.d(203,10): Warning: Logical expression `x && x` is same as `x`
fail_compilation/diag_self_assign.d(202,9): Warning: Logical expression `x && x || x && x` is same as `x && x`
fail_compilation/diag_self_assign.d(208,16): Warning: Conditional expression `true ? x : x` is same as `x`
fail_compilation/diag_self_assign.d(209,24): Warning: Logical expression `x && x` is same as `x`
fail_compilation/diag_self_assign.d(209,35): Warning: Logical expression `x && x` is same as `x`
fail_compilation/diag_self_assign.d(209,16): Warning: Conditional expression `true ? x && x : x && x` is same as `x && x`
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

struct U
{
@safe pure nothrow @nogc:
    void opAssign(U) {}
}

@safe pure nothrow @nogc void test2()
{
    U u;
    u = u;
}

/// Neither GCC 10` nor Clang 10 warn here.
void check_equal_lhs_and_rhs(int i)
{
    bool x, y;
    alias xa = x;

    enum { a = 0, b = 1 }
    enum { x1 = (0 | 1), x2 }

    if (a & a)
        i = 42;

    if (b & b)
        i = 42;

    if (a & b)
        i = 42;

    if (1 & 2)
        i = 42;

    if (false & false)
        i = 42;

    if (true & true)
        i = 42;

    if (x1 & x1)
        i = 42;

    if (x & x)                  // warn
        i = 42;

    i = x + x;
    i = x - x;
    i = x * x;

    if (x & xa)                 // warn
        i = 42;

    if (x & y)
        i = 42;

    if (x | x)                  // warn
        i = 42;

    if (x & x |                 // warn
        x & x)                  // warn
        i = 42;

    if (x && x)                 // warn
        i = 42;

    if (x || x)                 // warn
        i = 42;

    if ((x && x) ||             // warn
        (x && x))               // warn
        i = 42;

    const i1 = true ? 42 : 42;
    const i2 = true ? a : a;
    const i3 = true ? x : x;    // warn
    const i4 = true ? (x && x) : (x && x); // warn

    enum int ei2 = 2;
    enum int ei3 = 3;
    assert(ei2 & ei3);
    assert(ei2 && ei3);
}

/** State being either `yes`, `no` or `unknown`.
 */
struct Tristate
{
@safe pure nothrow @nogc:

    enum defaultCode = 0;

    enum no      = make(defaultCode);
    enum yes     = make(2);
    enum unknown = make(6);

    this(bool b)
    {
        _v = b ? yes._v : no._v;
    }

    void opAssign(bool b)
    {
        _v = b ? yes._v : no._v;
    }

    Tristate opUnary(string s)() if (s == "~")
    {
        return make((193 >> _v & 3) << 1);
    }

    Tristate opBinary(string s)(Tristate rhs) if (s == "|")
    {
        return make((12756 >> (_v + rhs._v) & 3) << 1);
    }

    Tristate opBinary(string s)(Tristate rhs) if (s == "&")
    {
        return make((13072 >> (_v + rhs._v) & 3) << 1);
    }

    Tristate opBinary(string s)(Tristate rhs) if (s == "^")
    {
        return make((13252 >> (_v + rhs._v) & 3) << 1);
    }

private:
    ubyte _v = defaultCode;
    static Tristate make(ubyte b)
    {
        Tristate r = void;
        r._v = b;
        return r;
    }
}

@safe pure nothrow @nogc unittest
{
    alias T = Tristate;
    T a;
    assert(a == T.no);
    static assert(!is(typeof({ if (a) {} })));
    assert(!is(typeof({ auto b = T(3); })));

    a = true;
    assert(a == T.yes);

    a = false;
    assert(a == T.no);

    a = T.unknown;
    T b;

    b = a;
    assert(b == a);

    auto c = a | b;
    assert(c == T.unknown);
    assert((a & b) == T.unknown);

    a = true;
    assert(~a == T.no);

    a = true;
    b = false;
    assert((a ^ b) == T.yes);

    with (T)
    {
        // or
        assert((no | no) == no); // TODO: shouldn't warn
        assert((no | yes) == yes);
        assert((yes | no) == yes);
        assert((yes | yes) == yes); // TODO: shouldn't warn
        assert((no | unknown) == unknown);
        assert((yes | unknown) == yes);
        assert((unknown | no) == unknown);
        assert((unknown | yes) == yes);
        assert((unknown | unknown) == unknown); // TODO: shouldn't warn

        // and
        assert((no & no) == no); // TODO: shouldn't warn
        assert((no & yes) == no);
        assert((yes & no) == no);
        assert((yes & yes) == yes); // TODO: shouldn't warn
        assert((no & unknown) == no);
        assert((unknown & no) == no);
        assert((unknown & unknown) == unknown); // TODO: shouldn't warn
        assert((yes & unknown) == unknown);
        assert((unknown & yes) == unknown);

        // exclusive or
        assert((yes ^ yes) == no);
        assert((no ^ no) == no);
        assert((no ^ yes) == yes);
        assert((yes ^ no) == yes);
        assert((no ^ unknown) == unknown);
        assert((yes ^ unknown) == unknown);
        assert((unknown ^ no) == unknown);
        assert((unknown ^ yes) == unknown);
        assert((unknown ^ unknown) == unknown);
    }
}

/** Tristate: Three-state logic.
*/
struct TristateCond
{
    @safe pure nothrow @nogc:

    enum defaultCode = 0;

    enum no      = make(defaultCode);
    enum yes     = make(1);
    enum unknown = make(4);

    this(bool b)
    {
        _v = b ? yes._v : no._v;
    }

    void opAssign(bool b)
    {
        _v = b ? yes._v : no._v;
    }

    TristateCond opUnary(string s)() if (s == "~")
    {
        return this == unknown ? this : make(!_v);
    }

    TristateCond opBinary(string s)(TristateCond rhs) if (s == "|")
    {
        // | yields 0, 1, 4, 5
        auto v = _v | rhs._v;
        return v == 4 ? unknown : make(v & 1);
    }

    TristateCond opBinary(string s)(TristateCond rhs) if (s == "&")
    {
        // & yields 0, 1, 4
        return make(_v & rhs._v);
    }

    TristateCond opBinary(string s)(TristateCond rhs) if (s == "^")
    {
        // + yields 0, 1, 2, 4, 5, 8
        auto v = _v + rhs._v;
        return v >= 4 ? unknown : make(!!v);
    }

private:
    ubyte _v = defaultCode;
    static TristateCond make(ubyte b)
    {
        TristateCond r = void;
        r._v = b;
        return r;
    }
}

@safe pure nothrow @nogc unittest
{
    TristateCond a;
    assert(a == TristateCond.no);
    static assert(!is(typeof({ if (a) {} })));
    assert(!is(typeof({ auto b = TristateCond(3); })));
    a = true;
    assert(a == TristateCond.yes);
    a = false;
    assert(a == TristateCond.no);
    a = TristateCond.unknown;
    TristateCond b;
    b = a;
    assert(b == a);
    auto c = a | b;
    assert(c == TristateCond.unknown);
    assert((a & b) == TristateCond.unknown);
    a = true;
    assert(~a == TristateCond.no);
    a = true;
    b = false;
    assert((a ^ b) == TristateCond.yes);
}
