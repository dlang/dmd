/**
 * Tests for Token quality.
 *
 * Most of the tests in this module are generated based on a description.
 */
module lexer.token.equality;

import dmd.frontend : deinitializeDMD;
import dmd.globals : Loc;
import dmd.tokens : TOK;

import support : afterEach;

@afterEach deinitializeFrontend()
{
    deinitializeDMD();
}

/**
 * Contains the necessary information to generate a unit test block.
 *
 * The generated test will test a single token by:
 *
 * * Setting up two lexers
 * * Lex the first token in both lexers
 * * Test the two tokens for equality
 *
 * Example of a generate unit test block:
 * ---
 * @("left parentheses, (")
 * unittest
 * {
 *      assert(isFirstTokenEqual("(", ")", false));
 * }
 * ---
 */
immutable struct Test
{
    /**
     * The description of the unit test.
     *
     * This will go into the UDA attached to the `unittest` block.
     */
    string description_;

    /**
     * The code for the first lexer.
     *
     * Optional. If the code is not provided the description will be used.
     * Useful when the description and the code is exactly the same, i.e. for
     * keywords.
     */
    string code1_ = null;

    /**
     * The code for the first lexer.
     *
     * Optional. If the code is not provided, `code1` will be used.
     */
    string code2 = null;

    /**
     * An example of the token that is tested.
     *
     * Optional. If the example is not provided, `code1` will be used.
     */
    string tokenExample = null;

    /**
     * Allow failed diagnostics.
     *
     * If this is `false` and the lexer reports a diagnostic, an assertion is
     * triggered.
     */
    bool allowFailedDiagnostics = false;

    /// Returns: the code for the first lexer
    string code1()
    {
        return code1_ ? code1_ : description_;
    }

    /// Returns: the description
    string description()
    {
        const example = tokenExample ? tokenExample : code1;

        if (example == description_)
            return example;
        else
            return description_ ~ ", " ~ example;
    }
}

/**
 * Contains the necessary information to generate a unit test block.
 *
 * The generated test will test a single token for a floating point literal of
 * various kinds. The content of the token is `NaN`.
 *
 * Example of a generated unit test block:
 * ---
 * @("32 bit floating point literal with NaN as its content")
 * unittest
 * {
 *     import dmd.tokens : Token;
 *
 *     Token token1 = {
 *         value: TOK.float32Literal,
 *         floatvalue: Token.floatvalue.nan
 *     };
 *
 *     auto token2 = token1;
 *
 *     assert(token1 == token2);
 * }
 * ---
 */
immutable struct NaNTest
{
    /// The description of the test.
    string description;

    /// The kind of token (`value`).
    TOK kind;
}

enum Test hexadecimalStringLiteral = {
    description_: "hexadecimal string literal",
    code1_: `x"61"`,
    // allow failed diagnostics because this is now an error. But it's still
    // recognized by the lexer and the lexer will create a token when this error
    // occurs.
    allowFailedDiagnostics: true
};

