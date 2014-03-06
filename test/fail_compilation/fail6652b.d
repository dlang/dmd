// PERMUTE_ARGS: -w -dw -de -d

/******************************************/
// 6652

/*
TEST_OUTPUT:
---
fail_compilation/fail6652b.d(18): Error: cannot modify const expression i
fail_compilation/fail6652b.d(23): Error: cannot modify const expression i
---
*/

void main()
{
    foreach (const i, e; [1,2,3,4,5])
    {
        ++i;
    }

    foreach (ref const i, e; [1,2,3,4,5])
    {
        ++i;
    }
}
