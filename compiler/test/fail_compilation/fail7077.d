/*
TEST_OUTPUT:
---
fail_compilation/fail7077.d(13): Error: undefined identifier `x`
    assert(x == 2);
           ^
---
*/

void main()
{
    if(0) mixin("auto x = 2;");
    assert(x == 2);
}
