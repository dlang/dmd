/*
REQUIRED_ARGS: -w
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/warn11613.d(15): Warning: case variables are deprecated, use if-else instead
---
*/

void main()
{
    int x;
    switch(x)
    {
    case x:
    default:
        assert(0);
    }
}
