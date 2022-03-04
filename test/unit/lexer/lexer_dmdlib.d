module lexer.lexer_dmdlib;

import dmd.lexer : Lexer;
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

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, false, false);
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

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, true, false);
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

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, true, true);
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
        TOK.whitespace,
    ];

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, true, true);
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
        TOK.whitespace,
        TOK.leftCurly,
        TOK.whitespace,
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
        TOK.whitespace,
        TOK.rightCurly,
        TOK.whitespace,
        TOK.comment,
        TOK.whitespace,
    ];

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, true, true);
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
        TOK.whitespace,
        TOK.whitespace,
        TOK.semicolon,
        TOK.whitespace,
        TOK.semicolon,
        TOK.whitespace,
        TOK.whitespace,
        TOK.comment,
        TOK.whitespace,
        TOK.whitespace,
        TOK.whitespace,
        TOK.whitespace,
        TOK.comment,
        TOK.whitespace,
        TOK.whitespace,
    ];

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, true, true);
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

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, false);
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

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, true);
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

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, false);

    TOK[] result;

    foreach(TOK t; lexer)
    {
        result ~= t;
    }

    assert(result == expected);
    assert(lexer.empty);
}
