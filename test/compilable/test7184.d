// https://issues.dlang.org/show_bug.cgi?id=7184

static assert({
    int[2] y;
    int *x = y.ptr;
    *(x)++=2;
    assert(y[0] == 2);
    assert(y[1] == 0);

    auto a = 0;
    auto b = (a)++;
    assert(a == 1);
    assert(b == 0);

    a = 1;
    b = 1;
    b = (a)--;
    assert(a == 0);
    assert(b == 1);
    return true;
}());
