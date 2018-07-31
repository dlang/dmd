module three;

void aaa() @nogc
{

}

struct TT(T)
{
    void insertabcdefg(T) // @nogc  <-- deduction problem
    {
        pragma(msg, insertabcdefg.mangleof);
        aaa();
    }
}
