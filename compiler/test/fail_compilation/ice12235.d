/*
TEST_OUTPUT:
---
fail_compilation/ice12235.d(20): Error: forward reference to inferred return type of function `__lambda_L18_C5`
        enum s = __traits(parent, x).mangleof;
                                    ^
fail_compilation/ice12235.d(21): Error: forward reference to inferred return type of function `__lambda_L18_C5`
        pragma(msg, __traits(parent, x).mangleof);
                                       ^
fail_compilation/ice12235.d(21):        while evaluating `pragma(msg, __lambda_L18_C5.mangleof)`
        pragma(msg, __traits(parent, x).mangleof);
        ^
---
*/

void main()
{
    (){
        int x;
        enum s = __traits(parent, x).mangleof;
        pragma(msg, __traits(parent, x).mangleof);
    }();
}
