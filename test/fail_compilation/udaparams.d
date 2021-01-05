/*
TEST_OUTPUT:
---
fail_compilation/udaparams.d(28): Error: variadic parameter cannot have user-defined attributes
fail_compilation/udaparams.d(29): Error: variadic parameter cannot have user-defined attributes
fail_compilation/udaparams.d(31): Error: user-defined attributes cannot appear as postfixes
fail_compilation/udaparams.d(32): Error: user-defined attributes cannot appear as postfixes
fail_compilation/udaparams.d(33): Error: user-defined attributes cannot appear as postfixes
fail_compilation/udaparams.d(35): Error: `@safe` attribute for function parameter is not supported
fail_compilation/udaparams.d(36): Error: `@safe` attribute for function parameter is not supported
fail_compilation/udaparams.d(37): Error: `@safe` attribute for function parameter is not supported
fail_compilation/udaparams.d(40): Error: `@system` attribute for function parameter is not supported
fail_compilation/udaparams.d(41): Error: `@trusted` attribute for function parameter is not supported
fail_compilation/udaparams.d(42): Error: `@nogc` attribute for function parameter is not supported
fail_compilation/udaparams.d(45): Error: user-defined attributes not allowed for `alias` declarations
fail_compilation/udaparams.d(45): Error: semicolon expected to close `alias` declaration
fail_compilation/udaparams.d(45): Error: declaration expected, not `=>`
fail_compilation/udaparams.d(48): Error: basic type expected, not `@`
fail_compilation/udaparams.d(48): Error: identifier expected for template value parameter
fail_compilation/udaparams.d(48): Error: found `@` when expecting `)`
fail_compilation/udaparams.d(48): Error: basic type expected, not `3`
fail_compilation/udaparams.d(48): Error: found `3` when expecting `)`
fail_compilation/udaparams.d(48): Error: semicolon expected following function declaration
fail_compilation/udaparams.d(48): Error: declaration expected, not `)`
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


void test16(A)(A a @system);
void test16(A)(A a @trusted);
void test16(A)(A a @nogc);

// lambdas without parentheses
alias test19a = @(3) b => 1 + 2;

// UDAs on Template parameter aren't supported
void test19e(@(3) T)(T t) {}
