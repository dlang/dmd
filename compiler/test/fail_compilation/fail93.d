/*
TEST_OUTPUT:
---
fail_compilation/fail93.d(18): Error: variable `i` is shadowing variable `fail93.main.i`
    synchronized int i = 2; // should fail to compile
                 ^
fail_compilation/fail93.d(17):        declared here
    int i = 1;
        ^
---
*/

// accepts-valid with DMD0.120. volatile as well as synchronized

void main()
{
    int i = 1;
    synchronized int i = 2; // should fail to compile
}
