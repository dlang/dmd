/*
TEST_OUTPUT:
---
fail_compilation/ice12235.d(14): Error: forward reference to inferred return type of function `() { int x = 0; enum s = __lambda_L12_C5.mangleof; pragma (msg, __traits(pare...`
fail_compilation/ice12235.d(15): Error: forward reference to inferred return type of function `() { int x = 0; enum _error_ s = __error__; pragma (msg, __lambda_L12_C5.mang...`
fail_compilation/ice12235.d(15):        while evaluating `pragma(msg, __lambda_L12_C5.mangleof)`
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
