/*
TEST_OUTPUT:
---
fail_compilation/udaparams.d(15): Error: variadic parameter cannot has UDAs
fail_compilation/udaparams.d(16): Error: variadic parameter cannot has UDAs
fail_compilation/udaparams.d(18): Error: user defined attributes cannot appear as postfixes
fail_compilation/udaparams.d(19): Error: user defined attributes cannot appear as postfixes
fail_compilation/udaparams.d(20): Error: user defined attributes cannot appear as postfixes
fail_compilation/udaparams.d(22): Error: @safe attribute for function parameter is not supported
fail_compilation/udaparams.d(23): Error: @safe attribute for function parameter is not supported
fail_compilation/udaparams.d(24): Error: @safe attribute for function parameter is not supported
---
*/

void vararg1(int a, @(10) ...);
extern(C) void vararg2(int a, @(10) ...);

void rhsuda(int a @(10));
void rhsuda2(int @(10));
void rhsuda3(int[] arr @(10) ...);

void wrongAttr1(@safe int);
void wrongAttr2(@safe void function());
void wrongAttr3(@safe void delegate());
