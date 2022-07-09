/+
https://issues.dlang.org/show_bug.cgi?id=22031

TEST_OUTPUT:
---
fail_compilation/crt_ctor.d(21): Error: cannot modify `immutable` expression `example`
fail_compilation/crt_ctor.d(35): Error: cannot modify `immutable` expression `example`
fail_compilation/crt_ctor.d(41): Error: cannot call `crt_constructor` function `initialize` in `@safe` code
fail_compilation/crt_ctor.d(42): Error: cannot take address of `crt_constructor` function `initialize` in `@safe` code
fail_compilation/crt_ctor.d(44): Error: `@safe` function `D main` cannot call `@system` function `crt_ctor.inferCall!().inferCall`
fail_compilation/crt_ctor.d(48):        `crt_ctor.inferCall!().inferCall` is declared here
fail_compilation/crt_ctor.d(45): Error: `@safe` function `D main` cannot call `@system` function `crt_ctor.inferAddress!().inferAddress`
fail_compilation/crt_ctor.d(53):        `crt_ctor.inferAddress!().inferAddress` is declared here
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
    void initialize() @safe
    {
        example = 1;
    }

    pragma(crt_destructor)
    void destruct()
    {
        example = 2;
    }
}

void main() @safe
{
    initialize();
    auto addr = &initialize;
    addr();
    inferCall();
    inferAddress();
}

void inferCall()()
{
    initialize();
}

void inferAddress()()
{
    auto addr = &initialize;
}
