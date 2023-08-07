/*
TEST_OUTPUT:
---
fail_compilation/switch_skip.d(13): Error: `switch` skips declaration of variable `switch_skip.test3.j`
fail_compilation/switch_skip.d(17):        declared here
fail_compilation/switch_skip.d(30): Error: `switch` skips declaration of variable `switch_skip.test.z`
fail_compilation/switch_skip.d(32):        declared here
---
*/

void test3(int i)
{
    switch (i)
    {
        case 1:
        {
            int j;
        case 2:
            ++j;
            break;
        }
        default:
            break;
    }
}

// https://issues.dlang.org/show_bug.cgi?id=18858
int test(int n)
{
    final switch(n)
    {
        int z = 5;
        enum e = 6;

        case 1:
            int y = 2;
            return y;
    }
}
