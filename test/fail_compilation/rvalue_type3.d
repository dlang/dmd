/* REQUIRED_ARGS: -preview=rvaluetype
TEST_OUTPUT:
---
fail_compilation/rvalue_type3.d(16): Error: `rvalue_type3.fun` called with argument types `(int)` matches both:
fail_compilation/rvalue_type3.d(11):     `rvalue_type3.fun(ref @rvalue(int))`
and:
fail_compilation/rvalue_type3.d(12):     `rvalue_type3.fun(int)`
---
*/

void fun(@rvalue ref int);
void fun(int);

void test()
{
    fun(0);
}
