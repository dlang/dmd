/*
TEST_OUTPUT:
---
fail_compilation/udaparams.d(75): Error: variadic parameter cannot have user-defined attributes
void vararg1(int a, @(10) ...);
                          ^
fail_compilation/udaparams.d(76): Error: variadic parameter cannot have user-defined attributes
extern(C) void vararg2(int a, @(10) ...);
                                    ^
fail_compilation/udaparams.d(78): Error: user-defined attributes cannot appear as postfixes
void rhsuda(int a @(10));
                       ^
fail_compilation/udaparams.d(79): Error: user-defined attributes cannot appear as postfixes
void rhsuda2(int @(10));
                      ^
fail_compilation/udaparams.d(80): Error: user-defined attributes cannot appear as postfixes
void rhsuda3(int[] arr @(10) ...);
                             ^
fail_compilation/udaparams.d(82): Error: `@safe` attribute for function parameter is not supported
void wrongAttr1(@safe int);
                 ^
fail_compilation/udaparams.d(83): Error: `@safe` attribute for function parameter is not supported
void wrongAttr2(@safe void function());
                 ^
fail_compilation/udaparams.d(84): Error: `@safe` attribute for function parameter is not supported
void wrongAttr3(@safe void delegate());
                 ^
fail_compilation/udaparams.d(87): Error: `@system` attribute for function parameter is not supported
void test16(A)(A a @system);
                    ^
fail_compilation/udaparams.d(88): Error: `@trusted` attribute for function parameter is not supported
void test16(A)(A a @trusted);
                    ^
fail_compilation/udaparams.d(89): Error: `@nogc` attribute for function parameter is not supported
void test16(A)(A a @nogc);
                    ^
fail_compilation/udaparams.d(95): Error: cannot put a storage-class in an `alias` declaration.
fail_compilation/udaparams.d(96): Error: cannot put a storage-class in an `alias` declaration.
fail_compilation/udaparams.d(97): Error: semicolon expected to close `alias` declaration, not `=>`
alias test19f = extern(C++) b => 1 + 2;
                              ^
fail_compilation/udaparams.d(97): Error: declaration expected, not `=>`
alias test19f = extern(C++) b => 1 + 2;
                              ^
fail_compilation/udaparams.d(98): Error: semicolon expected to close `alias` declaration, not `=>`
alias test19g = align(2) b => 1 + 2;
                           ^
fail_compilation/udaparams.d(98): Error: declaration expected, not `=>`
alias test19g = align(2) b => 1 + 2;
                           ^
fail_compilation/udaparams.d(101): Error: basic type expected, not `@`
void test21(@(3) T)(T t) {}
            ^
fail_compilation/udaparams.d(101): Error: identifier expected for template value parameter
void test21(@(3) T)(T t) {}
            ^
fail_compilation/udaparams.d(101): Error: found `@` when expecting `)`
void test21(@(3) T)(T t) {}
            ^
fail_compilation/udaparams.d(101): Error: basic type expected, not `3`
void test21(@(3) T)(T t) {}
              ^
fail_compilation/udaparams.d(101): Error: found `3` when expecting `)`
void test21(@(3) T)(T t) {}
              ^
fail_compilation/udaparams.d(101): Error: semicolon expected following function declaration, not `)`
void test21(@(3) T)(T t) {}
               ^
fail_compilation/udaparams.d(101): Error: declaration expected, not `)`
void test21(@(3) T)(T t) {}
               ^
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
alias test19a = @safe b => 1 + 2;
alias test19b = @system b => 1 + 2;
alias test19c = @nogc b => 1 + 2;
alias test19d = @(2) @system b => 1 + 2;
alias test19e = @safe @(2) b => 1 + 2;
alias test19f = extern(C++) b => 1 + 2;
alias test19g = align(2) b => 1 + 2;

// UDAs on Template parameter aren't supported
void test21(@(3) T)(T t) {}
