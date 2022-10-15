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

// Issue 22495
unittest
{
    import std.conv : text, to;
    import std.string : fromStringz;

    import core.stdc.stdarg : va_list;

    import dmd.frontend;
    import dmd.globals : Loc;
    import dmd.common.outbuffer;
    import dmd.console : Color;

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
        "void test(){} // \u200E comment \u200F",
        "#!usr/bin/env dmd # \u200E comment \u200F\nvoid test(){}",
        // Make sure shebang being invalid UTF-8 does not stop vigilance with
        // bidi chars in there.
        "#!usr/\x80\x85\x8A/env dmd # \u200E comment \xFF\u200F\nvoid test(){}"
    ];

    foreach (codeNum, code; codes)
    {
        auto fileName = text("file", codeNum, '\0');
        Lexer lexer = new Lexer(fileName.ptr, code.ptr, 0, code.length, false, false);
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
        ["file3", bidiErrorMessage],
        ["file3", "character 0x200e is not a valid token"],
        ["file3", bidiErrorMessage],
        ["file3", "character 0x200f is not a valid token"],
        ["file4", bidiErrorMessage],
        ["file4", "character 0x200e is not a valid token"],
        ["file4", "Outside Unicode code space"],
        ["file4", bidiErrorMessage],
        ["file4", "char 0x200f not allowed in identifier"],
        ["file4", bidiErrorMessage],
        ["file4", "character 0x200f is not a valid token"]
    ];

    //assert(0, diagnosticMessages.to!string);
    assert(diagnosticMessages == excepted);
}
