struct F
{
    alias thisTup = typeof(this).tupleof;

    int a,b,c,d;

    void test()
    {
        static foreach (i; 0 .. 4)
            thisTup[i] = i + 1;
        assert(a == 1);
        assert(b == 2);
        assert(c == 3);
        assert(d == 4);
    }
}

void main()
{
    F().test();
}
