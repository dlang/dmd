/*
TEST_OUTPUT:
---
fail_compilation/fail196.d(25): Error: delimited string must end in )"
fail_compilation/fail196.d(25): Error: Implicit string concatenation is deprecated, use "foo(xxx)" ~ ";\x0a    assert(s == " instead
fail_compilation/fail196.d(26): Error: semicolon expected, not `foo`
fail_compilation/fail196.d(26): Error: found `");\x0a\x0a    s = q"` when expecting `;` following statement
fail_compilation/fail196.d(28): Error: found `";\x0a    assert(s == "` when expecting `;` following statement
fail_compilation/fail196.d(29): Error: found `");\x0a\x0a    s = q"` when expecting `;` following statement
fail_compilation/fail196.d(31): Error: found `{` when expecting `;` following statement
fail_compilation/fail196.d(31): Error: found `}` when expecting `;` following statement
fail_compilation/fail196.d(32): Error: found `foo` when expecting `;` following statement
fail_compilation/fail196.d(32): Error: found `}` when expecting `;` following statement
fail_compilation/fail196.d(34): Error: found `<` when expecting `;` following statement
fail_compilation/fail196.d(35): Error: found `foo` when expecting `;` following statement
fail_compilation/fail196.d(35): Error: found `<` instead of statement
fail_compilation/fail196.d(41): Error: unterminated string constant starting at fail_compilation/fail196.d(41)
fail_compilation/fail196.d(43): Error: found `End of File` when expecting `}` following compound statement
fail_compilation/fail196.d(43): Error: found `End of File` when expecting `}` following compound statement
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
