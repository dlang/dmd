/**
 * Defines lexical tokens.
 *
 * Specification: $(LINK2 https://dlang.org/spec/lex.html#tokens, Tokens)
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/tokens.d, _tokens.d)
 * Documentation:  https://dlang.org/phobos/dmd_tokens.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/tokens.d
 */

module dmd.tokens;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import dmd.identifier;
import dmd.location;
import dmd.root.ctfloat;
import dmd.common.outbuffer;
import dmd.root.rmem;
import dmd.root.utf;

enum TOK : ubyte
{
    reserved,

    // if this list changes, update
    // tokens.h, ../tests/cxxfrontend.cc and ../../test/unit/lexer/location_offset.d to match

    // Other
    leftParenthesis,
    rightParenthesis,
    leftBracket,
    rightBracket,
    leftCurly,
    rightCurly,
    colon,
    semicolon,
    dotDotDot,
    endOfFile,
    cast_,
    null_,
    assert_,
    true_,
    false_,
    throw_,
    new_,
    variable,
    slice,
    version_,
    module_,
    dollar,
    template_,
    typeof_,
    pragma_,
    typeid_,
    comment,

    // Operators
    lessThan,
    greaterThan,
    lessOrEqual,
    greaterOrEqual,
    equal,
    notEqual,
    identity,
    notIdentity,
    is_,

    leftShift,
    rightShift,
    leftShiftAssign,
    rightShiftAssign,
    unsignedRightShift,
    unsignedRightShiftAssign,
    concatenateAssign, // ~=
    add,
    min,
    addAssign,
    minAssign,
    mul,
    div,
    mod,
    mulAssign,
    divAssign,
    modAssign,
    and,
    or,
    xor,
    andAssign,
    orAssign,
    xorAssign,
    assign,
    not,
    tilde,
    plusPlus,
    minusMinus,
    dot,
    comma,
    question,
    andAnd,
    orOr,

    // Numeric literals
    int32Literal,
    uns32Literal,
    int64Literal,
    uns64Literal,
    int128Literal,
    uns128Literal,
    float32Literal,
    float64Literal,
    float80Literal,
    imaginary32Literal,
    imaginary64Literal,
    imaginary80Literal,

    // Char constants
    charLiteral,
    wcharLiteral,
    dcharLiteral,

    // Leaf operators
    identifier,
    string_,
    interpolated,
    hexadecimalString,
    this_,
    super_,
    error,

    // Basic types
    void_,
    int8,
    uns8,
    int16,
    uns16,
    int32,
    uns32,
    int64,
    uns64,
    int128,
    uns128,
    float32,
    float64,
    float80,
    imaginary32,
    imaginary64,
    imaginary80,
    complex32,
    complex64,
    complex80,
    char_,
    wchar_,
    dchar_,
    bool_,

    // Aggregates
    struct_,
    class_,
    interface_,
    union_,
    enum_,
    import_,
    alias_,
    override_,
    delegate_,
    function_,
    mixin_,
    align_,
    extern_,
    private_,
    protected_,
    public_,
    export_,
    static_,
    final_,
    const_,
    abstract_,
    debug_,
    deprecated_,
    in_,
    out_,
    inout_,
    lazy_,
    auto_,
    package_,
    immutable_,

    // Statements
    if_,
    else_,
    while_,
    for_,
    do_,
    switch_,
    case_,
    default_,
    break_,
    continue_,
    with_,
    synchronized_,
    return_,
    goto_,
    try_,
    catch_,
    finally_,
    asm_,
    foreach_,
    foreach_reverse_,
    scope_,
    onScopeExit,
    onScopeFailure,
    onScopeSuccess,

    // Contracts
    invariant_,

    // Testing
    unittest_,

    // Added after 1.0
    argumentTypes,
    ref_,
    macro_,

    parameters,
    traits,
    pure_,
    nothrow_,
    gshared,
    line,
    file,
    fileFullPath,
    moduleString,   // __MODULE__
    functionString, // __FUNCTION__
    prettyFunction, // __PRETTY_FUNCTION__
    shared_,
    at,
    pow,
    powAssign,
    goesTo,
    vector,
    pound,

