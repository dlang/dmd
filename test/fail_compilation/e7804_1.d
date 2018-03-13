/*
TEST_OUTPUT:
---
fail_compilation/e7804_1.d(9): Error: invalid `__traits`, only `getMember` can give types and symbols
---
*/
module e7804_1;

__traits(farfelu, Aggr, "member") a;
