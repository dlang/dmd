/*
TEST_OUTPUT:
---
fail_compilation/goto2.d(1007): Error: cannot `goto` into `try` block
fail_compilation/goto2.d(1024): Error: case cannot be in different `try` block level from `switch`
fail_compilation/goto2.d(1026): Error: default cannot be in different `try` block level from `switch`
---
 */


void foo();
void bar();

#line 1000

void test1()
{
    goto L1;
    try
    {
        foo();
      L1:
        { }
    }
    finally
    {
        bar();
    }

    /********************************/

    int i;
    switch (i)
    {
        case 1:
            try
            {
                foo();
        case 2:
                {   }
        default:
                {   }
            }
            finally
            {
                bar();
            }
            break;
    }
}


