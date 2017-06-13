/*
REQUIRED_ARGS: -Ifail_compilation/extra-files
TEST_OUTPUT:
---
fail_compilation/extra-files/imp17489.d(2): Error: basic type expected, not )
---
*/

void trigger()
{
    import imp17489;
}
