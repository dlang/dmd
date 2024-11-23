/*
TEST_OUTPUT:
---
fail_compilation/issue11070.d(18): Error: undefined identifier `x`
    x = 1;
    ^
---
*/

int get() { return 1; }

void test() {
    import std.stdio : writeln;
    switch (auto x = get()) {
        default:
            auto z = x;
    }
    x = 1;
}
