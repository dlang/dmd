// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail20163.d-mixin-10(10): Deprecation: module `imports.fail20164` is deprecated
---
*/
module fail20163;

mixin("import imports.fail20164;");
