// https://issues.dlang.org/show_bug.cgi?id=22663

void main()
{
    struct S
    {
        bool b: 1;
    }
    S s = S(true);

    assert(s.b == true);
    assert(s.b == 1);

    assert(!s.b == false);
    assert(!s.b == 0);

    assert(s.b ? true : false);
    assert(!s.b ? false: true);

    if (s.b) assert(1);
    if (!s.b) assert(0);
}
