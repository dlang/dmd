/* TEST_OUTPUT:
---
fail_compilation/dip1027.d(103): Error: istring ended prematurely
fail_compilation/dip1027.d(104): Error: identifier expected after $
---
*/

#line 100

void test()
{
    auto t = i"$";
    auto u = i"$7";
}
