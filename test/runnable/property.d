
struct Foo
{
    int v;

    int bar(int value) { return v = value + 2; }
    int bar() { return 73; }
}

int main()
{
    Foo f;
    int i;

    i = (f.bar = 6);
    assert(i == 8);
    assert(f.v == 8);

    i = f.bar;
    assert(i == 73);

    return 0;
}

