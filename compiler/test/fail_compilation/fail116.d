/*
TEST_OUTPUT:
---
fail_compilation/fail116.d(15): Error: undefined identifier `x`
template square(typeof(x) x)
                       ^
fail_compilation/fail116.d(20): Error: template instance `square!1.2` does not match template declaration `square(_error_ x)`
const b = square!(1.2);
          ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=405
// typeof in TemplateParameterList causes compiletime segmentfault
template square(typeof(x) x)
{
    const square = x * x;
}

const b = square!(1.2);
