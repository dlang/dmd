/*
TEST_OUTPUT:
---
fail_compilation/diag12312.d(14): Error: variable `diag12312.main.arr` of type `void[16]` does not have a default initializer
    void[16] arr;
             ^
fail_compilation/diag12312.d(19): Error: variable `diag12312.bug1176.v` of type `void[1]` does not have a default initializer
    void[1] v;
            ^
---
*/
void main()
{
    void[16] arr;
}

void bug1176()
{
    void[1] v;
}
