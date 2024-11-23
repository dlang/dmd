/*
TEST_OUTPUT:
---
fail_compilation/fnconstraint.d(24): Error: template constraint must follow parameter lists and attributes
if (true)
^
fail_compilation/fnconstraint.d(24): Error: declaration expected, not `if`
if (true)
^
fail_compilation/fnconstraint.d(33): Error: template constraint must follow parameter lists and attributes
    if (true) {}
    ^
fail_compilation/fnconstraint.d(33): Error: declaration expected, not `if`
    if (true) {}
    ^
fail_compilation/fnconstraint.d(37): Error: `}` expected following members in `struct` declaration
fail_compilation/fnconstraint.d(29):        struct `S` starts here
struct S
^
---
*/
void foo()()
in(true)
if (true)
{}

alias f = foo!();

struct S
{
    this()()
    if (true)
    if (true) {}
}

S s;
