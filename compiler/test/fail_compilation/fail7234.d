/*
TEST_OUTPUT:
---
fail_compilation/fail7234.d(16): Error: no property `empty` for `r` of type `fail7234.Contract*`
fail_compilation/fail7234.d(16):        perhaps `import std.range;` is needed?
fail_compilation/fail7234.d(16): Error: template instance `opDispatch!"empty"` does not match template declaration `opDispatch()()`
---
*/

struct Contract {
    void opDispatch()(){}
}

void foo()
{
    Contract* r; if (r.empty) {}
}
