/+
TEST_OUTPUT:
---
fail_compilation/must_use_opunary.d(20): Error: ignored value of `@mustUse` type `must_use_opunary.S`; prepend a `cast(void)` if intentional
---
+/
import core.attribute;

@mustUse struct S
{
    ref S opUnary(string op)() return
    {
        return this;
    }
}

void test()
{
    S s;
    -s;
}
