/*
TEST_OUTPUT:
---
fail_compilation/test6883.d(23): Error: array index 5 is out of bounds `x[0 .. 5]`
        x[x.length] = 1;
        ^
fail_compilation/test6883.d(25): Error: array index 7 is out of bounds `x[0 .. 5]`
        x[x.length + n] = 2;
        ^
fail_compilation/test6883.d(29): Error: array index 5 is out of bounds `x[0 .. 5]`
        x[$] = 1;
        ^
fail_compilation/test6883.d(31): Error: array index 7 is out of bounds `x[0 .. 5]`
        x[$ + n] = 2;
        ^
---
*/

void main()
{
    {
        int[5] x;
        x[x.length] = 1;
        enum size_t n = 2;
        x[x.length + n] = 2;
    }
    {
        int[5] x;
        x[$] = 1;
        enum size_t n = 2;
        x[$ + n] = 2;
    }
}
