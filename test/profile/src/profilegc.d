import core.runtime;

void main(string[] args)
{
    profilegc_setlogfilename(args[1]);

    struct S { ~this() { } }
    class C { }
    interface I { }

    {
        auto a = new C();
        auto b = new int;
        auto c = new int[3];
        auto d = new int[][](3,4);
        auto e = new float;
        auto f = new float[3];
        auto g = new float[][](3,4);
    }

    {
        int[] a = [1, 2, 3];
        string[int] aa = [1:"one", 2:"two", 3:"three"];
    }

    {
        int[] a, b, c;
        c = a ~ b;
        c = a ~ b ~ c;
    }

    {
        dchar dc = 'a';
        char[] ac; ac ~= dc;
        wchar[] aw; aw ~= dc;
        char[] ac2; ac2 ~= ac;
        int[] ai; ai ~= 3;
    }

    {
        int[] ai; ai.length = 10;
        float[] af; af.length = 10;
    }

    auto foo ( )
    {
        int v = 42;
        return { return v; };
    }

    auto x = foo()();
}
