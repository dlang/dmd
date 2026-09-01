// https://github.com/dlang/dmd/issues/22175
// void-returning update callback for AA must take value by ref
/*
TEST_OUTPUT:
---
fail_compilation/fail22175.d(14): Error: static assert:  "void-returning update callback must take ref parameter"
---
*/

void main()
{
    int[int] aa;
    // Regression guard: this callback shape must never compile.
    static assert(
        is(typeof(aa.update(1, () => 10, delegate void(int x) { x += 1; }))),
        "void-returning update callback must take ref parameter"
    );
}
