// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.parse;

import core.stdc.stdio;
import core.stdc.string;
import ddmd.aggregate;
import ddmd.aliasthis;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.cond;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dimport;
import ddmd.dmodule;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.dtemplate;
import ddmd.dversion;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.init;
import ddmd.lexer;
import ddmd.mtype;
import ddmd.nspace;
import ddmd.root.outbuffer;
import ddmd.root.rmem;
import ddmd.root.rootobject;
import ddmd.statement;
import ddmd.staticassert;
import ddmd.tokens;

// How multiple declarations are parsed.
// If 1, treat as C.
// If 0, treat:
//      int *p, i;
// as:
//      int* p;
//      int* i;
enum CDECLSYNTAX = 0;

// Support C cast syntax:
//      (type)(expression)
enum CCASTSYNTAX = 1;

// Support postfix C array declarations, such as
//      int a[3][4];
enum CARRAYDECL = 1;

/**********************************
 * Set operator precedence for each operator.
 */
__gshared PREC[TOKMAX] precedence =
[
    TOKtype : PREC_expr,
    TOKerror : PREC_expr,
    TOKtypeof : PREC_primary,
    TOKmixin : PREC_primary,
    TOKdotvar : PREC_primary,
    TOKimport : PREC_primary,
    TOKidentifier : PREC_primary,
    TOKthis : PREC_primary,
    TOKsuper : PREC_primary,
    TOKint64 : PREC_primary,
    TOKfloat64 : PREC_primary,
    TOKcomplex80 : PREC_primary,
    TOKnull : PREC_primary,
    TOKstring : PREC_primary,
    TOKarrayliteral : PREC_primary,
    TOKassocarrayliteral : PREC_primary,
    TOKclassreference : PREC_primary,
    TOKfile : PREC_primary,
    TOKline : PREC_primary,
    TOKmodulestring : PREC_primary,
    TOKfuncstring : PREC_primary,
    TOKprettyfunc : PREC_primary,
    TOKtypeid : PREC_primary,
    TOKis : PREC_primary,
    TOKassert : PREC_primary,
    TOKhalt : PREC_primary,
    TOKtemplate : PREC_primary,
    TOKdsymbol : PREC_primary,
    TOKfunction : PREC_primary,
    TOKvar : PREC_primary,
    TOKsymoff : PREC_primary,
    TOKstructliteral : PREC_primary,
    TOKarraylength : PREC_primary,
    TOKdelegateptr : PREC_primary,
    TOKdelegatefuncptr : PREC_primary,
    TOKremove : PREC_primary,
    TOKtuple : PREC_primary,
    TOKtraits : PREC_primary,
    TOKdefault : PREC_primary,
    TOKoverloadset : PREC_primary,
    TOKvoid : PREC_primary,
    // post
    TOKdotti : PREC_primary,
    TOKdot : PREC_primary,
    TOKdottd : PREC_primary,
    TOKdotexp : PREC_primary,
    TOKdottype : PREC_primary,
    TOKplusplus : PREC_primary,
    TOKminusminus : PREC_primary,
    TOKpreplusplus : PREC_primary,
    TOKpreminusminus : PREC_primary,
    TOKcall : PREC_primary,
    TOKslice : PREC_primary,
    TOKarray : PREC_primary,
    TOKindex : PREC_primary,
    TOKdelegate : PREC_unary,
    TOKaddress : PREC_unary,
    TOKstar : PREC_unary,
    TOKneg : PREC_unary,
    TOKuadd : PREC_unary,
    TOKnot : PREC_unary,
    TOKtobool : PREC_add,
    TOKtilde : PREC_unary,
    TOKdelete : PREC_unary,
    TOKnew : PREC_unary,
    TOKnewanonclass : PREC_unary,
    TOKcast : PREC_unary,
    TOKvector : PREC_unary,
    TOKpow : PREC_pow,
    TOKmul : PREC_mul,
    TOKdiv : PREC_mul,
    TOKmod : PREC_mul,
    TOKadd : PREC_add,
    TOKmin : PREC_add,
    TOKcat : PREC_add,
    TOKshl : PREC_shift,
    TOKshr : PREC_shift,
    TOKushr : PREC_shift,
    TOKlt : PREC_rel,
    TOKle : PREC_rel,
    TOKgt : PREC_rel,
    TOKge : PREC_rel,
    TOKunord : PREC_rel,
    TOKlg : PREC_rel,
    TOKleg : PREC_rel,
    TOKule : PREC_rel,
    TOKul : PREC_rel,
    TOKuge : PREC_rel,
    TOKug : PREC_rel,
    TOKue : PREC_rel,
    TOKin : PREC_rel,

    /* Note that we changed precedence, so that < and != have the same
     * precedence. This change is in the parser, too.
     */
    TOKequal : PREC_rel,
    TOKnotequal : PREC_rel,
    TOKidentity : PREC_rel,
    TOKnotidentity : PREC_rel,

    TOKand : PREC_and,
    TOKxor : PREC_xor,
    TOKor : PREC_or,
    TOKandand : PREC_andand,
    TOKoror : PREC_oror,
    TOKquestion : PREC_cond,
    TOKassign : PREC_assign,
    TOKconstruct : PREC_assign,
    TOKblit : PREC_assign,
    TOKaddass : PREC_assign,
    TOKminass : PREC_assign,
    TOKcatass : PREC_assign,
    TOKmulass : PREC_assign,
    TOKdivass : PREC_assign,
    TOKmodass : PREC_assign,
    TOKpowass : PREC_assign,
    TOKshlass : PREC_assign,
    TOKshrass : PREC_assign,
    TOKushrass : PREC_assign,
    TOKandass : PREC_assign,
    TOKorass : PREC_assign,
    TOKxorass : PREC_assign,
    TOKcomma : PREC_expr,
    TOKdeclaration : PREC_expr,
    TOKinterval : PREC_assign,
];

enum ParseStatementFlags : int
{
    PSsemi          = 1,        // empty ';' statements are allowed, but deprecated
    PSscope         = 2,        // start a new scope
    PScurly         = 4,        // { } statement is required
    PScurlyscope    = 8,        // { } starts a new scope
    PSsemi_ok       = 0x10,     // empty ';' are really ok
}

alias PSsemi = ParseStatementFlags.PSsemi;
alias PSscope = ParseStatementFlags.PSscope;
alias PScurly = ParseStatementFlags.PScurly;
alias PScurlyscope = ParseStatementFlags.PScurlyscope;
alias PSsemi_ok = ParseStatementFlags.PSsemi_ok;

struct PrefixAttributes
{
    StorageClass storageClass;
    Expression depmsg;
    LINK link;
    Prot protection;
    uint alignment;
    Expressions* udas;
    const(char)* comment;
}

/***********************************************************
 */
final class Parser : Lexer
{
public:
    Module mod;
    ModuleDeclaration* md;
    LINK linkage;
    Loc endloc; // set to location of last right curly
    int inBrackets; // inside [] of array index or slice
    Loc lookingForElse; // location of lonely if looking for an else

    /*********************
     * Use this constructor for string mixins.
     * Input:
     *      loc     location in source file of mixin
     */
    extern (D) this(Loc loc, Module _module, const(char)* base, size_t length, int doDocComment)
    {
        super(_module ? _module.srcfile.toChars() : null, base, 0, length, doDocComment, 0);
        //printf("Parser::Parser()\n");
        scanloc = loc;
        if (loc.filename)
        {
            /* Create a pseudo-filename for the mixin string, as it may not even exist
             * in the source file.
             */
            char* filename = cast(char*)mem.xmalloc(strlen(loc.filename) + 7 + (loc.linnum).sizeof * 3 + 1);
            sprintf(filename, "%s-mixin-%d", loc.filename, cast(int)loc.linnum);
            scanloc.filename = filename;
        }
        mod = _module;
        linkage = LINKd;
        //nextToken();              // start up the scanner
    }

    extern (D) this(Module _module, const(char)* base, size_t length, int doDocComment)
    {
        super(_module ? _module.srcfile.toChars() : null, base, 0, length, doDocComment, 0);
        //printf("Parser::Parser()\n");
        mod = _module;
        linkage = LINKd;
        //nextToken();              // start up the scanner
    }

