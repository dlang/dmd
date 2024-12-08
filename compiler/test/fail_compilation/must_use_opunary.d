/+
TEST_OUTPUT:
---
fail_compilation/must_use_opunary.d(22): Error: ignored value of `@mustuse` type `must_use_opunary.S`; prepend a `cast(void)` if intentional
    -s;
    ^
---
+/
import core.attribute;

@mustuse struct S
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
