/*
REQUIRED_ARGS: -w
TEST_OUTPUT:
---
fail_compilation/lint_unused_params.d(17): Lint: [unusedParams] function parameter `y` is never used
fail_compilation/lint_unused_params.d(36): Lint: [unusedParams] function parameter `b` is never used
fail_compilation/lint_unused_params.d(52): Lint: [unusedParams] function parameter `b` is never used
fail_compilation/lint_unused_params.d(64): Lint: [unusedParams] function parameter `z` is never used
fail_compilation/lint_unused_params.d(43): Lint: [unusedParams] function parameter `y` is never used
fail_compilation/lint_unused_params.d(47): Error: template instance `lint_unused_params.tplFunc!int` error instantiating
---
*/

pragma(lint, unusedParams):

// 1. Regular functions
void testBasic(int x, int y)
{
    cast(void)x;
}

// 2. Interfaces and abstract methods (no body - ignored)
interface I { void ifaceMethod(int a); }
abstract class AbstractBase { abstract void absMethod(int a); }

// 3. Virtual and overridden methods (ignored)
class Base { void foo(int a) {} }
class Derived : Base
{
    override void foo(int a) {}
}

// 4. Final methods (cannot be overridden, so parameters must be used)
class Normal
{
    final void bar(int a, int b)
    {
        cast(void)a;
    }
}

// 5. Template functions (checked upon instantiation)
void tplFunc(T)(T x, T y)
{
    cast(void)x;
}
alias instantiateTpl = tplFunc!int;

// 6. Delegates and lambdas
void testDelegate()
{
    auto dg = (int a, int b) {
        cast(void)a;
    };
}

// 7. Unnamed parameters (ignored by the compiler as they have STC.temp)
void unnamedParam(int, int x)
{
    cast(void)x;
}

// 8. Default parameters
void defaultArg(int x = 5, int z = 10)
{
    cast(void)x;
}

// 9. Disable linter for the rest of the file
pragma(lint, none):

void completelyIgnored(int a) {}
