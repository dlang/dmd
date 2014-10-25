// PERMUTE_ARGS:
// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/fail9368.d(20): Error: enum member b not represented in final switch
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
