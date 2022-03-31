module lexer.dmdlib_lexer_test;

import dmd.dmdlib_lexer;
import dmd.tokens : TOK;

unittest
{
    immutable code = "void test() {} // foobar";

    immutable expected = [
        TOK.void_,
        TOK.identifier,
        TOK.leftParenthesis,
        TOK.rightParenthesis,
        TOK.leftCurly,
        TOK.rightCurly,
    ];

    LexerConfig config = { doc : false, comm : CommentOptions.None, ws : WhitespaceOptions.None };
    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, config);
    TOK[] result;

    while (lexer.nextToken != TOK.endOfFile)
        result ~= lexer.token.value;

    assert(result == expected);
}

unittest
{
    immutable code = "void test() {} // foobar";

    immutable expected = [
        TOK.void_,
        TOK.identifier,
        TOK.leftParenthesis,
        TOK.rightParenthesis,
        TOK.leftCurly,
        TOK.rightCurly,
        TOK.comment,
    ];

    LexerConfig config = { doc : false, comm : CommentOptions.All, ws : WhitespaceOptions.None };
    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, config);
    TOK[] result;

    while (lexer.nextToken != TOK.endOfFile)
        result ~= lexer.token.value;

    assert(result == expected);
}

unittest
{
    immutable code = "void test() {} // foobar";

    TOK[] expected = [
        TOK.void_,
        TOK.whitespace,
        TOK.identifier,
        TOK.leftParenthesis,
        TOK.rightParenthesis,
        TOK.whitespace,
        TOK.leftCurly,
        TOK.rightCurly,
        TOK.whitespace,
        TOK.comment,
    ];

    LexerConfig config = { doc : false, comm : CommentOptions.All, ws : WhitespaceOptions.All };
    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, config);
    TOK[] result;

    while (lexer.nextToken != TOK.endOfFile)
        result ~= lexer.token.value;

    assert(result == expected);
}

unittest
{
    immutable code = "void test() {} // foobar\n";

    TOK[] expected = [
        TOK.void_,
        TOK.whitespace,
        TOK.identifier,
        TOK.leftParenthesis,
        TOK.rightParenthesis,
        TOK.whitespace,
        TOK.leftCurly,
        TOK.rightCurly,
        TOK.whitespace,
        TOK.comment,
        TOK.endOfLine,
    ];

    LexerConfig config = { doc : false, comm : CommentOptions.All, ws : WhitespaceOptions.All };
    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, config);
    TOK[] result;

    while (lexer.nextToken != TOK.endOfFile)
        result ~= lexer.token.value;

    assert(result == expected);
}

unittest
{
    immutable code =
        "void test()\n"
        ~ "{\n"
        ~ "\tint a = 5; // some comment\n"
        ~ "} // another comment\n";

    TOK[] expected = [
        TOK.void_,
        TOK.whitespace,
        TOK.identifier,
        TOK.leftParenthesis,
        TOK.rightParenthesis,
        TOK.endOfLine,
        TOK.leftCurly,
        TOK.endOfLine,
        TOK.whitespace,
        TOK.int32,
        TOK.whitespace,
        TOK.identifier,
        TOK.whitespace,
        TOK.assign,
        TOK.whitespace,
        TOK.int32Literal,
        TOK.semicolon,
        TOK.whitespace,
        TOK.comment,
        TOK.endOfLine,
        TOK.rightCurly,
        TOK.whitespace,
        TOK.comment,
        TOK.endOfLine,
    ];

    LexerConfig config = { doc : false, comm : CommentOptions.All, ws : WhitespaceOptions.All };
    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, config);
    TOK[] result;

    while (lexer.nextToken != TOK.endOfFile)
        result ~= lexer.token.value;

    assert(result == expected);
}

