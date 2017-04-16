//Optimization check
F foo(F)(F c, F d) {
    c += d;
    c += d;
    return c;
}

void test0() {
    alias F = float;
    enum F d = (cast(F)(2)) ^^ (F.max_exp - 1);
    assert(foo(-d, d) == d);
}

void test1() {
    alias F = double;
    enum F d = (cast(F)(2)) ^^ (F.max_exp - 1);
    assert(foo(-d, d) == d);
}

void test2() {
    alias F = real;
    enum F d = (cast(F)(2)) ^^ (F.max_exp - 1);
    assert(foo(-d, d) == d); 
}

void main() {
    test0();
    test1();
    test2();
    import core.stdc.stdio;
    printf("Success\n");
}
