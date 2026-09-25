/*
TEST_OUTPUT:
---
fail_compilation/enum_union_legacy_template_payload.d(14): Error: function declaration without return type
fail_compilation/enum_union_legacy_template_payload.d(14):        Note that constructors are always named `this`
fail_compilation/enum_union_legacy_template_payload.d(14): Error: found `*` when expecting `)`
fail_compilation/enum_union_legacy_template_payload.d(14): Error: `,` or `;` expected after enum union variant
fail_compilation/enum_union_legacy_template_payload.d(14): Error: declaration expected, not `)`
---
*/

enum union List(T)
{
    case Cons(T, List(T)*);
    case Nil();
}
