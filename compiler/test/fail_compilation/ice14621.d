/*
TEST_OUTPUT:
---
fail_compilation/ice14621.d(26): Error: static assert:  `false` is false
        static assert(false);
        ^
fail_compilation/ice14621.d(32):        instantiated from here: `erroneousTemplateInstantiation!()`
        ret[] = erroneousTemplateInstantiation!();
                ^
---
*/

void main()
{
    S s;
    s.foo();
}

struct S
{
    float[] array;
    alias array this;

    template erroneousTemplateInstantiation()
    {
        static assert(false);
    }

    void foo()
    {
        S ret;
        ret[] = erroneousTemplateInstantiation!();
    }
}
