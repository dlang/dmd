/*
TEST_OUTPUT:
---
fail_compilation/diag9247.d(15): Error: functions cannot return opaque type `S` by value
S foo();
  ^
fail_compilation/diag9247.d(16): Error: functions cannot return opaque type `S` by value
S function() bar;
             ^
---
*/

struct S;

S foo();
S function() bar;
