/*
TEST_OUTPUT:
---
fail_compilation/enum_union_case_missing_semicolon.d(12): Error: `,` or `;` expected after enum union variant
fail_compilation/enum_union_case_missing_semicolon.d(19): Error: `,` or `;` expected after enum union variant
---
*/

enum union MissingBetweenCases
{
    case First()
    case Second();
    case Third();
}

enum union MissingBeforeMember
{
    case One(), Two()
    void helper() {}
}