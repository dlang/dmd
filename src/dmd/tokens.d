/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/tokens.d, _tokens.d)
 * Documentation:  https://dlang.org/phobos/dmd_tokens.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/tokens.d
 */

module dmd.tokens;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import dmd.globals;
import dmd.identifier;
import dmd.root.ctfloat;
import dmd.root.outbuffer;
import dmd.root.rmem;
import dmd.utf;

enum TOK : int
{
    reserved,

    // Other
    leftParentheses,
    rightParentheses,
    leftBracket,
    rightBracket,
    leftCurly,
    rightCurly,
    colon,
    negate,
    semicolon,
    dotDotDot,
    endOfFile,
    cast_,
    null_,
    assert_,
    true_,
    false_,
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
    version_,
    module_,
    dollar,
    template_,
    dotTemplateDeclaration,
    declaration,
    typeof_,
    pragma_,
    dSymbol,
    typeid_,
    uadd,
    remove,
    newAnonymousClass,
    comment,
    arrayLiteral,
    assocArrayLiteral,
    structLiteral,
    classReference,
    thrownException,
    delegatePointer,
    delegateFunctionPointer,

    // 54
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

    // 64
    // NCEG floating point compares
    // !<>=     <>    <>=    !>     !>=   !<     !<=   !<>
    unord,
    lg,
    leg,
    ule,
    ul,
    uge,
    ug,
    ue,

    // 72
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
    arrow,
    comma,
    question,
    andAnd,
    orOr,
    prePlusPlus,
    preMinusMinus,

    // 113
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

    // 125
    // Char constants
    charLiteral,
    wcharLiteral,
    dcharLiteral,

    // 128
    // Leaf operators
    identifier,
    string_,
    hexadecimalString,
    this_,
    super_,
    halt,
    tuple,
    error,

    // 136
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

    // 160
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
    manifest,
    immutable_,

    // 191
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

    // 215
    // Contracts
    invariant_,

    // Testing
    unittest_,

    // Added after 1.0
    argumentTypes,
    ref_,
    macro_,

    // 221
    parameters,
    traits,
    overloadSet,
    pure_,
    nothrow_,
    gshared,
    line,
    file,
    fileFullPath,
    moduleString,
    functionString,
    prettyFunction,
    shared_,
    at,
    pow,
    powAssign,
    goesTo,
    vector,
    pound,

    // 239
    interval,
    voidExpression,
    cantExpression,

    max_,
}

/***********************************************************
 */
