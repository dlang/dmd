/*
TEST_OUTPUT:
---
fail_compilation/fail7369.d(11): Error: cannot modify `this.a` in `const` function
    invariant() { a += 5; }
                  ^
---
*/
struct S7369 {
    int a;
    invariant() { a += 5; }
}
