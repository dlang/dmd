/+
https://issues.dlang.org/show_bug.cgi?id=22730

EXTRA_FILES: imports/include_unittest/compiled_lib.d import imports/include_unittest/skipped_unittest_lib.d import imports/include_unittest/compiled_unittest_lib.d

REQUIRED_ARGS: -i=compiled_lib -i=lib.with_.unittests -unittest
TEST_OUTPUT:
---
Found module with skipped unittests
Compiling compiled_lib.unittests
Compiling compiled_lib.someFunction
Compiling lib.with_.unittests.someFunction
Compiling lib.with_.unittests.unittest
---
+/

import imports.include_unittest.compiled_lib;          // Matches the first -i pattern, no module decl.
import imports.include_unittest.skipped_unittest_lib;  // Matches neither -i pattern
import imports.include_unittest.compiled_unittest_lib; // Matches the second -i pattern, has module decl.
