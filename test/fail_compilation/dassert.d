/*
REQUIRED_ARGS: -checkaction=context
TEST_OUTPUT:
---
fail_compilation/dassert.d(11): Error: expression `tuple(0, 0)` of type `(int, int)` does not have a boolean value
---
*/
struct Baguette { int bread, floor; }
void main ()
{
    assert(Baguette.init.tupleof);
}
