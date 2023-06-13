// https://issues.dlang.org/show_bug.cgi?id=23973

/*
TEST_OUTPUT:
---
fail_compilation/test23973.d(16): Error: function `test23973.foo` is not `nothrow`
fail_compilation/test23973.d(14): Error: A module constructor may not throw as the runtime has not been yet initialized
---
*/
void foo()
{
}

static this()
{
    foo();
}

void main()
{
}
