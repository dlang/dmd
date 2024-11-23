/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/diag23295.d(31): Error: scope variable `x` assigned to non-scope parameter `y` calling `foo`
    foo(x, null);
        ^
fail_compilation/diag23295.d(42):        which is assigned to non-scope parameter `z`
auto fooImpl(int* z, int** w)
                ^
fail_compilation/diag23295.d(44):        which is not `scope` because of `f = & z`
    auto f = &z;
         ^
fail_compilation/diag23295.d(34): Error: scope variable `ex` assigned to non-scope parameter `e` calling `thro`
    thro(ex);
         ^
fail_compilation/diag23295.d(49):        which is not `scope` because of `throw e`
    throw e;
          ^
---
*/

// explain why scope inference failed
// https://issues.dlang.org/show_bug.cgi?id=23295

@safe:

void main()
{
    scope int* x;
    foo(x, null);

    scope Exception ex;
    thro(ex);
}

auto foo(int* y, int** w)
{
    fooImpl(y, null);
}

auto fooImpl(int* z, int** w)
{
    auto f = &z;
}

auto thro(Exception e)
{
    throw e;
}
