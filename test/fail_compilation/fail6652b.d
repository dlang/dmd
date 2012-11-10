// REQUIRED_ARGS: -w

/******************************************/
// 6652

/*
TEST_OUTPUT:
---
fail_compilation/fail6652b.d(19): Warning: variable modified in foreach body requires ref storage class
fail_compilation/fail6652b.d(24): Error: cannot modify const expression i
---
*/

void main()
{
    size_t[] res;
    foreach (i, e; [1,2,3,4,5])
    {
        res ~= ++i;
    }

    foreach (const i, e; [1,2,3,4,5])
    {
        ++i;
    }
}
