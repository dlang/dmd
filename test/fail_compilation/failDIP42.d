/*
TEST_OUTPUT:
---
fail_compilation/failDIP42.d(9): Error: eponymous template syntax with variables is allowed only for enums
fail_compilation/failDIP42.d(10): Error: eponymous template syntax with variables is allowed only for enums
---
*/

string v1(T) = T.stringof;
static v2(T) = T.stringof;
