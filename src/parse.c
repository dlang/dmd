
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// This is the D parser

#include <stdio.h>
#include <assert.h>
#include <string.h>                     // strlen(),memcpy()

#include "rmem.h"
#include "lexer.h"
#include "parse.h"
#include "init.h"
#include "attrib.h"
#include "cond.h"
#include "mtype.h"
#include "template.h"
#include "staticassert.h"
#include "expression.h"
#include "statement.h"
#include "module.h"
#include "dsymbol.h"
#include "import.h"
#include "declaration.h"
#include "aggregate.h"
#include "enum.h"
#include "id.h"
#include "version.h"
#include "aliasthis.h"

// How multiple declarations are parsed.
// If 1, treat as C.
// If 0, treat:
//      int *p, i;
// as:
//      int* p;
//      int* i;
#define CDECLSYNTAX     0

// Support C cast syntax:
//      (type)(expression)
#define CCASTSYNTAX     1

// Support postfix C array declarations, such as
//      int a[3][4];
#define CARRAYDECL      1

// Support left-to-right array declarations
#define LTORARRAYDECL   1


Parser::Parser(Module *module, unsigned char *base, unsigned length, int doDocComment)
    : Lexer(module, base, 0, length, doDocComment, 0)
{
    //printf("Parser::Parser()\n");
    md = NULL;
    linkage = LINKd;
    endloc = 0;
    inBrackets = 0;
    //nextToken();              // start up the scanner
}

Dsymbols *Parser::parseModule()
{
    Dsymbols *decldefs;

    bool isdeprecated = false;
    Expression *msg = NULL;

    if (token.value == TOKdeprecated)
    {
        Token *tk = NULL;
        if (skipParensIf(peek(&token), &tk) &&
            tk->value == TOKmodule)
        {
            // deprecated (...) module ...
            isdeprecated = true;
            nextToken();
            if (token.value == TOKlparen)
            {
                check(TOKlparen);
                msg = parseAssignExp();
                check(TOKrparen);
            }
        }
    }

    // ModuleDeclation leads off
    if (token.value == TOKmodule)
    {
        unsigned char *comment = token.blockComment;

        nextToken();
        if (token.value != TOKidentifier)
        {   error("Identifier expected following module");
            goto Lerr;
        }
        else
        {
            Identifiers *a = NULL;
            Identifier *id;

            id = token.ident;
            while (nextToken() == TOKdot)
            {
                if (!a)
                    a = new Identifiers();
                a->push(id);
                nextToken();
                if (token.value != TOKidentifier)
                {   error("Identifier expected following package");
                    goto Lerr;
                }
                id = token.ident;
            }

            md = new ModuleDeclaration(a, id);
            md->isdeprecated = isdeprecated;
            md->msg = msg;

            check(TOKsemicolon, "module declaration");
            addComment(mod, comment);
        }
    }

    decldefs = parseDeclDefs(0);
    if (token.value != TOKeof)
    {   error(loc, "unrecognized declaration");
        goto Lerr;
    }
    return decldefs;

Lerr:
    while (token.value != TOKsemicolon && token.value != TOKeof)
        nextToken();
    nextToken();
    return new Dsymbols();
}

Dsymbols *Parser::parseDeclDefs(int once)
{   Dsymbol *s;
    Dsymbols *decldefs;
    Dsymbols *a;
    Dsymbols *aelse;
    enum PROT prot;
    StorageClass stc;
    Condition *condition;
    unsigned char *comment;

    //printf("Parser::parseDeclDefs()\n");
    decldefs = new Dsymbols();
    do
    {
        comment = token.blockComment;
        switch (token.value)
        {
            case TOKenum:
                s = parseEnum();
                break;

            case TOKstruct:
            case TOKunion:
            case TOKclass:
            case TOKinterface:
                s = parseAggregate();
                break;

            case TOKimport:
                s = parseImport(decldefs, 0);
                break;

            case TOKtemplate:
                s = (Dsymbol *)parseTemplateDeclaration();
                break;

            case TOKmixin:
            {   Loc loc = this->loc;
                if (peek(&token)->value == TOKlparen)
                {   // mixin(string)
                    nextToken();
                    check(TOKlparen, "mixin");
                    Expression *e = parseAssignExp();
                    check(TOKrparen);
                    check(TOKsemicolon);
                    s = new CompileDeclaration(loc, e);
                    break;
                }
                s = parseMixin();
                break;
            }

            case BASIC_TYPES:
            case TOKalias:
            case TOKtypedef:
            case TOKidentifier:
            case TOKtypeof:
            case TOKdot:
            Ldeclaration:
                a = parseDeclarations();
                decldefs->append(a);
                continue;

            case TOKthis:
                s = parseCtor();
                break;

            case TOKtilde:
                s = parseDtor();
                break;

            case TOKinvariant:
            {
                Token *t = peek(&token);
                if (t->value == TOKlparen && peek(t)->value == TOKrparen)
                {
                }
                else if ((global.params.enabledV2hints & V2MODEsyntax) &&
                    mod && mod->isRoot()
                    )
                {
                    warning(loc, "D2 requires () after invariant [-v2=%s]",
                            V2MODE_name(V2MODEsyntax));
                }
                s = parseInvariant();
                break;
            }

            case TOKunittest:
                s = parseUnitTest();
                break;

            case TOKnew:
                s = parseNew();
                break;

            case TOKdelete:
                s = parseDelete();
                break;

            case TOKeof:
            case TOKrcurly:
                if (once)
                    error("Declaration expected, not '%s'", token.toChars());
                return decldefs;

            case TOKstatic:
                nextToken();
                if (token.value == TOKthis)
                    s = parseStaticCtor();
                else if (token.value == TOKtilde)
                    s = parseStaticDtor();
                else if (token.value == TOKassert)
                    s = parseStaticAssert();
                else if (token.value == TOKif)
                {   condition = parseStaticIfCondition();
                    a = parseBlock();
                    aelse = NULL;
                    if (token.value == TOKelse)
                    {   nextToken();
                        aelse = parseBlock();
                    }
                    s = new StaticIfDeclaration(condition, a, aelse);
                    break;
                }
                else if (token.value == TOKimport)
                {
                    s = parseImport(decldefs, 1);
                }
                else
                {   stc = STCstatic;
                    goto Lstc2;
                }
                break;

            case TOKconst:        stc = STCconst;        goto Lstc;
            case TOKfinal:        stc = STCfinal;        goto Lstc;
            case TOKauto:         stc = STCauto;         goto Lstc;
            case TOKscope:        stc = STCscope;        goto Lstc;
            case TOKoverride:     stc = STCoverride;     goto Lstc;
            case TOKabstract:     stc = STCabstract;     goto Lstc;
            case TOKsynchronized: stc = STCsynchronized; goto Lstc;
#if DMDV2
            case TOKnothrow:      stc = STCnothrow;      goto Lstc;
            case TOKpure:         stc = STCpure;         goto Lstc;
            case TOKref:          stc = STCref;          goto Lstc;
            case TOKtls:          stc = STCtls;          goto Lstc;
            case TOKgshared:      stc = STCgshared;      goto Lstc;
            //case TOKmanifest:   stc = STCmanifest;     goto Lstc;
            case TOKat:           stc = parseAttribute(); goto Lstc;
#endif

            Lstc:
                nextToken();
            Lstc2:
                switch (token.value)
                {
                    case TOKconst:        stc |= STCconst;       goto Lstc;
                    case TOKfinal:        stc |= STCfinal;       goto Lstc;
                    case TOKauto:         stc |= STCauto;        goto Lstc;
                    case TOKscope:        stc |= STCscope;       goto Lstc;
                    case TOKoverride:     stc |= STCoverride;    goto Lstc;
                    case TOKabstract:     stc |= STCabstract;    goto Lstc;
                    case TOKsynchronized: stc |= STCsynchronized; goto Lstc;
                    //case TOKinvariant:    stc |= STCimmutable;   goto Lstc;
                    default:
                        break;
                }

                /* Look for auto initializers:
                 *      storage_class identifier = initializer;
                 */
                if (token.value == TOKidentifier &&
                    peek(&token)->value == TOKassign)
                {
                    while (1)
                    {
                        Identifier *ident = token.ident;
                        nextToken();
                        nextToken();
                        Initializer *init = parseInitializer();
                        VarDeclaration *v = new VarDeclaration(loc, NULL, ident, init);
                        v->storage_class = stc;
                        s = v;
                        if (token.value == TOKsemicolon)
                        {
                            nextToken();
                        }
                        else if (token.value == TOKcomma)
                        {
                            nextToken();
                            if (token.value == TOKidentifier &&
                                peek(&token)->value == TOKassign)
                            {
                                decldefs->push(s);
                                addComment(s, comment);
                                continue;
                            }
                            else
                                error("Identifier expected following comma");
                        }
                        else
                            error("semicolon expected following auto declaration, not '%s'", token.toChars());
                        break;
                    }
                }
                else
                {   a = parseBlock();
                    s = new StorageClassDeclaration(stc, a);
                }
                break;

            case TOKdeprecated:
            {
                if (peek(&token)->value != TOKlparen)
                {
                    stc = STCdeprecated;
                    goto Lstc;
                }
                nextToken();
                check(TOKlparen);
                Expression *e = parseAssignExp();
                check(TOKrparen);
#if 1
                a = parseBlock();
                s = new DeprecatedDeclaration(e, a);
#else
                if (pAttrs->depmsg)
                {
                    error("conflicting storage class 'deprecated(%s)' and 'deprecated(%s)'",
                        pAttrs->depmsg->toChars(), e->toChars());
                }
                pAttrs->depmsg = e;
                a = parseBlock(pLastDecl, pAttrs);
                if (pAttrs->depmsg)
                {
                    s = new DeprecatedDeclaration(pAttrs->depmsg, a);
                    pAttrs->depmsg = NULL;
                }
#endif
                break;
            }

            case TOKextern:
                if (peek(&token)->value != TOKlparen)
                {   stc = STCextern;
                    goto Lstc;
                }
            {
                enum LINK linksave = linkage;
                linkage = parseLinkage();
                a = parseBlock();
                s = new LinkDeclaration(linkage, a);
                linkage = linksave;
                break;
            }
            case TOKprivate:    prot = PROTprivate;     goto Lprot;
            case TOKpackage:    prot = PROTpackage;     goto Lprot;
            case TOKprotected:  prot = PROTprotected;   goto Lprot;
            case TOKpublic:     prot = PROTpublic;      goto Lprot;
            case TOKexport:     prot = PROTexport;      goto Lprot;

            Lprot:
                nextToken();
                switch (token.value)
                {
                    case TOKprivate:
                    case TOKpackage:
                    case TOKprotected:
                    case TOKpublic:
                    case TOKexport:
                        error("redundant protection attribute");
                        break;
                }
                a = parseBlock();
                s = new ProtDeclaration(prot, a);
                break;

            case TOKalign:
            {   unsigned n;

                s = NULL;
                nextToken();
                if (token.value == TOKlparen)
                {
                    nextToken();
                    if (token.value == TOKint32v && token.uns64value > 0)
                    {
                        if (token.uns64value & (token.uns64value - 1))
                            error("align(%s) must be a power of 2", token.toChars());
                        n = (unsigned)token.uns64value;
                    }
                    else
                    {   error("positive integer expected, not %s", token.toChars());
                        n = 1;
                    }
                    nextToken();
                    check(TOKrparen);
                }
                else
                    n = global.structalign;             // default

                a = parseBlock();
                s = new AlignDeclaration(n, a);
                break;
            }

            case TOKpragma:
            {   Identifier *ident;
                Expressions *args = NULL;

                nextToken();
                check(TOKlparen);
                if (token.value != TOKidentifier)
                {   error("pragma(identifier) expected");
                    goto Lerror;
                }
                ident = token.ident;
                nextToken();
                if (token.value == TOKcomma && peekNext() != TOKrparen)
                    args = parseArguments();    // pragma(identifier, args...)
                else
                    check(TOKrparen);           // pragma(identifier)

                if (token.value == TOKsemicolon)
                    a = NULL;
                else
                    a = parseBlock();
                s = new PragmaDeclaration(loc, ident, args, a);
                break;
            }

            case TOKdebug:
                nextToken();
                if (token.value == TOKassign)
                {
                    nextToken();
                    if (token.value == TOKidentifier)
                        s = new DebugSymbol(loc, token.ident);
                    else if (token.value == TOKint32v || token.value == TOKint64v)
                        s = new DebugSymbol(loc, (unsigned)token.uns64value);
                    else
                    {   error("identifier or integer expected, not %s", token.toChars());
                        s = NULL;
                    }
                    nextToken();
                    check(TOKsemicolon, "debug declaration");
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
                        s = new VersionSymbol(loc, token.ident);
                    else if (token.value == TOKint32v || token.value == TOKint64v)
                        s = new VersionSymbol(loc, (unsigned)token.uns64value);
                    else
                    {   error("identifier or integer expected, not %s", token.toChars());
                        s = NULL;
                    }
                    nextToken();
                    check(TOKsemicolon, "version declaration");
                    break;
                }
                condition = parseVersionCondition();
                goto Lcondition;

            Lcondition:
                a = parseBlock();
                aelse = NULL;
                if (token.value == TOKelse)
                {   nextToken();
                    aelse = parseBlock();
                }
                s = new ConditionalDeclaration(condition, a, aelse);
                break;

            case TOKsemicolon:          // empty declaration
                nextToken();
                continue;

            default:
                error("Declaration expected, not '%s'",token.toChars());
            Lerror:
                while (token.value != TOKsemicolon && token.value != TOKeof)
                    nextToken();
                nextToken();
                s = NULL;
                continue;
        }
        if (s)
        {   decldefs->push(s);
            addComment(s, comment);
        }
    } while (!once);
    return decldefs;
}

/*********************************************
 * Give error on conflicting storage classes.
 */

#if DMDV2
void Parser::composeStorageClass(StorageClass stc)
{
    StorageClass u = stc;
    u &= STCconst | STCimmutable | STCmanifest;
    if (u & (u - 1))
        error("conflicting storage class %s", Token::toChars(token.value));
    u = stc;
    u &= STCgshared | STCshared | STCtls;
    if (u & (u - 1))
        error("conflicting storage class %s", Token::toChars(token.value));
}
#endif

/***********************************************
 * Parse storage class, lexer is on '@'
 */

#if DMDV2
StorageClass Parser::parseAttribute()
{
    nextToken();
    StorageClass stc = 0;
    if (token.value != TOKidentifier)
    {
        error("identifier expected after @, not %s", token.toChars());
    }
    else if (token.ident == Id::property)
        stc = STCproperty;
    else if (token.ident == Id::safe)
        stc = STCsafe;
    else if (token.ident == Id::trusted)
        stc = STCtrusted;
    else if (token.ident == Id::system)
        stc = STCsystem;
    else if (token.ident == Id::disable)
        stc = STCdisable;
    else
        error("valid attribute identifiers are @property, @safe, @trusted, @system, @disable not @%s", token.toChars());
    return stc;
}
#endif


/********************************************
 * Parse declarations after an align, protection, or extern decl.
 */

Dsymbols *Parser::parseBlock()
{
    Dsymbols *a = NULL;

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
            nextToken();
            a = parseDeclDefs(0);
            if (token.value != TOKrcurly)
            {   /* { */
                error("matching '}' expected, not %s", token.toChars());
            }
            else
                nextToken();
            break;

        case TOKcolon:
            nextToken();
#if 0
            a = NULL;
#else
            a = parseDeclDefs(0);       // grab declarations up to closing curly bracket
#endif
            break;

        default:
            a = parseDeclDefs(1);
            break;
    }
    return a;
}

