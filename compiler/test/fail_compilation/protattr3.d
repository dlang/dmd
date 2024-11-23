/*
EXTRA_FILES: protection/subpkg/test3.d
TEST_OUTPUT:
---
fail_compilation/protection/subpkg/test3.d(3): Error: `protection package` expected as dot-separated identifiers, got `123`
package(123) void foo3();
        ^
---
*/
import protection.subpkg.test3;
