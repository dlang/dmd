// REQUIRED_ARGS: -i -unittest-roots
// EXTRA_FILES: imports/compiled_lib.d
/*
TEST_OUTPUT:
---
Compiling unittest_roots
---
*/

module unittest_roots;

unittest
{
	pragma(msg, "Compiling unittest_roots");
}

import imports.compiled_lib; // imported but no unittest in imports.compiled_lib is semantically analyzed
