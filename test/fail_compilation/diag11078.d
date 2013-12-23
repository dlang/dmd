/*
TEST_OUTPUT:
---
fail_compilation/diag11078.d(17): Error: function diag11078.S1.value () is not callable using argument types (double)
---
*/

struct S1
{
    @property int value() { return 1; }
    @property void value(int n) { }
}

void main()
{
    S1 s1;
    s1.value = 1.0;
}
