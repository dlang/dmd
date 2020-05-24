/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/dep_extern_safety.d(10): Deprecation: `extern` function `dep_extern_safety.cfun` should be marked explicitly as `@safe`, `@system`, or `@trusted`
fail_compilation/dep_extern_safety.d(11): Deprecation: `extern` function `dep_extern_safety.dfun` should be marked explicitly as `@safe`, `@system`, or `@trusted`
---
*/

extern extern(C) void cfun();
extern extern(D) void dfun();
