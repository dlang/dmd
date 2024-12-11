/*
REQUIRED_ARGS: -unittest
TEST_OUTPUT:
---
fail_compilation/fail14249.d(45): Error: `shared static` constructor can only be member of module/aggregate/template, not function `main`
    shared static this() {}
    ^
fail_compilation/fail14249.d(46): Error: `shared static` destructor can only be member of module/aggregate/template, not function `main`
    shared static ~this() {}
    ^
fail_compilation/fail14249.d(47): Error: `static` constructor can only be member of module/aggregate/template, not function `main`
    static this() {}    // from fail197.d, 1510 ICE: Assertion failure: 'ad' on line 925 in file 'func.c'
    ^
fail_compilation/fail14249.d(48): Error: `static` destructor can only be member of module/aggregate/template, not function `main`
    static ~this() {}
    ^
fail_compilation/fail14249.d(49): Error: `unittest` can only be a member of module/aggregate/template, not function `main`
    unittest {}
    ^
fail_compilation/fail14249.d(50): Error: `invariant` can only be a member of aggregate, not function `main`
    invariant {}
    ^
fail_compilation/fail14249.d(51): Error: alias this can only be a member of aggregate, not function `main`
    alias a this;
    ^
fail_compilation/fail14249.d(52): Error: constructor can only be a member of aggregate, not function `main`
    this() {}           // from fail268.d
    ^
fail_compilation/fail14249.d(53): Error: destructor can only be a member of aggregate, not function `main`
    ~this() {}          // from fail268.d
    ^
fail_compilation/fail14249.d(54): Error: postblit can only be a member of struct, not function `main`
    this(this) {}
    ^
fail_compilation/fail14249.d(55): Error: anonymous union can only be a part of an aggregate, not function `main`
    union { int x; double y; }
    ^
fail_compilation/fail14249.d(59): Error: mixin `fail14249.main.Mix!()` error instantiating
    mixin Mix!();
    ^
---
*/
mixin template Mix()
{
    shared static this() {}
    shared static ~this() {}
    static this() {}    // from fail197.d, 1510 ICE: Assertion failure: 'ad' on line 925 in file 'func.c'
    static ~this() {}
    unittest {}
    invariant {}
    alias a this;
    this() {}           // from fail268.d
    ~this() {}          // from fail268.d
    this(this) {}
    union { int x; double y; }
}
void main()
{
    mixin Mix!();
}
