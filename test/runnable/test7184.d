// https://issues.dlang.org/show_bug.cgi?id=7184

void main()
{
    auto a = 0;
    auto b = (a)++;
    assert(a == 1);
    assert(b == 0);

    a = 1;
    b = 1;
    b = (a)--;
    assert(a == 0);
    assert(b == 1);
}
