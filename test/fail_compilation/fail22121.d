// https://issues.dlang.org/show_bug.cgi?id=22121

/*
TEST_OUTPUT:
---
fail_compilation/imports/test22121/package.d(1): Error: package name 'fail_compilation' conflicts with usage as a module name in file fail_compilation/fail22121.d
---
*/

module fail_compilation;
import fail_compilation.imports.test22121;
