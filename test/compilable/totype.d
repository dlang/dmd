/* TEST_OUTPUT:
---
i int
d double
Pi int*
---
*/

pragma(msg, 1.mangleof, " ", __totype(1.mangleof));
pragma(msg, (1.0).mangleof, " ", __totype((1.0).mangleof));
pragma(msg, (int*).mangleof, " ", __totype((int*).mangleof));

static assert(is(__totype(1.mangleof) == int));
static assert(is(__totype((1.0).mangleof) == double));
static assert(is(__totype((int*).mangleof) == int*));


