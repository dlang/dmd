/*
TEST_OUTPUT:
---
fail_compilation/fail17570.d(18): Error: cannot use function constraints for non-template functions. Use `static if` instead
    void func() if(isIntegral!T)
                ^
fail_compilation/fail17570.d(18): Error: declaration expected, not `if`
    void func() if(isIntegral!T)
                ^
fail_compilation/fail17570.d(21): Error: `}` expected following members in `struct` declaration
fail_compilation/fail17570.d(17):        struct `S` starts here
struct S(T) {
^
---
*/

struct S(T) {
    void func() if(isIntegral!T)
    {}
}
