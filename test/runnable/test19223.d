version (D_SIMD)
{
    import core.simd;

    int fn(const int[4] x)
    {
        int sum = 0;
        foreach (i; x) sum += i;
        return sum;
    }

    // https://issues.dlang.org/show_bug.cgi?id=19223
    void test19223()
    {
        int4 v1 = int4.init;
        assert(fn(v1.array) == 0);
        assert(fn(int4.init.array) == 0);
    }

    void main ()
    {
        test19223();
    }
}
else
{
    void main() { }
}
