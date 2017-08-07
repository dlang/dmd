/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _parse.d)
 */

module ddmd.parse;

import core.stdc.stdio;
import core.stdc.string;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.lexer;
import ddmd.errors;
import ddmd.root.filename;
import ddmd.root.outbuffer;
import ddmd.root.rmem;
import ddmd.root.rootobject;
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
    TOKtype : PREC.expr,
    TOKerror : PREC.expr,

    TOKtypeof : PREC.primary,
    TOKmixin : PREC.primary,

    TOKimport : PREC.primary,
    TOKdotvar : PREC.primary,
    TOKscope : PREC.primary,
    TOKidentifier : PREC.primary,
    TOKthis : PREC.primary,
    TOKsuper : PREC.primary,
    TOKint64 : PREC.primary,
    TOKfloat64 : PREC.primary,
    TOKcomplex80 : PREC.primary,
    TOKnull : PREC.primary,
    TOKstring : PREC.primary,
    TOKarrayliteral : PREC.primary,
    TOKassocarrayliteral : PREC.primary,
    TOKclassreference : PREC.primary,
    TOKfile : PREC.primary,
    TOKfilefullpath : PREC.primary,
    TOKline : PREC.primary,
    TOKmodulestring : PREC.primary,
    TOKfuncstring : PREC.primary,
    TOKprettyfunc : PREC.primary,
    TOKtypeid : PREC.primary,
    TOKis : PREC.primary,
    TOKassert : PREC.primary,
    TOKhalt : PREC.primary,
    TOKtemplate : PREC.primary,
    TOKdsymbol : PREC.primary,
    TOKfunction : PREC.primary,
    TOKvar : PREC.primary,
    TOKsymoff : PREC.primary,
    TOKstructliteral : PREC.primary,
    TOKarraylength : PREC.primary,
    TOKdelegateptr : PREC.primary,
    TOKdelegatefuncptr : PREC.primary,
    TOKremove : PREC.primary,
    TOKtuple : PREC.primary,
    TOKtraits : PREC.primary,
    TOKdefault : PREC.primary,
    TOKoverloadset : PREC.primary,
    TOKvoid : PREC.primary,

    // post
    TOKdotti : PREC.primary,
    TOKdotid : PREC.primary,
    TOKdottd : PREC.primary,
    TOKdot : PREC.primary,
    TOKdottype : PREC.primary,
    TOKplusplus : PREC.primary,
    TOKminusminus : PREC.primary,
    TOKpreplusplus : PREC.primary,
    TOKpreminusminus : PREC.primary,
    TOKcall : PREC.primary,
    TOKslice : PREC.primary,
    TOKarray : PREC.primary,
    TOKindex : PREC.primary,

    TOKdelegate : PREC.unary,
    TOKaddress : PREC.unary,
    TOKstar : PREC.unary,
    TOKneg : PREC.unary,
    TOKuadd : PREC.unary,
    TOKnot : PREC.unary,
    TOKtilde : PREC.unary,
    TOKdelete : PREC.unary,
    TOKnew : PREC.unary,
    TOKnewanonclass : PREC.unary,
    TOKcast : PREC.unary,

    TOKvector : PREC.unary,
    TOKpow : PREC.pow,

    TOKmul : PREC.mul,
    TOKdiv : PREC.mul,
    TOKmod : PREC.mul,

    TOKadd : PREC.add,
    TOKmin : PREC.add,
    TOKcat : PREC.add,

    TOKshl : PREC.shift,
    TOKshr : PREC.shift,
    TOKushr : PREC.shift,

    TOKlt : PREC.rel,
    TOKle : PREC.rel,
    TOKgt : PREC.rel,
    TOKge : PREC.rel,
    TOKunord : PREC.rel,
    TOKlg : PREC.rel,
    TOKleg : PREC.rel,
    TOKule : PREC.rel,
    TOKul : PREC.rel,
    TOKuge : PREC.rel,
    TOKug : PREC.rel,
    TOKue : PREC.rel,
    TOKin : PREC.rel,

    /* Note that we changed precedence, so that < and != have the same
     * precedence. This change is in the parser, too.
     */
    TOKequal : PREC.rel,
    TOKnotequal : PREC.rel,
    TOKidentity : PREC.rel,
    TOKnotidentity : PREC.rel,

    TOKand : PREC.and,
    TOKxor : PREC.xor,
    TOKor : PREC.or,

    TOKandand : PREC.andand,
    TOKoror : PREC.oror,

    TOKquestion : PREC.cond,

    TOKassign : PREC.assign,
    TOKconstruct : PREC.assign,
    TOKblit : PREC.assign,
    TOKaddass : PREC.assign,
    TOKminass : PREC.assign,
    TOKcatass : PREC.assign,
    TOKmulass : PREC.assign,
    TOKdivass : PREC.assign,
    TOKmodass : PREC.assign,
    TOKpowass : PREC.assign,
    TOKshlass : PREC.assign,
    TOKshrass : PREC.assign,
    TOKushrass : PREC.assign,
    TOKandass : PREC.assign,
    TOKorass : PREC.assign,
    TOKxorass : PREC.assign,

    TOKcomma : PREC.expr,
    TOKdeclaration : PREC.expr,

    TOKinterval : PREC.assign,
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

struct PrefixAttributes(AST)
{
    StorageClass storageClass;
    AST.Expression depmsg;
    LINK link;
    AST.Prot protection;
    bool setAlignment;
    AST.Expression ealign;
    AST.Expressions* udas;
    const(char)* comment;
}

/*****************************
 * Destructively extract storage class from pAttrs.
 */
private StorageClass getStorageClass(AST)(PrefixAttributes!(AST)* pAttrs)
{
    StorageClass stc = AST.STCundefined;
    if (pAttrs)
    {
        stc = pAttrs.storageClass;
        pAttrs.storageClass = AST.STCundefined;
    }
    return stc;
}

/***********************************************************
 */
final class Parser(AST) : Lexer
{
    AST.Module mod;
    AST.ModuleDeclaration* md;
    LINK linkage;
    CPPMANGLE cppmangle;
    Loc endloc; // set to location of last right curly
    int inBrackets; // inside [] of array index or slice
    Loc lookingForElse; // location of lonely if looking for an else

