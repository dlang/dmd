/*
TEST_OUTPUT:
---
fail_compilation/traits_parameters.d(13): Error: `__traits(parameters)` cannot have arguments, but `234` was supplied
typeof(__traits(parameters, 234)) xyz;
       ^
fail_compilation/traits_parameters.d(14): Error: `__traits(parameters)` may only be used inside a function
typeof(__traits(parameters)) x;
       ^
---
*/

typeof(__traits(parameters, 234)) xyz;
typeof(__traits(parameters)) x;
