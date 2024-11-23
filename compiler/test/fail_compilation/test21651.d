// REQUIRED_ARGS: -de
// EXTRA_SOURCES: imports/test21651b.d
/* TEST_OUTPUT:
---
fail_compilation/test21651.d(13): Deprecation: module imports.test21651b is not accessible here, perhaps add 'static import imports.test21651b;'
imports.test21651b.T a;
                     ^
---
*/

module imports.test21651;

imports.test21651b.T a;