    arrow,      // ->
    colonColon, // ::
    wchar_tLiteral,
    endOfLine,  // \n, \r, \u2028, \u2029
    whitespace,
    rvalue,

    // C only keywords
    inline,
    register,
    restrict,
    signed,
    sizeof_,
    typedef_,
    unsigned,
    volatile,
    _Alignas,
    _Alignof,
    _Atomic,
    _Bool,
    _Complex,
    _Generic,
    _Imaginary,
    _Noreturn,
    _Static_assert,
    _Thread_local,

    // C only extended keywords
    _assert,
    _import,
    _module,
    __cdecl,
    __declspec,
    __stdcall,
    __thread,
    __pragma,
    __int128,
    __attribute__,
}

/// Expression nodes
enum EXP : ubyte
{
    reserved,

    // Other
    negate,
    cast_,
    null_,
    assert_,
    array,
    call,
    address,
    type,
    throw_,
    new_,
    delete_,
    star,
    symbolOffset,
    variable,
    dotVariable,
    dotIdentifier,
    dotTemplateInstance,
    dotType,
    slice,
    arrayLength,
    dollar,
    template_,
    dotTemplateDeclaration,
    declaration,
    dSymbol,
    typeid_,
    uadd,
    remove,
    newAnonymousClass,
    arrayLiteral,
    assocArrayLiteral,
    structLiteral,
    classReference,
    thrownException,
    delegatePointer,
    delegateFunctionPointer,

    // Operators
    lessThan,
    greaterThan,
    lessOrEqual,
    greaterOrEqual,
    equal,
    notEqual,
    identity,
    notIdentity,
    index,
    is_,

    leftShift,
    rightShift,
    leftShiftAssign,
    rightShiftAssign,
    unsignedRightShift,
    unsignedRightShiftAssign,
    concatenate,
    concatenateAssign, // ~=
    concatenateElemAssign,
    concatenateDcharAssign,
    add,
    min,
    addAssign,
    minAssign,
    mul,
    div,
    mod,
    mulAssign,
    divAssign,
    modAssign,
    and,
    or,
    xor,
    andAssign,
    orAssign,
    xorAssign,
    assign,
    not,
    tilde,
    plusPlus,
    minusMinus,
    construct,
    blit,
    dot,
    comma,
    question,
    andAnd,
    orOr,
    prePlusPlus,
    preMinusMinus,

    // Leaf operators
    identifier,
    string_,
    interpolated,
    this_,
    super_,
    halt,
    tuple,
    error,

    // Basic types
    void_,
    int64,
    float64,
    complex80,
    import_,
    delegate_,
    function_,
    mixin_,
    in_,
    break_,
    continue_,
    goto_,
    scope_,

    traits,
    overloadSet,
    defaultInit,    // DefaultInitExp
    pow,
    powAssign,
    vector,

    voidExpression,
    cantExpression,
    showCtfeContext,
    objcClassReference,
    vectorArray,
    compoundLiteral, // ( type-name ) { initializer-list }
    _Generic,
    interval,

    loweredAssignExp,
    rvalue,
}

enum FirstCKeyword = TOK.inline;

// Assert that all token enum members have consecutive values and
// that none of them overlap
static assert(() {
    foreach (idx, enumName; __traits(allMembers, TOK))
    {
       static if (idx != __traits(getMember, TOK, enumName))
       {
           pragma(msg, "Error: Expected TOK.", enumName, " to be ", idx, " but is ", __traits(getMember, TOK, enumName));
           static assert(0);
       }
    }
    return true;
}());

/****************************************
 */

