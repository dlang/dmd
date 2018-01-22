/*
TEST_OUTPUT:
---
fail_compilation/fail97.d(11): Error: pragma lib is missing a terminating `;`
---
*/

// 151

import std.stdio;
pragma(lib,"ws2_32.lib")//;
class bla{}
void main(){}
