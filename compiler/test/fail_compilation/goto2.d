/*
TEST_OUTPUT:
---
fail_compilation/goto2.d(1024): Error: case cannot be in different `try` block level from `switch`
fail_compilation/goto2.d(1026): Error: default cannot be in different `try` block level from `switch`
fail_compilation/goto2.d(1003): Error: cannot `goto` into `try` block
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

/**************************************************
https://issues.dlang.org/show_bug.cgi?id=11540
goto label + try-catch-finally / with statement

TEST_OUTPUT:
---
fail_compilation/goto2.d(1121): Error: cannot `goto` into `try` block
---
*/
#line 1100

int interpret3a()
{
    // enter to TryCatchStatement.body
    {
        bool c = false;
        try
        {
            if (c)  // need to bypass front-end optimization
                throw new Exception("");
            else
            {
                goto Lx;
              L1:
                c = true;
            }
        }
        catch (Exception e) {}

      Lx:
        if (!c)
            goto L1;
    }
    return 1;
}

/**************************************************
https://issues.dlang.org/show_bug.cgi?id=11540
goto label + try-catch-finally / with statement

TEST_OUTPUT:
---
fail_compilation/goto2.d(1217): Error: cannot `goto` into `try` block
---
*/
#line 1200

int interpret3b()
{
    // enter back to TryFinallyStatement.body
    {
        bool c = false;
        try
        {
            goto Lx;
          L1:
            c = true;
        }
        finally {
        }

      Lx:
        if (!c)
            goto L1;
    }

    return 1;
}

/**************************************************
https://issues.dlang.org/show_bug.cgi?id=13815

TEST_OUTPUT:
---
fail_compilation/goto2.d(1234): Error: cannot `goto` into `try` block
---
*/

bool f()
{
    goto L;
    try
    {
L:                                  // line 7
        throw new Exception("");    // line 8
    }
    catch (Exception e)
    {
        return true;
    }
    return false;
}

/**************************************************
https://github.com/dlang/dmd/issues/18274

TEST_OUTPUT:
---
fail_compilation/goto2.d(1267): Error: `goto` skips declaration of variable `goto2.test_throwing.s`
fail_compilation/goto2.d(1268):        declared here
fail_compilation/goto2.d(1274): Error: cannot `goto` past `scope(exit)` block
fail_compilation/goto2.d(1281): Error: cannot `goto` past `scope(failure)` block
fail_compilation/goto2.d(1288): Error: cannot `goto` past `scope(success)` block
---
*/

struct S
{
    ~this() nothrow;
}

void test_throwing()
{
    goto skip;
    S s;
skip:
}

void test_scope_exit(ref int x)
{
    goto skip;
    scope(exit) { x++; }
skip:
}

void test_scope_failure(ref int x)
{
    goto skip;
    scope(failure) { x++; }
skip:
}

void test_scope_success(ref int x)
{
    goto skip;
    scope(success) { x++; }
skip:
}
