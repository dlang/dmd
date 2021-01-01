/************************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/traits.d(200): Error: undefined identifier `imports.nonexistent`
fail_compilation/traits.d(201): Error: undefined identifier `imports.nonexistent`
fail_compilation/traits.d(202): Error: expected 1 arguments for `isPackage` but had 0
fail_compilation/traits.d(203): Error: expected 1 arguments for `isModule` but had 0
---
*/

#line 200
enum A2 = __traits(isPackage, imports.nonexistent);
enum B2 = __traits(isModule, imports.nonexistent);
enum C2 = __traits(isPackage);
enum D2 = __traits(isModule);
