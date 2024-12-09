/*
TEST_OUTPUT:
---
fail_compilation/fail9279.d(14): Error: escaping reference to stack allocated value returned by `b()`
string a() { return b(); }
                     ^
fail_compilation/fail9279.d(17): Error: escaping reference to stack allocated value returned by `getArr()`
string getString() { return getArr(); }
                                  ^
---
*/

char[2] b()() { char[2] ret; return ret; }
string a() { return b(); }

char[12] getArr() { return "Hello World!"; }
string getString() { return getArr(); }
