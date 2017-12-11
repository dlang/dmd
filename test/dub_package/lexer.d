#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../.."
+/
void main()
{
    import dmd.lexer;
    import dmd.tokens;

    immutable expected = [
        TOKvoid,
        TOKidentifier,
        TOKlparen,
        TOKrparen,
        TOKlcurly,
        TOKrcurly
    ];

    immutable sourceCode = "void test() {} // foobar";
    scope lexer = new Lexer("test", sourceCode.ptr, 0, sourceCode.length, 0, 0);
    lexer.nextToken;

    TOK[] result;

    do
    {
        result ~= lexer.token.value;
    } while (lexer.nextToken != TOKeof);

    assert(result == expected);
}
