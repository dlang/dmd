// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/diag9277.d(20): Error: cannot cast v of type int to type diag9277.main.Int
fail_compilation/diag9277.d(22): Error: cannot cast v of type int to type diag9277.main.Int
---
*/

void main()
{
    class Int
    {
        int _val;
        this(int val){ _val = val; }
    }
    Int[] sink;

    foreach(v; 0..5_000)
        sink ~= [cast(Int)v]; //12
    foreach(v; 0..5_000)
        sink ~= cast(Int)v; //14
}
