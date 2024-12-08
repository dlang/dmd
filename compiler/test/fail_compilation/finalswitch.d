/*
TEST_OUTPUT:
---
fail_compilation/finalswitch.d(47): Error: missing cases for `enum` members in `final switch`:
    final switch(e)
    ^
fail_compilation/finalswitch.d(47):        `B`
fail_compilation/finalswitch.d(65): Error: missing cases for `enum` members in `final switch`:
    final switch (f)
    ^
fail_compilation/finalswitch.d(65):        `b`
fail_compilation/finalswitch.d(79): Error: missing cases for `enum` members in `final switch`:
    final switch (e)
    ^
fail_compilation/finalswitch.d(79):        `B`
fail_compilation/finalswitch.d(97): Error: missing cases for `enum` members in `final switch`:
    final switch (H.init)
    ^
fail_compilation/finalswitch.d(97):        `m3`
fail_compilation/finalswitch.d(97):        `m4`
fail_compilation/finalswitch.d(97):        `m5`
fail_compilation/finalswitch.d(97):        `m6`
fail_compilation/finalswitch.d(97):        `m7`
fail_compilation/finalswitch.d(97):        `m9`
fail_compilation/finalswitch.d(102): Error: missing cases for `enum` members in `final switch`:
    final switch (H.init)
    ^
fail_compilation/finalswitch.d(102):        `m1`
fail_compilation/finalswitch.d(102):        `m2`
fail_compilation/finalswitch.d(102):        `m3`
fail_compilation/finalswitch.d(102):        `m4`
fail_compilation/finalswitch.d(102):        `m5`
fail_compilation/finalswitch.d(102):        `m6`
fail_compilation/finalswitch.d(102):        ... (4 more, -v to show) ...
---
*/

// https://issues.dlang.org/show_bug.cgi?id=4517
enum E : ushort
{
    A, B
}

void test4517()
{
    E e;
    final switch(e)
    {
        case E.A:
            break;
    }
}

// https://issues.dlang.org/show_bug.cgi?id=9368
enum E1
{
    a,
    b
}

void test9368()
{
    alias E1 F;
    F f;
    final switch (f)
    {
        case F.a:
    }
}

enum G
{
    A,B,C
}

void test286()
{
    G e;
    final switch (e)
    {
        case G.A:
//      case G.B:
        case G.C:
            {}
    }
}

// https://issues.dlang.org/show_bug.cgi?id=22038

enum H {
    m1, m2, m3, m4, m5,
    m6, m7, m8, m9, m10,
}

void test22038()
{
    final switch (H.init)
    {
        case H.m1, H.m2, H.m8, H.m10: break;
    }

    final switch (H.init)
    {

    }
}
