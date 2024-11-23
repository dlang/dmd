/*
TEST_OUTPUT:
---
fail_compilation/fail236.d(20): Error: undefined identifier `x`
    void Templ2(x)
         ^
fail_compilation/fail236.d(28): Error: template `Templ2` is not callable using argument types `!()(int)`
    Templ2(i);
          ^
fail_compilation/fail236.d(18):        Candidate is: `Templ2(alias a)(x)`
template Templ2(alias a)
^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=870
// contradictory error messages for templates
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
