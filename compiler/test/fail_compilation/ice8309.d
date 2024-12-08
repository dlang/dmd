/*
TEST_OUTPUT:
---
fail_compilation/ice8309.d(12): Error: incompatible types for `(__lambda_L12_C15) : (__lambda_L12_C24)`: `double function() pure nothrow @nogc @safe` and `int function() pure nothrow @nogc @safe`
    auto x = [()=>1.0, ()=>1];
                       ^
---
*/

void main()
{
    auto x = [()=>1.0, ()=>1];
}
