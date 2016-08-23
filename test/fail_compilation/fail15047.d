/*
REQUIRED_ARGS: -w -O
TEST_OUTPUT:
---
fail_compilation/fail15047.d(22): Warning: variable a used before set
fail_compilation/fail15047.d(29): Warning: variable a used before set
---
*/












void one() {
    int a = void;
    int b = a;
}

int two() {
    int a = void;
    int b = void;
    int fun(int x) { int y = x; return y; }
    b = fun(a);
    return b;
}
