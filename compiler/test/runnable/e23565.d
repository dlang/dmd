module e23565;

struct S
{
    int[] a;
}

void main()
{
    auto a = new int[](2);
    a.ptr[$-1] = 20;
    assert(a[1] == 20);

    S s;
    s.a.length = 2;
    s.a.ptr[$-1] = 20;
    assert(s.a[1] == 20);

    a.ptr[0 .. $] = [1,2];
    assert(a == [1,2]);

    s.a.ptr[0 .. $] = [1,2];
    assert(s.a == [1,2]);
}
