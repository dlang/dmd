/*
TEST_OUTPUT:
---
fail_compilation/diag6699.d(19): Error: no property `x` for type `int`
alias b6699.x b6699a;
      ^
fail_compilation/diag6699.d(21): Error: undefined identifier `junk1`
class X : junk1, junk2 {}
^
fail_compilation/diag6699.d(21): Error: undefined identifier `junk2`
class X : junk1, junk2 {}
^
fail_compilation/diag6699.d(22): Error: undefined identifier `junk3`
interface X2 : junk3 {}
^
---
*/
alias int b6699;
alias b6699.x b6699a;

class X : junk1, junk2 {}
interface X2 : junk3 {}
