// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/failattr.d(22): Error: variable `failattr.C2901.v1` cannot be `synchronized`
fail_compilation/failattr.d(23): Error: variable `failattr.C2901.v2` cannot be `override`
fail_compilation/failattr.d(24): Error: variable `failattr.C2901.v3` cannot be `abstract`
fail_compilation/failattr.d(25): Error: variable `failattr.C2901.v4` cannot be `final`, perhaps you meant `const`?
fail_compilation/failattr.d(37): Error: variable `failattr.C2901.v13` cannot be `final abstract synchronized override`
fail_compilation/failattr.d(39): Error: variable `failattr.C2901.v14` cannot be `final`, perhaps you meant `const`?
fail_compilation/failattr.d(43): Deprecation: variable `failattr.e1` cannot be `@nogc`
fail_compilation/failattr.d(44): Deprecation: variable `failattr.e2` cannot be `@property`
fail_compilation/failattr.d(45): Deprecation: variable `failattr.e3` cannot be `nothrow`
fail_compilation/failattr.d(46): Deprecation: variable `failattr.e4` cannot be `pure`
fail_compilation/failattr.d(47): Deprecation: variable `failattr.e5` cannot be `@live`
fail_compilation/failattr.d(62): Error: variable `failattr.c6` cannot be `final @nogc`
---
*/
class C2901
{
    synchronized    int v1;         // error
    override        int v2;         // error
    abstract        int v3;         // error
    final           int v4;         // error

    synchronized    { int v5; }     // no error
    override        { int v6; }     // no error
    abstract        { int v7; }     // no error
    final           { int v8; }     // no error

    synchronized:   int v9;         // no error
    override:       int v10;        // no error
    abstract:       int v11;        // no error
    final:          int v12;        // no error

    synchronized override abstract final int v13;   // one line error

    static final int v14;           // error, even if static is applied at the same time
}

// https://issues.dlang.org/show_bug.cgi?id=7432
@nogc           int e1;         // deprecation
@property       int e2;         // deprecation
nothrow         int e3;         // deprecation
pure            int e4;         // deprecation
@live           int e5;         // deprecation

@nogc          { int s1; }      // no error
@property      { int s2; }      // no error
nothrow        { int s3; }      // no error
pure           { int s4; }      // no error
@live          { int s5; }      // no error

@nogc:         int c1;          // no error
@property:     int c2;          // no error
nothrow:       int c3;          // no error
pure:          int c4;          // no error
@live:         int c5;          // no error

// deprecation + error => error
@nogc final int c6;             // error

// this should still be allowed
nothrow void function() x = null;
@nogc void function()[1] x = [null];
