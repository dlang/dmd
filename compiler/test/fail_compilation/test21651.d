// REQUIRED_ARGS: -de
// EXTRA_SOURCES: imports/test21651b.d
/* TEST_OUTPUT:
---
 fail_compilation/test21651.d(11): Error: undefined identifier `test21651b` in package `imports`, perhaps add `static import imports.test21651b;`
---
*/

module imports.test21651;

imports.test21651b.T a;
