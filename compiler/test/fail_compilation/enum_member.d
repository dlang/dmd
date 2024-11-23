/*
TEST_OUTPUT:
---
fail_compilation/enum_member.d(20): Error: basic type expected, not `for`
    for,
    ^
fail_compilation/enum_member.d(21): Error: no identifier for declarator `T`
    T @a b = 1
      ^
fail_compilation/enum_member.d(21): Error: found `@` when expecting `,`
    T @a b = 1
      ^
fail_compilation/enum_member.d(28): Error: found `}` when expecting `identifier`
fail_compilation/enum_member.d(30): Error: found `End of File` when expecting `,`
fail_compilation/enum_member.d(30): Error: premature end of file
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
