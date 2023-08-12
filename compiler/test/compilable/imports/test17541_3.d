module three;

void aaa() pure @safe @nogc nothrow
{

}

struct TT(T)
{
    void insertabcdefg(T) // @nogc  <-- deduction problem
    {
        //static assert(insertabcdefg.mangleof == "_D5three__T2TTTiZQg13insertabcdefgMFiZv");
        aaa();
    }
}
