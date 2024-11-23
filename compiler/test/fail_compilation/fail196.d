/*
TEST_OUTPUT:
---
fail_compilation/fail196.d(88): Error: delimited string must end in `)"`
    string s = q"(foo(xxx)) ";
               ^
fail_compilation/fail196.d(88): Error: implicit string concatenation is error-prone and disallowed in D
    string s = q"(foo(xxx)) ";
                            ^
fail_compilation/fail196.d(88):        Use the explicit syntax instead (concatenating literals is `@nogc`): "foo(xxx)" ~ ";\n    assert(s == "
fail_compilation/fail196.d(89): Error: semicolon needed to end declaration of `s`, instead of `foo`
    assert(s == "foo(xxx)");
                 ^
fail_compilation/fail196.d(88):        `s` declared here
    string s = q"(foo(xxx)) ";
           ^
fail_compilation/fail196.d(89): Error: found `");\n\n    s = q"` when expecting `;` following expression
    assert(s == "foo(xxx)");
                         ^
fail_compilation/fail196.d(89):        expression: `foo(xxx)`
    assert(s == "foo(xxx)");
                    ^
fail_compilation/fail196.d(91): Error: found `";\n    assert(s == "` when expecting `;` following expression
    s = q"[foo[xxx]]";
                    ^
fail_compilation/fail196.d(91):        expression: `[foo[xxx]]`
    s = q"[foo[xxx]]";
          ^
fail_compilation/fail196.d(92): Error: found `");\n\n    s = q"` when expecting `;` following expression
    assert(s == "foo[xxx]");
                         ^
fail_compilation/fail196.d(92):        expression: `foo[xxx]`
    assert(s == "foo[xxx]");
                    ^
fail_compilation/fail196.d(94): Error: found `{` when expecting `;` following expression
    s = q"{foo{xxx}}";
              ^
fail_compilation/fail196.d(94):        expression: `foo`
    s = q"{foo{xxx}}";
           ^
fail_compilation/fail196.d(94): Error: found `}` when expecting `;` following expression
    s = q"{foo{xxx}}";
                  ^
fail_compilation/fail196.d(94):        expression: `xxx`
    s = q"{foo{xxx}}";
               ^
fail_compilation/fail196.d(95): Error: found `foo` when expecting `;` following expression
    assert(s == "foo{xxx}");
                 ^
fail_compilation/fail196.d(94):        expression: `";\n    assert(s == "`
    s = q"{foo{xxx}}";
                    ^
fail_compilation/fail196.d(95): Error: found `}` when expecting `;` following expression
    assert(s == "foo{xxx}");
                        ^
fail_compilation/fail196.d(95):        expression: `xxx`
    assert(s == "foo{xxx}");
                     ^
fail_compilation/fail196.d(97): Error: found `<` when expecting `;` following expression
    s = q"<foo<xxx>>";
              ^
fail_compilation/fail196.d(95):        expression: `");\n\n    s = q" < foo`
    assert(s == "foo{xxx}");
                         ^
fail_compilation/fail196.d(98): Error: found `foo` when expecting `;` following expression
    assert(s == "foo<xxx>");
                 ^
fail_compilation/fail196.d(97):        expression: `xxx >> ";\n    assert(s == "`
    s = q"<foo<xxx>>";
               ^
fail_compilation/fail196.d(98): Error: found `<` instead of statement
    assert(s == "foo<xxx>");
                    ^
fail_compilation/fail196.d(104): Error: unterminated string constant starting at fail_compilation/fail196.d(104)
    assert(s == "foo]");
                     ^
fail_compilation/fail196.d(106): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/fail196.d(95):        unmatched `{`
    assert(s == "foo{xxx}");
                    ^
fail_compilation/fail196.d(106): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/fail196.d(87):        unmatched `{`
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
