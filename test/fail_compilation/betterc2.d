/* REQUIRED_ARGS: -betterC
 * TEST_OUTPUT:
---
fail_compilation/betterc2.d(9): Error: function `betterc2.notNoThrow` must be `nothrow` if compiling without support for exceptions (e.g. -betterC)
fail_compilation/betterc2.d(13): Error: function `betterc2.S.notNowThrow` must be `nothrow` if compiling without support for exceptions (e.g. -betterC)
---
*/

void notNoThrow() {}

struct S
{
    void notNowThrow() { }
}
