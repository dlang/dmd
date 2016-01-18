// REQUIRED_ARGS: -dwarfeh
/*
TEST_OUTPUT:
---
fail_compilation/cppeh1.d(24): Error: cannot catch C++ class objects in @safe code
---
*/

extern (C++, std)
{
    class exception { }
}

@safe:
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
}
