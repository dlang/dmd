/*
TEST_OUTPUT:
---
fail_compilation/fail97.d(13): Error: pragma `lib` is missing a terminating `;`
pragma(lib,"ws2_32.lib")//;
^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=151

import core.stdc.stdio;
pragma(lib,"ws2_32.lib")//;
class bla{}
void main(){}
