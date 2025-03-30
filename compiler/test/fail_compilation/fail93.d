/*
TEST_OUTPUT:
---
fail_compilation/fail93.d(14): Error: variable `i` is shadowing variable `fail93.main.i`
fail_compilation/fail93.d(13):        declared here
---
*/

// accepts-valid with DMD0.120. volatile as well as synchronized

void main()
{
    int i = 1;
    synchronized int i = 2; // should fail to compile
}
