#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../.."
+/
void main()
{
    import dmd.errors;
    import dmd.globals;
    import dmd.lexer;
    import dmd.tokens;

    immutable expected = [
        TOK.void_,
        TOK.identifier,
        TOK.leftParentheses,
        TOK.rightParentheses,
        TOK.leftCurly,
        TOK.rightCurly
    ];

    immutable sourceCode = "void test() {} // foobar";
    scope diagnosticReporter = new StderrDiagnosticReporter(global.params.useDeprecated);
    scope lexer = new Lexer("test", sourceCode.ptr, 0, sourceCode.length, 0, 0, diagnosticReporter);
    lexer.nextToken;

    TOK[] result;

    do
    {
        result ~= lexer.token.value;
    } while (lexer.nextToken != TOK.endOfFile);

    assert(result == expected);
}
