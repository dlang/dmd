/* REQUIRED_ARGS: -verrors=context
 * TEST_OUTPUT:
---
fail_compilation/biterrors7.d(14): Error: struct `biterrors7.S` cannot have anonymous field with same struct type
    S : S();
    ^
fail_compilation/biterrors7.d(14): Error: anonymous bitfield cannot be of non-integral type `S`
    S : S();
    ^
---
*/
struct S
{
    S : S();
}
