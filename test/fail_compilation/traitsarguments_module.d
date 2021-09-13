/*
TEST_OUTPUT:
---
fail_compilation/traitsarguments_module.d(9): Error: `__traits(arguments)` cannot have arguments, but `234` was supplied
fail_compilation/traitsarguments_module.d(10): Error: `__traits(arguments)` may only be used inside a function
---
*/

typeof(__traits(arguments, 234)) xyz;
typeof(__traits(arguments)) x;