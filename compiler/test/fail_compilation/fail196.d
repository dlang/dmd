/*
TEST_OUTPUT:
---
fail_compilation/fail196.d(38): Error: delimited string must end in `)"`
fail_compilation/fail196.d(38): Error: implicit string concatenation is error-prone and disallowed in D
fail_compilation/fail196.d(38):        Use the explicit syntax instead (concatenating literals is `@nogc`): "foo(xxx)" ~ ";\n    assert(s == "
fail_compilation/fail196.d(39): Error: semicolon needed to end declaration of `s`, instead of `foo`
fail_compilation/fail196.d(38):        `s` declared here
fail_compilation/fail196.d(39): Error: found `");\n\n    s = q"` when expecting `;` following statement
fail_compilation/fail196.d(39):        `foo(xxx)` found here
fail_compilation/fail196.d(41): Error: found `";\n    assert(s == "` when expecting `;` following statement
fail_compilation/fail196.d(41):        `[foo[xxx]]` found here
fail_compilation/fail196.d(42): Error: found `");\n\n    s = q"` when expecting `;` following statement
fail_compilation/fail196.d(42):        `foo[xxx]` found here
fail_compilation/fail196.d(44): Error: found `{` when expecting `;` following statement
fail_compilation/fail196.d(44):        `foo` found here
fail_compilation/fail196.d(44): Error: found `}` when expecting `;` following statement
fail_compilation/fail196.d(44):        `xxx` found here
fail_compilation/fail196.d(45): Error: found `foo` when expecting `;` following statement
fail_compilation/fail196.d(44):        `";\n    assert(s == "` found here
fail_compilation/fail196.d(45): Error: found `}` when expecting `;` following statement
fail_compilation/fail196.d(45):        `xxx` found here
fail_compilation/fail196.d(47): Error: found `<` when expecting `;` following statement
fail_compilation/fail196.d(45):        `");\n\n    s = q" < foo` found here
fail_compilation/fail196.d(48): Error: found `foo` when expecting `;` following statement
fail_compilation/fail196.d(47):        `xxx >> ";\n    assert(s == "` found here
fail_compilation/fail196.d(48): Error: found `<` instead of statement
fail_compilation/fail196.d(54): Error: unterminated string constant starting at fail_compilation/fail196.d(54)
fail_compilation/fail196.d(56): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/fail196.d(45):        unmatched `{`
fail_compilation/fail196.d(56): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/fail196.d(37):        unmatched `{`
---
*/

void main()
{
    string s = q"(foo(xxx)) ";
    assert(s == "foo(xxx)");

    s = q"[foo[xxx]]";
    assert(s == "foo[xxx]");

    s = q"{foo{xxx}}";
    assert(s == "foo{xxx}");

    s = q"<foo<xxx>>";
    assert(s == "foo<xxx>");

    s = q"[foo(]";
    assert(s == "foo(");

    s = q"/foo]/";
    assert(s == "foo]");
}
