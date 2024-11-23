/*
EXTRA_FILES: imports/a17625.d imports/b17625.d
TEST_OUTPUT:
---
fail_compilation/fail17625.d(18): Error: undefined identifier `boo`
    boo();
    ^
---
*/

module fail17625;

import imports.a17625;
import imports.b17625;

void main()
{
    boo();
}
