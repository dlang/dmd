/*
TEST_OUTPUT:
---
fail_compilation/diag3673.d(9): Error: members expected
---
*/

class A {}
class B(T) if(false) : A if (true) { }
