/*
TEST_OUTPUT:
---
fail_compilation/ice16035.d(22): Error: forward reference to inferred return type of function call `this.a[0].toString()`
        a[0].toString();
                     ^
fail_compilation/ice16035.d(17): Error: template instance `ice16035.Value.get!string` error instantiating
        get!string;
        ^
---
*/

struct Value
{
    auto toString() inout
    {
        get!string;
    }

    T get(T)()
    {
        a[0].toString();
    }

    const(Value)* a;
}
