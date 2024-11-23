/*
TEST_OUTPUT:
----
fail_compilation/test17868b.d(15): Error: pragma `crt_constructor` can only apply to a single declaration
pragma(crt_constructor):
^
fail_compilation/test17868b.d(20): Error: function `test17868b.bar` must return `void` for `pragma(crt_constructor)`
extern(C) int bar()
              ^
fail_compilation/test17868b.d(24): Error: function `test17868b.baz` must be `extern(C)` for `pragma(crt_constructor)` when taking parameters
void baz(int argc, char** argv)
     ^
----
 */
pragma(crt_constructor):
void foo()
{
}

extern(C) int bar()
{
}

void baz(int argc, char** argv)
{
}

extern(C) void bazC(int, char**)
{
}
