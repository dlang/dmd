/*
TEST_OUTPUT:
---
fail_compilation/enum_member.d(14): Error: basic type expected, not `for`
fail_compilation/enum_member.d(15): Error: no identifier for declarator `T`
fail_compilation/enum_member.d(15): Error: found `@` when expecting `,`
fail_compilation/enum_member.d(22): Error: found `}` when expecting `identifier`
fail_compilation/enum_member.d(24): Error: found `End of File` when expecting `,`
fail_compilation/enum_member.d(24): Error: premature end of file
---
*/
enum
{
    for,
    T @a b = 1
}
// See also: fail10285.d

enum E
{
    @a
}
// See also: fail20538.d
