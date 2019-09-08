module lexer.line_endings;

import std.traits : isNumeric;

import dmd.tokens : Token, TOK;

import support : afterEach;

@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

@("CRLF line endings")
unittest
{
    import support : stripDelimited;

    enum crLFCode = `
        #!/usr/bin/env dmd -run

        #line 4

        void main()
        {
        }

        // single-line comment

        /*
          multi-line comment
        */

        /+
          nested comment
        +/

        /**
          doc comment
        */
        void documentee() {}
    `
    .stripDelimited
    .toCRLF;

    const expected = [
        token!"#", token(4),
        token!void, identifier("main"), token!"(", token!")",
        token!"{",
        token!"}",
        comment,
        comment,
        comment,
        comment,
        token!void, identifier("documentee"), token!"(", token!")", token!"{", token!"}"
    ];

    assert(lexedTokensEqualTo(crLFCode, expected));
}

@("mixed line endings")
unittest
{
    enum code = "// mixed\n// line\r\n// endings\nvoid fun()\r{\r}";

    const expected = [
        comment, comment, comment,
        token!void, identifier("fun"), token!"(", token!")", token!"{", token!"}"
    ];

    assert(lexedTokensEqualTo(code, expected));
}

@("string containing CRLF line endings")
unittest
{
    import std.format : format;

    enum code = format!`"%s"`("\r\nfoo\r\nbar\nbaz\r\n");
    const expected = token("\nfoo\nbar\nbaz\n");

    assert(lexedTokensEqualTo(code, expected));
}

@("backquoted wysiwyg string containing CRLF line endings")
unittest
{
    import std.format : format;

    enum code = "`\r\nfoo\r\nbar\nbaz\r\n`";
    const expected = token("\nfoo\nbar\nbaz\n");

    assert(lexedTokensEqualTo(code, expected));
}

@("identifier delimited string containing CRLF line endings")
unittest
{
    import std.format : format;

    enum code = format!`q"EOF%sEOF"`("\r\nfoo\r\nbar\nbaz\r\n");
    const expected = token("foo\nbar\nbaz\n");

    assert(lexedTokensEqualTo(code, expected));
}

@("delimited string containing CRLF line endings")
unittest
{
    import std.format : format;

    enum code = format!`q"(%s)"`("\r\nfoo\r\nbar\nbaz\r\n");
    const expected = token("\nfoo\nbar\nbaz\n");

    assert(lexedTokensEqualTo(code, expected));
}

private:

enum isString(T) = is(T == string) || is(T == wstring) || is(T == dstring);

Token comment()
{
    return token(TOK.comment, "comment");
}

Token identifier(string identifier)
{
    return token(TOK.identifier, identifier);
}

Token token(T)()
{
    return token!(T.stringof);
}

Token token(string kind)()
{
    import std.format : format;
    import dmd.tokens : stringToTOK;

    enum tok = stringToTOK!kind;
    static assert(tok != TOK.max_, format!`Invalid token kind "%s"`(kind));

    return token(cast(TOK) tok, kind);
}

Token token(T)(T value, char postfix = char.init)
if (isString!T)
{
    import std.conv : to;

    Token token = {
        value: TOK.string_,
        postfix: postfix == postfix.init ? 0 : postfix
    };

    const stringValue = value.to!string;
    token.setString(stringValue.ptr, stringValue.length);

    return token;
}

Token token(T)(T value)
if (!isString!T)
{
    import std.conv : to;
    import std.format : format;

    enum missingCase = format!`Missing case for type "%s"`(T.stringof);

    Token token;

    static if (
        is(T == int) ||
        is(T == uint) ||
        is(T == long) ||
        is(T == ulong) ||
        is(T == char) ||
        is(T == wchar) ||
        is(T == dchar)
    )
    {
        token.unsvalue = value.to!(typeof(token.unsvalue));

        static if (is(T == int))
            token.value = TOK.int32Literal;
        else static if (is(T == uint))
            token.value = TOK.uns32Literal;
        else static if (is(T == long))
            token.value = TOK.int64Literal;
        else static if (is(T == ulong))
            token.value = TOK.uns64Literal;
        else static if (is(T == char))
            token.value = TOK.charLiteral;
        else static if (is(T == wchar))
            token.value = TOK.wcharLiteral;
        else static if (is(T == dchar))
            token.value = TOK.dcharLiteral;
        else
            static assert(false, missingCase);
    }

    else static if (
        is(T == float) ||
        is(T == double) ||
        is(T == real)
    )
    {
        token.floatvalue = value.to!(typeof(token.floatvalue));

        static if (is(T == float))
            token.value = TOK.float32Literal;
        else static if (is(T == double))
            token.value = TOK.float64Literal;
        else static if (is(T == real))
            token.value = TOK.float80Literal;
        else
            static assert(false, missingCase);
    }

    else static if (is(T == bool))
        return value ? token(TOK.true_, "true") : token(TOK.false_, "false");

    else
        static assert(format!`Unsupported type "%s"`(T.stringof));

    return token;
}

Token token(TOK kind, string identifier = null)
{
    import dmd.identifier : Identifier;

    if (!identifier)
        identifier = Token.toString(kind);

    Token token = {
        value: kind,
        ident: Identifier.idPool(identifier)
    };

    return token;
}

string toCRLF(string str)
{
    import std.array : join;
    import std.string : lineSplitter;

    return str.lineSplitter.join("\r\n");
}

bool lexedTokensEqualTo(string code, const Token[] tokens ...)
{
    import std.algorithm : equal;
    import dmd.lexer : Lexer;

    import support : NoopDiagnosticReporter;

    scope reporter = new NoopDiagnosticReporter;
    scope lexer = new Lexer("test", code.ptr, 0, code.length, false, true, reporter);
    lexer.popFront;

    return lexer.equal(tokens);
}
