/*
TEST_OUTPUT:
---
fail_compilation/fail6458.d(12): Error: cannot implicitly convert expression `'\ufffd'` of type `wchar` to `char`
    char d = '�';
             ^
---
*/

void main()
{
    char d = '�';
}
