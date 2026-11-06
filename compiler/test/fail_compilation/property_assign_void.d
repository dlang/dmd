/*
TEST_OUTPUT:
---
fail_compilation/property_assign_void.d(13): Error: cannot use result of property assignment `prop = 6`, `prop` returns `void`
---
*/

@property
void prop(int x) {}

void main()
{
    int a = prop = 6;
}
