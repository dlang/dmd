/*
TEST_OUTPUT
---
fail_compilation/nodiscard_function.d(11): Error: ignored return value of `@nodiscard` function `nodiscard_function.func`; prepend a `cast(void)` if intentional
---
*/
@nodiscard extern int func();

void ignore()
{
    func();
}
