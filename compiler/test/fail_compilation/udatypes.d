/*
TEST_OUTPUT:
---
fail_compilation/udatypes.d(10): Error: user-defined attributes not allowed for `alias` declarations
alias c_typedef = extern(C) @(1) void* function(size_t);
                                 ^
---
*/

alias c_typedef = extern(C) @(1) void* function(size_t);
