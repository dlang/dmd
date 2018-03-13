/*
TEST_OUTPUT:
---
fail_compilation/e7804_1.d(9): Error: invalid `__traits`, only `getMember` can be aliased and not `farfelu`
---
*/
module e7804_1;

__traits(farfelu, Aggr, "member") a;
