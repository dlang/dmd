/*
EXTRA_FILES: imports/a18243.d
TEST_OUTPUT:
---
fail_compilation/fail18243.d(17): Error: none of the overloads of `isNaN` are callable using argument types `!()(float)`
/home/nick/git/dmd/compiler/test/../../../phobos/std/math/traits.d(31):        Candidates are: `isNaN(X)(X x)`
fail_compilation/imports/a18243.d(5):                        `a18243.isNaN()`
---
*/

module fail18243;

import imports.a18243;

void main()
{
    bool b = isNaN(float.nan);
}
