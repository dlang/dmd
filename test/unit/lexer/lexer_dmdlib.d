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
