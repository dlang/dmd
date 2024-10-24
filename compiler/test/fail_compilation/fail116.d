/*
TEST_OUTPUT:
---
fail_compilation/fail116.d(11): Error: undefined identifier `x`
fail_compilation/fail116.d(16): Error: template instance `square!1.2` does not match template declaration `square(_error_ x)`
fail_compilation/fail116.d(16):        instantiated from here: `square!1.2`
fail_compilation/fail116.d(11):        Candidate match: square(_error_ x)
---
*/

#line 100

// https://issues.dlang.org/show_bug.cgi?id=405
// typeof in TemplateParameterList causes compiletime segmentfault
template square(typeof(x) x)
{
    const square = x * x;
}

const b = square!(1.2);