/// Tests for all different kinds of tokens.
enum tests = [
    Test("left parentheses", "("),
    Test("right parentheses", ")"),
    Test("left square bracket", "["),
    Test("right square bracket", "]"),
    Test("left curly brace", "{"),
    Test("right curly brace", "{"),
    Test("colon", ":"),
    Test("negate", "!"),
    Test("semicolon", ";"),
    Test("triple dot", "..."),
    Test("end of file", "\u001A", "\0"),
    Test("cast"),
    Test("null"),
    Test("assert"),
    Test("true"),
    Test("false"),
    Test("throw"),
    Test("new"),
    Test("delete"),
    Test("new"),
    Test("slice", ".."),
    Test("version"),
    Test("module"),
    Test("dollar", "$"),
    Test("template"),
    Test("typeof"),
    Test("pragma"),
    Test("typeid"),

    Test("less than", "<"),
    Test("greater then", ">"),
    Test("less then or equal", "<="),
    Test("greater then or equal", ">="),
    Test("equal", "=="),
    Test("not equal", "!="),
    Test("identify", "is"),
    Test("not identify", "!is"),
    Test("left shift", "<<"),
    Test("right shift", ">>"),
    Test("left shift assign", "<<="),
    Test("right shift assign", ">>="),
    Test("unsigned right shift", ">>>"),
    Test("unsigned right shift assign", ">>>="),
    Test("concatenate assign", "~="),
    Test("plus", "+"),
    Test("minus", "-"),
    Test("plus assign", "+="),
    Test("minus assign", "-="),
    Test("multiply", "*"),
    Test("divide", "/"),
    Test("modulo", "%"),
    Test("multiply assign", "*="),
    Test("divide assign", "/="),
    Test("modulo assign", "%="),
    Test("and", "&"),
    Test("or", "|"),
    Test("xor", "^"),
    Test("and assign", "&="),
    Test("or assign", "|="),
    Test("xor assign", "^="),
    Test("assign", "="),
    Test("not", "!"),
    Test("tilde", "~"),
    Test("plus plus", "++"),
    Test("minus minus", "--"),
    Test("dot", "."),
    Test("comma", ","),
    Test("question mark", "?"),
    Test("and and", "&&"),
    Test("or or", "||"),

    Test("32 bit integer literal", "0"),
    Test("32 bit unsigned integer literal", "0U"),
    Test("64 bit integer literal", "0L"),
    Test("64 bit unsigned integer literal", "0UL"),
    Test("32 bit floating point literal", "0.0f"),
    Test("64 bit floating point literal", "0.0"),
    Test("80 bit floating point literal", "0.0L"),
    Test("32 bit imaginary floating point literal", "0.0fi"),
    Test("64 bit imaginary floating point literal", "0.0i"),
    Test("80 bit imaginary floating point literal", "0.0Li"),

    Test("character literal", "'a'"),
    Test("wide character literal", "'ö'"),
    Test("double wide character literal", "'🍺'"),

    Test("identifier", "foo"),
    Test("string literal", `"foo"`),
    hexadecimalStringLiteral,
    Test("this"),
    Test("super"),

    Test("void"),
    Test("byte"),
    Test("ubyte"),
    Test("short"),
    Test("ushort"),
    Test("int"),
    Test("uint"),
    Test("long"),
    Test("ulong"),
    Test("cent"),
    Test("ucent"),
    Test("float"),
    Test("double"),
    Test("real"),
    Test("ifloat"),
    Test("idouble"),
    Test("ireal"),
    Test("cfloat"),
    Test("cdouble"),
    Test("creal"),
    Test("char"),
    Test("wchar"),
    Test("dchar"),
    Test("bool"),

    Test("struct"),
    Test("class"),
    Test("interface"),
    Test("union"),
    Test("enum"),
    Test("import"),
    Test("alias"),
    Test("override"),
    Test("delegate"),
    Test("function"),
    Test("mixin"),
    Test("align"),
    Test("extern"),
    Test("private"),
    Test("protected"),
    Test("public"),
    Test("export"),
    Test("static"),
    Test("final"),
    Test("const"),
    Test("abstract"),
    Test("debug"),
    Test("deprecated"),
    Test("in"),
    Test("out"),
    Test("inout"),
    Test("lazy"),
    Test("auto"),
    Test("package"),
    Test("immutable"),

    Test("if"),
    Test("else"),
    Test("while"),
    Test("for"),
    Test("do"),
    Test("switch"),
    Test("case"),
    Test("default"),
    Test("break"),
    Test("continue"),
    Test("with"),
    Test("synchronized"),
    Test("return"),
    Test("goto"),
    Test("try"),
    Test("catch"),
    Test("finally"),
    Test("asm"),
    Test("foreach"),
    Test("foreach_reverse"),
    Test("scope"),

    Test("invariant"),

    Test("unittest"),

    Test("__argTypes"),
    Test("ref"),
    Test("macro"),

    Test("__parameters"),
    Test("__traits"),
    Test("__overloadset"),
    Test("pure"),
    Test("nothrow"),
    Test("__gshared"),

    Test("__LINE__"),
    Test("__FILE__"),
    Test("__FILE_FULL_PATH__"),
    Test("__MODULE__"),
    Test("__FUNCTION__"),
    Test("__PRETTY_FUNCTION__"),

    Test("shared"),
    Test("at sign", "@"),
    Test("power", "^^"),
    Test("power assign", "^^="),
    Test("fat arrow", "=>"),
    Test("__vector"),
    Test("pound", "#"),

    Test("32 bit integer literal with 0 prefix", "01", "1"),
    Test("32 bit unsigned integer literal with 0 prefix", "01U", "1U"),
    Test("64 bit integer literal with 0 prefix", "01L", "1L"),
    Test("64 bit unsigned integer literal with 0 prefix", "01UL", "1UL"),
    Test("32 bit floating point literal with 0 prefix", "01.0f", "1.0f"),
    Test("64 bit floating point literal with 0 prefix", "01.0", "1.0"),
    Test("80 bit floating point literal with 0 prefix", "01.0L", "1.0L"),
    Test("32 bit imaginary floating point literal with 0 prefix", "01.0fi", "1.0fi"),
    Test("64 bit imaginary floating point literal with 0 prefix", "01.0i", "1.0i"),
    Test("80 bit imaginary floating point literal with 0 prefix", "01.0Li", "1.0Li"),
];

