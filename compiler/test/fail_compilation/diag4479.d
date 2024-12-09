// EXTRA_SOURCES: imports/fail4479.d
/*
TEST_OUTPUT:
---
fail_compilation/diag4479.d(12): Error: module `imports.fail4479mod` from file fail_compilation/imports/fail4479.d must be imported with 'import imports.fail4479mod;'
import imports.fail4479;
       ^
---
*/

module diag4479;
import imports.fail4479;
void main() { }
