/*
REQUIRED_ARGS: -verrors=0
TEST_OUTPUT:
---
fail_compilation/misc_parser_err_cov1.d(71): Error: basic type expected, not `)`
void foo(in);
           ^
fail_compilation/misc_parser_err_cov1.d(72): Error: basic type expected, not `)`
void bar(int, const @tation);
                           ^
fail_compilation/misc_parser_err_cov1.d(78): Error: `__traits(identifier, args...)` expected
    auto tt = __traits(<o<);
                       ^
fail_compilation/misc_parser_err_cov1.d(78): Error: semicolon expected following auto declaration, not `o`
    auto tt = __traits(<o<);
                        ^
fail_compilation/misc_parser_err_cov1.d(78): Error: expression expected, not `)`
    auto tt = __traits(<o<);
                          ^
fail_compilation/misc_parser_err_cov1.d(79): Error: expected `(` following `is`, not `;`
fail_compilation/misc_parser_err_cov1.d(80): Error: semicolon expected following auto declaration, not `auto`
    auto mx1 = mixin +);
    ^
fail_compilation/misc_parser_err_cov1.d(80): Error: found `+` when expecting `(` following `mixin`
    auto mx1 = mixin +);
                     ^
fail_compilation/misc_parser_err_cov1.d(82): Error: `key:value` expected for associative array literal
    aa +=  [key:value, key];
                          ^
fail_compilation/misc_parser_err_cov1.d(83): Error: basic type expected, not `;`
fail_compilation/misc_parser_err_cov1.d(83): Error: `{ members }` expected for anonymous class
fail_compilation/misc_parser_err_cov1.d(85): Error: template argument expected following `!`
    if (parseShift !if){}
                    ^
fail_compilation/misc_parser_err_cov1.d(85): Error: missing closing `)` after `if (parseShift!()`
    if (parseShift !if){}
                    ^
fail_compilation/misc_parser_err_cov1.d(85): Error: found `)` when expecting `(`
    if (parseShift !if){}
                      ^
fail_compilation/misc_parser_err_cov1.d(86): Error: missing closing `)` after `if (`
    auto unaryExParseError = immutable(int).+;
    ^
fail_compilation/misc_parser_err_cov1.d(86): Error: identifier expected following `immutable(int).`, not `+`
    auto unaryExParseError = immutable(int).+;
                                            ^
fail_compilation/misc_parser_err_cov1.d(86): Error: expression expected, not `;`
fail_compilation/misc_parser_err_cov1.d(87): Error: semicolon expected following auto declaration, not `auto`
    auto postFixParseError = int.max.+;
    ^
fail_compilation/misc_parser_err_cov1.d(87): Error: identifier or `new` expected following `.`, not `+`
    auto postFixParseError = int.max.+;
                                     ^
fail_compilation/misc_parser_err_cov1.d(88): Error: identifier or new keyword expected following `(...)`.
    (int).+;
         ^
fail_compilation/misc_parser_err_cov1.d(88): Error: expression expected, not `;`
fail_compilation/misc_parser_err_cov1.d(89): Error: found `}` when expecting `;` following expression
fail_compilation/misc_parser_err_cov1.d(88):        expression: `(__error) + (__error)`
    (int).+;
    ^
fail_compilation/misc_parser_err_cov1.d(90): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/misc_parser_err_cov1.d(75):        unmatched `{`
---
*/
module misc_parser_err_cov1;


//https://issues.dlang.org/show_bug.cgi?id=19995
// Line 29 starts here
void foo(in);
void bar(int, const @tation);

void main()
{
    // cover errors from line 7930 to EOF
    // Line 31 starts here
    auto tt = __traits(<o<);
    auto b = is ;
    auto mx1 = mixin +);

    aa +=  [key:value, key];
    auto anon1 = new class;
    auto anon2 = new class {};
    if (parseShift !if){}
    auto unaryExParseError = immutable(int).+;
    auto postFixParseError = int.max.+;
    (int).+;
}
