/*
TEST_OUTPUT:
---
fail_compilation/fail236.d(12): Error: undefined identifier x
---
*/

// Issue 870 - contradictory error messages for templates

template Templ2(alias a)
{
    void Templ2(x)
    {
    }
}

void main()
{
    int i;
    Templ2(i);
}
