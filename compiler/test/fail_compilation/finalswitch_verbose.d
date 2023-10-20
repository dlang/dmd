/*
REQUIRED_ARGS: -v
TRANSFORM_OUTPUT: remove_lines("^(predefs|binary|version|config|DFLAG|parse|import|semantic|entry|\s*$)")
TEST_OUTPUT:
---
fail_compilation/finalswitch_verbose.d(40): Error: missing cases for `enum` members in `final switch`:
fail_compilation/finalswitch_verbose.d(40):        `m1`
fail_compilation/finalswitch_verbose.d(40):        `m2`
fail_compilation/finalswitch_verbose.d(40):        `m3`
fail_compilation/finalswitch_verbose.d(40):        `m4`
fail_compilation/finalswitch_verbose.d(40):        `m5`
fail_compilation/finalswitch_verbose.d(40):        `m6`
fail_compilation/finalswitch_verbose.d(40):        `m7`
fail_compilation/finalswitch_verbose.d(40):        `m8`
fail_compilation/finalswitch_verbose.d(40):        `m9`
fail_compilation/finalswitch_verbose.d(40):        `m10`
fail_compilation/finalswitch_verbose.d(40):        `m11`
fail_compilation/finalswitch_verbose.d(40):        `m12`
fail_compilation/finalswitch_verbose.d(40):        `m13`
fail_compilation/finalswitch_verbose.d(40):        `m14`
fail_compilation/finalswitch_verbose.d(40):        `m15`
fail_compilation/finalswitch_verbose.d(40):        `m16`
fail_compilation/finalswitch_verbose.d(40):        `m17`
fail_compilation/finalswitch_verbose.d(40):        `m18`
fail_compilation/finalswitch_verbose.d(40):        `m19`
fail_compilation/finalswitch_verbose.d(40):        `m20`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22038
enum H {
    m1, m2, m3, m4, m5,
    m6, m7, m8, m9, m10,
    m11, m12, m13, m14, m15,
    m16, m17, m18, m19, m20
}

void test22038()
{
    final switch (H.init)
    {

    }
}
