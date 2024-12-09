// https://issues.dlang.org/show_bug.cgi?id=10283
/*
TEST_OUTPUT:
---
fail_compilation/ice10283.d(16): Error: cannot implicitly convert expression `7` of type `int` to `string`
    string source = 7;
                    ^
---
*/

S10283 blah(S10283 xxx) { return xxx; }
S10283 repy = blah(S10283());

struct S10283
{
    string source = 7;
}
