/*
REQUIRED_ARGS: -requireinit
TEST_OUTPUT:
---
fail_compilation/requireinit.d(21): Error: `tc` was not iniitialized
fail_compilation/requireinit.d(22): Error: `ts` was not iniitialized
fail_compilation/requireinit.d(23): Error: `s` was not iniitialized
fail_compilation/requireinit.d(24): Error: `i` was not iniitialized
fail_compilation/requireinit.d(25): Error: `a` was not iniitialized
fail_compilation/requireinit.d(29): Error: `ltc` was not iniitialized
fail_compilation/requireinit.d(30): Error: `lts` was not iniitialized
fail_compilation/requireinit.d(31): Error: `ls` was not iniitialized
fail_compilation/requireinit.d(32): Error: `li` was not iniitialized
fail_compilation/requireinit.d(33): Error: `la` was not iniitialized
---
*/

class TestClass {}
struct TestStruct {}

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
