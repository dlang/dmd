/+
https://issues.dlang.org/show_bug.cgi?id=22031

TEST_OUTPUT:
---
fail_compilation/crt_ctor.d(17): Error: cannot modify `immutable` expression `example`
fail_compilation/crt_ctor.d(31): Error: cannot modify `immutable` expression `example`
fail_compilation/crt_ctor.d(37): Error: functions marked as `crt_constructor` may not be called at runtime
fail_compilation/crt_ctor.d(38): Error: cannot take address of function `initialize` marked as `crt_constructor`
---
+/

immutable int example;

shared static ~this()
{
    example = 2;
}

extern (C)
{
    pragma(crt_constructor)
    void initialize()
    {
        example = 1;
    }

    pragma(crt_destructor)
    void destruct()
    {
        example = 2;
    }
}

void main()
{
    initialize();
    auto addr = &initialize;
    addr();
}
