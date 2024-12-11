/*
EXTRA_FILES: imports/fail356.d
TEST_OUTPUT:
---
fail_compilation/fail356a.d(11): Error: variable `fail356a.imports` conflicts with import `fail356a.imports` at fail_compilation/fail356a.d(10)
int imports; // collides with package name
    ^
---
*/
import imports.fail356;
int imports; // collides with package name
