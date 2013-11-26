/*
TEST_OUTPUT:
---
fail_compilation/fail236.d(15): Error: undefined identifier x
fail_compilation/fail236.d(23): Error: template fail236.Templ2 does not match any function template declaration. Candidates are:
fail_compilation/fail236.d(13):        fail236.Templ2(alias a)(x)
fail_compilation/fail236.d(23): Error: template fail236.Templ2(alias a)(x) cannot deduce template function from argument types !()(int)
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