private immutable TOK[] keywords =
[
    TOK.this_,
    TOK.super_,
    TOK.assert_,
    TOK.null_,
    TOK.true_,
    TOK.false_,
    TOK.cast_,
    TOK.new_,
    TOK.throw_,
    TOK.module_,
    TOK.pragma_,
    TOK.typeof_,
    TOK.typeid_,
    TOK.template_,
    TOK.void_,
    TOK.int8,
    TOK.uns8,
    TOK.int16,
    TOK.uns16,
    TOK.int32,
    TOK.uns32,
    TOK.int64,
    TOK.uns64,
    TOK.int128,
    TOK.uns128,
    TOK.float32,
    TOK.float64,
    TOK.float80,
    TOK.bool_,
    TOK.char_,
    TOK.wchar_,
    TOK.dchar_,
    TOK.imaginary32,
    TOK.imaginary64,
    TOK.imaginary80,
    TOK.complex32,
    TOK.complex64,
    TOK.complex80,
    TOK.delegate_,
    TOK.function_,
    TOK.is_,
    TOK.if_,
    TOK.else_,
    TOK.while_,
    TOK.for_,
    TOK.do_,
    TOK.switch_,
    TOK.case_,
    TOK.default_,
    TOK.break_,
    TOK.continue_,
    TOK.synchronized_,
    TOK.return_,
    TOK.goto_,
    TOK.try_,
    TOK.catch_,
    TOK.finally_,
    TOK.with_,
    TOK.asm_,
    TOK.foreach_,
    TOK.foreach_reverse_,
    TOK.scope_,
    TOK.struct_,
    TOK.class_,
    TOK.interface_,
    TOK.union_,
    TOK.enum_,
    TOK.import_,
    TOK.mixin_,
    TOK.static_,
    TOK.final_,
    TOK.const_,
    TOK.alias_,
    TOK.override_,
    TOK.abstract_,
    TOK.debug_,
    TOK.deprecated_,
    TOK.in_,
    TOK.out_,
    TOK.inout_,
    TOK.lazy_,
    TOK.auto_,
    TOK.align_,
    TOK.extern_,
    TOK.private_,
    TOK.package_,
    TOK.protected_,
    TOK.public_,
    TOK.export_,
    TOK.invariant_,
    TOK.unittest_,
    TOK.version_,
    TOK.argumentTypes,
    TOK.parameters,
    TOK.ref_,
    TOK.macro_,
    TOK.pure_,
    TOK.nothrow_,
    TOK.gshared,
    TOK.traits,
    TOK.vector,
    TOK.file,
    TOK.fileFullPath,
    TOK.line,
    TOK.moduleString,
    TOK.functionString,
    TOK.prettyFunction,
    TOK.shared_,
    TOK.immutable_,
    TOK.rvalue,

    // C only keywords
    TOK.inline,
    TOK.register,
    TOK.restrict,
    TOK.signed,
    TOK.sizeof_,
    TOK.typedef_,
    TOK.unsigned,
    TOK.volatile,
    TOK._Alignas,
    TOK._Alignof,
    TOK._Atomic,
    TOK._Bool,
    TOK._Complex,
    TOK._Generic,
    TOK._Imaginary,
    TOK._Noreturn,
    TOK._Static_assert,
    TOK._Thread_local,

    // C only extended keywords
    TOK._assert,
    TOK._import,
    TOK._module,
    TOK.__cdecl,
    TOK.__declspec,
    TOK.__stdcall,
    TOK.__thread,
    TOK.__pragma,
    TOK.__int128,
    TOK.__attribute__,
];

// Initialize the identifier pool
shared static this() nothrow
{
    Identifier.initTable();
    foreach (kw; keywords)
    {
        //printf("keyword[%d] = '%s'\n",kw, Token.tochars[kw].ptr);
        Identifier.idPool(Token.tochars[kw], kw);
    }
}

/************************************
 * This is used to pick the C keywords out of the tokens.
 * If it's not a C keyword, then it's an identifier.
 */
