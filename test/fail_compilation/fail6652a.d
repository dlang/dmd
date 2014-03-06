// PERMUTE_ARGS: -w -dw -de -d

/******************************************/
// 6652

/*
TEST_OUTPUT:
---
fail_compilation/fail6652a.d(18): Error: cannot modify const expression i
fail_compilation/fail6652a.d(23): Error: cannot modify const expression i
---
*/

void main()
{
    foreach (const i; 0..2)
    {
        ++i;
    }

    foreach (ref const i; 0..2)
    {
        ++i;
    }
}
