import test10567a;

template TypeTuple(TL...) { alias TL TypeTuple; }

void main()
{
    foreach (BigInt; TypeTuple!(BigInt1, BigInt2, BigInt3))
    {
        auto i = BigInt([100]);
        auto j = BigInt([100]);

        assert(typeid(BigInt).equals(&i, &j) == true);
        assert(typeid(BigInt).compare(&i, &j) == 0);
    }
}
