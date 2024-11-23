/*
TEST_OUTPUT:
---
fail_compilation/diag11078.d(25): Error: none of the overloads of `value` are callable using argument types `(double)`
    s1.value = 1.0;
    ^
fail_compilation/diag11078.d(18):        Candidates are: `diag11078.S1.value()`
    @property int value() { return 1; }
                  ^
fail_compilation/diag11078.d(19):                        `diag11078.S1.value(int n)`
    @property void value(int n) { }
                   ^
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
