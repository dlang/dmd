/*
REQUIRED_ARGS: -w
TEST_OUTPUT:
---
fail_compilation/lint_struct_params_fail.d(24): Warning: [constSpecial] special method `opEquals` should be marked as `const`
fail_compilation/lint_struct_params_fail.d(29): Warning: [unusedParams] function parameter `x` is never used
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/

struct LintParams {
    bool enabled = true;
    bool constSpecial = true;
    bool unusedParams = true;
}

enum StrictLint = LintParams(true, true, true);
pragma(lint, StrictLint):

struct BadStruct
{
    // LINT: constSpecial
    bool opEquals(ref const BadStruct _rhs) { return true; }
}

class A
{
    final void foo(int x) {}
}
