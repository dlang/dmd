// PERMUTE_ARGS:

void fun() {}

void main()
{
    auto a = &fun;
    const b = a;
    assert(a == a);
    assert(a == b);
    assert(b == b);
    immutable c = cast(immutable)&fun;
    assert(a == c);
    assert(b == c);
    assert(c == c);
}
