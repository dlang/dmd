/*
TEST_OUTPUT:
---
fail_compilation/uda_rvalueref1.d(11): Error: `@rvalue_ref` cannot apply to auto ref parameters
fail_compilation/uda_rvalueref1.d(15): Error: template instance `uda_rvalueref1.h!()` error instantiating
---
*/

struct rvalue_ref {}

extern(C++) void h()(@rvalue_ref auto ref int i);

void test()
{
    h(1);
    int i;
    h(i);
}