static immutable TOK[TOK.max + 1] Ckeywords =
() {
    with (TOK)
    {
        TOK[TOK.max + 1] tab = identifier;  // default to identifier
        enum Ckwds = [ auto_, break_, case_, char_, const_, continue_, default_, do_, float64, else_,
                       enum_, extern_, float32, for_, goto_, if_, inline, int32, int64, register,
                       restrict, return_, int16, signed, sizeof_, static_, struct_, switch_, typedef_,
                       union_, unsigned, void_, volatile, while_, asm_, typeof_,
                       _Alignas, _Alignof, _Atomic, _Bool, _Complex, _Generic, _Imaginary, _Noreturn,
                       _Static_assert, _Thread_local,
                       _import, _module, __cdecl, __declspec, __stdcall, __thread, __pragma, __int128, __attribute__,
                       _assert ];

        foreach (kw; Ckwds)
            tab[kw] = cast(TOK) kw;

        return tab;
    }
} ();

struct InterpolatedSet {
    // all strings in the parts are zero terminated at length+1
    string[] parts;
}

/***********************************************************
 */
extern (C++) struct Token
{
    Token* next;
    Loc loc;
    const(char)* ptr; // pointer to first character of this token within buffer
    TOK value;
    const(char)[] blockComment; // doc comment string prior to this token
    const(char)[] lineComment; // doc comment for previous token

    union
    {
        // Integers
        long intvalue;
        ulong unsvalue;
        // Floats
        real_t floatvalue;

        struct
        {
            union
            {
                const(char)* ustring; // UTF8 string
                InterpolatedSet* interpolatedSet;
            }
            uint len;
            ubyte postfix; // 'c', 'w', 'd'
        }

        Identifier ident;
    }

    extern (D) private static immutable string[TOK.max + 1] tochars =
    [
        // Keywords
        TOK.this_: "this",
        TOK.super_: "super",
        TOK.assert_: "assert",
        TOK.null_: "null",
        TOK.true_: "true",
        TOK.false_: "false",
        TOK.cast_: "cast",
        TOK.new_: "new",
        TOK.throw_: "throw",
        TOK.module_: "module",
        TOK.pragma_: "pragma",
        TOK.typeof_: "typeof",
        TOK.typeid_: "typeid",
        TOK.rvalue: "__rvalue",
        TOK.template_: "template",
        TOK.void_: "void",
        TOK.int8: "byte",
        TOK.uns8: "ubyte",
        TOK.int16: "short",
        TOK.uns16: "ushort",
        TOK.int32: "int",
        TOK.uns32: "uint",
        TOK.int64: "long",
        TOK.uns64: "ulong",
        TOK.int128: "cent",
        TOK.uns128: "ucent",
        TOK.float32: "float",
        TOK.float64: "double",
        TOK.float80: "real",
        TOK.bool_: "bool",
        TOK.char_: "char",
        TOK.wchar_: "wchar",
        TOK.dchar_: "dchar",
        TOK.imaginary32: "ifloat",
        TOK.imaginary64: "idouble",
        TOK.imaginary80: "ireal",
        TOK.complex32: "cfloat",
        TOK.complex64: "cdouble",
        TOK.complex80: "creal",
        TOK.delegate_: "delegate",
        TOK.function_: "function",
        TOK.is_: "is",
        TOK.if_: "if",
        TOK.else_: "else",
        TOK.while_: "while",
        TOK.for_: "for",
        TOK.do_: "do",
        TOK.switch_: "switch",
        TOK.case_: "case",
        TOK.default_: "default",
        TOK.break_: "break",
        TOK.continue_: "continue",
        TOK.synchronized_: "synchronized",
        TOK.return_: "return",
        TOK.goto_: "goto",
        TOK.try_: "try",
        TOK.catch_: "catch",
        TOK.finally_: "finally",
        TOK.with_: "with",
        TOK.asm_: "asm",
        TOK.foreach_: "foreach",
        TOK.foreach_reverse_: "foreach_reverse",
        TOK.scope_: "scope",
        TOK.struct_: "struct",
        TOK.class_: "class",
        TOK.interface_: "interface",
        TOK.union_: "union",
        TOK.enum_: "enum",
        TOK.import_: "import",
        TOK.mixin_: "mixin",
        TOK.static_: "static",
        TOK.final_: "final",
        TOK.const_: "const",
        TOK.alias_: "alias",
        TOK.override_: "override",
        TOK.abstract_: "abstract",
        TOK.debug_: "debug",
        TOK.deprecated_: "deprecated",
        TOK.in_: "in",
        TOK.out_: "out",
        TOK.inout_: "inout",
        TOK.lazy_: "lazy",
        TOK.auto_: "auto",
        TOK.align_: "align",
        TOK.extern_: "extern",
        TOK.private_: "private",
        TOK.package_: "package",
        TOK.protected_: "protected",
        TOK.public_: "public",
        TOK.export_: "export",
        TOK.invariant_: "invariant",
        TOK.unittest_: "unittest",
        TOK.version_: "version",
        TOK.argumentTypes: "__argTypes",
        TOK.parameters: "__parameters",
        TOK.ref_: "ref",
        TOK.macro_: "macro",
        TOK.pure_: "pure",
        TOK.nothrow_: "nothrow",
        TOK.gshared: "__gshared",
        TOK.traits: "__traits",
        TOK.vector: "__vector",
        TOK.file: "__FILE__",
        TOK.fileFullPath: "__FILE_FULL_PATH__",
        TOK.line: "__LINE__",
        TOK.moduleString: "__MODULE__",
        TOK.functionString: "__FUNCTION__",
        TOK.prettyFunction: "__PRETTY_FUNCTION__",
        TOK.shared_: "shared",
        TOK.immutable_: "immutable",

        TOK.endOfFile: "End of File",
        TOK.leftCurly: "{",
        TOK.rightCurly: "}",
        TOK.leftParenthesis: "(",
        TOK.rightParenthesis: ")",
        TOK.leftBracket: "[",
        TOK.rightBracket: "]",
        TOK.semicolon: ";",
        TOK.colon: ":",
        TOK.comma: ",",
        TOK.dot: ".",
        TOK.xor: "^",
        TOK.xorAssign: "^=",
        TOK.assign: "=",
        TOK.lessThan: "<",
        TOK.greaterThan: ">",
        TOK.lessOrEqual: "<=",
        TOK.greaterOrEqual: ">=",
        TOK.equal: "==",
        TOK.notEqual: "!=",
        TOK.not: "!",
        TOK.leftShift: "<<",
        TOK.rightShift: ">>",
        TOK.unsignedRightShift: ">>>",
        TOK.add: "+",
        TOK.min: "-",
        TOK.mul: "*",
        TOK.div: "/",
        TOK.mod: "%",
        TOK.slice: "..",
        TOK.dotDotDot: "...",
        TOK.and: "&",
        TOK.andAnd: "&&",
        TOK.or: "|",
        TOK.orOr: "||",
        TOK.tilde: "~",
        TOK.dollar: "$",
        TOK.plusPlus: "++",
        TOK.minusMinus: "--",
        TOK.question: "?",
        TOK.variable: "var",
        TOK.addAssign: "+=",
        TOK.minAssign: "-=",
        TOK.mulAssign: "*=",
        TOK.divAssign: "/=",
        TOK.modAssign: "%=",
        TOK.leftShiftAssign: "<<=",
        TOK.rightShiftAssign: ">>=",
        TOK.unsignedRightShiftAssign: ">>>=",
        TOK.andAssign: "&=",
        TOK.orAssign: "|=",
        TOK.concatenateAssign: "~=",
        TOK.identity: "is",
        TOK.notIdentity: "!is",
        TOK.identifier: "identifier",
        TOK.at: "@",
        TOK.pow: "^^",
        TOK.powAssign: "^^=",
        TOK.goesTo: "=>",
        TOK.pound: "#",
        TOK.arrow: "->",
        TOK.colonColon: "::",

        // For debugging
        TOK.error: "error",
        TOK.string_: "string",
        TOK.interpolated: "interpolated string",
        TOK.onScopeExit: "scope(exit)",
        TOK.onScopeSuccess: "scope(success)",
        TOK.onScopeFailure: "scope(failure)",

        // Finish up
        TOK.reserved: "reserved",
        TOK.comment: "comment",
        TOK.int32Literal: "int32v",
        TOK.uns32Literal: "uns32v",
        TOK.int64Literal: "int64v",
        TOK.uns64Literal: "uns64v",
        TOK.int128Literal: "int128v",
        TOK.uns128Literal: "uns128v",
        TOK.float32Literal: "float32v",
        TOK.float64Literal: "float64v",
        TOK.float80Literal: "float80v",
        TOK.imaginary32Literal: "imaginary32v",
        TOK.imaginary64Literal: "imaginary64v",
        TOK.imaginary80Literal: "imaginary80v",
        TOK.charLiteral: "charv",
        TOK.wcharLiteral: "wcharv",
        TOK.dcharLiteral: "dcharv",
        TOK.wchar_tLiteral: "wchar_tv",
        TOK.hexadecimalString: "xstring",
        TOK.endOfLine: "\\n",
        TOK.whitespace: "whitespace",

        // C only keywords
        TOK.inline    : "inline",
        TOK.register  : "register",
        TOK.restrict  : "restrict",
        TOK.signed    : "signed",
        TOK.sizeof_   : "sizeof",
        TOK.typedef_  : "typedef",
        TOK.unsigned  : "unsigned",
        TOK.volatile  : "volatile",
        TOK._Alignas  : "_Alignas",
        TOK._Alignof  : "_Alignof",
        TOK._Atomic   : "_Atomic",
        TOK._Bool     : "_Bool",
        TOK._Complex  : "_Complex",
        TOK._Generic  : "_Generic",
        TOK._Imaginary: "_Imaginary",
        TOK._Noreturn : "_Noreturn",
        TOK._Static_assert : "_Static_assert",
        TOK._Thread_local  : "_Thread_local",

        // C only extended keywords
        TOK._assert       : "__check",
        TOK._import       : "__import",
        TOK._module       : "__module",
        TOK.__cdecl        : "__cdecl",
        TOK.__declspec     : "__declspec",
        TOK.__stdcall      : "__stdcall",
        TOK.__thread       : "__thread",
        TOK.__pragma       : "__pragma",
        TOK.__int128       : "__int128",
        TOK.__attribute__  : "__attribute__",
    ];

    static assert(() {
        foreach (s; tochars)
            assert(s.length);
        return true;
    }());

nothrow:

    extern (D) int isKeyword() pure const @safe @nogc
    {
        foreach (kw; keywords)
        {
            if (kw == value)
                return 1;
        }
        return 0;
    }

    extern(D) void appendInterpolatedPart(const(char)[] str)
    {
        assert(value == TOK.interpolated);
        if (interpolatedSet is null)
            interpolatedSet = new InterpolatedSet;

        auto s = cast(char*)mem.xmalloc_noscan(str.length + 1);
        memcpy(s, str.ptr, str.length);
        s[str.length] = 0;

        interpolatedSet.parts ~= cast(string) s[0 .. str.length];
    }

    /****
     * Set to contents of str
     * Params:
     *  str = string
     */
    extern (D) void setString(const(char)[] str)
    {
        value = TOK.string_;
        len = cast(uint)str.length;
        if (len)
        {
            auto s = cast(char*)mem.xmalloc_noscan(len + 1);
            memcpy(s, str.ptr, len);
            s[len] = 0;
            ustring = s;
        }
        else
            ustring = "";
        postfix = 0;
    }

    extern (C++) const(char)* toChars() const
    {
        OutBuffer buf;
        toString(&buf.put);
        return buf.extractChars();
    }

    /*********************************
     * Params:
     *  sink = where the generated characters get sent
     */
    extern (D) void toString(scope void delegate (ubyte c) nothrow sink) const
    {
        nothrow void arraySink(const(char)[] s) { foreach (char c; s) sink(c); }

        const bufflen = 3 + 3 * floatvalue.sizeof + 1;
        char[bufflen + 2] buffer = void;     // extra 2 for suffixes
        char* p = &buffer[0];

        Sink s = Sink(sink);
        switch (value)
        {
        case TOK.int32Literal:
            s.printf("%d", cast(int)intvalue);
            return;

        case TOK.uns32Literal:
        case TOK.wchar_tLiteral:
            s.printf("%uU", cast(uint)unsvalue);
            return;

        case TOK.wcharLiteral:
        case TOK.dcharLiteral:
        case TOK.charLiteral:
            writeSingleCharLiteral(cast(dchar) intvalue, sink);
            return;

        case TOK.int64Literal:
            s.printf("%lldL", cast(long)intvalue);
            return;

        case TOK.uns64Literal:
            s.printf("%lluUL", cast(ulong)unsvalue);
            return;

        case TOK.float32Literal:
            const length = CTFloat.sprint(p, bufflen, 'g', floatvalue);
            arraySink(p[0 .. length]);
            sink('f');
            return;

        case TOK.float64Literal:
            const length = CTFloat.sprint(p, bufflen, 'g', floatvalue);
            return arraySink(p[0 .. length]);

        case TOK.float80Literal:
            const length = CTFloat.sprint(p, bufflen, 'g', floatvalue);
            arraySink(p[0 .. length]);
            sink('L');
            return;

        case TOK.imaginary32Literal:
            const length = CTFloat.sprint(p, bufflen, 'g', floatvalue);
            arraySink(p[0 .. length]);
            sink('f');
            sink('i');
            return;

        case TOK.imaginary64Literal:
            const length = CTFloat.sprint(p, bufflen, 'g', floatvalue);
            arraySink(p[0 .. length]);
            sink('i');
            return;

        case TOK.imaginary80Literal:
            const length = CTFloat.sprint(p, bufflen, 'g', floatvalue);
            arraySink(p[0 .. length]);
            sink('L');
            sink('i');
            return;

        case TOK.string_:
            sink('"');
            for (size_t i = 0; i < len;)
            {
                dchar d;
                utf_decodeChar(ustring[0 .. len], i, d);
                writeCharLiteral(d, sink);
            }
            sink('"');
            if (postfix)
                sink(postfix);
            return;

        case TOK.hexadecimalString:
            sink('x');
            sink('"');
            foreach (size_t i; 0 .. len)
            {
                if (i)
                    sink(' ');
                s.printf("%02x", ustring[i]);
            }
            sink('"');
            if (postfix)
                sink(postfix);
            return;

        case TOK.identifier:
        case TOK.enum_:
        case TOK.struct_:
        case TOK.import_:
        case TOK.wchar_:
        case TOK.dchar_:
        case TOK.bool_:
        case TOK.char_:
        case TOK.int8:
        case TOK.uns8:
        case TOK.int16:
        case TOK.uns16:
        case TOK.int32:
        case TOK.uns32:
        case TOK.int64:
        case TOK.uns64:
        case TOK.int128:
        case TOK.uns128:
        case TOK.float32:
        case TOK.float64:
        case TOK.float80:
        case TOK.imaginary32:
        case TOK.imaginary64:
        case TOK.imaginary80:
        case TOK.complex32:
        case TOK.complex64:
        case TOK.complex80:
        case TOK.void_:
            return arraySink(ident.toString());

        default:
            return arraySink(tochars[value]);
        }
    }

    static const(char)* toChars(TOK value)
    {
        return toString(value).ptr;
    }

    extern (D) static string toString(TOK value) pure nothrow @nogc @safe
    {
        return tochars[value];
    }
}

