void func() { }

// ok
void test1() nothrow
{
    try
    {
        func();
    }
    catch (Exception th)
    {
    }
}

// Error: function 'test.test2' is nothrow yet may throw
void test2() nothrow
{
    try
    {
        func();
    }
    catch (Error th)
    {
    }
}
