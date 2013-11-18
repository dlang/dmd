/*
TEST_OUTPUT:
---
fail_compilation/fail8059.d(10): Deprecation: .classinfo deprecated, use typeid(type)
---
*/

void main()
{
    auto x = Object.classinfo;
}