/**
 * Write a character, using a readable escape sequence if needed
 *
 * Useful for printing "" string literals in e.g. error messages, ddoc, or the `.stringof` property
 *
 * Params:
 *   d = dchar to convert to literal
 *   sink = sink for generated characters
 */
nothrow
void writeCharLiteral(dchar d, scope void delegate(ubyte) nothrow sink)
{
    char c;
    switch (d)
    {
        case '\0': c = '0';  goto Lput;
        case '\n': c = 'n';  goto Lput;
        case '\r': c = 'r';  goto Lput;
        case '\t': c = 't';  goto Lput;
        case '\b': c = 'b';  goto Lput;
        case '\f': c = 'f';  goto Lput;
        Lput:
            sink('\\');
            sink(cast(ubyte)c);
            break;

        case '"':
        case '\\':
            sink('\\');
            goto default;
        default:
            Sink s = Sink(sink);
            if (d <= 0xFF)
            {
                if (isprint(d))
                    sink(cast(ubyte)d);
                else
                    s.printf("\\x%02x", d);
            }
            else if (d <= 0xFFFF)
                s.printf("\\u%04x", d);
            else
                s.printf("\\U%08x", d);
            break;
    }
}

unittest
{
    char[40] buf = void;   // 40 should be good enough for anybody
    size_t i;
    foreach(dchar d; "a\n\r\t\b\f\0\x11\u7233\U00017233"d)
    {
        void sink(ubyte c) { buf[i++] = c; }
        writeCharLiteral(d, &sink);
    }
    assert(buf[0 .. i] == `a\n\r\t\b\f\0\x11\u7233\U00017233`);
}

