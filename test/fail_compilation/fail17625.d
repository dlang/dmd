/*
TEST_OUTPUT:
---
fail_compilation/fail17625.d(16): Deprecation: `b17625.boo` is not visible from module `fail17625`
fail_compilation/fail17625.d(16): Error: function `b17625.boo` is not accessible from module `fail17625`
---
*/

module fail17625;

import imports.a17625;
import imports.b17625;

void main()
{
    boo();
}
