/* TEST_OUTPUT:
---
fail_compilation/bb14964.d(7): Error: argument is not an identifier
fail_compilation/bb14964.d(8): Error: expected 1 arguments for isAlias but had 2
---
*/
static assert( __traits(isAlias, int));
static assert( __traits(isAlias, a, b));
