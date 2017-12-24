// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

/***************** if (__ctfe) *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc4.d(19): Error: cannot use operator `~=` in `@nogc` function `nogc4.test1`
fail_compilation/nogc4.d(33): Error: cannot use operator `~=` in `@nogc` function `nogc4.test2`
fail_compilation/nogc4.d(45): Error: cannot use operator `~=` in `@nogc` function `nogc4.test3`
---
*/
@nogc void test1()
{
    if (!__ctfe)
    {
        int[] arr;
        arr ~= 42;
    }
}

@nogc void test2()
{
    if (__ctfe)
    {
        int[] arr;
        arr ~= 42;
    }
    else
    {
        int[] arr;
        arr ~= 42;
    }
}

@nogc void test3()
{
    if (__ctfe)
    {
    }
    else
    {
        int[] arr;
        arr ~= 42;
    }
}