static foreach (test; tests)
{
    @(test.description)
    unittest
    {
        assert(isFirstTokenEqual(test.code1, test.code2, test.allowFailedDiagnostics));
    }
}

/// Tests for floating point literals where the content is `NaN`.
enum nanTests = [
    NaNTest(
        "32 bit floating point literal with NaN as its content",
        TOK.float32Literal
    ),

    NaNTest(
        "64 bit floating point literal with NaN as its content",
        TOK.float64Literal
    ),

    NaNTest(
        "80 bit floating point literal with NaN as its content",
        TOK.float80Literal
    ),

    NaNTest(
        "32 bit imaginary floating point literal with NaN as its content",
        TOK.imaginary32Literal
    ),

    NaNTest(
        "64 bit imaginary floating point literal with NaN as its content",
        TOK.imaginary64Literal
    ),

    NaNTest(
        "80 bit imaginary floating point literal with NaN as its content",
        TOK.imaginary80Literal
    ),
];

static foreach (test; nanTests)
{
    @(test.description)
    unittest
    {
        import dmd.tokens : Token;

        Token token1 = {
            value: test.kind,
            floatvalue: Token.floatvalue.nan
        };

        auto token2 = token1;

        assert(token1 == token2);
    }
}

/**
 * Returns `true` if the first token of the two code strings are equal.
 *
 * This will:
 *
 * * Setup up two lexers
 * * Lex the first token in both lexers
 * * Test the two tokens for equality
 *
 * Params:
 *  code1 = the code for the first lexer
 *  code2 = the code for the second lexer
 *  allowFailedDiagnostics = if `false` and any of the lexers generates a
 *      diagnostic, an assertion is triggered
 */
bool isFirstTokenEqual(string code1, string code2, bool allowFailedDiagnostics)
{
    import dmd.lexer : Lexer;
    import dmd.tokens : Token;
    import support : CollectingDiagnosticReporter;

    Token lexFirstToken(string code)
    {
        scope reporter = new CollectingDiagnosticReporter;
        scope lexer = new Lexer("test", code.ptr, 0, code.length, false, true, reporter);
        lexer.nextToken();

        if (!allowFailedDiagnostics)
            assert(reporter.diagnostics.empty, '\n' ~ reporter.diagnostics.toString);

        deinitializeDMD();

        return lexer.token;
    }

    if (!code2)
        code2 = code1;

    return lexFirstToken(code1) == lexFirstToken(code2);
}
