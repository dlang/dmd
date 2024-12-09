/*
TEST_OUTPUT:
----
fail_compilation/test17868.d(18): Error: pragma `crt_constructor` takes no argument
pragma(crt_constructor, ctfe())
^
fail_compilation/test17868.d(19): Error: pragma `crt_constructor` takes no argument
pragma(crt_constructor, 1.5f)
^
fail_compilation/test17868.d(20): Error: pragma `crt_constructor` takes no argument
pragma(crt_constructor, "foobar")
^
fail_compilation/test17868.d(21): Error: pragma `crt_constructor` takes no argument
pragma(crt_constructor, S())
^
----
 */
pragma(crt_constructor, ctfe())
pragma(crt_constructor, 1.5f)
pragma(crt_constructor, "foobar")
pragma(crt_constructor, S())
void foo()
{
}

int ctfe()
{
    __gshared int val;
    return val;
}

struct S {}
