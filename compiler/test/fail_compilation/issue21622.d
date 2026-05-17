/*
TEST_OUTPUT:
---
issue21622.d(17): Error: `foo!0` matches multiple overloads exactly
issue21622.d(17): Error: `foo!0` has no effect
---
*/

// https://github.com/dlang/dmd/issues/21622

template foo(int N) {
    void foo() {}
}

void foo(int N)() {}

void main() {
    foo!0;
}
