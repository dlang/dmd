// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/spell9644.d(21): Error: undefined identifier b
fail_compilation/spell9644.d(22): Error: undefined identifier xx
fail_compilation/spell9644.d(23): Error: undefined identifier cb, did you mean variable ab?
fail_compilation/spell9644.d(24): Error: undefined identifier bc, did you mean variable abc?
fail_compilation/spell9644.d(25): Error: undefined identifier ccc, did you mean variable abc?
---
*/

int a;
int ab;
int abc;

int main()
{
    cast(void)b; // max distance 0, no match
    cast(void)xx; // max distance 1, no match
    cast(void)cb; // max distance 1, match
    cast(void)bc; // max distance 1, match
    cast(void)ccc; // max distance 2, match
}
