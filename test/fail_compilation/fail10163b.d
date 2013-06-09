/*
TEST_OUTPUT:
---
fail_compilation/fail10163b.d(9): Error: field v must be initialized in constructor
fail_compilation/fail10163b.d(10): Error: field v must be initialized in constructor
---
*/

class C { void[1] v; }
class D { void[1] v; int i; }
