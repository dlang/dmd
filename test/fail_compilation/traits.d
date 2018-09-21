/*
REQUIRED_ARGS:
PERMUTE_ARGS:
*/

/************************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/traits.d(100): Error: `getTargetInfo` key `"not_a_target_info"` not supported by this implementation
fail_compilation/traits.d(101): Error: string expected as argument of __traits `getTargetInfo` instead of `100`
fail_compilation/traits.d(102): Error: expected 1 arguments for `getTargetInfo` but had 2
fail_compilation/traits.d(103): Error: expected 1 arguments for `getTargetInfo` but had 0
---
*/

#line 100
enum A = __traits(getTargetInfo, "not_a_target_info");
enum B = __traits(getTargetInfo, 100);
enum C = __traits(getTargetInfo, "cppRuntimeLibrary", "bits");
enum D = __traits(getTargetInfo);
