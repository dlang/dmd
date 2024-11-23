/*
TEST_OUTPUT:
---
fail_compilation/fail19915.d(12): Error: undefined identifier `c` in module `fail19915`
class a (b) { align.c d; }
                      ^
fail_compilation/fail19915.d(13): Error: template instance `fail19915.a!int` error instantiating
alias a!(int) e;
      ^
---
*/
class a (b) { align.c d; }
alias a!(int) e;
