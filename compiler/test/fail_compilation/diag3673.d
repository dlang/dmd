/*
TEST_OUTPUT:
---
fail_compilation/diag3673.d(11): Error: template constraints appear both before and after BaseClassList, put them before
class B(T) if(false) : A if (true) { }
                         ^
---
*/

class A {}
class B(T) if(false) : A if (true) { }
