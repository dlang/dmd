/+
TEST_OUTPUT:
---
fail_compilation/must_use_union.d(17): Error: ignored value of `@mustuse` type `must_use_union.U`; prepend a `cast(void)` if intentional
    fun();
       ^
---
+/
import core.attribute;

@mustuse union U {}

U fun() { return U(); }

void test()
{
    fun();
}