    /*********************
     * Use this constructor for string mixins.
     * Input:
     *      loc     location in source file of mixin
     */
    extern (D) this(Loc loc, AST.Module _module, const(char)[] input, bool doDocComment)
    {
        super(_module ? _module.srcfile.toChars() : null, input.ptr, 0, input.length, doDocComment, false);

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

    extern (D) this(AST.Module _module, const(char)[] input, bool doDocComment)
    {
        super(_module ? _module.srcfile.toChars() : null, input.ptr, 0, input.length, doDocComment, false);

        //printf("Parser::Parser()\n");
        mod = _module;
        linkage = LINKd;
        //nextToken();              // start up the scanner
    }

    AST.Dsymbols* parseModule()
    {
        const comment = token.blockComment;
        bool isdeprecated = false;
        AST.Expression msg = null;
        AST.Expressions* udas = null;
        AST.Dsymbols* decldefs;
        AST.Dsymbol lastDecl = mod; // for attaching ddoc unittests to module decl

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
                        AST.Expressions* exps = null;
                        const stc = parseAttribute(&exps);
                        if (stc == AST.STCproperty || stc == AST.STCnogc
                          || stc == AST.STCdisable || stc == AST.STCsafe
                          || stc == AST.STCtrusted || stc == AST.STCsystem)
                        {
                            error("`@%s` attribute for module declaration is not supported", token.toChars());
                        }
                        else
                        {
                            udas = AST.UserAttributeDeclaration.concat(udas, exps);
                        }
                        if (stc)
                            nextToken();
                        break;
                    }
                default:
                    {
                        error("`module` expected instead of `%s`", token.toChars());
                        nextToken();
                        break;
                    }
                }
            }
        }

        if (udas)
        {
            auto a = new AST.Dsymbols();
            auto udad = new AST.UserAttributeDeclaration(udas, a);
            mod.userAttribDecl = udad;
        }

        // ModuleDeclation leads off
        if (token.value == TOKmodule)
        {
            const loc = token.loc;

            nextToken();
            if (token.value != TOKidentifier)
            {
                error("identifier expected following `module`");
                goto Lerr;
            }
            else
            {
                AST.Identifiers* a = null;
                Identifier id = token.ident;

                while (nextToken() == TOKdot)
                {
                    if (!a)
                        a = new AST.Identifiers();
                    a.push(id);
                    nextToken();
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected following `package`");
                        goto Lerr;
                    }
                    id = token.ident;
                }

                md = new AST.ModuleDeclaration(loc, a, id, msg, isdeprecated);

                if (token.value != TOKsemicolon)
                    error("`;` expected following module declaration instead of `%s`", token.toChars());
                nextToken();
                addComment(mod, comment);
            }
        }

        decldefs = parseDeclDefs(0, &lastDecl);
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
        return new AST.Dsymbols();
    }

    AST.Dsymbols* parseDeclDefs(int once, AST.Dsymbol* pLastDecl = null, PrefixAttributes!AST* pAttrs = null)
    {
        AST.Dsymbol lastDecl = null; // used to link unittest to its previous declaration
        if (!pLastDecl)
            pLastDecl = &lastDecl;

        const linksave = linkage; // save global state

        //printf("Parser::parseDeclDefs()\n");
        auto decldefs = new AST.Dsymbols();
        do
        {
            // parse result
            AST.Dsymbol s = null;
            AST.Dsymbols* a = null;

            PrefixAttributes!AST attrs;
            if (!once || !pAttrs)
            {
                pAttrs = &attrs;
                pAttrs.comment = token.blockComment;
            }
            AST.PROTKIND prot;
            StorageClass stc;
            AST.Condition condition;

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
                s = cast(AST.Dsymbol)parseTemplateDeclaration();
                break;

            case TOKmixin:
                {
                    const loc = token.loc;
                    switch (peekNext())
                    {
                    case TOKlparen:
                        {
                            // mixin(string)
                            nextToken();
                            check(TOKlparen, "mixin");
                            AST.Expression e = parseAssignExp();
                            check(TOKrparen);
                            check(TOKsemicolon);
                            s = new AST.CompileDeclaration(loc, e);
                            break;
                        }
                    case TOKtemplate:
                        // mixin template
                        nextToken();
                        s = cast(AST.Dsymbol)parseTemplateDeclaration(true);
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
                        error("invariant body expected, not `%s`", token.toChars());
                        goto Lerror;
                    }
                    break;
                }
            case TOKunittest:
                if (global.params.useUnitTests || global.params.doDocComments || global.params.doHdrGeneration)
                {
                    s = parseUnitTest(pAttrs);
                    if (*pLastDecl)
                        (*pLastDecl).ddocUnittest = cast(AST.UnitTestDeclaration)s;
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
                            error(loc, "closing `}` of unittest not found before end of file");
                            goto Lerror;

                        default:
                            continue;
                        }
                        break;
                    }
                    // Workaround 14894. Add an empty unittest declaration to keep
                    // the number of symbols in this scope independent of -unittest.
                    s = new AST.UnitTestDeclaration(loc, token.loc, AST.STCundefined, null);
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
                error("declaration expected, not `%s`", token.toChars());
                goto Lerror;

            case TOKrcurly:
            case TOKeof:
                if (once)
                    error("declaration expected, not `%s`", token.toChars());
                return decldefs;

            case TOKstatic:
                {
                    const next = peekNext();
                    if (next == TOKthis)
                        s = parseStaticCtor(pAttrs);
                    else if (next == TOKtilde)
                        s = parseStaticDtor(pAttrs);
                    else if (next == TOKassert)
                        s = parseStaticAssert();
                    else if (next == TOKif)
                    {
                        condition = parseStaticIfCondition();
                        AST.Dsymbols* athen;
                        if (token.value == TOKcolon)
                            athen = parseBlock(pLastDecl);
                        else
                        {
                            const lookingForElseSave = lookingForElse;
                            lookingForElse = token.loc;
                            athen = parseBlock(pLastDecl);
                            lookingForElse = lookingForElseSave;
                        }
                        AST.Dsymbols* aelse = null;
                        if (token.value == TOKelse)
                        {
                            const elseloc = token.loc;
                            nextToken();
                            aelse = parseBlock(pLastDecl);
                            checkDanglingElse(elseloc);
                        }
                        s = new AST.StaticIfDeclaration(condition, athen, aelse);
                    }
                    else if (next == TOKimport)
                    {
                        a = parseImport();
                        // keep pLastDecl
                    }
                    else if (next == TOKforeach || next == TOKforeach_reverse)
                    {
                        s = parseForeach!(true,true)(loc, pLastDecl);
                    }
                    else
                    {
                        stc = AST.STCstatic;
                        goto Lstc;
                    }
                    break;
                }
            case TOKconst:
                if (peekNext() == TOKlparen)
                    goto Ldeclaration;
                stc = AST.STCconst;
                goto Lstc;

            case TOKimmutable:
                if (peekNext() == TOKlparen)
                    goto Ldeclaration;
                stc = AST.STCimmutable;
                goto Lstc;

            case TOKshared:
                {
                    const next = peekNext();
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
                    stc = AST.STCshared;
                    goto Lstc;
                }
            case TOKwild:
                if (peekNext() == TOKlparen)
                    goto Ldeclaration;
                stc = AST.STCwild;
                goto Lstc;

            case TOKfinal:
                stc = AST.STCfinal;
                goto Lstc;

            case TOKauto:
                stc = AST.STCauto;
                goto Lstc;

            case TOKscope:
                stc = AST.STCscope;
                goto Lstc;

            case TOKoverride:
                stc = AST.STCoverride;
                goto Lstc;

            case TOKabstract:
                stc = AST.STCabstract;
                goto Lstc;

            case TOKsynchronized:
                stc = AST.STCsynchronized;
                goto Lstc;

            case TOKnothrow:
                stc = AST.STCnothrow;
                goto Lstc;

            case TOKpure:
                stc = AST.STCpure;
                goto Lstc;

            case TOKref:
                stc = AST.STCref;
                goto Lstc;

            case TOKgshared:
                stc = AST.STCgshared;
                goto Lstc;

            //case TOKmanifest:   stc = STCmanifest;     goto Lstc;

            case TOKat:
                {
                    AST.Expressions* exps = null;
                    stc = parseAttribute(&exps);
                    if (stc)
                        goto Lstc; // it's a predefined attribute
                    // no redundant/conflicting check for UDAs
                    pAttrs.udas = AST.UserAttributeDeclaration.concat(pAttrs.udas, exps);
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
                    a = parseAutoDeclarations(getStorageClass!AST(pAttrs), pAttrs.comment);
                    if (a && a.dim)
                        *pLastDecl = (*a)[a.dim - 1];
                    if (pAttrs.udas)
                    {
                        s = new AST.UserAttributeDeclaration(pAttrs.udas, a);
                        pAttrs.udas = null;
                    }
                    break;
                }

                /* Look for return type inference for template functions.
                 */
                if (token.value == TOKidentifier && skipParens(peek(&token), &tk) && skipAttributes(tk, &tk) &&
                    (tk.value == TOKlparen || tk.value == TOKlcurly || tk.value == TOKin ||
                     tk.value == TOKout || tk.value == TOKdo ||
                     tk.value == TOKidentifier && tk.ident == Id._body))
                {
                    a = parseDeclarations(true, pAttrs, pAttrs.comment);
                    if (a && a.dim)
                        *pLastDecl = (*a)[a.dim - 1];
                    if (pAttrs.udas)
                    {
                        s = new AST.UserAttributeDeclaration(pAttrs.udas, a);
                        pAttrs.udas = null;
                    }
                    break;
                }

                a = parseBlock(pLastDecl, pAttrs);
                auto stc2 = getStorageClass!AST(pAttrs);
                if (stc2 != AST.STCundefined)
                {
                    s = new AST.StorageClassDeclaration(stc2, a);
                }
                if (pAttrs.udas)
                {
                    if (s)
                    {
                        a = new AST.Dsymbols();
                        a.push(s);
                    }
                    s = new AST.UserAttributeDeclaration(pAttrs.udas, a);
                    pAttrs.udas = null;
                }
                break;

            case TOKdeprecated:
                {
                    if (peek(&token).value != TOKlparen)
                    {
                        stc = AST.STCdeprecated;
                        goto Lstc;
                    }
                    nextToken();
                    check(TOKlparen);
                    AST.Expression e = parseAssignExp();
                    check(TOKrparen);
                    if (pAttrs.depmsg)
                    {
                        error("conflicting storage class `deprecated(%s)` and `deprecated(%s)`", pAttrs.depmsg.toChars(), e.toChars());
                    }
                    pAttrs.depmsg = e;
                    a = parseBlock(pLastDecl, pAttrs);
                    if (pAttrs.depmsg)
                    {
                        s = new AST.DeprecatedDeclaration(pAttrs.depmsg, a);
                        pAttrs.depmsg = null;
                    }
                    break;
                }
            case TOKlbracket:
                {
                    if (peekNext() == TOKrbracket)
                        error("empty attribute list is not allowed");
                    error("use `@(attributes)` instead of `[attributes]`");
                    AST.Expressions* exps = parseArguments();
                    // no redundant/conflicting check for UDAs

                    pAttrs.udas = AST.UserAttributeDeclaration.concat(pAttrs.udas, exps);
                    a = parseBlock(pLastDecl, pAttrs);
                    if (pAttrs.udas)
                    {
                        s = new AST.UserAttributeDeclaration(pAttrs.udas, a);
                        pAttrs.udas = null;
                    }
                    break;
                }
            case TOKextern:
                {
                    if (peek(&token).value != TOKlparen)
                    {
                        stc = AST.STCextern;
                        goto Lstc;
                    }

                    const linkLoc = token.loc;
                    AST.Identifiers* idents = null;
                    CPPMANGLE cppmangle;
                    const link = parseLinkage(&idents, cppmangle);
                    if (pAttrs.link != LINKdefault)
                    {
                        if (pAttrs.link != link)
                        {
                            error("conflicting linkage `extern (%s)` and `extern (%s)`", AST.linkageToChars(pAttrs.link), AST.linkageToChars(link));
                        }
                        else if (idents)
                        {
                            // Allow:
                            //      extern(C++, foo) extern(C++, bar) void foo();
                            // to be equivalent with:
                            //      extern(C++, foo.bar) void foo();
                        }
                        else
                            error("redundant linkage `extern (%s)`", AST.linkageToChars(pAttrs.link));
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
                            {
                                a = new AST.Dsymbols();
                                a.push(s);
                            }
                            s = new AST.Nspace(linkLoc, id, a);
                        }
                        pAttrs.link = LINKdefault;
                    }
                    else if (cppmangle != CPPMANGLE.def)
                    {
                        assert(link == LINKcpp);
                        s = new AST.CPPMangleDeclaration(cppmangle, a);
                    }
                    else if (pAttrs.link != LINKdefault)
                    {
                        s = new AST.LinkDeclaration(pAttrs.link, a);
                        pAttrs.link = LINKdefault;
                    }
                    break;
                }

            case TOKprivate:
                prot = AST.PROTprivate;
                goto Lprot;

            case TOKpackage:
                prot = AST.PROTpackage;
                goto Lprot;

            case TOKprotected:
                prot = AST.PROTprotected;
                goto Lprot;

            case TOKpublic:
                prot = AST.PROTpublic;
                goto Lprot;

            case TOKexport:
                prot = AST.PROTexport;
                goto Lprot;
            Lprot:
                {
                    if (pAttrs.protection.kind != AST.PROTundefined)
                    {
                        if (pAttrs.protection.kind != prot)
                            error("conflicting protection attribute `%s` and `%s`", AST.protectionToChars(pAttrs.protection.kind), AST.protectionToChars(prot));
                        else
                            error("redundant protection attribute `%s`", AST.protectionToChars(prot));
                    }
                    pAttrs.protection.kind = prot;

                    nextToken();

                    // optional qualified package identifier to bind
                    // protection to
                    AST.Identifiers* pkg_prot_idents = null;
                    if (pAttrs.protection.kind == AST.PROTpackage && token.value == TOKlparen)
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

                    const attrloc = token.loc;
                    a = parseBlock(pLastDecl, pAttrs);
                    if (pAttrs.protection.kind != AST.PROTundefined)
                    {
                        if (pAttrs.protection.kind == AST.PROTpackage && pkg_prot_idents)
                            s = new AST.ProtDeclaration(attrloc, pkg_prot_idents, a);
                        else
                            s = new AST.ProtDeclaration(attrloc, pAttrs.protection, a);

                        pAttrs.protection = AST.Prot(AST.PROTundefined);
                    }
                    break;
                }
            case TOKalign:
                {
                    const attrLoc = token.loc;

                    nextToken();

                    AST.Expression e = null; // default
                    if (token.value == TOKlparen)
                    {
                        nextToken();
                        e = parseAssignExp();
                        check(TOKrparen);
                    }

                    if (pAttrs.setAlignment)
                    {
                        if (e)
                            error("redundant alignment attribute `align(%s)`", e.toChars());
                        else
                            error("redundant alignment attribute `align`");
                    }

                    pAttrs.setAlignment = true;
                    pAttrs.ealign = e;
                    a = parseBlock(pLastDecl, pAttrs);
                    if (pAttrs.setAlignment)
                    {
                        s = new AST.AlignDeclaration(attrLoc, pAttrs.ealign, a);
                        pAttrs.setAlignment = false;
                        pAttrs.ealign = null;
                    }
                    break;
                }
            case TOKpragma:
                {
                    AST.Expressions* args = null;
                    const loc = token.loc;

                    nextToken();
                    check(TOKlparen);
                    if (token.value != TOKidentifier)
                    {
                        error("`pragma(identifier)` expected");
                        goto Lerror;
                    }
                    Identifier ident = token.ident;
                    nextToken();
                    if (token.value == TOKcomma && peekNext() != TOKrparen)
                        args = parseArguments(); // pragma(identifier, args...)
                    else
                        check(TOKrparen); // pragma(identifier)

                    AST.Dsymbols* a2 = null;
                    if (token.value == TOKsemicolon)
                    {
                        /* https://issues.dlang.org/show_bug.cgi?id=2354
                         * Accept single semicolon as an empty
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
                    s = new AST.PragmaDeclaration(loc, ident, args, a2);
                    break;
                }
            case TOKdebug:
                nextToken();
                if (token.value == TOKassign)
                {
                    nextToken();
                    if (token.value == TOKidentifier)
                        s = new AST.DebugSymbol(token.loc, token.ident);
                    else if (token.value == TOKint32v || token.value == TOKint64v)
                        s = new AST.DebugSymbol(token.loc, cast(uint)token.uns64value);
                    else
                    {
                        error("identifier or integer expected, not `%s`", token.toChars());
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
                        s = new AST.VersionSymbol(token.loc, token.ident);
                    else if (token.value == TOKint32v || token.value == TOKint64v)
                        s = new AST.VersionSymbol(token.loc, cast(uint)token.uns64value);
                    else
                    {
                        error("identifier or integer expected, not `%s`", token.toChars());
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
                    AST.Dsymbols* athen;
                    if (token.value == TOKcolon)
                        athen = parseBlock(pLastDecl);
                    else
                    {
                        const lookingForElseSave = lookingForElse;
                        lookingForElse = token.loc;
                        athen = parseBlock(pLastDecl);
                        lookingForElse = lookingForElseSave;
                    }
                    AST.Dsymbols* aelse = null;
                    if (token.value == TOKelse)
                    {
                        const elseloc = token.loc;
                        nextToken();
                        aelse = parseBlock(pLastDecl);
                        checkDanglingElse(elseloc);
                    }
                    s = new AST.ConditionalDeclaration(condition, athen, aelse);
                    break;
                }
            case TOKsemicolon:
                // empty declaration
                //error("empty declaration");
                nextToken();
                continue;

            default:
                error("declaration expected, not `%s`", token.toChars());
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
    AST.Dsymbols* parseAutoDeclarations(StorageClass storageClass, const(char)* comment)
    {
        //printf("parseAutoDeclarations\n");
        Token* tk;
        auto a = new AST.Dsymbols();

        while (1)
        {
            const loc = token.loc;
            Identifier ident = token.ident;
            nextToken(); // skip over ident

            AST.TemplateParameters* tpl = null;
            if (token.value == TOKlparen)
                tpl = parseTemplateParameterList();

            check(TOKassign);   // skip over '='
            AST.Initializer _init = parseInitializer();
            auto v = new AST.VarDeclaration(loc, null, ident, _init, storageClass);

            AST.Dsymbol s = v;
            if (tpl)
            {
                auto a2 = new AST.Dsymbols();
                a2.push(v);
                auto tempdecl = new AST.TemplateDeclaration(loc, ident, tpl, null, a2, 0);
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
                error("semicolon expected following auto declaration, not `%s`", token.toChars());
                break;
            }
            break;
        }
        return a;
    }

    /********************************************
     * Parse declarations after an align, protection, or extern decl.
     */
    AST.Dsymbols* parseBlock(AST.Dsymbol* pLastDecl, PrefixAttributes!AST* pAttrs = null)
    {
        AST.Dsymbols* a = null;

        //printf("parseBlock()\n");
        switch (token.value)
        {
        case TOKsemicolon:
            error("declaration expected following attribute, not `;`");
            nextToken();
            break;

        case TOKeof:
            error("declaration expected following attribute, not end of file");
            break;

        case TOKlcurly:
            {
                const lookingForElseSave = lookingForElse;
                lookingForElse = Loc();

                nextToken();
                a = parseDeclDefs(0, pLastDecl);
                if (token.value != TOKrcurly)
                {
                    /* { */
                    error("matching `}` expected, not `%s`", token.toChars());
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
        if ((storageClass & stc) || (storageClass & AST.STCin && stc & (AST.STCconst | AST.STCscope)) || (stc & AST.STCin && storageClass & (AST.STCconst | AST.STCscope)))
        {
            OutBuffer buf;
            AST.stcToBuffer(&buf, stc);
            if (deprec)
                deprecation("redundant attribute `%s`", buf.peekString());
            else
                error("redundant attribute `%s`", buf.peekString());
            return storageClass | stc;
        }

        storageClass |= stc;

        if (stc & (AST.STCconst | AST.STCimmutable | AST.STCmanifest))
        {
            StorageClass u = storageClass & (AST.STCconst | AST.STCimmutable | AST.STCmanifest);
            if (u & (u - 1))
                error("conflicting attribute `%s`", Token.toChars(token.value));
        }
        if (stc & (AST.STCgshared | AST.STCshared | AST.STCtls))
        {
            StorageClass u = storageClass & (AST.STCgshared | AST.STCshared | AST.STCtls);
            if (u & (u - 1))
                error("conflicting attribute `%s`", Token.toChars(token.value));
        }
        if (stc & (AST.STCsafe | AST.STCsystem | AST.STCtrusted))
        {
            StorageClass u = storageClass & (AST.STCsafe | AST.STCsystem | AST.STCtrusted);
            if (u & (u - 1))
                error("conflicting attribute `@%s`", token.toChars());
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
    StorageClass parseAttribute(AST.Expressions** pudas)
    {
        nextToken();
        AST.Expressions* udas = null;
        StorageClass stc = 0;
        if (token.value == TOKidentifier)
        {
            if (token.ident == Id.property)
                stc = AST.STCproperty;
            else if (token.ident == Id.nogc)
                stc = AST.STCnogc;
            else if (token.ident == Id.safe)
                stc = AST.STCsafe;
            else if (token.ident == Id.trusted)
                stc = AST.STCtrusted;
            else if (token.ident == Id.system)
                stc = AST.STCsystem;
            else if (token.ident == Id.disable)
                stc = AST.STCdisable;
            else if (token.ident == Id.future)
                stc = AST.STCfuture;
            else
            {
                // Allow identifier, template instantiation, or function call
                AST.Expression exp = parsePrimaryExp();
                if (token.value == TOKlparen)
                {
                    const loc = token.loc;
                    exp = new AST.CallExp(loc, exp, parseArguments());
                }

                udas = new AST.Expressions();
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
            error("@identifier or @(ArgumentList) expected, not `@%s`", token.toChars());
        }

        if (stc)
        {
        }
        else if (udas)
        {
            *pudas = AST.UserAttributeDeclaration.concat(*pudas, udas);
        }
        else
            error("valid attributes are `@property`, `@safe`, `@trusted`, `@system`, `@disable`, `@nogc`");
        return stc;
    }

    /***********************************************
     * Parse const/immutable/shared/inout/nothrow/pure postfix
     */
    StorageClass parsePostfix(StorageClass storageClass, AST.Expressions** pudas)
    {
        while (1)
        {
            StorageClass stc;
            switch (token.value)
            {
            case TOKconst:
                stc = AST.STCconst;
                break;

            case TOKimmutable:
                stc = AST.STCimmutable;
                break;

            case TOKshared:
                stc = AST.STCshared;
                break;

            case TOKwild:
                stc = AST.STCwild;
                break;

            case TOKnothrow:
                stc = AST.STCnothrow;
                break;

            case TOKpure:
                stc = AST.STCpure;
                break;

            case TOKreturn:
                stc = AST.STCreturn;
                break;

            case TOKscope:
                stc = AST.STCscope;
                break;

            case TOKat:
                {
                    AST.Expressions* udas = null;
                    stc = parseAttribute(&udas);
                    if (udas)
                    {
                        if (pudas)
                            *pudas = AST.UserAttributeDeclaration.concat(*pudas, udas);
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
        StorageClass storageClass = AST.STCundefined;

        while (1)
        {
            if (peek(&token).value == TOKlparen)
                return storageClass;

            StorageClass stc;
            switch (token.value)
            {
            case TOKconst:
                stc = AST.STCconst;
                break;

            case TOKimmutable:
                stc = AST.STCimmutable;
                break;

            case TOKshared:
                stc = AST.STCshared;
                break;

            case TOKwild:
                stc = AST.STCwild;
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
    AST.Expression parseConstraint()
    {
        AST.Expression e = null;
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
    AST.TemplateDeclaration parseTemplateDeclaration(bool ismixin = false)
    {
        AST.TemplateDeclaration tempdecl;
        Identifier id;
        AST.TemplateParameters* tpl;
        AST.Dsymbols* decldefs;
        AST.Expression constraint = null;
        const loc = token.loc;

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
            decldefs = parseBlock(null);

        tempdecl = new AST.TemplateDeclaration(loc, id, tpl, constraint, decldefs, ismixin);
        return tempdecl;

    Lerr:
        return null;
    }

    /******************************************
     * Parse template parameter list.
     * Input:
     *      flag    0: parsing "( list )"
     *              1: parsing non-empty "list $(RPAREN)"
     */
    AST.TemplateParameters* parseTemplateParameterList(int flag = 0)
    {
        auto tpl = new AST.TemplateParameters();

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
                AST.TemplateParameter tp;
                Loc loc;
                Identifier tp_ident = null;
                AST.Type tp_spectype = null;
                AST.Type tp_valtype = null;
                AST.Type tp_defaulttype = null;
                AST.Expression tp_specvalue = null;
                AST.Expression tp_defaultvalue = null;
                Token* t;

                // Get TemplateParameter

                // First, look ahead to see if it is a TypeParameter or a ValueParameter
                t = peek(&token);
                if (token.value == TOKalias)
                {
                    // AliasParameter
                    nextToken();
                    loc = token.loc; // todo
                    AST.Type spectype = null;
                    if (isDeclaration(&token, NeedDeclaratorId.must, TOKreserved, null))
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
                        if (isDeclaration(&token, NeedDeclaratorId.no, TOKreserved, null))
                            spec = parseType();
                        else
                            spec = parseCondExp();
                    }
                    RootObject def = null;
                    if (token.value == TOKassign) // = Type
                    {
                        nextToken();
                        if (isDeclaration(&token, NeedDeclaratorId.no, TOKreserved, null))
                            def = parseType();
                        else
                            def = parseCondExp();
                    }
                    tp = new AST.TemplateAliasParameter(loc, tp_ident, spectype, spec, def);
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
                    tp = new AST.TemplateTypeParameter(loc, tp_ident, tp_spectype, tp_defaulttype);
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
                    tp = new AST.TemplateTupleParameter(loc, tp_ident);
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
                    tp = new AST.TemplateThisParameter(loc, tp_ident, tp_spectype, tp_defaulttype);
                }
                else
                {
                    // ValueParameter
                    loc = token.loc; // todo
                    tp_valtype = parseType(&tp_ident);
                    if (!tp_ident)
                    {
                        error("identifier expected for template value parameter");
                        tp_ident = Identifier.idPool("error");
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
                    tp = new AST.TemplateValueParameter(loc, tp_ident, tp_valtype, tp_specvalue, tp_defaultvalue);
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
    AST.Dsymbol parseMixin()
    {
        AST.TemplateMixin tm;
        Identifier id;
        AST.Objects* tiargs;

        //printf("parseMixin()\n");
        const locMixin = token.loc;
        nextToken(); // skip 'mixin'

        auto loc = token.loc;
        AST.TypeQualified tqual = null;
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
                error("identifier expected, not `%s`", token.toChars());
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
                auto tempinst = new AST.TemplateInstance(loc, id, tiargs);
                if (!tqual)
                    tqual = new AST.TypeInstance(loc, tempinst);
                else
                    tqual.addInst(tempinst);
                tiargs = null;
            }
            else
            {
                if (!tqual)
                    tqual = new AST.TypeIdentifier(loc, id);
                else
                    tqual.addIdent(id);
            }

            if (token.value != TOKdot)
                break;

            nextToken();
            if (token.value != TOKidentifier)
            {
                error("identifier expected following `.` instead of `%s`", token.toChars());
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

        tm = new AST.TemplateMixin(locMixin, id, tqual, tiargs);
        if (token.value != TOKsemicolon)
            error("`;` expected after mixin");
        nextToken();

        return tm;
    }

    /******************************************
     * Parse template arguments.
     * Input:
     *      current token is opening '!'
     * Output:
     *      current token is one after closing '$(RPAREN)'
     */
    AST.Objects* parseTemplateArguments()
    {
        AST.Objects* tiargs;

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
     *      current token is opening '$(LPAREN)',
     *          or ',' for __traits
     * Output:
     *      current token is one after closing '$(RPAREN)'
     */
    AST.Objects* parseTemplateArgumentList()
    {
        //printf("Parser::parseTemplateArgumentList()\n");
        auto tiargs = new AST.Objects();
        TOK endtok = TOKrparen;
        assert(token.value == TOKlparen || token.value == TOKcomma);
        nextToken();

        // Get TemplateArgumentList
        while (token.value != endtok)
        {
            // See if it is an Expression or a Type
            if (isDeclaration(&token, NeedDeclaratorId.no, TOKreserved, null))
            {
                // Template argument is a type
                AST.Type ta = parseType();
                tiargs.push(ta);
            }
            else
            {
                // Template argument is an expression
                AST.Expression ea = parseAssignExp();
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
    AST.Objects* parseTemplateSingleArgument()
    {
        //printf("parseTemplateSingleArgument()\n");
        auto tiargs = new AST.Objects();
        AST.Type ta;
        switch (token.value)
        {
        case TOKidentifier:
            ta = new AST.TypeIdentifier(token.loc, token.ident);
            goto LabelX;

        case TOKvector:
            ta = parseVector();
            goto LabelX;

        case TOKvoid:
            ta = AST.Type.tvoid;
            goto LabelX;

        case TOKint8:
            ta = AST.Type.tint8;
            goto LabelX;

        case TOKuns8:
            ta = AST.Type.tuns8;
            goto LabelX;

        case TOKint16:
            ta = AST.Type.tint16;
            goto LabelX;

        case TOKuns16:
            ta = AST.Type.tuns16;
            goto LabelX;

        case TOKint32:
            ta = AST.Type.tint32;
            goto LabelX;

        case TOKuns32:
            ta = AST.Type.tuns32;
            goto LabelX;

        case TOKint64:
            ta = AST.Type.tint64;
            goto LabelX;

        case TOKuns64:
            ta = AST.Type.tuns64;
            goto LabelX;

        case TOKint128:
            ta = AST.Type.tint128;
            goto LabelX;

        case TOKuns128:
            ta = AST.Type.tuns128;
            goto LabelX;

        case TOKfloat32:
            ta = AST.Type.tfloat32;
            goto LabelX;

        case TOKfloat64:
            ta = AST.Type.tfloat64;
            goto LabelX;

        case TOKfloat80:
            ta = AST.Type.tfloat80;
            goto LabelX;

        case TOKimaginary32:
            ta = AST.Type.timaginary32;
            goto LabelX;

        case TOKimaginary64:
            ta = AST.Type.timaginary64;
            goto LabelX;

        case TOKimaginary80:
            ta = AST.Type.timaginary80;
            goto LabelX;

        case TOKcomplex32:
            ta = AST.Type.tcomplex32;
            goto LabelX;

        case TOKcomplex64:
            ta = AST.Type.tcomplex64;
            goto LabelX;

        case TOKcomplex80:
            ta = AST.Type.tcomplex80;
            goto LabelX;

        case TOKbool:
            ta = AST.Type.tbool;
            goto LabelX;

        case TOKchar:
            ta = AST.Type.tchar;
            goto LabelX;

        case TOKwchar:
            ta = AST.Type.twchar;
            goto LabelX;

        case TOKdchar:
            ta = AST.Type.tdchar;
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
        case TOKfilefullpath:
        case TOKline:
        case TOKmodulestring:
        case TOKfuncstring:
        case TOKprettyfunc:
        case TOKthis:
            {
                // Template argument is an expression
                AST.Expression ea = parsePrimaryExp();
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
    AST.StaticAssert parseStaticAssert()
    {
        const loc = token.loc;
        AST.Expression exp;
        AST.Expression msg = null;

        //printf("parseStaticAssert()\n");
        nextToken();
        nextToken();
        check(TOKlparen);
        exp = parseAssignExp();
        if (token.value == TOKcomma)
        {
            nextToken();
            if (token.value != TOKrparen)
            {
                msg = parseAssignExp();
                if (token.value == TOKcomma)
                    nextToken();
            }
        }
        check(TOKrparen);
        check(TOKsemicolon);
        return new AST.StaticAssert(loc, exp, msg);
    }

    /***********************************
     * Parse typeof(expression).
     * Current token is on the 'typeof'.
     */
    AST.TypeQualified parseTypeof()
    {
        AST.TypeQualified t;
        const loc = token.loc;

        nextToken();
        check(TOKlparen);
        if (token.value == TOKreturn) // typeof(return)
        {
            nextToken();
            t = new AST.TypeReturn(loc);
        }
        else
        {
            AST.Expression exp = parseExpression(); // typeof(expression)
            t = new AST.TypeTypeof(loc, exp);
        }
        check(TOKrparen);
        return t;
    }

    /***********************************
     * Parse __vector(type).
     * Current token is on the '__vector'.
     */
    AST.Type parseVector()
    {
        const loc = token.loc;
        nextToken();
        check(TOKlparen);
        AST.Type tb = parseType();
        check(TOKrparen);
        return new AST.TypeVector(loc, tb);
    }

    /***********************************
     * Parse:
     *      extern (linkage)
     *      extern (C++, namespaces)
     * The parser is on the 'extern' token.
     */
    LINK parseLinkage(AST.Identifiers** pidents, out CPPMANGLE cppmangle)
    {
        AST.Identifiers* idents = null;
        cppmangle = CPPMANGLE.def;
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
                    if (token.value == TOKcomma) // , namespaces or class or struct
                    {
                        nextToken();
                        if (token.value == TOKclass || token.value == TOKstruct)
                        {
                            cppmangle = token.value == TOKclass ? CPPMANGLE.asClass : CPPMANGLE.asStruct;
                            nextToken();
                        }
                        else
                        {
                            idents = new AST.Identifiers();
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
                                {
                                    error("identifier expected for C++ namespace");
                                    idents = null;  // error occurred, invalidate list of elements.
                                }
                                break;
                            }
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
                link = LINKsystem;
            }
            else
            {
            LinvalidLinkage:
                error("valid linkage identifiers are `D`, `C`, `C++`, `Objective-C`, `Pascal`, `Windows`, `System`");
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
    AST.Identifiers* parseQualifiedIdentifier(const(char)* entity)
    {
        AST.Identifiers* qualified = null;

        do
        {
            nextToken();
            if (token.value != TOKidentifier)
            {
                error("`%s` expected as dot-separated identifiers, got `%s`", entity, token.toChars());
                return null;
            }

            Identifier id = token.ident;
            if (!qualified)
                qualified = new AST.Identifiers();
            qualified.push(id);

            nextToken();
        }
        while (token.value == TOKdot);

        return qualified;
    }

    /**************************************
     * Parse a debug conditional
     */
    AST.Condition parseDebugCondition()
    {
        uint level = 1;
        Identifier id = null;

        if (token.value == TOKlparen)
        {
            nextToken();

            if (token.value == TOKidentifier)
                id = token.ident;
            else if (token.value == TOKint32v || token.value == TOKint64v)
                level = cast(uint)token.uns64value;
            else
                error("identifier or integer expected inside debug(...), not `%s`", token.toChars());
            nextToken();
            check(TOKrparen);
        }
        return new AST.DebugCondition(mod, level, id);
    }

    /**************************************
     * Parse a version conditional
     */
    AST.Condition parseVersionCondition()
    {
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
                id = Identifier.idPool(Token.toString(TOKunittest));
            else if (token.value == TOKassert)
                id = Identifier.idPool(Token.toString(TOKassert));
            else
                error("identifier or integer expected inside version(...), not `%s`", token.toChars());
            nextToken();
            check(TOKrparen);
        }
        else
            error("(condition) expected following `version`");
        return new AST.VersionCondition(mod, level, id);
    }

    /***********************************************
     *      static if (expression)
     *          body
     *      else
     *          body
     * Current token is 'static'.
     */
    AST.Condition parseStaticIfCondition()
    {
        AST.Expression exp;
        AST.Condition condition;
        const loc = token.loc;

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
            error("(expression) expected following `static if`");
            exp = null;
        }
        condition = new AST.StaticIfCondition(loc, exp);
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
    AST.Dsymbol parseCtor(PrefixAttributes!AST* pAttrs)
    {
        AST.Expressions* udas = null;
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();
        if (token.value == TOKlparen && peekNext() == TOKthis && peekNext2() == TOKrparen)
        {
            // this(this) { ... }
            nextToken();
            nextToken();
            check(TOKrparen);

            stc = parsePostfix(stc, &udas);
            if (stc & AST.STCstatic)
                error(loc, "postblit cannot be static");

            auto f = new AST.PostBlitDeclaration(loc, Loc(), stc, Id.postblit);
            AST.Dsymbol s = parseContracts(f);
            if (udas)
            {
                auto a = new AST.Dsymbols();
                a.push(f);
                s = new AST.UserAttributeDeclaration(udas, a);
            }
            return s;
        }

        /* Look ahead to see if:
         *   this(...)(...)
         * which is a constructor template
         */
        AST.TemplateParameters* tpl = null;
        if (token.value == TOKlparen && peekPastParen(&token).value == TOKlparen)
        {
            tpl = parseTemplateParameterList();
        }

        /* Just a regular constructor
         */
        int varargs;
        AST.Parameters* parameters = parseParameters(&varargs);
        stc = parsePostfix(stc, &udas);
        if (varargs != 0 || AST.Parameter.dim(parameters) != 0)
        {
            if (stc & AST.STCstatic)
                error(loc, "constructor cannot be static");
        }
        else if (StorageClass ss = stc & (AST.STCshared | AST.STCstatic)) // this()
        {
            if (ss == AST.STCstatic)
                error(loc, "use `static this()` to declare a static constructor");
            else if (ss == (AST.STCshared | AST.STCstatic))
                error(loc, "use `shared static this()` to declare a shared static constructor");
        }

        AST.Expression constraint = tpl ? parseConstraint() : null;

        AST.Type tf = new AST.TypeFunction(parameters, null, varargs, linkage, stc); // RetrunType -> auto
        tf = tf.addSTC(stc);

        auto f = new AST.CtorDeclaration(loc, Loc(), stc, tf);
        AST.Dsymbol s = parseContracts(f);
        if (udas)
        {
            auto a = new AST.Dsymbols();
            a.push(f);
            s = new AST.UserAttributeDeclaration(udas, a);
        }

        if (tpl)
        {
            // Wrap a template around it
            auto decldefs = new AST.Dsymbols();
            decldefs.push(s);
            s = new AST.TemplateDeclaration(loc, f.ident, tpl, constraint, decldefs);
        }

        return s;
    }

    /*****************************************
     * Parse a destructor definition:
     *      ~this() { body }
     * Current token is '~'.
     */
    AST.Dsymbol parseDtor(PrefixAttributes!AST* pAttrs)
    {
        AST.Expressions* udas = null;
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();
        check(TOKthis);
        check(TOKlparen);
        check(TOKrparen);

        stc = parsePostfix(stc, &udas);
        if (StorageClass ss = stc & (AST.STCshared | AST.STCstatic))
        {
            if (ss == AST.STCstatic)
                error(loc, "use `static ~this()` to declare a static destructor");
            else if (ss == (AST.STCshared | AST.STCstatic))
                error(loc, "use `shared static ~this()` to declare a shared static destructor");
        }

        auto f = new AST.DtorDeclaration(loc, Loc(), stc, Id.dtor);
        AST.Dsymbol s = parseContracts(f);
        if (udas)
        {
            auto a = new AST.Dsymbols();
            a.push(f);
            s = new AST.UserAttributeDeclaration(udas, a);
        }
        return s;
    }

    /*****************************************
     * Parse a static constructor definition:
     *      static this() { body }
     * Current token is 'static'.
     */
    AST.Dsymbol parseStaticCtor(PrefixAttributes!AST* pAttrs)
    {
        //Expressions *udas = NULL;
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();
        nextToken();
        check(TOKlparen);
        check(TOKrparen);

        stc = parsePostfix(stc & ~AST.STC_TYPECTOR, null) | stc;
        if (stc & AST.STCshared)
            error(loc, "use `shared static this()` to declare a shared static constructor");
        else if (stc & AST.STCstatic)
            appendStorageClass(stc, AST.STCstatic); // complaint for the redundancy
        else if (StorageClass modStc = stc & AST.STC_TYPECTOR)
        {
            OutBuffer buf;
            AST.stcToBuffer(&buf, modStc);
            error(loc, "static constructor cannot be `%s`", buf.peekString());
        }
        stc &= ~(AST.STCstatic | AST.STC_TYPECTOR);

        auto f = new AST.StaticCtorDeclaration(loc, Loc(), stc);
        AST.Dsymbol s = parseContracts(f);
        return s;
    }

    /*****************************************
     * Parse a static destructor definition:
     *      static ~this() { body }
     * Current token is 'static'.
     */
    AST.Dsymbol parseStaticDtor(PrefixAttributes!AST* pAttrs)
    {
        AST.Expressions* udas = null;
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();
        nextToken();
        check(TOKthis);
        check(TOKlparen);
        check(TOKrparen);

        stc = parsePostfix(stc & ~AST.STC_TYPECTOR, &udas) | stc;
        if (stc & AST.STCshared)
            error(loc, "use `shared static ~this()` to declare a shared static destructor");
        else if (stc & AST.STCstatic)
            appendStorageClass(stc, AST.STCstatic); // complaint for the redundancy
        else if (StorageClass modStc = stc & AST.STC_TYPECTOR)
        {
            OutBuffer buf;
            AST.stcToBuffer(&buf, modStc);
            error(loc, "static destructor cannot be `%s`", buf.peekString());
        }
        stc &= ~(AST.STCstatic | AST.STC_TYPECTOR);

        auto f = new AST.StaticDtorDeclaration(loc, Loc(), stc);
        AST.Dsymbol s = parseContracts(f);
        if (udas)
        {
            auto a = new AST.Dsymbols();
            a.push(f);
            s = new AST.UserAttributeDeclaration(udas, a);
        }
        return s;
    }

    /*****************************************
     * Parse a shared static constructor definition:
     *      shared static this() { body }
     * Current token is 'shared'.
     */
    AST.Dsymbol parseSharedStaticCtor(PrefixAttributes!AST* pAttrs)
    {
        //Expressions *udas = NULL;
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();
        nextToken();
        nextToken();
        check(TOKlparen);
        check(TOKrparen);

        stc = parsePostfix(stc & ~AST.STC_TYPECTOR, null) | stc;
        if (StorageClass ss = stc & (AST.STCshared | AST.STCstatic))
            appendStorageClass(stc, ss); // complaint for the redundancy
        else if (StorageClass modStc = stc & AST.STC_TYPECTOR)
        {
            OutBuffer buf;
            AST.stcToBuffer(&buf, modStc);
            error(loc, "shared static constructor cannot be `%s`", buf.peekString());
        }
        stc &= ~(AST.STCstatic | AST.STC_TYPECTOR);

        auto f = new AST.SharedStaticCtorDeclaration(loc, Loc(), stc);
        AST.Dsymbol s = parseContracts(f);
        return s;
    }

    /*****************************************
     * Parse a shared static destructor definition:
     *      shared static ~this() { body }
     * Current token is 'shared'.
     */
    AST.Dsymbol parseSharedStaticDtor(PrefixAttributes!AST* pAttrs)
    {
        AST.Expressions* udas = null;
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();
        nextToken();
        nextToken();
        check(TOKthis);
        check(TOKlparen);
        check(TOKrparen);

        stc = parsePostfix(stc & ~AST.STC_TYPECTOR, &udas) | stc;
        if (StorageClass ss = stc & (AST.STCshared | AST.STCstatic))
            appendStorageClass(stc, ss); // complaint for the redundancy
        else if (StorageClass modStc = stc & AST.STC_TYPECTOR)
        {
            OutBuffer buf;
            AST.stcToBuffer(&buf, modStc);
            error(loc, "shared static destructor cannot be `%s`", buf.peekString());
        }
        stc &= ~(AST.STCstatic | AST.STC_TYPECTOR);

        auto f = new AST.SharedStaticDtorDeclaration(loc, Loc(), stc);
        AST.Dsymbol s = parseContracts(f);
        if (udas)
        {
            auto a = new AST.Dsymbols();
            a.push(f);
            s = new AST.UserAttributeDeclaration(udas, a);
        }
        return s;
    }

    /*****************************************
     * Parse an invariant definition:
     *      invariant() { body }
     * Current token is 'invariant'.
     */
    AST.Dsymbol parseInvariant(PrefixAttributes!AST* pAttrs)
    {
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();
        if (token.value == TOKlparen) // optional ()
        {
            nextToken();
            check(TOKrparen);
        }

        auto fbody = parseStatement(PScurly);
        auto f = new AST.InvariantDeclaration(loc, token.loc, stc, null, fbody);
        return f;
    }

    /*****************************************
     * Parse a unittest definition:
     *      unittest { body }
     * Current token is 'unittest'.
     */
    AST.Dsymbol parseUnitTest(PrefixAttributes!AST* pAttrs)
    {
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();

        const(char)* begPtr = token.ptr + 1; // skip '{'
        const(char)* endPtr = null;
        AST.Statement sbody = parseStatement(PScurly, &endPtr);

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

        auto f = new AST.UnitTestDeclaration(loc, token.loc, stc, docline);
        f.fbody = sbody;
        return f;
    }

    /*****************************************
     * Parse a new definition:
     *      new(parameters) { body }
     * Current token is 'new'.
     */
    AST.Dsymbol parseNew(PrefixAttributes!AST* pAttrs)
    {
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();

        int varargs;
        AST.Parameters* parameters = parseParameters(&varargs);
        auto f = new AST.NewDeclaration(loc, Loc(), stc, parameters, varargs);
        AST.Dsymbol s = parseContracts(f);
        return s;
    }

    /*****************************************
     * Parse a delete definition:
     *      delete(parameters) { body }
     * Current token is 'delete'.
     */
    AST.Dsymbol parseDelete(PrefixAttributes!AST* pAttrs)
    {
        const loc = token.loc;
        StorageClass stc = getStorageClass!AST(pAttrs);

        nextToken();

        int varargs;
        AST.Parameters* parameters = parseParameters(&varargs);
        if (varargs)
            error("`...` not allowed in delete function parameter list");
        auto f = new AST.DeleteDeclaration(loc, Loc(), stc, parameters);
        AST.Dsymbol s = parseContracts(f);
        return s;
    }

    /**********************************************
     * Parse parameter list.
     */
    AST.Parameters* parseParameters(int* pvarargs, AST.TemplateParameters** tpl = null)
    {
        auto parameters = new AST.Parameters();
        int varargs = 0;
        int hasdefault = 0;

        check(TOKlparen);
        while (1)
        {
            Identifier ai = null;
            AST.Type at;
            StorageClass storageClass = 0;
            StorageClass stc;
            AST.Expression ae;

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
                    stc = AST.STCconst;
                    goto L2;

                case TOKimmutable:
                    if (peek(&token).value == TOKlparen)
                        goto Ldefault;
                    stc = AST.STCimmutable;
                    goto L2;

                case TOKshared:
                    if (peek(&token).value == TOKlparen)
                        goto Ldefault;
                    stc = AST.STCshared;
                    goto L2;

                case TOKwild:
                    if (peek(&token).value == TOKlparen)
                        goto Ldefault;
                    stc = AST.STCwild;
                    goto L2;

                case TOKin:
                    stc = AST.STCin;
                    goto L2;

                case TOKout:
                    stc = AST.STCout;
                    goto L2;

                case TOKref:
                    stc = AST.STCref;
                    goto L2;

                case TOKlazy:
                    stc = AST.STClazy;
                    goto L2;

                case TOKscope:
                    stc = AST.STCscope;
                    goto L2;

                case TOKfinal:
                    stc = AST.STCfinal;
                    goto L2;

                case TOKauto:
                    stc = AST.STCauto;
                    goto L2;

                case TOKreturn:
                    stc = AST.STCreturn;
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
                                error("default argument expected for `alias %s`", ai ? ai.toChars() : "");
                        }
                        goto L3;
                    }
                default:
                Ldefault:
                    {
                        stc = storageClass & (AST.STCin | AST.STCout | AST.STCref | AST.STClazy);
                        // if stc is not a power of 2
                        if (stc & (stc - 1) && !(stc == (AST.STCin | AST.STCref)))
                            error("incompatible parameter storage classes");
                        //if ((storageClass & STCscope) && (storageClass & (STCref | STCout)))
                            //error("scope cannot be ref or out");

                        if (tpl && token.value == TOKidentifier)
                        {
                            Token* t = peek(&token);
                            if (t.value == TOKcomma || t.value == TOKrparen || t.value == TOKdotdotdot)
                            {
                                Identifier id = Identifier.generateId("__T");
                                const loc = token.loc;
                                at = new AST.TypeIdentifier(loc, id);
                                if (!*tpl)
                                    *tpl = new AST.TemplateParameters();
                                AST.TemplateParameter tp = new AST.TemplateTypeParameter(loc, id, null, null);
                                (*tpl).push(tp);

                                ai = token.ident;
                                nextToken();
                            }
                            else goto _else;
                        }
                        else
                        {
                        _else:
                            at = parseType(&ai);
                        }
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
                                error("default argument expected for `%s`", ai ? ai.toChars() : at.toChars());
                        }
                        if (token.value == TOKdotdotdot)
                        {
                            /* This is:
                             *      at ai ...
                             */
                            if (storageClass & (AST.STCout | AST.STCref))
                                error("variadic argument cannot be `out` or `ref`");
                            varargs = 2;
                            parameters.push(new AST.Parameter(storageClass, at, ai, ae));
                            nextToken();
                            break;
                        }
                        parameters.push(new AST.Parameter(storageClass, at, ai, ae));
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
    AST.EnumDeclaration parseEnum()
    {
        AST.EnumDeclaration e;
        Identifier id;
        AST.Type memtype;
        auto loc = token.loc;

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
            const typeLoc = token.loc;
            memtype = parseBasicType();
            memtype = parseDeclarator(memtype, &alt, null);
            checkCstyleTypeSyntax(typeLoc, memtype, alt, null);
        }
        else
            memtype = null;

        e = new AST.EnumDeclaration(loc, id, memtype);
        if (token.value == TOKsemicolon && id)
            nextToken();
        else if (token.value == TOKlcurly)
        {
            //printf("enum definition\n");
            e.members = new AST.Dsymbols();
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

                AST.Type type = null;
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
                        error("no identifier for declarator `%s`", type.toChars());
                    if (id || memtype)
                        error("type only allowed if anonymous enum and no enum type");
                }

                AST.Expression value;
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

                auto em = new AST.EnumMember(loc, ident, value, type);
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

        //printf("-parseEnum() %s\n", e.toChars());
        return e;
    }

    /********************************
     * Parse struct, union, interface, class.
     */
    AST.Dsymbol parseAggregate()
    {
        AST.TemplateParameters* tpl = null;
        AST.Expression constraint;
        const loc = token.loc;
        TOK tok = token.value;

        //printf("Parser::parseAggregate()\n");
        nextToken();
        Identifier id;
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
                // struct/class template declaration.
                tpl = parseTemplateParameterList();
                constraint = parseConstraint();
            }
        }

        // Collect base class(es)
        AST.BaseClasses* baseclasses = null;
        if (token.value == TOKcolon)
        {
            if (tok != TOKinterface && tok != TOKclass)
                error("base classes are not allowed for `%s`, did you mean `;`?", Token.toChars(tok));
            nextToken();
            baseclasses = parseBaseClasses();
        }

        if (token.value == TOKif)
        {
            if (constraint)
                error("template constraints appear both before and after BaseClassList, put them before");
            constraint = parseConstraint();
        }
        if (constraint)
        {
            if (!id)
                error("template constraints not allowed for anonymous `%s`", Token.toChars(tok));
            if (!tpl)
                error("template constraints only allowed for templates");
        }

        AST.Dsymbols* members = null;
        if (token.value == TOKlcurly)
        {
            //printf("aggregate definition\n");
            const lookingForElseSave = lookingForElse;
            lookingForElse = Loc();
            nextToken();
            members = parseDeclDefs(0);
            lookingForElse = lookingForElseSave;
            if (token.value != TOKrcurly)
            {
                /* { */
                error("`}` expected following members in `%s` declaration at %s",
                    Token.toChars(tok), loc.toChars());
            }
            nextToken();
        }
        else if (token.value == TOKsemicolon && id)
        {
            if (baseclasses || constraint)
                error("members expected");
            nextToken();
        }
        else
        {
            error("{ } expected following `%s` declaration", Token.toChars(tok));
        }

        AST.AggregateDeclaration a;
        switch (tok)
        {
        case TOKinterface:
            if (!id)
                error(loc, "anonymous interfaces not allowed");
            a = new AST.InterfaceDeclaration(loc, id, baseclasses);
            a.members = members;
            break;

        case TOKclass:
            if (!id)
                error(loc, "anonymous classes not allowed");
            bool inObject = md && !md.packages && md.id == Id.object;
            a = new AST.ClassDeclaration(loc, id, baseclasses, members, inObject);
            break;

        case TOKstruct:
            if (id)
            {
                a = new AST.StructDeclaration(loc, id);
                a.members = members;
            }
            else
            {
                /* Anonymous structs/unions are more like attributes.
                 */
                assert(!tpl);
                return new AST.AnonDeclaration(loc, false, members);
            }
            break;

        case TOKunion:
            if (id)
            {
                a = new AST.UnionDeclaration(loc, id);
                a.members = members;
            }
            else
            {
                /* Anonymous structs/unions are more like attributes.
                 */
                assert(!tpl);
                return new AST.AnonDeclaration(loc, true, members);
            }
            break;

        default:
            assert(0);
        }

        if (tpl)
        {
            // Wrap a template around the aggregate declaration
            auto decldefs = new AST.Dsymbols();
            decldefs.push(a);
            auto tempdecl = new AST.TemplateDeclaration(loc, id, tpl, constraint, decldefs);
            return tempdecl;
        }
        return a;
    }

    /*******************************************
     */
    AST.BaseClasses* parseBaseClasses()
    {
        auto baseclasses = new AST.BaseClasses();

        for (; 1; nextToken())
        {
            auto b = new AST.BaseClass(parseBasicType());
            baseclasses.push(b);
            if (token.value != TOKcomma)
                break;
        }
        return baseclasses;
    }

    AST.Dsymbols* parseImport()
    {
        auto decldefs = new AST.Dsymbols();
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

            const loc = token.loc;
            Identifier id = token.ident;
            AST.Identifiers* a = null;
            nextToken();
            if (!aliasid && token.value == TOKassign)
            {
                aliasid = id;
                goto L1;
            }
            while (token.value == TOKdot)
            {
                if (!a)
                    a = new AST.Identifiers();
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

            auto s = new AST.Import(loc, a, id, aliasid, isstatic);
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
                        error("identifier expected following `:`");
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
                            error("identifier expected following `%s=`", _alias.toChars());
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
                break; // no comma-separated imports of this form
            }
            aliasid = null;
        }
        while (token.value == TOKcomma);

        if (token.value == TOKsemicolon)
            nextToken();
        else
        {
            error("`;` expected");
            nextToken();
        }

        return decldefs;
    }

    AST.Type parseType(Identifier* pident = null, AST.TemplateParameters** ptpl = null)
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
                    break; // const as type constructor
                stc |= AST.STCconst; // const as storage class
                nextToken();
                continue;

            case TOKimmutable:
                if (peekNext() == TOKlparen)
                    break;
                stc |= AST.STCimmutable;
                nextToken();
                continue;

            case TOKshared:
                if (peekNext() == TOKlparen)
                    break;
                stc |= AST.STCshared;
                nextToken();
                continue;

            case TOKwild:
                if (peekNext() == TOKlparen)
                    break;
                stc |= AST.STCwild;
                nextToken();
                continue;

            default:
                break;
            }
            break;
        }

        const typeLoc = token.loc;

        AST.Type t;
        t = parseBasicType();

        int alt = 0;
        t = parseDeclarator(t, &alt, pident, ptpl);
        checkCstyleTypeSyntax(typeLoc, t, alt, pident ? *pident : null);

        t = t.addSTC(stc);
        return t;
    }

    AST.Type parseBasicType(bool dontLookDotIdents = false)
    {
        AST.Type t;
        Loc loc;
        Identifier id;
        //printf("parseBasicType()\n");
        switch (token.value)
        {
        case TOKvoid:
            t = AST.Type.tvoid;
            goto LabelX;

        case TOKint8:
            t = AST.Type.tint8;
            goto LabelX;

        case TOKuns8:
            t = AST.Type.tuns8;
            goto LabelX;

        case TOKint16:
            t = AST.Type.tint16;
            goto LabelX;

        case TOKuns16:
            t = AST.Type.tuns16;
            goto LabelX;

        case TOKint32:
            t = AST.Type.tint32;
            goto LabelX;

        case TOKuns32:
            t = AST.Type.tuns32;
            goto LabelX;

        case TOKint64:
            t = AST.Type.tint64;
            goto LabelX;

        case TOKuns64:
            t = AST.Type.tuns64;
            goto LabelX;

        case TOKint128:
            t = AST.Type.tint128;
            goto LabelX;

        case TOKuns128:
            t = AST.Type.tuns128;
            goto LabelX;

        case TOKfloat32:
            t = AST.Type.tfloat32;
            goto LabelX;

        case TOKfloat64:
            t = AST.Type.tfloat64;
            goto LabelX;

        case TOKfloat80:
            t = AST.Type.tfloat80;
            goto LabelX;

        case TOKimaginary32:
            t = AST.Type.timaginary32;
            goto LabelX;

        case TOKimaginary64:
            t = AST.Type.timaginary64;
            goto LabelX;

        case TOKimaginary80:
            t = AST.Type.timaginary80;
            goto LabelX;

        case TOKcomplex32:
            t = AST.Type.tcomplex32;
            goto LabelX;

        case TOKcomplex64:
            t = AST.Type.tcomplex64;
            goto LabelX;

        case TOKcomplex80:
            t = AST.Type.tcomplex80;
            goto LabelX;

        case TOKbool:
            t = AST.Type.tbool;
            goto LabelX;

        case TOKchar:
            t = AST.Type.tchar;
            goto LabelX;

        case TOKwchar:
            t = AST.Type.twchar;
            goto LabelX;

        case TOKdchar:
            t = AST.Type.tdchar;
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
                auto tempinst = new AST.TemplateInstance(loc, id, parseTemplateArguments());
                t = parseBasicTypeStartingAt(new AST.TypeInstance(loc, tempinst), dontLookDotIdents);
            }
            else
            {
                t = parseBasicTypeStartingAt(new AST.TypeIdentifier(loc, id), dontLookDotIdents);
            }
            break;

        case TOKdot:
            // Leading . as in .foo
            t = parseBasicTypeStartingAt(new AST.TypeIdentifier(token.loc, Id.empty), dontLookDotIdents);
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
            t = parseType().addSTC(AST.STCconst);
            check(TOKrparen);
            break;

        case TOKimmutable:
            // immutable(type)
            nextToken();
            check(TOKlparen);
            t = parseType().addSTC(AST.STCimmutable);
            check(TOKrparen);
            break;

        case TOKshared:
            // shared(type)
            nextToken();
            check(TOKlparen);
            t = parseType().addSTC(AST.STCshared);
            check(TOKrparen);
            break;

        case TOKwild:
            // wild(type)
            nextToken();
            check(TOKlparen);
            t = parseType().addSTC(AST.STCwild);
            check(TOKrparen);
            break;

        default:
            error("basic type expected, not `%s`", token.toChars());
            t = AST.Type.terror;
            break;
        }
        return t;
    }

    AST.Type parseBasicTypeStartingAt(AST.TypeQualified tid, bool dontLookDotIdents)
    {
        AST.Type maybeArray = null;
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
                        error("identifier expected following `.` instead of `%s`", token.toChars());
                        break;
                    }
                    if (maybeArray)
                    {
                        // This is actually a TypeTuple index, not an {a/s}array.
                        // We need to have a while loop to unwind all index taking:
                        // T[e1][e2].U   ->  T, addIndex(e1), addIndex(e2)
                        AST.Objects dimStack;
                        AST.Type t = maybeArray;
                        while (true)
                        {
                            if (t.ty == AST.Tsarray)
                            {
                                // The index expression is an Expression.
                                AST.TypeSArray a = cast(AST.TypeSArray)t;
                                dimStack.push(a.dim.syntaxCopy());
                                t = a.next.syntaxCopy();
                            }
                            else if (t.ty == AST.Taarray)
                            {
                                // The index expression is a Type. It will be interpreted as an expression at semantic time.
                                AST.TypeAArray a = cast(AST.TypeAArray)t;
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
                        tid = cast(AST.TypeQualified)t;
                        while (dimStack.dim)
                        {
                            tid.addIndex(dimStack.pop());
                        }
                        maybeArray = null;
                    }
                    const loc = token.loc;
                    Identifier id = token.ident;
                    nextToken();
                    if (token.value == TOKnot)
                    {
                        auto tempinst = new AST.TemplateInstance(loc, id, parseTemplateArguments());
                        tid.addInst(tempinst);
                    }
                    else
                        tid.addIdent(id);
                    continue;
                }
            case TOKlbracket:
                {
                    if (dontLookDotIdents) // workaround for https://issues.dlang.org/show_bug.cgi?id=14911
                        goto Lend;

                    nextToken();
                    AST.Type t = maybeArray ? maybeArray : cast(AST.Type)tid;
                    if (token.value == TOKrbracket)
                    {
                        // It's a dynamic array, and we're done:
                        // T[].U does not make sense.
                        t = new AST.TypeDArray(t);
                        nextToken();
                        return t;
                    }
                    else if (isDeclaration(&token, NeedDeclaratorId.no, TOKrbracket, null))
                    {
                        // This can be one of two things:
                        //  1 - an associative array declaration, T[type]
                        //  2 - an associative array declaration, T[expr]
                        // These  can only be disambiguated later.
                        AST.Type index = parseType(); // [ type ]
                        maybeArray = new AST.TypeAArray(t, index);
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
                        AST.Expression e = parseAssignExp(); // [ expression ]
                        if (token.value == TOKslice)
                        {
                            // It's a slice, and we're done.
                            nextToken();
                            AST.Expression e2 = parseAssignExp(); // [ exp .. exp ]
                            t = new AST.TypeSlice(t, e, e2);
                            inBrackets--;
                            check(TOKrbracket);
                            return t;
                        }
                        else
                        {
                            maybeArray = new AST.TypeSArray(t, e);
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
        return maybeArray ? maybeArray : cast(AST.Type)tid;
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
    AST.Type parseBasicType2(AST.Type t)
    {
        //printf("parseBasicType2()\n");
        while (1)
        {
            switch (token.value)
            {
            case TOKmul:
                t = new AST.TypePointer(t);
                nextToken();
                continue;

            case TOKlbracket:
                // Handle []. Make sure things like
                //     int[3][1] a;
                // is (array[1] of array[3] of int)
                nextToken();
                if (token.value == TOKrbracket)
                {
                    t = new AST.TypeDArray(t); // []
                    nextToken();
                }
                else if (isDeclaration(&token, NeedDeclaratorId.no, TOKrbracket, null))
                {
                    // It's an associative array declaration
                    //printf("it's an associative array\n");
                    AST.Type index = parseType(); // [ type ]
                    t = new AST.TypeAArray(t, index);
                    check(TOKrbracket);
                }
                else
                {
                    //printf("it's type[expression]\n");
                    inBrackets++;
                    AST.Expression e = parseAssignExp(); // [ expression ]
                    if (token.value == TOKslice)
                    {
                        nextToken();
                        AST.Expression e2 = parseAssignExp(); // [ exp .. exp ]
                        t = new AST.TypeSlice(t, e, e2);
                    }
                    else
                    {
                        t = new AST.TypeSArray(t, e);
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
                    AST.Parameters* parameters = parseParameters(&varargs);

                    StorageClass stc = parsePostfix(AST.STCundefined, null);
                    auto tf = new AST.TypeFunction(parameters, t, varargs, linkage, stc);
                    if (stc & (AST.STCconst | AST.STCimmutable | AST.STCshared | AST.STCwild | AST.STCreturn))
                    {
                        if (save == TOKfunction)
                            error("const/immutable/shared/inout/return attributes are only valid for non-static member functions");
                        else
                            tf = cast(AST.TypeFunction)tf.addSTC(stc);
                    }

                    if (save == TOKdelegate)
                        t = new AST.TypeDelegate(tf);
                    else
                        t = new AST.TypePointer(tf); // pointer to function
                    continue;
                }
            default:
                return t;
            }
            assert(0);
        }
        assert(0);
    }

    AST.Type parseDeclarator(AST.Type t, int* palt, Identifier* pident, AST.TemplateParameters** tpl = null, StorageClass storageClass = 0, int* pdisable = null, AST.Expressions** pudas = null)
    {
        //printf("parseDeclarator(tpl = %p)\n", tpl);
        t = parseBasicType2(t);
        AST.Type ts;
        switch (token.value)
        {
        case TOKidentifier:
            if (pident)
                *pident = token.ident;
            else
                error("unexpected identifier `%s` in declarator", token.ident.toChars());
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
                    error("function declaration without return type. (Note that constructors are always named `this`)");
                }
                else
                    error("unexpected `(` in declarator");
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
                        AST.TypeNext ta;
                        nextToken();
                        if (token.value == TOKrbracket)
                        {
                            // It's a dynamic array
                            ta = new AST.TypeDArray(t); // []
                            nextToken();
                            *palt |= 2;
                        }
                        else if (isDeclaration(&token, NeedDeclaratorId.no, TOKrbracket, null))
                        {
                            // It's an associative array
                            //printf("it's an associative array\n");
                            AST.Type index = parseType(); // [ type ]
                            check(TOKrbracket);
                            ta = new AST.TypeAArray(t, index);
                            *palt |= 2;
                        }
                        else
                        {
                            //printf("It's a static array\n");
                            AST.Expression e = parseAssignExp(); // [ expression ]
                            ta = new AST.TypeSArray(t, e);
                            check(TOKrbracket);
                            *palt |= 2;
                        }

                        /* Insert ta into
                         *   ts -> ... -> t
                         * so that
                         *   ts -> ... -> ta -> t
                         */
                        AST.Type* pt;
                        for (pt = &ts; *pt != t; pt = &(cast(AST.TypeNext)*pt).next)
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
                    AST.Parameters* parameters = parseParameters(&varargs);

                    /* Parse const/immutable/shared/inout/nothrow/pure/return postfix
                     */
                    // merge prefix storage classes
                    StorageClass stc = parsePostfix(storageClass, pudas);

                    AST.Type tf = new AST.TypeFunction(parameters, t, varargs, linkage, stc);
                    tf = tf.addSTC(stc);
                    if (pdisable)
                        *pdisable = stc & AST.STCdisable ? 1 : 0;

                    /* Insert tf into
                     *   ts -> ... -> t
                     * so that
                     *   ts -> ... -> tf -> t
                     */
                    AST.Type* pt;
                    for (pt = &ts; *pt != t; pt = &(cast(AST.TypeNext)*pt).next)
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

    void parseStorageClasses(ref StorageClass storage_class, ref LINK link,
        ref bool setAlignment, ref AST.Expression ealign, ref AST.Expressions* udas)
    {
        StorageClass stc;
        bool sawLinkage = false; // seen a linkage declaration

        while (1)
        {
            switch (token.value)
            {
            case TOKconst:
                if (peek(&token).value == TOKlparen)
                    break; // const as type constructor
                stc = AST.STCconst; // const as storage class
                goto L1;

            case TOKimmutable:
                if (peek(&token).value == TOKlparen)
                    break;
                stc = AST.STCimmutable;
                goto L1;

            case TOKshared:
                if (peek(&token).value == TOKlparen)
                    break;
                stc = AST.STCshared;
                goto L1;

            case TOKwild:
                if (peek(&token).value == TOKlparen)
                    break;
                stc = AST.STCwild;
                goto L1;

            case TOKstatic:
                stc = AST.STCstatic;
                goto L1;

            case TOKfinal:
                stc = AST.STCfinal;
                goto L1;

            case TOKauto:
                stc = AST.STCauto;
                goto L1;

            case TOKscope:
                stc = AST.STCscope;
                goto L1;

            case TOKoverride:
                stc = AST.STCoverride;
                goto L1;

            case TOKabstract:
                stc = AST.STCabstract;
                goto L1;

            case TOKsynchronized:
                stc = AST.STCsynchronized;
                goto L1;

            case TOKdeprecated:
                stc = AST.STCdeprecated;
                goto L1;

            case TOKnothrow:
                stc = AST.STCnothrow;
                goto L1;

            case TOKpure:
                stc = AST.STCpure;
                goto L1;

            case TOKref:
                stc = AST.STCref;
                goto L1;

            case TOKgshared:
                stc = AST.STCgshared;
                goto L1;

            case TOKenum:
                stc = AST.STCmanifest;
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
                        stc = AST.STCextern;
                        goto L1;
                    }

                    if (sawLinkage)
                        error("redundant linkage declaration");
                    sawLinkage = true;
                    AST.Identifiers* idents = null;
                    CPPMANGLE cppmangle;
                    link = parseLinkage(&idents, cppmangle);
                    if (idents)
                    {
                        error("C++ name spaces not allowed here");
                    }
                    if (cppmangle != CPPMANGLE.def)
                    {
                        error("C++ mangle declaration not allowed here");
                    }
                    continue;
                }
            case TOKalign:
                {
                    nextToken();
                    setAlignment = true;
                    if (token.value == TOKlparen)
                    {
                        nextToken();
                        ealign = parseExpression();
                        check(TOKrparen);
                    }
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
    AST.Dsymbols* parseDeclarations(bool autodecl, PrefixAttributes!AST* pAttrs, const(char)* comment)
    {
        StorageClass storage_class = AST.STCundefined;
        AST.Type ts;
        AST.Type t;
        AST.Type tfirst;
        Identifier ident;
        TOK tok = TOKreserved;
        LINK link = linkage;
        bool setAlignment = false;
        AST.Expression ealign;
        auto loc = token.loc;
        AST.Expressions* udas = null;
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
                auto s = new AST.AliasThis(loc, token.ident);
                nextToken();
                check(TOKthis);
                check(TOKsemicolon);
                auto a = new AST.Dsymbols();
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
                auto a = new AST.Dsymbols();
                while (1)
                {
                    ident = token.ident;
                    nextToken();
                    AST.TemplateParameters* tpl = null;
                    if (token.value == TOKlparen)
                        tpl = parseTemplateParameterList();
                    check(TOKassign);

                    AST.Declaration v;
                    if (token.value == TOKfunction ||
                        token.value == TOKdelegate ||
                        token.value == TOKlparen &&
                            skipAttributes(peekPastParen(&token), &tk) &&
                            (tk.value == TOKgoesto || tk.value == TOKlcurly) ||
                        token.value == TOKlcurly ||
                        token.value == TOKidentifier && peekNext() == TOKgoesto
                       )
                    {
                        // function (parameters) { statements... }
                        // delegate (parameters) { statements... }
                        // (parameters) { statements... }
                        // (parameters) => expression
                        // { statements... }
                        // identifier => expression

                        AST.Dsymbol s = parseFunctionLiteral();
                        v = new AST.AliasDeclaration(loc, ident, s);
                    }
                    else
                    {
                        // StorageClasses type

                        storage_class = AST.STCundefined;
                        link = linkage;
                        setAlignment = false;
                        ealign = null;
                        udas = null;
                        parseStorageClasses(storage_class, link, setAlignment, ealign, udas);

                        if (udas)
                            error("user defined attributes not allowed for `%s` declarations", Token.toChars(tok));

                        t = parseType();
                        v = new AST.AliasDeclaration(loc, ident, t);
                    }
                    v.storage_class = storage_class;

                    AST.Dsymbol s = v;
                    if (tpl)
                    {
                        auto a2 = new AST.Dsymbols();
                        a2.push(s);
                        auto tempdecl = new AST.TemplateDeclaration(loc, ident, tpl, null, a2);
                        s = tempdecl;
                    }
                    if (link != linkage)
                    {
                        auto a2 = new AST.Dsymbols();
                        a2.push(s);
                        s = new AST.LinkDeclaration(link, a2);
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
                            error("identifier expected following comma, not `%s`", token.toChars());
                            break;
                        }
                        if (peekNext() != TOKassign && peekNext() != TOKlparen)
                        {
                            error("`=` expected following identifier");
                            nextToken();
                            break;
                        }
                        continue;

                    default:
                        error("semicolon expected to close `%s` declaration", Token.toChars(tok));
                        break;
                    }
                    break;
                }
                return a;
            }

            // alias StorageClasses type ident;
        }

        parseStorageClasses(storage_class, link, setAlignment, ealign, udas);

        if (token.value == TOKstruct ||
            token.value == TOKunion ||
            token.value == TOKclass ||
            token.value == TOKinterface)
        {
            AST.Dsymbol s = parseAggregate();
            auto a = new AST.Dsymbols();
            a.push(s);

            if (storage_class)
            {
                s = new AST.StorageClassDeclaration(storage_class, a);
                a = new AST.Dsymbols();
                a.push(s);
            }
            if (setAlignment)
            {
                s = new AST.AlignDeclaration(s.loc, ealign, a);
                a = new AST.Dsymbols();
                a.push(s);
            }
            if (link != linkage)
            {
                s = new AST.LinkDeclaration(link, a);
                a = new AST.Dsymbols();
                a.push(s);
            }
            if (udas)
            {
                s = new AST.UserAttributeDeclaration(udas, a);
                a = new AST.Dsymbols();
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
            AST.Dsymbols* a = parseAutoDeclarations(storage_class, comment);
            if (udas)
            {
                AST.Dsymbol s = new AST.UserAttributeDeclaration(udas, a);
                a = new AST.Dsymbols();
                a.push(s);
            }
            return a;
        }

        /* Look for return type inference for template functions.
         */
        if ((storage_class || udas) && token.value == TOKidentifier && skipParens(peek(&token), &tk) &&
            skipAttributes(tk, &tk) &&
            (tk.value == TOKlparen || tk.value == TOKlcurly || tk.value == TOKin || tk.value == TOKout ||
             tk.value == TOKdo || tk.value == TOKidentifier && tk.ident == Id._body))
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
        auto a = new AST.Dsymbols();

        if (pAttrs)
        {
            storage_class |= pAttrs.storageClass;
            //pAttrs.storageClass = STCundefined;
        }

        while (1)
        {
            AST.TemplateParameters* tpl = null;
            int disable;
            int alt = 0;

            loc = token.loc;
            ident = null;
            t = parseDeclarator(ts, &alt, &ident, &tpl, storage_class, &disable, &udas);
            assert(t);
            if (!tfirst)
                tfirst = t;
            else if (t != tfirst)
                error("multiple declarations must have the same type, not `%s` and `%s`", tfirst.toChars(), t.toChars());

            bool isThis = (t.ty == AST.Tident && (cast(AST.TypeIdentifier)t).ident == Id.This && token.value == TOKassign);
            if (ident)
                checkCstyleTypeSyntax(loc, t, alt, ident);
            else if (!isThis)
                error("no identifier for declarator `%s`", t.toChars());

            if (tok == TOKalias)
            {
                AST.Declaration v;
                AST.Initializer _init = null;

                /* Aliases can no longer have multiple declarators, storage classes,
                 * linkages, or auto declarations.
                 * These never made any sense, anyway.
                 * The code below needs to be fixed to reject them.
                 * The grammar has already been fixed to preclude them.
                 */

                if (udas)
                    error("user defined attributes not allowed for `%s` declarations", Token.toChars(tok));

                if (token.value == TOKassign)
                {
                    nextToken();
                    _init = parseInitializer();
                }
                if (_init)
                {
                    if (isThis)
                        error("cannot use syntax `alias this = %s`, use `alias %s this` instead", _init.toChars(), _init.toChars());
                    else
                        error("alias cannot have initializer");
                }
                v = new AST.AliasDeclaration(loc, ident, t);

                v.storage_class = storage_class;
                if (pAttrs)
                {
                    /* AliasDeclaration distinguish @safe, @system, @trusted attributes
                     * on prefix and postfix.
                     *   @safe alias void function() FP1;
                     *   alias @safe void function() FP2;    // FP2 is not @safe
                     *   alias void function() @safe FP3;
                     */
                    pAttrs.storageClass &= (AST.STCsafe | AST.STCsystem | AST.STCtrusted);
                }
                AST.Dsymbol s = v;

                if (link != linkage)
                {
                    auto ax = new AST.Dsymbols();
                    ax.push(v);
                    s = new AST.LinkDeclaration(link, ax);
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
                    error("semicolon expected to close `%s` declaration", Token.toChars(tok));
                    break;
                }
            }
            else if (t.ty == AST.Tfunction)
            {
                AST.Expression constraint = null;
                version (none)
                {
                    TypeFunction tf = cast(TypeFunction)t;
                    if (Parameter.isTPL(tf.parameters))
                    {
                        if (!tpl)
                            tpl = new TemplateParameters();
                    }
                }

                //printf("%s funcdecl t = %s, storage_class = x%lx\n", loc.toChars(), t.toChars(), storage_class);
                auto f = new AST.FuncDeclaration(loc, Loc(), ident, storage_class | (disable ? AST.STCdisable : 0), t);
                if (pAttrs)
                    pAttrs.storageClass = AST.STCundefined;
                if (tpl)
                    constraint = parseConstraint();
                AST.Dsymbol s = parseContracts(f);
                auto tplIdent = s.ident;

                if (link != linkage)
                {
                    auto ax = new AST.Dsymbols();
                    ax.push(s);
                    s = new AST.LinkDeclaration(link, ax);
                }
                if (udas)
                {
                    auto ax = new AST.Dsymbols();
                    ax.push(s);
                    s = new AST.UserAttributeDeclaration(udas, ax);
                }

                /* A template parameter list means it's a function template
                 */
                if (tpl)
                {
                    // Wrap a template around the function declaration
                    auto decldefs = new AST.Dsymbols();
                    decldefs.push(s);
                    auto tempdecl = new AST.TemplateDeclaration(loc, tplIdent, tpl, constraint, decldefs);
                    s = tempdecl;

                    if (storage_class & AST.STCstatic)
                    {
                        assert(f.storage_class & AST.STCstatic);
                        f.storage_class &= ~AST.STCstatic;
                        auto ax = new AST.Dsymbols();
                        ax.push(s);
                        s = new AST.StorageClassDeclaration(AST.STCstatic, ax);
                    }
                }
                a.push(s);
                addComment(s, comment);
            }
            else if (ident)
            {
                AST.Initializer _init = null;
                if (token.value == TOKassign)
                {
                    nextToken();
                    _init = parseInitializer();
                }

                auto v = new AST.VarDeclaration(loc, t, ident, _init);
                v.storage_class = storage_class;
                if (pAttrs)
                    pAttrs.storageClass = AST.STCundefined;

                AST.Dsymbol s = v;

                if (tpl && _init)
                {
                    auto a2 = new AST.Dsymbols();
                    a2.push(s);
                    auto tempdecl = new AST.TemplateDeclaration(loc, ident, tpl, null, a2, 0);
                    s = tempdecl;
                }
                if (setAlignment)
                {
                    auto ax = new AST.Dsymbols();
                    ax.push(s);
                    s = new AST.AlignDeclaration(v.loc, ealign, ax);
                }
                if (link != linkage)
                {
                    auto ax = new AST.Dsymbols();
                    ax.push(s);
                    s = new AST.LinkDeclaration(link, ax);
                }
                if (udas)
                {
                    auto ax = new AST.Dsymbols();
                    ax.push(s);
                    s = new AST.UserAttributeDeclaration(udas, ax);
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
                    error("semicolon expected, not `%s`", token.toChars());
                    break;
                }
            }
            break;
        }
        return a;
    }

    AST.Dsymbol parseFunctionLiteral()
    {
        const loc = token.loc;
        AST.TemplateParameters* tpl = null;
        AST.Parameters* parameters = null;
        int varargs = 0;
        AST.Type tret = null;
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
            goto case TOKlparen;

        case TOKlparen:
            {
                // (parameters) => expression
                // (parameters) { statements... }
                parameters = parseParameters(&varargs, &tpl);
                stc = parsePostfix(AST.STCundefined, null);
                if (StorageClass modStc = stc & AST.STC_TYPECTOR)
                {
                    if (save == TOKfunction)
                    {
                        OutBuffer buf;
                        AST.stcToBuffer(&buf, modStc);
                        error("function literal cannot be `%s`", buf.peekString());
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
                parameters = new AST.Parameters();
                Identifier id = Identifier.generateId("__T");
                AST.Type t = new AST.TypeIdentifier(loc, id);
                parameters.push(new AST.Parameter(0, t, token.ident, null));

                tpl = new AST.TemplateParameters();
                AST.TemplateParameter tp = new AST.TemplateTypeParameter(loc, id, null, null);
                tpl.push(tp);

                nextToken();
                break;
            }
        default:
            assert(0);
        }

        if (!parameters)
            parameters = new AST.Parameters();
        auto tf = new AST.TypeFunction(parameters, tret, varargs, linkage, stc);
        tf = cast(AST.TypeFunction)tf.addSTC(stc);
        auto fd = new AST.FuncLiteralDeclaration(loc, Loc(), tf, save, null);

        if (token.value == TOKgoesto)
        {
            check(TOKgoesto);
            const returnloc = token.loc;
            AST.Expression ae = parseAssignExp();
            fd.fbody = new AST.ReturnStatement(returnloc, ae);
            fd.endloc = token.loc;
        }
        else
        {
            parseContracts(fd);
        }

        if (tpl)
        {
            // Wrap a template around function fd
            auto decldefs = new AST.Dsymbols();
            decldefs.push(fd);
            return new AST.TemplateDeclaration(fd.loc, fd.ident, tpl, null, decldefs, false, true);
        }
        else
            return fd;
    }

    /*****************************************
     * Parse contracts following function declaration.
     */
    AST.FuncDeclaration parseContracts(AST.FuncDeclaration f)
    {
        LINK linksave = linkage;

        bool literal = f.isFuncLiteralDeclaration() !is null;

        // The following is irrelevant, as it is overridden by sc.linkage in
        // TypeFunction::semantic
        linkage = LINKd; // nested functions have D linkage
    L1:
        switch (token.value)
        {
        case TOKlcurly:
            if (f.frequire || f.fensure)
                error("missing `body { ... }` after `in` or `out`");
            f.fbody = parseStatement(PSsemi);
            f.endloc = endloc;
            break;

        case TOKidentifier:
            if (token.ident == Id._body)
                goto case TOKdo;
            goto default;

        case TOKdo:
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
                error("redundant `in` statement");
            f.frequire = parseStatement(PScurly | PSscope);
            goto L1;

        case TOKout:
            // parse: out (identifier) { statement }
            nextToken();
            if (token.value != TOKlcurly)
            {
                check(TOKlparen);
                if (token.value != TOKidentifier)
                    error("`(identifier)` following `out` expected, not `%s`", token.toChars());
                f.outId = token.ident;
                nextToken();
                check(TOKrparen);
            }
            if (f.fensure)
                error("redundant `out` statement");
            f.fensure = parseStatement(PScurly | PSscope);
            goto L1;

        case TOKsemicolon:
            if (!literal)
            {
                // https://issues.dlang.org/show_bug.cgi?id=15799
                // Semicolon becomes a part of function declaration
                // only when neither of contracts exists.
                if (!f.frequire && !f.fensure)
                    nextToken();
                break;
            }
            goto default;

        default:
            if (literal)
            {
                const(char)* sbody = (f.frequire || f.fensure) ? "body " : "";
                error("missing `%s{ ... }` for function literal", sbody);
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
            f.fbody = new AST.CompoundStatement(Loc(), cast(AST.Statement)null);
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

    void checkCstyleTypeSyntax(Loc loc, AST.Type t, int alt, Identifier ident)
    {
        if (!alt)
            return;

        const(char)* sp = !ident ? "" : " ";
        const(char)* s = !ident ? "" : ident.toChars();
        if (alt & 1) // contains C-style function pointer syntax
            error(loc, "instead of C-style syntax, use D-style `%s%s%s`", t.toChars(), sp, s);
        else
           ddmd.errors.deprecation(loc, "instead of C-style syntax, use D-style syntax `%s%s%s`", t.toChars(), sp, s);
    }

    /*****************************************
     * Determines additional argument types for parseForeach.
     */
    private template ParseForeachArgs(bool isStatic, bool isDecl)
    {
        static alias Seq(T...) = T;
        static if(isDecl)
        {
            alias ParseForeachArgs = Seq!(AST.Dsymbol*);
        }
        else
        {
            alias ParseForeachArgs = Seq!();
        }
    }
    /*****************************************
     * Determines the result type for parseForeach.
     */
    private template ParseForeachRet(bool isStatic, bool isDecl)
    {
        static if(!isStatic)
        {
            alias ParseForeachRet = AST.Statement;
        }
        else static if(isDecl)
        {
            alias ParseForeachRet = AST.StaticForeachDeclaration;
        }
        else
        {
            alias ParseForeachRet = AST.StaticForeachStatement;
        }
    }
    /*****************************************
     * Parses `foreach` statements, `static foreach` statements and
     * `static foreach` declarations.  The template parameter
     * `isStatic` is true, iff a `static foreach` should be parsed.
     * If `isStatic` is true, `isDecl` can be true to indicate that a
     * `static foreach` declaration should be parsed.
     */
    ParseForeachRet!(isStatic, isDecl) parseForeach(bool isStatic, bool isDecl)(Loc loc, ParseForeachArgs!(isStatic, isDecl) args)
    {
        static if(isDecl)
        {
            static assert(isStatic);
        }
        static if(isStatic)
        {
            nextToken();
            static if(isDecl) auto pLastDecl = args[0];
        }

        TOK op = token.value;

        nextToken();
        check(TOKlparen);

        auto parameters = new AST.Parameters();
        while (1)
        {
            Identifier ai = null;
            AST.Type at;

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
                    stc = AST.STCref;
                    goto Lagain;

                case TOKenum:
                    stc = AST.STCmanifest;
                    goto Lagain;

                case TOKalias:
                    storageClass = appendStorageClass(storageClass, AST.STCalias);
                    nextToken();
                    break;

                case TOKconst:
                    if (peekNext() != TOKlparen)
                    {
                        stc = AST.STCconst;
                        goto Lagain;
                    }
                    break;

                case TOKimmutable:
                    if (peekNext() != TOKlparen)
                    {
                        stc = AST.STCimmutable;
                        goto Lagain;
                    }
                    break;

                case TOKshared:
                    if (peekNext() != TOKlparen)
                    {
                        stc = AST.STCshared;
                        goto Lagain;
                    }
                    break;

                case TOKwild:
                    if (peekNext() != TOKlparen)
                    {
                        stc = AST.STCwild;
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
                error("no identifier for declarator `%s`", at.toChars());
        Larg:
            auto p = new AST.Parameter(storageClass, at, ai, null);
            parameters.push(p);
            if (token.value == TOKcomma)
            {
                nextToken();
                continue;
            }
            break;
        }
        check(TOKsemicolon);

        AST.Expression aggr = parseExpression();
        static if(isStatic)
        {
            bool isRange = false;
        }
        if (token.value == TOKslice && parameters.dim == 1)
        {
            AST.Parameter p = (*parameters)[0];
            nextToken();
            AST.Expression upr = parseExpression();
            check(TOKrparen);
            Loc endloc;
            static if (!isDecl)
            {
                AST.Statement _body = parseStatement(0, null, &endloc);
            }
            else
            {
                AST.Statement _body = null;
            }
            auto rangefe = new AST.ForeachRangeStatement(loc, op, p, aggr, upr, _body, endloc);
            static if (!isStatic)
            {
                return rangefe;
            }
            else static if(isDecl)
            {
                return new AST.StaticForeachDeclaration(new AST.StaticForeach(loc, null, rangefe), parseBlock(pLastDecl));
            }
            else
            {
                return new AST.StaticForeachStatement(loc, new AST.StaticForeach(loc, null, rangefe));
            }
        }
        else
        {
            check(TOKrparen);
            Loc endloc;
            static if (!isDecl)
            {
                AST.Statement _body = parseStatement(0, null, &endloc);
            }
            else
            {
                AST.Statement _body = null;
            }
            auto aggrfe = new AST.ForeachStatement(loc, op, parameters, aggr, _body, endloc);
            static if(!isStatic)
            {
                return aggrfe;
            }
            else static if(isDecl)
            {
                return new AST.StaticForeachDeclaration(new AST.StaticForeach(loc, aggrfe, null), parseBlock(pLastDecl));
            }
            else
            {
                return new AST.StaticForeachStatement(loc, new AST.StaticForeach(loc, aggrfe, null));
            }
        }

    }

    /*****************************************
     * Input:
     *      flags   PSxxxx
     * Output:
     *      pEndloc if { ... statements ... }, store location of closing brace, otherwise loc of first token of next statement
     */
    AST.Statement parseStatement(int flags, const(char)** endPtr = null, Loc* pEndloc = null)
    {
        AST.Statement s;
        AST.Condition cond;
        AST.Statement ifbody;
        AST.Statement elsebody;
        bool isfinal;
        const loc = token.loc;

        //printf("parseStatement()\n");
        if (flags & PScurly && token.value != TOKlcurly)
            error("statement expected to be `{ }`, not `%s`", token.toChars());

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
                        error("use `.` for member lookup, not `::`");
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
                    s = new AST.LabelStatement(loc, ident, s);
                    break;
                }
                goto case TOKdot;
            }
        case TOKdot:
        case TOKtypeof:
        case TOKvector:
            /* https://issues.dlang.org/show_bug.cgi?id=15163
             * If tokens can be handled as
             * old C-style declaration or D expression, prefer the latter.
             */
            if (isDeclaration(&token, NeedDeclaratorId.mustIfDstyle, TOKreserved, null))
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
        case TOKfilefullpath:
        case TOKline:
        case TOKmodulestring:
        case TOKfuncstring:
        case TOKprettyfunc:
        Lexp:
            {
                AST.Expression exp = parseExpression();
                check(TOKsemicolon, "statement");
                s = new AST.ExpStatement(loc, exp);
                break;
            }
        case TOKstatic:
            {
                // Look ahead to see if it's static assert() or static if()
                Token* t = peek(&token);
                if (t.value == TOKassert)
                {
                    s = new AST.StaticAssertStatement(parseStaticAssert());
                    break;
                }
                if (t.value == TOKif)
                {
                    cond = parseStaticIfCondition();
                    goto Lcondition;
                }
                else if(t.value == TOKforeach || t.value == TOKforeach_reverse)
                {
                    s = parseForeach!(true,false)(loc);
                    break;
                }
                if (t.value == TOKimport)
                {
                    AST.Dsymbols* imports = parseImport();
                    s = new AST.ImportStatement(loc, imports);
                    if (flags & PSscope)
                        s = new AST.ScopeStatement(loc, s, token.loc);
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
            goto case;

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
                AST.Dsymbols* a = parseDeclarations(false, null, null);
                if (a.dim > 1)
                {
                    auto as = new AST.Statements();
                    as.reserve(a.dim);
                    foreach (i; 0 .. a.dim)
                    {
                        AST.Dsymbol d = (*a)[i];
                        s = new AST.ExpStatement(loc, d);
                        as.push(s);
                    }
                    s = new AST.CompoundDeclarationStatement(loc, as);
                }
                else if (a.dim == 1)
                {
                    AST.Dsymbol d = (*a)[0];
                    s = new AST.ExpStatement(loc, d);
                }
                else
                    s = new AST.ExpStatement(loc, cast(AST.Expression)null);
                if (flags & PSscope)
                    s = new AST.ScopeStatement(loc, s, token.loc);
                break;
            }
        case TOKenum:
            {
                /* Determine if this is a manifest constant declaration,
                 * or a conventional enum.
                 */
                AST.Dsymbol d;
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
                s = new AST.ExpStatement(loc, d);
                if (flags & PSscope)
                    s = new AST.ScopeStatement(loc, s, token.loc);
                break;
            }
        case TOKmixin:
            {
                Token* t = peek(&token);
                if (t.value == TOKlparen)
                {
                    // mixin(string)
                    AST.Expression e = parseAssignExp();
                    check(TOKsemicolon);
                    if (e.op == TOKmixin)
                    {
                        AST.CompileExp cpe = cast(AST.CompileExp)e;
                        s = new AST.CompileStatement(loc, cpe.e1);
                    }
                    else
                    {
                        s = new AST.ExpStatement(loc, e);
                    }
                    break;
                }
                AST.Dsymbol d = parseMixin();
                s = new AST.ExpStatement(loc, d);
                if (flags & PSscope)
                    s = new AST.ScopeStatement(loc, s, token.loc);
                break;
            }
        case TOKlcurly:
            {
                const lookingForElseSave = lookingForElse;
                lookingForElse = Loc();

                nextToken();
                //if (token.value == TOKsemicolon)
                //    error("use `{ }` for an empty statement, not `;`");
                auto statements = new AST.Statements();
                while (token.value != TOKrcurly && token.value != TOKeof)
                {
                    statements.push(parseStatement(PSsemi | PScurlyscope));
                }
                if (endPtr)
                    *endPtr = token.ptr;
                endloc = token.loc;
                if (pEndloc)
                {
                    *pEndloc = token.loc;
                    pEndloc = null; // don't set it again
                }
                s = new AST.CompoundStatement(loc, statements);
                if (flags & (PSscope | PScurlyscope))
                    s = new AST.ScopeStatement(loc, s, token.loc);
                check(TOKrcurly, "compound statement");
                lookingForElse = lookingForElseSave;
                break;
            }
        case TOKwhile:
            {
                nextToken();
                check(TOKlparen);
                AST.Expression condition = parseExpression();
                check(TOKrparen);
                Loc endloc;
                AST.Statement _body = parseStatement(PSscope, null, &endloc);
                s = new AST.WhileStatement(loc, condition, _body, endloc);
                break;
            }
        case TOKsemicolon:
            if (!(flags & PSsemi_ok))
            {
                if (flags & PSsemi)
                    deprecation("use `{ }` for an empty statement, not `;`");
                else
                    error("use `{ }` for an empty statement, not `;`");
            }
            nextToken();
            s = new AST.ExpStatement(loc, cast(AST.Expression)null);
            break;

        case TOKdo:
            {
                AST.Statement _body;
                AST.Expression condition;

                nextToken();
                const lookingForElseSave = lookingForElse;
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
                    error("terminating `;` required after do-while statement");
                s = new AST.DoStatement(loc, _body, condition, token.loc);
                break;
            }
        case TOKfor:
            {
                AST.Statement _init;
                AST.Expression condition;
                AST.Expression increment;

                nextToken();
                check(TOKlparen);
                if (token.value == TOKsemicolon)
                {
                    _init = null;
                    nextToken();
                }
                else
                {
                    const lookingForElseSave = lookingForElse;
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
                AST.Statement _body = parseStatement(PSscope, null, &endloc);
                s = new AST.ForStatement(loc, _init, condition, increment, _body, endloc);
                break;
            }
        case TOKforeach:
        case TOKforeach_reverse:
            {
                s = parseForeach!(false,false)(loc);
                break;
            }
        case TOKif:
            {
                AST.Parameter param = null;
                AST.Expression condition;

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
                    stc = AST.STCref;
                    goto LagainStc;

                case TOKauto:
                    stc = AST.STCauto;
                    goto LagainStc;

                case TOKconst:
                    if (peekNext() != TOKlparen)
                    {
                        stc = AST.STCconst;
                        goto LagainStc;
                    }
                    break;

                case TOKimmutable:
                    if (peekNext() != TOKlparen)
                    {
                        stc = AST.STCimmutable;
                        goto LagainStc;
                    }
                    break;

                case TOKshared:
                    if (peekNext() != TOKlparen)
                    {
                        stc = AST.STCshared;
                        goto LagainStc;
                    }
                    break;

                case TOKwild:
                    if (peekNext() != TOKlparen)
                    {
                        stc = AST.STCwild;
                        goto LagainStc;
                    }
                    break;

                default:
                    break;
                }
                if (storageClass != 0 && token.value == TOKidentifier && peek(&token).value == TOKassign)
                {
                    Identifier ai = token.ident;
                    AST.Type at = null; // infer parameter type
                    nextToken();
                    check(TOKassign);
                    param = new AST.Parameter(storageClass, at, ai, null);
                }
                else if (isDeclaration(&token, NeedDeclaratorId.must, TOKassign, null))
                {
                    Identifier ai;
                    AST.Type at = parseType(&ai);
                    check(TOKassign);
                    param = new AST.Parameter(storageClass, at, ai, null);
                }

                condition = parseExpression();
                check(TOKrparen);
                {
                    const lookingForElseSave = lookingForElse;
                    lookingForElse = loc;
                    ifbody = parseStatement(PSscope);
                    lookingForElse = lookingForElseSave;
                }
                if (token.value == TOKelse)
                {
                    const elseloc = token.loc;
                    nextToken();
                    elsebody = parseStatement(PSscope);
                    checkDanglingElse(elseloc);
                }
                else
                    elsebody = null;
                if (condition && ifbody)
                    s = new AST.IfStatement(loc, param, condition, ifbody, elsebody, token.loc);
                else
                    s = null; // don't propagate parsing errors
                break;
            }
        case TOKscope:
            if (peek(&token).value != TOKlparen)
                goto Ldeclaration; // scope used as storage class
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
                    error("valid scope identifiers are `exit`, `failure`, or `success`, not `%s`", id.toChars());
                nextToken();
                check(TOKrparen);
                AST.Statement st = parseStatement(PSscope);
                s = new AST.OnScopeStatement(loc, t, st);
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
                const lookingForElseSave = lookingForElse;
                lookingForElse = loc;
                ifbody = parseStatement(0);
                lookingForElse = lookingForElseSave;
            }
            elsebody = null;
            if (token.value == TOKelse)
            {
                const elseloc = token.loc;
                nextToken();
                elsebody = parseStatement(0);
                checkDanglingElse(elseloc);
            }
            s = new AST.ConditionalStatement(loc, cond, ifbody, elsebody);
            if (flags & PSscope)
                s = new AST.ScopeStatement(loc, s, token.loc);
            break;

        case TOKpragma:
            {
                Identifier ident;
                AST.Expressions* args = null;
                AST.Statement _body;

                nextToken();
                check(TOKlparen);
                if (token.value != TOKidentifier)
                {
                    error("`pragma(identifier)` expected");
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
                s = new AST.PragmaStatement(loc, ident, args, _body);
                break;
            }
        case TOKswitch:
            isfinal = false;
            goto Lswitch;

        Lswitch:
            {
                nextToken();
                check(TOKlparen);
                AST.Expression condition = parseExpression();
                check(TOKrparen);
                AST.Statement _body = parseStatement(PSscope);
                s = new AST.SwitchStatement(loc, condition, _body, isfinal);
                break;
            }
        case TOKcase:
            {
                AST.Expression exp;
                AST.Expressions cases; // array of Expression's
                AST.Expression last = null;

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
                    auto statements = new AST.Statements();
                    while (token.value != TOKcase && token.value != TOKdefault && token.value != TOKeof && token.value != TOKrcurly)
                    {
                        statements.push(parseStatement(PSsemi | PScurlyscope));
                    }
                    s = new AST.CompoundStatement(loc, statements);
                }
                else
                    s = parseStatement(PSsemi | PScurlyscope);
                s = new AST.ScopeStatement(loc, s, token.loc);

                if (last)
                {
                    s = new AST.CaseRangeStatement(loc, exp, last, s);
                }
                else
                {
                    // Keep cases in order by building the case statements backwards
                    for (size_t i = cases.dim; i; i--)
                    {
                        exp = cases[i - 1];
                        s = new AST.CaseStatement(loc, exp, s);
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
                    auto statements = new AST.Statements();
                    while (token.value != TOKcase && token.value != TOKdefault && token.value != TOKeof && token.value != TOKrcurly)
                    {
                        statements.push(parseStatement(PSsemi | PScurlyscope));
                    }
                    s = new AST.CompoundStatement(loc, statements);
                }
                else
                    s = parseStatement(PSsemi | PScurlyscope);
                s = new AST.ScopeStatement(loc, s, token.loc);
                s = new AST.DefaultStatement(loc, s);
                break;
            }
        case TOKreturn:
            {
                AST.Expression exp;
                nextToken();
                if (token.value == TOKsemicolon)
                    exp = null;
                else
                    exp = parseExpression();
                check(TOKsemicolon, "return statement");
                s = new AST.ReturnStatement(loc, exp);
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
                s = new AST.BreakStatement(loc, ident);
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
                s = new AST.ContinueStatement(loc, ident);
                break;
            }
        case TOKgoto:
            {
                Identifier ident;
                nextToken();
                if (token.value == TOKdefault)
                {
                    nextToken();
                    s = new AST.GotoDefaultStatement(loc);
                }
                else if (token.value == TOKcase)
                {
                    AST.Expression exp = null;
                    nextToken();
                    if (token.value != TOKsemicolon)
                        exp = parseExpression();
                    s = new AST.GotoCaseStatement(loc, exp);
                }
                else
                {
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected following `goto`");
                        ident = null;
                    }
                    else
                    {
                        ident = token.ident;
                        nextToken();
                    }
                    s = new AST.GotoStatement(loc, ident);
                }
                check(TOKsemicolon, "goto statement");
                break;
            }
        case TOKsynchronized:
            {
                AST.Expression exp;
                AST.Statement _body;

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
                s = new AST.SynchronizedStatement(loc, exp, _body);
                break;
            }
        case TOKwith:
            {
                AST.Expression exp;
                AST.Statement _body;
                Loc endloc = loc;

                nextToken();
                check(TOKlparen);
                exp = parseExpression();
                check(TOKrparen);
                _body = parseStatement(PSscope, null, &endloc);
                s = new AST.WithStatement(loc, exp, _body, endloc);
                break;
            }
        case TOKtry:
            {
                AST.Statement _body;
                AST.Catches* catches = null;
                AST.Statement finalbody = null;

                nextToken();
                const lookingForElseSave = lookingForElse;
                lookingForElse = Loc();
                _body = parseStatement(PSscope);
                lookingForElse = lookingForElseSave;
                while (token.value == TOKcatch)
                {
                    AST.Statement handler;
                    AST.Catch c;
                    AST.Type t;
                    Identifier id;
                    const catchloc = token.loc;

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
                    c = new AST.Catch(catchloc, t, id, handler);
                    if (!catches)
                        catches = new AST.Catches();
                    catches.push(c);
                }

                if (token.value == TOKfinally)
                {
                    nextToken();
                    finalbody = parseStatement(0);
                }

                s = _body;
                if (!catches && !finalbody)
                    error("`catch` or `finally` expected following `try`");
                else
                {
                    if (catches)
                        s = new AST.TryCatchStatement(loc, _body, catches);
                    if (finalbody)
                        s = new AST.TryFinallyStatement(loc, s, finalbody);
                }
                break;
            }
        case TOKthrow:
            {
                AST.Expression exp;
                nextToken();
                exp = parseExpression();
                check(TOKsemicolon, "throw statement");
                s = new AST.ThrowStatement(loc, exp);
                break;
            }

        case TOKasm:
            {
                // Parse the asm block into a sequence of AsmStatements,
                // each AsmStatement is one instruction.
                // Separate out labels.
                // Defer parsing of AsmStatements until semantic processing.

                Loc labelloc;

                nextToken();
                StorageClass stc = parsePostfix(AST.STCundefined, null);
                if (stc & (AST.STCconst | AST.STCimmutable | AST.STCshared | AST.STCwild))
                    error("const/immutable/shared/inout attributes are not allowed on `asm` blocks");

                check(TOKlcurly);
                Token* toklist = null;
                Token** ptoklist = &toklist;
                Identifier label = null;
                auto statements = new AST.Statements();
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
                            error("`asm` statements must end in `;`");
                        }
                        break;

                    case TOKsemicolon:
                        if (nestlevel != 0)
                            error("mismatched number of curly brackets");

                        s = null;
                        if (toklist || label)
                        {
                            // Create AsmStatement from list of tokens we've saved
                            s = new AST.AsmStatement(token.loc, toklist);
                            toklist = null;
                            ptoklist = &toklist;
                            if (label)
                            {
                                s = new AST.LabelStatement(labelloc, label, s);
                                label = null;
                            }
                            statements.push(s);
                        }
                        nextToken();
                        continue;

                    case TOKeof:
                        /* { */
                        error("matching `}` expected, not end of file");
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
                s = new AST.CompoundAsmStatement(loc, statements, stc);
                nextToken();
                break;
            }
        case TOKimport:
            {
                AST.Dsymbols* imports = parseImport();
                s = new AST.ImportStatement(loc, imports);
                if (flags & PSscope)
                    s = new AST.ScopeStatement(loc, s, token.loc);
                break;
            }
        case TOKtemplate:
            {
                AST.Dsymbol d = parseTemplateDeclaration();
                s = new AST.ExpStatement(loc, d);
                break;
            }
        default:
            error("found `%s` instead of statement", token.toChars());
            goto Lerror;

        Lerror:
            while (token.value != TOKrcurly && token.value != TOKsemicolon && token.value != TOKeof)
                nextToken();
            if (token.value == TOKsemicolon)
                nextToken();
            s = null;
            break;
        }
        if (pEndloc)
            *pEndloc = token.loc;
        return s;
    }

    /*****************************************
     * Parse initializer for variable declaration.
     */
    AST.Initializer parseInitializer()
    {
        AST.StructInitializer _is;
        AST.ArrayInitializer ia;
        AST.ExpInitializer ie;
        AST.Expression e;
        Identifier id;
        AST.Initializer value;
        int comma;
        const loc = token.loc;
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

            _is = new AST.StructInitializer(loc);
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
                        error("expression expected, not `,`");
                    nextToken();
                    comma = 2;
                    continue;

                case TOKrcurly: // allow trailing comma's
                    nextToken();
                    break;

                case TOKeof:
                    error("found end of file instead of initializer");
                    break;

                default:
                    if (comma == 1)
                        error("comma expected separating field initializers");
                    value = parseInitializer();
                    _is.addInit(null, value);
                    comma = 1;
                    continue;
                    //error("found `%s` instead of field initializer", token.toChars());
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

            ia = new AST.ArrayInitializer(loc);
            nextToken();
            comma = 2;
            while (1)
            {
                switch (token.value)
                {
                default:
                    if (comma == 1)
                    {
                        error("comma expected separating array initializers, not `%s`", token.toChars());
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
                        value = new AST.ExpInitializer(e.loc, e);
                        e = null;
                    }
                    ia.addInit(e, value);
                    comma = 1;
                    continue;

                case TOKlcurly:
                case TOKlbracket:
                    if (comma == 1)
                        error("comma expected separating array initializers, not `%s`", token.toChars());
                    value = parseInitializer();
                    if (token.value == TOKcolon)
                    {
                        nextToken();
                        e = AST.initializerToExpression(value);
                        value = parseInitializer();
                    }
                    else
                        e = null;
                    ia.addInit(e, value);
                    comma = 1;
                    continue;

                case TOKcomma:
                    if (comma == 2)
                        error("expression expected, not `,`");
                    nextToken();
                    comma = 2;
                    continue;

                case TOKrbracket: // allow trailing comma's
                    nextToken();
                    break;

                case TOKeof:
                    error("found `%s` instead of array initializer", token.toChars());
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
                return new AST.VoidInitializer(loc);
            }
            goto Lexpression;

        default:
        Lexpression:
            e = parseAssignExp();
            ie = new AST.ExpInitializer(loc, e);
            return ie;
        }
    }

    /*****************************************
     * Parses default argument initializer expression that is an assign expression,
     * with special handling for __FILE__, __FILE_DIR__, __LINE__, __MODULE__, __FUNCTION__, and __PRETTY_FUNCTION__.
     */
    AST.Expression parseDefaultInitExp()
    {
        if (token.value == TOKfile || token.value == TOKfilefullpath || token.value == TOKline
            || token.value == TOKmodulestring || token.value == TOKfuncstring || token.value == TOKprettyfunc)
        {
            Token* t = peek(&token);
            if (t.value == TOKcomma || t.value == TOKrparen)
            {
                AST.Expression e = null;
                if (token.value == TOKfile)
                    e = new AST.FileInitExp(token.loc, TOKfile);
                else if (token.value == TOKfilefullpath)
                    e = new AST.FileInitExp(token.loc, TOKfilefullpath);
                else if (token.value == TOKline)
                    e = new AST.LineInitExp(token.loc);
                else if (token.value == TOKmodulestring)
                    e = new AST.ModuleInitExp(token.loc);
                else if (token.value == TOKfuncstring)
                    e = new AST.FuncInitExp(token.loc);
                else if (token.value == TOKprettyfunc)
                    e = new AST.PrettyFuncInitExp(token.loc);
                else
                    assert(0);
                nextToken();
                return e;
            }
        }
        AST.Expression e = parseAssignExp();
        return e;
    }

    void check(Loc loc, TOK value)
    {
        if (token.value != value)
            error(loc, "found `%s` when expecting `%s`", token.toChars(), Token.toChars(value));
        nextToken();
    }

    void check(TOK value)
    {
        check(token.loc, value);
    }

    void check(TOK value, const(char)* string)
    {
        if (token.value != value)
            error("found `%s` when expecting `%s` following %s", token.toChars(), Token.toChars(value), string);
        nextToken();
    }

    void checkParens(TOK value, AST.Expression e)
    {
        if (precedence[e.op] == PREC.rel && !e.parens)
            error(e.loc, "`%s` must be parenthesized when next to operator `%s`", e.toChars(), Token.toChars(value));
    }

    enum NeedDeclaratorId
    {
        no,             // Declarator part must have no identifier
        opt,            // Declarator part identifier is optional
        must,           // Declarator part must have identifier
        mustIfDstyle,   // Declarator part must have identifier, but don't recognize old C-style syntax
    }

    /************************************
     * Determine if the scanner is sitting on the start of a declaration.
     * Params:
     *      needId
     * Output:
     *      if *pt is not NULL, it is set to the ending token, which would be endtok
     */
    bool isDeclaration(Token* t, NeedDeclaratorId needId, TOK endtok, Token** pt)
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
        if (!isDeclarator(&t, &haveId, &haveTpl, endtok, needId != NeedDeclaratorId.mustIfDstyle))
            goto Lisnot;
        if ((needId == NeedDeclaratorId.no && !haveId) ||
            (needId == NeedDeclaratorId.opt) ||
            (needId == NeedDeclaratorId.must && haveId) ||
            (needId == NeedDeclaratorId.mustIfDstyle && haveId))
        {
            if (pt)
                *pt = t;
            goto Lis;
        }
        else
            goto Lisnot;

    Lis:
        //printf("\tis declaration, t = %s\n", t.toChars());
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
                    case TOKfilefullpath:
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
            if (!isDeclaration(t, NeedDeclaratorId.no, TOKrparen, &t))
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

        //printf("Parser::isDeclarator() %s\n", t.toChars());
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
                else if (isDeclaration(t, NeedDeclaratorId.no, TOKrbracket, &t))
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
                    else if (isDeclaration(t, NeedDeclaratorId.no, TOKrbracket, &t))
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
                    case TOKscope:
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
            case TOKdo:
                // The !parens is to disallow unnecessary parentheses
                if (!parens && (endtok == TOKreserved || endtok == t.value))
                {
                    *pt = t;
                    return true;
                }
                return false;

            case TOKidentifier:
                if (t.ident == Id._body)
                    goto case TOKdo;
                goto default;

            case TOKif:
                return haveTpl ? true : false;

            default:
                return false;
            }
        }
        assert(0);
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
            case TOKreturn:
                continue;

            case TOKconst:
            case TOKimmutable:
            case TOKshared:
            case TOKwild:
                t = peek(t);
                if (t.value == TOKlparen)
                {
                    t = peek(t);
                    if (!isDeclaration(t, NeedDeclaratorId.no, TOKrparen, &t))
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
     *      t is on opening $(LPAREN)
     * Output:
     *      *pt is set to closing token, which is '$(RPAREN)' on success
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

    AST.Expression parseExpression()
    {
        auto loc = token.loc;

        //printf("Parser::parseExpression() loc = %d\n", loc.linnum);
        auto e = parseAssignExp();
        while (token.value == TOKcomma)
        {
            nextToken();
            auto e2 = parseAssignExp();
            e = new AST.CommaExp(loc, e, e2, false);
            loc = token.loc;
        }
        return e;
    }

    /********************************* Expression Parser ***************************/

    AST.Expression parsePrimaryExp()
    {
        AST.Expression e;
        AST.Type t;
        Identifier id;
        const loc = token.loc;

        //printf("parsePrimaryExp(): loc = %d\n", loc.linnum);
        switch (token.value)
        {
        case TOKidentifier:
            {
                Token* t1 = peek(&token);
                Token* t2 = peek(t1);
                if (t1.value == TOKmin && t2.value == TOKgt)
                {
                    // skip ident.
                    nextToken();
                    nextToken();
                    nextToken();
                    error("use `.` for member lookup, not `->`");
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
                    auto tempinst = new AST.TemplateInstance(loc, id, parseTemplateArguments());
                    e = new AST.ScopeExp(loc, tempinst);
                }
                else
                    e = new AST.IdentifierExp(loc, id);
                break;
            }
        case TOKdollar:
            if (!inBrackets)
                error("`$` is valid only inside [] of index or slice");
            e = new AST.DollarExp(loc);
            nextToken();
            break;

        case TOKdot:
            // Signal global scope '.' operator with "" identifier
            e = new AST.IdentifierExp(loc, Id.empty);
            break;

        case TOKthis:
            e = new AST.ThisExp(loc);
            nextToken();
            break;

        case TOKsuper:
            e = new AST.SuperExp(loc);
            nextToken();
            break;

        case TOKint32v:
            e = new AST.IntegerExp(loc, cast(d_int32)token.int64value, AST.Type.tint32);
            nextToken();
            break;

        case TOKuns32v:
            e = new AST.IntegerExp(loc, cast(d_uns32)token.uns64value, AST.Type.tuns32);
            nextToken();
            break;

        case TOKint64v:
            e = new AST.IntegerExp(loc, token.int64value, AST.Type.tint64);
            nextToken();
            break;

        case TOKuns64v:
            e = new AST.IntegerExp(loc, token.uns64value, AST.Type.tuns64);
            nextToken();
            break;

        case TOKfloat32v:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.tfloat32);
            nextToken();
            break;

        case TOKfloat64v:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.tfloat64);
            nextToken();
            break;

        case TOKfloat80v:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.tfloat80);
            nextToken();
            break;

        case TOKimaginary32v:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.timaginary32);
            nextToken();
            break;

        case TOKimaginary64v:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.timaginary64);
            nextToken();
            break;

        case TOKimaginary80v:
            e = new AST.RealExp(loc, token.floatvalue, AST.Type.timaginary80);
            nextToken();
            break;

        case TOKnull:
            e = new AST.NullExp(loc);
            nextToken();
            break;

        case TOKfile:
            {
                const(char)* s = loc.filename ? loc.filename : mod.ident.toChars();
                e = new AST.StringExp(loc, cast(char*)s);
                nextToken();
                break;
            }
        case TOKfilefullpath:
            {
                const(char)* srcfile = mod.srcfile.name.toChars();
                const(char)* s;
                if(loc.filename && !FileName.equals(loc.filename, srcfile)) {
                    s = loc.filename;
                } else {
                    s = FileName.combine(mod.srcfilePath, srcfile);
                }
                e = new AST.StringExp(loc, cast(char*)s);
                nextToken();
                break;
            }
        case TOKline:
            e = new AST.IntegerExp(loc, loc.linnum, AST.Type.tint32);
            nextToken();
            break;

        case TOKmodulestring:
            {
                const(char)* s = md ? md.toChars() : mod.toChars();
                e = new AST.StringExp(loc, cast(char*)s);
                nextToken();
                break;
            }
        case TOKfuncstring:
            e = new AST.FuncInitExp(loc);
            nextToken();
            break;

        case TOKprettyfunc:
            e = new AST.PrettyFuncInitExp(loc);
            nextToken();
            break;

        case TOKtrue:
            e = new AST.IntegerExp(loc, 1, AST.Type.tbool);
            nextToken();
            break;

        case TOKfalse:
            e = new AST.IntegerExp(loc, 0, AST.Type.tbool);
            nextToken();
            break;

        case TOKcharv:
            e = new AST.IntegerExp(loc, cast(d_uns8)token.uns64value, AST.Type.tchar);
            nextToken();
            break;

        case TOKwcharv:
            e = new AST.IntegerExp(loc, cast(d_uns16)token.uns64value, AST.Type.twchar);
            nextToken();
            break;

        case TOKdcharv:
            e = new AST.IntegerExp(loc, cast(d_uns32)token.uns64value, AST.Type.tdchar);
            nextToken();
            break;

        case TOKstring:
        case TOKxstring:
            {
                // cat adjacent strings
                auto s = token.ustring;
                auto len = token.len;
                auto postfix = token.postfix;
                while (1)
                {
                    const prev = token;
                    nextToken();
                    if (token.value == TOKstring || token.value == TOKxstring)
                    {
                        if (token.postfix)
                        {
                            if (token.postfix != postfix)
                                error("mismatched string literal postfixes `'%c'` and `'%c'`", postfix, token.postfix);
                            postfix = token.postfix;
                        }

                        deprecation("Implicit string concatenation is deprecated, use %s ~ %s instead",
                                    prev.toChars(), token.toChars());

                        const len1 = len;
                        const len2 = token.len;
                        len = len1 + len2;
                        auto s2 = cast(char*)mem.xmalloc(len * char.sizeof);
                        memcpy(s2, s, len1 * char.sizeof);
                        memcpy(s2 + len1, token.ustring, len2 * char.sizeof);
                        s = s2;
                    }
                    else
                        break;
                }
                e = new AST.StringExp(loc, cast(char*)s, len, postfix);
                break;
            }
        case TOKvoid:
            t = AST.Type.tvoid;
            goto LabelX;

        case TOKint8:
            t = AST.Type.tint8;
            goto LabelX;

        case TOKuns8:
            t = AST.Type.tuns8;
            goto LabelX;

        case TOKint16:
            t = AST.Type.tint16;
            goto LabelX;

        case TOKuns16:
            t = AST.Type.tuns16;
            goto LabelX;

        case TOKint32:
            t = AST.Type.tint32;
            goto LabelX;

        case TOKuns32:
            t = AST.Type.tuns32;
            goto LabelX;

        case TOKint64:
            t = AST.Type.tint64;
            goto LabelX;

        case TOKuns64:
            t = AST.Type.tuns64;
            goto LabelX;

        case TOKint128:
            t = AST.Type.tint128;
            goto LabelX;

        case TOKuns128:
            t = AST.Type.tuns128;
            goto LabelX;

        case TOKfloat32:
            t = AST.Type.tfloat32;
            goto LabelX;

        case TOKfloat64:
            t = AST.Type.tfloat64;
            goto LabelX;

        case TOKfloat80:
            t = AST.Type.tfloat80;
            goto LabelX;

        case TOKimaginary32:
            t = AST.Type.timaginary32;
            goto LabelX;

        case TOKimaginary64:
            t = AST.Type.timaginary64;
            goto LabelX;

        case TOKimaginary80:
            t = AST.Type.timaginary80;
            goto LabelX;

        case TOKcomplex32:
            t = AST.Type.tcomplex32;
            goto LabelX;

        case TOKcomplex64:
            t = AST.Type.tcomplex64;
            goto LabelX;

        case TOKcomplex80:
            t = AST.Type.tcomplex80;
            goto LabelX;

        case TOKbool:
            t = AST.Type.tbool;
            goto LabelX;

        case TOKchar:
            t = AST.Type.tchar;
            goto LabelX;

        case TOKwchar:
            t = AST.Type.twchar;
            goto LabelX;

        case TOKdchar:
            t = AST.Type.tdchar;
            goto LabelX;
        LabelX:
            nextToken();
            if (token.value == TOKlparen)
            {
                e = new AST.TypeExp(loc, t);
                e = new AST.CallExp(loc, e, parseArguments());
                break;
            }
            check(TOKdot, t.toChars());
            if (token.value != TOKidentifier)
            {
                error("found `%s` when expecting identifier following `%s.`", token.toChars(), t.toChars());
                goto Lerr;
            }
            e = new AST.DotIdExp(loc, new AST.TypeExp(loc, t), token.ident);
            nextToken();
            break;

        case TOKtypeof:
            {
                t = parseTypeof();
                e = new AST.TypeExp(loc, t);
                break;
            }
        case TOKvector:
            {
                t = parseVector();
                e = new AST.TypeExp(loc, t);
                break;
            }
        case TOKtypeid:
            {
                nextToken();
                check(TOKlparen, "typeid");
                RootObject o;
                if (isDeclaration(&token, NeedDeclaratorId.no, TOKreserved, null))
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
                e = new AST.TypeidExp(loc, o);
                break;
            }
        case TOKtraits:
            {
                /* __traits(identifier, args...)
                 */
                Identifier ident;
                AST.Objects* args = null;

                nextToken();
                check(TOKlparen);
                if (token.value != TOKidentifier)
                {
                    error("`__traits(identifier, args...)` expected");
                    goto Lerr;
                }
                ident = token.ident;
                nextToken();
                if (token.value == TOKcomma)
                    args = parseTemplateArgumentList(); // __traits(identifier, args...)
                else
                    check(TOKrparen); // __traits(identifier)

                e = new AST.TraitsExp(loc, ident, args);
                break;
            }
        case TOKis:
            {
                AST.Type targ;
                Identifier ident = null;
                AST.Type tspec = null;
                TOK tok = TOKreserved;
                TOK tok2 = TOKreserved;
                AST.TemplateParameters* tpl = null;

                nextToken();
                if (token.value == TOKlparen)
                {
                    nextToken();
                    targ = parseType(&ident);
                    if (token.value == TOKcolon || token.value == TOKequal)
                    {
                        tok = token.value;
                        nextToken();
                        if (tok == TOKequal && (token.value == TOKstruct || token.value == TOKunion
                            || token.value == TOKclass || token.value == TOKsuper || token.value == TOKenum
                            || token.value == TOKinterface || token.value == TOKargTypes
                            || token.value == TOKparameters || token.value == TOKconst && peek(&token).value == TOKrparen
                            || token.value == TOKimmutable && peek(&token).value == TOKrparen
                            || token.value == TOKshared && peek(&token).value == TOKrparen
                            || token.value == TOKwild && peek(&token).value == TOKrparen || token.value == TOKfunction
                            || token.value == TOKdelegate || token.value == TOKreturn
                            || (token.value == TOKvector && peek(&token).value == TOKrparen)))
                        {
                            tok2 = token.value;
                            nextToken();
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
                            tpl = new AST.TemplateParameters();
                            check(TOKrparen);
                        }
                    }
                    else
                        check(TOKrparen);
                }
                else
                {
                    error("`type identifier : specialization` expected following `is`");
                    goto Lerr;
                }
                e = new AST.IsExp(loc, targ, ident, tok, tspec, tok2, tpl);
                break;
            }
        case TOKassert:
            {
                AST.Expression msg = null;

                nextToken();
                check(TOKlparen, "assert");
                e = parseAssignExp();
                if (token.value == TOKcomma)
                {
                    nextToken();
                    if (token.value != TOKrparen)
                    {
                        msg = parseAssignExp();
                        if (token.value == TOKcomma)
                            nextToken();
                    }
                }
                check(TOKrparen);
                e = new AST.AssertExp(loc, e, msg);
                break;
            }
        case TOKmixin:
            {
                nextToken();
                check(TOKlparen, "mixin");
                e = parseAssignExp();
                check(TOKrparen);
                e = new AST.CompileExp(loc, e);
                break;
            }
        case TOKimport:
            {
                nextToken();
                check(TOKlparen, "import");
                e = parseAssignExp();
                check(TOKrparen);
                e = new AST.ImportExp(loc, e);
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
                auto values = new AST.Expressions();
                AST.Expressions* keys = null;

                nextToken();
                while (token.value != TOKrbracket && token.value != TOKeof)
                {
                    e = parseAssignExp();
                    if (token.value == TOKcolon && (keys || values.dim == 0))
                    {
                        nextToken();
                        if (!keys)
                            keys = new AST.Expressions();
                        keys.push(e);
                        e = parseAssignExp();
                    }
                    else if (keys)
                    {
                        error("`key:value` expected for associative array literal");
                        keys = null;
                    }
                    values.push(e);
                    if (token.value == TOKrbracket)
                        break;
                    check(TOKcomma);
                }
                check(loc, TOKrbracket);

                if (keys)
                    e = new AST.AssocArrayLiteralExp(loc, keys, values);
                else
                    e = new AST.ArrayLiteralExp(loc, values);
                break;
            }
        case TOKlcurly:
        case TOKfunction:
        case TOKdelegate:
        case_delegate:
            {
                AST.Dsymbol s = parseFunctionLiteral();
                e = new AST.FuncExp(loc, s);
                break;
            }
        default:
            error("expression expected, not `%s`", token.toChars());
        Lerr:
            // Anything for e, as long as it's not NULL
            e = new AST.IntegerExp(loc, 0, AST.Type.tint32);
            nextToken();
            break;
        }
        return e;
    }

    AST.Expression parseUnaryExp()
    {
        AST.Expression e;
        const loc = token.loc;

        switch (token.value)
        {
        case TOKand:
            nextToken();
            e = parseUnaryExp();
            e = new AST.AddrExp(loc, e);
            break;

        case TOKplusplus:
            nextToken();
            e = parseUnaryExp();
            //e = new AddAssignExp(loc, e, new IntegerExp(loc, 1, Type::tint32));
            e = new AST.PreExp(TOKpreplusplus, loc, e);
            break;

        case TOKminusminus:
            nextToken();
            e = parseUnaryExp();
            //e = new MinAssignExp(loc, e, new IntegerExp(loc, 1, Type::tint32));
            e = new AST.PreExp(TOKpreminusminus, loc, e);
            break;

        case TOKmul:
            nextToken();
            e = parseUnaryExp();
            e = new AST.PtrExp(loc, e);
            break;

        case TOKmin:
            nextToken();
            e = parseUnaryExp();
            e = new AST.NegExp(loc, e);
            break;

        case TOKadd:
            nextToken();
            e = parseUnaryExp();
            e = new AST.UAddExp(loc, e);
            break;

        case TOKnot:
            nextToken();
            e = parseUnaryExp();
            e = new AST.NotExp(loc, e);
            break;

        case TOKtilde:
            nextToken();
            e = parseUnaryExp();
            e = new AST.ComExp(loc, e);
            break;

        case TOKdelete:
            nextToken();
            e = parseUnaryExp();
            e = new AST.DeleteExp(loc, e, false);
            break;

        case TOKcast: // cast(type) expression
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
                            break; // const as type constructor
                        m |= AST.MODconst; // const as storage class
                        nextToken();
                        continue;

                    case TOKimmutable:
                        if (peekNext() == TOKlparen)
                            break;
                        m |= AST.MODimmutable;
                        nextToken();
                        continue;

                    case TOKshared:
                        if (peekNext() == TOKlparen)
                            break;
                        m |= AST.MODshared;
                        nextToken();
                        continue;

                    case TOKwild:
                        if (peekNext() == TOKlparen)
                            break;
                        m |= AST.MODwild;
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
                    e = new AST.CastExp(loc, e, m);
                }
                else
                {
                    AST.Type t = parseType(); // cast( type )
                    t = t.addMod(m); // cast( const type )
                    check(TOKrparen);
                    e = parseUnaryExp();
                    e = new AST.CastExp(loc, e, t);
                }
                break;
            }
        case TOKwild:
        case TOKshared:
        case TOKconst:
        case TOKimmutable: // immutable(type)(arguments) / immutable(type).init
            {
                StorageClass stc = parseTypeCtor();

                AST.Type t = parseBasicType();
                t = t.addSTC(stc);

                if (stc == 0 && token.value == TOKdot)
                {
                    nextToken();
                    if (token.value != TOKidentifier)
                    {
                        error("identifier expected following `(type)`.");
                        return null;
                    }
                    e = new AST.DotIdExp(loc, new AST.TypeExp(loc, t), token.ident);
                    nextToken();
                    e = parsePostExp(e);
                }
                else
                {
                    e = new AST.TypeExp(loc, t);
                    if (token.value != TOKlparen)
                    {
                        error("`(arguments)` expected following `%s`", t.toChars());
                        return e;
                    }
                    e = new AST.CallExp(loc, e, parseArguments());
                }
                break;
            }
        case TOKlparen:
            {
                auto tk = peek(&token);
                static if (CCASTSYNTAX)
                {
                    // If cast
                    if (isDeclaration(tk, NeedDeclaratorId.no, TOKrparen, &tk))
                    {
                        tk = peek(tk); // skip over right parenthesis
                        switch (tk.value)
                        {
                        case TOKnot:
                            tk = peek(tk);
                            if (tk.value == TOKis || tk.value == TOKin) // !is or !in
                                break;
                            goto case;

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
                        case TOKfilefullpath:
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
                                nextToken();
                                auto t = parseType();
                                check(TOKrparen);

                                // if .identifier
                                // or .identifier!( ... )
                                if (token.value == TOKdot)
                                {
                                    if (peekNext() != TOKidentifier && peekNext() != TOKnew)
                                    {
                                        error("identifier or new keyword expected following `(...)`.");
                                        return null;
                                    }
                                    e = new AST.TypeExp(loc, t);
                                    e = parsePostExp(e);
                                }
                                else
                                {
                                    e = parseUnaryExp();
                                    e = new AST.CastExp(loc, e, t);
                                    error("C style cast illegal, use `%s`", e.toChars());
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
            AST.Expression e2 = parseUnaryExp();
            e = new AST.PowExp(loc, e, e2);
        }

        return e;
    }

    AST.Expression parsePostExp(AST.Expression e)
    {
        while (1)
        {
            const loc = token.loc;
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
                        AST.Objects* tiargs = parseTemplateArguments();
                        e = new AST.DotTemplateInstanceExp(loc, e, id, tiargs);
                    }
                    else
                        e = new AST.DotIdExp(loc, e, id);
                    continue;
                }
                else if (token.value == TOKnew)
                {
                    e = parseNewExp(e);
                    continue;
                }
                else
                    error("identifier expected following `.`, not `%s`", token.toChars());
                break;

            case TOKplusplus:
                e = new AST.PostExp(TOKplusplus, loc, e);
                break;

            case TOKminusminus:
                e = new AST.PostExp(TOKminusminus, loc, e);
                break;

            case TOKlparen:
                e = new AST.CallExp(loc, e, parseArguments());
                continue;

            case TOKlbracket:
                {
                    // array dereferences:
                    //      array[index]
                    //      array[]
                    //      array[lwr .. upr]
                    AST.Expression index;
                    AST.Expression upr;
                    auto arguments = new AST.Expressions();

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
                            arguments.push(new AST.IntervalExp(loc, index, upr));
                        }
                        else
                            arguments.push(index);
                        if (token.value == TOKrbracket)
                            break;
                        check(TOKcomma);
                    }
                    check(TOKrbracket);
                    inBrackets--;
                    e = new AST.ArrayExp(loc, e, arguments);
                    continue;
                }
            default:
                return e;
            }
            nextToken();
        }
    }

    AST.Expression parseMulExp()
    {
        const loc = token.loc;
        auto e = parseUnaryExp();

        while (1)
        {
            switch (token.value)
            {
            case TOKmul:
                nextToken();
                auto e2 = parseUnaryExp();
                e = new AST.MulExp(loc, e, e2);
                continue;

            case TOKdiv:
                nextToken();
                auto e2 = parseUnaryExp();
                e = new AST.DivExp(loc, e, e2);
                continue;

            case TOKmod:
                nextToken();
                auto e2 = parseUnaryExp();
                e = new AST.ModExp(loc, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    AST.Expression parseAddExp()
    {
        const loc = token.loc;
        auto e = parseMulExp();

        while (1)
        {
            switch (token.value)
            {
            case TOKadd:
                nextToken();
                auto e2 = parseMulExp();
                e = new AST.AddExp(loc, e, e2);
                continue;

            case TOKmin:
                nextToken();
                auto e2 = parseMulExp();
                e = new AST.MinExp(loc, e, e2);
                continue;

            case TOKtilde:
                nextToken();
                auto e2 = parseMulExp();
                e = new AST.CatExp(loc, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    AST.Expression parseShiftExp()
    {
        const loc = token.loc;
        auto e = parseAddExp();

        while (1)
        {
            switch (token.value)
            {
            case TOKshl:
                nextToken();
                auto e2 = parseAddExp();
                e = new AST.ShlExp(loc, e, e2);
                continue;

            case TOKshr:
                nextToken();
                auto e2 = parseAddExp();
                e = new AST.ShrExp(loc, e, e2);
                continue;

            case TOKushr:
                nextToken();
                auto e2 = parseAddExp();
                e = new AST.UshrExp(loc, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    AST.Expression parseCmpExp()
    {
        const loc = token.loc;

        auto e = parseShiftExp();
        TOK op = token.value;

        switch (op)
        {
        case TOKequal:
        case TOKnotequal:
            nextToken();
            auto e2 = parseShiftExp();
            e = new AST.EqualExp(op, loc, e, e2);
            break;

        case TOKis:
            op = TOKidentity;
            goto L1;

        case TOKnot:
        {
            // Attempt to identify '!is'
            auto t = peek(&token);
            if (t.value == TOKin)
            {
                nextToken();
                nextToken();
                auto e2 = parseShiftExp();
                e = new AST.InExp(loc, e, e2);
                e = new AST.NotExp(loc, e);
                break;
            }
            if (t.value != TOKis)
                break;
            nextToken();
            op = TOKnotidentity;
            goto L1;
        }
        L1:
            nextToken();
            auto e2 = parseShiftExp();
            e = new AST.IdentityExp(op, loc, e, e2);
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
            auto e2 = parseShiftExp();
            e = new AST.CmpExp(op, loc, e, e2);
            break;

        case TOKin:
            nextToken();
            auto e2 = parseShiftExp();
            e = new AST.InExp(loc, e, e2);
            break;

        default:
            break;
        }
        return e;
    }

    AST.Expression parseAndExp()
    {
        Loc loc = token.loc;
        auto e = parseCmpExp();
        while (token.value == TOKand)
        {
            checkParens(TOKand, e);
            nextToken();
            auto e2 = parseCmpExp();
            checkParens(TOKand, e2);
            e = new AST.AndExp(loc, e, e2);
            loc = token.loc;
        }
        return e;
    }

    AST.Expression parseXorExp()
    {
        const loc = token.loc;

        auto e = parseAndExp();
        while (token.value == TOKxor)
        {
            checkParens(TOKxor, e);
            nextToken();
            auto e2 = parseAndExp();
            checkParens(TOKxor, e2);
            e = new AST.XorExp(loc, e, e2);
        }
        return e;
    }

    AST.Expression parseOrExp()
    {
        const loc = token.loc;

        auto e = parseXorExp();
        while (token.value == TOKor)
        {
            checkParens(TOKor, e);
            nextToken();
            auto e2 = parseXorExp();
            checkParens(TOKor, e2);
            e = new AST.OrExp(loc, e, e2);
        }
        return e;
    }

    AST.Expression parseAndAndExp()
    {
        const loc = token.loc;

        auto e = parseOrExp();
        while (token.value == TOKandand)
        {
            nextToken();
            auto e2 = parseOrExp();
            e = new AST.AndAndExp(loc, e, e2);
        }
        return e;
    }

    AST.Expression parseOrOrExp()
    {
        const loc = token.loc;

        auto e = parseAndAndExp();
        while (token.value == TOKoror)
        {
            nextToken();
            auto e2 = parseAndAndExp();
            e = new AST.OrOrExp(loc, e, e2);
        }
        return e;
    }

    AST.Expression parseCondExp()
    {
        const loc = token.loc;

        auto e = parseOrOrExp();
        if (token.value == TOKquestion)
        {
            nextToken();
            auto e1 = parseExpression();
            check(TOKcolon);
            auto e2 = parseCondExp();
            e = new AST.CondExp(loc, e, e1, e2);
        }
        return e;
    }

    AST.Expression parseAssignExp()
    {
        auto e = parseCondExp();
        while (1)
        {
            const loc = token.loc;
            switch (token.value)
            {
            case TOKassign:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.AssignExp(loc, e, e2);
                continue;

            case TOKaddass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.AddAssignExp(loc, e, e2);
                continue;

            case TOKminass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.MinAssignExp(loc, e, e2);
                continue;

            case TOKmulass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.MulAssignExp(loc, e, e2);
                continue;

            case TOKdivass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.DivAssignExp(loc, e, e2);
                continue;

            case TOKmodass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.ModAssignExp(loc, e, e2);
                continue;

            case TOKpowass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.PowAssignExp(loc, e, e2);
                continue;

            case TOKandass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.AndAssignExp(loc, e, e2);
                continue;

            case TOKorass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.OrAssignExp(loc, e, e2);
                continue;

            case TOKxorass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.XorAssignExp(loc, e, e2);
                continue;

            case TOKshlass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.ShlAssignExp(loc, e, e2);
                continue;

            case TOKshrass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.ShrAssignExp(loc, e, e2);
                continue;

            case TOKushrass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.UshrAssignExp(loc, e, e2);
                continue;

            case TOKcatass:
                nextToken();
                auto e2 = parseAssignExp();
                e = new AST.CatAssignExp(loc, e, e2);
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
     * Assume current token is ',', '$(LPAREN)' or '['.
     */
    AST.Expressions* parseArguments()
    {
        // function call
        AST.Expressions* arguments;
        TOK endtok;

        arguments = new AST.Expressions();
        if (token.value == TOKlbracket)
            endtok = TOKrbracket;
        else
            endtok = TOKrparen;

        {
            nextToken();
            while (token.value != endtok && token.value != TOKeof)
            {
                auto arg = parseAssignExp();
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
    AST.Expression parseNewExp(AST.Expression thisexp)
    {
        const loc = token.loc;

        nextToken();
        AST.Expressions* newargs = null;
        AST.Expressions* arguments = null;
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

            AST.BaseClasses* baseclasses = null;
            if (token.value != TOKlcurly)
                baseclasses = parseBaseClasses();

            Identifier id = null;
            AST.Dsymbols* members = null;

            if (token.value != TOKlcurly)
            {
                error("`{ members }` expected for anonymous class");
            }
            else
            {
                nextToken();
                members = parseDeclDefs(0);
                if (token.value != TOKrcurly)
                    error("class member expected");
                nextToken();
            }

            auto cd = new AST.ClassDeclaration(loc, id, baseclasses, members, false);
            auto e = new AST.NewAnonClassExp(loc, thisexp, newargs, cd, arguments);
            return e;
        }

        const stc = parseTypeCtor();
        auto t = parseBasicType(true);
        t = parseBasicType2(t);
        t = t.addSTC(stc);
        if (t.ty == AST.Taarray)
        {
            AST.TypeAArray taa = cast(AST.TypeAArray)t;
            AST.Type index = taa.index;
            auto edim = AST.typeToExpression(index);
            if (!edim)
            {
                error("need size of rightmost array, not type `%s`", index.toChars());
                return new AST.NullExp(loc);
            }
            t = new AST.TypeSArray(taa.next, edim);
        }
        else if (t.ty == AST.Tsarray)
        {
        }
        else if (token.value == TOKlparen)
        {
            arguments = parseArguments();
        }

        auto e = new AST.NewExp(loc, thisexp, newargs, t, arguments);
        return e;
    }

    /**********************************************
     */
    void addComment(AST.Dsymbol s, const(char)* blockComment)
    {
        if (s !is null)
        {
            s.addComment(combineComments(blockComment, token.lineComment, true));
            token.lineComment = null;
        }
    }
}

enum PREC : int
{
    zero,
    expr,
    assign,
    cond,
    oror,
    andand,
    or,
    xor,
    and,
    equal,
    rel,
    shift,
    add,
    mul,
    pow,
    unary,
    primary,
}
