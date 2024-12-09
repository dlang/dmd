/*
TEST_OUTPUT:
---
fail_compilation/ice11926.d(15): Error: no identifier for declarator `const(a)`
    const a = 1,
            ^
fail_compilation/ice11926.d(16): Error: no identifier for declarator `const(b)`
    const b = 2
            ^
---
*/

enum
{
    const a = 1,
    const b = 2
}
