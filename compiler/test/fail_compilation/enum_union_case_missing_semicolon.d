/*
TEST_OUTPUT:
---
fail_compilation/enum_union_case_missing_semicolon.d(11): Error: `,` or `;` expected after enum union variant
---
*/

enum union MissingTerminator
{
    case First()
    case Second();
}