/**********************************
 * Parse a static assertion.
 */

StaticAssert *Parser::parseStaticAssert()
{
    Loc loc = this->loc;
    Expression *exp;
    Expression *msg = NULL;

    //printf("parseStaticAssert()\n");
    nextToken();
    check(TOKlparen);
    exp = parseAssignExp();
    if (token.value == TOKcomma)
    {   nextToken();
        msg = parseAssignExp();
    }
    check(TOKrparen);
    check(TOKsemicolon, "static assert");
    return new StaticAssert(loc, exp, msg);
}

/***********************************
 * Parse typeof(expression).
 * Current token is on the 'typeof'.
 */

#if DMDV2
TypeQualified *Parser::parseTypeof()
{   TypeQualified *t;
    Loc loc = this->loc;

    nextToken();
    check(TOKlparen);
    if (token.value == TOKreturn)       // typeof(return)
    {
        nextToken();
        t = new TypeReturn(loc);
    }
    else
    {   Expression *exp = parseExpression();    // typeof(expression)
        t = new TypeTypeof(loc, exp);
    }
    check(TOKrparen);
    return t;
}
#endif

/***********************************
 * Parse extern (linkage)
 * The parser is on the 'extern' token.
 */

enum LINK Parser::parseLinkage()
{
    enum LINK link = LINKdefault;
    nextToken();
    assert(token.value == TOKlparen);
    nextToken();
    if (token.value == TOKidentifier)
    {   Identifier *id = token.ident;

        nextToken();
        if (id == Id::Windows)
            link = LINKwindows;
        else if (id == Id::Pascal)
            link = LINKpascal;
        else if (id == Id::D)
            link = LINKd;
        else if (id == Id::C)
        {
            link = LINKc;
            if (token.value == TOKplusplus)
            {   link = LINKcpp;
                nextToken();
            }
        }
        else if (id == Id::System)
        {
#if _WIN32
            link = LINKwindows;
#else
            link = LINKc;
#endif
        }
        else
        {
            error("valid linkage identifiers are D, C, C++, Pascal, Windows, System");
            link = LINKd;
        }
    }
    else
    {
        link = LINKd;           // default
    }
    check(TOKrparen);
    return link;
}

/**************************************
 * Parse a debug conditional
 */

Condition *Parser::parseDebugCondition()
{
    Condition *c;

    if (token.value == TOKlparen)
    {
        nextToken();
        unsigned level = 1;
        Identifier *id = NULL;

        if (token.value == TOKidentifier)
            id = token.ident;
        else if (token.value == TOKint32v || token.value == TOKint64v)
            level = (unsigned)token.uns64value;
        else
            error("identifier or integer expected, not %s", token.toChars());
        nextToken();
        check(TOKrparen);
        c = new DebugCondition(mod, level, id);
    }
    else
        c = new DebugCondition(mod, 1, NULL);
    return c;

}

/**************************************
 * Parse a version conditional
 */

