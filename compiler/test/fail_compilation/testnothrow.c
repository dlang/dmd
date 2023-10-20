/* TEST_OUTPUT:
---
fail_compilation/testnothrow.c(105): Error: function `testnothrow.throwing` is not `nothrow`
fail_compilation/testnothrow.c(104): Error: function `testnothrow.mul` may throw but is marked as `nothrow`
fail_compilation/testnothrow.c(111): Error: function `testnothrow.throwing` is not `nothrow`
fail_compilation/testnothrow.c(110): Error: function `testnothrow.add` may throw but is marked as `nothrow`
---
*/

// https://issues.dlang.org/show_bug?id=21938

#line 100

void throwing() { }

__attribute__((nothrow)) int mul(int x)
{
    throwing();
    return x * x;
}

__declspec(nothrow) int add(int x)
{
    throwing();
    return x + x;
}

int doSquare(int x)
{
    return mul(x) + add(x);
}
