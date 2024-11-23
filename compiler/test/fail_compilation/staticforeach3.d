/*
TEST_OUTPUT:
---
fail_compilation/staticforeach3.d(9): Error: variable `staticforeach3.__anonymous.i` conflicts with variable `staticforeach3.__anonymous.i` at fail_compilation/staticforeach3.d(9)
static foreach(i,i;[0]){}
^
---
*/
static foreach(i,i;[0]){}
