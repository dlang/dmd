/* REQUIRED_ARGS: -vtemplates
TEST_OUTPUT:
---
  Number   Unique   Name
       4        3   foo(int I)()
---
*/

void foo(int I)() { }

void test()
{
    foo!(1)();
    foo!(1)();
    foo!(2)();
    foo!(3)();
}
