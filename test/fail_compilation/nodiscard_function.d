/*
REQUIRED_ARGS: -preview=nodiscard
TEST_OUTPUT
---
fail_compilation/nodiscard_function.d(12): Error: ignored return value of `@nodiscard` function `nodiscard_function.func`; prepend a `cast(void)` if intentional
---
*/
@nodiscard extern int func();

void ignore()
{
    func();
}
