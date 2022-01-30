/+
TEST_OUTPUT:
---
fail_compilation/must_use_union.d(15): Error: ignored value of `@mustUse` type `must_use_union.U`; prepend a `cast(void)` if intentional
---
+/
import core.attribute;

@mustUse union U {}

U fun() { return U(); }

void test()
{
    fun();
}

