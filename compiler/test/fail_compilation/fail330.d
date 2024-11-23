/*
TEST_OUTPUT:
---
fail_compilation/fail330.d(11): Error: variable `fail330.fun.result` cannot modify result `result` in contract
out(result) { result = 2; }
              ^
---
*/

int fun()
out(result) { result = 2; }
do { return 1; }
