/*
REQUIRED_ARGS: -requireinit
TEST_OUTPUT:
---
fail_compilation/requireinit.d(30): Error: `tc` was not initialized
fail_compilation/requireinit.d(31): Error: `ts` was not initialized
fail_compilation/requireinit.d(32): Error: `s` was not initialized
fail_compilation/requireinit.d(33): Error: `i` was not initialized
fail_compilation/requireinit.d(34): Error: `a` was not initialized
fail_compilation/requireinit.d(39): Error: `tc` was not initialized
fail_compilation/requireinit.d(40): Error: `ts` was not initialized
fail_compilation/requireinit.d(41): Error: `s` was not initialized
fail_compilation/requireinit.d(42): Error: `i` was not initialized
fail_compilation/requireinit.d(43): Error: `a` was not initialized
fail_compilation/requireinit.d(46): Error: `tc` was not initialized
fail_compilation/requireinit.d(47): Error: `ts` was not initialized
fail_compilation/requireinit.d(48): Error: `s` was not initialized
fail_compilation/requireinit.d(49): Error: `i` was not initialized
fail_compilation/requireinit.d(50): Error: `a` was not initialized
fail_compilation/requireinit.d(54): Error: `ltc` was not initialized
fail_compilation/requireinit.d(55): Error: `lts` was not initialized
fail_compilation/requireinit.d(56): Error: `ls` was not initialized
fail_compilation/requireinit.d(57): Error: `li` was not initialized
fail_compilation/requireinit.d(58): Error: `la` was not initialized
---
*/

class TestClass
{
    TestClass tc;
    TestStruct ts;
    string s;
    int i;
    int[] a;
}

struct TestStruct
{
    TestClass tc;
    TestStruct ts;
    string s;
    int i;
    int[] a;
}

TestClass tc;
TestStruct ts;
string s;
int i;
int[] a;

void main()
{
    TestClass ltc;
    TestStruct lts;
    string ls;
    int li;
    int[] la;
}
