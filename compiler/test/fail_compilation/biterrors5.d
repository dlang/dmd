/* REQUIRED_ARGS: -preview=bitfields
 * TEST_OUTPUT:
---
fail_compilation/biterrors5.d(27): Error: bitfield symbol expected not struct `biterrors5.S`
    i = __traits(getBitfieldOffset, S);
        ^
fail_compilation/biterrors5.d(28): Error: bitfield symbol expected not variable `biterrors5.test0.i`
    i = __traits(getBitfieldOffset, i);
        ^
---
*/

struct S
{
    int a,b;
    int :2, c:3;
}

static assert(__traits(getBitfieldOffset, S.b) == 0);
static assert(__traits(getBitfieldWidth, S.b) == 32);
static assert(__traits(getBitfieldOffset, S.c) == 2);
static assert(__traits(getBitfieldWidth, S.c) == 3);

void test0()
{
    int i;
    i = __traits(getBitfieldOffset, S);
    i = __traits(getBitfieldOffset, i);
}