extern (C++) struct Token
{
    Token* next;
    Loc loc;
    const(char)* ptr; // pointer to first character of this token within buffer
    TOK value;
    const(char)* blockComment; // doc comment string prior to this token
    const(char)* lineComment; // doc comment for previous token

    union
    {
        // Integers
        sinteger_t intvalue;
        uinteger_t unsvalue;
        // Floats
        real_t floatvalue;

        struct
        {
            const(char)* ustring; // UTF8 string
            uint len;
            ubyte postfix; // 'c', 'w', 'd'
        }

        Identifier ident;
    }

    extern (D) private __gshared immutable string[TOK.max_] tochars =
    [
        // Keywords
        TOKthis: "this",
        TOKsuper: "super",
        TOKassert: "assert",
        TOKnull: "null",
        TOKtrue: "true",
        TOKfalse: "false",
        TOKcast: "cast",
        TOKnew: "new",
        TOKdelete: "delete",
        TOKthrow: "throw",
        TOKmodule: "module",
        TOKpragma: "pragma",
        TOKtypeof: "typeof",
        TOKtypeid: "typeid",
        TOKtemplate: "template",
        TOKvoid: "void",
        TOKint8: "byte",
        TOKuns8: "ubyte",
        TOKint16: "short",
        TOKuns16: "ushort",
        TOKint32: "int",
        TOKuns32: "uint",
        TOKint64: "long",
        TOKuns64: "ulong",
        TOKint128: "cent",
        TOKuns128: "ucent",
        TOKfloat32: "float",
        TOKfloat64: "double",
        TOKfloat80: "real",
        TOKbool: "bool",
        TOKchar: "char",
        TOKwchar: "wchar",
        TOKdchar: "dchar",
        TOKimaginary32: "ifloat",
        TOKimaginary64: "idouble",
        TOKimaginary80: "ireal",
        TOKcomplex32: "cfloat",
        TOKcomplex64: "cdouble",
        TOKcomplex80: "creal",
        TOKdelegate: "delegate",
        TOKfunction: "function",
        TOKis: "is",
        TOKif: "if",
        TOKelse: "else",
        TOKwhile: "while",
        TOKfor: "for",
        TOKdo: "do",
        TOKswitch: "switch",
        TOKcase: "case",
        TOKdefault: "default",
        TOKbreak: "break",
        TOKcontinue: "continue",
        TOKsynchronized: "synchronized",
        TOKreturn: "return",
        TOKgoto: "goto",
        TOKtry: "try",
        TOKcatch: "catch",
        TOKfinally: "finally",
        TOKwith: "with",
        TOKasm: "asm",
        TOKforeach: "foreach",
        TOKforeach_reverse: "foreach_reverse",
        TOKscope: "scope",
        TOKstruct: "struct",
        TOKclass: "class",
        TOKinterface: "interface",
        TOKunion: "union",
        TOKenum: "enum",
        TOKimport: "import",
        TOKmixin: "mixin",
        TOKstatic: "static",
        TOKfinal: "final",
        TOKconst: "const",
        TOKalias: "alias",
        TOKoverride: "override",
        TOKabstract: "abstract",
        TOKdebug: "debug",
        TOKdeprecated: "deprecated",
        TOKin: "in",
        TOKout: "out",
        TOKinout: "inout",
        TOKlazy: "lazy",
        TOKauto: "auto",
        TOKalign: "align",
        TOKextern: "extern",
        TOKprivate: "private",
        TOKpackage: "package",
        TOKprotected: "protected",
        TOKpublic: "public",
        TOKexport: "export",
        TOKinvariant: "invariant",
        TOKunittest: "unittest",
        TOKversion: "version",
        TOKargTypes: "__argTypes",
        TOKparameters: "__parameters",
        TOKref: "ref",
        TOKmacro: "macro",
        TOKpure: "pure",
        TOKnothrow: "nothrow",
        TOKgshared: "__gshared",
        TOKtraits: "__traits",
        TOKvector: "__vector",
        TOKoverloadset: "__overloadset",
        TOKfile: "__FILE__",
        TOKfilefullpath: "__FILE_FULL_PATH__",
        TOKline: "__LINE__",
        TOKmodulestring: "__MODULE__",
        TOKfuncstring: "__FUNCTION__",
        TOKprettyfunc: "__PRETTY_FUNCTION__",
        TOKshared: "shared",
        TOKimmutable: "immutable",

        TOKeof: "EOF",
        TOKlcurly: "{",
        TOKrcurly: "}",
        TOKlparen: "(",
        TOKrparen: ")",
        TOKlbracket: "[",
        TOKrbracket: "]",
        TOKsemicolon: ";",
        TOKcolon: ":",
        TOKcomma: ",",
        TOKdot: ".",
        TOKxor: "^",
        TOKxorass: "^=",
        TOKassign: "=",
        TOKconstruct: "=",
        TOKblit: "=",
        TOKlt: "<",
        TOKgt: ">",
        TOKle: "<=",
        TOKge: ">=",
        TOKequal: "==",
        TOKnotequal: "!=",
        TOKunord: "!<>=",
        TOKue: "!<>",
        TOKlg: "<>",
        TOKleg: "<>=",
        TOKule: "!>",
        TOKul: "!>=",
        TOKuge: "!<",
        TOKug: "!<=",
        TOKnot: "!",
        TOKshl: "<<",
        TOKshr: ">>",
        TOKushr: ">>>",
        TOKadd: "+",
        TOKmin: "-",
        TOKmul: "*",
        TOKdiv: "/",
        TOKmod: "%",
        TOKslice: "..",
        TOKdotdotdot: "...",
        TOKand: "&",
        TOKandand: "&&",
        TOKor: "|",
        TOKoror: "||",
        TOKarray: "[]",
        TOKindex: "[i]",
        TOKaddress: "&",
        TOKstar: "*",
        TOKtilde: "~",
        TOKdollar: "$",
        TOKplusplus: "++",
        TOKminusminus: "--",
        TOKpreplusplus: "++",
        TOKpreminusminus: "--",
        TOKtype: "type",
        TOKquestion: "?",
        TOKneg: "-",
        TOKuadd: "+",
        TOKvar: "var",
        TOKaddass: "+=",
        TOKminass: "-=",
        TOKmulass: "*=",
        TOKdivass: "/=",
        TOKmodass: "%=",
        TOKshlass: "<<=",
        TOKshrass: ">>=",
        TOKushrass: ">>>=",
        TOKandass: "&=",
        TOKorass: "|=",
        TOKcatass: "~=",
        TOKcatelemass: "~=",
        TOKcatdcharass: "~=",
        TOKcat: "~",
        TOKcall: "call",
        TOKidentity: "is",
        TOKnotidentity: "!is",
        TOKidentifier: "identifier",
        TOKat: "@",
        TOKpow: "^^",
        TOKpowass: "^^=",
        TOKgoesto: "=>",
        TOKpound: "#",

        // For debugging
        TOKerror: "error",
        TOKdotid: "dotid",
        TOKdottd: "dottd",
        TOKdotti: "dotti",
        TOKdotvar: "dotvar",
        TOKdottype: "dottype",
        TOKsymoff: "symoff",
        TOKarraylength: "arraylength",
        TOKarrayliteral: "arrayliteral",
        TOKassocarrayliteral: "assocarrayliteral",
        TOKstructliteral: "structliteral",
        TOKstring: "string",
        TOKdsymbol: "symbol",
        TOKtuple: "tuple",
        TOKdeclaration: "declaration",
        TOKon_scope_exit: "scope(exit)",
        TOKon_scope_success: "scope(success)",
        TOKon_scope_failure: "scope(failure)",
        TOKdelegateptr: "delegateptr",

        // Finish up
        TOKreserved: "reserved",
        TOKremove: "remove",
        TOKnewanonclass: "newanonclass",
        TOKcomment: "comment",
        TOKclassreference: "classreference",
        TOKthrownexception: "thrownexception",
        TOKdelegatefuncptr: "delegatefuncptr",
        TOKarrow: "arrow",
        TOKint32v: "int32v",
        TOKuns32v: "uns32v",
        TOKint64v: "int64v",
        TOKuns64v: "uns64v",
        TOKint128v: "int128v",
        TOKuns128v: "uns128v",
        TOKfloat32v: "float32v",
        TOKfloat64v: "float64v",
        TOKfloat80v: "float80v",
        TOKimaginary32v: "imaginary32v",
        TOKimaginary64v: "imaginary64v",
        TOKimaginary80v: "imaginary80v",
        TOKcharv: "charv",
        TOKwcharv: "wcharv",
        TOKdcharv: "dcharv",

        TOKhalt: "halt",
        TOKxstring: "xstring",
        TOKmanifest: "manifest",

        TOKinterval: "interval",
        TOKvoidexp: "voidexp",
        TOKcantexp: "cantexp",
    ];

    static assert(() {
        foreach (s; tochars)
            assert(s.length);
        return true;
    }());

    shared static this()
    {
        Identifier.initTable();
        foreach (kw; keywords)
        {
            //printf("keyword[%d] = '%s'\n",kw, tochars[kw].ptr);
            Identifier.idPool(tochars[kw].ptr, tochars[kw].length, cast(uint)kw);
        }
    }

    __gshared Token* freelist = null;

    static Token* alloc()
    {
        if (Token.freelist)
        {
            Token* t = freelist;
            freelist = t.next;
            t.next = null;
            return t;
        }
        return new Token();
    }

    void free()
    {
        next = freelist;
        freelist = &this;
    }

    int isKeyword() const
    {
        foreach (kw; keywords)
        {
            if (kw == value)
                return 1;
        }
        return 0;
    }

    debug
    {
        void print()
        {
            fprintf(stderr, "%s\n", toChars());
        }
    }

    /****
     * Set to contents of ptr[0..length]
     * Params:
     *  ptr = pointer to string
     *  length = length of string
     */
    final void setString(const(char)* ptr, size_t length)
    {
        auto s = cast(char*)mem.xmalloc(length + 1);
        memcpy(s, ptr, length);
        s[length] = 0;
        ustring = s;
        len = cast(uint)length;
        postfix = 0;
    }

    /****
     * Set to contents of buf
     * Params:
     *  buf = string (not zero terminated)
     */
    final void setString(const ref OutBuffer buf)
    {
        setString(cast(const(char)*)buf.data, buf.offset);
    }

    /****
     * Set to empty string
     */
    final void setString()
    {
        ustring = "";
        len = 0;
        postfix = 0;
    }

    extern (C++) const(char)* toChars() const
    {
        __gshared char[3 + 3 * floatvalue.sizeof + 1] buffer;
        const(char)* p = &buffer[0];
        switch (value)
        {
        case TOKint32v:
            sprintf(&buffer[0], "%d", cast(d_int32)intvalue);
            break;
        case TOKuns32v:
        case TOKcharv:
        case TOKwcharv:
        case TOKdcharv:
            sprintf(&buffer[0], "%uU", cast(d_uns32)unsvalue);
            break;
        case TOKint64v:
            sprintf(&buffer[0], "%lldL", cast(long)intvalue);
            break;
        case TOKuns64v:
            sprintf(&buffer[0], "%lluUL", cast(ulong)unsvalue);
            break;
        case TOKfloat32v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "f");
            break;
        case TOKfloat64v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            break;
        case TOKfloat80v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "L");
            break;
        case TOKimaginary32v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "fi");
            break;
        case TOKimaginary64v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "i");
            break;
        case TOKimaginary80v:
            CTFloat.sprint(&buffer[0], 'g', floatvalue);
            strcat(&buffer[0], "Li");
            break;
        case TOKstring:
            {
                OutBuffer buf;
                buf.writeByte('"');
                for (size_t i = 0; i < len;)
                {
                    dchar c;
                    utf_decodeChar(ustring, len, i, c);
                    switch (c)
                    {
                    case 0:
                        break;
                    case '"':
                    case '\\':
                        buf.writeByte('\\');
                        goto default;
                    default:
                        if (c <= 0x7F)
                        {
                            if (isprint(c))
                                buf.writeByte(c);
                            else
                                buf.printf("\\x%02x", c);
                        }
                        else if (c <= 0xFFFF)
                            buf.printf("\\u%04x", c);
                        else
                            buf.printf("\\U%08x", c);
                        continue;
                    }
                    break;
                }
                buf.writeByte('"');
                if (postfix)
                    buf.writeByte(postfix);
                p = buf.extractString();
            }
            break;
        case TOKxstring:
            {
                OutBuffer buf;
                buf.writeByte('x');
                buf.writeByte('"');
                foreach (size_t i; 0 .. len)
                {
                    if (i)
                        buf.writeByte(' ');
                    buf.printf("%02x", ustring[i]);
                }
                buf.writeByte('"');
                if (postfix)
                    buf.writeByte(postfix);
                buf.writeByte(0);
                p = buf.extractData();
                break;
            }
        case TOKidentifier:
        case TOKenum:
        case TOKstruct:
        case TOKimport:
        case TOKwchar:
        case TOKdchar:
        case TOKbool:
        case TOKchar:
        case TOKint8:
        case TOKuns8:
        case TOKint16:
        case TOKuns16:
        case TOKint32:
        case TOKuns32:
        case TOKint64:
        case TOKuns64:
        case TOKint128:
        case TOKuns128:
        case TOKfloat32:
        case TOKfloat64:
        case TOKfloat80:
        case TOKimaginary32:
        case TOKimaginary64:
        case TOKimaginary80:
        case TOKcomplex32:
        case TOKcomplex64:
        case TOKcomplex80:
        case TOKvoid:
            p = ident.toChars();
            break;
        default:
            p = toChars(value);
            break;
        }
        return p;
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

