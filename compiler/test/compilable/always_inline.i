// https://issues.dlang.org/show_bug?id=21938

__attribute__((always_inline)) int square(int x) { return x * x; }

int doSquare(int x) { return square(x); }