/**
 * Write a single-quoted character literal
 *
 * Useful for printing '' char literals in e.g. error messages, ddoc, or the `.stringof` property
 *
 * Params:
 *   c = code point to write
 *   sink = where the output goes
 */
nothrow
void writeSingleCharLiteral(dchar c, scope void delegate(ubyte c) nothrow sink)
{
    sink('\'');
    if (c == '\'')
        sink('\\');

    if (c == '"')
        sink('"');
    else
    {
        writeCharLiteral(c, sink);
    }
    sink('\'');
}

unittest
{
    OutBuffer buf;
    writeSingleCharLiteral('\'', &buf.write);
    assert(buf[] == `'\''`);
    buf.reset();
    writeSingleCharLiteral('"', &buf.write);
    assert(buf[] == `'"'`);
    buf.reset();
    writeSingleCharLiteral('\n', &buf.write);
    assert(buf[] == `'\n'`);
}

import core.stdc.stdarg;

/* Because extern (C) functions cannot accept delegates as arguments
 */
struct Sink
{
    void delegate(ubyte) nothrow put;

    /************************************************
     * Works like printf, but writes the resulting characters to
     * sink rather than stdout.
     * Cribbed from common/outbuffer.d
     * Params:
     *  sink = where the output goes
     *  format = printf-style format string
     *  args = arguments to format
     */

