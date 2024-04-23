/*
REQUIRED_ARGS: -cpp=
TEST_OUTPUT:
---
fail_compilation/attrpure.i(13): Error: `pure` function `attrpure.pureAsSnow` cannot call impure function `attrpure.impure`
---
*/

void impure();

__attribute__((pure)) void pureAsSnow()
{
    impure();
}
