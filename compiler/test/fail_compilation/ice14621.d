/*
TEST_OUTPUT:
---
fail_compilation/ice14621.d(22): Error: static assert:  `false` is false
fail_compilation/ice14621.d(22):        instantiated from: `erroneousTemplateInstantiation!()` at fail_compilation/ice14621.d(28)
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
