/*
REQUIRED_ARGS: -preview=nodiscard
TEST_OUTPUT
---
fail_compilation/nodiscard_type.d(13): Error: ignored value of `@nodiscard` type `S`; prepend a `cast(void)` if intentional
---
*/
@nodiscard struct S {};
extern S func();

void ignore()
{
    func();
}