    Dsymbols* parseModule()
    {
        const(char)* comment = token.blockComment;
        bool isdeprecated = false;
        Expression msg = null;
        Expressions* udas = null;
        Dsymbols* decldefs;
        Token* tk;
        if (skipAttributes(&token, &tk) && tk.value == TOKmodule)
        {
            while (token.value != TOKmodule)
            {
                switch (token.value)
                {
                case TOKdeprecated:
                    {
                        // deprecated (...) module ...
                        if (isdeprecated)
                        {
                            error("there is only one deprecation attribute allowed for module declaration");
                        }
                        else
                        {
                            isdeprecated = true;
                        }
                        nextToken();
                        if (token.value == TOKlparen)
                        {
                            check(TOKlparen);
                            msg = parseAssignExp();
                            check(TOKrparen);
                        }
                        break;
                    }
                case TOKat:
                    {
                        Expressions* exps = null;
                        StorageClass stc = parseAttribute(&exps);
                        if (stc == STCproperty || stc == STCnogc || stc == STCdisable || stc == STCsafe || stc == STCtrusted || stc == STCsystem)
                        {
                            error("@%s attribute for module declaration is not supported", token.toChars());
                        }
                        else
                        {
                            udas = UserAttributeDeclaration.concat(udas, exps);
                        }
                        if (stc)
                            nextToken();
                        break;
                    }
                default:
                    {
                        error("'module' expected instead of %s", token.toChars());
                        nextToken();
                        break;
                    }
                }
            }
        }
        if (udas)
        {
            auto a = new Dsymbols();
            auto udad = new UserAttributeDeclaration(udas, a);
            mod.userAttribDecl = udad;
        }
        // ModuleDeclation leads off
        if (token.value == TOKmodule)
        {
            Loc loc = token.loc;
            nextToken();
            if (token.value != TOKidentifier)
            {
                error("identifier expected following module");
                goto Lerr;
            }
            else
            {
                Identifiers* a = null;
                Identifier id;
                id = token.ident;
                while (nextToken() == TOKdot)
                {
                    if (!a)
                        a = new Identifiers();
                    a.push(id);
                    nextToken();
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected following package");
                        goto Lerr;
                    }
                    id = token.ident;
                }
                md = new ModuleDeclaration(loc, a, id);
                md.isdeprecated = isdeprecated;
                md.msg = msg;
                if (token.value != TOKsemicolon)
                    error("';' expected following module declaration instead of %s", token.toChars());
                nextToken();
                addComment(mod, comment);
            }
        }
        decldefs = parseDeclDefs(0);
        if (token.value != TOKeof)
        {
            error(token.loc, "unrecognized declaration");
            goto Lerr;
        }
        return decldefs;
    Lerr:
        while (token.value != TOKsemicolon && token.value != TOKeof)
            nextToken();
        nextToken();
        return new Dsymbols();
    }

    Dsymbols* parseDeclDefs(int once, Dsymbol* pLastDecl = null, PrefixAttributes* pAttrs = null)
    {
        Dsymbol lastDecl = null; // used to link unittest to its previous declaration
        if (!pLastDecl)
            pLastDecl = &lastDecl;
        LINK linksave = linkage; // save global state
        //printf("Parser::parseDeclDefs()\n");
        auto decldefs = new Dsymbols();
        do
        {
            // parse result
            Dsymbol s = null;
            Dsymbols* a = null;
            PrefixAttributes attrs;
            if (!once || !pAttrs)
            {
                pAttrs = &attrs;
                pAttrs.comment = token.blockComment;
            }
            PROTKIND prot;
            StorageClass stc;
            Condition condition;
            linkage = linksave;
            switch (token.value)
            {
            case TOKenum:
                {
                    /* Determine if this is a manifest constant declaration,
                     * or a conventional enum.
                     */
                    Token* t = peek(&token);
                    if (t.value == TOKlcurly || t.value == TOKcolon)
                        s = parseEnum();
                    else if (t.value != TOKidentifier)
                        goto Ldeclaration;
                    else
                    {
                        t = peek(t);
                        if (t.value == TOKlcurly || t.value == TOKcolon || t.value == TOKsemicolon)
                            s = parseEnum();
                        else
                            goto Ldeclaration;
                    }
                    break;
                }
            case TOKimport:
                a = parseImport();
                // keep pLastDecl
                break;
            case TOKtemplate:
                s = cast(Dsymbol)parseTemplateDeclaration();
                break;
            case TOKmixin:
                {
                    Loc loc = token.loc;
                    switch (peekNext())
                    {
                    case TOKlparen:
                        {
                            // mixin(string)
                            nextToken();
                            check(TOKlparen, "mixin");
                            Expression e = parseAssignExp();
                            check(TOKrparen);
                            check(TOKsemicolon);
                            s = new CompileDeclaration(loc, e);
                            break;
                        }
                    case TOKtemplate:
                        // mixin template
                        nextToken();
                        s = cast(Dsymbol)parseTemplateDeclaration(true);
                        break;
                    default:
                        s = parseMixin();
                        break;
                    }
                    break;
                }
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
            case TOKalias:
            case TOKtypedef:
            case TOKidentifier:
            case TOKsuper:
            case TOKtypeof:
            case TOKdot:
            case TOKvector:
            case TOKstruct:
            case TOKunion:
            case TOKclass:
            case TOKinterface:
            Ldeclaration:
                a = parseDeclarations(false, pAttrs, pAttrs.comment);
                if (a && a.dim)
                    *pLastDecl = (*a)[a.dim - 1];
                break;
            case TOKthis:
                if (peekNext() == TOKdot)
                    goto Ldeclaration;
                else
                    s = parseCtor(pAttrs);
                break;
            case TOKtilde:
                s = parseDtor(pAttrs);
                break;
            case TOKinvariant:
                {
                    Token* t = peek(&token);
                    if (t.value == TOKlparen && peek(t).value == TOKrparen || t.value == TOKlcurly)
                    {
                        // invariant {}
                        // invariant() {}
                        s = parseInvariant(pAttrs);
                    }
                    else
                    {
                        error("invariant body expected, not '%s'", token.toChars());
                        goto Lerror;
                    }
                    break;
                }
            case TOKunittest:
                if (global.params.useUnitTests || global.params.doDocComments || global.params.doHdrGeneration)
                {
                    s = parseUnitTest(pAttrs);
                    if (*pLastDecl)
                        (*pLastDecl).ddocUnittest = cast(UnitTestDeclaration)s;
                }
                else
                {
                    // Skip over unittest block by counting { }
                    Loc loc = token.loc;
                    int braces = 0;
                    while (1)
                    {
                        nextToken();
                        switch (token.value)
                        {
                        case TOKlcurly:
                            ++braces;
                            continue;
                        case TOKrcurly:
                            if (--braces)
                                continue;
                            nextToken();
                            break;
                        case TOKeof:
                            /* { */
                            error(loc, "closing } of unittest not found before end of file");
                            goto Lerror;
                        default:
                            continue;
                        }
                        break;
                    }
                    // Workaround 14894. Add an empty unittest declaration to keep
                    // the number of symbols in this scope independent of -unittest.
                    s = new UnitTestDeclaration(loc, token.loc, STCundefined, null);
                }
                break;
            case TOKnew:
                s = parseNew(pAttrs);
                break;
            case TOKdelete:
                s = parseDelete(pAttrs);
                break;
            case TOKcolon:
            case TOKlcurly:
                error("declaration expected, not '%s'", token.toChars());
                goto Lerror;
            case TOKrcurly:
            case TOKeof:
                if (once)
                    error("declaration expected, not '%s'", token.toChars());
                return decldefs;
            case TOKstatic:
                {
                    TOK next = peekNext();
                    if (next == TOKthis)
                        s = parseStaticCtor(pAttrs);
                    else if (next == TOKtilde)
                        s = parseStaticDtor(pAttrs);
                    else if (next == TOKassert)
                        s = parseStaticAssert();
                    else if (next == TOKif)
                    {
                        condition = parseStaticIfCondition();
                        Dsymbols* athen;
                        if (token.value == TOKcolon)
                            athen = parseBlock(pLastDecl);
                        else
                        {
                            Loc lookingForElseSave = lookingForElse;
                            lookingForElse = token.loc;
                            athen = parseBlock(pLastDecl);
                            lookingForElse = lookingForElseSave;
                        }
                        Dsymbols* aelse = null;
                        if (token.value == TOKelse)
                        {
                            Loc elseloc = token.loc;
                            nextToken();
                            aelse = parseBlock(pLastDecl);
                            checkDanglingElse(elseloc);
                        }
                        s = new StaticIfDeclaration(condition, athen, aelse);
                    }
                    else if (next == TOKimport)
                    {
                        a = parseImport();
                        // keep pLastDecl
                    }
                    else
                    {
                        stc = STCstatic;
                        goto Lstc;
                    }
                    break;
                }
            case TOKconst:
                if (peekNext() == TOKlparen)
                    goto Ldeclaration;
                stc = STCconst;
                goto Lstc;
            case TOKimmutable:
                if (peekNext() == TOKlparen)
                    goto Ldeclaration;
                stc = STCimmutable;
                goto Lstc;
            case TOKshared:
                {
                    TOK next = peekNext();
                    if (next == TOKlparen)
                        goto Ldeclaration;
                    if (next == TOKstatic)
                    {
                        TOK next2 = peekNext2();
                        if (next2 == TOKthis)
                        {
                            s = parseSharedStaticCtor(pAttrs);
                            break;
                        }
                        if (next2 == TOKtilde)
                        {
                            s = parseSharedStaticDtor(pAttrs);
                            break;
                        }
                    }
                    stc = STCshared;
                    goto Lstc;
                }
            case TOKwild:
                if (peekNext() == TOKlparen)
                    goto Ldeclaration;
                stc = STCwild;
                goto Lstc;
            case TOKfinal:
                stc = STCfinal;
                goto Lstc;
            case TOKauto:
                stc = STCauto;
                goto Lstc;
            case TOKscope:
                stc = STCscope;
                goto Lstc;
            case TOKoverride:
                stc = STCoverride;
                goto Lstc;
            case TOKabstract:
                stc = STCabstract;
                goto Lstc;
            case TOKsynchronized:
                stc = STCsynchronized;
                goto Lstc;
            case TOKnothrow:
                stc = STCnothrow;
                goto Lstc;
            case TOKpure:
                stc = STCpure;
                goto Lstc;
            case TOKref:
                stc = STCref;
                goto Lstc;
            case TOKgshared:
                stc = STCgshared;
                goto Lstc;
                //case TOKmanifest:   stc = STCmanifest;     goto Lstc;
            case TOKat:
                {
                    Expressions* exps = null;
                    stc = parseAttribute(&exps);
                    if (stc)
                        goto Lstc;
                    // it's a predefined attribute
                    // no redundant/conflicting check for UDAs
                    pAttrs.udas = UserAttributeDeclaration.concat(pAttrs.udas, exps);
                    goto Lautodecl;
                }
            Lstc:
                pAttrs.storageClass = appendStorageClass(pAttrs.storageClass, stc);
                nextToken();
            Lautodecl:
                Token* tk;
                /* Look for auto initializers:
                 *      storage_class identifier = initializer;
                 *      storage_class identifier(...) = initializer;
                 */
                if (token.value == TOKidentifier && skipParensIf(peek(&token), &tk) && tk.value == TOKassign)
                {
                    a = parseAutoDeclarations(pAttrs.storageClass, pAttrs.comment);
                    pAttrs.storageClass = STCundefined;
                    if (a && a.dim)
                        *pLastDecl = (*a)[a.dim - 1];
                    if (pAttrs.udas)
                    {
                        s = new UserAttributeDeclaration(pAttrs.udas, a);
                        pAttrs.udas = null;
                    }
                    break;
                }
                /* Look for return type inference for template functions.
                 */
                if (token.value == TOKidentifier && skipParens(peek(&token), &tk) && skipAttributes(tk, &tk) && (tk.value == TOKlparen || tk.value == TOKlcurly || tk.value == TOKin || tk.value == TOKout || tk.value == TOKbody))
                {
                    a = parseDeclarations(true, pAttrs, pAttrs.comment);
                    if (a && a.dim)
                        *pLastDecl = (*a)[a.dim - 1];
                    if (pAttrs.udas)
                    {
                        s = new UserAttributeDeclaration(pAttrs.udas, a);
                        pAttrs.udas = null;
                    }
                    break;
                }
                a = parseBlock(pLastDecl, pAttrs);
                if (pAttrs.storageClass != STCundefined)
                {
                    s = new StorageClassDeclaration(pAttrs.storageClass, a);
                    pAttrs.storageClass = STCundefined;
                }
                if (pAttrs.udas)
                {
                    if (s)
                        a = new Dsymbols(), a.push(s);
                    s = new UserAttributeDeclaration(pAttrs.udas, a);
                    pAttrs.udas = null;
                }
                break;
            case TOKdeprecated:
                {
                    if (peek(&token).value != TOKlparen)
                    {
                        stc = STCdeprecated;
                        goto Lstc;
                    }
                    nextToken();
                    check(TOKlparen);
                    Expression e = parseAssignExp();
                    check(TOKrparen);
                    if (pAttrs.depmsg)
                    {
                        error("conflicting storage class 'deprecated(%s)' and 'deprecated(%s)'", pAttrs.depmsg.toChars(), e.toChars());
                    }
                    pAttrs.depmsg = e;
                    a = parseBlock(pLastDecl, pAttrs);
                    if (pAttrs.depmsg)
                    {
                        s = new DeprecatedDeclaration(pAttrs.depmsg, a);
                        pAttrs.depmsg = null;
                    }
                    break;
                }
            case TOKlbracket:
                {
                    if (peekNext() == TOKrbracket)
                        error("empty attribute list is not allowed");
                    error("use @(attributes) instead of [attributes]");
                    Expressions* exps = parseArguments();
                    // no redundant/conflicting check for UDAs
                    pAttrs.udas = UserAttributeDeclaration.concat(pAttrs.udas, exps);
                    a = parseBlock(pLastDecl, pAttrs);
                    if (pAttrs.udas)
                    {
                        s = new UserAttributeDeclaration(pAttrs.udas, a);
                        pAttrs.udas = null;
                    }
                    break;
                }
            case TOKextern:
                {
                    if (peek(&token).value != TOKlparen)
                    {
                        stc = STCextern;
                        goto Lstc;
                    }
                    Loc linkLoc = token.loc;
                    Identifiers* idents = null;
                    LINK link = parseLinkage(&idents);
                    if (pAttrs.link != LINKdefault)
                    {
                        if (pAttrs.link != link)
                        {
                            error("conflicting linkage extern (%s) and extern (%s)", linkageToChars(pAttrs.link), linkageToChars(link));
                        }
                        else if (idents)
                        {
                            // Allow:
                            //      extern(C++, foo) extern(C++, bar) void foo();
                            // to be equivalent with:
                            //      extern(C++, foo.bar) void foo();
                        }
                        else
                            error("redundant linkage extern (%s)", linkageToChars(pAttrs.link));
                    }
                    pAttrs.link = link;
                    this.linkage = link;
                    a = parseBlock(pLastDecl, pAttrs);
                    if (idents)
                    {
                        assert(link == LINKcpp);
                        assert(idents.dim);
                        for (size_t i = idents.dim; i;)
                        {
                            Identifier id = (*idents)[--i];
                            if (s)
                                a = new Dsymbols(), a.push(s);
                            s = new Nspace(linkLoc, id, a);
                        }
                        pAttrs.link = LINKdefault;
                    }
                    else if (pAttrs.link != LINKdefault)
                    {
                        s = new LinkDeclaration(pAttrs.link, a);
                        pAttrs.link = LINKdefault;
                    }
                    break;
                }
            case TOKprivate:
                prot = PROTprivate;
                goto Lprot;
            case TOKpackage:
                prot = PROTpackage;
                goto Lprot;
            case TOKprotected:
                prot = PROTprotected;
                goto Lprot;
            case TOKpublic:
                prot = PROTpublic;
                goto Lprot;
            case TOKexport:
                prot = PROTexport;
                goto Lprot;
            Lprot:
                {
                    if (pAttrs.protection.kind != PROTundefined)
                    {
                        if (pAttrs.protection.kind != prot)
                            error("conflicting protection attribute '%s' and '%s'", protectionToChars(pAttrs.protection.kind), protectionToChars(prot));
                        else
                            error("redundant protection attribute '%s'", protectionToChars(prot));
                    }
                    pAttrs.protection.kind = prot;
                    nextToken();
                    // optional qualified package identifier to bind
                    // protection to
                    Identifiers* pkg_prot_idents = null;
                    if (pAttrs.protection.kind == PROTpackage && token.value == TOKlparen)
                    {
                        pkg_prot_idents = parseQualifiedIdentifier("protection package");
                        if (pkg_prot_idents)
                            check(TOKrparen);
                        else
                        {
                            while (token.value != TOKsemicolon && token.value != TOKeof)
                                nextToken();
                            nextToken();
                            break;
                        }
                    }
                    Loc attrloc = token.loc;
                    a = parseBlock(pLastDecl, pAttrs);
                    if (pAttrs.protection.kind != PROTundefined)
                    {
                        if (pAttrs.protection.kind == PROTpackage && pkg_prot_idents)
                            s = new ProtDeclaration(attrloc, pkg_prot_idents, a);
                        else
                            s = new ProtDeclaration(attrloc, pAttrs.protection, a);
                        pAttrs.protection = Prot(PROTundefined);
                    }
                    break;
                }
            case TOKalign:
                {
                    nextToken();
                    uint n;
                    if (token.value == TOKlparen)
                    {
                        nextToken();
                        if (token.value == TOKint32v && token.uns64value > 0)
                        {
                            if (token.uns64value & (token.uns64value - 1))
                                error("align(%s) must be a power of 2", token.toChars());
                            n = cast(uint)token.uns64value;
                        }
                        else
                        {
                            error("positive integer expected, not %s", token.toChars());
                            n = 1;
                        }
                        nextToken();
                        check(TOKrparen);
                    }
                    else
                        n = STRUCTALIGN_DEFAULT; // default
                    if (pAttrs.alignment != 0)
                    {
                        const(char)* s1 = "";
                        OutBuffer buf1;
                        if (n != STRUCTALIGN_DEFAULT)
                        {
                            buf1.printf("(%d)", n);
                            s1 = buf1.peekString();
                        }
                        if (pAttrs.alignment != n)
                        {
                            OutBuffer buf2;
                            const(char)* s2 = "";
                            if (pAttrs.alignment != STRUCTALIGN_DEFAULT)
                            {
                                buf2.printf("(%d)", pAttrs.alignment);
                                s2 = buf2.peekString();
                            }
                            error("conflicting alignment attribute align%s and align%s", s2, s1);
                        }
                        else
                            error("redundant alignment attribute align%s", s1);
                    }
                    pAttrs.alignment = n;
                    a = parseBlock(pLastDecl, pAttrs);
                    if (pAttrs.alignment != 0)
                    {
                        s = new AlignDeclaration(pAttrs.alignment, a);
                        pAttrs.alignment = 0;
                    }
                    break;
                }
            case TOKpragma:
                {
                    Expressions* args = null;
                    Loc loc = token.loc;
                    nextToken();
                    check(TOKlparen);
                    if (token.value != TOKidentifier)
                    {
                        error("pragma(identifier) expected");
                        goto Lerror;
                    }
                    Identifier ident = token.ident;
                    nextToken();
                    if (token.value == TOKcomma && peekNext() != TOKrparen)
                        args = parseArguments(); // pragma(identifier, args...)
                    else
                        check(TOKrparen); // pragma(identifier)
                    Dsymbols* a2 = null;
                    if (token.value == TOKsemicolon)
                    {
                        /* Bugzilla 2354: Accept single semicolon as an empty
                         * DeclarationBlock following attribute.
                         *
                         * Attribute DeclarationBlock
                         * Pragma    DeclDef
                         *           ;
                         */
                        nextToken();
                    }
                    else
                        a2 = parseBlock(pLastDecl);
                    s = new PragmaDeclaration(loc, ident, args, a2);
                    break;
                }
            case TOKdebug:
                nextToken();
                if (token.value == TOKassign)
                {
                    nextToken();
                    if (token.value == TOKidentifier)
                        s = new DebugSymbol(token.loc, token.ident);
                    else if (token.value == TOKint32v || token.value == TOKint64v)
                        s = new DebugSymbol(token.loc, cast(uint)token.uns64value);
                    else
                    {
                        error("identifier or integer expected, not %s", token.toChars());
                        s = null;
                    }
                    nextToken();
                    if (token.value != TOKsemicolon)
                        error("semicolon expected");
                    nextToken();
                    break;
                }
                condition = parseDebugCondition();
                goto Lcondition;
            case TOKversion:
                nextToken();
                if (token.value == TOKassign)
                {
                    nextToken();
                    if (token.value == TOKidentifier)
                        s = new VersionSymbol(token.loc, token.ident);
                    else if (token.value == TOKint32v || token.value == TOKint64v)
                        s = new VersionSymbol(token.loc, cast(uint)token.uns64value);
                    else
                    {
                        error("identifier or integer expected, not %s", token.toChars());
                        s = null;
                    }
                    nextToken();
                    if (token.value != TOKsemicolon)
                        error("semicolon expected");
                    nextToken();
                    break;
                }
                condition = parseVersionCondition();
                goto Lcondition;
            Lcondition:
                {
                    Dsymbols* athen;
                    if (token.value == TOKcolon)
                        athen = parseBlock(pLastDecl);
                    else
                    {
                        Loc lookingForElseSave = lookingForElse;
                        lookingForElse = token.loc;
                        athen = parseBlock(pLastDecl);
                        lookingForElse = lookingForElseSave;
                    }
                    Dsymbols* aelse = null;
                    if (token.value == TOKelse)
                    {
                        Loc elseloc = token.loc;
                        nextToken();
                        aelse = parseBlock(pLastDecl);
                        checkDanglingElse(elseloc);
                    }
                    s = new ConditionalDeclaration(condition, athen, aelse);
                    break;
                }
            case TOKsemicolon:
                // empty declaration
                //error("empty declaration");
                nextToken();
                continue;
            default:
                error("declaration expected, not '%s'", token.toChars());
            Lerror:
                while (token.value != TOKsemicolon && token.value != TOKeof)
                    nextToken();
                nextToken();
                s = null;
                continue;
            }
            if (s)
            {
                if (!s.isAttribDeclaration())
                    *pLastDecl = s;
                decldefs.push(s);
                addComment(s, pAttrs.comment);
            }
            else if (a && a.dim)
            {
                decldefs.append(a);
            }
        }
        while (!once);
        linkage = linksave;
        return decldefs;
    }

    /*****************************************
     * Parse auto declarations of the form:
     *   storageClass ident = init, ident = init, ... ;
     * and return the array of them.
     * Starts with token on the first ident.
     * Ends with scanner past closing ';'
     */
    Dsymbols* parseAutoDeclarations(StorageClass storageClass, const(char)* comment)
    {
        //printf("parseAutoDeclarations\n");
        Token* tk;
        auto a = new Dsymbols();
        while (1)
        {
            Loc loc = token.loc;
            Identifier ident = token.ident;
            nextToken(); // skip over ident
            TemplateParameters* tpl = null;
            if (token.value == TOKlparen)
                tpl = parseTemplateParameterList();
            check(TOKassign);   // skip over '='
            Initializer _init = parseInitializer();
            auto v = new VarDeclaration(loc, null, ident, _init);
            v.storage_class = storageClass;
            Dsymbol s = v;
            if (tpl)
            {
                auto a2 = new Dsymbols();
                a2.push(v);
                auto tempdecl = new TemplateDeclaration(loc, ident, tpl, null, a2, 0);
                s = tempdecl;
            }
            a.push(s);
            switch (token.value)
            {
            case TOKsemicolon:
                nextToken();
                addComment(s, comment);
                break;
            case TOKcomma:
                nextToken();
                if (!(token.value == TOKidentifier && skipParensIf(peek(&token), &tk) && tk.value == TOKassign))
                {
                    error("identifier expected following comma");
                    break;
                }
                addComment(s, comment);
                continue;
            default:
                error("semicolon expected following auto declaration, not '%s'", token.toChars());
                break;
            }
            break;
        }
        return a;
    }

    /********************************************
     * Parse declarations after an align, protection, or extern decl.
     */
    Dsymbols* parseBlock(Dsymbol* pLastDecl, PrefixAttributes* pAttrs = null)
    {
        Dsymbols* a = null;
        //printf("parseBlock()\n");
        switch (token.value)
        {
        case TOKsemicolon:
            error("declaration expected following attribute, not ';'");
            nextToken();
            break;
        case TOKeof:
            error("declaration expected following attribute, not EOF");
            break;
        case TOKlcurly:
            {
                Loc lookingForElseSave = lookingForElse;
                lookingForElse = Loc();
                nextToken();
                a = parseDeclDefs(0, pLastDecl);
                if (token.value != TOKrcurly)
                {
                    /* { */
                    error("matching '}' expected, not %s", token.toChars());
                }
                else
                    nextToken();
                lookingForElse = lookingForElseSave;
                break;
            }
        case TOKcolon:
            nextToken();
            a = parseDeclDefs(0, pLastDecl); // grab declarations up to closing curly bracket
            break;
        default:
            a = parseDeclDefs(1, pLastDecl, pAttrs);
            break;
        }
        return a;
    }

    /*********************************************
     * Give error on redundant/conflicting storage class.
     *
     * TODO: remove deprecation in 2.068 and keep only error
     */
    StorageClass appendStorageClass(StorageClass storageClass, StorageClass stc, bool deprec = false)
    {
        if ((storageClass & stc) || (storageClass & STCin && stc & (STCconst | STCscope)) || (stc & STCin && storageClass & (STCconst | STCscope)))
        {
            OutBuffer buf;
            stcToBuffer(&buf, stc);
            if (deprec)
                deprecation("redundant attribute '%s'", buf.peekString());
            else
                error("redundant attribute '%s'", buf.peekString());
            return storageClass | stc;
        }
        storageClass |= stc;
        if (stc & (STCconst | STCimmutable | STCmanifest))
        {
            StorageClass u = storageClass & (STCconst | STCimmutable | STCmanifest);
            if (u & (u - 1))
                error("conflicting attribute '%s'", Token.toChars(token.value));
        }
        if (stc & (STCgshared | STCshared | STCtls))
        {
            StorageClass u = storageClass & (STCgshared | STCshared | STCtls);
            if (u & (u - 1))
                error("conflicting attribute '%s'", Token.toChars(token.value));
        }
        if (stc & (STCsafe | STCsystem | STCtrusted))
        {
            StorageClass u = storageClass & (STCsafe | STCsystem | STCtrusted);
            if (u & (u - 1))
                error("conflicting attribute '@%s'", token.toChars());
        }
        return storageClass;
    }

    /***********************************************
     * Parse attribute, lexer is on '@'.
     * Input:
     *      pudas           array of UDAs to append to
     * Returns:
     *      storage class   if a predefined attribute; also scanner remains on identifier.
     *      0               if not a predefined attribute
     *      *pudas          set if user defined attribute, scanner is past UDA
     *      *pudas          NULL if not a user defined attribute
     */
    StorageClass parseAttribute(Expressions** pudas)
    {
        nextToken();
        Expressions* udas = null;
        StorageClass stc = 0;
        if (token.value == TOKidentifier)
        {
            if (token.ident == Id.property)
                stc = STCproperty;
            else if (token.ident == Id.nogc)
                stc = STCnogc;
            else if (token.ident == Id.safe)
                stc = STCsafe;
            else if (token.ident == Id.trusted)
                stc = STCtrusted;
            else if (token.ident == Id.system)
                stc = STCsystem;
            else if (token.ident == Id.disable)
                stc = STCdisable;
            else
            {
                // Allow identifier, template instantiation, or function call
                Expression exp = parsePrimaryExp();
                if (token.value == TOKlparen)
                {
                    Loc loc = token.loc;
                    exp = new CallExp(loc, exp, parseArguments());
                }
                udas = new Expressions();
                udas.push(exp);
            }
        }
        else if (token.value == TOKlparen)
        {
            // @( ArgumentList )
            // Concatenate with existing
            if (peekNext() == TOKrparen)
                error("empty attribute list is not allowed");
            udas = parseArguments();
        }
        else
        {
            error("@identifier or @(ArgumentList) expected, not @%s", token.toChars());
        }
        if (stc)
        {
        }
        else if (udas)
        {
            *pudas = UserAttributeDeclaration.concat(*pudas, udas);
        }
        else
            error("valid attributes are @property, @safe, @trusted, @system, @disable");
        return stc;
    }

    /***********************************************
     * Parse const/immutable/shared/inout/nothrow/pure postfix
     */
    StorageClass parsePostfix(StorageClass storageClass, Expressions** pudas)
    {
        while (1)
        {
            StorageClass stc;
            switch (token.value)
            {
            case TOKconst:
                stc = STCconst;
                break;
            case TOKimmutable:
                stc = STCimmutable;
                break;
            case TOKshared:
                stc = STCshared;
                break;
            case TOKwild:
                stc = STCwild;
                break;
            case TOKnothrow:
                stc = STCnothrow;
                break;
            case TOKpure:
                stc = STCpure;
                break;
            case TOKreturn:
                stc = STCreturn;
                break;
            case TOKat:
                {
                    Expressions* udas = null;
                    stc = parseAttribute(&udas);
                    if (udas)
                    {
                        if (pudas)
                            *pudas = UserAttributeDeclaration.concat(*pudas, udas);
                        else
                        {
                            // Disallow:
                            //      void function() @uda fp;
                            //      () @uda { return 1; }
                            error("user defined attributes cannot appear as postfixes");
                        }
                        continue;
                    }
                    break;
                }
            default:
                return storageClass;
            }
            storageClass = appendStorageClass(storageClass, stc, true);
            nextToken();
        }
    }

    StorageClass parseTypeCtor()
    {
        StorageClass storageClass = STCundefined;
        while (1)
        {
            if (peek(&token).value == TOKlparen)
                return storageClass;
            StorageClass stc;
            switch (token.value)
            {
            case TOKconst:
                stc = STCconst;
                break;
            case TOKimmutable:
                stc = STCimmutable;
                break;
            case TOKshared:
                stc = STCshared;
                break;
            case TOKwild:
                stc = STCwild;
                break;
            default:
                return storageClass;
            }
            storageClass = appendStorageClass(storageClass, stc);
            nextToken();
        }
    }

    /**************************************
     * Parse constraint.
     * Constraint is of the form:
     *      if ( ConstraintExpression )
     */
    Expression parseConstraint()
    {
        Expression e = null;
        if (token.value == TOKif)
        {
            nextToken(); // skip over 'if'
            check(TOKlparen);
            e = parseExpression();
            check(TOKrparen);
        }
        return e;
    }

    /**************************************
     * Parse a TemplateDeclaration.
     */
    TemplateDeclaration parseTemplateDeclaration(bool ismixin = false)
    {
        TemplateDeclaration tempdecl;
        Identifier id;
        TemplateParameters* tpl;
        Dsymbols* decldefs;
        Expression constraint = null;
        Loc loc = token.loc;
        nextToken();
        if (token.value != TOKidentifier)
        {
            error("identifier expected following template");
            goto Lerr;
        }
        id = token.ident;
        nextToken();
        tpl = parseTemplateParameterList();
        if (!tpl)
            goto Lerr;
        constraint = parseConstraint();
        if (token.value != TOKlcurly)
        {
            error("members of template declaration expected");
            goto Lerr;
        }
        else
        {
            nextToken();
            decldefs = parseDeclDefs(0);
            if (token.value != TOKrcurly)
            {
                error("template member expected");
                goto Lerr;
            }
            nextToken();
        }
        tempdecl = new TemplateDeclaration(loc, id, tpl, constraint, decldefs, ismixin);
        return tempdecl;
    Lerr:
        return null;
    }

    /******************************************
     * Parse template parameter list.
     * Input:
     *      flag    0: parsing "( list )"
     *              1: parsing non-empty "list )"
     */
    TemplateParameters* parseTemplateParameterList(int flag = 0)
    {
        auto tpl = new TemplateParameters();
        if (!flag && token.value != TOKlparen)
        {
            error("parenthesized TemplateParameterList expected following TemplateIdentifier");
            goto Lerr;
        }
        nextToken();
        // Get array of TemplateParameters
        if (flag || token.value != TOKrparen)
        {
            int isvariadic = 0;
            while (token.value != TOKrparen)
            {
                TemplateParameter tp;
                Loc loc;
                Identifier tp_ident = null;
                Type tp_spectype = null;
                Type tp_valtype = null;
                Type tp_defaulttype = null;
                Expression tp_specvalue = null;
                Expression tp_defaultvalue = null;
                Token* t;
                // Get TemplateParameter
                // First, look ahead to see if it is a TypeParameter or a ValueParameter
                t = peek(&token);
                if (token.value == TOKalias)
                {
                    // AliasParameter
                    nextToken();
                    loc = token.loc; // todo
                    Type spectype = null;
                    if (isDeclaration(&token, 2, TOKreserved, null))
                    {
                        spectype = parseType(&tp_ident);
                    }
                    else
                    {
                        if (token.value != TOKidentifier)
                        {
                            error("identifier expected for template alias parameter");
                            goto Lerr;
                        }
                        tp_ident = token.ident;
                        nextToken();
                    }
                    RootObject spec = null;
                    if (token.value == TOKcolon) // : Type
                    {
                        nextToken();
                        if (isDeclaration(&token, 0, TOKreserved, null))
                            spec = parseType();
                        else
                            spec = parseCondExp();
                    }
                    RootObject def = null;
                    if (token.value == TOKassign) // = Type
                    {
                        nextToken();
                        if (isDeclaration(&token, 0, TOKreserved, null))
                            def = parseType();
                        else
                            def = parseCondExp();
                    }
                    tp = new TemplateAliasParameter(loc, tp_ident, spectype, spec, def);
                }
                else if (t.value == TOKcolon || t.value == TOKassign || t.value == TOKcomma || t.value == TOKrparen)
                {
                    // TypeParameter
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected for template type parameter");
                        goto Lerr;
                    }
                    loc = token.loc;
                    tp_ident = token.ident;
                    nextToken();
                    if (token.value == TOKcolon) // : Type
                    {
                        nextToken();
                        tp_spectype = parseType();
                    }
                    if (token.value == TOKassign) // = Type
                    {
                        nextToken();
                        tp_defaulttype = parseType();
                    }
                    tp = new TemplateTypeParameter(loc, tp_ident, tp_spectype, tp_defaulttype);
                }
                else if (token.value == TOKidentifier && t.value == TOKdotdotdot)
                {
                    // ident...
                    if (isvariadic)
                        error("variadic template parameter must be last");
                    isvariadic = 1;
                    loc = token.loc;
                    tp_ident = token.ident;
                    nextToken();
                    nextToken();
                    tp = new TemplateTupleParameter(loc, tp_ident);
                }
                else if (token.value == TOKthis)
                {
                    // ThisParameter
                    nextToken();
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected for template this parameter");
                        goto Lerr;
                    }
                    loc = token.loc;
                    tp_ident = token.ident;
                    nextToken();
                    if (token.value == TOKcolon) // : Type
                    {
                        nextToken();
                        tp_spectype = parseType();
                    }
                    if (token.value == TOKassign) // = Type
                    {
                        nextToken();
                        tp_defaulttype = parseType();
                    }
                    tp = new TemplateThisParameter(loc, tp_ident, tp_spectype, tp_defaulttype);
                }
                else
                {
                    // ValueParameter
                    loc = token.loc; // todo
                    tp_valtype = parseType(&tp_ident);
                    if (!tp_ident)
                    {
                        error("identifier expected for template value parameter");
                        tp_ident = new Identifier("error", TOKidentifier);
                    }
                    if (token.value == TOKcolon) // : CondExpression
                    {
                        nextToken();
                        tp_specvalue = parseCondExp();
                    }
                    if (token.value == TOKassign) // = CondExpression
                    {
                        nextToken();
                        tp_defaultvalue = parseDefaultInitExp();
                    }
                    tp = new TemplateValueParameter(loc, tp_ident, tp_valtype, tp_specvalue, tp_defaultvalue);
                }
                tpl.push(tp);
                if (token.value != TOKcomma)
                    break;
                nextToken();
            }
        }
        check(TOKrparen);
    Lerr:
        return tpl;
    }

    /******************************************
     * Parse template mixin.
     *      mixin Foo;
     *      mixin Foo!(args);
     *      mixin a.b.c!(args).Foo!(args);
     *      mixin Foo!(args) identifier;
     *      mixin typeof(expr).identifier!(args);
     */
    Dsymbol parseMixin()
    {
        TemplateMixin tm;
        Identifier id;
        Objects* tiargs;
        //printf("parseMixin()\n");
        Loc locMixin = token.loc;
        nextToken(); // skip 'mixin'
        Loc loc = token.loc;
        TypeQualified tqual = null;
        if (token.value == TOKdot)
        {
            id = Id.empty;
        }
        else
        {
            if (token.value == TOKtypeof)
            {
                tqual = parseTypeof();
                check(TOKdot);
            }
            if (token.value != TOKidentifier)
            {
                error("identifier expected, not %s", token.toChars());
                id = Id.empty;
            }
            else
                id = token.ident;
            nextToken();
        }
        while (1)
        {
            tiargs = null;
            if (token.value == TOKnot)
            {
                tiargs = parseTemplateArguments();
            }
            if (tiargs && token.value == TOKdot)
            {
                auto tempinst = new TemplateInstance(loc, id);
                tempinst.tiargs = tiargs;
                if (!tqual)
                    tqual = new TypeInstance(loc, tempinst);
                else
                    tqual.addInst(tempinst);
                tiargs = null;
            }
            else
            {
                if (!tqual)
                    tqual = new TypeIdentifier(loc, id);
                else
                    tqual.addIdent(id);
            }
            if (token.value != TOKdot)
                break;
            nextToken();
            if (token.value != TOKidentifier)
            {
                error("identifier expected following '.' instead of '%s'", token.toChars());
                break;
            }
            loc = token.loc;
            id = token.ident;
            nextToken();
        }
        if (token.value == TOKidentifier)
        {
            id = token.ident;
            nextToken();
        }
        else
            id = null;
        tm = new TemplateMixin(locMixin, id, tqual, tiargs);
        if (token.value != TOKsemicolon)
            error("';' expected after mixin");
        nextToken();
        return tm;
    }

    /******************************************
     * Parse template arguments.
     * Input:
     *      current token is opening '!'
     * Output:
     *      current token is one after closing ')'
     */
    Objects* parseTemplateArguments()
    {
        Objects* tiargs;
        nextToken();
        if (token.value == TOKlparen)
        {
            // ident!(template_arguments)
            tiargs = parseTemplateArgumentList();
        }
        else
        {
            // ident!template_argument
            tiargs = parseTemplateSingleArgument();
        }
        if (token.value == TOKnot)
        {
            TOK tok = peekNext();
            if (tok != TOKis && tok != TOKin)
            {
                error("multiple ! arguments are not allowed");
            Lagain:
                nextToken();
                if (token.value == TOKlparen)
                    parseTemplateArgumentList();
                else
                    parseTemplateSingleArgument();
                if (token.value == TOKnot && (tok = peekNext()) != TOKis && tok != TOKin)
                    goto Lagain;
            }
        }
        return tiargs;
    }

    /******************************************
     * Parse template argument list.
     * Input:
     *      current token is opening '(',
     *          or ',' for __traits
     * Output:
     *      current token is one after closing ')'
     */
    Objects* parseTemplateArgumentList()
    {
        //printf("Parser::parseTemplateArgumentList()\n");
        auto tiargs = new Objects();
        TOK endtok = TOKrparen;
        assert(token.value == TOKlparen || token.value == TOKcomma);
        nextToken();
        // Get TemplateArgumentList
        while (token.value != endtok)
        {
            // See if it is an Expression or a Type
            if (isDeclaration(&token, 0, TOKreserved, null))
            {
                // Template argument is a type
                Type ta = parseType();
                tiargs.push(ta);
            }
            else
            {
                // Template argument is an expression
                Expression ea = parseAssignExp();
                tiargs.push(ea);
            }
            if (token.value != TOKcomma)
                break;
            nextToken();
        }
        check(endtok, "template argument list");
        return tiargs;
    }

    /*****************************
     * Parse single template argument, to support the syntax:
     *      foo!arg
     * Input:
     *      current token is the arg
     */
    Objects* parseTemplateSingleArgument()
    {
        //printf("parseTemplateSingleArgument()\n");
        auto tiargs = new Objects();
        Type ta;
        switch (token.value)
        {
        case TOKidentifier:
            ta = new TypeIdentifier(token.loc, token.ident);
            goto LabelX;
        case TOKvector:
            ta = parseVector();
            goto LabelX;
        case TOKvoid:
            ta = Type.tvoid;
            goto LabelX;
        case TOKint8:
            ta = Type.tint8;
            goto LabelX;
        case TOKuns8:
            ta = Type.tuns8;
            goto LabelX;
        case TOKint16:
            ta = Type.tint16;
            goto LabelX;
        case TOKuns16:
            ta = Type.tuns16;
            goto LabelX;
        case TOKint32:
            ta = Type.tint32;
            goto LabelX;
        case TOKuns32:
            ta = Type.tuns32;
            goto LabelX;
        case TOKint64:
            ta = Type.tint64;
            goto LabelX;
        case TOKuns64:
            ta = Type.tuns64;
            goto LabelX;
        case TOKint128:
            ta = Type.tint128;
            goto LabelX;
        case TOKuns128:
            ta = Type.tuns128;
            goto LabelX;
        case TOKfloat32:
            ta = Type.tfloat32;
            goto LabelX;
        case TOKfloat64:
            ta = Type.tfloat64;
            goto LabelX;
        case TOKfloat80:
            ta = Type.tfloat80;
            goto LabelX;
        case TOKimaginary32:
            ta = Type.timaginary32;
            goto LabelX;
        case TOKimaginary64:
            ta = Type.timaginary64;
            goto LabelX;
        case TOKimaginary80:
            ta = Type.timaginary80;
            goto LabelX;
        case TOKcomplex32:
            ta = Type.tcomplex32;
            goto LabelX;
        case TOKcomplex64:
            ta = Type.tcomplex64;
            goto LabelX;
        case TOKcomplex80:
            ta = Type.tcomplex80;
            goto LabelX;
        case TOKbool:
            ta = Type.tbool;
            goto LabelX;
        case TOKchar:
            ta = Type.tchar;
            goto LabelX;
        case TOKwchar:
            ta = Type.twchar;
            goto LabelX;
        case TOKdchar:
            ta = Type.tdchar;
            goto LabelX;
        LabelX:
            tiargs.push(ta);
            nextToken();
            break;
        case TOKint32v:
        case TOKuns32v:
        case TOKint64v:
        case TOKuns64v:
        case TOKint128v:
        case TOKuns128v:
        case TOKfloat32v:
        case TOKfloat64v:
        case TOKfloat80v:
        case TOKimaginary32v:
        case TOKimaginary64v:
        case TOKimaginary80v:
        case TOKnull:
        case TOKtrue:
        case TOKfalse:
        case TOKcharv:
        case TOKwcharv:
        case TOKdcharv:
        case TOKstring:
        case TOKxstring:
        case TOKfile:
        case TOKline:
        case TOKmodulestring:
        case TOKfuncstring:
        case TOKprettyfunc:
        case TOKthis:
            {
                // Template argument is an expression
                Expression ea = parsePrimaryExp();
                tiargs.push(ea);
                break;
            }
        default:
            error("template argument expected following !");
            break;
        }
        return tiargs;
    }

    /**********************************
     * Parse a static assertion.
     * Current token is 'static'.
     */
    StaticAssert parseStaticAssert()
    {
        Loc loc = token.loc;
        Expression exp;
        Expression msg = null;
        //printf("parseStaticAssert()\n");
        nextToken();
        nextToken();
        check(TOKlparen);
        exp = parseAssignExp();
        if (token.value == TOKcomma)
        {
            nextToken();
            msg = parseAssignExp();
        }
        check(TOKrparen);
        check(TOKsemicolon);
        return new StaticAssert(loc, exp, msg);
    }

    /***********************************
     * Parse typeof(expression).
     * Current token is on the 'typeof'.
     */
    TypeQualified parseTypeof()
    {
        TypeQualified t;
        Loc loc = token.loc;
        nextToken();
        check(TOKlparen);
        if (token.value == TOKreturn) // typeof(return)
        {
            nextToken();
            t = new TypeReturn(loc);
        }
        else
        {
            Expression exp = parseExpression(); // typeof(expression)
            t = new TypeTypeof(loc, exp);
        }
        check(TOKrparen);
        return t;
    }

    /***********************************
     * Parse __vector(type).
     * Current token is on the '__vector'.
     */
    Type parseVector()
    {
        Loc loc = token.loc;
        nextToken();
        check(TOKlparen);
        Type tb = parseType();
        check(TOKrparen);
        return new TypeVector(loc, tb);
    }

    /***********************************
     * Parse:
     *      extern (linkage)
     *      extern (C++, namespaces)
     * The parser is on the 'extern' token.
     */
    LINK parseLinkage(Identifiers** pidents)
    {
        Identifiers* idents = null;
        LINK link = LINKdefault;
        nextToken();
        assert(token.value == TOKlparen);
        nextToken();
        if (token.value == TOKidentifier)
        {
            Identifier id = token.ident;
            nextToken();
            if (id == Id.Windows)
                link = LINKwindows;
            else if (id == Id.Pascal)
                link = LINKpascal;
            else if (id == Id.D)
                link = LINKd;
            else if (id == Id.C)
            {
                link = LINKc;
                if (token.value == TOKplusplus)
                {
                    link = LINKcpp;
                    nextToken();
                    if (token.value == TOKcomma) // , namespaces
                    {
                        idents = new Identifiers();
                        nextToken();
                        while (1)
                        {
                            if (token.value == TOKidentifier)
                            {
                                Identifier idn = token.ident;
                                idents.push(idn);
                                nextToken();
                                if (token.value == TOKdot)
                                {
                                    nextToken();
                                    continue;
                                }
                            }
                            else
                                error("identifier expected for C++ namespace");
                            break;
                        }
                    }
                }
            }
            else if (id == Id.Objective) // Looking for tokens "Objective-C"
            {
                if (token.value == TOKmin)
                {
                    nextToken();
                    if (token.ident == Id.C)
                    {
                        link = LINKobjc;
                        nextToken();
                    }
                    else
                        goto LinvalidLinkage;
                }
                else
                    goto LinvalidLinkage;
            }
            else if (id == Id.System)
            {
                link = global.params.isWindows ? LINKwindows : LINKc;
            }
            else
            {
            LinvalidLinkage:
                error("valid linkage identifiers are D, C, C++, Objective-C, Pascal, Windows, System");
                link = LINKd;
            }
        }
        else
        {
            link = LINKd; // default
        }
        check(TOKrparen);
        *pidents = idents;
        return link;
    }

    /***********************************
     * Parse ident1.ident2.ident3
     *
     * Params:
     *  entity = what qualified identifier is expected to resolve into.
     *     Used only for better error message
     *
     * Returns:
     *     array of identifiers with actual qualified one stored last
     */
    Identifiers* parseQualifiedIdentifier(const(char)* entity)
    {
        Identifiers* qualified = null;
        do
        {
            nextToken();
            if (token.value != TOKidentifier)
            {
                error("%s expected as dot-separated identifiers, got '%s'", entity, token.toChars());
                return null;
            }
            Identifier id = token.ident;
            if (!qualified)
                qualified = new Identifiers();
            qualified.push(id);
            nextToken();
        }
        while (token.value == TOKdot);
        return qualified;
    }

    /**************************************
     * Parse a debug conditional
     */
    Condition parseDebugCondition()
    {
        Condition c;
        if (token.value == TOKlparen)
        {
            nextToken();
            uint level = 1;
            Identifier id = null;
            if (token.value == TOKidentifier)
                id = token.ident;
            else if (token.value == TOKint32v || token.value == TOKint64v)
                level = cast(uint)token.uns64value;
            else
                error("identifier or integer expected, not %s", token.toChars());
            nextToken();
            check(TOKrparen);
            c = new DebugCondition(mod, level, id);
        }
        else
            c = new DebugCondition(mod, 1, null);
        return c;
    }

    /**************************************
     * Parse a version conditional
     */
    Condition parseVersionCondition()
    {
        Condition c;
        uint level = 1;
        Identifier id = null;
        if (token.value == TOKlparen)
        {
            nextToken();
            /* Allow:
             *    version (unittest)
             *    version (assert)
             * even though they are keywords
             */
            if (token.value == TOKidentifier)
                id = token.ident;
            else if (token.value == TOKint32v || token.value == TOKint64v)
                level = cast(uint)token.uns64value;
            else if (token.value == TOKunittest)
                id = Identifier.idPool(Token.toChars(TOKunittest));
            else if (token.value == TOKassert)
                id = Identifier.idPool(Token.toChars(TOKassert));
            else
                error("identifier or integer expected, not %s", token.toChars());
            nextToken();
            check(TOKrparen);
        }
        else
            error("(condition) expected following version");
        c = new VersionCondition(mod, level, id);
        return c;
    }

    /***********************************************
     *      static if (expression)
     *          body
     *      else
     *          body
     * Current token is 'static'.
     */
    Condition parseStaticIfCondition()
    {
        Expression exp;
        Condition condition;
        Loc loc = token.loc;
        nextToken();
        nextToken();
        if (token.value == TOKlparen)
        {
            nextToken();
            exp = parseAssignExp();
            check(TOKrparen);
        }
        else
        {
            error("(expression) expected following static if");
            exp = null;
        }
        condition = new StaticIfCondition(loc, exp);
        return condition;
    }

    /*****************************************
     * Parse a constructor definition:
     *      this(parameters) { body }
     * or postblit:
     *      this(this) { body }
     * or constructor template:
     *      this(templateparameters)(parameters) { body }
     * Current token is 'this'.
     */
    Dsymbol parseCtor(PrefixAttributes* pAttrs)
    {
        Expressions* udas = null;
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        if (token.value == TOKlparen && peekNext() == TOKthis && peekNext2() == TOKrparen)
        {
            // this(this) { ... }
            nextToken();
            nextToken();
            check(TOKrparen);
            stc = parsePostfix(stc, &udas);
            if (stc & STCstatic)
                error(loc, "postblit cannot be static");
            auto f = new PostBlitDeclaration(loc, Loc(), stc, Id.postblit);
            if (pAttrs)
                pAttrs.storageClass = STCundefined;
            Dsymbol s = parseContracts(f);
            if (udas)
            {
                auto a = new Dsymbols();
                a.push(f);
                s = new UserAttributeDeclaration(udas, a);
            }
            return s;
        }
        /* Look ahead to see if:
         *   this(...)(...)
         * which is a constructor template
         */
        TemplateParameters* tpl = null;
        if (token.value == TOKlparen && peekPastParen(&token).value == TOKlparen)
        {
            tpl = parseTemplateParameterList();
        }
        /* Just a regular constructor
         */
        int varargs;
        Parameters* parameters = parseParameters(&varargs);
        stc = parsePostfix(stc, &udas);
        if (varargs != 0 || Parameter.dim(parameters) != 0)
        {
            if (stc & STCstatic)
                error(loc, "constructor cannot be static");
        }
        else if (StorageClass ss = stc & (STCshared | STCstatic)) // this()
        {
            if (ss == STCstatic)
                error(loc, "use 'static this()' to declare a static constructor");
            else if (ss == (STCshared | STCstatic))
                error(loc, "use 'shared static this()' to declare a shared static constructor");
        }
        Expression constraint = tpl ? parseConstraint() : null;
        Type tf = new TypeFunction(parameters, null, varargs, linkage, stc); // RetrunType -> auto
        tf = tf.addSTC(stc);
        auto f = new CtorDeclaration(loc, Loc(), stc, tf);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        Dsymbol s = parseContracts(f);
        if (udas)
        {
            auto a = new Dsymbols();
            a.push(f);
            s = new UserAttributeDeclaration(udas, a);
        }
        if (tpl)
        {
            // Wrap a template around it
            auto decldefs = new Dsymbols();
            decldefs.push(s);
            s = new TemplateDeclaration(loc, f.ident, tpl, constraint, decldefs);
        }
        return s;
    }

    /*****************************************
     * Parse a destructor definition:
     *      ~this() { body }
     * Current token is '~'.
     */
    Dsymbol parseDtor(PrefixAttributes* pAttrs)
    {
        Expressions* udas = null;
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        check(TOKthis);
        check(TOKlparen);
        check(TOKrparen);
        stc = parsePostfix(stc, &udas);
        if (StorageClass ss = stc & (STCshared | STCstatic))
        {
            if (ss == STCstatic)
                error(loc, "use 'static ~this()' to declare a static destructor");
            else if (ss == (STCshared | STCstatic))
                error(loc, "use 'shared static ~this()' to declare a shared static destructor");
        }
        auto f = new DtorDeclaration(loc, Loc(), stc, Id.dtor);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        Dsymbol s = parseContracts(f);
        if (udas)
        {
            auto a = new Dsymbols();
            a.push(f);
            s = new UserAttributeDeclaration(udas, a);
        }
        return s;
    }

    /*****************************************
     * Parse a static constructor definition:
     *      static this() { body }
     * Current token is 'static'.
     */
    Dsymbol parseStaticCtor(PrefixAttributes* pAttrs)
    {
        //Expressions *udas = NULL;
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        nextToken();
        check(TOKlparen);
        check(TOKrparen);
        stc = parsePostfix(stc & ~STC_TYPECTOR, null) | stc;
        if (stc & STCshared)
            error(loc, "use 'shared static this()' to declare a shared static constructor");
        else if (stc & STCstatic)
            appendStorageClass(stc, STCstatic); // complaint for the redundancy
        else if (StorageClass modStc = stc & STC_TYPECTOR)
        {
            OutBuffer buf;
            stcToBuffer(&buf, modStc);
            error(loc, "static constructor cannot be %s", buf.peekString());
        }
        stc &= ~(STCstatic | STC_TYPECTOR);
        auto f = new StaticCtorDeclaration(loc, Loc(), stc);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        Dsymbol s = parseContracts(f);
        return s;
    }

    /*****************************************
     * Parse a static destructor definition:
     *      static ~this() { body }
     * Current token is 'static'.
     */
    Dsymbol parseStaticDtor(PrefixAttributes* pAttrs)
    {
        Expressions* udas = null;
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        nextToken();
        check(TOKthis);
        check(TOKlparen);
        check(TOKrparen);
        stc = parsePostfix(stc & ~STC_TYPECTOR, &udas) | stc;
        if (stc & STCshared)
            error(loc, "use 'shared static ~this()' to declare a shared static destructor");
        else if (stc & STCstatic)
            appendStorageClass(stc, STCstatic); // complaint for the redundancy
        else if (StorageClass modStc = stc & STC_TYPECTOR)
        {
            OutBuffer buf;
            stcToBuffer(&buf, modStc);
            error(loc, "static destructor cannot be %s", buf.peekString());
        }
        stc &= ~(STCstatic | STC_TYPECTOR);
        auto f = new StaticDtorDeclaration(loc, Loc(), stc);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        Dsymbol s = parseContracts(f);
        if (udas)
        {
            auto a = new Dsymbols();
            a.push(f);
            s = new UserAttributeDeclaration(udas, a);
        }
        return s;
    }

    /*****************************************
     * Parse a shared static constructor definition:
     *      shared static this() { body }
     * Current token is 'shared'.
     */
    Dsymbol parseSharedStaticCtor(PrefixAttributes* pAttrs)
    {
        //Expressions *udas = NULL;
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        nextToken();
        nextToken();
        check(TOKlparen);
        check(TOKrparen);
        stc = parsePostfix(stc & ~STC_TYPECTOR, null) | stc;
        if (StorageClass ss = stc & (STCshared | STCstatic))
            appendStorageClass(stc, ss); // complaint for the redundancy
        else if (StorageClass modStc = stc & STC_TYPECTOR)
        {
            OutBuffer buf;
            stcToBuffer(&buf, modStc);
            error(loc, "shared static constructor cannot be %s", buf.peekString());
        }
        stc &= ~(STCstatic | STC_TYPECTOR);
        auto f = new SharedStaticCtorDeclaration(loc, Loc(), stc);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        Dsymbol s = parseContracts(f);
        return s;
    }

    /*****************************************
     * Parse a shared static destructor definition:
     *      shared static ~this() { body }
     * Current token is 'shared'.
     */
    Dsymbol parseSharedStaticDtor(PrefixAttributes* pAttrs)
    {
        Expressions* udas = null;
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        nextToken();
        nextToken();
        check(TOKthis);
        check(TOKlparen);
        check(TOKrparen);
        stc = parsePostfix(stc & ~STC_TYPECTOR, &udas) | stc;
        if (StorageClass ss = stc & (STCshared | STCstatic))
            appendStorageClass(stc, ss); // complaint for the redundancy
        else if (StorageClass modStc = stc & STC_TYPECTOR)
        {
            OutBuffer buf;
            stcToBuffer(&buf, modStc);
            error(loc, "shared static destructor cannot be %s", buf.peekString());
        }
        stc &= ~(STCstatic | STC_TYPECTOR);
        auto f = new SharedStaticDtorDeclaration(loc, Loc(), stc);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        Dsymbol s = parseContracts(f);
        if (udas)
        {
            auto a = new Dsymbols();
            a.push(f);
            s = new UserAttributeDeclaration(udas, a);
        }
        return s;
    }

    /*****************************************
     * Parse an invariant definition:
     *      invariant() { body }
     * Current token is 'invariant'.
     */
    Dsymbol parseInvariant(PrefixAttributes* pAttrs)
    {
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        if (token.value == TOKlparen) // optional ()
        {
            nextToken();
            check(TOKrparen);
        }
        auto f = new InvariantDeclaration(loc, Loc(), stc);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        f.fbody = parseStatement(PScurly);
        return f;
    }

    /*****************************************
     * Parse a unittest definition:
     *      unittest { body }
     * Current token is 'unittest'.
     */
    Dsymbol parseUnitTest(PrefixAttributes* pAttrs)
    {
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        const(char)* begPtr = token.ptr + 1; // skip '{'
        const(char)* endPtr = null;
        Statement sbody = parseStatement(PScurly, &endPtr);
        /** Extract unittest body as a string. Must be done eagerly since memory
         will be released by the lexer before doc gen. */
        char* docline = null;
        if (global.params.doDocComments && endPtr > begPtr)
        {
            /* Remove trailing whitespaces */
            for (const(char)* p = endPtr - 1; begPtr <= p && (*p == ' ' || *p == '\r' || *p == '\n' || *p == '\t'); --p)
            {
                endPtr = p;
            }
            size_t len = endPtr - begPtr;
            if (len > 0)
            {
                docline = cast(char*)mem.xmalloc(len + 2);
                memcpy(docline, begPtr, len);
                docline[len] = '\n'; // Terminate all lines by LF
                docline[len + 1] = '\0';
            }
        }
        auto f = new UnitTestDeclaration(loc, token.loc, stc, docline);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        f.fbody = sbody;
        return f;
    }

    /*****************************************
     * Parse a new definition:
     *      new(parameters) { body }
     * Current token is 'new'.
     */
    Dsymbol parseNew(PrefixAttributes* pAttrs)
    {
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        int varargs;
        Parameters* parameters = parseParameters(&varargs);
        auto f = new NewDeclaration(loc, Loc(), stc, parameters, varargs);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        Dsymbol s = parseContracts(f);
        return s;
    }

    /*****************************************
     * Parse a delete definition:
     *      delete(parameters) { body }
     * Current token is 'delete'.
     */
    Dsymbol parseDelete(PrefixAttributes* pAttrs)
    {
        Loc loc = token.loc;
        StorageClass stc = pAttrs ? pAttrs.storageClass : STCundefined;
        nextToken();
        int varargs;
        Parameters* parameters = parseParameters(&varargs);
        if (varargs)
            error("... not allowed in delete function parameter list");
        auto f = new DeleteDeclaration(loc, Loc(), stc, parameters);
        if (pAttrs)
            pAttrs.storageClass = STCundefined;
        Dsymbol s = parseContracts(f);
        return s;
    }

    /**********************************************
     * Parse parameter list.
     */
    Parameters* parseParameters(int* pvarargs, TemplateParameters** tpl = null)
    {
        auto parameters = new Parameters();
        int varargs = 0;
        int hasdefault = 0;
        check(TOKlparen);
        while (1)
        {
            Identifier ai = null;
            Type at;
            StorageClass storageClass = 0;
            StorageClass stc;
            Expression ae;
            for (; 1; nextToken())
            {
                switch (token.value)
                {
                case TOKrparen:
                    break;
                case TOKdotdotdot:
                    varargs = 1;
                    nextToken();
                    break;
                case TOKconst:
                    if (peek(&token).value == TOKlparen)
                        goto Ldefault;
                    stc = STCconst;
                    goto L2;
                case TOKimmutable:
                    if (peek(&token).value == TOKlparen)
                        goto Ldefault;
                    stc = STCimmutable;
                    goto L2;
                case TOKshared:
                    if (peek(&token).value == TOKlparen)
                        goto Ldefault;
                    stc = STCshared;
                    goto L2;
                case TOKwild:
                    if (peek(&token).value == TOKlparen)
                        goto Ldefault;
                    stc = STCwild;
                    goto L2;
                case TOKin:
                    stc = STCin;
                    goto L2;
                case TOKout:
                    stc = STCout;
                    goto L2;
                case TOKref:
                    stc = STCref;
                    goto L2;
                case TOKlazy:
                    stc = STClazy;
                    goto L2;
                case TOKscope:
                    stc = STCscope;
                    goto L2;
                case TOKfinal:
                    stc = STCfinal;
                    goto L2;
                case TOKauto:
                    stc = STCauto;
                    goto L2;
                case TOKreturn:
                    stc = STCreturn;
                    goto L2;
                L2:
                    storageClass = appendStorageClass(storageClass, stc);
                    continue;
                    version (none)
                    {
                    case TOKstatic:
                        stc = STCstatic;
                        goto L2;
                    case TOKauto:
                        storageClass = STCauto;
                        goto L4;
                    case TOKalias:
                        storageClass = STCalias;
                        goto L4;
                    L4:
                        nextToken();
                        if (token.value == TOKidentifier)
                        {
                            ai = token.ident;
                            nextToken();
                        }
                        else
                            ai = null;
                        at = null; // no type
                        ae = null; // no default argument
                        if (token.value == TOKassign) // = defaultArg
                        {
                            nextToken();
                            ae = parseDefaultInitExp();
                            hasdefault = 1;
                        }
                        else
                        {
                            if (hasdefault)
                                error("default argument expected for alias %s", ai ? ai.toChars() : "");
                        }
                        goto L3;
                    }
                default:
                Ldefault:
                    {
                        stc = storageClass & (STCin | STCout | STCref | STClazy);
                        // if stc is not a power of 2
                        if (stc & (stc - 1) && !(stc == (STCin | STCref)))
                            error("incompatible parameter storage classes");
                        if ((storageClass & STCscope) && (storageClass & (STCref | STCout)))
                            error("scope cannot be ref or out");
                        Token* t;
                        if (tpl && token.value == TOKidentifier && (t = peek(&token), (t.value == TOKcomma || t.value == TOKrparen || t.value == TOKdotdotdot)))
                        {
                            Identifier id = Identifier.generateId("__T");
                            Loc loc = token.loc;
                            at = new TypeIdentifier(loc, id);
                            if (!*tpl)
                                *tpl = new TemplateParameters();
                            TemplateParameter tp = new TemplateTypeParameter(loc, id, null, null);
                            (*tpl).push(tp);
                            ai = token.ident;
                            nextToken();
                        }
                        else
                            at = parseType(&ai);
                        ae = null;
                        if (token.value == TOKassign) // = defaultArg
                        {
                            nextToken();
                            ae = parseDefaultInitExp();
                            hasdefault = 1;
                        }
                        else
                        {
                            if (hasdefault)
                                error("default argument expected for %s", ai ? ai.toChars() : at.toChars());
                        }
                        if (token.value == TOKdotdotdot)
                        {
                            /* This is:
                             *      at ai ...
                             */
                            if (storageClass & (STCout | STCref))
                                error("variadic argument cannot be out or ref");
                            varargs = 2;
                            parameters.push(new Parameter(storageClass, at, ai, ae));
                            nextToken();
                            break;
                        }
                        parameters.push(new Parameter(storageClass, at, ai, ae));
                        if (token.value == TOKcomma)
                        {
                            nextToken();
                            goto L1;
                        }
                        break;
                    }
                }
                break;
            }
            break;
        L1:
        }
        check(TOKrparen);
        *pvarargs = varargs;
        return parameters;
    }

    /*************************************
     */
    EnumDeclaration parseEnum()
    {
        EnumDeclaration e;
        Identifier id;
        Type memtype;
        Loc loc = token.loc;
        //printf("Parser::parseEnum()\n");
        nextToken();
        if (token.value == TOKidentifier)
        {
            id = token.ident;
            nextToken();
        }
        else
            id = null;
        if (token.value == TOKcolon)
        {
            nextToken();
            int alt = 0;
            Loc typeLoc = token.loc;
            memtype = parseBasicType();
            memtype = parseDeclarator(memtype, &alt, null);
            checkCstyleTypeSyntax(typeLoc, memtype, alt, null);
        }
        else
            memtype = null;
        e = new EnumDeclaration(loc, id, memtype);
        if (token.value == TOKsemicolon && id)
            nextToken();
        else if (token.value == TOKlcurly)
        {
            //printf("enum definition\n");
            e.members = new Dsymbols();
            nextToken();
            const(char)* comment = token.blockComment;
            while (token.value != TOKrcurly)
            {
                /* Can take the following forms:
                 *  1. ident
                 *  2. ident = value
                 *  3. type ident = value
                 */
                loc = token.loc;
                Type type = null;
                Identifier ident = null;
                Token* tp = peek(&token);
                if (token.value == TOKidentifier && (tp.value == TOKassign || tp.value == TOKcomma || tp.value == TOKrcurly))
                {
                    ident = token.ident;
                    type = null;
                    nextToken();
                }
                else
                {
                    type = parseType(&ident, null);
                    if (!ident)
                        error("no identifier for declarator %s", type.toChars());
                    if (id || memtype)
                        error("type only allowed if anonymous enum and no enum type");
                }
                Expression value;
                if (token.value == TOKassign)
                {
                    nextToken();
                    value = parseAssignExp();
                }
                else
                {
                    value = null;
                    if (type)
                        error("if type, there must be an initializer");
                }
                auto em = new EnumMember(loc, ident, value, type);
                e.members.push(em);
                if (token.value == TOKrcurly)
                {
                }
                else
                {
                    addComment(em, comment);
                    comment = null;
                    check(TOKcomma);
                }
                addComment(em, comment);
                comment = token.blockComment;
                if (token.value == TOKeof)
                {
                    error("premature end of file");
                    break;
                }
            }
            nextToken();
        }
        else
            error("enum declaration is invalid");
        //printf("-parseEnum() %s\n", e->toChars());
        return e;
    }

    /********************************
     * Parse struct, union, interface, class.
     */
    Dsymbol parseAggregate()
    {
        AggregateDeclaration a = null;
        int anon = 0;
        Identifier id;
        TemplateParameters* tpl = null;
        Expression constraint = null;
        Loc loc = token.loc;
        TOK tok = token.value;
        //printf("Parser::parseAggregate()\n");
        nextToken();
        if (token.value != TOKidentifier)
        {
            id = null;
        }
        else
        {
            id = token.ident;
            nextToken();
            if (token.value == TOKlparen)
            {
                // Class template declaration.
                // Gather template parameter list
                tpl = parseTemplateParameterList();
                constraint = parseConstraint();
            }
        }
        switch (tok)
        {
        case TOKclass:
        case TOKinterface:
            {
                if (!id)
                    error("anonymous classes not allowed");
                // Collect base class(es)
                BaseClasses* baseclasses = null;
                if (token.value == TOKcolon)
                {
                    nextToken();
                    baseclasses = parseBaseClasses();
                    if (tpl)
                    {
                        Expression tempCons = parseConstraint();
                        if (tempCons)
                        {
                            if (constraint)
                                error("members expected");
                            else
                                constraint = tempCons;
                        }
                    }
                    if (token.value != TOKlcurly)
                        error("members expected");
                }
                if (tok == TOKclass)
                {
                    bool inObject = md && !md.packages && md.id == Id.object;
                    a = new ClassDeclaration(loc, id, baseclasses, inObject);
                }
                else
                    a = new InterfaceDeclaration(loc, id, baseclasses);
                break;
            }
        case TOKstruct:
            if (id)
                a = new StructDeclaration(loc, id);
            else
                anon = 1;
            break;
        case TOKunion:
            if (id)
                a = new UnionDeclaration(loc, id);
            else
                anon = 2;
            break;
        default:
            assert(0);
        }
        if (a && token.value == TOKsemicolon)
        {
            nextToken();
        }
        else if (token.value == TOKlcurly)
        {
            //printf("aggregate definition\n");
            nextToken();
            Dsymbols* decl = parseDeclDefs(0);
            if (token.value != TOKrcurly)
                error("} expected following members in %s declaration at %s", Token.toChars(tok), loc.toChars());
            nextToken();
            if (anon)
            {
                /* Anonymous structs/unions are more like attributes.
                 */
                return new AnonDeclaration(loc, anon == 2, decl);
            }
            else
                a.members = decl;
        }
        else
        {
            error("{ } expected following %s declaration", Token.toChars(tok));
            a = new StructDeclaration(loc, null);
        }
        if (tpl)
        {
            // Wrap a template around the aggregate declaration
            auto decldefs = new Dsymbols();
            decldefs.push(a);
            auto tempdecl = new TemplateDeclaration(loc, id, tpl, constraint, decldefs);
            return tempdecl;
        }
        return a;
    }

    /*******************************************
     */
    BaseClasses* parseBaseClasses()
    {
        auto baseclasses = new BaseClasses();
        for (; 1; nextToken())
        {
            bool prot = false;
            Prot protection = Prot(PROTpublic);
            switch (token.value)
            {
            case TOKprivate:
                prot = true;
                protection = Prot(PROTprivate);
                nextToken();
                break;
            case TOKpackage:
                prot = true;
                protection = Prot(PROTpackage);
                nextToken();
                break;
            case TOKprotected:
                prot = true;
                protection = Prot(PROTprotected);
                nextToken();
                break;
            case TOKpublic:
                prot = true;
                protection = Prot(PROTpublic);
                nextToken();
                break;
            default:
                break;
            }
            if (prot)
                error("use of base class protection is no longer supported");
            auto b = new BaseClass(parseBasicType(), protection);
            baseclasses.push(b);
            if (token.value != TOKcomma)
                break;
        }
        return baseclasses;
    }

    Dsymbols* parseImport()
    {
        auto decldefs = new Dsymbols();
        Identifier aliasid = null;
        int isstatic = token.value == TOKstatic;
        if (isstatic)
            nextToken();
        //printf("Parser::parseImport()\n");
        do
        {
        L1:
            nextToken();
            if (token.value != TOKidentifier)
            {
                error("identifier expected following import");
                break;
            }
            Loc loc = token.loc;
            Identifier id = token.ident;
            Identifiers* a = null;
            nextToken();
            if (!aliasid && token.value == TOKassign)
            {
                aliasid = id;
                goto L1;
            }
            while (token.value == TOKdot)
            {
                if (!a)
                    a = new Identifiers();
                a.push(id);
                nextToken();
                if (token.value != TOKidentifier)
                {
                    error("identifier expected following package");
                    break;
                }
                id = token.ident;
                nextToken();
            }
            auto s = new Import(loc, a, id, aliasid, isstatic);
            decldefs.push(s);
            /* Look for
             *      : alias=name, alias=name;
             * syntax.
             */
            if (token.value == TOKcolon)
            {
                do
                {
                    nextToken();
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected following :");
                        break;
                    }
                    Identifier _alias = token.ident;
                    Identifier name;
                    nextToken();
                    if (token.value == TOKassign)
                    {
                        nextToken();
                        if (token.value != TOKidentifier)
                        {
                            error("identifier expected following %s=", _alias.toChars());
                            break;
                        }
                        name = token.ident;
                        nextToken();
                    }
                    else
                    {
                        name = _alias;
                        _alias = null;
                    }
                    s.addAlias(name, _alias);
                }
                while (token.value == TOKcomma);
                break;
                // no comma-separated imports of this form
            }
            aliasid = null;
        }
        while (token.value == TOKcomma);
        if (token.value == TOKsemicolon)
            nextToken();
        else
        {
            error("';' expected");
            nextToken();
        }
        return decldefs;
    }

    Type parseType(Identifier* pident = null, TemplateParameters** ptpl = null)
    {
        /* Take care of the storage class prefixes that
         * serve as type attributes:
         *               const type
         *           immutable type
         *              shared type
         *               inout type
         *         inout const type
         *        shared const type
         *        shared inout type
         *  shared inout const type
         */
        StorageClass stc = 0;
        while (1)
        {
            switch (token.value)
            {
            case TOKconst:
                if (peekNext() == TOKlparen)
                    break;
                // const as type constructor
                stc |= STCconst; // const as storage class
                nextToken();
                continue;
            case TOKimmutable:
                if (peekNext() == TOKlparen)
                    break;
                stc |= STCimmutable;
                nextToken();
                continue;
            case TOKshared:
                if (peekNext() == TOKlparen)
                    break;
                stc |= STCshared;
                nextToken();
                continue;
            case TOKwild:
                if (peekNext() == TOKlparen)
                    break;
                stc |= STCwild;
                nextToken();
                continue;
            default:
                break;
            }
            break;
        }
        Loc typeLoc = token.loc;
        Type t;
        t = parseBasicType();
        int alt = 0;
        t = parseDeclarator(t, &alt, pident, ptpl);
        checkCstyleTypeSyntax(typeLoc, t, alt, pident ? *pident : null);
        t = t.addSTC(stc);
        return t;
    }

    Type parseBasicType(bool dontLookDotIdents = false)
    {
        Type t;
        Loc loc;
        Identifier id;
        //printf("parseBasicType()\n");
        switch (token.value)
        {
        case TOKvoid:
            t = Type.tvoid;
            goto LabelX;
        case TOKint8:
            t = Type.tint8;
            goto LabelX;
        case TOKuns8:
            t = Type.tuns8;
            goto LabelX;
        case TOKint16:
            t = Type.tint16;
            goto LabelX;
        case TOKuns16:
            t = Type.tuns16;
            goto LabelX;
        case TOKint32:
            t = Type.tint32;
            goto LabelX;
        case TOKuns32:
            t = Type.tuns32;
            goto LabelX;
        case TOKint64:
            t = Type.tint64;
            goto LabelX;
        case TOKuns64:
            t = Type.tuns64;
            goto LabelX;
        case TOKint128:
            t = Type.tint128;
            goto LabelX;
        case TOKuns128:
            t = Type.tuns128;
            goto LabelX;
        case TOKfloat32:
            t = Type.tfloat32;
            goto LabelX;
        case TOKfloat64:
            t = Type.tfloat64;
            goto LabelX;
        case TOKfloat80:
            t = Type.tfloat80;
            goto LabelX;
        case TOKimaginary32:
            t = Type.timaginary32;
            goto LabelX;
        case TOKimaginary64:
            t = Type.timaginary64;
            goto LabelX;
        case TOKimaginary80:
            t = Type.timaginary80;
            goto LabelX;
        case TOKcomplex32:
            t = Type.tcomplex32;
            goto LabelX;
        case TOKcomplex64:
            t = Type.tcomplex64;
            goto LabelX;
        case TOKcomplex80:
            t = Type.tcomplex80;
            goto LabelX;
        case TOKbool:
            t = Type.tbool;
            goto LabelX;
        case TOKchar:
            t = Type.tchar;
            goto LabelX;
        case TOKwchar:
            t = Type.twchar;
            goto LabelX;
        case TOKdchar:
            t = Type.tdchar;
            goto LabelX;
        LabelX:
            nextToken();
            break;
        case TOKthis:
        case TOKsuper:
        case TOKidentifier:
            loc = token.loc;
            id = token.ident;
            nextToken();
            if (token.value == TOKnot)
            {
                // ident!(template_arguments)
                auto tempinst = new TemplateInstance(loc, id);
                tempinst.tiargs = parseTemplateArguments();
                t = parseBasicTypeStartingAt(new TypeInstance(loc, tempinst), dontLookDotIdents);
            }
            else
            {
                t = parseBasicTypeStartingAt(new TypeIdentifier(loc, id), dontLookDotIdents);
            }
            break;
        case TOKdot:
            // Leading . as in .foo
            t = parseBasicTypeStartingAt(new TypeIdentifier(token.loc, Id.empty), dontLookDotIdents);
            break;
        case TOKtypeof:
            // typeof(expression)
            t = parseBasicTypeStartingAt(parseTypeof(), dontLookDotIdents);
            break;
        case TOKvector:
            t = parseVector();
            break;
        case TOKconst:
            // const(type)
            nextToken();
            check(TOKlparen);
            t = parseType().addSTC(STCconst);
            check(TOKrparen);
            break;
        case TOKimmutable:
            // immutable(type)
            nextToken();
            check(TOKlparen);
            t = parseType().addSTC(STCimmutable);
            check(TOKrparen);
            break;
        case TOKshared:
            // shared(type)
            nextToken();
            check(TOKlparen);
            t = parseType().addSTC(STCshared);
            check(TOKrparen);
            break;
        case TOKwild:
            // wild(type)
            nextToken();
            check(TOKlparen);
            t = parseType().addSTC(STCwild);
            check(TOKrparen);
            break;
        default:
            error("basic type expected, not %s", token.toChars());
            t = Type.tint32;
            break;
        }
        return t;
    }

    Type parseBasicTypeStartingAt(TypeQualified tid, bool dontLookDotIdents)
    {
        Type maybeArray = null;
        // See https://issues.dlang.org/show_bug.cgi?id=1215
        // A basic type can look like MyType (typical case), but also:
        //  MyType.T -> A type
        //  MyType[expr] -> Either a static array of MyType or a type (iif MyType is a Ttuple)
        //  MyType[expr].T -> A type.
        //  MyType[expr].T[expr] ->  Either a static array of MyType[expr].T or a type
        //                           (iif MyType[expr].T is a Ttuple)
        while (1)
        {
            switch (token.value)
            {
            case TOKdot:
                {
                    nextToken();
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected following '.' instead of '%s'", token.toChars());
                        break;
                    }
                    if (maybeArray)
                    {
                        // This is actually a TypeTuple index, not an {a/s}array.
                        // We need to have a while loop to unwind all index taking:
                        // T[e1][e2].U   ->  T, addIndex(e1), addIndex(e2)
                        Objects dimStack;
                        Type t = maybeArray;
                        while (true)
                        {
                            if (t.ty == Tsarray)
                            {
                                // The index expression is an Expression.
                                TypeSArray a = cast(TypeSArray)t;
                                dimStack.push(a.dim.syntaxCopy());
                                t = a.next.syntaxCopy();
                            }
                            else if (t.ty == Taarray)
                            {
                                // The index expression is a Type. It will be interpreted as an expression at semantic time.
                                TypeAArray a = cast(TypeAArray)t;
                                dimStack.push(a.index.syntaxCopy());
                                t = a.next.syntaxCopy();
                            }
                            else
                            {
                                break;
                            }
                        }
                        assert(dimStack.dim > 0);
                        // We're good. Replay indices in the reverse order.
                        tid = cast(TypeQualified)t;
                        while (dimStack.dim)
                        {
                            tid.addIndex(dimStack.pop());
                        }
                        maybeArray = null;
                    }
                    Loc loc = token.loc;
                    Identifier id = token.ident;
                    nextToken();
                    if (token.value == TOKnot)
                    {
                        auto tempinst = new TemplateInstance(loc, id);
                        tempinst.tiargs = parseTemplateArguments();
                        tid.addInst(tempinst);
                    }
                    else
                        tid.addIdent(id);
                    continue;
                }
            case TOKlbracket:
                {
                    if (dontLookDotIdents) // workaround for Bugzilla 14911
                        goto Lend;
                    nextToken();
                    Type t = maybeArray ? maybeArray : cast(Type)tid;
                    if (token.value == TOKrbracket)
                    {
                        // It's a dynamic array, and we're done:
                        // T[].U does not make sense.
                        t = new TypeDArray(t);
                        nextToken();
                        return t;
                    }
                    else if (isDeclaration(&token, 0, TOKrbracket, null))
                    {
                        // This can be one of two things:
                        //  1 - an associative array declaration, T[type]
                        //  2 - an associative array declaration, T[expr]
                        // These  can only be disambiguated later.
                        Type index = parseType(); // [ type ]
                        maybeArray = new TypeAArray(t, index);
                        check(TOKrbracket);
                    }
                    else
                    {
                        // This can be one of three things:
                        //  1 - an static array declaration, T[expr]
                        //  2 - a slice, T[expr .. expr]
                        //  3 - a template parameter pack index expression, T[expr].U
                        // 1 and 3 can only be disambiguated later.
                        //printf("it's type[expression]\n");
                        inBrackets++;
                        Expression e = parseAssignExp(); // [ expression ]
                        if (token.value == TOKslice)
                        {
                            // It's a slice, and we're done.
                            nextToken();
                            Expression e2 = parseAssignExp(); // [ exp .. exp ]
                            t = new TypeSlice(t, e, e2);
                            inBrackets--;
                            check(TOKrbracket);
                            return t;
                        }
                        else
                        {
                            maybeArray = new TypeSArray(t, e);
                            inBrackets--;
                            check(TOKrbracket);
                            continue;
                        }
                    }
                    break;
                }
            default:
                goto Lend;
            }
        }
    Lend:
        return maybeArray ? maybeArray : cast(Type)tid;
    }

    /******************************************
     * Parse things that follow the initial type t.
     *      t *
     *      t []
     *      t [type]
     *      t [expression]
     *      t [expression .. expression]
     *      t function
     *      t delegate
     */
    Type parseBasicType2(Type t)
    {
        //printf("parseBasicType2()\n");
        while (1)
        {
            switch (token.value)
            {
            case TOKmul:
                t = new TypePointer(t);
                nextToken();
                continue;
            case TOKlbracket:
                // Handle []. Make sure things like
                //     int[3][1] a;
                // is (array[1] of array[3] of int)
                nextToken();
                if (token.value == TOKrbracket)
                {
                    t = new TypeDArray(t); // []
                    nextToken();
                }
                else if (isDeclaration(&token, 0, TOKrbracket, null))
                {
                    // It's an associative array declaration
                    //printf("it's an associative array\n");
                    Type index = parseType(); // [ type ]
                    t = new TypeAArray(t, index);
                    check(TOKrbracket);
                }
                else
                {
                    //printf("it's type[expression]\n");
                    inBrackets++;
                    Expression e = parseAssignExp(); // [ expression ]
                    if (token.value == TOKslice)
                    {
                        nextToken();
                        Expression e2 = parseAssignExp(); // [ exp .. exp ]
                        t = new TypeSlice(t, e, e2);
                    }
                    else
                    {
                        t = new TypeSArray(t, e);
                    }
                    inBrackets--;
                    check(TOKrbracket);
                }
                continue;
            case TOKdelegate:
            case TOKfunction:
                {
                    // Handle delegate declaration:
                    //      t delegate(parameter list) nothrow pure
                    //      t function(parameter list) nothrow pure
                    TOK save = token.value;
                    nextToken();
                    int varargs;
                    Parameters* parameters = parseParameters(&varargs);
                    StorageClass stc = parsePostfix(STCundefined, null);
                    auto tf = new TypeFunction(parameters, t, varargs, linkage, stc);
                    if (stc & (STCconst | STCimmutable | STCshared | STCwild | STCreturn))
                    {
                        if (save == TOKfunction)
                            error("const/immutable/shared/inout/return attributes are only valid for non-static member functions");
                        else
                            tf = cast(TypeFunction)tf.addSTC(stc);
                    }
                    if (save == TOKdelegate)
                        t = new TypeDelegate(tf);
                    else
                        t = new TypePointer(tf); // pointer to function
                    continue;
                }
            default:
                return t;
            }
            assert(0);
        }
        assert(0);
    }

    Type parseDeclarator(Type t, int* palt, Identifier* pident, TemplateParameters** tpl = null, StorageClass storageClass = 0, int* pdisable = null, Expressions** pudas = null)
    {
        //printf("parseDeclarator(tpl = %p)\n", tpl);
        t = parseBasicType2(t);
        Type ts;
        switch (token.value)
        {
        case TOKidentifier:
            if (pident)
                *pident = token.ident;
            else
                error("unexpected identifer '%s' in declarator", token.ident.toChars());
            ts = t;
            nextToken();
            break;
        case TOKlparen:
            {
                // like: T (*fp)();
                // like: T ((*fp))();
                if (peekNext() == TOKmul || peekNext() == TOKlparen)
                {
                    /* Parse things with parentheses around the identifier, like:
                     *  int (*ident[3])[]
                     * although the D style would be:
                     *  int[]*[3] ident
                     */
                    *palt |= 1;
                    nextToken();
                    ts = parseDeclarator(t, palt, pident);
                    check(TOKrparen);
                    break;
                }
                ts = t;
                Token* peekt = &token;
                /* Completely disallow C-style things like:
                 *   T (a);
                 * Improve error messages for the common bug of a missing return type
                 * by looking to see if (a) looks like a parameter list.
                 */
                if (isParameters(&peekt))
                {
                    error("function declaration without return type. (Note that constructors are always named 'this')");
                }
                else
                    error("unexpected ( in declarator");
                break;
            }
        default:
            ts = t;
            break;
        }
        // parse DeclaratorSuffixes
        while (1)
        {
            switch (token.value)
            {
                static if (CARRAYDECL)
                {
                    /* Support C style array syntax:
                     *   int ident[]
                     * as opposed to D-style:
                     *   int[] ident
                     */
                case TOKlbracket:
                    {
                        // This is the old C-style post [] syntax.
                        TypeNext ta;
                        nextToken();
                        if (token.value == TOKrbracket)
                        {
                            // It's a dynamic array
                            ta = new TypeDArray(t); // []
                            nextToken();
                            *palt |= 2;
                        }
                        else if (isDeclaration(&token, 0, TOKrbracket, null))
                        {
                            // It's an associative array
                            //printf("it's an associative array\n");
                            Type index = parseType(); // [ type ]
                            check(TOKrbracket);
                            ta = new TypeAArray(t, index);
                            *palt |= 2;
                        }
                        else
                        {
                            //printf("It's a static array\n");
                            Expression e = parseAssignExp(); // [ expression ]
                            ta = new TypeSArray(t, e);
                            check(TOKrbracket);
                            *palt |= 2;
                        }
                        /* Insert ta into
                         *   ts -> ... -> t
                         * so that
                         *   ts -> ... -> ta -> t
                         */
                        Type* pt;
                        for (pt = &ts; *pt != t; pt = &(cast(TypeNext)*pt).next)
                        {
                        }
                        *pt = ta;
                        continue;
                    }
                }
            case TOKlparen:
                {
                    if (tpl)
                    {
                        Token* tk = peekPastParen(&token);
                        if (tk.value == TOKlparen)
                        {
                            /* Look ahead to see if this is (...)(...),
                             * i.e. a function template declaration
                             */
                            //printf("function template declaration\n");
                            // Gather template parameter list
                            *tpl = parseTemplateParameterList();
                        }
                        else if (tk.value == TOKassign)
                        {
                            /* or (...) =,
                             * i.e. a variable template declaration
                             */
                            //printf("variable template declaration\n");
                            *tpl = parseTemplateParameterList();
                            break;
                        }
                    }
                    int varargs;
                    Parameters* parameters = parseParameters(&varargs);
                    /* Parse const/immutable/shared/inout/nothrow/pure/return postfix
                     */
                    StorageClass stc = parsePostfix(storageClass, pudas);
                    // merge prefix storage classes
                    Type tf = new TypeFunction(parameters, t, varargs, linkage, stc);
                    tf = tf.addSTC(stc);
                    if (pdisable)
                        *pdisable = stc & STCdisable ? 1 : 0;
                    /* Insert tf into
                     *   ts -> ... -> t
                     * so that
                     *   ts -> ... -> tf -> t
                     */
                    Type* pt;
                    for (pt = &ts; *pt != t; pt = &(cast(TypeNext)*pt).next)
                    {
                    }
                    *pt = tf;
                    break;
                }
            default:
                break;
            }
            break;
        }
        return ts;
    }

    void parseStorageClasses(ref StorageClass storage_class, ref LINK link, ref uint structalign, ref Expressions* udas)
    {
        StorageClass stc;
        bool sawLinkage = false; // seen a linkage declaration
        while (1)
        {
            switch (token.value)
            {
            case TOKconst:
                if (peek(&token).value == TOKlparen)
                    break;
                // const as type constructor
                stc = STCconst; // const as storage class
                goto L1;
            case TOKimmutable:
                if (peek(&token).value == TOKlparen)
                    break;
                stc = STCimmutable;
                goto L1;
            case TOKshared:
                if (peek(&token).value == TOKlparen)
                    break;
                stc = STCshared;
                goto L1;
            case TOKwild:
                if (peek(&token).value == TOKlparen)
                    break;
                stc = STCwild;
                goto L1;
            case TOKstatic:
                stc = STCstatic;
                goto L1;
            case TOKfinal:
                stc = STCfinal;
                goto L1;
            case TOKauto:
                stc = STCauto;
                goto L1;
            case TOKscope:
                stc = STCscope;
                goto L1;
            case TOKoverride:
                stc = STCoverride;
                goto L1;
            case TOKabstract:
                stc = STCabstract;
                goto L1;
            case TOKsynchronized:
                stc = STCsynchronized;
                goto L1;
            case TOKdeprecated:
                stc = STCdeprecated;
                goto L1;
            case TOKnothrow:
                stc = STCnothrow;
                goto L1;
            case TOKpure:
                stc = STCpure;
                goto L1;
            case TOKref:
                stc = STCref;
                goto L1;
            case TOKgshared:
                stc = STCgshared;
                goto L1;
            case TOKenum:
                stc = STCmanifest;
                goto L1;
            case TOKat:
                {
                    stc = parseAttribute(&udas);
                    if (stc)
                        goto L1;
                    continue;
                }
            L1:
                storage_class = appendStorageClass(storage_class, stc);
                nextToken();
                continue;
            case TOKextern:
                {
                    if (peek(&token).value != TOKlparen)
                    {
                        stc = STCextern;
                        goto L1;
                    }
                    if (sawLinkage)
                        error("redundant linkage declaration");
                    sawLinkage = true;
                    Identifiers* idents = null;
                    link = parseLinkage(&idents);
                    if (idents)
                    {
                        error("C++ name spaces not allowed here");
                    }
                    continue;
                }
            case TOKalign:
                {
                    nextToken();
                    if (token.value == TOKlparen)
                    {
                        nextToken();
                        if (token.value == TOKint32v && token.uns64value > 0)
                            structalign = cast(uint)token.uns64value;
                        else
                        {
                            error("positive integer expected, not %s", token.toChars());
                            structalign = 1;
                        }
                        nextToken();
                        check(TOKrparen);
                    }
                    else
                        structalign = STRUCTALIGN_DEFAULT; // default
                    continue;
                }
            default:
                break;
            }
            break;
        }
    }

    /**********************************
     * Parse Declarations.
     * These can be:
     *      1. declarations at global/class level
     *      2. declarations at statement level
     * Return array of Declaration *'s.
     */
    Dsymbols* parseDeclarations(bool autodecl, PrefixAttributes* pAttrs, const(char)* comment)
    {
        StorageClass storage_class = STCundefined;
        Type ts;
        Type t;
        Type tfirst;
        Identifier ident;
        TOK tok = TOKreserved;
        LINK link = linkage;
        uint structalign = 0;
        Loc loc = token.loc;
        Expressions* udas = null;
        Token* tk;
        //printf("parseDeclarations() %s\n", token.toChars());
        if (!comment)
            comment = token.blockComment;
        if (autodecl)
        {
            ts = null; // infer type
            goto L2;
        }
        if (token.value == TOKalias)
        {
            tok = token.value;
            nextToken();
            /* Look for:
             *   alias identifier this;
             */
            if (token.value == TOKidentifier && peekNext() == TOKthis)
            {
                auto s = new AliasThis(loc, token.ident);
                nextToken();
                check(TOKthis);
                check(TOKsemicolon);
                auto a = new Dsymbols();
                a.push(s);
                addComment(s, comment);
                return a;
            }
            version (none)
            {
                /* Look for:
                 *  alias this = identifier;
                 */
                if (token.value == TOKthis && peekNext() == TOKassign && peekNext2() == TOKidentifier)
                {
                    check(TOKthis);
                    check(TOKassign);
                    auto s = new AliasThis(loc, token.ident);
                    nextToken();
                    check(TOKsemicolon);
                    auto a = new Dsymbols();
                    a.push(s);
                    addComment(s, comment);
                    return a;
                }
            }
            /* Look for:
             *  alias identifier = type;
             *  alias identifier(...) = type;
             */
            if (token.value == TOKidentifier && skipParensIf(peek(&token), &tk) && tk.value == TOKassign)
            {
                auto a = new Dsymbols();
                while (1)
                {
                    ident = token.ident;
                    nextToken();
                    TemplateParameters* tpl = null;
                    if (token.value == TOKlparen)
                        tpl = parseTemplateParameterList();
                    check(TOKassign);
                    storage_class = STCundefined;
                    link = linkage;
                    structalign = 0;
                    udas = null;
                    parseStorageClasses(storage_class, link, structalign, udas);
                    if (udas)
                        error("user defined attributes not allowed for %s declarations", Token.toChars(tok));
                    t = parseType();
                    Declaration v = new AliasDeclaration(loc, ident, t);
                    v.storage_class = storage_class;
                    Dsymbol s = v;
                    if (tpl)
                    {
                        auto a2 = new Dsymbols();
                        a2.push(s);
                        auto tempdecl = new TemplateDeclaration(loc, ident, tpl, null, a2);
                        s = tempdecl;
                    }
                    if (link != linkage)
                    {
                        auto a2 = new Dsymbols();
                        a2.push(s);
                        s = new LinkDeclaration(link, a2);
                    }
                    a.push(s);
                    switch (token.value)
                    {
                    case TOKsemicolon:
                        nextToken();
                        addComment(s, comment);
                        break;
                    case TOKcomma:
                        nextToken();
                        addComment(s, comment);
                        if (token.value != TOKidentifier)
                        {
                            error("identifier expected following comma, not %s", token.toChars());
                            break;
                        }
                        if (peekNext() != TOKassign && peekNext() != TOKlparen)
                        {
                            error("= expected following identifier");
                            nextToken();
                            break;
                        }
                        continue;
                    default:
                        error("semicolon expected to close %s declaration", Token.toChars(tok));
                        break;
                    }
                    break;
                }
                return a;
            }
            // alias StorageClasses type ident;
        }
        else if (token.value == TOKtypedef)
        {
            error("use alias instead of typedef");
            tok = token.value;
            nextToken();
        }
        parseStorageClasses(storage_class, link, structalign, udas);
        if (token.value == TOKstruct || token.value == TOKunion || token.value == TOKclass || token.value == TOKinterface)
        {
            Dsymbol s = parseAggregate();
            auto a = new Dsymbols();
            a.push(s);
            if (storage_class)
            {
                s = new StorageClassDeclaration(storage_class, a);
                a = new Dsymbols();
                a.push(s);
            }
            if (structalign != 0)
            {
                s = new AlignDeclaration(structalign, a);
                a = new Dsymbols();
                a.push(s);
            }
            if (link != linkage)
            {
                s = new LinkDeclaration(link, a);
                a = new Dsymbols();
                a.push(s);
            }
            if (udas)
            {
                s = new UserAttributeDeclaration(udas, a);
                a = new Dsymbols();
                a.push(s);
            }
            addComment(s, comment);
            return a;
        }
        /* Look for auto initializers:
         *  storage_class identifier = initializer;
         *  storage_class identifier(...) = initializer;
         */
        if ((storage_class || udas) && token.value == TOKidentifier && skipParensIf(peek(&token), &tk) && tk.value == TOKassign)
        {
            Dsymbols* a = parseAutoDeclarations(storage_class, comment);
            if (udas)
            {
                Dsymbol s = new UserAttributeDeclaration(udas, a);
                a = new Dsymbols();
                a.push(s);
            }
            return a;
        }
        /* Look for return type inference for template functions.
         */
        if ((storage_class || udas) && token.value == TOKidentifier && skipParens(peek(&token), &tk) && skipAttributes(tk, &tk) && (tk.value == TOKlparen || tk.value == TOKlcurly || tk.value == TOKin || tk.value == TOKout || tk.value == TOKbody))
        {
            ts = null;
        }
        else
        {
            ts = parseBasicType();
            ts = parseBasicType2(ts);
        }
    L2:
        tfirst = null;
        auto a = new Dsymbols();
        if (pAttrs)
        {
            storage_class |= pAttrs.storageClass;
            //pAttrs->storageClass = STCundefined;
        }
        while (1)
        {
            TemplateParameters* tpl = null;
            int disable;
            int alt = 0;
            loc = token.loc;
            ident = null;
            t = parseDeclarator(ts, &alt, &ident, &tpl, storage_class, &disable, &udas);
            assert(t);
            if (!tfirst)
                tfirst = t;
            else if (t != tfirst)
                error("multiple declarations must have the same type, not %s and %s", tfirst.toChars(), t.toChars());
            bool isThis = (t.ty == Tident && (cast(TypeIdentifier)t).ident == Id.This && token.value == TOKassign);
            if (ident)
                checkCstyleTypeSyntax(loc, t, alt, ident);
            else if (!isThis)
                error("no identifier for declarator %s", t.toChars());
            if (tok == TOKtypedef || tok == TOKalias)
            {
                Declaration v;
                Initializer _init = null;
                /* Aliases can no longer have multiple declarators, storage classes,
                 * linkages, or auto declarations.
                 * These never made any sense, anyway.
                 * The code below needs to be fixed to reject them.
                 * The grammar has already been fixed to preclude them.
                 */
                if (udas)
                    error("user defined attributes not allowed for %s declarations", Token.toChars(tok));
                if (token.value == TOKassign)
                {
                    nextToken();
                    _init = parseInitializer();
                }
                if (tok == TOKtypedef)
                {
                    v = new AliasDeclaration(loc, ident, t); // dummy
                }
                else
                {
                    if (_init)
                    {
                        if (isThis)
                            error("cannot use syntax 'alias this = %s', use 'alias %s this' instead", _init.toChars(), _init.toChars());
                        else
                            error("alias cannot have initializer");
                    }
                    v = new AliasDeclaration(loc, ident, t);
                }
                v.storage_class = storage_class;
                if (pAttrs)
                {
                    /* AliasDeclaration distinguish @safe, @system, @trusted atttributes
                     * on prefix and postfix.
                     *   @safe alias void function() FP1;
                     *   alias @safe void function() FP2;    // FP2 is not @safe
                     *   alias void function() @safe FP3;
                     */
                    pAttrs.storageClass &= (STCsafe | STCsystem | STCtrusted);
                }
                Dsymbol s = v;
                if (link != linkage)
                {
                    auto ax = new Dsymbols();
                    ax.push(v);
                    s = new LinkDeclaration(link, ax);
                }
                a.push(s);
                switch (token.value)
                {
                case TOKsemicolon:
                    nextToken();
                    addComment(s, comment);
                    break;
                case TOKcomma:
                    nextToken();
                    addComment(s, comment);
                    continue;
                default:
                    error("semicolon expected to close %s declaration", Token.toChars(tok));
                    break;
                }
            }
            else if (t.ty == Tfunction)
            {
                Expression constraint = null;
                version (none)
                {
                    TypeFunction tf = cast(TypeFunction)t;
                    if (Parameter.isTPL(tf.parameters))
                    {
                        if (!tpl)
                            tpl = new TemplateParameters();
                    }
                }
                //printf("%s funcdecl t = %s, storage_class = x%lx\n", loc.toChars(), t->toChars(), storage_class);
                auto f = new FuncDeclaration(loc, Loc(), ident, storage_class | (disable ? STCdisable : 0), t);
                if (pAttrs)
                    pAttrs.storageClass = STCundefined;
                if (tpl)
                    constraint = parseConstraint();
                Dsymbol s = parseContracts(f);
                /* A template parameter list means it's a function template
                 */
                if (tpl)
                {
                    // Wrap a template around the function declaration
                    auto decldefs = new Dsymbols();
                    decldefs.push(s);
                    auto tempdecl = new TemplateDeclaration(loc, s.ident, tpl, constraint, decldefs);
                    s = tempdecl;
                    if (storage_class & STCstatic)
                    {
                        assert(f.storage_class & STCstatic);
                        f.storage_class &= ~STCstatic;
                        auto ax = new Dsymbols();
                        ax.push(s);
                        s = new StorageClassDeclaration(STCstatic, ax);
                    }
                }
                if (link != linkage)
                {
                    auto ax = new Dsymbols();
                    ax.push(s);
                    s = new LinkDeclaration(link, ax);
                }
                if (udas)
                {
                    auto ax = new Dsymbols();
                    ax.push(s);
                    s = new UserAttributeDeclaration(udas, ax);
                }
                a.push(s);
                addComment(s, comment);
            }
            else if (ident)
            {
                Initializer _init = null;
                if (token.value == TOKassign)
                {
                    nextToken();
                    _init = parseInitializer();
                }
                auto v = new VarDeclaration(loc, t, ident, _init);
                v.storage_class = storage_class;
                if (pAttrs)
                    pAttrs.storageClass = STCundefined;
                Dsymbol s = v;
                if (tpl && _init)
                {
                    auto a2 = new Dsymbols();
                    a2.push(s);
                    auto tempdecl = new TemplateDeclaration(loc, ident, tpl, null, a2, 0);
                    s = tempdecl;
                }
                if (link != linkage)
                {
                    auto ax = new Dsymbols();
                    ax.push(s);
                    s = new LinkDeclaration(link, ax);
                }
                if (udas)
                {
                    auto ax = new Dsymbols();
                    ax.push(s);
                    s = new UserAttributeDeclaration(udas, ax);
                }
                a.push(s);
                switch (token.value)
                {
                case TOKsemicolon:
                    nextToken();
                    addComment(s, comment);
                    break;
                case TOKcomma:
                    nextToken();
                    addComment(s, comment);
                    continue;
                default:
                    error("semicolon expected, not '%s'", token.toChars());
                    break;
                }
            }
            break;
        }
        return a;
    }

    Dsymbol parseFunctionLiteral()
    {
        Loc loc = token.loc;
        TemplateParameters* tpl = null;
        Parameters* parameters = null;
        int varargs = 0;
        Type tret = null;
        StorageClass stc = 0;
        TOK save = TOKreserved;
        switch (token.value)
        {
        case TOKfunction:
        case TOKdelegate:
            save = token.value;
            nextToken();
            if (token.value != TOKlparen && token.value != TOKlcurly)
            {
                // function type (parameters) { statements... }
                // delegate type (parameters) { statements... }
                tret = parseBasicType();
                tret = parseBasicType2(tret); // function return type
            }
            if (token.value == TOKlparen)
            {
                // function (parameters) { statements... }
                // delegate (parameters) { statements... }
            }
            else
            {
                // function { statements... }
                // delegate { statements... }
                break;
            }
            /* fall through to TOKlparen */
        case TOKlparen:
            {
                // (parameters) => expression
                // (parameters) { statements... }
                parameters = parseParameters(&varargs, &tpl);
                stc = parsePostfix(STCundefined, null);
                if (StorageClass modStc = stc & STC_TYPECTOR)
                {
                    if (save == TOKfunction)
                    {
                        OutBuffer buf;
                        stcToBuffer(&buf, modStc);
                        error("function literal cannot be %s", buf.peekString());
                    }
                    else
                        save = TOKdelegate;
                }
                break;
            }
        case TOKlcurly:
            // { statements... }
            break;
        case TOKidentifier:
            {
                // identifier => expression
                parameters = new Parameters();
                Identifier id = Identifier.generateId("__T");
                Type t = new TypeIdentifier(loc, id);
                parameters.push(new Parameter(0, t, token.ident, null));
                tpl = new TemplateParameters();
                TemplateParameter tp = new TemplateTypeParameter(loc, id, null, null);
                tpl.push(tp);
                nextToken();
                break;
            }
        default:
            assert(0);
        }
        if (!parameters)
            parameters = new Parameters();
        auto tf = new TypeFunction(parameters, tret, varargs, linkage, stc);
        tf = cast(TypeFunction)tf.addSTC(stc);
        auto fd = new FuncLiteralDeclaration(loc, Loc(), tf, save, null);
        if (token.value == TOKgoesto)
        {
            check(TOKgoesto);
            Loc returnloc = token.loc;
            Expression ae = parseAssignExp();
            fd.fbody = new ReturnStatement(returnloc, ae);
            fd.endloc = token.loc;
        }
        else
        {
            parseContracts(fd);
        }
        if (tpl)
        {
            // Wrap a template around function fd
            auto decldefs = new Dsymbols();
            decldefs.push(fd);
            return new TemplateDeclaration(fd.loc, fd.ident, tpl, null, decldefs, false, true);
        }
        else
            return fd;
    }

    /*****************************************
     * Parse contracts following function declaration.
     */
    FuncDeclaration parseContracts(FuncDeclaration f)
    {
        LINK linksave = linkage;
        bool literal = f.isFuncLiteralDeclaration() !is null;
        // The following is irrelevant, as it is overridden by sc->linkage in
        // TypeFunction::semantic
        linkage = LINKd; // nested functions have D linkage
    L1:
        switch (token.value)
        {
        case TOKlcurly:
            if (f.frequire || f.fensure)
                error("missing body { ... } after in or out");
            f.fbody = parseStatement(PSsemi);
            f.endloc = endloc;
            break;
        case TOKbody:
            nextToken();
            f.fbody = parseStatement(PScurly);
            f.endloc = endloc;
            break;
            version (none)
            {
                // Do we want this for function declarations, so we can do:
                // int x, y, foo(), z;
            case TOKcomma:
                nextToken();
                continue;
            }
            version (none)
            {
                // Dumped feature
            case TOKthrow:
                if (!f.fthrows)
                    f.fthrows = new Types();
                nextToken();
                check(TOKlparen);
                while (1)
                {
                    Type tb = parseBasicType();
                    f.fthrows.push(tb);
                    if (token.value == TOKcomma)
                    {
                        nextToken();
                        continue;
                    }
                    break;
                }
                check(TOKrparen);
                goto L1;
            }
        case TOKin:
            nextToken();
            if (f.frequire)
                error("redundant 'in' statement");
            f.frequire = parseStatement(PScurly | PSscope);
            goto L1;
        case TOKout:
            // parse: out (identifier) { statement }
            nextToken();
            if (token.value != TOKlcurly)
            {
                check(TOKlparen);
                if (token.value != TOKidentifier)
                    error("(identifier) following 'out' expected, not %s", token.toChars());
                f.outId = token.ident;
                nextToken();
                check(TOKrparen);
            }
            if (f.fensure)
                error("redundant 'out' statement");
            f.fensure = parseStatement(PScurly | PSscope);
            goto L1;
        case TOKsemicolon:
            if (!literal)
            {
                if (f.frequire || f.fensure)
                    error("missing body { ... } after in or out");
                nextToken();
                break;
            }
            /* fall through */
        default:
            if (literal)
            {
                const(char)* sbody = (f.frequire || f.fensure) ? "body " : "";
                error("missing %s{ ... } for function literal", sbody);
            }
            else if (!f.frequire && !f.fensure) // allow these even with no body
            {
                error("semicolon expected following function declaration");
            }
            break;
        }
        if (literal && !f.fbody)
        {
            // Set empty function body for error recovery
            f.fbody = new CompoundStatement(Loc(), cast(Statement)null);
        }
        linkage = linksave;
        return f;
    }

    /*****************************************
     */
    void checkDanglingElse(Loc elseloc)
    {
        if (token.value != TOKelse && token.value != TOKcatch && token.value != TOKfinally && lookingForElse.linnum != 0)
        {
            warning(elseloc, "else is dangling, add { } after condition at %s", lookingForElse.toChars());
        }
    }

    void checkCstyleTypeSyntax(Loc loc, Type t, int alt, Identifier ident)
    {
        if (!alt)
            return;
        const(char)* sp = !ident ? "" : " ";
        const(char)* s = !ident ? "" : ident.toChars();
        if (alt & 1) // contains C-style function pointer syntax
            error(loc, "instead of C-style syntax, use D-style '%s%s%s'", t.toChars(), sp, s);
        else
            .warning(loc, "instead of C-style syntax, use D-style syntax '%s%s%s'", t.toChars(), sp, s);
    }

    /*****************************************
     * Input:
     *      flags   PSxxxx
     * Output:
     *      pEndloc if { ... statements ... }, store location of closing brace
     */
    Statement parseStatement(int flags, const(char)** endPtr = null, Loc* pEndloc = null)
    {
        Statement s;
        Condition cond;
        Statement ifbody;
        Statement elsebody;
        bool isfinal;
        Loc loc = token.loc;
        //printf("parseStatement()\n");
        if (flags & PScurly && token.value != TOKlcurly)
            error("statement expected to be { }, not %s", token.toChars());
        switch (token.value)
        {
        case TOKidentifier:
            {
                /* A leading identifier can be a declaration, label, or expression.
                 * The easiest case to check first is label:
                 */
                Token* t = peek(&token);
                if (t.value == TOKcolon)
                {
                    Token* nt = peek(t);
                    if (nt.value == TOKcolon)
                    {
                        // skip ident::
                        nextToken();
                        nextToken();
                        nextToken();
                        error("use '.' for member lookup, not '::'");
                        break;
                    }
                    // It's a label
                    Identifier ident = token.ident;
                    nextToken();
                    nextToken();
                    if (token.value == TOKrcurly)
                        s = null;
                    else if (token.value == TOKlcurly)
                        s = parseStatement(PScurly | PSscope);
                    else
                        s = parseStatement(PSsemi_ok);
                    s = new LabelStatement(loc, ident, s);
                    break;
                }
                // fallthrough to TOKdot
            }
        case TOKdot:
        case TOKtypeof:
        case TOKvector:
            /* Bugzilla 15163: If tokens can be handled as
             * old C-style declaration or D expression, prefer the latter.
             */
            if (isDeclaration(&token, 3, TOKreserved, null))
                goto Ldeclaration;
            else
                goto Lexp;
        case TOKassert:
        case TOKthis:
        case TOKsuper:
        case TOKint32v:
        case TOKuns32v:
        case TOKint64v:
        case TOKuns64v:
        case TOKint128v:
        case TOKuns128v:
        case TOKfloat32v:
        case TOKfloat64v:
        case TOKfloat80v:
        case TOKimaginary32v:
        case TOKimaginary64v:
        case TOKimaginary80v:
        case TOKcharv:
        case TOKwcharv:
        case TOKdcharv:
        case TOKnull:
        case TOKtrue:
        case TOKfalse:
        case TOKstring:
        case TOKxstring:
        case TOKlparen:
        case TOKcast:
        case TOKmul:
        case TOKmin:
        case TOKadd:
        case TOKtilde:
        case TOKnot:
        case TOKplusplus:
        case TOKminusminus:
        case TOKnew:
        case TOKdelete:
        case TOKdelegate:
        case TOKfunction:
        case TOKtypeid:
        case TOKis:
        case TOKlbracket:
        case TOKtraits:
        case TOKfile:
        case TOKline:
        case TOKmodulestring:
        case TOKfuncstring:
        case TOKprettyfunc:
        Lexp:
            {
                Expression exp = parseExpression();
                check(TOKsemicolon, "statement");
                s = new ExpStatement(loc, exp);
                break;
            }
        case TOKstatic:
            {
                // Look ahead to see if it's static assert() or static if()
                Token* t = peek(&token);
                if (t.value == TOKassert)
                {
                    s = new StaticAssertStatement(parseStaticAssert());
                    break;
                }
                if (t.value == TOKif)
                {
                    cond = parseStaticIfCondition();
                    goto Lcondition;
                }
                if (t.value == TOKimport)
                {
                    Dsymbols* imports = parseImport();
                    s = new ImportStatement(loc, imports);
                    if (flags & PSscope)
                        s = new ScopeStatement(loc, s);
                    break;
                }
                goto Ldeclaration;
            }
        case TOKfinal:
            if (peekNext() == TOKswitch)
            {
                nextToken();
                isfinal = true;
                goto Lswitch;
            }
            goto Ldeclaration;
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
            // bug 7773: int.max is always a part of expression
            if (peekNext() == TOKdot)
                goto Lexp;
            if (peekNext() == TOKlparen)
                goto Lexp;
        case TOKtypedef:
        case TOKalias:
        case TOKconst:
        case TOKauto:
        case TOKabstract:
        case TOKextern:
        case TOKalign:
        case TOKimmutable:
        case TOKshared:
        case TOKwild:
        case TOKdeprecated:
        case TOKnothrow:
        case TOKpure:
        case TOKref:
        case TOKgshared:
        case TOKat:
        case TOKstruct:
        case TOKunion:
        case TOKclass:
        case TOKinterface:
        Ldeclaration:
            {
                Dsymbols* a = parseDeclarations(false, null, null);
                if (a.dim > 1)
                {
                    auto as = new Statements();
                    as.reserve(a.dim);
                    foreach (i; 0 .. a.dim)
                    {
                        Dsymbol d = (*a)[i];
                        s = new ExpStatement(loc, d);
                        as.push(s);
                    }
                    s = new CompoundDeclarationStatement(loc, as);
                }
                else if (a.dim == 1)
                {
                    Dsymbol d = (*a)[0];
                    s = new ExpStatement(loc, d);
                }
                else
                    s = new ExpStatement(loc, cast(Expression)null);
                if (flags & PSscope)
                    s = new ScopeStatement(loc, s);
                break;
            }
        case TOKenum:
            {
                /* Determine if this is a manifest constant declaration,
                 * or a conventional enum.
                 */
                Dsymbol d;
                Token* t = peek(&token);
                if (t.value == TOKlcurly || t.value == TOKcolon)
                    d = parseEnum();
                else if (t.value != TOKidentifier)
                    goto Ldeclaration;
                else
                {
                    t = peek(t);
                    if (t.value == TOKlcurly || t.value == TOKcolon || t.value == TOKsemicolon)
                        d = parseEnum();
                    else
                        goto Ldeclaration;
                }
                s = new ExpStatement(loc, d);
                if (flags & PSscope)
                    s = new ScopeStatement(loc, s);
                break;
            }
        case TOKmixin:
            {
                Token* t = peek(&token);
                if (t.value == TOKlparen)
                {
                    // mixin(string)
                    Expression e = parseAssignExp();
                    check(TOKsemicolon);
                    if (e.op == TOKmixin)
                    {
                        CompileExp cpe = cast(CompileExp)e;
                        s = new CompileStatement(loc, cpe.e1);
                    }
                    else
                    {
                        s = new ExpStatement(loc, e);
                    }
                    break;
                }
                Dsymbol d = parseMixin();
                s = new ExpStatement(loc, d);
                if (flags & PSscope)
                    s = new ScopeStatement(loc, s);
                break;
            }
        case TOKlcurly:
            {
                Loc lookingForElseSave = lookingForElse;
                lookingForElse = Loc();
                nextToken();
                //if (token.value == TOKsemicolon)
                //error("use '{ }' for an empty statement, not a ';'");
                auto statements = new Statements();
                while (token.value != TOKrcurly && token.value != TOKeof)
                {
                    statements.push(parseStatement(PSsemi | PScurlyscope));
                }
                if (endPtr)
                    *endPtr = token.ptr;
                endloc = token.loc;
                if (pEndloc)
                    *pEndloc = token.loc;
                s = new CompoundStatement(loc, statements);
                if (flags & (PSscope | PScurlyscope))
                    s = new ScopeStatement(loc, s);
                check(TOKrcurly, "compound statement");
                lookingForElse = lookingForElseSave;
                break;
            }
        case TOKwhile:
            {
                nextToken();
                check(TOKlparen);
                Expression condition = parseExpression();
                check(TOKrparen);
                Loc endloc;
                Statement _body = parseStatement(PSscope, null, &endloc);
                s = new WhileStatement(loc, condition, _body, endloc);
                break;
            }
        case TOKsemicolon:
            if (!(flags & PSsemi_ok))
            {
                if (flags & PSsemi)
                    warning(loc, "use '{ }' for an empty statement, not a ';'");
                else
                    error("use '{ }' for an empty statement, not a ';'");
            }
            nextToken();
            s = new ExpStatement(loc, cast(Expression)null);
            break;
        case TOKdo:
            {
                Statement _body;
                Expression condition;
                nextToken();
                Loc lookingForElseSave = lookingForElse;
                lookingForElse = Loc();
                _body = parseStatement(PSscope);
                lookingForElse = lookingForElseSave;
                check(TOKwhile);
                check(TOKlparen);
                condition = parseExpression();
                check(TOKrparen);
                if (token.value == TOKsemicolon)
                    nextToken();
                else
                    error("terminating ';' required after do-while statement");
                s = new DoStatement(loc, _body, condition);
                break;
            }
        case TOKfor:
            {
                Statement _init;
                Expression condition;
                Expression increment;
                nextToken();
                check(TOKlparen);
                if (token.value == TOKsemicolon)
                {
                    _init = null;
                    nextToken();
                }
                else
                {
                    Loc lookingForElseSave = lookingForElse;
                    lookingForElse = Loc();
                    _init = parseStatement(0);
                    lookingForElse = lookingForElseSave;
                }
                if (token.value == TOKsemicolon)
                {
                    condition = null;
                    nextToken();
                }
                else
                {
                    condition = parseExpression();
                    check(TOKsemicolon, "for condition");
                }
                if (token.value == TOKrparen)
                {
                    increment = null;
                    nextToken();
                }
                else
                {
                    increment = parseExpression();
                    check(TOKrparen);
                }
                Loc endloc;
                Statement _body = parseStatement(PSscope, null, &endloc);
                s = new ForStatement(loc, _init, condition, increment, _body, endloc);
                break;
            }
        case TOKforeach:
        case TOKforeach_reverse:
            {
                TOK op = token.value;
                nextToken();
                check(TOKlparen);
                auto parameters = new Parameters();
                while (1)
                {
                    Identifier ai = null;
                    Type at;
                    StorageClass storageClass = 0;
                    StorageClass stc = 0;
                Lagain:
                    if (stc)
                    {
                        storageClass = appendStorageClass(storageClass, stc);
                        nextToken();
                    }
                    switch (token.value)
                    {
                    case TOKref:
                        stc = STCref;
                        goto Lagain;
                    case TOKconst:
                        if (peekNext() != TOKlparen)
                        {
                            stc = STCconst;
                            goto Lagain;
                        }
                        break;
                    case TOKimmutable:
                        if (peekNext() != TOKlparen)
                        {
                            stc = STCimmutable;
                            goto Lagain;
                        }
                        break;
                    case TOKshared:
                        if (peekNext() != TOKlparen)
                        {
                            stc = STCshared;
                            goto Lagain;
                        }
                        break;
                    case TOKwild:
                        if (peekNext() != TOKlparen)
                        {
                            stc = STCwild;
                            goto Lagain;
                        }
                        break;
                    default:
                        break;
                    }
                    if (token.value == TOKidentifier)
                    {
                        Token* t = peek(&token);
                        if (t.value == TOKcomma || t.value == TOKsemicolon)
                        {
                            ai = token.ident;
                            at = null; // infer argument type
                            nextToken();
                            goto Larg;
                        }
                    }
                    at = parseType(&ai);
                    if (!ai)
                        error("no identifier for declarator %s", at.toChars());
                Larg:
                    auto p = new Parameter(storageClass, at, ai, null);
                    parameters.push(p);
                    if (token.value == TOKcomma)
                    {
                        nextToken();
                        continue;
                    }
                    break;
                }
                check(TOKsemicolon);
                Expression aggr = parseExpression();
                if (token.value == TOKslice && parameters.dim == 1)
                {
                    Parameter p = (*parameters)[0];
                    nextToken();
                    Expression upr = parseExpression();
                    check(TOKrparen);
                    Loc endloc;
                    Statement _body = parseStatement(0, null, &endloc);
                    s = new ForeachRangeStatement(loc, op, p, aggr, upr, _body, endloc);
                }
                else
                {
                    check(TOKrparen);
                    Loc endloc;
                    Statement _body = parseStatement(0, null, &endloc);
                    s = new ForeachStatement(loc, op, parameters, aggr, _body, endloc);
                }
                break;
            }
        case TOKif:
            {
                Parameter param = null;
                Expression condition;
                nextToken();
                check(TOKlparen);
                StorageClass storageClass = 0;
                StorageClass stc = 0;
            LagainStc:
                if (stc)
                {
                    storageClass = appendStorageClass(storageClass, stc);
                    nextToken();
                }
                switch (token.value)
                {
                case TOKref:
                    stc = STCref;
                    goto LagainStc;
                case TOKauto:
                    stc = STCauto;
                    goto LagainStc;
                case TOKconst:
                    if (peekNext() != TOKlparen)
                    {
                        stc = STCconst;
                        goto LagainStc;
                    }
                    break;
                case TOKimmutable:
                    if (peekNext() != TOKlparen)
                    {
                        stc = STCimmutable;
                        goto LagainStc;
                    }
                    break;
                case TOKshared:
                    if (peekNext() != TOKlparen)
                    {
                        stc = STCshared;
                        goto LagainStc;
                    }
                    break;
                case TOKwild:
                    if (peekNext() != TOKlparen)
                    {
                        stc = STCwild;
                        goto LagainStc;
                    }
                    break;
                default:
                    break;
                }
                if (storageClass != 0 && token.value == TOKidentifier && peek(&token).value == TOKassign)
                {
                    Identifier ai = token.ident;
                    Type at = null; // infer parameter type
                    nextToken();
                    check(TOKassign);
                    param = new Parameter(storageClass, at, ai, null);
                }
                else if (isDeclaration(&token, 2, TOKassign, null))
                {
                    Identifier ai;
                    Type at = parseType(&ai);
                    check(TOKassign);
                    param = new Parameter(storageClass, at, ai, null);
                }
                condition = parseExpression();
                if (condition.op == TOKassign)
                    error("assignment cannot be used as a condition, perhaps == was meant?");
                check(TOKrparen);
                {
                    Loc lookingForElseSave = lookingForElse;
                    lookingForElse = loc;
                    ifbody = parseStatement(PSscope);
                    lookingForElse = lookingForElseSave;
                }
                if (token.value == TOKelse)
                {
                    Loc elseloc = token.loc;
                    nextToken();
                    elsebody = parseStatement(PSscope);
                    checkDanglingElse(elseloc);
                }
                else
                    elsebody = null;
                if (condition && ifbody)
                    s = new IfStatement(loc, param, condition, ifbody, elsebody);
                else
                    s = null; // don't propagate parsing errors
                break;
            }
        case TOKscope:
            if (peek(&token).value != TOKlparen)
                goto Ldeclaration;
            // scope used as storage class
            nextToken();
            check(TOKlparen);
            if (token.value != TOKidentifier)
            {
                error("scope identifier expected");
                goto Lerror;
            }
            else
            {
                TOK t = TOKon_scope_exit;
                Identifier id = token.ident;
                if (id == Id.exit)
                    t = TOKon_scope_exit;
                else if (id == Id.failure)
                    t = TOKon_scope_failure;
                else if (id == Id.success)
                    t = TOKon_scope_success;
                else
                    error("valid scope identifiers are exit, failure, or success, not %s", id.toChars());
                nextToken();
                check(TOKrparen);
                Statement st = parseStatement(PScurlyscope);
                s = new OnScopeStatement(loc, t, st);
                break;
            }
        case TOKdebug:
            nextToken();
            if (token.value == TOKassign)
            {
                error("debug conditions can only be declared at module scope");
                nextToken();
                nextToken();
                goto Lerror;
            }
            cond = parseDebugCondition();
            goto Lcondition;
        case TOKversion:
            nextToken();
            if (token.value == TOKassign)
            {
                error("version conditions can only be declared at module scope");
                nextToken();
                nextToken();
                goto Lerror;
            }
            cond = parseVersionCondition();
            goto Lcondition;
        Lcondition:
            {
                Loc lookingForElseSave = lookingForElse;
                lookingForElse = loc;
                ifbody = parseStatement(0);
                lookingForElse = lookingForElseSave;
            }
            elsebody = null;
            if (token.value == TOKelse)
            {
                Loc elseloc = token.loc;
                nextToken();
                elsebody = parseStatement(0);
                checkDanglingElse(elseloc);
            }
            s = new ConditionalStatement(loc, cond, ifbody, elsebody);
            if (flags & PSscope)
                s = new ScopeStatement(loc, s);
            break;
        case TOKpragma:
            {
                Identifier ident;
                Expressions* args = null;
                Statement _body;
                nextToken();
                check(TOKlparen);
                if (token.value != TOKidentifier)
                {
                    error("pragma(identifier expected");
                    goto Lerror;
                }
                ident = token.ident;
                nextToken();
                if (token.value == TOKcomma && peekNext() != TOKrparen)
                    args = parseArguments(); // pragma(identifier, args...);
                else
                    check(TOKrparen); // pragma(identifier);
                if (token.value == TOKsemicolon)
                {
                    nextToken();
                    _body = null;
                }
                else
                    _body = parseStatement(PSsemi);
                s = new PragmaStatement(loc, ident, args, _body);
                break;
            }
        case TOKswitch:
            isfinal = false;
            goto Lswitch;
        Lswitch:
            {
                nextToken();
                check(TOKlparen);
                Expression condition = parseExpression();
                check(TOKrparen);
                Statement _body = parseStatement(PSscope);
                s = new SwitchStatement(loc, condition, _body, isfinal);
                break;
            }
        case TOKcase:
            {
                Expression exp;
                Expressions cases; // array of Expression's
                Expression last = null;
                while (1)
                {
                    nextToken();
                    exp = parseAssignExp();
                    cases.push(exp);
                    if (token.value != TOKcomma)
                        break;
                }
                check(TOKcolon);
                /* case exp: .. case last:
                 */
                if (token.value == TOKslice)
                {
                    if (cases.dim > 1)
                        error("only one case allowed for start of case range");
                    nextToken();
                    check(TOKcase);
                    last = parseAssignExp();
                    check(TOKcolon);
                }
                if (flags & PScurlyscope)
                {
                    auto statements = new Statements();
                    while (token.value != TOKcase && token.value != TOKdefault && token.value != TOKeof && token.value != TOKrcurly)
                    {
                        statements.push(parseStatement(PSsemi | PScurlyscope));
                    }
                    s = new CompoundStatement(loc, statements);
                }
                else
                    s = parseStatement(PSsemi | PScurlyscope);
                s = new ScopeStatement(loc, s);
                if (last)
                {
                    s = new CaseRangeStatement(loc, exp, last, s);
                }
                else
                {
                    // Keep cases in order by building the case statements backwards
                    for (size_t i = cases.dim; i; i--)
                    {
                        exp = cases[i - 1];
                        s = new CaseStatement(loc, exp, s);
                    }
                }
                break;
            }
        case TOKdefault:
            {
                nextToken();
                check(TOKcolon);
                if (flags & PScurlyscope)
                {
                    auto statements = new Statements();
                    while (token.value != TOKcase && token.value != TOKdefault && token.value != TOKeof && token.value != TOKrcurly)
                    {
                        statements.push(parseStatement(PSsemi | PScurlyscope));
                    }
                    s = new CompoundStatement(loc, statements);
                }
                else
                    s = parseStatement(PSsemi | PScurlyscope);
                s = new ScopeStatement(loc, s);
                s = new DefaultStatement(loc, s);
                break;
            }
        case TOKreturn:
            {
                Expression exp;
                nextToken();
                if (token.value == TOKsemicolon)
                    exp = null;
                else
                    exp = parseExpression();
                check(TOKsemicolon, "return statement");
                s = new ReturnStatement(loc, exp);
                break;
            }
        case TOKbreak:
            {
                Identifier ident;
                nextToken();
                if (token.value == TOKidentifier)
                {
                    ident = token.ident;
                    nextToken();
                }
                else
                    ident = null;
                check(TOKsemicolon, "break statement");
                s = new BreakStatement(loc, ident);
                break;
            }
        case TOKcontinue:
            {
                Identifier ident;
                nextToken();
                if (token.value == TOKidentifier)
                {
                    ident = token.ident;
                    nextToken();
                }
                else
                    ident = null;
                check(TOKsemicolon, "continue statement");
                s = new ContinueStatement(loc, ident);
                break;
            }
        case TOKgoto:
            {
                Identifier ident;
                nextToken();
                if (token.value == TOKdefault)
                {
                    nextToken();
                    s = new GotoDefaultStatement(loc);
                }
                else if (token.value == TOKcase)
                {
                    Expression exp = null;
                    nextToken();
                    if (token.value != TOKsemicolon)
                        exp = parseExpression();
                    s = new GotoCaseStatement(loc, exp);
                }
                else
                {
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected following goto");
                        ident = null;
                    }
                    else
                    {
                        ident = token.ident;
                        nextToken();
                    }
                    s = new GotoStatement(loc, ident);
                }
                check(TOKsemicolon, "goto statement");
                break;
            }
        case TOKsynchronized:
            {
                Expression exp;
                Statement _body;
                Token* t = peek(&token);
                if (skipAttributes(t, &t) && t.value == TOKclass)
                    goto Ldeclaration;
                nextToken();
                if (token.value == TOKlparen)
                {
                    nextToken();
                    exp = parseExpression();
                    check(TOKrparen);
                }
                else
                    exp = null;
                _body = parseStatement(PSscope);
                s = new SynchronizedStatement(loc, exp, _body);
                break;
            }
        case TOKwith:
            {
                Expression exp;
                Statement _body;
                nextToken();
                check(TOKlparen);
                exp = parseExpression();
                check(TOKrparen);
                _body = parseStatement(PSscope);
                s = new WithStatement(loc, exp, _body);
                break;
            }
        case TOKtry:
            {
                Statement _body;
                Catches* catches = null;
                Statement finalbody = null;
                nextToken();
                Loc lookingForElseSave = lookingForElse;
                lookingForElse = Loc();
                _body = parseStatement(PSscope);
                lookingForElse = lookingForElseSave;
                while (token.value == TOKcatch)
                {
                    Statement handler;
                    Catch c;
                    Type t;
                    Identifier id;
                    Loc catchloc = token.loc;
                    nextToken();
                    if (token.value == TOKlcurly || token.value != TOKlparen)
                    {
                        t = null;
                        id = null;
                    }
                    else
                    {
                        check(TOKlparen);
                        id = null;
                        t = parseType(&id);
                        check(TOKrparen);
                    }
                    handler = parseStatement(0);
                    c = new Catch(catchloc, t, id, handler);
                    if (!catches)
                        catches = new Catches();
                    catches.push(c);
                }
                if (token.value == TOKfinally)
                {
                    nextToken();
                    finalbody = parseStatement(0);
                }
                s = _body;
                if (!catches && !finalbody)
                    error("catch or finally expected following try");
                else
                {
                    if (catches)
                        s = new TryCatchStatement(loc, _body, catches);
                    if (finalbody)
                        s = new TryFinallyStatement(loc, s, finalbody);
                }
                break;
            }
        case TOKthrow:
            {
                Expression exp;
                nextToken();
                exp = parseExpression();
                check(TOKsemicolon, "throw statement");
                s = new ThrowStatement(loc, exp);
                break;
            }
        case TOKvolatile:
            nextToken();
            s = parseStatement(PSsemi | PScurlyscope);
            error("volatile statements no longer allowed; use synchronized statements instead");
            s = new SynchronizedStatement(loc, cast(Expression)null, s);
            break;
        case TOKasm:
            {
                // Parse the asm block into a sequence of AsmStatements,
                // each AsmStatement is one instruction.
                // Separate out labels.
                // Defer parsing of AsmStatements until semantic processing.
                Loc labelloc;
                nextToken();
                StorageClass stc = parsePostfix(STCundefined, null);
                if (stc & (STCconst | STCimmutable | STCshared | STCwild))
                    error("const/immutable/shared/inout attributes are not allowed on asm blocks");
                check(TOKlcurly);
                Token* toklist = null;
                Token** ptoklist = &toklist;
                Identifier label = null;
                auto statements = new Statements();
                size_t nestlevel = 0;
                while (1)
                {
                    switch (token.value)
                    {
                    case TOKidentifier:
                        if (!toklist)
                        {
                            // Look ahead to see if it is a label
                            Token* t = peek(&token);
                            if (t.value == TOKcolon)
                            {
                                // It's a label
                                label = token.ident;
                                labelloc = token.loc;
                                nextToken();
                                nextToken();
                                continue;
                            }
                        }
                        goto Ldefault;
                    case TOKlcurly:
                        ++nestlevel;
                        goto Ldefault;
                    case TOKrcurly:
                        if (nestlevel > 0)
                        {
                            --nestlevel;
                            goto Ldefault;
                        }
                        if (toklist || label)
                        {
                            error("asm statements must end in ';'");
                        }
                        break;
                    case TOKsemicolon:
                        if (nestlevel != 0)
                            error("mismatched number of curly brackets");
                        s = null;
                        if (toklist || label)
                        {
                            // Create AsmStatement from list of tokens we've saved
                            s = new AsmStatement(token.loc, toklist);
                            toklist = null;
                            ptoklist = &toklist;
                            if (label)
                            {
                                s = new LabelStatement(labelloc, label, s);
                                label = null;
                            }
                            statements.push(s);
                        }
                        nextToken();
                        continue;
                    case TOKeof:
                        /* { */
                        error("matching '}' expected, not end of file");
                        goto Lerror;
                    default:
                    Ldefault:
                        *ptoklist = Token.alloc();
                        memcpy(*ptoklist, &token, Token.sizeof);
                        ptoklist = &(*ptoklist).next;
                        *ptoklist = null;
                        nextToken();
                        continue;
                    }
                    break;
                }
                s = new CompoundAsmStatement(loc, statements, stc);
                nextToken();
                break;
            }
        case TOKimport:
            {
                Dsymbols* imports = parseImport();
                s = new ImportStatement(loc, imports);
                if (flags & PSscope)
                    s = new ScopeStatement(loc, s);
                break;
            }
        case TOKtemplate:
            {
                Dsymbol d = parseTemplateDeclaration();
                s = new ExpStatement(loc, d);
                break;
            }
        default:
            error("found '%s' instead of statement", token.toChars());
            goto Lerror;
        Lerror:
            while (token.value != TOKrcurly && token.value != TOKsemicolon && token.value != TOKeof)
                nextToken();
            if (token.value == TOKsemicolon)
                nextToken();
            s = null;
            break;
        }
        return s;
    }

    /*****************************************
     * Parse initializer for variable declaration.
     */
    Initializer parseInitializer()
    {
        StructInitializer _is;
        ArrayInitializer ia;
        ExpInitializer ie;
        Expression e;
        Identifier id;
        Initializer value;
        int comma;
        Loc loc = token.loc;
        Token* t;
        int braces;
        int brackets;
        switch (token.value)
        {
        case TOKlcurly:
            /* Scan ahead to see if it is a struct initializer or
             * a function literal.
             * If it contains a ';', it is a function literal.
             * Treat { } as a struct initializer.
             */
            braces = 1;
            for (t = peek(&token); 1; t = peek(t))
            {
                switch (t.value)
                {
                case TOKsemicolon:
                case TOKreturn:
                    goto Lexpression;
                case TOKlcurly:
                    braces++;
                    continue;
                case TOKrcurly:
                    if (--braces == 0)
                        break;
                    continue;
                case TOKeof:
                    break;
                default:
                    continue;
                }
                break;
            }
            _is = new StructInitializer(loc);
            nextToken();
            comma = 2;
            while (1)
            {
                switch (token.value)
                {
                case TOKidentifier:
                    if (comma == 1)
                        error("comma expected separating field initializers");
                    t = peek(&token);
                    if (t.value == TOKcolon)
                    {
                        id = token.ident;
                        nextToken();
                        nextToken(); // skip over ':'
                    }
                    else
                    {
                        id = null;
                    }
                    value = parseInitializer();
                    _is.addInit(id, value);
                    comma = 1;
                    continue;
                case TOKcomma:
                    if (comma == 2)
                        error("expression expected, not ','");
                    nextToken();
                    comma = 2;
                    continue;
                case TOKrcurly:
                    // allow trailing comma's
                    nextToken();
                    break;
                case TOKeof:
                    error("found EOF instead of initializer");
                    break;
                default:
                    if (comma == 1)
                        error("comma expected separating field initializers");
                    value = parseInitializer();
                    _is.addInit(null, value);
                    comma = 1;
                    continue;
                    //error("found '%s' instead of field initializer", token.toChars());
                    //break;
                }
                break;
            }
            return _is;
        case TOKlbracket:
            /* Scan ahead to see if it is an array initializer or
             * an expression.
             * If it ends with a ';' ',' or '}', it is an array initializer.
             */
            brackets = 1;
            for (t = peek(&token); 1; t = peek(t))
            {
                switch (t.value)
                {
                case TOKlbracket:
                    brackets++;
                    continue;
                case TOKrbracket:
                    if (--brackets == 0)
                    {
                        t = peek(t);
                        if (t.value != TOKsemicolon && t.value != TOKcomma && t.value != TOKrbracket && t.value != TOKrcurly)
                            goto Lexpression;
                        break;
                    }
                    continue;
                case TOKeof:
                    break;
                default:
                    continue;
                }
                break;
            }
            ia = new ArrayInitializer(loc);
            nextToken();
            comma = 2;
            while (1)
            {
                switch (token.value)
                {
                default:
                    if (comma == 1)
                    {
                        error("comma expected separating array initializers, not %s", token.toChars());
                        nextToken();
                        break;
                    }
                    e = parseAssignExp();
                    if (!e)
                        break;
                    if (token.value == TOKcolon)
                    {
                        nextToken();
                        value = parseInitializer();
                    }
                    else
                    {
                        value = new ExpInitializer(e.loc, e);
                        e = null;
                    }
                    ia.addInit(e, value);
                    comma = 1;
                    continue;
                case TOKlcurly:
                case TOKlbracket:
                    if (comma == 1)
                        error("comma expected separating array initializers, not %s", token.toChars());
                    value = parseInitializer();
                    if (token.value == TOKcolon)
                    {
                        nextToken();
                        e = value.toExpression();
                        value = parseInitializer();
                    }
                    else
                        e = null;
                    ia.addInit(e, value);
                    comma = 1;
                    continue;
                case TOKcomma:
                    if (comma == 2)
                        error("expression expected, not ','");
                    nextToken();
                    comma = 2;
                    continue;
                case TOKrbracket:
                    // allow trailing comma's
                    nextToken();
                    break;
                case TOKeof:
                    error("found '%s' instead of array initializer", token.toChars());
                    break;
                }
                break;
            }
            return ia;
        case TOKvoid:
            t = peek(&token);
            if (t.value == TOKsemicolon || t.value == TOKcomma)
            {
                nextToken();
                return new VoidInitializer(loc);
            }
            goto Lexpression;
        default:
        Lexpression:
            e = parseAssignExp();
            ie = new ExpInitializer(loc, e);
            return ie;
        }
    }

    /*****************************************
     * Parses default argument initializer expression that is an assign expression,
     * with special handling for __FILE__, __LINE__, __MODULE__, __FUNCTION__, and __PRETTY_FUNCTION__.
     */
    Expression parseDefaultInitExp()
    {
        if (token.value == TOKfile || token.value == TOKline || token.value == TOKmodulestring || token.value == TOKfuncstring || token.value == TOKprettyfunc)
        {
            Token* t = peek(&token);
            if (t.value == TOKcomma || t.value == TOKrparen)
            {
                Expression e = null;
                if (token.value == TOKfile)
                    e = new FileInitExp(token.loc);
                else if (token.value == TOKline)
                    e = new LineInitExp(token.loc);
                else if (token.value == TOKmodulestring)
                    e = new ModuleInitExp(token.loc);
                else if (token.value == TOKfuncstring)
                    e = new FuncInitExp(token.loc);
                else if (token.value == TOKprettyfunc)
                    e = new PrettyFuncInitExp(token.loc);
                else
                    assert(0);
                nextToken();
                return e;
            }
        }
        Expression e = parseAssignExp();
        return e;
    }

    void check(Loc loc, TOK value)
    {
        if (token.value != value)
            error(loc, "found '%s' when expecting '%s'", token.toChars(), Token.toChars(value));
        nextToken();
    }

    void check(TOK value)
    {
        check(token.loc, value);
    }

    void check(TOK value, const(char)* string)
    {
        if (token.value != value)
            error("found '%s' when expecting '%s' following %s", token.toChars(), Token.toChars(value), string);
        nextToken();
    }

    void checkParens(TOK value, Expression e)
    {
        if (precedence[e.op] == PREC_rel && !e.parens)
            error(e.loc, "%s must be parenthesized when next to operator %s", e.toChars(), Token.toChars(value));
    }

    /************************************
     * Determine if the scanner is sitting on the start of a declaration.
     * Input:
     *      needId  0       no identifier
     *              1       identifier optional
     *              2       must have identifier
     *              3       must have identifier, but don't recognize old C-style syntax.
     * Output:
     *      if *pt is not NULL, it is set to the ending token, which would be endtok
     */
    bool isDeclaration(Token* t, int needId, TOK endtok, Token** pt)
    {
        //printf("isDeclaration(needId = %d)\n", needId);
        int haveId = 0;
        int haveTpl = 0;
        while (1)
        {
            if ((t.value == TOKconst || t.value == TOKimmutable || t.value == TOKwild || t.value == TOKshared) && peek(t).value != TOKlparen)
            {
                /* const type
                 * immutable type
                 * shared type
                 * wild type
                 */
                t = peek(t);
                continue;
            }
            break;
        }
        if (!isBasicType(&t))
        {
            goto Lisnot;
        }
        if (!isDeclarator(&t, &haveId, &haveTpl, endtok, needId != 3))
            goto Lisnot;
        if (needId == 1 || (needId == 0 && !haveId) || ((needId == 2 || needId == 3) && haveId))
        {
            if (pt)
                *pt = t;
            goto Lis;
        }
        else
            goto Lisnot;
    Lis:
        //printf("\tis declaration, t = %s\n", t->toChars());
        return true;
    Lisnot:
        //printf("\tis not declaration\n");
        return false;
    }

    bool isBasicType(Token** pt)
    {
        // This code parallels parseBasicType()
        Token* t = *pt;
        switch (t.value)
        {
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
            t = peek(t);
            break;
        case TOKidentifier:
        L5:
            t = peek(t);
            if (t.value == TOKnot)
            {
                goto L4;
            }
            goto L3;
            while (1)
            {
            L2:
                t = peek(t);
            L3:
                if (t.value == TOKdot)
                {
                Ldot:
                    t = peek(t);
                    if (t.value != TOKidentifier)
                        goto Lfalse;
                    t = peek(t);
                    if (t.value != TOKnot)
                        goto L3;
                L4:
                    /* Seen a !
                     * Look for:
                     * !( args ), !identifier, etc.
                     */
                    t = peek(t);
                    switch (t.value)
                    {
                    case TOKidentifier:
                        goto L5;
                    case TOKlparen:
                        if (!skipParens(t, &t))
                            goto Lfalse;
                        goto L3;
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
                    case TOKint32v:
                    case TOKuns32v:
                    case TOKint64v:
                    case TOKuns64v:
                    case TOKint128v:
                    case TOKuns128v:
                    case TOKfloat32v:
                    case TOKfloat64v:
                    case TOKfloat80v:
                    case TOKimaginary32v:
                    case TOKimaginary64v:
                    case TOKimaginary80v:
                    case TOKnull:
                    case TOKtrue:
                    case TOKfalse:
                    case TOKcharv:
                    case TOKwcharv:
                    case TOKdcharv:
                    case TOKstring:
                    case TOKxstring:
                    case TOKfile:
                    case TOKline:
                    case TOKmodulestring:
                    case TOKfuncstring:
                    case TOKprettyfunc:
                        goto L2;
                    default:
                        goto Lfalse;
                    }
                }
                else
                    break;
            }
            break;
        case TOKdot:
            goto Ldot;
        case TOKtypeof:
        case TOKvector:
            /* typeof(exp).identifier...
             */
            t = peek(t);
            if (!skipParens(t, &t))
                goto Lfalse;
            goto L3;
        case TOKconst:
        case TOKimmutable:
        case TOKshared:
        case TOKwild:
            // const(type)  or  immutable(type)  or  shared(type)  or  wild(type)
            t = peek(t);
            if (t.value != TOKlparen)
                goto Lfalse;
            t = peek(t);
            if (!isDeclaration(t, 0, TOKrparen, &t))
            {
                goto Lfalse;
            }
            t = peek(t);
            break;
        default:
            goto Lfalse;
        }
        *pt = t;
        //printf("is\n");
        return true;
    Lfalse:
        //printf("is not\n");
        return false;
    }

    bool isDeclarator(Token** pt, int* haveId, int* haveTpl, TOK endtok, bool allowAltSyntax = true)
    {
        // This code parallels parseDeclarator()
        Token* t = *pt;
        int parens;
        //printf("Parser::isDeclarator() %s\n", t->toChars());
        if (t.value == TOKassign)
            return false;
        while (1)
        {
            parens = false;
            switch (t.value)
            {
            case TOKmul:
                //case TOKand:
                t = peek(t);
                continue;
            case TOKlbracket:
                t = peek(t);
                if (t.value == TOKrbracket)
                {
                    t = peek(t);
                }
                else if (isDeclaration(t, 0, TOKrbracket, &t))
                {
                    // It's an associative array declaration
                    t = peek(t);
                    // ...[type].ident
                    if (t.value == TOKdot && peek(t).value == TOKidentifier)
                    {
                        t = peek(t);
                        t = peek(t);
                    }
                }
                else
                {
                    // [ expression ]
                    // [ expression .. expression ]
                    if (!isExpression(&t))
                        return false;
                    if (t.value == TOKslice)
                    {
                        t = peek(t);
                        if (!isExpression(&t))
                            return false;
                        if (t.value != TOKrbracket)
                            return false;
                        t = peek(t);
                    }
                    else
                    {
                        if (t.value != TOKrbracket)
                            return false;
                        t = peek(t);
                        // ...[index].ident
                        if (t.value == TOKdot && peek(t).value == TOKidentifier)
                        {
                            t = peek(t);
                            t = peek(t);
                        }
                    }
                }
                continue;
            case TOKidentifier:
                if (*haveId)
                    return false;
                *haveId = true;
                t = peek(t);
                break;

            case TOKlparen:
                if (!allowAltSyntax)
                    return false;   // Do not recognize C-style declarations.

                t = peek(t);
                if (t.value == TOKrparen)
                    return false; // () is not a declarator

                /* Regard ( identifier ) as not a declarator
                 * BUG: what about ( *identifier ) in
                 *      f(*p)(x);
                 * where f is a class instance with overloaded () ?
                 * Should we just disallow C-style function pointer declarations?
                 */
                if (t.value == TOKidentifier)
                {
                    Token* t2 = peek(t);
                    if (t2.value == TOKrparen)
                        return false;
                }
                if (!isDeclarator(&t, haveId, null, TOKrparen))
                    return false;
                t = peek(t);
                parens = true;
                break;
            case TOKdelegate:
            case TOKfunction:
                t = peek(t);
                if (!isParameters(&t))
                    return false;
                skipAttributes(t, &t);
                continue;
            default:
                break;
            }
            break;
        }
        while (1)
        {
            switch (t.value)
            {
                static if (CARRAYDECL)
                {
                case TOKlbracket:
                    parens = false;
                    t = peek(t);
                    if (t.value == TOKrbracket)
                    {
                        t = peek(t);
                    }
                    else if (isDeclaration(t, 0, TOKrbracket, &t))
                    {
                        // It's an associative array declaration
                        t = peek(t);
                    }
                    else
                    {
                        // [ expression ]
                        if (!isExpression(&t))
                            return false;
                        if (t.value != TOKrbracket)
                            return false;
                        t = peek(t);
                    }
                    continue;
                }
            case TOKlparen:
                parens = false;
                if (Token* tk = peekPastParen(t))
                {
                    if (tk.value == TOKlparen)
                    {
                        if (!haveTpl)
                            return false;
                        *haveTpl = 1;
                        t = tk;
                    }
                    else if (tk.value == TOKassign)
                    {
                        if (!haveTpl)
                            return false;
                        *haveTpl = 1;
                        *pt = tk;
                        return true;
                    }
                }
                if (!isParameters(&t))
                    return false;
                while (1)
                {
                    switch (t.value)
                    {
                    case TOKconst:
                    case TOKimmutable:
                    case TOKshared:
                    case TOKwild:
                    case TOKpure:
                    case TOKnothrow:
                    case TOKreturn:
                        t = peek(t);
                        continue;
                    case TOKat:
                        t = peek(t); // skip '@'
                        t = peek(t); // skip identifier
                        continue;
                    default:
                        break;
                    }
                    break;
                }
                continue;
                // Valid tokens that follow a declaration
            case TOKrparen:
            case TOKrbracket:
            case TOKassign:
            case TOKcomma:
            case TOKdotdotdot:
            case TOKsemicolon:
            case TOKlcurly:
            case TOKin:
            case TOKout:
            case TOKbody:
                // The !parens is to disallow unnecessary parentheses
                if (!parens && (endtok == TOKreserved || endtok == t.value))
                {
                    *pt = t;
                    return true;
                }
                return false;
            case TOKif:
                return haveTpl ? true : false;
            default:
                return false;
            }
        }
    }

    bool isParameters(Token** pt)
    {
        // This code parallels parseParameters()
        Token* t = *pt;
        //printf("isParameters()\n");
        if (t.value != TOKlparen)
            return false;
        t = peek(t);
        for (; 1; t = peek(t))
        {
        L1:
            switch (t.value)
            {
            case TOKrparen:
                break;
            case TOKdotdotdot:
                t = peek(t);
                break;
            case TOKin:
            case TOKout:
            case TOKref:
            case TOKlazy:
            case TOKscope:
            case TOKfinal:
            case TOKauto:
                continue;
            case TOKconst:
            case TOKimmutable:
            case TOKshared:
            case TOKwild:
                t = peek(t);
                if (t.value == TOKlparen)
                {
                    t = peek(t);
                    if (!isDeclaration(t, 0, TOKrparen, &t))
                        return false;
                    t = peek(t); // skip past closing ')'
                    goto L2;
                }
                goto L1;
                version (none)
                {
                case TOKstatic:
                    continue;
                case TOKauto:
                case TOKalias:
                    t = peek(t);
                    if (t.value == TOKidentifier)
                        t = peek(t);
                    if (t.value == TOKassign)
                    {
                        t = peek(t);
                        if (!isExpression(&t))
                            return false;
                    }
                    goto L3;
                }
            default:
                {
                    if (!isBasicType(&t))
                        return false;
                L2:
                    int tmp = false;
                    if (t.value != TOKdotdotdot && !isDeclarator(&t, &tmp, null, TOKreserved))
                        return false;
                    if (t.value == TOKassign)
                    {
                        t = peek(t);
                        if (!isExpression(&t))
                            return false;
                    }
                    if (t.value == TOKdotdotdot)
                    {
                        t = peek(t);
                        break;
                    }
                }
                if (t.value == TOKcomma)
                {
                    continue;
                }
                break;
            }
            break;
        }
        if (t.value != TOKrparen)
            return false;
        t = peek(t);
        *pt = t;
        return true;
    }

    bool isExpression(Token** pt)
    {
        // This is supposed to determine if something is an expression.
        // What it actually does is scan until a closing right bracket
        // is found.
        Token* t = *pt;
        int brnest = 0;
        int panest = 0;
        int curlynest = 0;
        for (;; t = peek(t))
        {
            switch (t.value)
            {
            case TOKlbracket:
                brnest++;
                continue;
            case TOKrbracket:
                if (--brnest >= 0)
                    continue;
                break;
            case TOKlparen:
                panest++;
                continue;
            case TOKcomma:
                if (brnest || panest)
                    continue;
                break;
            case TOKrparen:
                if (--panest >= 0)
                    continue;
                break;
            case TOKlcurly:
                curlynest++;
                continue;
            case TOKrcurly:
                if (--curlynest >= 0)
                    continue;
                return false;
            case TOKslice:
                if (brnest)
                    continue;
                break;
            case TOKsemicolon:
                if (curlynest)
                    continue;
                return false;
            case TOKeof:
                return false;
            default:
                continue;
            }
            break;
        }
        *pt = t;
        return true;
    }

    /*******************************************
     * Skip parens, brackets.
     * Input:
     *      t is on opening (
     * Output:
     *      *pt is set to closing token, which is ')' on success
     * Returns:
     *      true    successful
     *      false   some parsing error
     */
    bool skipParens(Token* t, Token** pt)
    {
        if (t.value != TOKlparen)
            return false;
        int parens = 0;
        while (1)
        {
            switch (t.value)
            {
            case TOKlparen:
                parens++;
                break;
            case TOKrparen:
                parens--;
                if (parens < 0)
                    goto Lfalse;
                if (parens == 0)
                    goto Ldone;
                break;
            case TOKeof:
                goto Lfalse;
            default:
                break;
            }
            t = peek(t);
        }
    Ldone:
        if (pt)
            *pt = peek(t); // skip found rparen
        return true;
    Lfalse:
        return false;
    }

    bool skipParensIf(Token* t, Token** pt)
    {
        if (t.value != TOKlparen)
        {
            if (pt)
                *pt = t;
            return true;
        }
        return skipParens(t, pt);
    }

    /*******************************************
     * Skip attributes.
     * Input:
     *      t is on a candidate attribute
     * Output:
     *      *pt is set to first non-attribute token on success
     * Returns:
     *      true    successful
     *      false   some parsing error
     */
    bool skipAttributes(Token* t, Token** pt)
    {
        while (1)
        {
            switch (t.value)
            {
            case TOKconst:
            case TOKimmutable:
            case TOKshared:
            case TOKwild:
            case TOKfinal:
            case TOKauto:
            case TOKscope:
            case TOKoverride:
            case TOKabstract:
            case TOKsynchronized:
                break;
            case TOKdeprecated:
                if (peek(t).value == TOKlparen)
                {
                    t = peek(t);
                    if (!skipParens(t, &t))
                        goto Lerror;
                    // t is on the next of closing parenthesis
                    continue;
                }
                break;
            case TOKnothrow:
            case TOKpure:
            case TOKref:
            case TOKgshared:
            case TOKreturn:
                //case TOKmanifest:
                break;
            case TOKat:
                t = peek(t);
                if (t.value == TOKidentifier)
                {
                    /* @identifier
                     * @identifier!arg
                     * @identifier!(arglist)
                     * any of the above followed by (arglist)
                     * @predefined_attribute
                     */
                    if (t.ident == Id.property || t.ident == Id.nogc || t.ident == Id.safe || t.ident == Id.trusted || t.ident == Id.system || t.ident == Id.disable)
                        break;
                    t = peek(t);
                    if (t.value == TOKnot)
                    {
                        t = peek(t);
                        if (t.value == TOKlparen)
                        {
                            // @identifier!(arglist)
                            if (!skipParens(t, &t))
                                goto Lerror;
                            // t is on the next of closing parenthesis
                        }
                        else
                        {
                            // @identifier!arg
                            // Do low rent skipTemplateArgument
                            if (t.value == TOKvector)
                            {
                                // identifier!__vector(type)
                                t = peek(t);
                                if (!skipParens(t, &t))
                                    goto Lerror;
                            }
                            else
                                t = peek(t);
                        }
                    }
                    if (t.value == TOKlparen)
                    {
                        if (!skipParens(t, &t))
                            goto Lerror;
                        // t is on the next of closing parenthesis
                        continue;
                    }
                    continue;
                }
                if (t.value == TOKlparen)
                {
                    // @( ArgumentList )
                    if (!skipParens(t, &t))
                        goto Lerror;
                    // t is on the next of closing parenthesis
                    continue;
                }
                goto Lerror;
            default:
                goto Ldone;
            }
            t = peek(t);
        }
    Ldone:
        if (pt)
            *pt = t;
        return true;
    Lerror:
        return false;
    }

    Expression parseExpression()
    {
        Expression e;
        Expression e2;
        Loc loc = token.loc;
        //printf("Parser::parseExpression() loc = %d\n", loc.linnum);
        e = parseAssignExp();
        while (token.value == TOKcomma)
        {
            nextToken();
            e2 = parseAssignExp();
            e = new CommaExp(loc, e, e2);
            loc = token.loc;
        }
        return e;
    }

    /********************************* Expression Parser ***************************/
    Expression parsePrimaryExp()
    {
        Expression e;
        Type t;
        Identifier id;
        Loc loc = token.loc;
        //printf("parsePrimaryExp(): loc = %d\n", loc.linnum);
        switch (token.value)
        {
        case TOKidentifier:
            {
                Token* t1 = peek(&token);
                Token* t2 = peek(t1);
                if (t1.value == TOKmin && t2.value == TOKgt)
                {
                    // skip ident->
                    nextToken();
                    nextToken();
                    nextToken();
                    error("use '.' for member lookup, not '->'");
                    goto Lerr;
                }

                if (peekNext() == TOKgoesto)
                    goto case_delegate;
                id = token.ident;
                nextToken();
                TOK save;
                if (token.value == TOKnot && (save = peekNext()) != TOKis && save != TOKin)
                {
                    // identifier!(template-argument-list)
                    TemplateInstance tempinst;
                    tempinst = new TemplateInstance(loc, id);
                    tempinst.tiargs = parseTemplateArguments();
                    e = new ScopeExp(loc, tempinst);
                }
                else
                    e = new IdentifierExp(loc, id);
                break;
            }
        case TOKdollar:
            if (!inBrackets)
                error("'$' is valid only inside [] of index or slice");
            e = new DollarExp(loc);
            nextToken();
            break;
        case TOKdot:
            // Signal global scope '.' operator with "" identifier
            e = new IdentifierExp(loc, Id.empty);
            break;
        case TOKthis:
            e = new ThisExp(loc);
            nextToken();
            break;
        case TOKsuper:
            e = new SuperExp(loc);
            nextToken();
            break;
        case TOKint32v:
            e = new IntegerExp(loc, cast(d_int32)token.int64value, Type.tint32);
            nextToken();
            break;
        case TOKuns32v:
            e = new IntegerExp(loc, cast(d_uns32)token.uns64value, Type.tuns32);
            nextToken();
            break;
        case TOKint64v:
            e = new IntegerExp(loc, token.int64value, Type.tint64);
            nextToken();
            break;
        case TOKuns64v:
            e = new IntegerExp(loc, token.uns64value, Type.tuns64);
            nextToken();
            break;
        case TOKfloat32v:
            e = new RealExp(loc, token.float80value, Type.tfloat32);
            nextToken();
            break;
        case TOKfloat64v:
            e = new RealExp(loc, token.float80value, Type.tfloat64);
            nextToken();
            break;
        case TOKfloat80v:
            e = new RealExp(loc, token.float80value, Type.tfloat80);
            nextToken();
            break;
        case TOKimaginary32v:
            e = new RealExp(loc, token.float80value, Type.timaginary32);
            nextToken();
            break;
        case TOKimaginary64v:
            e = new RealExp(loc, token.float80value, Type.timaginary64);
            nextToken();
            break;
        case TOKimaginary80v:
            e = new RealExp(loc, token.float80value, Type.timaginary80);
            nextToken();
            break;
        case TOKnull:
            e = new NullExp(loc);
            nextToken();
            break;
        case TOKfile:
            {
                const(char)* s = loc.filename ? loc.filename : mod.ident.toChars();
                e = new StringExp(loc, cast(char*)s, strlen(s), 0);
                nextToken();
                break;
            }
        case TOKline:
            e = new IntegerExp(loc, loc.linnum, Type.tint32);
            nextToken();
            break;
        case TOKmodulestring:
            {
                const(char)* s = md ? md.toChars() : mod.toChars();
                e = new StringExp(loc, cast(char*)s, strlen(s), 0);
                nextToken();
                break;
            }
        case TOKfuncstring:
            e = new FuncInitExp(loc);
            nextToken();
            break;
        case TOKprettyfunc:
            e = new PrettyFuncInitExp(loc);
            nextToken();
            break;
        case TOKtrue:
            e = new IntegerExp(loc, 1, Type.tbool);
            nextToken();
            break;
        case TOKfalse:
            e = new IntegerExp(loc, 0, Type.tbool);
            nextToken();
            break;
        case TOKcharv:
            e = new IntegerExp(loc, cast(d_uns8)token.uns64value, Type.tchar);
            nextToken();
            break;
        case TOKwcharv:
            e = new IntegerExp(loc, cast(d_uns16)token.uns64value, Type.twchar);
            nextToken();
            break;
        case TOKdcharv:
            e = new IntegerExp(loc, cast(d_uns32)token.uns64value, Type.tdchar);
            nextToken();
            break;
        case TOKstring:
        case TOKxstring:
            {
                // cat adjacent strings
                char* s = token.ustring;
                size_t len = token.len;
                ubyte postfix = token.postfix;
                while (1)
                {
                    nextToken();
                    if (token.value == TOKstring || token.value == TOKxstring)
                    {
                        if (token.postfix)
                        {
                            if (token.postfix != postfix)
                                error("mismatched string literal postfixes '%c' and '%c'", postfix, token.postfix);
                            postfix = token.postfix;
                        }
                        size_t len1 = len;
                        size_t len2 = token.len;
                        len = len1 + len2;
                        char* s2 = cast(char*)mem.xmalloc((len + 1) * char.sizeof);
                        memcpy(s2, s, len1 * char.sizeof);
                        memcpy(s2 + len1, token.ustring, (len2 + 1) * char.sizeof);
                        s = s2;
                    }
                    else
                        break;
                }
                e = new StringExp(loc, s, len, postfix);
                break;
            }
        case TOKvoid:
            t = Type.tvoid;
            goto LabelX;
        case TOKint8:
            t = Type.tint8;
            goto LabelX;
        case TOKuns8:
            t = Type.tuns8;
            goto LabelX;
        case TOKint16:
            t = Type.tint16;
            goto LabelX;
        case TOKuns16:
            t = Type.tuns16;
            goto LabelX;
        case TOKint32:
            t = Type.tint32;
            goto LabelX;
        case TOKuns32:
            t = Type.tuns32;
            goto LabelX;
        case TOKint64:
            t = Type.tint64;
            goto LabelX;
        case TOKuns64:
            t = Type.tuns64;
            goto LabelX;
        case TOKint128:
            t = Type.tint128;
            goto LabelX;
        case TOKuns128:
            t = Type.tuns128;
            goto LabelX;
        case TOKfloat32:
            t = Type.tfloat32;
            goto LabelX;
        case TOKfloat64:
            t = Type.tfloat64;
            goto LabelX;
        case TOKfloat80:
            t = Type.tfloat80;
            goto LabelX;
        case TOKimaginary32:
            t = Type.timaginary32;
            goto LabelX;
        case TOKimaginary64:
            t = Type.timaginary64;
            goto LabelX;
        case TOKimaginary80:
            t = Type.timaginary80;
            goto LabelX;
        case TOKcomplex32:
            t = Type.tcomplex32;
            goto LabelX;
        case TOKcomplex64:
            t = Type.tcomplex64;
            goto LabelX;
        case TOKcomplex80:
            t = Type.tcomplex80;
            goto LabelX;
        case TOKbool:
            t = Type.tbool;
            goto LabelX;
        case TOKchar:
            t = Type.tchar;
            goto LabelX;
        case TOKwchar:
            t = Type.twchar;
            goto LabelX;
        case TOKdchar:
            t = Type.tdchar;
            goto LabelX;
        LabelX:
            nextToken();
            if (token.value == TOKlparen)
            {
                e = new TypeExp(loc, t);
                e = new CallExp(loc, e, parseArguments());
                break;
            }
            check(TOKdot, t.toChars());
            if (token.value != TOKidentifier)
            {
                error("found '%s' when expecting identifier following '%s.'", token.toChars(), t.toChars());
                goto Lerr;
            }
            e = typeDotIdExp(loc, t, token.ident);
            nextToken();
            break;
        case TOKtypeof:
            {
                t = parseTypeof();
                e = new TypeExp(loc, t);
                break;
            }
        case TOKvector:
            {
                t = parseVector();
                e = new TypeExp(loc, t);
                break;
            }
        case TOKtypeid:
            {
                nextToken();
                check(TOKlparen, "typeid");
                RootObject o;
                if (isDeclaration(&token, 0, TOKreserved, null))
                {
                    // argument is a type
                    o = parseType();
                }
                else
                {
                    // argument is an expression
                    o = parseAssignExp();
                }
                check(TOKrparen);
                e = new TypeidExp(loc, o);
                break;
            }
        case TOKtraits:
            {
                /* __traits(identifier, args...)
                 */
                Identifier ident;
                Objects* args = null;
                nextToken();
                check(TOKlparen);
                if (token.value != TOKidentifier)
                {
                    error("__traits(identifier, args...) expected");
                    goto Lerr;
                }
                ident = token.ident;
                nextToken();
                if (token.value == TOKcomma)
                    args = parseTemplateArgumentList(); // __traits(identifier, args...)
                else
                    check(TOKrparen); // __traits(identifier)
                e = new TraitsExp(loc, ident, args);
                break;
            }
        case TOKis:
            {
                Type targ;
                Identifier ident = null;
                Type tspec = null;
                TOK tok = TOKreserved;
                TOK tok2 = TOKreserved;
                TemplateParameters* tpl = null;
                nextToken();
                if (token.value == TOKlparen)
                {
                    nextToken();
                    targ = parseType(&ident);
                    if (token.value == TOKcolon || token.value == TOKequal)
                    {
                        tok = token.value;
                        nextToken();
                        if (tok == TOKequal && (token.value == TOKtypedef || token.value == TOKstruct || token.value == TOKunion || token.value == TOKclass || token.value == TOKsuper || token.value == TOKenum || token.value == TOKinterface || token.value == TOKargTypes || token.value == TOKparameters || token.value == TOKconst && peek(&token).value == TOKrparen || token.value == TOKimmutable && peek(&token).value == TOKrparen || token.value == TOKshared && peek(&token).value == TOKrparen || token.value == TOKwild && peek(&token).value == TOKrparen || token.value == TOKfunction || token.value == TOKdelegate || token.value == TOKreturn))
                        {
                            tok2 = token.value;
                            nextToken();
                            if (tok2 == TOKtypedef)
                                deprecation("typedef is removed");
                        }
                        else
                        {
                            tspec = parseType();
                        }
                    }
                    if (tspec)
                    {
                        if (token.value == TOKcomma)
                            tpl = parseTemplateParameterList(1);
                        else
                        {
                            tpl = new TemplateParameters();
                            check(TOKrparen);
                        }
                    }
                    else
                        check(TOKrparen);
                }
                else
                {
                    error("(type identifier : specialization) expected following is");
                    goto Lerr;
                }
                e = new IsExp(loc, targ, ident, tok, tspec, tok2, tpl);
                break;
            }
        case TOKassert:
            {
                Expression msg = null;
                nextToken();
                check(TOKlparen, "assert");
                e = parseAssignExp();
                if (token.value == TOKcomma)
                {
                    nextToken();
                    msg = parseAssignExp();
                }
                check(TOKrparen);
                e = new AssertExp(loc, e, msg);
                break;
            }
        case TOKmixin:
            {
                nextToken();
                check(TOKlparen, "mixin");
                e = parseAssignExp();
                check(TOKrparen);
                e = new CompileExp(loc, e);
                break;
            }
        case TOKimport:
            {
                nextToken();
                check(TOKlparen, "import");
                e = parseAssignExp();
                check(TOKrparen);
                e = new FileExp(loc, e);
                break;
            }
        case TOKnew:
            e = parseNewExp(null);
            break;
        case TOKlparen:
            {
                Token* tk = peekPastParen(&token);
                if (skipAttributes(tk, &tk) && (tk.value == TOKgoesto || tk.value == TOKlcurly))
                {
                    // (arguments) => expression
                    // (arguments) { statements... }
                    goto case_delegate;
                }
                // ( expression )
                nextToken();
                e = parseExpression();
                e.parens = 1;
                check(loc, TOKrparen);
                break;
            }
        case TOKlbracket:
            {
                /* Parse array literals and associative array literals:
                 *  [ value, value, value ... ]
                 *  [ key:value, key:value, key:value ... ]
                 */
                auto values = new Expressions();
                Expressions* keys = null;
                nextToken();
                while (token.value != TOKrbracket && token.value != TOKeof)
                {
                    e = parseAssignExp();
                    if (token.value == TOKcolon && (keys || values.dim == 0))
                    {
                        nextToken();
                        if (!keys)
                            keys = new Expressions();
                        keys.push(e);
                        e = parseAssignExp();
                    }
                    else if (keys)
                    {
                        error("'key:value' expected for associative array literal");
                        keys = null;
                    }
                    values.push(e);
                    if (token.value == TOKrbracket)
                        break;
                    check(TOKcomma);
                }
                check(loc, TOKrbracket);
                if (keys)
                    e = new AssocArrayLiteralExp(loc, keys, values);
                else
                    e = new ArrayLiteralExp(loc, values);
                break;
            }
        case TOKlcurly:
        case TOKfunction:
        case TOKdelegate:
        case_delegate:
            {
                Dsymbol s = parseFunctionLiteral();
                e = new FuncExp(loc, s);
                break;
            }
        default:
            error("expression expected, not '%s'", token.toChars());
        Lerr:
            // Anything for e, as long as it's not NULL
            e = new IntegerExp(loc, 0, Type.tint32);
            nextToken();
            break;
        }
        return e;
    }

    Expression parseUnaryExp()
    {
        Expression e;
        Loc loc = token.loc;
        switch (token.value)
        {
        case TOKand:
            nextToken();
            e = parseUnaryExp();
            e = new AddrExp(loc, e);
            break;
        case TOKplusplus:
            nextToken();
            e = parseUnaryExp();
            //e = new AddAssignExp(loc, e, new IntegerExp(loc, 1, Type::tint32));
            e = new PreExp(TOKpreplusplus, loc, e);
            break;
        case TOKminusminus:
            nextToken();
            e = parseUnaryExp();
            //e = new MinAssignExp(loc, e, new IntegerExp(loc, 1, Type::tint32));
            e = new PreExp(TOKpreminusminus, loc, e);
            break;
        case TOKmul:
            nextToken();
            e = parseUnaryExp();
            e = new PtrExp(loc, e);
            break;
        case TOKmin:
            nextToken();
            e = parseUnaryExp();
            e = new NegExp(loc, e);
            break;
        case TOKadd:
            nextToken();
            e = parseUnaryExp();
            e = new UAddExp(loc, e);
            break;
        case TOKnot:
            nextToken();
            e = parseUnaryExp();
            e = new NotExp(loc, e);
            break;
        case TOKtilde:
            nextToken();
            e = parseUnaryExp();
            e = new ComExp(loc, e);
            break;
        case TOKdelete:
            nextToken();
            e = parseUnaryExp();
            e = new DeleteExp(loc, e);
            break;
        case TOKcast:
            // cast(type) expression
            {
                nextToken();
                check(TOKlparen);
                /* Look for cast(), cast(const), cast(immutable),
                 * cast(shared), cast(shared const), cast(wild), cast(shared wild)
                 */
                ubyte m = 0;
                while (1)
                {
                    switch (token.value)
                    {
                    case TOKconst:
                        if (peekNext() == TOKlparen)
                            break;
                        // const as type constructor
                        m |= MODconst; // const as storage class
                        nextToken();
                        continue;
                    case TOKimmutable:
                        if (peekNext() == TOKlparen)
                            break;
                        m |= MODimmutable;
                        nextToken();
                        continue;
                    case TOKshared:
                        if (peekNext() == TOKlparen)
                            break;
                        m |= MODshared;
                        nextToken();
                        continue;
                    case TOKwild:
                        if (peekNext() == TOKlparen)
                            break;
                        m |= MODwild;
                        nextToken();
                        continue;
                    default:
                        break;
                    }
                    break;
                }
                if (token.value == TOKrparen)
                {
                    nextToken();
                    e = parseUnaryExp();
                    e = new CastExp(loc, e, m);
                }
                else
                {
                    Type t = parseType(); // cast( type )
                    t = t.addMod(m); // cast( const type )
                    check(TOKrparen);
                    e = parseUnaryExp();
                    e = new CastExp(loc, e, t);
                }
                break;
            }
        case TOKwild:
        case TOKshared:
        case TOKconst:
        case TOKimmutable:
            // immutable(type)(arguments) / immutable(type).init
            {
                StorageClass stc = parseTypeCtor();
                Type t = parseBasicType();
                t = t.addSTC(stc);
                e = new TypeExp(loc, t);
                if (stc == 0 && token.value == TOKdot)
                {
                    nextToken();
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected following (type).");
                        return null;
                    }
                    e = typeDotIdExp(loc, t, token.ident);
                    nextToken();
                    e = parsePostExp(e);
                    break;
                }
                else if (token.value != TOKlparen)
                {
                    error("(arguments) expected following %s", t.toChars());
                    return e;
                }
                e = new CallExp(loc, e, parseArguments());
                break;
            }
        case TOKlparen:
            {
                Token* tk;
                tk = peek(&token);
                static if (CCASTSYNTAX)
                {
                    // If cast
                    if (isDeclaration(tk, 0, TOKrparen, &tk))
                    {
                        tk = peek(tk); // skip over right parenthesis
                        switch (tk.value)
                        {
                        case TOKnot:
                            tk = peek(tk);
                            if (tk.value == TOKis || tk.value == TOKin) // !is or !in
                                break;
                        case TOKdot:
                        case TOKplusplus:
                        case TOKminusminus:
                        case TOKdelete:
                        case TOKnew:
                        case TOKlparen:
                        case TOKidentifier:
                        case TOKthis:
                        case TOKsuper:
                        case TOKint32v:
                        case TOKuns32v:
                        case TOKint64v:
                        case TOKuns64v:
                        case TOKint128v:
                        case TOKuns128v:
                        case TOKfloat32v:
                        case TOKfloat64v:
                        case TOKfloat80v:
                        case TOKimaginary32v:
                        case TOKimaginary64v:
                        case TOKimaginary80v:
                        case TOKnull:
                        case TOKtrue:
                        case TOKfalse:
                        case TOKcharv:
                        case TOKwcharv:
                        case TOKdcharv:
                        case TOKstring:
                            version (none)
                            {
                            case TOKtilde:
                            case TOKand:
                            case TOKmul:
                            case TOKmin:
                            case TOKadd:
                            }
                        case TOKfunction:
                        case TOKdelegate:
                        case TOKtypeof:
                        case TOKvector:
                        case TOKfile:
                        case TOKline:
                        case TOKmodulestring:
                        case TOKfuncstring:
                        case TOKprettyfunc:
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
                            {
                                // (type) una_exp
                                Type t;
                                nextToken();
                                t = parseType();
                                check(TOKrparen);
                                // if .identifier
                                // or .identifier!( ... )
                                if (token.value == TOKdot)
                                {
                                    if (peekNext() != TOKidentifier && peekNext() != TOKnew)
                                    {
                                        error("identifier or new keyword expected following (...).");
                                        return null;
                                    }
                                    e = new TypeExp(loc, t);
                                    e = parsePostExp(e);
                                }
                                else
                                {
                                    e = parseUnaryExp();
                                    e = new CastExp(loc, e, t);
                                    error("C style cast illegal, use %s", e.toChars());
                                }
                                return e;
                            }
                        default:
                            break;
                        }
                    }
                }
                e = parsePrimaryExp();
                e = parsePostExp(e);
                break;
            }
        default:
            e = parsePrimaryExp();
            e = parsePostExp(e);
            break;
        }
        assert(e);
        // ^^ is right associative and has higher precedence than the unary operators
        while (token.value == TOKpow)
        {
            nextToken();
            Expression e2 = parseUnaryExp();
            e = new PowExp(loc, e, e2);
        }
        return e;
    }

    Expression parsePostExp(Expression e)
    {
        Loc loc;
        while (1)
        {
            loc = token.loc;
            switch (token.value)
            {
            case TOKdot:
                nextToken();
                if (token.value == TOKidentifier)
                {
                    Identifier id = token.ident;
                    nextToken();
                    if (token.value == TOKnot && peekNext() != TOKis && peekNext() != TOKin)
                    {
                        Objects* tiargs = parseTemplateArguments();
                        e = new DotTemplateInstanceExp(loc, e, id, tiargs);
                    }
                    else
                        e = new DotIdExp(loc, e, id);
                    continue;
                }
                else if (token.value == TOKnew)
                {
                    e = parseNewExp(e);
                    continue;
                }
                else
                    error("identifier expected following '.', not '%s'", token.toChars());
                break;
            case TOKplusplus:
                e = new PostExp(TOKplusplus, loc, e);
                break;
            case TOKminusminus:
                e = new PostExp(TOKminusminus, loc, e);
                break;
            case TOKlparen:
                e = new CallExp(loc, e, parseArguments());
                continue;
            case TOKlbracket:
                {
                    // array dereferences:
                    //      array[index]
                    //      array[]
                    //      array[lwr .. upr]
                    Expression index;
                    Expression upr;
                    auto arguments = new Expressions();
                    inBrackets++;
                    nextToken();
                    while (token.value != TOKrbracket && token.value != TOKeof)
                    {
                        index = parseAssignExp();
                        if (token.value == TOKslice)
                        {
                            // array[..., lwr..upr, ...]
                            nextToken();
                            upr = parseAssignExp();
                            arguments.push(new IntervalExp(loc, index, upr));
                        }
                        else
                            arguments.push(index);
                        if (token.value == TOKrbracket)
                            break;
                        check(TOKcomma);
                    }
                    check(TOKrbracket);
                    inBrackets--;
                    e = new ArrayExp(loc, e, arguments);
                    continue;
                }
            default:
                return e;
            }
            nextToken();
        }
    }

    Expression parseMulExp()
    {
        Expression e;
        Expression e2;
        Loc loc = token.loc;
        e = parseUnaryExp();
        while (1)
        {
            switch (token.value)
            {
            case TOKmul:
                nextToken();
                e2 = parseUnaryExp();
                e = new MulExp(loc, e, e2);
                continue;
            case TOKdiv:
                nextToken();
                e2 = parseUnaryExp();
                e = new DivExp(loc, e, e2);
                continue;
            case TOKmod:
                nextToken();
                e2 = parseUnaryExp();
                e = new ModExp(loc, e, e2);
                continue;
            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseAddExp()
    {
        Expression e;
        Expression e2;
        Loc loc = token.loc;
        e = parseMulExp();
        while (1)
        {
            switch (token.value)
            {
            case TOKadd:
                nextToken();
                e2 = parseMulExp();
                e = new AddExp(loc, e, e2);
                continue;
            case TOKmin:
                nextToken();
                e2 = parseMulExp();
                e = new MinExp(loc, e, e2);
                continue;
            case TOKtilde:
                nextToken();
                e2 = parseMulExp();
                e = new CatExp(loc, e, e2);
                continue;
            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseShiftExp()
    {
        Expression e;
        Expression e2;
        Loc loc = token.loc;
        e = parseAddExp();
        while (1)
        {
            switch (token.value)
            {
            case TOKshl:
                nextToken();
                e2 = parseAddExp();
                e = new ShlExp(loc, e, e2);
                continue;
            case TOKshr:
                nextToken();
                e2 = parseAddExp();
                e = new ShrExp(loc, e, e2);
                continue;
            case TOKushr:
                nextToken();
                e2 = parseAddExp();
                e = new UshrExp(loc, e, e2);
                continue;
            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseCmpExp()
    {
        Expression e;
        Expression e2;
        Token* t;
        Loc loc = token.loc;
        e = parseShiftExp();
        TOK op = token.value;
        switch (op)
        {
        case TOKequal:
        case TOKnotequal:
            nextToken();
            e2 = parseShiftExp();
            e = new EqualExp(op, loc, e, e2);
            break;
        case TOKis:
            op = TOKidentity;
            goto L1;
        case TOKnot:
            // Attempt to identify '!is'
            t = peek(&token);
            if (t.value == TOKin)
            {
                nextToken();
                nextToken();
                e2 = parseShiftExp();
                e = new InExp(loc, e, e2);
                e = new NotExp(loc, e);
                break;
            }
            if (t.value != TOKis)
                break;
            nextToken();
            op = TOKnotidentity;
            goto L1;
        L1:
            nextToken();
            e2 = parseShiftExp();
            e = new IdentityExp(op, loc, e, e2);
            break;
        case TOKlt:
        case TOKle:
        case TOKgt:
        case TOKge:
        case TOKunord:
        case TOKlg:
        case TOKleg:
        case TOKule:
        case TOKul:
        case TOKuge:
        case TOKug:
        case TOKue:
            nextToken();
            e2 = parseShiftExp();
            e = new CmpExp(op, loc, e, e2);
            break;
        case TOKin:
            nextToken();
            e2 = parseShiftExp();
            e = new InExp(loc, e, e2);
            break;
        default:
            break;
        }
        return e;
    }

    Expression parseAndExp()
    {
        Loc loc = token.loc;
        Expression e = parseCmpExp();
        while (token.value == TOKand)
        {
            checkParens(TOKand, e);
            nextToken();
            Expression e2 = parseCmpExp();
            checkParens(TOKand, e2);
            e = new AndExp(loc, e, e2);
            loc = token.loc;
        }
        return e;
    }

    Expression parseXorExp()
    {
        Loc loc = token.loc;
        Expression e = parseAndExp();
        while (token.value == TOKxor)
        {
            checkParens(TOKxor, e);
            nextToken();
            Expression e2 = parseAndExp();
            checkParens(TOKxor, e2);
            e = new XorExp(loc, e, e2);
        }
        return e;
    }

    Expression parseOrExp()
    {
        Loc loc = token.loc;
        Expression e = parseXorExp();
        while (token.value == TOKor)
        {
            checkParens(TOKor, e);
            nextToken();
            Expression e2 = parseXorExp();
            checkParens(TOKor, e2);
            e = new OrExp(loc, e, e2);
        }
        return e;
    }

    Expression parseAndAndExp()
    {
        Expression e;
        Expression e2;
        Loc loc = token.loc;
        e = parseOrExp();
        while (token.value == TOKandand)
        {
            nextToken();
            e2 = parseOrExp();
            e = new AndAndExp(loc, e, e2);
        }
        return e;
    }

    Expression parseOrOrExp()
    {
        Expression e;
        Expression e2;
        Loc loc = token.loc;
        e = parseAndAndExp();
        while (token.value == TOKoror)
        {
            nextToken();
            e2 = parseAndAndExp();
            e = new OrOrExp(loc, e, e2);
        }
        return e;
    }

    Expression parseCondExp()
    {
        Expression e;
        Expression e1;
        Expression e2;
        Loc loc = token.loc;
        e = parseOrOrExp();
        if (token.value == TOKquestion)
        {
            nextToken();
            e1 = parseExpression();
            check(TOKcolon);
            e2 = parseCondExp();
            e = new CondExp(loc, e, e1, e2);
        }
        return e;
    }

    Expression parseAssignExp()
    {
        Expression e;
        Expression e2;
        Loc loc;
        e = parseCondExp();
        while (1)
        {
            loc = token.loc;
            switch (token.value)
            {
            case TOKassign:
                nextToken();
                e2 = parseAssignExp();
                e = new AssignExp(loc, e, e2);
                continue;
            case TOKaddass:
                nextToken();
                e2 = parseAssignExp();
                e = new AddAssignExp(loc, e, e2);
                continue;
            case TOKminass:
                nextToken();
                e2 = parseAssignExp();
                e = new MinAssignExp(loc, e, e2);
                continue;
            case TOKmulass:
                nextToken();
                e2 = parseAssignExp();
                e = new MulAssignExp(loc, e, e2);
                continue;
            case TOKdivass:
                nextToken();
                e2 = parseAssignExp();
                e = new DivAssignExp(loc, e, e2);
                continue;
            case TOKmodass:
                nextToken();
                e2 = parseAssignExp();
                e = new ModAssignExp(loc, e, e2);
                continue;
            case TOKpowass:
                nextToken();
                e2 = parseAssignExp();
                e = new PowAssignExp(loc, e, e2);
                continue;
            case TOKandass:
                nextToken();
                e2 = parseAssignExp();
                e = new AndAssignExp(loc, e, e2);
                continue;
            case TOKorass:
                nextToken();
                e2 = parseAssignExp();
                e = new OrAssignExp(loc, e, e2);
                continue;
            case TOKxorass:
                nextToken();
                e2 = parseAssignExp();
                e = new XorAssignExp(loc, e, e2);
                continue;
            case TOKshlass:
                nextToken();
                e2 = parseAssignExp();
                e = new ShlAssignExp(loc, e, e2);
                continue;
            case TOKshrass:
                nextToken();
                e2 = parseAssignExp();
                e = new ShrAssignExp(loc, e, e2);
                continue;
            case TOKushrass:
                nextToken();
                e2 = parseAssignExp();
                e = new UshrAssignExp(loc, e, e2);
                continue;
            case TOKcatass:
                nextToken();
                e2 = parseAssignExp();
                e = new CatAssignExp(loc, e, e2);
                continue;
            default:
                break;
            }
            break;
        }
        return e;
    }

    /*************************
     * Collect argument list.
     * Assume current token is ',', '(' or '['.
     */
    Expressions* parseArguments()
    {
        // function call
        Expressions* arguments;
        Expression arg;
        TOK endtok;
        arguments = new Expressions();
        if (token.value == TOKlbracket)
            endtok = TOKrbracket;
        else
            endtok = TOKrparen;
        {
            nextToken();
            while (token.value != endtok && token.value != TOKeof)
            {
                arg = parseAssignExp();
                arguments.push(arg);
                if (token.value == endtok)
                    break;
                check(TOKcomma);
            }
            check(endtok);
        }
        return arguments;
    }

    /*******************************************
     */
    Expression parseNewExp(Expression thisexp)
    {
        Type t;
        Expressions* newargs;
        Expressions* arguments = null;
        Loc loc = token.loc;
        nextToken();
        newargs = null;
        if (token.value == TOKlparen)
        {
            newargs = parseArguments();
        }
        // An anonymous nested class starts with "class"
        if (token.value == TOKclass)
        {
            nextToken();
            if (token.value == TOKlparen)
                arguments = parseArguments();
            BaseClasses* baseclasses = null;
            if (token.value != TOKlcurly)
                baseclasses = parseBaseClasses();
            Identifier id = null;
            auto cd = new ClassDeclaration(loc, id, baseclasses);
            if (token.value != TOKlcurly)
            {
                error("{ members } expected for anonymous class");
                cd.members = null;
            }
            else
            {
                nextToken();
                Dsymbols* decl = parseDeclDefs(0);
                if (token.value != TOKrcurly)
                    error("class member expected");
                nextToken();
                cd.members = decl;
            }
            Expression e = new NewAnonClassExp(loc, thisexp, newargs, cd, arguments);
            return e;
        }
        StorageClass stc = parseTypeCtor();
        t = parseBasicType(true);
        t = parseBasicType2(t);
        t = t.addSTC(stc);
        if (t.ty == Taarray)
        {
            TypeAArray taa = cast(TypeAArray)t;
            Type index = taa.index;
            Expression e = index.toExpression();
            if (e)
            {
                arguments = new Expressions();
                arguments.push(e);
                t = new TypeDArray(taa.next);
            }
            else
            {
                error("need size of rightmost array, not type %s", index.toChars());
                return new NullExp(loc);
            }
        }
        else if (t.ty == Tsarray)
        {
            TypeSArray tsa = cast(TypeSArray)t;
            Expression e = tsa.dim;
            arguments = new Expressions();
            arguments.push(e);
            t = new TypeDArray(tsa.next);
        }
        else if (token.value == TOKlparen)
        {
            arguments = parseArguments();
        }
        Expression e = new NewExp(loc, thisexp, newargs, t, arguments);
        return e;
    }

    /**********************************************
     */
    void addComment(Dsymbol s, const(char)* blockComment)
    {
        s.addComment(combineComments(blockComment, token.lineComment));
        token.lineComment = null;
    }
}

enum PREC : int
{
    PREC_zero,
    PREC_expr,
    PREC_assign,
    PREC_cond,
    PREC_oror,
    PREC_andand,
    PREC_or,
    PREC_xor,
    PREC_and,
    PREC_equal,
    PREC_rel,
    PREC_shift,
    PREC_add,
    PREC_mul,
    PREC_pow,
    PREC_unary,
    PREC_primary,
}

alias PREC_zero = PREC.PREC_zero;
alias PREC_expr = PREC.PREC_expr;
alias PREC_assign = PREC.PREC_assign;
alias PREC_cond = PREC.PREC_cond;
alias PREC_oror = PREC.PREC_oror;
alias PREC_andand = PREC.PREC_andand;
alias PREC_or = PREC.PREC_or;
alias PREC_xor = PREC.PREC_xor;
alias PREC_and = PREC.PREC_and;
alias PREC_equal = PREC.PREC_equal;
alias PREC_rel = PREC.PREC_rel;
alias PREC_shift = PREC.PREC_shift;
alias PREC_add = PREC.PREC_add;
alias PREC_mul = PREC.PREC_mul;
alias PREC_pow = PREC.PREC_pow;
alias PREC_unary = PREC.PREC_unary;
alias PREC_primary = PREC.PREC_primary;
