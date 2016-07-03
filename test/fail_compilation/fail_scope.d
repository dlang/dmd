/*
TEST_OUTPUT:
---
fail_compilation/fail_scope.d(15): Error: scope variable da may not be returned
fail_compilation/fail_scope.d(17): Error: scope variable o may not be returned
fail_compilation/fail_scope.d(18): Error: scope variable dg may not be returned
fail_compilation/fail_scope.d(20): Error: scope variable da may not be returned
fail_compilation/fail_scope.d(22): Error: scope variable o may not be returned
fail_compilation/fail_scope.d(23): Error: scope variable dg may not be returned
---
*/

alias int delegate() dg_t;

int[]  checkEscapeScope1(scope int[]  da) { return da; }
int[3] checkEscapeScope2(scope int[3] sa) { return sa; }
Object checkEscapeScope3(scope Object o)  { return o;  }
dg_t   checkEscapeScope4(scope dg_t   dg) { return dg; }

int[]  checkEscapeScope1() { scope int[]  da = [];           return da; }
int[3] checkEscapeScope2() { scope int[3] sa = [1,2,3];      return sa; }
Object checkEscapeScope3() { scope Object  o = new Object;   return o;  }   // same with fail7294.d
dg_t   checkEscapeScope4() { scope dg_t   dg = () => 1;      return dg; }
