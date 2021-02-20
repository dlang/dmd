/*
TEST_OUTPUT:
---
noreturn
---
*/

alias noreturn = typeof(*null);
pragma(msg, noreturn);