unittest
{
    immutable code =
        "\n"
        ~ "\n;"
        ~ "\t;\t\r// some comment\n"
        ~ "\v\f\r// another comment\n\n";

    TOK[] expected = [
        TOK.endOfLine,
        TOK.endOfLine,
        TOK.semicolon,
        TOK.whitespace,
        TOK.semicolon,
        TOK.whitespace,
        TOK.endOfLine,
        TOK.comment,
        TOK.endOfLine,
        TOK.whitespace,
        TOK.whitespace,
        TOK.endOfLine,
        TOK.comment,
        TOK.endOfLine,
        TOK.endOfLine,
    ];

    LexerConfig config = { doc : false, comm : CommentOptions.All, ws : WhitespaceOptions.All };
    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, config);
    TOK[] result;

    while (lexer.nextToken != TOK.endOfFile)
        result ~= lexer.token.value;

    assert(result == expected);
}

unittest
{
    immutable code =
        "\n"
        ~ "\n;"
        ~ "\t;\t\r// some comment\n"
        ~ "\v\f\r// another comment\n\n"
        ~ "/* and other comments *//* .. */";

    TOK[] expected = [
        TOK.endOfLine,
        TOK.endOfLine,
        TOK.semicolon,
        TOK.semicolon,
        TOK.endOfLine,
        TOK.comment,
        TOK.endOfLine,
        TOK.endOfLine,
        TOK.comment,
        TOK.endOfLine,
        TOK.endOfLine,
        TOK.comment,
    ];

    LexerConfig config = { doc : false, comm : CommentOptions.AllCondensed, ws : WhitespaceOptions.OnlyNewLines };
    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, config);
    TOK[] result;

    while (lexer.nextToken != TOK.endOfFile)
        result ~= lexer.token.value;

    import std.stdio : writeln;
    writeln(result);

    assert(result == expected);
}

unittest
{
    immutable code =
        "\n"
        ~ "\n;"
        ~ "\t;\t\r// some comment\n"
        ~ "\v\f\r// another comment\n\n"
        ~ "/* and other comments *//* .. */";

    TOK[] expected = [
        TOK.endOfLine,
        TOK.semicolon,
        TOK.whitespace,
        TOK.semicolon,
        TOK.whitespace,
        TOK.endOfLine,
        TOK.comment,
        TOK.endOfLine,
        TOK.whitespace,
        TOK.endOfLine,
        TOK.comment,
        TOK.endOfLine,
        TOK.comment,
    ];

    LexerConfig config = { doc : false, comm : CommentOptions.AllCondensed, ws : WhitespaceOptions.AllCondensed };
    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, config);
    TOK[] result;

    while (lexer.nextToken != TOK.endOfFile)
        result ~= lexer.token.value;

    import std.stdio : writeln;
    writeln(result);

    assert(result == expected);
}

unittest
{
    immutable code =
        "// some comment\n"
        ~ "// another comment\n\n"
        ~ "/* and other comments *//* .. */";

    TOK[] expected = [
        TOK.comment,
    ];

    LexerConfig config = { doc : false, comm : CommentOptions.AllCondensed, ws : WhitespaceOptions.None };
    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, config);
    TOK[] result;

    while (lexer.nextToken != TOK.endOfFile)
        result ~= lexer.token.value;

    assert(result == expected);
}

unittest
{
    immutable code = "void test() {}";

    immutable expected = [
        TOK.void_,
        TOK.identifier,
        TOK.leftParenthesis,
        TOK.rightParenthesis,
        TOK.leftCurly,
        TOK.rightCurly,
    ];

    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, false, false);
    lexer.nextToken;

    TOK[] result;

    foreach(TOK t; lexer)
    {
        result ~= t;
    }

    assert(result == expected);
}

unittest
{
    immutable code = "// some comment";

    immutable expected = [
        TOK.comment,
    ];

    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, false, true);
    lexer.nextToken;

    TOK[] result;

    foreach(TOK t; lexer)
    {
        result ~= t;
    }

    assert(result == expected);
    assert(lexer.empty);
    lexer.popFront;
    assert(lexer.empty);
    lexer.popFront;
    assert(lexer.empty);
}

unittest
{
    immutable code = "";

    immutable expected = [
        TOK.reserved,
    ];

    ConfigurableLexer lexer = new ConfigurableLexer(null, code.ptr, 0, code.length, false, false);

    TOK[] result;

    foreach(TOK t; lexer)
    {
        result ~= t;
    }

    assert(result == expected);
    assert(lexer.empty);
}
