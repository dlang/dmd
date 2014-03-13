// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
compilable/test70.d(14): Deprecation: implicit overload merging with selective/renamed import is now removed.
---
*/
import imports.test70 : foo;
void foo(int) {}
// selective import does not create local alias implicitly

void bar()
{
    foo();
    foo(1);
}
