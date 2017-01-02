/*
REQUIRED_ARGS: -wi -O
TEST_OUTPUT:
---
compilable/test15047.d(22): Warning: variable a used before set
compilable/test15047.d(29): Warning: variable a used before set
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
