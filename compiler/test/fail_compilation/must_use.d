/+
TEST_OUTPUT:
---
fail_compilation/must_use.d(21): Error: ignored value of `@mustuse` type `must_use.S`; prepend a `cast(void)` if intentional
    fun();
       ^
fail_compilation/must_use.d(22): Error: ignored value of `@mustuse` type `must_use.S`; prepend a `cast(void)` if intentional
    fun(), x++;
       ^
---
+/
import core.attribute;

@mustuse struct S {}

S fun();

void test()
{
    int x;
    fun();
    fun(), x++;
}
