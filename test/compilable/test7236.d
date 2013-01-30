// PERMUTE_ARGS:
import imports.test7236a;

class C2 : C1
{
    void m(C1 c1, C2 c2)
    {
        c1.pm();   // ok
        c1.pf = 1; // ok
        c2.pm();   // ok
        c2.pf = 1; // ok
    }

    static void sm(C1 c1, C2 c2)
    {
        c1.pm();   // ok
        c1.pf = 1; // ok
        c2.pm();   // ok
        c2.pf = 1; // ok
    }
}

class NC1
{
    void m(C2 c2)
    {
        c2.pm();   // ok -> NC1 has protected access if in same module
        c2.pf = 1; // ditto
    }

    static void sm(C2 c2)
    {
        c2.pm();   // ditto
        c2.pf = 1; // ditto
    }
}
