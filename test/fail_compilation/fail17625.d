/*
TEST_OUTPUT:
---
fail_compilation/fail17625.d(15): Error: undefined identifier `boo`
---
*/

module fail17625;

import imports.a17625;
import imports.b17625;

void main()
{
    boo();
}
