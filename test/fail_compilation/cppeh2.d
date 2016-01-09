// REQUIRED_ARGS: -dwarfeh
/*
TEST_OUTPUT:
---
fail_compilation/cppeh2.d(19): Error: cannot mix catching D and C++ exceptions in the same try-catch
---
*/

extern (C++, std)
{
    class exception { }
}

void bar();
void abc();

void foo()
{
    try
    {
        bar();
    }
    catch (std.exception e)
    {
        abc();
    }
    catch (Exception e)
    {
        abc();
    }
}
