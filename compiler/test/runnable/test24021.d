// https://github.com/dlang/dmd/issues/24021
// Array `==` calls the element type's `opEquals` in CTFE, as it does at runtime

struct S
{
    int x;
    bool opEquals(S) const { return true; }
}

class C
{
    int x;
    this(int x) { this.x = x; }
    override bool opEquals(Object o) const { return (cast(C) o).x % 10 == x % 10; }
}

bool test()
{
    assert([S(1)] == [S(2)]);
    assert(!([S(1)] != [S(2)]));
    assert([S(1)] != [S(2), S(3)]);

    S[] a = [S(1), S(2)];
    S[] b = [S(3), S(4)];
    assert(a == b);
    assert(a[0 .. 1] == b[1 .. 2]);

    S[2] sa = [S(1), S(2)];
    assert(sa == b);

    assert([[S(1)]] == [[S(2)]]);

    assert([new C(1)] == [new C(11)]);
    assert([new C(1)] != [new C(2)]);
    return true;
}

static assert(test());

void main()
{
    assert(test());
}