Condition *Parser::parseVersionCondition()
{
    Condition *c;
    unsigned level = 1;
    Identifier *id = NULL;

    if (token.value == TOKlparen)
    {
        nextToken();
        if (token.value == TOKidentifier)
            id = token.ident;
        else if (token.value == TOKint32v || token.value == TOKint64v)
            level = (unsigned)token.uns64value;
#if DMDV2
        /* Allow:
         *    version (unittest)
         * even though unittest is a keyword
         */
        else if (token.value == TOKunittest)
            id = Lexer::idPool(Token::toChars(TOKunittest));
#endif
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
 */

Condition *Parser::parseStaticIfCondition()
{   Expression *exp;
    Condition *condition;
    Loc loc = this->loc;

    nextToken();
    if (token.value == TOKlparen)
    {
        nextToken();
        exp = parseAssignExp();
        check(TOKrparen);
    }
    else
    {   error("(expression) expected following static if");
        exp = NULL;
    }
    condition = new StaticIfCondition(loc, exp);
    return condition;
}


/*****************************************
 * Parse a constructor definition:
 *      this(parameters) { body }
 * Current token is 'this'.
 */

Dsymbol *Parser::parseCtor()
{
    Loc loc = this->loc;

    nextToken();
    int varargs;
    Parameters *parameters = parseParameters(&varargs);
    CtorDeclaration *f = new CtorDeclaration(loc, 0, parameters, varargs);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse a destructor definition:
 *      ~this() { body }
 * Current token is '~'.
 */

DtorDeclaration *Parser::parseDtor()
{
    DtorDeclaration *f;
    Loc loc = this->loc;

    nextToken();
    check(TOKthis, "~");
    check(TOKlparen, "~this");
    check(TOKrparen);

    f = new DtorDeclaration(loc, 0);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse a static constructor definition:
 *      static this() { body }
 * Current token is 'this'.
 */

StaticCtorDeclaration *Parser::parseStaticCtor()
{
    Loc loc = this->loc;

    nextToken();
    check(TOKlparen, "static this");
    check(TOKrparen);

    StaticCtorDeclaration *f = new StaticCtorDeclaration(loc, 0);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse a shared static constructor definition:
 *      shared static this() { body }
 * Current token is 'shared'.
 */
#if DMDV2
SharedStaticCtorDeclaration *Parser::parseSharedStaticCtor()
{
    Loc loc = this->loc;

    nextToken();
    nextToken();
    nextToken();
    check(TOKlparen, "shared static this");
    check(TOKrparen);

    SharedStaticCtorDeclaration *f = new SharedStaticCtorDeclaration(loc, 0);
    parseContracts(f);
    return f;
}
#endif

/*****************************************
 * Parse a static destructor definition:
 *      static ~this() { body }
 * Current token is '~'.
 */

StaticDtorDeclaration *Parser::parseStaticDtor()
{
    Loc loc = this->loc;

    nextToken();
    check(TOKthis, "~");
    check(TOKlparen, "~this");
    check(TOKrparen);

    StaticDtorDeclaration *f = new StaticDtorDeclaration(loc, 0);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse a shared static destructor definition:
 *      shared static ~this() { body }
 * Current token is 'shared'.
 */
#if DMDV2
SharedStaticDtorDeclaration *Parser::parseSharedStaticDtor()
{
    Loc loc = this->loc;

    nextToken();
    nextToken();
    nextToken();
    check(TOKthis, "shared static ~");
    check(TOKlparen, "shared static ~this");
    check(TOKrparen);

    SharedStaticDtorDeclaration *f = new SharedStaticDtorDeclaration(loc, 0);
    parseContracts(f);
    return f;
}
#endif

/*****************************************
 * Parse an invariant definition:
 *      invariant() { body }
 * Current token is 'invariant'.
 */

InvariantDeclaration *Parser::parseInvariant()
{
    InvariantDeclaration *f;
    Loc loc = this->loc;

    nextToken();
    if (token.value == TOKlparen)       // optional ()
    {
        nextToken();
        check(TOKrparen);
    }

    f = new InvariantDeclaration(loc, 0);
    f->fbody = parseStatement(PScurly);
    return f;
}

/*****************************************
 * Parse a unittest definition:
 *      unittest { body }
 * Current token is 'unittest'.
 */

UnitTestDeclaration *Parser::parseUnitTest()
{
    UnitTestDeclaration *f;
    Statement *body;
    Loc loc = this->loc;

    nextToken();

    body = parseStatement(PScurly);

    f = new UnitTestDeclaration(loc, this->loc);
    f->fbody = body;
    return f;
}

/*****************************************
 * Parse a new definition:
 *      new(arguments) { body }
 * Current token is 'new'.
 */

NewDeclaration *Parser::parseNew()
{
    NewDeclaration *f;
    Parameters *arguments;
    int varargs;
    Loc loc = this->loc;

    nextToken();
    arguments = parseParameters(&varargs);
    f = new NewDeclaration(loc, 0, arguments, varargs);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse a delete definition:
 *      delete(arguments) { body }
 * Current token is 'delete'.
 */

DeleteDeclaration *Parser::parseDelete()
{
    DeleteDeclaration *f;
    Parameters *arguments;
    int varargs;
    Loc loc = this->loc;

    nextToken();
    arguments = parseParameters(&varargs);
    if (varargs)
        error("... not allowed in delete function parameter list");
    f = new DeleteDeclaration(loc, 0, arguments);
    parseContracts(f);
    return f;
}

/**********************************************
 * Parse parameter list.
 */

Parameters *Parser::parseParameters(int *pvarargs)
{
    Parameters *arguments = new Parameters();
    int varargs = 0;
    int hasdefault = 0;

    check(TOKlparen, "start of parameter list");
    while (1)
    {   Type *tb;
        Identifier *ai = NULL;
        Type *at;
        Parameter *a;
        StorageClass storageClass = 0;
        Expression *ae;

        storageClass = STCin;           // parameter is "in" by default
        switch (token.value)
        {
            case TOKrparen:
                break;

            case TOKdotdotdot:
                varargs = 1;
                nextToken();
                break;

            case TOKin:
                storageClass = STCin;
                nextToken();
                goto L1;

            case TOKout:
                storageClass = STCout;
                nextToken();
                goto L1;

            case TOKinout:
            case TOKref:
                storageClass = STCref;
                nextToken();
                goto L1;

            case TOKlazy:
                storageClass = STClazy;
                nextToken();
                goto L1;

            default:
            L1:
                tb = parseBasicType();
                at = parseDeclarator(tb, &ai);
                ae = NULL;
                if (token.value == TOKassign)   // = defaultArg
                {   nextToken();
                    ae = parseDefaultInitExp();
                    hasdefault = 1;
                }
                else
                {   if (hasdefault)
                        error("default argument expected for %s",
                                ai ? ai->toChars() : at->toChars());
                }
                if (token.value == TOKdotdotdot)
                {   /* This is:
                     *  at ai ...
                     */

                    if (storageClass & (STCout | STCref))
                        error("variadic argument cannot be out or ref");
                    varargs = 2;
                    a = new Parameter(storageClass, at, ai, ae);
                    arguments->push(a);
                    nextToken();
                    break;
                }
                a = new Parameter(storageClass, at, ai, ae);
                arguments->push(a);
                if (token.value == TOKcomma)
                {   nextToken();
                    continue;
                }
                break;
        }
        break;
    }
    check(TOKrparen);
    *pvarargs = varargs;
    return arguments;
}


/*************************************
 */

EnumDeclaration *Parser::parseEnum()
{   EnumDeclaration *e;
    Identifier *id;
    Type *memtype;
    Loc loc = this->loc;

    //printf("Parser::parseEnum()\n");
    nextToken();
    if (token.value == TOKidentifier)
    {   id = token.ident;
        nextToken();
    }
    else
        id = NULL;

    if (token.value == TOKcolon)
    {
        nextToken();
        memtype = parseBasicType();
    }
    else
        memtype = NULL;

    e = new EnumDeclaration(loc, id, memtype);
    if (token.value == TOKsemicolon && id)
        nextToken();
    else if (token.value == TOKlcurly)
    {
        //printf("enum definition\n");
        e->members = new Dsymbols();
        nextToken();
        unsigned char *comment = token.blockComment;
        while (token.value != TOKrcurly)
        {
            if (token.value == TOKidentifier)
            {
                Expression *value;
                Identifier *ident;

                loc = this->loc;
                ident = token.ident;
                value = NULL;
                nextToken();
                if (token.value == TOKassign)
                {
                    nextToken();
                    value = parseAssignExp();
                }
                EnumMember *em = new EnumMember(loc, ident, value);
                e->members->push(em);

                if (token.value == TOKrcurly)
                    ;
                else
                {   addComment(em, comment);
                    comment = NULL;
                    check(TOKcomma, "enum member");
                }
                addComment(em, comment);
                comment = token.blockComment;
            }
            else
            {   error("enum member expected");
                nextToken();
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

Dsymbol *Parser::parseAggregate()
{   AggregateDeclaration *a = NULL;
    int anon = 0;
    enum TOK tok;
    Identifier *id;
    TemplateParameters *tpl = NULL;
    Expression *constraint = NULL;

    //printf("Parser::parseAggregate()\n");
    tok = token.value;
    nextToken();
    if (token.value != TOKidentifier)
    {   id = NULL;
    }
    else
    {   id = token.ident;
        nextToken();

        if (token.value == TOKlparen)
        {   // Class template declaration.

            // Gather template parameter list
            tpl = parseTemplateParameterList();
        }
    }

    Loc loc = this->loc;
    switch (tok)
    {   case TOKclass:
        case TOKinterface:
        {
            if (!id)
                error("anonymous classes not allowed");

            // Collect base class(es)
            BaseClasses *baseclasses = NULL;
            if (token.value == TOKcolon)
            {
                nextToken();
                baseclasses = parseBaseClasses();

                if (token.value != TOKlcurly)
                    error("members expected");
            }

            if (tok == TOKclass)
                a = new ClassDeclaration(loc, id, baseclasses);
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
            break;
    }
    if (a && token.value == TOKsemicolon)
    {   nextToken();
    }
    else if (token.value == TOKlcurly)
    {
        //printf("aggregate definition\n");
        nextToken();
        Dsymbols *decl = parseDeclDefs(0);
        if (token.value != TOKrcurly)
            error("} expected following member declarations in aggregate");
        nextToken();
        if (anon)
        {
            /* Anonymous structs/unions are more like attributes.
             */
            return new AnonDeclaration(loc, anon - 1, decl);
        }
        else
            a->members = decl;
    }
    else
    {
        error("{ } expected following aggregate declaration");
        a = new StructDeclaration(loc, NULL);
    }

    if (tpl)
    {   // Wrap a template around the aggregate declaration

        Dsymbols *decldefs = new Dsymbols();
        decldefs->push(a);
        TemplateDeclaration *tempdecl =
                new TemplateDeclaration(loc, id, tpl, constraint, decldefs);
        return tempdecl;
    }

    return a;
}

/*******************************************
 */

BaseClasses *Parser::parseBaseClasses()
{
    BaseClasses *baseclasses = new BaseClasses();

    for (; 1; nextToken())
    {
        bool prot = false;
        enum PROT protection = PROTpublic;
        switch (token.value)
        {
            case TOKprivate:
                prot = true;
                protection = PROTprivate;
                nextToken();
                break;
            case TOKpackage:
                prot = true;
                protection = PROTpackage;
                nextToken();
                break;
            case TOKprotected:
                prot = true;
                protection = PROTprotected;
                nextToken();
                break;
            case TOKpublic:
                prot = true;
                protection = PROTpublic;
                nextToken();
                break;
        }
        if (token.value == TOKidentifier || token.value == TOKdot)
        {
            BaseClass *b = new BaseClass(parseBasicType(), protection);
            baseclasses->push(b);
            if (token.value != TOKcomma)
                break;
        }
        else
        {
            error("base classes expected instead of %s", token.toChars());
            return NULL;
        }
    }
    return baseclasses;
}

/**************************************
 * Parse constraint.
 * Constraint is of the form:
 *      if ( ConstraintExpression )
 */

#if DMDV2
Expression *Parser::parseConstraint()
{   Expression *e = NULL;

    if (token.value == TOKif)
    {
        nextToken();    // skip over 'if'
        check(TOKlparen, "if");
        e = parseExpression();
        check(TOKrparen);
    }
    return e;
}
#endif

/**************************************
 * Parse a TemplateDeclaration.
 */

TemplateDeclaration *Parser::parseTemplateDeclaration()
{
    TemplateDeclaration *tempdecl;
    Identifier *id;
    TemplateParameters *tpl;
    Dsymbols *decldefs;
    Loc loc = this->loc;

    nextToken();
    if (token.value != TOKidentifier)
    {   error("TemplateIdentifier expected following template");
        goto Lerr;
    }
    id = token.ident;
    nextToken();
    tpl = parseTemplateParameterList();
    if (!tpl)
        goto Lerr;

    if (token.value != TOKlcurly)
    {   error("members of template declaration expected");
        goto Lerr;
    }
    else
    {
        nextToken();
        decldefs = parseDeclDefs(0);
        if (token.value != TOKrcurly)
        {   error("template member expected");
            goto Lerr;
        }
        nextToken();
    }

    tempdecl = new TemplateDeclaration(loc, id, tpl, NULL, decldefs);
    return tempdecl;

Lerr:
    return NULL;
}

/******************************************
 * Parse template parameter list.
 * Input:
 *      flag    0: parsing "( list )"
 *              1: parsing non-empty "list )"
 */

TemplateParameters *Parser::parseTemplateParameterList(int flag)
{
    TemplateParameters *tpl = new TemplateParameters();

    if (token.value != TOKlparen)
    {   error("parenthesized TemplateParameterList expected following TemplateIdentifier");
        goto Lerr;
    }
    nextToken();

    // Get array of TemplateParameters
    if (token.value != TOKrparen)
    {   int isvariadic = 0;

        while (1)
        {   TemplateParameter *tp;
            Identifier *tp_ident = NULL;
            Type *tp_spectype = NULL;
            Type *tp_valtype = NULL;
            Type *tp_defaulttype = NULL;
            Expression *tp_specvalue = NULL;
            Expression *tp_defaultvalue = NULL;
            Token *t;

            // Get TemplateParameter

            // First, look ahead to see if it is a TypeParameter or a ValueParameter
            t = peek(&token);
            if (token.value == TOKalias)
            {   // AliasParameter
                nextToken();
                if (token.value != TOKidentifier)
                {   error("Identifier expected for template parameter");
                    goto Lerr;
                }
                tp_ident = token.ident;
                nextToken();
                if (token.value == TOKcolon)    // : Type
                {
                    nextToken();
                    tp_spectype = parseBasicType();
                    tp_spectype = parseDeclarator(tp_spectype, NULL);
                }
                if (token.value == TOKassign)   // = Type
                {
                    nextToken();
                    tp_defaulttype = parseBasicType();
                    tp_defaulttype = parseDeclarator(tp_defaulttype, NULL);
                }
                tp = new TemplateAliasParameter(loc, tp_ident, tp_spectype, tp_defaulttype);
            }
            else if (t->value == TOKcolon || t->value == TOKassign ||
                     t->value == TOKcomma || t->value == TOKrparen)
            {   // TypeParameter
                if (token.value != TOKidentifier)
                {   error("identifier expected for template type parameter");
                    goto Lerr;
                }
                tp_ident = token.ident;
                nextToken();
                if (token.value == TOKcolon)    // : Type
                {
                    nextToken();
                    tp_spectype = parseBasicType();
                    tp_spectype = parseDeclarator(tp_spectype, NULL);
                }
                if (token.value == TOKassign)   // = Type
                {
                    nextToken();
                    tp_defaulttype = parseBasicType();
                    tp_defaulttype = parseDeclarator(tp_defaulttype, NULL);
                }
                tp = new TemplateTypeParameter(loc, tp_ident, tp_spectype, tp_defaulttype);
            }
            else if (token.value == TOKidentifier && t->value == TOKdotdotdot)
            {   // ident...
                if (isvariadic)
                    error("variadic template parameter must be last");
                isvariadic = 1;
                tp_ident = token.ident;
                nextToken();
                nextToken();
                tp = new TemplateTupleParameter(loc, tp_ident);
            }
#if DMDV2
            else if (token.value == TOKthis)
            {   // ThisParameter
                nextToken();
                if (token.value != TOKidentifier)
                {   error("identifier expected for template this parameter");
                    goto Lerr;
                }
                tp_ident = token.ident;
                nextToken();
                if (token.value == TOKcolon)    // : Type
                {
                    nextToken();
                    tp_spectype = parseType();
                }
                if (token.value == TOKassign)   // = Type
                {
                    nextToken();
                    tp_defaulttype = parseType();
                }
                tp = new TemplateThisParameter(loc, tp_ident, tp_spectype, tp_defaulttype);
            }
#endif
            else
            {   // ValueParameter
                tp_valtype = parseBasicType();
                tp_valtype = parseDeclarator(tp_valtype, &tp_ident);
                if (!tp_ident)
                {
                    error("identifier expected for template value parameter");
                    tp_ident = new Identifier("error", TOKidentifier);
                }
                if (token.value == TOKcolon)    // : CondExpression
                {
                    nextToken();
                    tp_specvalue = parseCondExp();
                }
                if (token.value == TOKassign)   // = CondExpression
                {
                    nextToken();
                    tp_defaultvalue = parseDefaultInitExp();
                }
                tp = new TemplateValueParameter(loc, tp_ident, tp_valtype, tp_specvalue, tp_defaultvalue);
            }
            tpl->push(tp);
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

Dsymbol *Parser::parseMixin()
{
    TemplateMixin *tm;
    Identifier *id;
    Type *tqual;
    Objects *tiargs;
    Identifiers *idents;

    //printf("parseMixin()\n");
    nextToken();
    tqual = NULL;
    if (token.value == TOKdot)
    {
        id = Id::empty;
    }
    else
    {
        if (token.value == TOKtypeof)
        {   Expression *exp;

            nextToken();
            check(TOKlparen);
            exp = parseExpression();
            check(TOKrparen);
            tqual = new TypeTypeof(loc, exp);
            check(TOKdot, "typeof (expression)");
        }
        if (token.value != TOKidentifier)
        {
            error("identifier expected, not %s", token.toChars());
            id = Id::empty;
        }
        else
            id = token.ident;
        nextToken();
    }

    idents = new Identifiers();
    while (1)
    {
        tiargs = NULL;
        if (token.value == TOKnot)
        {
            nextToken();
            tiargs = parseTemplateArgumentList();
        }

        if (token.value != TOKdot)
            break;

        if (tiargs)
        {   TemplateInstance *tempinst = new TemplateInstance(loc, id);
            tempinst->tiargs = tiargs;
            id = (Identifier *)tempinst;
            tiargs = NULL;
        }
        idents->push(id);

        nextToken();
        if (token.value != TOKidentifier)
        {   error("identifier expected following '.' instead of '%s'", token.toChars());
            break;
        }
        id = token.ident;
        nextToken();
    }
    idents->push(id);

    if (token.value == TOKidentifier)
    {
        id = token.ident;
        nextToken();
    }
    else
        id = NULL;

    tm = new TemplateMixin(loc, id, tqual, idents, tiargs);
    check(TOKsemicolon, "template mixin");
    return tm;
}

/******************************************
 * Parse template argument list.
 * Input:
 *      current token is opening '('
 * Output:
 *      current token is one after closing ')'
 */

Objects *Parser::parseTemplateArgumentList()
{
    //printf("Parser::parseTemplateArgumentList()\n");
    Objects *tiargs = new Objects();
    if (token.value != TOKlparen)
    {   error("!(TemplateArgumentList) expected following TemplateIdentifier");
        return tiargs;
    }
    nextToken();

    // Get TemplateArgumentList
    if (token.value != TOKrparen)
    {
        while (1)
        {
            // See if it is an Expression or a Type
            if (isDeclaration(&token, 0, TOKreserved, NULL))
            {   // Type
                // Get TemplateArgument
                Type *ta = parseBasicType();
                ta = parseDeclarator(ta, NULL);
                tiargs->push(ta);
            }
            else
            {   // Template argument is an expression
                Expression *ea = parseAssignExp();
                tiargs->push(ea);
            }
            if (token.value != TOKcomma)
                break;
            nextToken();
        }
    }
    check(TOKrparen, "template argument list");
    return tiargs;
}

Import *Parser::parseImport(Dsymbols *decldefs, int isstatic)
{   Import *s;
    Identifier *id;
    Identifier *aliasid = NULL;
    Identifiers *a;
    Loc loc;

    //printf("Parser::parseImport()\n");
    do
    {
     L1:
        nextToken();
        if (token.value != TOKidentifier)
        {   error("Identifier expected following import");
            break;
        }

        loc = this->loc;
        a = NULL;
        id = token.ident;
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
            a->push(id);
            nextToken();
            if (token.value != TOKidentifier)
            {   error("identifier expected following package");
                break;
            }
            id = token.ident;
            nextToken();
        }

        s = new Import(loc, a, id, aliasid, isstatic);
        decldefs->push(s);

        /* Look for
         *      : alias=name, alias=name;
         * syntax.
         */
        if (token.value == TOKcolon)
        {
            do
            {   Identifier *name;

                nextToken();
                if (token.value != TOKidentifier)
                {   error("Identifier expected following :");
                    break;
                }
                Identifier *alias = token.ident;
                nextToken();
                if (token.value == TOKassign)
                {
                    nextToken();
                    if (token.value != TOKidentifier)
                    {   error("Identifier expected following %s=", alias->toChars());
                        break;
                    }
                    name = token.ident;
                    nextToken();
                }
                else
                {   name = alias;
                    alias = NULL;
                }
                s->addAlias(name, alias);
            } while (token.value == TOKcomma);
            break;      // no comma-separated imports of this form
        }

        aliasid = NULL;
    } while (token.value == TOKcomma);

    if (token.value == TOKsemicolon)
        nextToken();
    else
    {
        check(TOKsemicolon, "import declaration");
    }

    return NULL;
}

#if DMDV2
Type *Parser::parseType(Identifier **pident, TemplateParameters **tpl)
{   Type *t;

    /* Take care of the storage class prefixes that
     * serve as type attributes:
     *  const shared, shared const, const, invariant, shared
     */
    if (token.value == TOKconst && peekNext() == TOKshared && peekNext2() != TOKlparen ||
        token.value == TOKshared && peekNext() == TOKconst && peekNext2() != TOKlparen)
    {
        nextToken();
        nextToken();
        /* shared const type
         */
        t = parseType(pident, tpl);
        t = t->makeSharedConst();
        return t;
    }
    else if (token.value == TOKwild && peekNext() == TOKshared && peekNext2() != TOKlparen ||
        token.value == TOKshared && peekNext() == TOKwild && peekNext2() != TOKlparen)
    {
        nextToken();
        nextToken();
        /* shared wild type
         */
        t = parseType(pident, tpl);
        t = t->makeSharedWild();
        return t;
    }
    else if (token.value == TOKconst && peekNext() != TOKlparen)
    {
        nextToken();
        /* const type
         */
        t = parseType(pident, tpl);
        t = t->makeConst();
        return t;
    }
    else if ((token.value == TOKinvariant || token.value == TOKimmutable) &&
             peekNext() != TOKlparen)
    {
        nextToken();
        /* invariant type
         */
        t = parseType(pident, tpl);
        t = t->makeInvariant();
        return t;
    }
    else if (token.value == TOKshared && peekNext() != TOKlparen)
    {
        nextToken();
        /* shared type
         */
        t = parseType(pident, tpl);
        t = t->makeShared();
        return t;
    }
    else if (token.value == TOKwild && peekNext() != TOKlparen)
    {
        nextToken();
        /* wild type
         */
        t = parseType(pident, tpl);
        t = t->makeWild();
        return t;
    }
    else
        t = parseBasicType();
    t = parseDeclarator(t, pident, tpl);
    return t;
}
#endif

Type *Parser::parseBasicType()
{   Type *t;
    Identifier *id;
    TypeQualified *tid;

    //printf("parseBasicType()\n");
    switch (token.value)
    {
        case BASIC_TYPES_X(t):
            nextToken();
            break;

        case TOKidentifier:
            id = token.ident;
            nextToken();
            if (token.value == TOKnot)
            {   // ident!(template_arguments)
                TemplateInstance *tempinst = new TemplateInstance(loc, id);
                nextToken();
                tempinst->tiargs = parseTemplateArgumentList();
                tid = new TypeInstance(loc, tempinst);
                goto Lident2;
            }
        Lident:
            tid = new TypeIdentifier(loc, id);
        Lident2:
            while (token.value == TOKdot)
            {   nextToken();
                if (token.value != TOKidentifier)
                {   error("identifier expected following '.' instead of '%s'", token.toChars());
                    break;
                }
                id = token.ident;
                nextToken();
                if (token.value == TOKnot)
                {
                    nextToken();
                    TemplateInstance *tempinst = new TemplateInstance(loc, id);
                    tempinst->tiargs = parseTemplateArgumentList();
                    tid->addInst(tempinst);
                }
                else
                    tid->addIdent(id);
            }
            t = tid;
            break;

        case TOKdot:
            // Leading . as in .foo
            id = Id::empty;
            goto Lident;

        case TOKtypeof:
        {
            nextToken();
            check(TOKlparen);
            Expression *exp = parseExpression();
            check(TOKrparen);
            tid = new TypeTypeof(loc, exp);
            goto Lident2;
        }

        default:
            error("basic type expected, not %s", token.toChars());
            t = Type::tint32;
            break;
    }
    return t;
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

Type *Parser::parseBasicType2(Type *t)
{
    Type *ts;
    Type *ta;

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
#if LTORARRAYDECL
                // Handle []. Make sure things like
                //     int[3][1] a;
                // is (array[1] of array[3] of int)
                nextToken();
                if (token.value == TOKrbracket)
                {
                    t = new TypeDArray(t);                      // []
                    nextToken();
                }
                else if (isDeclaration(&token, 0, TOKrbracket, NULL))
                {   // It's an associative array declaration

                    //printf("it's an associative array\n");
                    Type *index = parseBasicType();
                    index = parseDeclarator(index, NULL);       // [ type ]
                    t = new TypeAArray(t, index);
                    check(TOKrbracket);
                }
                else
                {
                    //printf("it's [expression]\n");
                    inBrackets++;
                    Expression *e = parseExpression();          // [ expression ]
                    if (token.value == TOKslice)
                    {
                        nextToken();
                        Expression *e2 = parseExpression();                 // [ exp .. exp ]
                        t = new TypeSlice(t, e, e2);
                    }
                    else
                        t = new TypeSArray(t,e);
                    inBrackets--;
                    check(TOKrbracket);
                }
                continue;
#else
                // Handle []. Make sure things like
                //     int[3][1] a;
                // is (array[3] of array[1] of int)
                ts = t;
                while (token.value == TOKlbracket)
                {
                    nextToken();
                    if (token.value == TOKrbracket)
                    {
                        ta = new TypeDArray(t);                 // []
                        nextToken();
                    }
                    else if (isDeclaration(&token, 0, TOKrbracket, NULL))
                    {   // It's an associative array declaration
                        Type *index;

                        //printf("it's an associative array\n");
                        index = parseBasicType();
                        index = parseDeclarator(index, NULL);   // [ type ]
                        check(TOKrbracket);
                        ta = new TypeAArray(t, index);
                    }
                    else
                    {
                        //printf("it's [expression]\n");
                        Expression *e = parseExpression();      // [ expression ]
                        ta = new TypeSArray(t,e);
                        check(TOKrbracket);
                    }
                    Type **pt;
                    for (pt = &ts; *pt != t; pt = &(*pt)->next)
                        ;
                    *pt = ta;
                }
                t = ts;
                continue;
#endif

            case TOKdelegate:
            case TOKfunction:
            {   // Handle delegate declaration:
                //      t delegate(parameter list)
                //      t function(parameter list)
                Parameters *arguments;
                int varargs;
                enum TOK save = token.value;

                nextToken();
                arguments = parseParameters(&varargs);
                t = new TypeFunction(arguments, t, varargs, linkage);
                if (save == TOKdelegate)
                    t = new TypeDelegate(t);
                else
                    t = new TypePointer(t);     // pointer to function
                continue;
            }

            default:
                ts = t;
                break;
        }
        break;
    }
    return ts;
}

Type *Parser::parseDeclarator(Type *t, Identifier **pident, TemplateParameters **tpl)
{   Type *ts;
    Type *ta;

    //printf("parseDeclarator(tpl = %p)\n", tpl);
    t = parseBasicType2(t);

    switch (token.value)
    {

        case TOKidentifier:
            if (pident)
                *pident = token.ident;
            else
                error("unexpected identifer '%s' in declarator", token.ident->toChars());
            ts = t;
            nextToken();
            break;

        case TOKlparen:
            /* Parse things with parentheses around the identifier, like:
             *  int (*ident[3])[]
             * although the D style would be:
             *  int[]*[3] ident
             */
            nextToken();
            ts = parseDeclarator(t, pident);
            check(TOKrparen);
            break;

        default:
            ts = t;
            break;
    }

    // parse DeclaratorSuffixes
    while (1)
    {
        switch (token.value)
        {
#if CARRAYDECL
            /* Support C style array syntax:
             *   int ident[]
             * as opposed to D-style:
             *   int[] ident
             */
            case TOKlbracket:
            {   // This is the old C-style post [] syntax.
                nextToken();
                if (token.value == TOKrbracket)
                {   // It's a dynamic array
                    ta = new TypeDArray(t);             // []
                    nextToken();
                }
                else if (isDeclaration(&token, 0, TOKrbracket, NULL))
                {   // It's an associative array declaration

                    //printf("it's an associative array\n");
                    Type *index = parseBasicType();
                    index = parseDeclarator(index, NULL);       // [ type ]
                    check(TOKrbracket);
                    ta = new TypeAArray(t, index);
                }
                else
                {
                    //printf("it's [expression]\n");
                    Expression *e = parseExpression();          // [ expression ]
                    ta = new TypeSArray(t, e);
                    check(TOKrbracket);
                }

                /* Insert ta into
                 *   ts -> ... -> t
                 * so that
                 *   ts -> ... -> ta -> t
                 */
                Type **pt;
                for (pt = &ts; *pt != t; pt = &(*pt)->next)
                    ;
                *pt = ta;
                continue;
            }
#endif
            case TOKlparen:
            {
                if (tpl)
                {
                    /* Look ahead to see if this is (...)(...),
                     * i.e. a function template declaration
                     */
                    if (peekPastParen(&token)->value == TOKlparen)
                    {
                        //printf("function template declaration\n");

                        // Gather template parameter list
                        *tpl = parseTemplateParameterList();
                    }
                }

                int varargs;
                Parameters *arguments = parseParameters(&varargs);
                Type *ta = new TypeFunction(arguments, t, varargs, linkage);
                Type **pt;
                for (pt = &ts; *pt != t; pt = &(*pt)->next)
                    ;
                *pt = ta;
                break;
            }
        }
        break;
    }

    return ts;
}

/**********************************
 * Parse Declarations.
 * These can be:
 *      1. declarations at global/class level
 *      2. declarations at statement level
 * Return array of Declaration *'s.
 */

Dsymbols *Parser::parseDeclarations()
{
    StorageClass storage_class;
    StorageClass stc;
    Type *ts;
    Type *t;
    Type *tfirst;
    Identifier *ident;
    Dsymbols *a;
    enum TOK tok = TOKreserved;
    unsigned char *comment = token.blockComment;
    enum LINK link = linkage;

    //printf("parseDeclarations()\n");
    switch (token.value)
    {
        case TOKtypedef:
        case TOKalias:
            tok = token.value;
            nextToken();
            break;

        default:
            tok = TOKreserved;
            break;
    }

    storage_class = STCundefined;
    while (1)
    {
        switch (token.value)
        {
            case TOKconst:      stc = STCconst;          goto L1;
            case TOKstatic:     stc = STCstatic;         goto L1;
            case TOKfinal:      stc = STCfinal;          goto L1;
            case TOKauto:       stc = STCauto;           goto L1;
            case TOKscope:      stc = STCscope;          goto L1;
            case TOKoverride:   stc = STCoverride;       goto L1;
            case TOKabstract:   stc = STCabstract;       goto L1;
            case TOKsynchronized: stc = STCsynchronized; goto L1;
            case TOKdeprecated: stc = STCdeprecated;     goto L1;
#if DMDV2
            case TOKnothrow:    stc = STCnothrow;        goto L1;
            case TOKpure:       stc = STCpure;           goto L1;
            case TOKref:        stc = STCref;            goto L1;
            case TOKtls:        stc = STCtls;            goto L1;
            case TOKenum:       stc = STCmanifest;       goto L1;
#endif
            L1:
                if (storage_class & stc)
                    error("redundant storage class '%s'", token.toChars());
                storage_class = (STC) (storage_class | stc);
                nextToken();
                continue;

            case TOKextern:
                if (peek(&token)->value != TOKlparen)
                {   stc = STCextern;
                    goto L1;
                }

                link = parseLinkage();
                continue;

            default:
                break;
        }
        break;
    }

    a = new Dsymbols();

    /* Look for auto initializers:
     *  storage_class identifier = initializer;
     */
    while (storage_class &&
        token.value == TOKidentifier &&
        peek(&token)->value == TOKassign)
    {
        ident = token.ident;
        nextToken();
        nextToken();
        Initializer *init = parseInitializer();
        VarDeclaration *v = new VarDeclaration(loc, NULL, ident, init);
        v->storage_class = storage_class;
        a->push(v);
        if (token.value == TOKsemicolon)
        {
            nextToken();
            addComment(v, comment);
        }
        else if (token.value == TOKcomma)
        {
            nextToken();
            if (!(token.value == TOKidentifier && peek(&token)->value == TOKassign))
            {
                error("Identifier expected following comma");
            }
            else
                continue;
        }
        else
            error("semicolon expected following auto declaration, not '%s'", token.toChars());
        return a;
    }

    if (token.value == TOKclass)
    {   AggregateDeclaration *s;

        s = (AggregateDeclaration *)parseAggregate();
        s->storage_class |= storage_class;
        a->push(s);
        addComment(s, comment);
        return a;
    }

    ts = parseBasicType();
    ts = parseBasicType2(ts);
    tfirst = NULL;

    while (1)
    {
        Loc loc = this->loc;
        TemplateParameters *tpl = NULL;

        ident = NULL;
        t = parseDeclarator(ts, &ident, &tpl);
        assert(t);
        if (!tfirst)
            tfirst = t;
        else if (t != tfirst)
            error("multiple declarations must have the same type, not %s and %s",
                tfirst->toChars(), t->toChars());
        if (!ident)
            error("no identifier for declarator %s", t->toChars());

        if (tok == TOKtypedef || tok == TOKalias)
        {   Declaration *v;
            Initializer *init = NULL;

            if (token.value == TOKassign)
            {
                nextToken();
                init = parseInitializer();
            }
            if (tok == TOKtypedef)
            {
                v = new TypedefDeclaration(loc, ident, t, init);
            }
            else
            {   if (init)
                    error("alias cannot have initializer");
                v = new AliasDeclaration(loc, ident, t);
            }
            v->storage_class = storage_class;
            if (link == linkage)
                a->push(v);
            else
            {
                Dsymbols *ax = new Dsymbols();
                ax->push(v);
                Dsymbol *s = new LinkDeclaration(link, ax);
                a->push(s);
            }
            switch (token.value)
            {   case TOKsemicolon:
                    nextToken();
                    addComment(v, comment);
                    break;

                case TOKcomma:
                    nextToken();
                    addComment(v, comment);
                    continue;

                default:
                    error("semicolon expected to close %s declaration", Token::toChars(tok));
                    break;
            }
        }
        else if (t->ty == Tfunction)
        {   FuncDeclaration *f =
                new FuncDeclaration(loc, 0, ident, storage_class, t);
            addComment(f, comment);
            parseContracts(f);
            addComment(f, NULL);
            Dsymbol *s;
            if (link == linkage)
            {
                s = f;
            }
            else
            {
                Dsymbols *ax = new Dsymbols();
                ax->push(f);
                s = new LinkDeclaration(link, ax);
            }
            if (tpl)                    // it's a function template
            {
                // Wrap a template around the aggregate declaration
                Dsymbols *decldefs = new Dsymbols();
                decldefs->push(s);
                TemplateDeclaration *tempdecl =
                    new TemplateDeclaration(loc, s->ident, tpl, NULL, decldefs);
                s = tempdecl;
            }
            addComment(s, comment);
            a->push(s);
        }
        else
        {
            Initializer *init = NULL;
            if (token.value == TOKassign)
            {
                nextToken();
                init = parseInitializer();
            }

            VarDeclaration *v = new VarDeclaration(loc, t, ident, init);
            v->storage_class = storage_class;
            if (link == linkage)
                a->push(v);
            else
            {
                Dsymbols *ax = new Dsymbols();
                ax->push(v);
                Dsymbol *s = new LinkDeclaration(link, ax);
                a->push(s);
            }
            switch (token.value)
            {   case TOKsemicolon:
                    nextToken();
                    addComment(v, comment);
                    break;

                case TOKcomma:
                    nextToken();
                    addComment(v, comment);
                    continue;

                default:
                    error("semicolon expected to close declaration, not '%s'", token.toChars());
                    break;
            }
        }
        break;
    }
    return a;
}

/*****************************************
 * Parse auto declarations of the form:
 *   storageClass ident = init, ident = init, ... ;
 * and return the array of them.
 * Starts with token on the first ident.
 * Ends with scanner past closing ';'
 */

#if DMDV2
Dsymbols *Parser::parseAutoDeclarations(StorageClass storageClass, unsigned char *comment)
{
    Dsymbols *a = new Dsymbols;

    while (1)
    {
        Identifier *ident = token.ident;
        nextToken();            // skip over ident
        assert(token.value == TOKassign);
        nextToken();            // skip over '='
        Initializer *init = parseInitializer();
        VarDeclaration *v = new VarDeclaration(loc, NULL, ident, init);
        v->storage_class = storageClass;
        a->push(v);
        if (token.value == TOKsemicolon)
        {
            nextToken();
            addComment(v, comment);
        }
        else if (token.value == TOKcomma)
        {
            nextToken();
            if (token.value == TOKidentifier &&
                peek(&token)->value == TOKassign)
            {
                addComment(v, comment);
                continue;
            }
            else
                error("Identifier expected following comma");
        }
        else
            error("semicolon expected following auto declaration, not '%s'", token.toChars());
        break;
    }
    return a;
}
#endif

/*****************************************
 * Parse contracts following function declaration.
 */

void Parser::parseContracts(FuncDeclaration *f)
{
    enum LINK linksave = linkage;

    // The following is irrelevant, as it is overridden by sc->linkage in
    // TypeFunction::semantic
    linkage = LINKd;            // nested functions have D linkage
L1:
    switch (token.value)
    {
        case TOKlcurly:
            if (f->frequire || f->fensure)
                error("missing body { ... } after in or out");
            f->fbody = parseStatement(PSsemi);
            f->endloc = endloc;
            break;

        case TOKbody:
            nextToken();
            f->fbody = parseStatement(PScurly);
            f->endloc = endloc;
            break;

        case TOKsemicolon:
            if (f->frequire || f->fensure)
                error("missing body { ... } after in or out");
            nextToken();
            break;

#if 0   // Do we want this for function declarations, so we can do:
    // int x, y, foo(), z;
        case TOKcomma:
            nextToken();
            continue;
#endif

#if 0 // Dumped feature
        case TOKthrow:
            if (!f->fthrows)
                f->fthrows = new Array();
            nextToken();
            check(TOKlparen);
            while (1)
            {
                Type *tb = parseBasicType();
                f->fthrows->push(tb);
                if (token.value == TOKcomma)
                {   nextToken();
                    continue;
                }
                break;
            }
            check(TOKrparen);
            goto L1;
#endif

        case TOKin:
            nextToken();
            if (f->frequire)
                error("redundant 'in' statement");
            f->frequire = parseStatement(PScurly | PSscope);
            goto L1;

        case TOKout:
            // parse: out (identifier) { statement }
            nextToken();
            if (token.value != TOKlcurly)
            {
                check(TOKlparen, "out");
                if (token.value != TOKidentifier)
                    error("(identifier) following 'out' expected, not %s", token.toChars());
                f->outId = token.ident;
                nextToken();
                check(TOKrparen);
            }
            if (f->fensure)
                error("redundant 'out' statement");
            f->fensure = parseStatement(PScurly | PSscope);
            goto L1;

        default:
            error("semicolon expected following function declaration");
            break;
    }
    linkage = linksave;
}

/*****************************************
 * Parse initializer for variable declaration.
 */

Initializer *Parser::parseInitializer()
{
    StructInitializer *is;
    ArrayInitializer *ia;
    ExpInitializer *ie;
    Expression *e;
    Identifier *id;
    Initializer *value;
    int comma;
    Loc loc = this->loc;
    Token *t;
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
                switch (t->value)
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

            is = new StructInitializer(loc);
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
                        if (t->value == TOKcolon)
                        {
                            id = token.ident;
                            nextToken();
                            nextToken();        // skip over ':'
                        }
                        else
                        {   id = NULL;
                        }
                        value = parseInitializer();
                        is->addInit(id, value);
                        comma = 1;
                        continue;

                    case TOKcomma:
                        if (comma == 2)
                            error("expression expected, not ','");
                        nextToken();
                        comma = 2;
                        continue;

                    case TOKrcurly:             // allow trailing comma's
                        nextToken();
                        break;

                    case TOKeof:
                        error("found EOF instead of initializer");
                        break;

                    default:
                        if (comma == 1)
                            error("comma expected separating field initializers");
                        value = parseInitializer();
                        is->addInit(NULL, value);
                        comma = 1;
                        continue;
                        //error("found '%s' instead of field initializer", token.toChars());
                        //break;
                }
                break;
            }
            return is;

        case TOKlbracket:
            /* Scan ahead to see if it is an array initializer or
             * an expression.
             * If it ends with a ';', it is an array initializer.
             */
            brackets = 1;
            for (t = peek(&token); 1; t = peek(t))
            {
                switch (t->value)
                {
                    case TOKlbracket:
                        brackets++;
                        continue;

                    case TOKrbracket:
                        if (--brackets == 0)
                        {   t = peek(t);
                            if (t->value != TOKsemicolon &&
                                t->value != TOKcomma &&
                                t->value != TOKrbracket &&
                                t->value != TOKrcurly)
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
                        {   error("comma expected separating array initializers, not %s", token.toChars());
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
                        {   value = new ExpInitializer(e->loc, e);
                            e = NULL;
                        }
                        ia->addInit(e, value);
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
                            e = value->toExpression();
                            value = parseInitializer();
                        }
                        else
                            e = NULL;
                        ia->addInit(e, value);
                        comma = 1;
                        continue;

                    case TOKcomma:
                        if (comma == 2)
                            error("expression expected, not ','");
                        nextToken();
                        comma = 2;
                        continue;

                    case TOKrbracket:           // allow trailing comma's
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
            if (t->value == TOKsemicolon || t->value == TOKcomma)
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
 * with special handling for __FILE__ and __LINE__.
 */

Expression *Parser::parseDefaultInitExp()
{
    if (token.value == TOKfile ||
        token.value == TOKline)
    {
        Token *t = peek(&token);
        if (t->value == TOKcomma || t->value == TOKrparen)
        {
            Expression *e;
            if (token.value == TOKfile)
                e = new FileInitExp(loc);
            else
                e = new LineInitExp(loc);
            nextToken();
            return e;
        }
    }

    Expression *e = parseAssignExp();
    return e;
}


/*****************************************
 * Input:
 *      flags   PSxxxx
 */

Statement *Parser::parseStatement(int flags)
{   Statement *s;
    Token *t;
    Condition *condition;
    Statement *ifbody;
    Statement *elsebody;
    Loc loc = this->loc;

    //printf("parseStatement()\n");

    if (flags & PScurly && token.value != TOKlcurly)
        error("statement expected to be { }, not %s", token.toChars());

    switch (token.value)
    {
        case TOKidentifier:
            /* A leading identifier can be a declaration, label, or expression.
             * The easiest case to check first is label:
             */
            t = peek(&token);
            if (t->value == TOKcolon)
            {   // It's a label

                Identifier *ident = token.ident;
                nextToken();
                nextToken();
                s = parseStatement(PSsemi);
                s = new LabelStatement(loc, ident, s);
                break;
            }
            // fallthrough to TOKdot
        case TOKdot:
        case TOKtypeof:
            if (isDeclaration(&token, 2, TOKreserved, NULL))
                goto Ldeclaration;
            else
                goto Lexp;
            break;

        case TOKassert:
        case TOKthis:
        case TOKsuper:
        case TOKint32v:
        case TOKuns32v:
        case TOKint64v:
        case TOKuns64v:
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
        case TOKlparen:
        case TOKcast:
        case TOKmul:
        case TOKmin:
        case TOKadd:
        case TOKplusplus:
        case TOKminusminus:
        case TOKnew:
        case TOKdelete:
        case TOKdelegate:
        case TOKfunction:
        case TOKtypeid:
        case TOKis:
        case TOKlbracket:
        case TOKfile:
        case TOKline:
        Lexp:
        {
            Expression *exp = parseExpression();
            check(TOKsemicolon, "statement");
            s = new ExpStatement(loc, exp);
            break;
        }

        case TOKstatic:
        {   // Look ahead to see if it's static assert() or static if()
            Token *t;

            t = peek(&token);
            if (t->value == TOKassert)
            {
                nextToken();
                s = new StaticAssertStatement(parseStaticAssert());
                break;
            }
            if (t->value == TOKif)
            {
                nextToken();
                condition = parseStaticIfCondition();
                goto Lcondition;
            }
            goto Ldeclaration;
        }

        case BASIC_TYPES:
        case TOKtypedef:
        case TOKalias:
        case TOKconst:
        case TOKauto:
        case TOKextern:
        case TOKfinal:
        case TOKinvariant:
#if DMDV2
        case TOKimmutable:
        case TOKshared:
        case TOKwild:
        case TOKnothrow:
        case TOKpure:
        case TOKtls:
        case TOKgshared:
        case TOKat:
#endif
//      case TOKtypeof:
        Ldeclaration:
        {   Array *a;

            a = parseDeclarations();
            if (a->dim > 1)
            {
                Statements *as = new Statements();
                as->reserve(a->dim);
                for (size_t i = 0; i < a->dim; i++)
                {
                    Dsymbol *d = (Dsymbol *)a->data[i];
                    s = new ExpStatement(loc, d);
                    as->push(s);
                }
                s = new CompoundDeclarationStatement(loc, as);
            }
            else if (a->dim == 1)
            {
                Dsymbol *d = (Dsymbol *)a->data[0];
                s = new ExpStatement(loc, d);
            }
            else
                assert(0);
            if (flags & PSscope)
                s = new ScopeStatement(loc, s);
            break;
        }

        case TOKstruct:
        case TOKunion:
        case TOKclass:
        case TOKinterface:
        {   Dsymbol *d;

            d = parseAggregate();
            s = new ExpStatement(loc, d);
            break;
        }

        case TOKenum:
        {   Dsymbol *d;

            d = parseEnum();
            s = new ExpStatement(loc, d);
            break;
        }

        case TOKmixin:
        {   t = peek(&token);
            if (t->value == TOKlparen)
            {   // mixin(string)
                Expression *e = parseAssignExp();
                check(TOKsemicolon);
                if (e->op == TOKmixin)
                {
                    CompileExp *cpe = (CompileExp *)e;
                    s = new CompileStatement(loc, cpe->e1);
                }
                else
                {
                    s = new ExpStatement(loc, e);
                }
                break;
            }
            Dsymbol *d = parseMixin();
            s = new ExpStatement(loc, d);
            break;
        }

        case TOKlcurly:
        {
            nextToken();
            Statements *statements = new Statements();
            while (token.value != TOKrcurly && token.value != TOKeof)
            {
                statements->push(parseStatement(PSsemi | PScurlyscope));
            }
            endloc = this->loc;
            s = new CompoundStatement(loc, statements);
            if (flags & (PSscope | PScurlyscope))
                s = new ScopeStatement(loc, s);
            check(TOKrcurly, "compound statement");
            break;
        }

        case TOKwhile:
        {   Expression *condition;
            Statement *body;

            nextToken();
            check(TOKlparen, "while");
            condition = parseExpression();
            check(TOKrparen);
            body = parseStatement(PSscope);
            s = new WhileStatement(loc, condition, body);
            break;
        }

        case TOKsemicolon:
            if (!(flags & PSsemi))
                error("use '{ }' for an empty statement, not a ';'");
            nextToken();
            s = new ExpStatement(loc, (Expression *)NULL);
            break;

        case TOKdo:
        {   Statement *body;
            Expression *condition;

            nextToken();
            body = parseStatement(PSscope);
            check(TOKwhile, "statement");
            check(TOKlparen, "while");
            condition = parseExpression();
            check(TOKrparen);
            if (token.value == TOKsemicolon)
                nextToken();
            else if ((global.params.enabledV2hints & V2MODEsyntax) &&
                    mod && mod->isRoot())
            {
                warning(loc, "D2 requires that 'do { ... } while(...)' "
                        "end with a ';' [-v2=%s]", V2MODE_name(V2MODEsyntax));
            }
            s = new DoStatement(loc, body, condition);
            break;
        }

        case TOKfor:
        {
            Statement *init;
            Expression *condition;
            Expression *increment;
            Statement *body;

            nextToken();
            check(TOKlparen, "for");
            if (token.value == TOKsemicolon)
            {   init = NULL;
                nextToken();
            }
            else
            {   init = parseStatement(0);
            }
            if (token.value == TOKsemicolon)
            {
                condition = NULL;
                nextToken();
            }
            else
            {
                condition = parseExpression();
                check(TOKsemicolon, "for condition");
            }
            if (token.value == TOKrparen)
            {   increment = NULL;
                nextToken();
            }
            else
            {   increment = parseExpression();
                check(TOKrparen);
            }
            body = parseStatement(PSscope);
            s = new ForStatement(loc, init, condition, increment, body);
            if (init)
                s = new ScopeStatement(loc, s);
            break;
        }

        case TOKforeach:
        case TOKforeach_reverse:
        {
            enum TOK op = token.value;

            Statement *d;
            Statement *body;
            Expression *aggr;

            nextToken();
            check(TOKlparen, "foreach");

            Parameters *arguments = new Parameters();

            while (1)
            {
                Type *tb;
                Identifier *ai = NULL;
                Type *at;
                unsigned storageClass;

                storageClass = STCin;
                if (token.value == TOKinout || token.value == TOKref)
                {   storageClass = STCref;
                    nextToken();
                }
                if (token.value == TOKidentifier)
                {
                    Token *t = peek(&token);
                    if (t->value == TOKcomma || t->value == TOKsemicolon)
                    {   ai = token.ident;
                        at = NULL;              // infer argument type
                        nextToken();
                        goto Larg;
                    }
                }
                tb = parseBasicType();
                at = parseDeclarator(tb, &ai);
                if (!ai)
                    error("no identifier for declarator %s", at->toChars());
              Larg:
                Parameter *a = new Parameter(storageClass, at, ai, NULL);
                arguments->push(a);
                if (token.value == TOKcomma)
                {   nextToken();
                    continue;
                }
                break;
            }
            check(TOKsemicolon, "foreach statement");

            aggr = parseExpression();
            check(TOKrparen);
            body = parseStatement(0);
            s = new ForeachStatement(loc, op, arguments, aggr, body);
            break;
        }

        case TOKif:
        {   Parameter *arg = NULL;
            Expression *condition;
            Statement *ifbody;
            Statement *elsebody;

            nextToken();
            check(TOKlparen, "if");

            if (token.value == TOKauto)
            {
                nextToken();
                if (token.value == TOKidentifier)
                {
                    Token *t = peek(&token);
                    if (t->value == TOKassign)
                    {
                        arg = new Parameter(STCin, NULL, token.ident, NULL);
                        nextToken();
                        nextToken();
                    }
                    else
                    {   error("= expected following auto identifier");
                        goto Lerror;
                    }
                }
                else
                {   error("identifier expected following auto");
                    goto Lerror;
                }
            }
            else if (isDeclaration(&token, 2, TOKassign, NULL))
            {
                Type *tb;
                Type *at;
                Identifier *ai;

                tb = parseBasicType();
                at = parseDeclarator(tb, &ai);
                check(TOKassign);
                arg = new Parameter(STCin, at, ai, NULL);
            }

            // Check for " ident;"
            else if (token.value == TOKidentifier)
            {
                Token *t = peek(&token);
                if (t->value == TOKcomma || t->value == TOKsemicolon)
                {
                    arg = new Parameter(STCin, NULL, token.ident, NULL);
                    nextToken();
                    nextToken();
                    error("if (v; e) is no longer valid, use if (auto v = e)");
                }
            }

            condition = parseExpression();
            check(TOKrparen);
            ifbody = parseStatement(PSscope);
            if (token.value == TOKelse)
            {
                nextToken();
                elsebody = parseStatement(PSscope);
            }
            else
                elsebody = NULL;
            if (condition && ifbody)
                s = new IfStatement(loc, arg, condition, ifbody, elsebody);
            else
                s = NULL;               // don't propagate parsing errors
            break;
        }

        case TOKscope:
            if (peek(&token)->value != TOKlparen)
                goto Ldeclaration;              // scope used as storage class
            nextToken();
            check(TOKlparen, "scope");
            if (token.value != TOKidentifier)
            {   error("scope (identifier) expected");
                goto Lerror;
            }
            else
            {   TOK t = TOKon_scope_exit;
                Identifier *id = token.ident;

                if (id == Id::exit)
                    t = TOKon_scope_exit;
                else if (id == Id::failure)
                    t = TOKon_scope_failure;
                else if (id == Id::success)
                    t = TOKon_scope_success;
                else
                    error("valid scope identifiers are exit, failure, or success, not %s", id->toChars());
                nextToken();
                check(TOKrparen);
                Statement *st = parseStatement(PScurlyscope);
                s = new OnScopeStatement(loc, t, st);
                break;
            }

        case TOKdebug:
            nextToken();
            condition = parseDebugCondition();
            goto Lcondition;

        case TOKversion:
            nextToken();
            condition = parseVersionCondition();
            goto Lcondition;

        Lcondition:
            ifbody = parseStatement(0 /*PSsemi*/);
            elsebody = NULL;
            if (token.value == TOKelse)
            {
                nextToken();
                elsebody = parseStatement(0 /*PSsemi*/);
            }
            s = new ConditionalStatement(loc, condition, ifbody, elsebody);
            break;

        case TOKpragma:
        {   Identifier *ident;
            Expressions *args = NULL;
            Statement *body;

            nextToken();
            check(TOKlparen);
            if (token.value != TOKidentifier)
            {   error("pragma(identifier expected");
                goto Lerror;
            }
            ident = token.ident;
            nextToken();
            if (token.value == TOKcomma && peekNext() != TOKrparen)
                args = parseArguments();        // pragma(identifier, args...);
            else
                check(TOKrparen);               // pragma(identifier);
            if (token.value == TOKsemicolon)
            {   nextToken();
                body = NULL;
            }
            else
                body = parseStatement(PSsemi);
            s = new PragmaStatement(loc, ident, args, body);
            break;
        }

        case TOKswitch:
        {
            nextToken();
            check(TOKlparen, "switch");
            Expression *condition = parseExpression();
            check(TOKrparen);
            Statement *body = parseStatement(PSscope);
            s = new SwitchStatement(loc, condition, body);
            break;
        }

        case TOKcase:
        {   Expression *exp;
            Array cases;        // array of Expression's

            while (1)
            {
                nextToken();
                exp = parseAssignExp();
                cases.push(exp);
                if (token.value != TOKcomma)
                    break;
            }
            check(TOKcolon, "case expression");

#if DMDV2
            /* case exp: .. case last:
             */
            if (token.value == TOKslice)
            {
                if (cases.dim > 1)
                    error("only one case allowed for start of case range");
                nextToken();
                check(TOKcase, "..");
                last = parseAssignExp();
                check(TOKcolon, "case expression");
            }
#endif

            if (flags & PScurlyscope)
            {
                Statements *statements = new Statements();
                while (token.value != TOKcase &&
                       token.value != TOKdefault &&
                       token.value != TOKeof &&
                       token.value != TOKrcurly)
                {
                    statements->push(parseStatement(PSsemi | PScurlyscope));
                }
                s = new CompoundStatement(loc, statements);
            }
            else
                s = parseStatement(PSsemi | PScurlyscope);
            s = new ScopeStatement(loc, s);

            // Keep cases in order by building the case statements backwards
            for (size_t i = cases.dim; i; i--)
            {
                exp = (Expression *)cases.data[i - 1];
                s = new CaseStatement(loc, exp, s);
            }
            break;
        }

        case TOKdefault:
        {
            nextToken();
            check(TOKcolon, "default");

            if (flags & PScurlyscope)
            {
                Statements *statements = new Statements();
                while (token.value != TOKcase &&
                       token.value != TOKdefault &&
                       token.value != TOKeof &&
                       token.value != TOKrcurly)
                {
                    statements->push(parseStatement(PSsemi | PScurlyscope));
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
        {   Expression *exp;

            nextToken();
            if (token.value == TOKsemicolon)
                exp = NULL;
            else
                exp = parseExpression();
            check(TOKsemicolon, "return expression");
            s = new ReturnStatement(loc, exp);
            break;
        }

        case TOKbreak:
        {   Identifier *ident;

            nextToken();
            if (token.value == TOKidentifier)
            {   ident = token.ident;
                nextToken();
            }
            else
                ident = NULL;
            check(TOKsemicolon, "break statement");
            s = new BreakStatement(loc, ident);
            break;
        }

        case TOKcontinue:
        {   Identifier *ident;

            nextToken();
            if (token.value == TOKidentifier)
            {   ident = token.ident;
                nextToken();
            }
            else
                ident = NULL;
            check(TOKsemicolon, "continue statement");
            s = new ContinueStatement(loc, ident);
            break;
        }

        case TOKgoto:
        {   Identifier *ident;

            nextToken();
            if (token.value == TOKdefault)
            {
                nextToken();
                s = new GotoDefaultStatement(loc);
            }
            else if (token.value == TOKcase)
            {
                Expression *exp = NULL;

                nextToken();
                if (token.value != TOKsemicolon)
                    exp = parseExpression();
                s = new GotoCaseStatement(loc, exp);
            }
            else
            {
                if (token.value != TOKidentifier)
                {   error("Identifier expected following goto");
                    ident = NULL;
                }
                else
                {   ident = token.ident;
                    nextToken();
                }
                s = new GotoStatement(loc, ident);
            }
            check(TOKsemicolon, "goto statement");
            break;
        }

        case TOKsynchronized:
        {   Expression *exp;
            Statement *body;

            nextToken();
            if (token.value == TOKlparen)
            {
                nextToken();
                exp = parseExpression();
                check(TOKrparen);
            }
            else
                exp = NULL;
            body = parseStatement(PSscope);
            s = new SynchronizedStatement(loc, exp, body);
            break;
        }

        case TOKwith:
        {   Expression *exp;
            Statement *body;

            nextToken();
            check(TOKlparen, "with");
            exp = parseExpression();
            check(TOKrparen);
            body = parseStatement(PSscope);
            s = new WithStatement(loc, exp, body);
            break;
        }

        case TOKtry:
        {   Statement *body;
            Catches *catches = NULL;
            Statement *finalbody = NULL;

            nextToken();
            body = parseStatement(PSscope);
            while (token.value == TOKcatch)
            {
                Statement *handler;
                Catch *c;
                Type *t;
                Identifier *id;
                Loc loc = this->loc;

                nextToken();
                if (token.value == TOKlcurly || token.value != TOKlparen)
                {
                    t = NULL;
                    id = NULL;
                }
                else
                {
                    check(TOKlparen, "catch");
                    t = parseBasicType();
                    id = NULL;
                    t = parseDeclarator(t, &id);
                    check(TOKrparen);
                }
                handler = parseStatement(0);
                c = new Catch(loc, t, id, handler);
                if (!catches)
                    catches = new Catches();
                catches->push(c);
            }

            if (token.value == TOKfinally)
            {   nextToken();
                finalbody = parseStatement(0);
            }

            s = body;
            if (!catches && !finalbody)
                error("catch or finally expected following try");
            else
            {   if (catches)
                    s = new TryCatchStatement(loc, body, catches);
                if (finalbody)
                    s = new TryFinallyStatement(loc, s, finalbody);
            }
            break;
        }

        case TOKthrow:
        {   Expression *exp;

            nextToken();
            exp = parseExpression();
            check(TOKsemicolon, "throw statement");
            s = new ThrowStatement(loc, exp);
            break;
        }

        case TOKvolatile:
            nextToken();
            s = parseStatement(PSsemi | PScurlyscope);
            if ((global.params.enabledV2hints & V2MODEvolatile) && mod && mod->isRoot())
            {
                warning(loc, "'volatile' is deprecated in D2, consult with "
                        "module maintainer for appropriate replacement [-v2=%s]",
                        V2MODE_name(V2MODEvolatile));
            }
            s = new VolatileStatement(loc, s);
            break;

        case TOKasm:
        {
            // Parse the asm block into a sequence of AsmStatements,
            // each AsmStatement is one instruction.
            // Separate out labels.
            // Defer parsing of AsmStatements until semantic processing.

            Loc labelloc;

            nextToken();
            check(TOKlcurly);
            Token *toklist = NULL;
            Token **ptoklist = &toklist;
            Identifier *label = NULL;
            Statements *statements = new Statements();
            size_t nestlevel = 0;
            while (1)
            {
                switch (token.value)
                {
                    case TOKidentifier:
                        if (!toklist)
                        {
                            // Look ahead to see if it is a label
                            Token *t = peek(&token);
                            if (t->value == TOKcolon)
                            {   // It's a label
                                label = token.ident;
                                labelloc = this->loc;
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

                        s = NULL;
                        if (toklist || label)
                        {   // Create AsmStatement from list of tokens we've saved
                            s = new AsmStatement(this->loc, toklist);
                            toklist = NULL;
                            ptoklist = &toklist;
                            if (label)
                            {   s = new LabelStatement(labelloc, label, s);
                                label = NULL;
                            }
                            statements->push(s);
                        }
                        nextToken();
                        continue;

                    case TOKeof:
                        /* { */
                        error("matching '}' expected, not end of file");
                        goto Lerror;

                    default:
                    Ldefault:
                        *ptoklist = new Token();
                        memcpy(*ptoklist, &token, sizeof(Token));
                        ptoklist = &(*ptoklist)->next;
                        *ptoklist = NULL;

                        nextToken();
                        continue;
                }
                break;
            }
            s = new CompoundStatement(loc, statements);
            nextToken();
            break;
        }

        default:
            error("found '%s' instead of statement", token.toChars());
            goto Lerror;

        Lerror:
            while (token.value != TOKrcurly &&
                   token.value != TOKsemicolon &&
                   token.value != TOKeof)
                nextToken();
            if (token.value == TOKsemicolon)
                nextToken();
            s = NULL;
            break;
    }

    return s;
}

void Parser::check(enum TOK value)
{
    check(loc, value);
}

void Parser::check(Loc loc, enum TOK value)
{
    if (token.value != value)
        error(loc, "found '%s' when expecting '%s'", token.toChars(), Token::toChars(value));
    nextToken();
}

void Parser::check(enum TOK value, const char *string)
{
    if (token.value != value)
        error("found '%s' when expecting '%s' following %s",
            token.toChars(), Token::toChars(value), string);
    nextToken();
}

/************************************
 * Determine if the scanner is sitting on the start of a declaration.
 * Input:
 *      needId  0       no identifier
 *              1       identifier optional
 *              2       must have identifier
 * Output:
 *      if *pt is not NULL, it is set to the ending token, which would be endtok
 */

int Parser::isDeclaration(Token *t, int needId, enum TOK endtok, Token **pt)
{
    //printf("isDeclaration(needId = %d)\n", needId);
    int haveId = 0;

#if DMDV2
    if ((t->value == TOKconst ||
         t->value == TOKinvariant ||
         t->value == TOKimmutable ||
         t->value == TOKwild ||
         t->value == TOKshared) &&
        peek(t)->value != TOKlparen)
    {   /* const type
         * immutable type
         * shared type
         * wild type
         */
        t = peek(t);
    }
#endif

    if (!isBasicType(&t))
    {
        goto Lisnot;
    }
    if (!isDeclarator(&t, &haveId, endtok))
        goto Lisnot;
    if ( needId == 1 ||
        (needId == 0 && !haveId) ||
        (needId == 2 &&  haveId))
    {   if (pt)
            *pt = t;
        goto Lis;
    }
    else
        goto Lisnot;

Lis:
    //printf("\tis declaration, t = %s\n", t->toChars());
    return TRUE;

Lisnot:
    //printf("\tis not declaration\n");
    return FALSE;
}

int Parser::isBasicType(Token **pt)
{
    // This code parallels parseBasicType()
    Token *t = *pt;

    switch (t->value)
    {
        case BASIC_TYPES:
            t = peek(t);
            break;

        case TOKidentifier:
            t = peek(t);
            if (t->value == TOKnot)
            {
                goto L4;
            }
            goto L3;
            while (1)
            {
        L2:
                t = peek(t);
        L3:
                if (t->value == TOKdot)
                {
        Ldot:
                    t = peek(t);
                    if (t->value != TOKidentifier)
                        goto Lfalse;
                    t = peek(t);
                    if (t->value != TOKnot)
                        goto L3;
        L4:
                    t = peek(t);
                    if (t->value != TOKlparen)
                        goto Lfalse;
                    if (!skipParens(t, &t))
                        goto Lfalse;
                }
                else
                    break;
            }
            break;

        case TOKdot:
            goto Ldot;

        case TOKtypeof:
            /* typeof(exp).identifier...
             */
            t = peek(t);
            if (t->value != TOKlparen)
                goto Lfalse;
            if (!skipParens(t, &t))
                goto Lfalse;
            goto L2;

        default:
            goto Lfalse;
    }
    *pt = t;
    //printf("is\n");
    return TRUE;

Lfalse:
    //printf("is not\n");
    return FALSE;
}

int Parser::isDeclarator(Token **pt, int *haveId, enum TOK endtok)
{   // This code parallels parseDeclarator()
    Token *t = *pt;
    int parens;

    //printf("Parser::isDeclarator()\n");
    //t->print();
    if (t->value == TOKassign)
        return FALSE;

    while (1)
    {
        parens = FALSE;
        switch (t->value)
        {
            case TOKmul:
            //case TOKand:
                t = peek(t);
                continue;

            case TOKlbracket:
                t = peek(t);
                if (t->value == TOKrbracket)
                {
                    t = peek(t);
                }
                else if (isDeclaration(t, 0, TOKrbracket, &t))
                {   // It's an associative array declaration
                    t = peek(t);
                }
                else
                {
                    // [ expression ]
                    // [ expression .. expression ]
                    if (!isExpression(&t))
                        return FALSE;
                    if (t->value == TOKslice)
                    {   t = peek(t);
                        if (!isExpression(&t))
                            return FALSE;
                    }
                    if (t->value != TOKrbracket)
                        return FALSE;
                    t = peek(t);
                }
                continue;

            case TOKidentifier:
                if (*haveId)
                    return FALSE;
                *haveId = TRUE;
                t = peek(t);
                break;

            case TOKlparen:
                t = peek(t);

                if (t->value == TOKrparen)
                    return FALSE;               // () is not a declarator

                /* Regard ( identifier ) as not a declarator
                 * BUG: what about ( *identifier ) in
                 *      f(*p)(x);
                 * where f is a class instance with overloaded () ?
                 * Should we just disallow C-style function pointer declarations?
                 */
                if (t->value == TOKidentifier)
                {   Token *t2 = peek(t);
                    if (t2->value == TOKrparen)
                        return FALSE;
                }


                if (!isDeclarator(&t, haveId, TOKrparen))
                    return FALSE;
                t = peek(t);
                parens = TRUE;
                break;

            case TOKdelegate:
            case TOKfunction:
                t = peek(t);
                if (!isParameters(&t))
                    return FALSE;
                continue;
        }
        break;
    }

    while (1)
    {
        switch (t->value)
        {
#if CARRAYDECL
            case TOKlbracket:
                parens = FALSE;
                t = peek(t);
                if (t->value == TOKrbracket)
                {
                    t = peek(t);
                }
                else if (isDeclaration(t, 0, TOKrbracket, &t))
                {   // It's an associative array declaration
                    t = peek(t);
                }
                else
                {
                    // [ expression ]
                    if (!isExpression(&t))
                        return FALSE;
                    if (t->value != TOKrbracket)
                        return FALSE;
                    t = peek(t);
                }
                continue;
#endif

            case TOKlparen:
                parens = FALSE;
                if (!isParameters(&t))
                    return FALSE;
#if DMDV2
                while (1)
                {
                    switch (t->value)
                    {
                        case TOKconst:
                        case TOKinvariant:
                        case TOKimmutable:
                        case TOKshared:
                        case TOKwild:
                        case TOKpure:
                        case TOKnothrow:
                            t = peek(t);
                            continue;
                        case TOKat:
                            t = peek(t);        // skip '@'
                            t = peek(t);        // skip identifier
                            continue;
                        default:
                            break;
                    }
                    break;
                }
#endif
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
                if (!parens && (endtok == TOKreserved || endtok == t->value))
                {   *pt = t;
                    return TRUE;
                }
                return FALSE;

            default:
                return FALSE;
        }
    }
}


int Parser::isParameters(Token **pt)
{   // This code parallels parseParameters()
    Token *t = *pt;
    int tmp;

    //printf("isParameters()\n");
    if (t->value != TOKlparen)
        return FALSE;

    t = peek(t);
    while (1)
    {
        switch (t->value)
        {
            case TOKrparen:
                break;

            case TOKdotdotdot:
                t = peek(t);
                break;

            case TOKin:
            case TOKout:
            case TOKinout:
            case TOKref:
            case TOKlazy:
                t = peek(t);
            default:
                if (!isBasicType(&t))
                    return FALSE;
                tmp = FALSE;
                if (t->value != TOKdotdotdot &&
                    !isDeclarator(&t, &tmp, TOKreserved))
                    return FALSE;
                if (t->value == TOKassign)
                {   t = peek(t);
                    if (!isExpression(&t))
                        return FALSE;
                }
                if (t->value == TOKdotdotdot)
                {
                    t = peek(t);
                    break;
                }
                if (t->value == TOKcomma)
                {   t = peek(t);
                    continue;
                }
                break;
        }
        break;
    }
    if (t->value != TOKrparen)
        return FALSE;
    t = peek(t);
    *pt = t;
    return TRUE;
}

int Parser::isExpression(Token **pt)
{
    // This is supposed to determine if something is an expression.
    // What it actually does is scan until a closing right bracket
    // is found.

    Token *t = *pt;
    int brnest = 0;
    int panest = 0;

    for (;; t = peek(t))
    {
        switch (t->value)
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

            case TOKslice:
                if (brnest)
                    continue;
                break;

            case TOKeof:
                return FALSE;

            default:
                continue;
        }
        break;
    }

    *pt = t;
    return TRUE;
}

/**********************************************
 * Skip over
 *      instance foo.bar(parameters...)
 * Output:
 *      if (pt), *pt is set to the token following the closing )
 * Returns:
 *      1       it's valid instance syntax
 *      0       invalid instance syntax
 */

int Parser::isTemplateInstance(Token *t, Token **pt)
{
    t = peek(t);
    if (t->value != TOKdot)
    {
        if (t->value != TOKidentifier)
            goto Lfalse;
        t = peek(t);
    }
    while (t->value == TOKdot)
    {
        t = peek(t);
        if (t->value != TOKidentifier)
            goto Lfalse;
        t = peek(t);
    }
    if (t->value != TOKlparen)
        goto Lfalse;

    // Skip over the template arguments
    while (1)
    {
        while (1)
        {
            t = peek(t);
            switch (t->value)
            {
                case TOKlparen:
                    if (!skipParens(t, &t))
                        goto Lfalse;
                    continue;
                case TOKrparen:
                    break;
                case TOKcomma:
                    break;
                case TOKeof:
                case TOKsemicolon:
                    goto Lfalse;
                default:
                    continue;
            }
            break;
        }

        if (t->value != TOKcomma)
            break;
    }
    if (t->value != TOKrparen)
        goto Lfalse;
    t = peek(t);
    if (pt)
        *pt = t;
    return 1;

Lfalse:
    return 0;
}

/*******************************************
 * Skip parens, brackets.
 * Input:
 *      t is on opening (
 * Output:
 *      *pt is set to closing token, which is ')' on success
 * Returns:
 *      !=0     successful
 *      0       some parsing error
 */

int Parser::skipParens(Token *t, Token **pt)
{
    int parens = 0;

    while (1)
    {
        switch (t->value)
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
        *pt = t;
    return 1;

  Lfalse:
    return 0;
}

int Parser::skipParensIf(Token *t, Token **pt)
{
    if (t->value != TOKlparen)
    {
        if (pt)
            *pt = t;
        return 1;
    }
    return skipParens(t, pt);
}

/********************************* Expression Parser ***************************/

Expression *Parser::parsePrimaryExp()
{   Expression *e;
    Type *t;
    Identifier *id;
    enum TOK save;
    Loc loc = this->loc;

    //printf("parsePrimaryExp(): loc = %d\n", loc.linnum);
    switch (token.value)
    {
        case TOKidentifier:
            id = token.ident;
            nextToken();
            if (token.value == TOKnot && peek(&token)->value == TOKlparen)
            {   // identifier!(template-argument-list)
                TemplateInstance *tempinst;

                tempinst = new TemplateInstance(loc, id);
                nextToken();
                tempinst->tiargs = parseTemplateArgumentList();
                e = new ScopeExp(loc, tempinst);
            }
            else
                e = new IdentifierExp(loc, id);
            break;

        case TOKdollar:
            if (!inBrackets)
                error("'$' is valid only inside [] of index or slice");
            e = new DollarExp(loc);
            nextToken();
            break;

        case TOKdot:
            // Signal global scope '.' operator with "" identifier
            e = new IdentifierExp(loc, Id::empty);
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
            e = new IntegerExp(loc, token.int32value, Type::tint32);
            nextToken();
            break;

        case TOKuns32v:
            e = new IntegerExp(loc, token.uns32value, Type::tuns32);
            nextToken();
            break;

        case TOKint64v:
            e = new IntegerExp(loc, token.int64value, Type::tint64);
            nextToken();
            break;

        case TOKuns64v:
            e = new IntegerExp(loc, token.uns64value, Type::tuns64);
            nextToken();
            break;

        case TOKfloat32v:
            e = new RealExp(loc, token.float80value, Type::tfloat32);
            nextToken();
            break;

        case TOKfloat64v:
            e = new RealExp(loc, token.float80value, Type::tfloat64);
            nextToken();
            break;

        case TOKfloat80v:
            e = new RealExp(loc, token.float80value, Type::tfloat80);
            nextToken();
            break;

        case TOKimaginary32v:
            e = new RealExp(loc, token.float80value, Type::timaginary32);
            nextToken();
            break;

        case TOKimaginary64v:
            e = new RealExp(loc, token.float80value, Type::timaginary64);
            nextToken();
            break;

        case TOKimaginary80v:
            e = new RealExp(loc, token.float80value, Type::timaginary80);
            nextToken();
            break;

        case TOKnull:
            e = new NullExp(loc);
            nextToken();
            break;

        case TOKfile:
        {   const char *s = loc.filename ? loc.filename : mod->ident->toChars();
            e = new StringExp(loc, (char *)s, strlen(s), 0);
            nextToken();
            break;
        }

        case TOKline:
            e = new IntegerExp(loc, loc.linnum, Type::tint32);
            nextToken();
            break;


        case TOKtrue:
            e = new IntegerExp(loc, 1, Type::tbool);
            nextToken();
            break;

        case TOKfalse:
            e = new IntegerExp(loc, 0, Type::tbool);
            nextToken();
            break;

        case TOKcharv:
            e = new IntegerExp(loc, token.uns32value, Type::tchar);
            nextToken();
            break;

        case TOKwcharv:
            e = new IntegerExp(loc, token.uns32value, Type::twchar);
            nextToken();
            break;

        case TOKdcharv:
            e = new IntegerExp(loc, token.uns32value, Type::tdchar);
            nextToken();
            break;

        case TOKstring:
        {   unsigned char *s;
            unsigned len;
            unsigned char postfix;

            // cat adjacent strings
            s = token.ustring;
            len = token.len;
            postfix = token.postfix;
            while (1)
            {
                nextToken();
                if (token.value == TOKstring)
                {   unsigned len1;
                    unsigned len2;
                    unsigned char *s2;

                    if (token.postfix)
                    {   if (token.postfix != postfix)
                            error("mismatched string literal postfixes '%c' and '%c'", postfix, token.postfix);
                        postfix = token.postfix;
                    }

                    len1 = len;
                    len2 = token.len;
                    len = len1 + len2;
                    s2 = (unsigned char *)mem.malloc((len + 1) * sizeof(unsigned char));
                    memcpy(s2, s, len1 * sizeof(unsigned char));
                    memcpy(s2 + len1, token.ustring, (len2 + 1) * sizeof(unsigned char));
                    s = s2;
                }
                else
                    break;
            }
            e = new StringExp(loc, s, len, postfix);
            break;
        }

        case BASIC_TYPES_X(t):
            nextToken();
            check(TOKdot, t->toChars());
            if (token.value != TOKidentifier)
            {   error("found '%s' when expecting identifier following '%s.'", token.toChars(), t->toChars());
                goto Lerr;
            }
            e = typeDotIdExp(loc, t, token.ident);
            nextToken();
            break;

        case TOKtypeof:
        {   Expression *exp;

            nextToken();
            check(TOKlparen);
            exp = parseExpression();
            check(TOKrparen);
            t = new TypeTypeof(loc, exp);
            e = new TypeExp(loc, t);
            break;
        }

        case TOKtypeid:
        {   Type *t;

            nextToken();
            check(TOKlparen, "typeid");
            t = parseBasicType();
            t = parseDeclarator(t,NULL);        // ( type )
            check(TOKrparen);
            e = new TypeidExp(loc, t);
            break;
        }

#if DMDV2
        case TOKtraits:
        {   /* __traits(identifier, args...)
             */
            Identifier *ident;
            Objects *args = NULL;

            nextToken();
            check(TOKlparen, "__traits");
            if (token.value != TOKidentifier)
            {   error("__traits(identifier, args...) expected");
                goto Lerr;
            }
            ident = token.ident;
            nextToken();
            if (token.value == TOKcomma)
                args = parseTemplateArgumentList2();    // __traits(identifier, args...)
            else
                check(TOKrparen);               // __traits(identifier)

            e = new TraitsExp(loc, ident, args);
            break;
        }
#endif

        case TOKis:
        {   Type *targ;
            Identifier *ident = NULL;
            Type *tspec = NULL;
            enum TOK tok = TOKreserved;
            enum TOK tok2 = TOKreserved;
            Loc loc = this->loc;

            nextToken();
            if (token.value == TOKlparen)
            {
                nextToken();
                targ = parseBasicType();
                targ = parseDeclarator(targ, &ident);
                if (token.value == TOKcolon || token.value == TOKequal)
                {
                    tok = token.value;
                    nextToken();
                    if (tok == TOKequal &&
                        (token.value == TOKtypedef ||
                         token.value == TOKstruct ||
                         token.value == TOKunion ||
                         token.value == TOKclass ||
                         token.value == TOKsuper ||
                         token.value == TOKenum ||
                         token.value == TOKinterface ||
                         token.value == TOKargTypes ||
#if DMDV2
                         token.value == TOKconst && peek(&token)->value == TOKrparen ||
                         token.value == TOKinvariant && peek(&token)->value == TOKrparen ||
                         token.value == TOKimmutable && peek(&token)->value == TOKrparen ||
                         token.value == TOKshared && peek(&token)->value == TOKrparen ||
#endif
                         token.value == TOKfunction ||
                         token.value == TOKdelegate ||
                         token.value == TOKreturn))
                    {
                        tok2 = token.value;
                        nextToken();
                    }
                    else
                    {
                        tspec = parseBasicType();
                        tspec = parseDeclarator(tspec, NULL);
                    }
                }
                check(TOKrparen);
            }
            else
            {   error("(type identifier : specialization) expected following is");
                goto Lerr;
            }
            e = new IsExp(loc, targ, ident, tok, tspec, tok2);
            break;
        }

        case TOKassert:
        {   Expression *msg = NULL;

            nextToken();
            check(TOKlparen, "assert");
            e = parseAssignExp();
            if (token.value == TOKcomma)
            {   nextToken();
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

        case TOKlparen:
            if (peekPastParen(&token)->value == TOKlcurly)
            {   // (arguments) { statements... }
                save = TOKdelegate;
                goto case_delegate;
            }
            // ( expression )
            nextToken();
            e = parseExpression();
            check(loc, TOKrparen);
            break;

        case TOKlbracket:
        {   /* Parse array literals and associative array literals:
             *  [ value, value, value ... ]
             *  [ key:value, key:value, key:value ... ]
             */
            Expressions *values = new Expressions();
            Expressions *keys = NULL;

            nextToken();
            if (token.value != TOKrbracket)
            {
                while (token.value != TOKeof)
                {
                    Expression *e = parseAssignExp();
                    if (token.value == TOKcolon && (keys || values->dim == 0))
                    {   nextToken();
                        if (!keys)
                            keys = new Expressions();
                        keys->push(e);
                        e = parseAssignExp();
                    }
                    else if (keys)
                    {   error("'key:value' expected for associative array literal");
                        delete keys;
                        keys = NULL;
                    }
                    values->push(e);
                    if (token.value == TOKrbracket)
                        break;
                    check(TOKcomma, "literal element");
                }
            }
            check(TOKrbracket);

            if (keys)
                e = new AssocArrayLiteralExp(loc, keys, values);
            else
                e = new ArrayLiteralExp(loc, values);
            break;
        }

        case TOKlcurly:
            // { statements... }
            save = TOKdelegate;
            goto case_delegate;

        case TOKfunction:
        case TOKdelegate:
            save = token.value;
            nextToken();
        case_delegate:
        {
            /* function type(parameters) { body }
             * delegate type(parameters) { body }
             */
            Parameters *arguments;
            int varargs;
            FuncLiteralDeclaration *fd;
            Type *t;

            if (token.value == TOKlcurly)
            {
                t = NULL;
                varargs = 0;
                arguments = new Parameters();
            }
            else
            {
                if (token.value == TOKlparen)
                    t = NULL;
                else
                {
                    t = parseBasicType();
                    t = parseBasicType2(t);     // function return type
                }
                arguments = parseParameters(&varargs);
            }
            t = new TypeFunction(arguments, t, varargs, linkage);
            fd = new FuncLiteralDeclaration(loc, 0, t, save, NULL);
            parseContracts(fd);
            e = new FuncExp(loc, fd);
            break;
        }

        default:
            error("expression expected, not '%s'", token.toChars());
        Lerr:
            // Anything for e, as long as it's not NULL
            e = new IntegerExp(loc, 0, Type::tint32);
            nextToken();
            break;
    }
    return parsePostExp(e);
}

Expression *Parser::parsePostExp(Expression *e)
{
    Loc loc;

    while (1)
    {
        loc = this->loc;
        switch (token.value)
        {
            case TOKdot:
                nextToken();
                if (token.value == TOKidentifier)
                {   Identifier *id = token.ident;

                    nextToken();
                    if (token.value == TOKnot && peek(&token)->value == TOKlparen)
                    {   // identifier!(template-argument-list)
                        TemplateInstance *tempinst;

                        tempinst = new TemplateInstance(loc, id);
                        nextToken();
                        tempinst->tiargs = parseTemplateArgumentList();
                        e = new DotTemplateInstanceExp(loc, e, tempinst);
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
            {   // array dereferences:
                //      array[index]
                //      array[]
                //      array[lwr .. upr]
                Expression *index;
                Expression *upr;

                inBrackets++;
                nextToken();
                if (token.value == TOKrbracket)
                {   // array[]
                    inBrackets--;
                    e = new SliceExp(loc, e, NULL, NULL);
                    nextToken();
                }
                else
                {
                    index = parseAssignExp();
                    if (token.value == TOKslice)
                    {   // array[lwr .. upr]
                        nextToken();
                        upr = parseAssignExp();
                        e = new SliceExp(loc, e, index, upr);
                    }
                    else
                    {   // array[index, i2, i3, i4, ...]
                        Expressions *arguments = new Expressions();
                        arguments->push(index);
                        if (token.value == TOKcomma)
                        {
                            nextToken();
                            while (1)
                            {
                                Expression *arg = parseAssignExp();
                                arguments->push(arg);
                                if (token.value == TOKrbracket)
                                    break;
                                check(TOKcomma, "array literal element");
                            }
                        }
                        e = new ArrayExp(loc, e, arguments);
                    }
                    check(TOKrbracket);
                    inBrackets--;
                }
                continue;
            }

            default:
                return e;
        }
        nextToken();
    }
}

Expression *Parser::parseUnaryExp()
{   Expression *e;
    Loc loc = this->loc;

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
            e = new AddAssignExp(loc, e, new IntegerExp(loc, 1, Type::tint32));
            break;

        case TOKminusminus:
            nextToken();
            e = parseUnaryExp();
            e = new MinAssignExp(loc, e, new IntegerExp(loc, 1, Type::tint32));
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

        case TOKnew:
            e = parseNewExp(NULL);
            break;

        case TOKcast:                           // cast(type) expression
        {   Type *t;

            nextToken();
            check(TOKlparen);
            t = parseBasicType();
            t = parseDeclarator(t,NULL);        // ( type )
            check(TOKrparen);

            e = parseUnaryExp();
            e = new CastExp(loc, e, t);
            break;
        }

        case TOKlparen:
        {   Token *tk;

            tk = peek(&token);
#if CCASTSYNTAX
            // If cast
            if (isDeclaration(tk, 0, TOKrparen, &tk))
            {
                tk = peek(tk);          // skip over right parenthesis
                switch (tk->value)
                {
                    case TOKnot:
                        tk = peek(tk);
                        if (tk->value == TOKis) // !is
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
#if 0
                    case TOKtilde:
                    case TOKand:
                    case TOKmul:
                    case TOKmin:
                    case TOKadd:
#endif
                    case TOKfunction:
                    case TOKdelegate:
                    case TOKtypeof:
                    case TOKfile:
                    case TOKline:
                    case BASIC_TYPES:           // (type)int.size
                    {   // (type) una_exp
                        Type *t;

                        nextToken();
                        t = parseBasicType();
                        t = parseDeclarator(t,NULL);
                        check(TOKrparen);

                        // if .identifier
                        // or .identifier!( ... )
                        if (token.value == TOKdot)
                        {
                            if (peekNext() != TOKidentifier)
                            {   error("Identifier expected following (type).");
                                return NULL;
                            }
                            e = new TypeExp(loc, t);
                            e = parsePostExp(e);
                        }
                        else
                        {
                            e = parseUnaryExp();
                            e = new CastExp(loc, e, t);
                            error("C style cast illegal, use %s", e->toChars());
                        }
                        return e;
                    }
                    default:
                        break;
                }
            }
#endif
            e = parsePrimaryExp();
            break;
        }
        default:
            e = parsePrimaryExp();
            break;
    }
    assert(e);
    return e;
}

Expression *Parser::parseMulExp()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    e = parseUnaryExp();
    while (1)
    {
        switch (token.value)
        {
            case TOKmul: nextToken(); e2 = parseUnaryExp(); e = new MulExp(loc,e,e2); continue;
            case TOKdiv: nextToken(); e2 = parseUnaryExp(); e = new DivExp(loc,e,e2); continue;
            case TOKmod: nextToken(); e2 = parseUnaryExp(); e = new ModExp(loc,e,e2); continue;

            default:
                break;
        }
        break;
    }
    return e;
}

Expression *Parser::parseAddExp()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    e = parseMulExp();
    while (1)
    {
        switch (token.value)
        {
            case TOKadd:    nextToken(); e2 = parseMulExp(); e = new AddExp(loc,e,e2); continue;
            case TOKmin:    nextToken(); e2 = parseMulExp(); e = new MinExp(loc,e,e2); continue;
            case TOKtilde:  nextToken(); e2 = parseMulExp(); e = new CatExp(loc,e,e2); continue;

            default:
                break;
        }
        break;
    }
    return e;
}

Expression *Parser::parseShiftExp()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    e = parseAddExp();
    while (1)
    {
        switch (token.value)
        {
            case TOKshl:  nextToken(); e2 = parseAddExp(); e = new ShlExp(loc,e,e2);  continue;
            case TOKshr:  nextToken(); e2 = parseAddExp(); e = new ShrExp(loc,e,e2);  continue;
            case TOKushr: nextToken(); e2 = parseAddExp(); e = new UshrExp(loc,e,e2); continue;

            default:
                break;
        }
        break;
    }
    return e;
}

Expression *Parser::parseRelExp()
{   Expression *e;
    Expression *e2;
    enum TOK op;
    Loc loc = this->loc;

    e = parseShiftExp();
    while (1)
    {
        switch (token.value)
        {
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
                op = token.value;
                nextToken();
                e2 = parseShiftExp();
                e = new CmpExp(op, loc, e, e2);
                continue;

#if DMDV2
            case TOKnot:                // could be !in
                if (peekNext() == TOKin)
                {
                    nextToken();
                    nextToken();
                    e2 = parseShiftExp();
                    e = new InExp(loc, e, e2);
                    e = new NotExp(loc, e);
                    continue;
                }
                break;
#endif

            case TOKin:
                nextToken();
                e2 = parseShiftExp();
                e = new InExp(loc, e, e2);
                continue;

            default:
                break;
        }
        break;
    }
    return e;
}

Expression *Parser::parseEqualExp()
{   Expression *e;
    Expression *e2;
    Token *t;
    Loc loc = this->loc;

    e = parseRelExp();
    while (1)
    {   enum TOK value = token.value;

        switch (value)
        {
            case TOKequal:
            case TOKnotequal:
                nextToken();
                e2 = parseRelExp();
                e = new EqualExp(value, loc, e, e2);
                continue;

            case TOKidentity:
                error("'===' is no longer legal, use 'is' instead");
                goto L1;

            case TOKnotidentity:
                error("'!==' is no longer legal, use '!is' instead");
                goto L1;

            case TOKis:
                value = TOKidentity;
                goto L1;

            case TOKnot:
                // Attempt to identify '!is'
                t = peek(&token);
                if (t->value != TOKis)
                    break;
                nextToken();
                value = TOKnotidentity;
                goto L1;

            L1:
                nextToken();
                e2 = parseRelExp();
                e = new IdentityExp(value, loc, e, e2);
                continue;

            default:
                break;
        }
        break;
    }
    return e;
}

Expression *Parser::parseCmpExp()
{   Expression *e;
    Expression *e2;
    Token *t;
    Loc loc = this->loc;

    e = parseShiftExp();
    enum TOK op = token.value;

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
#if DMDV2
            if (t->value == TOKin)
            {
                nextToken();
                nextToken();
                e2 = parseShiftExp();
                e = new InExp(loc, e, e2);
                e = new NotExp(loc, e);
                break;
            }
#endif
            if (t->value != TOKis)
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

Expression *Parser::parseAndExp()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    if (global.params.Dversion == 1)
    {
        e = parseEqualExp();
        while (token.value == TOKand)
        {
            nextToken();
            e2 = parseEqualExp();
            e = new AndExp(loc,e,e2);
            loc = this->loc;
        }
    }
    else
    {
        e = parseCmpExp();
        while (token.value == TOKand)
        {
            nextToken();
            e2 = parseCmpExp();
            e = new AndExp(loc,e,e2);
            loc = this->loc;
        }
    }
    return e;
}

Expression *Parser::parseXorExp()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    e = parseAndExp();
    while (token.value == TOKxor)
    {
        nextToken();
        e2 = parseAndExp();
        e = new XorExp(loc, e, e2);
    }
    return e;
}

Expression *Parser::parseOrExp()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    e = parseXorExp();
    while (token.value == TOKor)
    {
        nextToken();
        e2 = parseXorExp();
        e = new OrExp(loc, e, e2);
    }
    return e;
}

Expression *Parser::parseAndAndExp()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    e = parseOrExp();
    while (token.value == TOKandand)
    {
        nextToken();
        e2 = parseOrExp();
        e = new AndAndExp(loc, e, e2);
    }
    return e;
}

Expression *Parser::parseOrOrExp()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    e = parseAndAndExp();
    while (token.value == TOKoror)
    {
        nextToken();
        e2 = parseAndAndExp();
        e = new OrOrExp(loc, e, e2);
    }
    return e;
}

Expression *Parser::parseCondExp()
{   Expression *e;
    Expression *e1;
    Expression *e2;
    Loc loc = this->loc;

    e = parseOrOrExp();
    if (token.value == TOKquestion)
    {
        nextToken();
        e1 = parseExpression();
        check(TOKcolon, "condition ? expression");
        e2 = parseCondExp();
        e = new CondExp(loc, e, e1, e2);
    }
    return e;
}

Expression *Parser::parseAssignExp()
{   Expression *e;
    Expression *e2;
    Loc loc;

    e = parseCondExp();
    while (1)
    {
        loc = this->loc;
        switch (token.value)
        {
#define X(tok,ector) \
            case tok:  nextToken(); e2 = parseAssignExp(); e = new ector(loc,e,e2); continue;

            X(TOKassign,    AssignExp);
            X(TOKaddass,    AddAssignExp);
            X(TOKminass,    MinAssignExp);
            X(TOKmulass,    MulAssignExp);
            X(TOKdivass,    DivAssignExp);
            X(TOKmodass,    ModAssignExp);
            X(TOKandass,    AndAssignExp);
            X(TOKorass,     OrAssignExp);
            X(TOKxorass,    XorAssignExp);
            X(TOKshlass,    ShlAssignExp);
            X(TOKshrass,    ShrAssignExp);
            X(TOKushrass,   UshrAssignExp);
            X(TOKcatass,    CatAssignExp);

#undef X
            default:
                break;
        }
        break;
    }
    return e;
}

Expression *Parser::parseExpression()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    //printf("Parser::parseExpression() loc = %d\n", loc.linnum);
    e = parseAssignExp();
    while (token.value == TOKcomma)
    {
        nextToken();
        e2 = parseAssignExp();
        e = new CommaExp(loc, e, e2);
        loc = this->loc;
    }
    return e;
}


/*************************
 * Collect argument list.
 * Assume current token is '(' or '['.
 */

Expressions *Parser::parseArguments()
{   // function call
    Expressions *arguments;
    Expression *arg;
    enum TOK endtok;

    arguments = new Expressions();
    if (token.value == TOKlbracket)
        endtok = TOKrbracket;
    else
        endtok = TOKrparen;

    {
        nextToken();
        if (token.value != endtok)
        {
            while (token.value != TOKeof)
            {
                arg = parseAssignExp();
                arguments->push(arg);
                if (token.value == endtok)
                    break;
                check(TOKcomma, "argument");
            }
        }
        check(endtok, "argument list");
    }
    return arguments;
}

/*******************************************
 */

Expression *Parser::parseNewExp(Expression *thisexp)
{   Type *t;
    Expressions *newargs;
    Expressions *arguments = NULL;
    Expression *e;
    Loc loc = this->loc;

    nextToken();
    newargs = NULL;
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

        BaseClasses *baseclasses = NULL;
        if (token.value != TOKlcurly)
            baseclasses = parseBaseClasses();

        Identifier *id = NULL;
        ClassDeclaration *cd = new ClassDeclaration(loc, id, baseclasses);

        if (token.value != TOKlcurly)
        {   error("{ members } expected for anonymous class");
            cd->members = NULL;
        }
        else
        {
            nextToken();
            Dsymbols *decl = parseDeclDefs(0);
            if (token.value != TOKrcurly)
                error("class member expected");
            nextToken();
            cd->members = decl;
        }

        e = new NewAnonClassExp(loc, thisexp, newargs, cd, arguments);

        return e;
    }

#if LTORARRAYDECL
    t = parseBasicType();
    t = parseBasicType2(t);
    if (t->ty == Taarray)
    {
        Type *index = ((TypeAArray *)t)->index;

        Expression *e = index->toExpression();
        if (e)
        {   arguments = new Expressions();
            arguments->push(e);
            t = new TypeDArray(t->next);
        }
        else
        {
            error("need size of rightmost array, not type %s", index->toChars());
            return new NullExp(loc);
        }
    }
    else if (t->ty == Tsarray)
    {
        TypeSArray *tsa = (TypeSArray *)t;
        Expression *e = tsa->dim;

        arguments = new Expressions();
        arguments->push(e);
        t = new TypeDArray(t->next);
    }
    else if (token.value == TOKlparen)
    {
        arguments = parseArguments();
    }
#else
    t = parseBasicType();
    while (token.value == TOKmul)
    {   t = new TypePointer(t);
        nextToken();
    }
    if (token.value == TOKlbracket)
    {
        Expression *e;

        nextToken();
        e = parseAssignExp();
        arguments = new Array();
        arguments->push(e);
        check(TOKrbracket);
        t = parseDeclarator(t, NULL);
        t = new TypeDArray(t);
    }
    else if (token.value == TOKlparen)
        arguments = parseArguments();
#endif
    e = new NewExp(loc, thisexp, newargs, t, arguments);
    return e;
}

/**********************************************
 */

void Parser::addComment(Dsymbol *s, unsigned char *blockComment)
{
    s->addComment(combineComments(blockComment, token.lineComment));
    token.lineComment = NULL;
}

/**********************************
 * Set operator precedence for each operator.
 */

enum PREC precedence[TOKMAX];

void initPrecedence()
{
    for (size_t i = 0; i < TOKMAX; i++)
        precedence[i] = PREC_zero;

    precedence[TOKtype] = PREC_expr;
    precedence[TOKerror] = PREC_expr;

    precedence[TOKtypeof] = PREC_primary;
    precedence[TOKmixin] = PREC_primary;

    precedence[TOKdotvar] = PREC_primary;
    precedence[TOKimport] = PREC_primary;
    precedence[TOKidentifier] = PREC_primary;
    precedence[TOKthis] = PREC_primary;
    precedence[TOKsuper] = PREC_primary;
    precedence[TOKint64] = PREC_primary;
    precedence[TOKfloat64] = PREC_primary;
    precedence[TOKcomplex80] = PREC_primary;
    precedence[TOKnull] = PREC_primary;
    precedence[TOKstring] = PREC_primary;
    precedence[TOKarrayliteral] = PREC_primary;
    precedence[TOKassocarrayliteral] = PREC_primary;
    precedence[TOKfile] = PREC_primary;
    precedence[TOKline] = PREC_primary;
    precedence[TOKtypeid] = PREC_primary;
    precedence[TOKis] = PREC_primary;
    precedence[TOKassert] = PREC_primary;
    precedence[TOKhalt] = PREC_primary;
    precedence[TOKtemplate] = PREC_primary;
    precedence[TOKdsymbol] = PREC_primary;
    precedence[TOKfunction] = PREC_primary;
    precedence[TOKvar] = PREC_primary;
    precedence[TOKsymoff] = PREC_primary;
    precedence[TOKstructliteral] = PREC_primary;
    precedence[TOKarraylength] = PREC_primary;
    precedence[TOKremove] = PREC_primary;
    precedence[TOKtuple] = PREC_primary;
    precedence[TOKdefault] = PREC_primary;
#if DMDV2
    precedence[TOKtraits] = PREC_primary;
    precedence[TOKoverloadset] = PREC_primary;
    precedence[TOKvoid] = PREC_primary;
#endif

    // post
    precedence[TOKdotti] = PREC_primary;
    precedence[TOKdot] = PREC_primary;
    precedence[TOKdottd] = PREC_primary;
    precedence[TOKdotexp] = PREC_primary;
    precedence[TOKdottype] = PREC_primary;
//  precedence[TOKarrow] = PREC_primary;
    precedence[TOKplusplus] = PREC_primary;
    precedence[TOKminusminus] = PREC_primary;
#if DMDV2
    precedence[TOKpreplusplus] = PREC_primary;
    precedence[TOKpreminusminus] = PREC_primary;
#endif
    precedence[TOKcall] = PREC_primary;
    precedence[TOKslice] = PREC_primary;
    precedence[TOKarray] = PREC_primary;
    precedence[TOKindex] = PREC_primary;

    precedence[TOKdelegate] = PREC_unary;
    precedence[TOKaddress] = PREC_unary;
    precedence[TOKstar] = PREC_unary;
    precedence[TOKneg] = PREC_unary;
    precedence[TOKuadd] = PREC_unary;
    precedence[TOKnot] = PREC_unary;
    precedence[TOKtobool] = PREC_add;
    precedence[TOKtilde] = PREC_unary;
    precedence[TOKdelete] = PREC_unary;
    precedence[TOKnew] = PREC_unary;
    precedence[TOKnewanonclass] = PREC_unary;
    precedence[TOKcast] = PREC_unary;

#if DMDV2
    precedence[TOKpow] = PREC_pow;
#endif

    precedence[TOKmul] = PREC_mul;
    precedence[TOKdiv] = PREC_mul;
    precedence[TOKmod] = PREC_mul;

    precedence[TOKadd] = PREC_add;
    precedence[TOKmin] = PREC_add;
    precedence[TOKcat] = PREC_add;

    precedence[TOKshl] = PREC_shift;
    precedence[TOKshr] = PREC_shift;
    precedence[TOKushr] = PREC_shift;

    precedence[TOKlt] = PREC_rel;
    precedence[TOKle] = PREC_rel;
    precedence[TOKgt] = PREC_rel;
    precedence[TOKge] = PREC_rel;
    precedence[TOKunord] = PREC_rel;
    precedence[TOKlg] = PREC_rel;
    precedence[TOKleg] = PREC_rel;
    precedence[TOKule] = PREC_rel;
    precedence[TOKul] = PREC_rel;
    precedence[TOKuge] = PREC_rel;
    precedence[TOKug] = PREC_rel;
    precedence[TOKue] = PREC_rel;
    precedence[TOKin] = PREC_rel;

#if 0
    precedence[TOKequal] = PREC_equal;
    precedence[TOKnotequal] = PREC_equal;
    precedence[TOKidentity] = PREC_equal;
    precedence[TOKnotidentity] = PREC_equal;
#else
    /* Note that we changed precedence, so that < and != have the same
     * precedence. This change is in the parser, too.
     */
    precedence[TOKequal] = PREC_rel;
    precedence[TOKnotequal] = PREC_rel;
    precedence[TOKidentity] = PREC_rel;
    precedence[TOKnotidentity] = PREC_rel;
#endif

    precedence[TOKand] = PREC_and;

    precedence[TOKxor] = PREC_xor;

    precedence[TOKor] = PREC_or;

    precedence[TOKandand] = PREC_andand;

    precedence[TOKoror] = PREC_oror;

    precedence[TOKquestion] = PREC_cond;

    precedence[TOKassign] = PREC_assign;
    precedence[TOKconstruct] = PREC_assign;
    precedence[TOKblit] = PREC_assign;
    precedence[TOKaddass] = PREC_assign;
    precedence[TOKminass] = PREC_assign;
    precedence[TOKcatass] = PREC_assign;
    precedence[TOKmulass] = PREC_assign;
    precedence[TOKdivass] = PREC_assign;
    precedence[TOKmodass] = PREC_assign;
#if DMDV2
    precedence[TOKpowass] = PREC_assign;
#endif
    precedence[TOKshlass] = PREC_assign;
    precedence[TOKshrass] = PREC_assign;
    precedence[TOKushrass] = PREC_assign;
    precedence[TOKandass] = PREC_assign;
    precedence[TOKorass] = PREC_assign;
    precedence[TOKxorass] = PREC_assign;

    precedence[TOKcomma] = PREC_expr;
    precedence[TOKdeclaration] = PREC_expr;
}

