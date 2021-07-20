module three;

void aaa() @nogc pure @safe
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
