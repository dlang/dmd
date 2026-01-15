/* REQUIRED_ARGS: -verrors=context
 * TEST_OUTPUT:
---
fail_compilation/biterrors2.d(100): Error: variable `biterrors2.a` - bitfield must be member of struct, union, or class
int a : 2;
    ^
fail_compilation/biterrors2.d(104): Error: bitfield `b` has zero width
    int b:0;
          ^
fail_compilation/biterrors2.d(105): Error: bitfield type `float` is not an integer type
    float c:3;
          ^
---
*/

#line 100
int a : 2;

struct S
{
    int b:0;
    float c:3;
}
