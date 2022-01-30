/+
TEST_OUTPUT:
---
fail_compilation/must_use.d(15): Error: ignored value of `@mustUse` type `must_use.S`; prepend a `cast(void)` if intentional
---
+/
import core.attribute;

@mustUse struct S {}

S fun() { return S(); }

void test()
{
    fun();
}
