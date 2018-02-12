/*
TEST_OUTPUT:
---
fail_compilation/fail320.d(10): Deprecation: module `fail320a` from file fail_compilation/imports/fail320a.d should be imported with 'import fail320a;'
fail_compilation/fail320.d(11): Deprecation: module `fail320b` from file fail_compilation/imports/fail320b.d should be imported with 'import fail320b;'
fail_compilation/fail320.d(12): Error: no overload matches for `foo`
---
*/

import imports.fail320a;
import imports.fail320b;
void main() { foo(); }
