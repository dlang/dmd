#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../../.."
+/
void main()
{
    import dmd.globals;
    import dmd.lexer;
    import dmd.tokens;
    import dmd.errorsink;

    immutable expected = [
        TOK.void_,
        TOK.identifier,
        TOK.leftParenthesis,
        TOK.rightParenthesis,
        TOK.leftCurly,
        TOK.rightCurly
    ];

    immutable sourceCode = "void test() {} // foobar";
    scope lexer = new Lexer("test", sourceCode.ptr, 0, sourceCode.length, 0, 0, 0, new ErrorSinkStderr);
    lexer.nextToken;

    TOK[] result;

    do
    {
        result ~= lexer.token.value;
    } while (lexer.nextToken != TOK.endOfFile);

    assert(result == expected);
}
