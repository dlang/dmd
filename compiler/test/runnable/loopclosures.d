// REQUIRED_ARGS: -unittest -main

unittest
{
    void delegate()[] funcs;
    int[] results;
    foreach (i; 0..3)
    {
        (){
            int j = i;
            void f()
            {
                results ~= j;
            }
            funcs ~= &f;
        }();
    }
    foreach (dg; funcs)
        dg();
    assert(results == [0, 1, 2]);
}

int[] delegate() test()
{
    void delegate()[] funcs;
    int[] results;
    foreach (i; 0..3)
    {
        void f()
        {
            results ~= i;
        }
        f();
    }
    assert(results == [0, 1, 2]);
    return { return results; };
}
unittest
{
    auto dg = test();
    assert(dg() == [0, 1, 2]);
}

unittest
{
    int[] results;
    foreach (i; 0..3)
    {
        static if (is(typeof(() @safe
        {
            results ~= i;
        })))
        {
            (){
                results ~= i;
            }();
        }
    }
    assert(results == [0, 1, 2]);
}
