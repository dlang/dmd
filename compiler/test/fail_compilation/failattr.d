// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/failattr.d(103): Error: variable `failattr.C2901.v1` cannot be `synchronized`
fail_compilation/failattr.d(104): Error: variable `failattr.C2901.v2` cannot be `override`
fail_compilation/failattr.d(105): Error: variable `failattr.C2901.v3` cannot be `abstract`
fail_compilation/failattr.d(106): Error: variable `failattr.C2901.v4` cannot be `final`, perhaps you meant `const`?
fail_compilation/failattr.d(118): Error: variable `failattr.C2901.v13` cannot be `final abstract synchronized override`
fail_compilation/failattr.d(120): Error: variable `failattr.C2901.v14` cannot be `final`, perhaps you meant `const`?
fail_compilation/failattr.d(123): Error: undefined identifier `ERROR`
---
*/
#line 100

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

enum B23122 { @ERROR e }
