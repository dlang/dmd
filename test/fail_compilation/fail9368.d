// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/fail9368.d(19): Error: `enum` member `b` not represented in `final switch`
---
*/

enum E
{
    a,
    b
}

void main()
{
    alias E F;
    F f;
    final switch (f)
    {
        case F.a:
    }
}

/*
TEST_OUTPUT:
---
fail_compilation/fail9368.d(40): Error: `enum` member `B` not represented in `final switch`
---
*/

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

