/*
TEST_OUTPUT:
---
fail_compilation/cppvar.d(10): Error: delegate `cppvar.__lambda3` cannot return type `bool[3]` because its linkage is `extern(C++)`
---
*/
#line 10
extern(C++) bool[3] funcLiteral = () { bool[3] a; return a; };
