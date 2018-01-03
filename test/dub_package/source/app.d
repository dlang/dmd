// The tests in this module are highlevel and mostly indented to make sure all
// necessary modules are included in the Dub package.

void main()
{
}

// lexer
unittest
{
    import ddmd.lexer;
    import ddmd.tokens;

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

// parser
unittest
{
    import ddmd.astbase;
    import ddmd.parse;

    scope parser = new Parser!ASTBase(null, null, false);
    assert(parser !is null);
}
