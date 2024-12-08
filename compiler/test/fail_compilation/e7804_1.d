/*
TEST_OUTPUT:
---
fail_compilation/e7804_1.d(22): Error: undefined identifier `Aggr`
__traits(farfelu, Aggr, "member") a;
^
fail_compilation/e7804_1.d(23): Error: unrecognized trait `farfelu`
__traits(farfelu, S, "member") a2;
^
fail_compilation/e7804_1.d(25): Error: undefined identifier `Aggr`
alias foo = __traits(farfelu, Aggr, "member");
            ^
fail_compilation/e7804_1.d(26): Error: unrecognized trait `farfelu`
alias foo2 = __traits(farfelu, S, "member");
             ^
---
*/
module e7804_1;

struct S {}

__traits(farfelu, Aggr, "member") a;
__traits(farfelu, S, "member") a2;

alias foo = __traits(farfelu, Aggr, "member");
alias foo2 = __traits(farfelu, S, "member");
