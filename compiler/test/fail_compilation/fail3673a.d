/*
TEST_OUTPUT:
---
fail_compilation/fail3673a.d(10): Error: template constraints only allowed for templates
class B : A if(false) { }
                      ^
---
*/
class A {}
class B : A if(false) { }
