// REQUIRED_ARGS: -w

/******************************************/
// 6652

/*
TEST_OUTPUT:
---
fail_compilation/fail6652a.d(19): Warning: variable modified in foreach body requires ref storage class
fail_compilation/fail6652a.d(24): Error: cannot modify const expression i
---
*/

void main()
{
    size_t[] res;
    foreach (i; 0..2)
    {
        res ~= ++i;
    }

    foreach (const i; 0..2)
    {
        ++i;
    }
}
