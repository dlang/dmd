// REQUIRED_ARGS: -c -Ifail_compilation/imports/ fail_compilation/imports/test18938a/cache.d fail_compilation/imports/test18938a/file.d
/*
TEST_OUTPUT:
---
fail_compilation/imports/test18938b/file.d(20): Deprecation: `std.algorithm.setops.No` is not visible from module `file`
fail_compilation/imports/test18938b/file.d(9): Error: `map(Range)(Range r) if (isInputRange!(Unqual!Range))` has no effect
---
*/

void main() {}
