/*
TEST_OUTPUT:
---
fail_compilation/fail19914.d(12): Error: undefined identifier `c` in module `fail19914`
class a(b) { align.c d; }
                     ^
fail_compilation/fail19914.d(13): Error: mixin `fail19914.a!string` error instantiating
mixin a!(string);
^
---
*/
class a(b) { align.c d; }
mixin a!(string);
