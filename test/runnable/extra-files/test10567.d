import test10567a;

void main()
{
    auto i = BigInt([100]);
    auto j = BigInt([100]);

    assert(typeid(BigInt).compare(&i, &j) == 0);
}
