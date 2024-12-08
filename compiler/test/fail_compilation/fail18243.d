/*
EXTRA_FILES: imports/a18243.d imports/b18243.d
TEST_OUTPUT:
---
fail_compilation/fail18243.d(23): Error: none of the overloads of `isNaN` are callable using argument types `!()(float)`
    bool b = isNaN(float.nan);
                  ^
fail_compilation/imports/b18243.d(3):        Candidates are: `isNaN(T)(T x)`
bool isNaN(T)(T x) { return false; }
     ^
fail_compilation/imports/a18243.d(5):                        `imports.a18243.isNaN()`
public bool isNaN() { return false; }
            ^
---
*/

module fail18243;

import imports.a18243;

void main()
{
    bool b = isNaN(float.nan);
}
