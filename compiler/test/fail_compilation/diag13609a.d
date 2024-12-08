/*
TEST_OUTPUT:
---
fail_compilation/diag13609a.d(20): Error: `}` expected following members in `struct` declaration
fail_compilation/diag13609a.d(19):        struct starts here
    struct {
    ^
fail_compilation/diag13609a.d(20): Error: `}` expected following members in `class` declaration
fail_compilation/diag13609a.d(15):        class `C` starts here
class C
^
---
*/

class C
{
    void foo() {}

    struct {
