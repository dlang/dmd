/*
TEST_OUTPUT:
---
fail_compilation/fail11125.d(24): Error: template fail11125.filter does not match any function template declaration. Candidates are:
fail_compilation/fail11125.d(15):        fail11125.filter(alias predfun) if (is(ReturnType!predfun == bool))
fail_compilation/fail11125.d(24): Error: template fail11125.filter(alias predfun) if (is(ReturnType!predfun == bool)) cannot deduce template function from argument types !(function (int a) => a + 1)(int[])
fail_compilation/fail11125.d(25): Error: template fail11125.filter does not match any function template declaration. Candidates are:
fail_compilation/fail11125.d(15):        fail11125.filter(alias predfun) if (is(ReturnType!predfun == bool))
fail_compilation/fail11125.d(25): Error: template fail11125.filter(alias predfun) if (is(ReturnType!predfun == bool)) cannot deduce template function from argument types !(function (int a) => a + 1)(int[])
---
*/

template ReturnType(alias fun) { alias int ReturnType; }

template filter(alias predfun)
    if (is(ReturnType!predfun == bool))
{
    static assert(is(ReturnType!predfun == bool));
    auto filter(Range)(Range r) { }
}

void main()
{
    filter!((int a) => a + 1)([1]);  // fails in constraint
    [1].filter!((int a) => a + 1);   // fails internally in static assert!
}
