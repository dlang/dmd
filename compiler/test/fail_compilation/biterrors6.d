/* REQUIRED_ARGS: -verrors=context
 * TEST_OUTPUT:
---
fail_compilation/biterrors6.d(20): Error: anonymous bitfield cannot be of non-integral type `noreturn`
    noreturn : -1;
    ^
fail_compilation/biterrors6.d(21): Error: anonymous bitfield has negative width `-1`
    int : -1;
           ^
fail_compilation/biterrors6.d(22): Error: bitfield `n` cannot be of non-integral type `noreturn`
    noreturn n : -500;
             ^
fail_compilation/biterrors6.d(23): Error: bitfield `i` has negative width `-500`
    int i : -500;
             ^
---
*/
struct S
{
    noreturn : -1;
    int : -1;
    noreturn n : -500;
    int i : -500;
}