/****************************************
 */

private immutable TOK[] keywords =
[
    TOKthis,
    TOKsuper,
    TOKassert,
    TOKnull,
    TOKtrue,
    TOKfalse,
    TOKcast,
    TOKnew,
    TOKdelete,
    TOKthrow,
    TOKmodule,
    TOKpragma,
    TOKtypeof,
    TOKtypeid,
    TOKtemplate,
    TOKvoid,
    TOKint8,
    TOKuns8,
    TOKint16,
    TOKuns16,
    TOKint32,
    TOKuns32,
    TOKint64,
    TOKuns64,
    TOKint128,
    TOKuns128,
    TOKfloat32,
    TOKfloat64,
    TOKfloat80,
    TOKbool,
    TOKchar,
    TOKwchar,
    TOKdchar,
    TOKimaginary32,
    TOKimaginary64,
    TOKimaginary80,
    TOKcomplex32,
    TOKcomplex64,
    TOKcomplex80,
    TOKdelegate,
    TOKfunction,
    TOKis,
    TOKif,
    TOKelse,
    TOKwhile,
    TOKfor,
    TOKdo,
    TOKswitch,
    TOKcase,
    TOKdefault,
    TOKbreak,
    TOKcontinue,
    TOKsynchronized,
    TOKreturn,
    TOKgoto,
    TOKtry,
    TOKcatch,
    TOKfinally,
    TOKwith,
    TOKasm,
    TOKforeach,
    TOKforeach_reverse,
    TOKscope,
    TOKstruct,
    TOKclass,
    TOKinterface,
    TOKunion,
    TOKenum,
    TOKimport,
    TOKmixin,
    TOKstatic,
    TOKfinal,
    TOKconst,
    TOKalias,
    TOKoverride,
    TOKabstract,
    TOKdebug,
    TOKdeprecated,
    TOKin,
    TOKout,
    TOKinout,
    TOKlazy,
    TOKauto,
    TOKalign,
    TOKextern,
    TOKprivate,
    TOKpackage,
    TOKprotected,
    TOKpublic,
    TOKexport,
    TOKinvariant,
    TOKunittest,
    TOKversion,
    TOKargTypes,
    TOKparameters,
    TOKref,
    TOKmacro,
    TOKpure,
    TOKnothrow,
    TOKgshared,
    TOKtraits,
    TOKvector,
    TOKoverloadset,
    TOKfile,
    TOKfilefullpath,
    TOKline,
    TOKmodulestring,
    TOKfuncstring,
    TOKprettyfunc,
    TOKshared,
    TOKimmutable,
];
