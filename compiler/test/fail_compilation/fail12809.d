// REQUIRED_ARGS: -o-

bool cond;

/*
TEST_OUTPUT:
---
fail_compilation/fail12809.d(43): Error: `object.Exception` is thrown but not caught
        throw new Exception("");        // error
        ^
fail_compilation/fail12809.d(40): Error: function `fail12809.test_finally1` may throw but is marked as `nothrow`
void test_finally1() nothrow
     ^
fail_compilation/fail12809.d(59): Error: `object.Exception` is thrown but not caught
        throw new Exception("");        // error
        ^
fail_compilation/fail12809.d(63): Error: `object.Exception` is thrown but not caught
            throw new Exception("");    // error
            ^
fail_compilation/fail12809.d(56): Error: function `fail12809.test_finally3` may throw but is marked as `nothrow`
void test_finally3() nothrow
     ^
fail_compilation/fail12809.d(73): Error: `object.Exception` is thrown but not caught
        throw new Exception("");        // error
        ^
fail_compilation/fail12809.d(68): Error: function `fail12809.test_finally4` may throw but is marked as `nothrow`
void test_finally4() nothrow
     ^
fail_compilation/fail12809.d(89): Error: `object.Exception` is thrown but not caught
            throw new Exception("");    // error
            ^
fail_compilation/fail12809.d(93): Error: `object.Exception` is thrown but not caught
        throw new Exception("");        // error
        ^
fail_compilation/fail12809.d(84): Error: function `fail12809.test_finally6` may throw but is marked as `nothrow`
void test_finally6() nothrow
     ^
---
*/
void test_finally1() nothrow
{
    try
        throw new Exception("");        // error
    finally
    {}
}

void test_finally2() nothrow
{
    try
        throw new Exception("");        // no error
    finally
        assert(0);  // unconditional halt
}

void test_finally3() nothrow
{
    try
        throw new Exception("");        // error
    finally
    {
        if (cond)
            throw new Exception("");    // error
        assert(0);  // conditional halt
    }
}

void test_finally4() nothrow
{
    try
    {}
    finally
        throw new Exception("");        // error
}

void test_finally5() nothrow
{
    try
        assert(0);  // unconditional halt
    finally
        throw new Exception("");        // no error
}

void test_finally6() nothrow
{
    try
    {
        if (cond)
            throw new Exception("");    // error
        assert(0);  // conditional halt
    }
    finally
        throw new Exception("");        // error
}
