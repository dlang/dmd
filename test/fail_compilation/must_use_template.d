/+
TEST_OUTPUT:
---
fail_compilation/must_use_template.d(15): Error: ignored value of `@mustUse` type `S!int`; prepend a `cast(void)` if intentional
---
+/
import core.attribute;

@mustUse struct S(T) {}

S!int fun() { return S!int(); }

void test()
{
    fun();
}
