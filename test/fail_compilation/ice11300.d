/*
TEST_OUTPUT:
---
fail_compilation/imports/ice11300a.d(3): Error: cannot resolve type for value
---
*/
module ice11300;
import imports.ice11300a;
enum value = 42;
