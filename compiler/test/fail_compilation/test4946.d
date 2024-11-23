/* TEST_OUTPUT:
---
fail_compilation/test4946.d(27): Error: 'pure' cannot be placed after a template constraint
void bar1(int x)() if (x > 0) pure { int a;}
                              ^
fail_compilation/test4946.d(28): Error: 'const' cannot be placed after a template constraint
void bar2(int x)() if (x > 0) const { int a;}
                              ^
fail_compilation/test4946.d(29): Error: 'immutable' cannot be placed after a template constraint
void bar3(int x)() if (x > 0) immutable { int a;}
                              ^
fail_compilation/test4946.d(30): Error: 'inout' cannot be placed after a template constraint
void bar4(int x)() if (x > 0) inout { int a;}
                              ^
fail_compilation/test4946.d(31): Error: 'shared' cannot be placed after a template constraint
void bar5(int x)() if (x > 0) shared { int a;}
                              ^
fail_compilation/test4946.d(32): Error: 'nothrow' cannot be placed after a template constraint
void bar6(int x)() if (x > 0) nothrow { int a;}
                              ^
fail_compilation/test4946.d(33): Error: attributes cannot be placed after a template constraint
void bar7(int x)() if (x > 0) @safe { int a;}
                              ^
---
*/

void bar1(int x)() if (x > 0) pure { int a;}
void bar2(int x)() if (x > 0) const { int a;}
void bar3(int x)() if (x > 0) immutable { int a;}
void bar4(int x)() if (x > 0) inout { int a;}
void bar5(int x)() if (x > 0) shared { int a;}
void bar6(int x)() if (x > 0) nothrow { int a;}
void bar7(int x)() if (x > 0) @safe { int a;}
