/*
TEST_OUTPUT:
---
fail_compilation/ice10624.d(44): Error: need member function `opCmp()` for struct `Tuple!(Msg)` to compare
            return *zis < *rhsPA ? -1 : 1;
                   ^
fail_compilation/ice10624.d(54): Error: template instance `ice10624.Variant.handler!(Tuple!(Msg))` error instantiating
        fptr = &handler!(T);
                ^
fail_compilation/ice10624.d(27):        instantiated from here: `opAssign!(Tuple!(Msg))`
    data = Tuple!Msg();
         ^
---
*/

struct Msg {}

struct Tuple(Specs...)
{
    Specs expand;
    alias expand this;
}

void main()
{
    Variant data;
    data = Tuple!Msg();

}

struct Variant
{
    ptrdiff_t function() fptr = &handler!(void);

    static ptrdiff_t handler(A : void)()
    {
        return 0;
    }
    static ptrdiff_t handler(A)()
    {
        A* zis;
        A* rhsPA;
        {
            return *zis < *rhsPA ? -1 : 1;
            // Tuple!(Msg) < Tuple!(Msg)
            // Tuple!(Msg).expand < Tuple!(Msg).expand
            // -> should be error
        }
        return 0;
    }

    Variant opAssign(T)(T rhs)
    {
        fptr = &handler!(T);
        return this;
    }
}
