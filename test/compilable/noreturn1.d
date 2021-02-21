/*
TEST_OUTPUT:
---
noreturn
---
*/

alias noreturn = typeof(*null);
pragma(msg, noreturn);

noreturn exits(int* p) { *p = 3; }
