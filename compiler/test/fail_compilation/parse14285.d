/*
TEST_OUTPUT:
---
fail_compilation/parse14285.d(10): Error: basic type expected, not `this`, did you mean `typeof(this)`?
---
*/

struct S
{
    alias this;
}
