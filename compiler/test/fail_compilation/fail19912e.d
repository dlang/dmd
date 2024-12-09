/*
TEST_OUTPUT:
---
fail_compilation/fail19912e.d(9): Error: function `fail19912e.object` conflicts with import `fail19912e.object` at fail_compilation/fail19912e.d
void object() { }
     ^
---
*/
void object() { }
void fun(string) { }
