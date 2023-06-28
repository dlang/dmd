module lexer.lexer_dmdlib;

import dmd.lexer : Lexer;
import dmd.tokens : TOK;
import dmd.errorsink;

/// Test that lexing `code` generates the `expected` tokens
private void test(string code, const TOK[] expected, bool keepComments = false, bool keepWhitespace = false)
{
    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, /*doDocComment*/ false, keepComments, keepWhitespace, new ErrorSinkStderr);
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
    ];

    test(code, expected, false, false);
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

    test(code, expected, true, false);
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

    test(code, expected, true, true);
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

    test(code, expected, true, true);
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

    test(code, expected, true, true);
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

    test(code, expected, true, true);
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

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, false, new ErrorSinkStderr, null);
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

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, true, new ErrorSinkStderr, null);
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

    Lexer lexer = new Lexer(null, code.ptr, 0, code.length, false, false, new ErrorSinkStderr, null);

    TOK[] result;

    foreach(TOK t; lexer)
    {
        result ~= t;
    }

    assert(result == expected);
    assert(lexer.empty);
}

// Issue 22495
unittest
{
    import std.conv : text, to;
    import std.string : fromStringz;

    import core.stdc.stdarg : va_list;

    import dmd.frontend;
    import dmd.location;
    import dmd.common.outbuffer;
    import dmd.console : Color;
    import dmd.errors;

    const(char)[][2][] diagnosticMessages;
    nothrow bool diagnosticHandler(const ref Loc loc, Color headerColor, const(char)* header,
                                   const(char)* format, va_list ap, const(char)* p1, const(char)* p2)
    {
        OutBuffer tmp;
        tmp.vprintf(format, ap);
        diagnosticMessages ~= [loc.filename.fromStringz, to!string(tmp.peekChars())];
        return true;
    }

    initDMD(&diagnosticHandler);
    scope(exit) deinitializeDMD();

    immutable codes = [
        "enum myString = \"\u061C\";",
        "enum myString = `\u202E\u2066 \u2069\u2066`;",
        "void test(){} // \u200E comment \u200F"
    ];

    foreach (codeNum, code; codes)
    {
        auto fileName = text("file", codeNum, '\0');
        Lexer lexer = new Lexer(fileName.ptr, code.ptr, 0, code.length, false, false, new ErrorSinkCompiler, null);
        // Generate the errors
        foreach(unused; lexer){}
    }

    string bidiErrorMessage =
        "Bidirectional control characters are disallowed for security reasons.";

    string[2][] excepted = [
        ["file0", bidiErrorMessage],
        ["file1", bidiErrorMessage],
        ["file1", bidiErrorMessage],
        ["file1", bidiErrorMessage],
        ["file1", bidiErrorMessage],
        ["file2", bidiErrorMessage],
        ["file2", bidiErrorMessage],
    ];

    assert(diagnosticMessages == excepted);
}
