/*
TEST_OUTPUT:
---
fail_compilation/fail160.d(22): Error: no property 'vtbl' for type 'object.TypeInfo_Interface'
---
*/

interface Foo
{
    void work();
}
template Wrapper(B, alias Func, int func)
{
    alias typeof(&Func) FuncPtr;

    private static FuncPtr get_funcptr() { return func; }
} 


int main(char[][] args)
{
    auto x = new Wrapper!(Foo, Foo.work, cast(int)(typeid(Foo).vtbl[0]))();

    return 0;
}

