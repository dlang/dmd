struct S7426
{
    static struct InnerS
    {
        int x;
        alias typeof(InnerS.tupleof) T;
        static assert(is(T[0] == int));
    }

    static class InnerC
    {
        double y;
        alias typeof(InnerC.tupleof) T;
    }
}

class C7426
{
    static struct InnerT
    {
        int x;
        alias typeof(InnerT.tupleof) T;
    }

    static class InnerD
    {
        double y;
        alias typeof(InnerD.tupleof) T;
        static assert(is(T[0] == double));
    }
}