    extern (C) void printf(const(char)* format, ...) nothrow @system
    {
        va_list ap;
        va_start(ap, format);
        vprintf(format, ap);
        va_end(ap);
    }

    private
    void vprintf(const(char)* format, va_list args) nothrow @system
    {
        debug
            enum BUFSIZE = 1;   // flush out reallocation bugs
        else
            enum BUFSIZE = 32;
        char[BUFSIZE] buf = void;       // 32 should be enough for anybody
        uint psize = BUFSIZE;
        char* pbuf = &buf[0];
        uint count;
        for (;;)
        {
            if (psize > BUFSIZE) // need a bigger boat
            {
                pbuf = cast(char*)mem.xrealloc_noscan((pbuf is &buf[0]) ? null : pbuf, psize);
            }
            va_list va;
            va_copy(va, args);
            /*
                The functions vprintf(), vfprintf(), vsprintf(), vsnprintf()
                are equivalent to the functions printf(), fprintf(), sprintf(),
                snprintf(), respectively, except that they are called with a
                va_list instead of a variable number of arguments. These
                functions do not call the va_end macro. Consequently, the value
                of ap is undefined after the call. The application should call
                va_end(ap) itself afterwards.
                */
            count = vsnprintf(cast(char*)pbuf, psize, format, va);
            va_end(va);
            if (count == -1) // snn.lib and older libcmt.lib return -1 if buffer too small
                psize *= 2;
            else if (count >= psize)
                psize = count + 1;      // count is number of characters that would have been written, excluding 0
            else
                break;
        }
        foreach (c; pbuf[0 .. count])
            put(c);
        if (psize > BUFSIZE)
            mem.xfree(pbuf);
    }
}
