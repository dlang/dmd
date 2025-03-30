/* REQUIRED_ARGS: -preview=bitfields
 * TEST_OUTPUT:
---
fail_compilation/biterrors3.d(103): Error: storage class not allowed for bit-field declaration
fail_compilation/biterrors3.d(106): Error: expected `,` or `=` after identifier, not `:`
fail_compilation/biterrors3.d(106): Error: found `:` when expecting `,`
fail_compilation/biterrors3.d(106): Error: found `3` when expecting `identifier`
---
*/

#line 100

struct S
{
    static int : 3;
}

enum E { d : 3 }
