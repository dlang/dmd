/+
TEST_OUTPUT:
---
fail_compilation/must_use_template.d(17): Error: ignored value of `@mustuse` type `must_use_template.S!int`; prepend a `cast(void)` if intentional
    fun();
       ^
---
+/
import core.attribute;

@mustuse struct S(T) {}

S!int fun() { return S!int(); }

void test()
{
    fun();
}
