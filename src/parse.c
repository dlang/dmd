
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// This is the D parser

#include <stdio.h>
#include <assert.h>

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

// Support D1 inout
#define D1INOUT         0

Parser::Parser(Module *module, unsigned char *base, unsigned length, int doDocComment)
    : Lexer(module, base, 0, length, doDocComment, 0)
{
    //printf("Parser::Parser()\n");
    md = NULL;
    linkage = LINKd;
    endloc = 0;
    inBrackets = 0;
    lookingForElse = 0;
    //nextToken();              // start up the scanner
}

Dsymbols *Parser::parseModule()
{
    Dsymbols *decldefs;

    // ModuleDeclation leads off
    if (token.value == TOKmodule)
    {
        unsigned char *comment = token.blockComment;
        bool safe = FALSE;

        nextToken();
#if 0 && DMDV2
        if (token.value == TOKlparen)
        {
            nextToken();
            if (token.value != TOKidentifier)
            {   error("module (system) identifier expected");
                goto Lerr;
            }
            Identifier *id = token.ident;

            if (id == Id::system)
                safe = TRUE;
            else
                error("(safe) expected, not %s", id->toChars());
            nextToken();
            check(TOKrparen);
        }
#endif

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

            md = new ModuleDeclaration(a, id, safe);

            if (token.value != TOKsemicolon)
                error("';' expected following module declaration instead of %s", token.toChars());
            nextToken();
            addComment(mod, comment);
        }
    }

    decldefs = parseDeclDefs(0);
    if (token.value != TOKeof)
    {   error("unrecognized declaration");
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
    StorageClass storageClass;
    Condition *condition;
    unsigned char *comment;

    //printf("Parser::parseDeclDefs()\n");
    decldefs = new Dsymbols();
    do
    {
        comment = token.blockComment;
        storageClass = STCundefined;
        switch (token.value)
        {
            case TOKenum:
            {   /* Determine if this is a manifest constant declaration,
                 * or a conventional enum.
                 */
                Token *t = peek(&token);
                if (t->value == TOKlcurly || t->value == TOKcolon)
                    s = parseEnum();
                else if (t->value != TOKidentifier)
                    goto Ldeclaration;
                else
                {
                    t = peek(t);
                    if (t->value == TOKlcurly || t->value == TOKcolon ||
                        t->value == TOKsemicolon)
                        s = parseEnum();
                    else
                        goto Ldeclaration;
                }
                break;
            }

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
                s = (Dsymbol *)parseTemplateDeclaration(0);
                break;

            case TOKmixin:
            {   Loc loc = this->loc;
                switch (peekNext())
                {
                    case TOKlparen:
                    {   // mixin(string)
                        nextToken();
                        check(TOKlparen, "mixin");
                        Expression *e = parseAssignExp();
                        check(TOKrparen);
                        check(TOKsemicolon);
                        s = new CompileDeclaration(loc, e);
                        break;
                    }
                    case TOKtemplate:
                        // mixin template
                        nextToken();
                        s = (Dsymbol *)parseTemplateDeclaration(1);
                        break;

                    default:
                        s = parseMixin();
                        break;
                }
                break;
            }

            case BASIC_TYPES:
            case TOKalias:
            case TOKtypedef:
            case TOKidentifier:
            case TOKsuper:
            case TOKtypeof:
            case TOKdot:
            Ldeclaration:
                a = parseDeclarations(STCundefined, NULL);
                decldefs->append(a);
                continue;

            case TOKthis:
                if (peekNext() == TOKdot)
                    goto Ldeclaration;
                else
                    s = parseCtor();
                break;

#if 0 // dead end, use this(this){} instead
            case TOKassign:
                s = parsePostBlit();
                break;
#endif
            case TOKtilde:
                s = parseDtor();
                break;

            case TOKinvariant:
            {   Token *t;
                t = peek(&token);
                if (t->value == TOKlparen)
                {
                    if (peek(t)->value == TOKrparen)
                        // invariant() forms start of class invariant
                        s = parseInvariant();
                    else
                        // invariant(type)
                        goto Ldeclaration;
                }
                else
                {
                    stc = STCimmutable;
                    goto Lstc;
                }
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
                    Loc lookingForElseSave = lookingForElse;
                    lookingForElse = loc;
                    a = parseBlock();
                    lookingForElse = lookingForElseSave;
                    aelse = NULL;
                    if (token.value == TOKelse)
                    {
                        Loc elseloc = this->loc;
                        nextToken();
                        aelse = parseBlock();
                        checkDanglingElse(elseloc);
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
            {   TOK next = peekNext();
                if (next == TOKlparen)
                    goto Ldeclaration;
                if (next == TOKstatic)
                {   TOK next2 = peekNext2();
                    if (next2 == TOKthis)
                    {   s = parseSharedStaticCtor();
                        break;
                    }
                    if (next2 == TOKtilde)
                    {   s = parseSharedStaticDtor();
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

            case TOKfinal:        stc = STCfinal;        goto Lstc;
            case TOKauto:         stc = STCauto;         goto Lstc;
            case TOKscope:        stc = STCscope;        goto Lstc;
            case TOKoverride:     stc = STCoverride;     goto Lstc;
            case TOKabstract:     stc = STCabstract;     goto Lstc;
            case TOKsynchronized: stc = STCsynchronized; goto Lstc;
            case TOKdeprecated:   stc = STCdeprecated;   goto Lstc;
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
                if (storageClass & stc)
                    error("redundant storage class %s", Token::toChars(token.value));
                composeStorageClass(storageClass | stc);
                nextToken();
            Lstc2:
                storageClass |= stc;
                switch (token.value)
                {
                    case TOKconst:
                    case TOKinvariant:
                    case TOKimmutable:
                    case TOKshared:
                    case TOKwild:
                        // If followed by a (, it is not a storage class
                        if (peek(&token)->value == TOKlparen)
                            break;
                        if (token.value == TOKconst)
                            stc = STCconst;
                        else if (token.value == TOKshared)
                            stc = STCshared;
                        else if (token.value == TOKwild)
                            stc = STCwild;
                        else
                            stc = STCimmutable;
                        goto Lstc;
                    case TOKfinal:        stc = STCfinal;        goto Lstc;
                    case TOKauto:         stc = STCauto;         goto Lstc;
                    case TOKscope:        stc = STCscope;        goto Lstc;
                    case TOKoverride:     stc = STCoverride;     goto Lstc;
                    case TOKabstract:     stc = STCabstract;     goto Lstc;
                    case TOKsynchronized: stc = STCsynchronized; goto Lstc;
                    case TOKdeprecated:   stc = STCdeprecated;   goto Lstc;
                    case TOKnothrow:      stc = STCnothrow;      goto Lstc;
                    case TOKpure:         stc = STCpure;         goto Lstc;
                    case TOKref:          stc = STCref;          goto Lstc;
                    case TOKtls:          stc = STCtls;          goto Lstc;
                    case TOKgshared:      stc = STCgshared;      goto Lstc;
                    //case TOKmanifest:   stc = STCmanifest;     goto Lstc;
                    case TOKat:           stc = parseAttribute(); goto Lstc;
                    default:
                        break;
                }

                /* Look for auto initializers:
                 *      storage_class identifier = initializer;
                 */
                if (token.value == TOKidentifier &&
                    peek(&token)->value == TOKassign)
                {
                    a = parseAutoDeclarations(storageClass, comment);
                    decldefs->append(a);
                    continue;
                }

                /* Look for return type inference for template functions.
                 */
                Token *tk;
                if (token.value == TOKidentifier &&
                    (tk = peek(&token))->value == TOKlparen &&
                    skipParens(tk, &tk) &&
                    ((tk = peek(tk)), 1) &&
                    skipAttributes(tk, &tk) &&
                    (tk->value == TOKlparen ||
                     tk->value == TOKlcurly)
                   )
                {
                    a = parseDeclarations(storageClass, comment);
                    decldefs->append(a);
                    continue;
                }
                a = parseBlock();
                s = new StorageClassDeclaration(storageClass, a);
                break;

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
                        n = (unsigned)token.uns64value;
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
                {   error("pragma(identifier expected");
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
                    else if (token.value == TOKint32v)
                        s = new DebugSymbol(loc, (unsigned)token.uns64value);
                    else
                    {   error("identifier or integer expected, not %s", token.toChars());
                        s = NULL;
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
                        s = new VersionSymbol(loc, token.ident);
                    else if (token.value == TOKint32v)
                        s = new VersionSymbol(loc, (unsigned)token.uns64value);
                    else
                    {   error("identifier or integer expected, not %s", token.toChars());
                        s = NULL;
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
                    Loc lookingForElseSave = lookingForElse;
                    lookingForElse = loc;
                    a = parseBlock();
                    lookingForElse = lookingForElseSave;
                }
                aelse = NULL;
                if (token.value == TOKelse)
                {
                    Loc elseloc = this->loc;
                    nextToken();
                    aelse = parseBlock();
                    checkDanglingElse(elseloc);
                }
                s = new ConditionalDeclaration(condition, a, aelse);
                break;

            case TOKsemicolon:          // empty declaration
                //error("empty declaration");
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
    u = stc;
    u &= STCsafe | STCsystem | STCtrusted;
    if (u & (u - 1))
        error("conflicting attribute @%s", token.toChars());
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

/***********************************************
 * Parse const/immutable/shared/inout/nothrow/pure postfix
 */

StorageClass Parser::parsePostfix()
{
    StorageClass stc = 0;

    while (1)
    {
        switch (token.value)
        {
            case TOKconst:              stc |= STCconst;                break;
            case TOKinvariant:
                if (!global.params.useDeprecated)
                    error("use of 'invariant' rather than 'immutable' is deprecated");
            case TOKimmutable:          stc |= STCimmutable;            break;
            case TOKshared:             stc |= STCshared;               break;
            case TOKwild:               stc |= STCwild;                 break;
            case TOKnothrow:            stc |= STCnothrow;              break;
            case TOKpure:               stc |= STCpure;                 break;
            case TOKat:                 stc |= parseAttribute();        break;

            default:
                composeStorageClass(stc);
                return stc;
        }
        nextToken();
    }
}

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
        {
            Loc lookingForElseSave = lookingForElse;
            lookingForElse = 0;

            nextToken();
            a = parseDeclDefs(0);
            if (token.value != TOKrcurly)
            {   /* { */
                error("matching '}' expected, not %s", token.toChars());
            }
            else
                nextToken();
            lookingForElse = lookingForElseSave;
            break;
        }

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
    check(TOKsemicolon);
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
        else if (token.value == TOKint32v)
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
        else if (token.value == TOKint32v)
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
 * or postblit:
 *      this(this) { body }
 * or constructor template:
 *      this(templateparameters)(parameters) { body }
 * Current token is 'this'.
 */

Dsymbol *Parser::parseCtor()
{
    Loc loc = this->loc;

    nextToken();
    if (token.value == TOKlparen && peek(&token)->value == TOKthis)
    {   // this(this) { ... }
        nextToken();
        nextToken();
        check(TOKrparen);
        PostBlitDeclaration *f = new PostBlitDeclaration(loc, 0);
        parseContracts(f);
        return f;
    }

    /* Look ahead to see if:
     *   this(...)(...)
     * which is a constructor template
     */
    TemplateParameters *tpl = NULL;
    if (token.value == TOKlparen && peekPastParen(&token)->value == TOKlparen)
    {   tpl = parseTemplateParameterList();

        int varargs;
        Parameters *parameters = parseParameters(&varargs);
        StorageClass stc = parsePostfix();

        Expression *constraint = tpl ? parseConstraint() : NULL;

                Type *tf = new TypeFunction(parameters, NULL, varargs, linkage, stc);   // RetrunType -> auto
        CtorDeclaration *f = new CtorDeclaration(loc, 0, stc, tf);
        parseContracts(f);

        // Wrap a template around it
        Dsymbols *decldefs = new Dsymbols();
        decldefs->push(f);
        TemplateDeclaration *tempdecl =
            new TemplateDeclaration(loc, f->ident, tpl, constraint, decldefs, 0);
        return tempdecl;
    }

    /* Just a regular constructor
     */
    int varargs;
    Parameters *parameters = parseParameters(&varargs);
    StorageClass stc = parsePostfix();
        Type *tf = new TypeFunction(parameters, NULL, varargs, linkage, stc);   // RetrunType -> auto
    CtorDeclaration *f = new CtorDeclaration(loc, 0, stc, tf);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse a postblit definition:
 *      =this() { body }
 * Current token is '='.
 */

PostBlitDeclaration *Parser::parsePostBlit()
{
    Loc loc = this->loc;

    nextToken();
    check(TOKthis);
    check(TOKlparen);
    check(TOKrparen);

    PostBlitDeclaration *f = new PostBlitDeclaration(loc, 0);
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
    check(TOKthis);
    check(TOKlparen);
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
    check(TOKlparen);
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

SharedStaticCtorDeclaration *Parser::parseSharedStaticCtor()
{
    Loc loc = this->loc;

    nextToken();
    nextToken();
    nextToken();
    check(TOKlparen);
    check(TOKrparen);

    SharedStaticCtorDeclaration *f = new SharedStaticCtorDeclaration(loc, 0);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse a static destructor definition:
 *      static ~this() { body }
 * Current token is '~'.
 */

StaticDtorDeclaration *Parser::parseStaticDtor()
{
    Loc loc = this->loc;

    nextToken();
    check(TOKthis);
    check(TOKlparen);
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

SharedStaticDtorDeclaration *Parser::parseSharedStaticDtor()
{
    Loc loc = this->loc;

    nextToken();
    nextToken();
    nextToken();
    check(TOKthis);
    check(TOKlparen);
    check(TOKrparen);

    SharedStaticDtorDeclaration *f = new SharedStaticDtorDeclaration(loc, 0);
    parseContracts(f);
    return f;
}

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

    check(TOKlparen);
    while (1)
    {
        Identifier *ai = NULL;
        Type *at;
        Parameter *a;
        StorageClass storageClass = 0;
        StorageClass stc;
        Expression *ae;

        for (;1; nextToken())
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
                    if (peek(&token)->value == TOKlparen)
                        goto Ldefault;
                    stc = STCconst;
                    goto L2;

                case TOKinvariant:
                case TOKimmutable:
                    if (peek(&token)->value == TOKlparen)
                        goto Ldefault;
                    stc = STCimmutable;
                    goto L2;

                case TOKshared:
                    if (peek(&token)->value == TOKlparen)
                        goto Ldefault;
                    stc = STCshared;
                    goto L2;

                case TOKwild:
                    if (peek(&token)->value == TOKlparen)
                        goto Ldefault;
                    stc = STCwild;
                    goto L2;

                case TOKin:        stc = STCin;         goto L2;
                case TOKout:       stc = STCout;        goto L2;
#if D1INOUT
                case TOKinout:
#endif
                case TOKref:       stc = STCref;        goto L2;
                case TOKlazy:      stc = STClazy;       goto L2;
                case TOKscope:     stc = STCscope;      goto L2;
                case TOKfinal:     stc = STCfinal;      goto L2;
                case TOKauto:      stc = STCauto;       goto L2;
                L2:
                    if (storageClass & stc ||
                        (storageClass & STCin && stc & (STCconst | STCscope)) ||
                        (stc & STCin && storageClass & (STCconst | STCscope))
                       )
                        error("redundant storage class %s", Token::toChars(token.value));
                    storageClass |= stc;
                    composeStorageClass(storageClass);
                    continue;

#if 0
                case TOKstatic:    stc = STCstatic;             goto L2;
                case TOKauto:   storageClass = STCauto;         goto L4;
                case TOKalias:  storageClass = STCalias;        goto L4;
                L4:
                    nextToken();
                    if (token.value == TOKidentifier)
                    {   ai = token.ident;
                        nextToken();
                    }
                    else
                        ai = NULL;
                    at = NULL;          // no type
                    ae = NULL;          // no default argument
                    if (token.value == TOKassign)       // = defaultArg
                    {   nextToken();
                        ae = parseDefaultInitExp();
                        hasdefault = 1;
                    }
                    else
                    {   if (hasdefault)
                            error("default argument expected for alias %s",
                                    ai ? ai->toChars() : "");
                    }
                    goto L3;
#endif

                default:
                Ldefault:
                    stc = storageClass & (STCin | STCout | STCref | STClazy);
                    if (stc & (stc - 1))        // if stc is not a power of 2
                        error("incompatible parameter storage classes");
                    if ((storageClass & (STCconst | STCout)) == (STCconst | STCout))
                        error("out cannot be const");
                    if ((storageClass & (STCimmutable | STCout)) == (STCimmutable | STCout))
                        error("out cannot be immutable");
                    if ((storageClass & STCscope) &&
                        (storageClass & (STCref | STCout)))
                        error("scope cannot be ref or out");
                    at = parseType(&ai);
                    ae = NULL;
                    if (token.value == TOKassign)       // = defaultArg
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
                         *      at ai ...
                         */

                        if (storageClass & (STCout | STCref))
                            error("variadic argument cannot be out or ref");
                        varargs = 2;
                        a = new Parameter(storageClass, at, ai, ae);
                        arguments->push(a);
                        nextToken();
                        break;
                    }
                            L3:
                    a = new Parameter(storageClass, at, ai, ae);
                    arguments->push(a);
                    if (token.value == TOKcomma)
                    {   nextToken();
                        goto L1;
                    }
                    break;
            }
            break;
        }
        break;

    L1: ;
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
        memtype = parseDeclarator(memtype, NULL, NULL);
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
            /* Can take the following forms:
             *  1. ident
             *  2. ident = value
             *  3. type ident = value
             */

            loc = this->loc;

            Type *type = NULL;
            Identifier *ident;
            Token *tp = peek(&token);
            if (token.value == TOKidentifier &&
                (tp->value == TOKassign || tp->value == TOKcomma || tp->value == TOKrcurly))
            {
                ident = token.ident;
                type = NULL;
                nextToken();
            }
            else
            {
                type = parseType(&ident, NULL);
                if (id || memtype)
                    error("type only allowed if anonymous enum and no enum type");
            }

            Expression *value;
            if (token.value == TOKassign)
            {
                nextToken();
                value = parseAssignExp();
            }
            else
            {   value = NULL;
                if (type)
                    error("if type, there must be an initializer");
            }

            EnumMember *em = new EnumMember(loc, ident, value, type);
            e->members->push(em);

            if (token.value == TOKrcurly)
                ;
            else
            {   addComment(em, comment);
                comment = NULL;
                check(TOKcomma);
            }
            addComment(em, comment);
            comment = token.blockComment;
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
            constraint = parseConstraint();
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
                new TemplateDeclaration(loc, id, tpl, constraint, decldefs, 0);
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
        enum PROT protection = PROTpublic;
        switch (token.value)
        {
            case TOKprivate:
                protection = PROTprivate;
                nextToken();
                break;
            case TOKpackage:
                protection = PROTpackage;
                nextToken();
                break;
            case TOKprotected:
                protection = PROTprotected;
                nextToken();
                break;
            case TOKpublic:
                protection = PROTpublic;
                nextToken();
                break;
        }
        if (token.value == TOKidentifier)
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
        check(TOKlparen);
        e = parseExpression();
        check(TOKrparen);
    }
    return e;
}
#endif

/**************************************
 * Parse a TemplateDeclaration.
 */

TemplateDeclaration *Parser::parseTemplateDeclaration(int ismixin)
{
    TemplateDeclaration *tempdecl;
    Identifier *id;
    TemplateParameters *tpl;
    Dsymbols *decldefs;
    Expression *constraint = NULL;
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

    constraint = parseConstraint();

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

    tempdecl = new TemplateDeclaration(loc, id, tpl, constraint, decldefs, ismixin);
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

    if (!flag && token.value != TOKlparen)
    {   error("parenthesized TemplateParameterList expected following TemplateIdentifier");
        goto Lerr;
    }
    nextToken();

    // Get array of TemplateParameters
    if (flag || token.value != TOKrparen)
    {   int isvariadic = 0;

        while (token.value != TOKrparen)
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
                Type *spectype = NULL;
                if (isDeclaration(&token, 2, TOKreserved, NULL))
                {
                    spectype = parseType(&tp_ident);
                }
                else
                {
                    if (token.value != TOKidentifier)
                    {   error("identifier expected for template alias parameter");
                        goto Lerr;
                    }
                    tp_ident = token.ident;
                    nextToken();
                }
                Object *spec = NULL;
                if (token.value == TOKcolon)    // : Type
                {
                    nextToken();
                    if (isDeclaration(&token, 0, TOKreserved, NULL))
                        spec = parseType();
                    else
                        spec = parseCondExp();
                }
                Object *def = NULL;
                if (token.value == TOKassign)   // = Type
                {
                    nextToken();
                    if (isDeclaration(&token, 0, TOKreserved, NULL))
                        def = parseType();
                    else
                        def = parseCondExp();
                }
                tp = new TemplateAliasParameter(loc, tp_ident, spectype, spec, def);
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
                    tp_spectype = parseType();
                }
                if (token.value == TOKassign)   // = Type
                {
                    nextToken();
                    tp_defaulttype = parseType();
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
                tp_valtype = parseType(&tp_ident);
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
        {
            tqual = parseTypeof();
            check(TOKdot);
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
            if (token.value == TOKlparen)
                tiargs = parseTemplateArgumentList();
            else
                tiargs = parseTemplateArgument();
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
    if (token.value != TOKsemicolon)
        error("';' expected after mixin");
    nextToken();

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
    if (token.value != TOKlparen && token.value != TOKlcurly)
    {   error("!(TemplateArgumentList) expected following TemplateIdentifier");
        return new Objects();
    }
    return parseTemplateArgumentList2();
}

Objects *Parser::parseTemplateArgumentList2()
{
    //printf("Parser::parseTemplateArgumentList2()\n");
    Objects *tiargs = new Objects();
    enum TOK endtok = TOKrparen;
    nextToken();

    // Get TemplateArgumentList
    while (token.value != endtok)
    {
            // See if it is an Expression or a Type
            if (isDeclaration(&token, 0, TOKreserved, NULL))
            {   // Template argument is a type
                Type *ta = parseType();
                tiargs->push(ta);
            }
            else
            {   // Template argument is an expression
                Expression *ea = parseAssignExp();

                if (ea->op == TOKfunction)
                {   FuncLiteralDeclaration *fd = ((FuncExp *)ea)->fd;
                    if (fd->type->ty == Tfunction)
                    {
                        TypeFunction *tf = (TypeFunction *)fd->type;
                        /* If there are parameters that consist of only an identifier,
                         * rather than assuming the identifier is a type, as we would
                         * for regular function declarations, assume the identifier
                         * is the parameter name, and we're building a template with
                         * a deduced type.
                         */
                        TemplateParameters *tpl = NULL;
                        for (size_t i = 0; i < tf->parameters->dim; i++)
                        {   Parameter *param = tf->parameters->tdata()[i];
                            if (param->ident == NULL &&
                                param->type &&
                                param->type->ty == Tident &&
                                ((TypeIdentifier *)param->type)->idents.dim == 0
                               )
                            {
                                /* Switch parameter type to parameter identifier,
                                 * parameterize with template type parameter _T
                                 */
                                TypeIdentifier *pt = (TypeIdentifier *)param->type;
                                param->ident = pt->ident;
                                Identifier *id = Lexer::uniqueId("__T");
                                param->type = new TypeIdentifier(pt->loc, id);
                                TemplateParameter *tp = new TemplateTypeParameter(fd->loc, id, NULL, NULL);
                                if (!tpl)
                                    tpl = new TemplateParameters();
                                tpl->push(tp);
                            }
                        }

                        if (tpl)
                        {   // Wrap a template around function fd
                            Dsymbols *decldefs = new Dsymbols();
                            decldefs->push(fd);
                            TemplateDeclaration *tempdecl =
                                new TemplateDeclaration(fd->loc, fd->ident, tpl, NULL, decldefs, 0);
                            tempdecl->literal = 1;      // it's a template 'literal'
                            tiargs->push(tempdecl);
                            goto L1;
                        }
                    }
                }

                tiargs->push(ea);
            }
         L1:
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

Objects *Parser::parseTemplateArgument()
{
    //printf("parseTemplateArgument()\n");
    Objects *tiargs = new Objects();
    Type *ta;
    switch (token.value)
    {
        case TOKidentifier:
            ta = new TypeIdentifier(loc, token.ident);
            goto LabelX;

        case BASIC_TYPES_X(ta):
            tiargs->push(ta);
            nextToken();
            break;

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
        case TOKfile:
        case TOKline:
        case TOKthis:
        {   // Template argument is an expression
            Expression *ea = parsePrimaryExp();
            tiargs->push(ea);
            break;
        }

        default:
            error("template argument expected following !");
            break;
    }
    if (token.value == TOKnot)
        error("multiple ! arguments are not allowed");
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
        error("';' expected");
        nextToken();
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

        case TOKthis:
        case TOKsuper:
        case TOKidentifier:
            id = token.ident;
            nextToken();
            if (token.value == TOKnot)
            {   // ident!(template_arguments)
                TemplateInstance *tempinst = new TemplateInstance(loc, id);
                nextToken();
                if (token.value == TOKlparen)
                    // ident!(template_arguments)
                    tempinst->tiargs = parseTemplateArgumentList();
                else
                    // ident!template_argument
                    tempinst->tiargs = parseTemplateArgument();
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
                    TemplateInstance *tempinst = new TemplateInstance(loc, id);
                    nextToken();
                    if (token.value == TOKlparen)
                        // ident!(template_arguments)
                        tempinst->tiargs = parseTemplateArgumentList();
                    else
                        // ident!template_argument
                        tempinst->tiargs = parseTemplateArgument();
                    tid->addIdent((Identifier *)tempinst);
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
            // typeof(expression)
            tid = parseTypeof();
            goto Lident2;

        case TOKconst:
            // const(type)
            nextToken();
            check(TOKlparen);
            t = parseType();
            check(TOKrparen);
            if (t->isShared())
                t = t->makeSharedConst();
            else
                t = t->makeConst();
            break;

        case TOKinvariant:
            if (!global.params.useDeprecated)
                error("use of 'invariant' rather than 'immutable' is deprecated");
        case TOKimmutable:
            // invariant(type)
            nextToken();
            check(TOKlparen);
            t = parseType();
            check(TOKrparen);
            t = t->makeInvariant();
            break;

        case TOKshared:
            // shared(type)
            nextToken();
            check(TOKlparen);
            t = parseType();
            check(TOKrparen);
            if (t->isConst())
                t = t->makeSharedConst();
            else if (t->isWild())
                t = t->makeSharedWild();
            else
                t = t->makeShared();
            break;

        case TOKwild:
            // wild(type)
            nextToken();
            check(TOKlparen);
            t = parseType();
            check(TOKrparen);
            if (t->isShared())
                t = t->makeSharedWild();
            else
                t = t->makeWild();
            break;

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
                    t = new TypeDArray(t);                      // []
                    nextToken();
                }
                else if (isDeclaration(&token, 0, TOKrbracket, NULL))
                {   // It's an associative array declaration

                    //printf("it's an associative array\n");
                    Type *index = parseType();          // [ type ]
                    t = new TypeAArray(t, index);
                    check(TOKrbracket);
                }
                else
                {
                    //printf("it's type[expression]\n");
                    inBrackets++;
                    Expression *e = parseAssignExp();           // [ expression ]
                    if (token.value == TOKslice)
                    {
                        nextToken();
                        Expression *e2 = parseAssignExp();      // [ exp .. exp ]
                        t = new TypeSlice(t, e, e2);
                    }
                    else
                        t = new TypeSArray(t,e);
                    inBrackets--;
                    check(TOKrbracket);
                }
                continue;

            case TOKdelegate:
            case TOKfunction:
            {   // Handle delegate declaration:
                //      t delegate(parameter list) nothrow pure
                //      t function(parameter list) nothrow pure
                Parameters *arguments;
                int varargs;
                enum TOK save = token.value;

                nextToken();
                arguments = parseParameters(&varargs);

                StorageClass stc = parsePostfix();
                if (stc & (STCconst | STCimmutable | STCshared | STCwild))
                    error("const/immutable/shared/inout attributes are only valid for non-static member functions");

                TypeFunction *tf = new TypeFunction(arguments, t, varargs, linkage, stc);

                if (save == TOKdelegate)
                    t = new TypeDelegate(tf);
                else
                    t = new TypePointer(tf);    // pointer to function
                continue;
            }

            default:
                return t;
        }
        assert(0);
    }
    assert(0);
    return NULL;
}

Type *Parser::parseDeclarator(Type *t, Identifier **pident, TemplateParameters **tpl, StorageClass storage_class)
{   Type *ts;

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
            if (peekNext() == TOKmul ||                 // like: T (*fp)();
                peekNext() == TOKlparen                 // like: T ((*fp))();
                /* || peekNext() == TOKlbracket*/)      // like: T ([] a)
            {
                /* Parse things with parentheses around the identifier, like:
                 *  int (*ident[3])[]
                 * although the D style would be:
                 *  int[]*[3] ident
                 */
                if (!global.params.useDeprecated)
                {
                    error("C-style function pointer and pointer to array syntax is deprecated. Use 'function' to declare function pointers");
                }
                nextToken();
                ts = parseDeclarator(t, pident);
                check(TOKrparen);
                break;
            }
            ts = t;
        {
            Token *peekt = &token;
            /* Completely disallow C-style things like:
             *   T (a);
             * Improve error messages for the common bug of a missing return type
             * by looking to see if (a) looks like a parameter list.
             */
            if (isParameters(&peekt)) {
                error("function declaration without return type. "
                "(Note that constructors are always named 'this')");
            }
            else
                error("unexpected ( in declarator");
        }
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
                TypeNext *ta;
                nextToken();
                if (token.value == TOKrbracket)
                {   // It's a dynamic array
                    ta = new TypeDArray(t);             // []
                    nextToken();
                }
                else if (isDeclaration(&token, 0, TOKrbracket, NULL))
                {   // It's an associative array

                    //printf("it's an associative array\n");
                    Type *index = parseType();          // [ type ]
                    check(TOKrbracket);
                    ta = new TypeAArray(t, index);
                }
                else
                {
                    //printf("It's a static array\n");
                    Expression *e = parseAssignExp();   // [ expression ]
                    ta = new TypeSArray(t, e);
                    check(TOKrbracket);
                }

                /* Insert ta into
                 *   ts -> ... -> t
                 * so that
                 *   ts -> ... -> ta -> t
                 */
                Type **pt;
                for (pt = &ts; *pt != t; pt = &((TypeNext*)*pt)->next)
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

                /* Parse const/immutable/shared/inout/nothrow/pure postfix
                 */
                StorageClass stc = parsePostfix();
                stc |= storage_class;   // merge prefix storage classes
                Type *tf = new TypeFunction(arguments, t, varargs, linkage, stc);

                if (stc & STCconst)
                {   if (tf->isShared())
                        tf = tf->makeSharedConst();
                    else
                        tf = tf->makeConst();
                }
                if (stc & STCimmutable)
                    tf = tf->makeInvariant();
                if (stc & STCshared)
                {   if (tf->isConst())
                        tf = tf->makeSharedConst();
                    else
                        tf = tf->makeShared();
                }
                if (stc & STCwild)
                {   if (tf->isShared())
                        tf = tf->makeSharedWild();
                    else
                        tf = tf->makeWild();
                }

                /* Insert tf into
                 *   ts -> ... -> t
                 * so that
                 *   ts -> ... -> tf -> t
                 */
                Type **pt;
                for (pt = &ts; *pt != t; pt = &((TypeNext*)*pt)->next)
                    ;
                *pt = tf;
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

Dsymbols *Parser::parseDeclarations(StorageClass storage_class, unsigned char *comment)
{
    StorageClass stc;
    Type *ts;
    Type *t;
    Type *tfirst;
    Identifier *ident;
    Dsymbols *a;
    enum TOK tok = TOKreserved;
    enum LINK link = linkage;

    //printf("parseDeclarations() %s\n", token.toChars());
    if (!comment)
        comment = token.blockComment;

    if (storage_class)
    {   ts = NULL;              // infer type
        goto L2;
    }

    switch (token.value)
    {
        case TOKalias:
            /* Look for:
             *   alias identifier this;
             */
            tok = token.value;
            nextToken();
            if (token.value == TOKidentifier && peek(&token)->value == TOKthis)
            {
                AliasThis *s = new AliasThis(this->loc, token.ident);
                nextToken();
                check(TOKthis);
                check(TOKsemicolon);
                a = new Dsymbols();
                a->push(s);
                addComment(s, comment);
                return a;
            }
            break;
        case TOKtypedef:
            tok = token.value;
            nextToken();
            break;
    }

    storage_class = STCundefined;
    while (1)
    {
        switch (token.value)
        {
            case TOKconst:
                if (peek(&token)->value == TOKlparen)
                    break;              // const as type constructor
                stc = STCconst;         // const as storage class
                goto L1;

            case TOKinvariant:
            case TOKimmutable:
                if (peek(&token)->value == TOKlparen)
                    break;
                stc = STCimmutable;
                goto L1;

            case TOKshared:
                if (peek(&token)->value == TOKlparen)
                    break;
                stc = STCshared;
                goto L1;

            case TOKwild:
                if (peek(&token)->value == TOKlparen)
                    break;
                stc = STCwild;
                goto L1;

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
            case TOKgshared:    stc = STCgshared;        goto L1;
            case TOKenum:       stc = STCmanifest;       goto L1;
            case TOKat:         stc = parseAttribute();  goto L1;
#endif
            L1:
                if (storage_class & stc)
                    error("redundant storage class '%s'", token.toChars());
                storage_class = storage_class | stc;
                composeStorageClass(storage_class);
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

    /* Look for auto initializers:
     *  storage_class identifier = initializer;
     */
    if (storage_class &&
        token.value == TOKidentifier &&
        peek(&token)->value == TOKassign)
    {
        return parseAutoDeclarations(storage_class, comment);
    }

    if (token.value == TOKclass)
    {
        AggregateDeclaration *s = (AggregateDeclaration *)parseAggregate();
        s->storage_class |= storage_class;
        Dsymbols *a = new Dsymbols();
        a->push(s);
        addComment(s, comment);
        return a;
    }

    /* Look for return type inference for template functions.
     */
    {
    Token *tk;
    if (storage_class &&
        token.value == TOKidentifier &&
        (tk = peek(&token))->value == TOKlparen &&
        skipParens(tk, &tk) &&
        peek(tk)->value == TOKlparen)
    {
        ts = NULL;
    }
    else
    {
        ts = parseBasicType();
        ts = parseBasicType2(ts);
    }
    }

L2:
    tfirst = NULL;
    a = new Dsymbols();

    while (1)
    {
        Loc loc = this->loc;
        TemplateParameters *tpl = NULL;

        ident = NULL;
        t = parseDeclarator(ts, &ident, &tpl, storage_class);
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
                v = new TypedefDeclaration(loc, ident, t, init);
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
        {
            TypeFunction *tf = (TypeFunction *)t;
            Expression *constraint = NULL;
#if 0
            if (Parameter::isTPL(tf->parameters))
            {
                if (!tpl)
                    tpl = new TemplateParameters();
            }
#endif

            //printf("%s funcdecl t = %s, storage_class = x%lx\n", loc.toChars(), t->toChars(), storage_class);

            FuncDeclaration *f =
                new FuncDeclaration(loc, 0, ident, storage_class, t);
            addComment(f, comment);
            if (tpl)
                constraint = parseConstraint();
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
            /* A template parameter list means it's a function template
             */
            if (tpl)
            {
                // Wrap a template around the function declaration
                Dsymbols *decldefs = new Dsymbols();
                decldefs->push(s);
                TemplateDeclaration *tempdecl =
                    new TemplateDeclaration(loc, s->ident, tpl, constraint, decldefs, 0);
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
                    error("semicolon expected, not '%s'", token.toChars());
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
                f->fthrows = new Types();
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
                check(TOKlparen);
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
            if (!f->frequire && !f->fensure)            // allow these even with no body
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
             * If it ends with a ';' ',' or '}', it is an array initializer.
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
                        ia->addInit(NULL, value);
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

#if DMDV2
Expression *Parser::parseDefaultInitExp()
{
    if (token.value == TOKfile ||
        token.value == TOKline)
    {
        Token *t = peek(&token);
        if (t->value == TOKcomma || t->value == TOKrparen)
        {   Expression *e;

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
#endif

/*****************************************
 */

void Parser::checkDanglingElse(Loc elseloc)
{
    if (token.value != TOKelse &&
        token.value != TOKcatch &&
        token.value != TOKfinally &&
        lookingForElse.linnum != 0)
    {
        warning(elseloc, "else is dangling, add { } after condition at %s", lookingForElse.toChars());
    }
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
    bool isfinal;
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
#if DMDV2
        case TOKtraits:
        case TOKfile:
        case TOKline:
#endif
        Lexp:
        {
            Expression *exp = parseExpression();
            check(TOKsemicolon, "statement");
            s = new ExpStatement(loc, exp);
            break;
        }

        case TOKstatic:
        {   // Look ahead to see if it's static assert() or static if()

            Token *t = peek(&token);
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
            if (t->value == TOKstruct || t->value == TOKunion || t->value == TOKclass)
            {
                nextToken();
                Dsymbols *a = parseBlock();
                Dsymbol *d = new StorageClassDeclaration(STCstatic, a);
                s = new ExpStatement(loc, d);
                if (flags & PSscope)
                    s = new ScopeStatement(loc, s);
                break;
            }
            if (t->value == TOKimport)
            {   nextToken();
                Dsymbols *imports = new Dsymbols();
                parseImport(imports, 1);                // static import ...
                s = new ImportStatement(loc, imports);
                break;
            }
            goto Ldeclaration;
        }

        case TOKfinal:
            if (peekNext() == TOKswitch)
            {
                nextToken();
                isfinal = TRUE;
                goto Lswitch;
            }
            goto Ldeclaration;

        case BASIC_TYPES:
        case TOKtypedef:
        case TOKalias:
        case TOKconst:
        case TOKauto:
        case TOKextern:
        case TOKinvariant:
#if DMDV2
        case TOKimmutable:
        case TOKshared:
        case TOKwild:
        case TOKnothrow:
        case TOKpure:
        case TOKref:
        case TOKtls:
        case TOKgshared:
        case TOKat:
#endif
//      case TOKtypeof:
        Ldeclaration:
        {   Dsymbols *a;

            a = parseDeclarations(STCundefined, NULL);
            if (a->dim > 1)
            {
                Statements *as = new Statements();
                as->reserve(a->dim);
                for (size_t i = 0; i < a->dim; i++)
                {
                    Dsymbol *d = a->tdata()[i];
                    s = new ExpStatement(loc, d);
                    as->push(s);
                }
                s = new CompoundDeclarationStatement(loc, as);
            }
            else if (a->dim == 1)
            {
                Dsymbol *d = a->tdata()[0];
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
        {   /* Determine if this is a manifest constant declaration,
             * or a conventional enum.
             */
            Dsymbol *d;
            Token *t = peek(&token);
            if (t->value == TOKlcurly || t->value == TOKcolon)
                d = parseEnum();
            else if (t->value != TOKidentifier)
                goto Ldeclaration;
            else
            {
                t = peek(t);
                if (t->value == TOKlcurly || t->value == TOKcolon ||
                    t->value == TOKsemicolon)
                    d = parseEnum();
                else
                    goto Ldeclaration;
            }
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
            Loc lookingForElseSave = lookingForElse;
            lookingForElse = 0;

            nextToken();
            //if (token.value == TOKsemicolon)
                //error("use '{ }' for an empty statement, not a ';'");
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
            lookingForElse = lookingForElseSave;
            break;
        }

        case TOKwhile:
        {   Expression *condition;
            Statement *body;

            nextToken();
            check(TOKlparen);
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
            Loc lookingForElseSave = lookingForElse;
            lookingForElse = 0;
            body = parseStatement(PSscope);
            lookingForElse = lookingForElseSave;
            check(TOKwhile);
            check(TOKlparen);
            condition = parseExpression();
            check(TOKrparen);
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
            check(TOKlparen);
            if (token.value == TOKsemicolon)
            {   init = NULL;
                nextToken();
            }
            else
            {
                Loc lookingForElseSave = lookingForElse;
                lookingForElse = 0;
                init = parseStatement(0);
                lookingForElse = lookingForElseSave;
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

            nextToken();
            check(TOKlparen);

            Parameters *arguments = new Parameters();

            while (1)
            {
                Identifier *ai = NULL;
                Type *at;

                StorageClass storageClass = 0;
                if (token.value == TOKref
#if D1INOUT
                        || token.value == TOKinout
#endif
                   )
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
                at = parseType(&ai);
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
            check(TOKsemicolon);

            Expression *aggr = parseExpression();
            if (token.value == TOKslice && arguments->dim == 1)
            {
                Parameter *a = arguments->tdata()[0];
                delete arguments;
                nextToken();
                Expression *upr = parseExpression();
                check(TOKrparen);
                Statement *body = parseStatement(0);
                s = new ForeachRangeStatement(loc, op, a, aggr, upr, body);
            }
            else
            {
                check(TOKrparen);
                Statement *body = parseStatement(0);
                s = new ForeachStatement(loc, op, arguments, aggr, body);
            }
            break;
        }

        case TOKif:
        {   Parameter *arg = NULL;
            Expression *condition;
            Statement *ifbody;
            Statement *elsebody;

            nextToken();
            check(TOKlparen);

            if (token.value == TOKauto)
            {
                nextToken();
                if (token.value == TOKidentifier)
                {
                    Token *t = peek(&token);
                    if (t->value == TOKassign)
                    {
                        arg = new Parameter(0, NULL, token.ident, NULL);
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
                Type *at;
                Identifier *ai;

                at = parseType(&ai);
                check(TOKassign);
                arg = new Parameter(0, at, ai, NULL);
            }

            // Check for " ident;"
            else if (token.value == TOKidentifier)
            {
                Token *t = peek(&token);
                if (t->value == TOKcomma || t->value == TOKsemicolon)
                {
                    arg = new Parameter(0, NULL, token.ident, NULL);
                    nextToken();
                    nextToken();
                    if (1 || !global.params.useDeprecated)
                        error("if (v; e) is deprecated, use if (auto v = e)");
                }
            }

            condition = parseExpression();
            check(TOKrparen);
            {
                Loc lookingForElseSave = lookingForElse;
                lookingForElse = loc;
                ifbody = parseStatement(PSscope);
                lookingForElse = lookingForElseSave;
            }
            if (token.value == TOKelse)
            {
                Loc elseloc = this->loc;
                nextToken();
                elsebody = parseStatement(PSscope);
                checkDanglingElse(elseloc);
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
            check(TOKlparen);
            if (token.value != TOKidentifier)
            {   error("scope identifier expected");
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
            {
                Loc lookingForElseSave = lookingForElse;
                lookingForElse = loc;
                ifbody = parseStatement(0 /*PSsemi*/);
                lookingForElse = lookingForElseSave;
            }
            elsebody = NULL;
            if (token.value == TOKelse)
            {
                Loc elseloc = this->loc;
                nextToken();
                elsebody = parseStatement(0 /*PSsemi*/);
                checkDanglingElse(elseloc);
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
            isfinal = FALSE;
            goto Lswitch;

        Lswitch:
        {
            nextToken();
            check(TOKlparen);
            Expression *condition = parseExpression();
            check(TOKrparen);
            Statement *body = parseStatement(PSscope);
            s = new SwitchStatement(loc, condition, body, isfinal);
            break;
        }

        case TOKcase:
        {   Expression *exp;
            Statements *statements;
            Expressions cases;        // array of Expression's
            Expression *last = NULL;

            while (1)
            {
                nextToken();
                exp = parseAssignExp();
                cases.push(exp);
                if (token.value != TOKcomma)
                    break;
            }
            check(TOKcolon);

#if DMDV2
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
#endif

            statements = new Statements();
            while (token.value != TOKcase &&
                   token.value != TOKdefault &&
                   token.value != TOKeof &&
                   token.value != TOKrcurly)
            {
                statements->push(parseStatement(PSsemi | PScurlyscope));
            }
            s = new CompoundStatement(loc, statements);
            s = new ScopeStatement(loc, s);

#if DMDV2
            if (last)
            {
                s = new CaseRangeStatement(loc, exp, last, s);
            }
            else
#endif
            {
                // Keep cases in order by building the case statements backwards
                for (size_t i = cases.dim; i; i--)
                {
                    exp = cases.tdata()[i - 1];
                    s = new CaseStatement(loc, exp, s);
                }
            }
            break;
        }

        case TOKdefault:
        {
            Statements *statements;

            nextToken();
            check(TOKcolon);

            statements = new Statements();
            while (token.value != TOKcase &&
                   token.value != TOKdefault &&
                   token.value != TOKeof &&
                   token.value != TOKrcurly)
            {
                statements->push(parseStatement(PSsemi | PScurlyscope));
            }
            s = new CompoundStatement(loc, statements);
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
            check(TOKsemicolon, "return statement");
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
            check(TOKlparen);
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
            Loc lookingForElseSave = lookingForElse;
            lookingForElse = 0;
            body = parseStatement(PSscope);
            lookingForElse = lookingForElseSave;
            while (token.value == TOKcatch)
            {
                Statement *handler;
                Catch *c;
                Type *t;
                Identifier *id;
                Loc loc = this->loc;

                nextToken();
                if (token.value == TOKlcurly)
                {
                    t = NULL;
                    id = NULL;
                }
                else
                {
                    check(TOKlparen);
                    id = NULL;
                    t = parseType(&id);
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
#if DMDV2
            if (!global.params.useDeprecated)
                error("volatile statements deprecated; used synchronized statements instead");
#endif
            s = new VolatileStatement(loc, s);
            break;

        case TOKasm:
        {   Statements *statements;
            Identifier *label;
            Loc labelloc;
            Token *toklist;
            Token **ptoklist;

            // Parse the asm block into a sequence of AsmStatements,
            // each AsmStatement is one instruction.
            // Separate out labels.
            // Defer parsing of AsmStatements until semantic processing.

            nextToken();
            check(TOKlcurly);
            toklist = NULL;
            ptoklist = &toklist;
            label = NULL;
            statements = new Statements();
            while (1)
            {
                switch (token.value)
                {
                    case TOKidentifier:
                        if (!toklist)
                        {
                            // Look ahead to see if it is a label
                            t = peek(&token);
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

                    case TOKrcurly:
                        if (toklist || label)
                        {
                            error("asm statements must end in ';'");
                        }
                        break;

                    case TOKsemicolon:
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
                        break;

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

        case TOKimport:
        {   Dsymbols *imports = new Dsymbols();
            parseImport(imports, 0);
            s = new ImportStatement(loc, imports);
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

void Parser::checkParens(enum TOK value, Expression *e)
{
    if (precedence[e->op] == PREC_rel && !e->parens)
        error(loc, "%s must be parenthesized when next to operator %s", e->toChars(), Token::toChars(value));
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
    int haveId = 0;

    switch (t->value)
    {
        case BASIC_TYPES:
            t = peek(t);
            break;

        case TOKidentifier:
        L5:
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
                    /* Seen a !
                     * Look for:
                     * !( args ), !identifier, etc.
                     */
                    t = peek(t);
                    switch (t->value)
                    {   case TOKidentifier:
                            goto L5;
                        case TOKlparen:
                            if (!skipParens(t, &t))
                                goto Lfalse;
                            break;
                        case BASIC_TYPES:
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
                        case TOKfile:
                        case TOKline:
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
            /* typeof(exp).identifier...
             */
            t = peek(t);
            if (t->value != TOKlparen)
                goto Lfalse;
            if (!skipParens(t, &t))
                goto Lfalse;
            goto L2;

        case TOKconst:
        case TOKinvariant:
        case TOKimmutable:
        case TOKshared:
        case TOKwild:
            // const(type)  or  immutable(type)  or  shared(type)  or  wild(type)
            t = peek(t);
            if (t->value != TOKlparen)
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
            case TOKsemicolon:
            case TOKlcurly:
            case TOKin:
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

    //printf("isParameters()\n");
    if (t->value != TOKlparen)
        return FALSE;

    t = peek(t);
    for (;1; t = peek(t))
    {
     L1:
        switch (t->value)
        {
            case TOKrparen:
                break;

            case TOKdotdotdot:
                t = peek(t);
                break;

#if D1INOUT
            case TOKinout:
#endif
            case TOKin:
            case TOKout:
            case TOKref:
            case TOKlazy:
            case TOKfinal:
            case TOKauto:
                continue;

            case TOKconst:
            case TOKinvariant:
            case TOKimmutable:
            case TOKshared:
            case TOKwild:
                t = peek(t);
                if (t->value == TOKlparen)
                {
                    t = peek(t);
                    if (!isDeclaration(t, 0, TOKrparen, &t))
                        return FALSE;
                    t = peek(t);        // skip past closing ')'
                    goto L2;
                }
                goto L1;

#if 0
            case TOKstatic:
                continue;
            case TOKauto:
            case TOKalias:
                t = peek(t);
                if (t->value == TOKidentifier)
                    t = peek(t);
                if (t->value == TOKassign)
                {   t = peek(t);
                    if (!isExpression(&t))
                        return FALSE;
                }
                goto L3;
#endif

            default:
            {   if (!isBasicType(&t))
                    return FALSE;
            L2:
                int tmp = FALSE;
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
            }
                if (t->value == TOKcomma)
                {
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
    int curlynest = 0;

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

            case TOKlcurly:
                curlynest++;
                continue;

            case TOKrcurly:
                if (--curlynest >= 0)
                    continue;
                return FALSE;

            case TOKslice:
                if (brnest)
                    continue;
                break;

            case TOKsemicolon:
                if (curlynest)
                    continue;
                return FALSE;

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
    if (*pt)
        *pt = t;
    return 1;

  Lfalse:
    return 0;
}

/*******************************************
 * Skip attributes.
 * Input:
 *      t is on a candidate attribute
 * Output:
 *      *pt is set to first non-attribute token on success
 * Returns:
 *      !=0     successful
 *      0       some parsing error
 */

int Parser::skipAttributes(Token *t, Token **pt)
{
    while (1)
    {
        switch (t->value)
        {
            case TOKconst:
            case TOKinvariant:
            case TOKimmutable:
            case TOKshared:
            case TOKwild:
            case TOKfinal:
            case TOKauto:
            case TOKscope:
            case TOKoverride:
            case TOKabstract:
            case TOKsynchronized:
            case TOKdeprecated:
            case TOKnothrow:
            case TOKpure:
            case TOKref:
            case TOKtls:
            case TOKgshared:
            //case TOKmanifest:
                break;
            case TOKat:
                if (parseAttribute() == STCundefined)
                    break;
                goto Lerror;
            default:
                goto Ldone;
        }
        t = peek(t);
    }

  Ldone:
    if (*pt)
        *pt = t;
    return 1;

  Lerror:
    return 0;
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
            if (token.value == TOKnot && (save = peekNext()) != TOKis && save != TOKin)
            {   // identifier!(template-argument-list)
                TemplateInstance *tempinst;

                tempinst = new TemplateInstance(loc, id);
                nextToken();
                if (token.value == TOKlparen)
                    // ident!(template_arguments)
                    tempinst->tiargs = parseTemplateArgumentList();
                else
                    // ident!template_argument
                    tempinst->tiargs = parseTemplateArgument();
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

#if DMDV2
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
#endif

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
        {
            t = parseTypeof();
            e = new TypeExp(loc, t);
            break;
        }

        case TOKtypeid:
        {
            nextToken();
            check(TOKlparen, "typeid");
            Object *o;
            if (isDeclaration(&token, 0, TOKreserved, NULL))
            {   // argument is a type
                o = parseType();
            }
            else
            {   // argument is an expression
                o = parseAssignExp();
            }
            check(TOKrparen);
            e = new TypeidExp(loc, o);
            break;
        }

#if DMDV2
        case TOKtraits:
        {   /* __traits(identifier, args...)
             */
            Identifier *ident;
            Objects *args = NULL;

            nextToken();
            check(TOKlparen);
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
            TemplateParameters *tpl = NULL;
            Loc loc = this->loc;

            nextToken();
            if (token.value == TOKlparen)
            {
                nextToken();
                targ = parseType(&ident);
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
                         token.value == TOKwild && peek(&token)->value == TOKrparen ||
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
                        tspec = parseType();
                    }
                }
                if (ident && tspec)
                {
                    if (token.value == TOKcomma)
                        tpl = parseTemplateParameterList(1);
                    else
                    {   tpl = new TemplateParameters();
                        check(TOKrparen);
                    }
                    TemplateParameter *tp = new TemplateTypeParameter(loc, ident, NULL, NULL);
                    tpl->insert(0, tp);
                }
                else
                    check(TOKrparen);
            }
            else
            {   error("(type identifier : specialization) expected following is");
                goto Lerr;
            }
            e = new IsExp(loc, targ, ident, tok, tspec, tok2, tpl);
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
            e->parens = 1;
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
            while (token.value != TOKrbracket && token.value != TOKeof)
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
            // { statements... }
            save = TOKdelegate;
            goto case_delegate;

        case TOKfunction:
        case TOKdelegate:
            save = token.value;
            nextToken();
        case_delegate:
        {
            /* function type(parameters) { body } pure nothrow
             * delegate type(parameters) { body } pure nothrow
             * (parameters) { body }
             * { body }
             */
            Parameters *arguments;
            int varargs;
            FuncLiteralDeclaration *fd;
            Type *t;
            StorageClass stc = 0;

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
                stc = parsePostfix();
                if (stc & (STCconst | STCimmutable | STCshared | STCwild))
                    error("const/immutable/shared/inout attributes are only valid for non-static member functions");
            }

            TypeFunction *tf = new TypeFunction(arguments, t, varargs, linkage, stc);

            fd = new FuncLiteralDeclaration(loc, 0, tf, save, NULL);
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
    return e;
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
                    if (token.value == TOKnot && peekNext() != TOKis && peekNext() != TOKin)
                    {   // identifier!(template-argument-list)
                        TemplateInstance *tempinst = new TemplateInstance(loc, id);
                        Objects *tiargs;
                        nextToken();
                        if (token.value == TOKlparen)
                            // ident!(template_arguments)
                            tiargs = parseTemplateArgumentList();
                        else
                            // ident!template_argument
                            tiargs = parseTemplateArgument();
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
                            while (token.value != TOKrbracket && token.value != TOKeof)
                            {
                                Expression *arg = parseAssignExp();
                                arguments->push(arg);
                                if (token.value == TOKrbracket)
                                    break;
                                check(TOKcomma);
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

        case TOKnew:
            e = parseNewExp(NULL);
            break;

        case TOKcast:                           // cast(type) expression
        {
            nextToken();
            check(TOKlparen);
            /* Look for cast(), cast(const), cast(immutable),
             * cast(shared), cast(shared const), cast(wild), cast(shared wild)
             */
            unsigned m;
            if (token.value == TOKrparen)
            {
                m = 0;
                goto Lmod1;
            }
            else if (token.value == TOKconst && peekNext() == TOKrparen)
            {
                m = MODconst;
                goto Lmod2;
            }
            else if ((token.value == TOKimmutable || token.value == TOKinvariant) && peekNext() == TOKrparen)
            {
                m = MODimmutable;
                goto Lmod2;
            }
            else if (token.value == TOKshared && peekNext() == TOKrparen)
            {
                m = MODshared;
                goto Lmod2;
            }
            else if (token.value == TOKwild && peekNext() == TOKrparen)
            {
                m = MODwild;
                goto Lmod2;
            }
            else if (token.value == TOKwild && peekNext() == TOKshared && peekNext2() == TOKrparen ||
                     token.value == TOKshared && peekNext() == TOKwild && peekNext2() == TOKrparen)
            {
                m = MODshared | MODwild;
                goto Lmod3;
            }
            else if (token.value == TOKconst && peekNext() == TOKshared && peekNext2() == TOKrparen ||
                     token.value == TOKshared && peekNext() == TOKconst && peekNext2() == TOKrparen)
            {
                m = MODshared | MODconst;
              Lmod3:
                nextToken();
              Lmod2:
                nextToken();
              Lmod1:
                nextToken();
                e = parseUnaryExp();
                e = new CastExp(loc, e, m);
            }
            else
            {
                Type *t = parseType();          // ( type )
                check(TOKrparen);
                e = parseUnaryExp();
                e = new CastExp(loc, e, t);
            }
            break;
        }

        case TOKwild:
        case TOKshared:
        case TOKconst:
        case TOKinvariant:
        case TOKimmutable:      // immutable(type)(arguments)
        {
            Type *t = parseBasicType();
            if (token.value != TOKlparen)
                error("(arguments) expected following type");
            e = new TypeExp(loc, t);
            e = new CallExp(loc, e, parseArguments());
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
                        if (tk->value == TOKis || tk->value == TOKin)   // !is or !in
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
#if DMDV2
                    case TOKfile:
                    case TOKline:
#endif
                    case BASIC_TYPES:           // (type)int.size
                    {   // (type) una_exp
                        Type *t;

                        nextToken();
                        t = parseType();
                        check(TOKrparen);

                        // if .identifier
                        if (token.value == TOKdot)
                        {
                            nextToken();
                            if (token.value != TOKidentifier)
                            {   error("Identifier expected following (type).");
                                return NULL;
                            }
                            e = typeDotIdExp(loc, t, token.ident);
                            nextToken();
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
                }
            }
#endif
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
        Expression *e2 = parseUnaryExp();
        e = new PowExp(loc, e, e2);
    }

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

#if DMDV1
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
#endif

#if DMDV1
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
#endif

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
            if (t->value == TOKin)
            {
                nextToken();
                nextToken();
                e2 = parseShiftExp();
                e = new InExp(loc, e, e2);
                e = new NotExp(loc, e);
                break;
            }
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
{
    Loc loc = this->loc;

    Expression *e = parseCmpExp();
    while (token.value == TOKand)
    {
        checkParens(TOKand, e);
        nextToken();
        Expression *e2 = parseCmpExp();
        checkParens(TOKand, e2);
        e = new AndExp(loc,e,e2);
        loc = this->loc;
    }
    return e;
}

Expression *Parser::parseXorExp()
{
    Loc loc = this->loc;

    Expression *e = parseAndExp();
    while (token.value == TOKxor)
    {
        checkParens(TOKxor, e);
        nextToken();
        Expression *e2 = parseAndExp();
        checkParens(TOKxor, e2);
        e = new XorExp(loc, e, e2);
    }
    return e;
}

Expression *Parser::parseOrExp()
{
    Loc loc = this->loc;

    Expression *e = parseXorExp();
    while (token.value == TOKor)
    {
        checkParens(TOKor, e);
        nextToken();
        Expression *e2 = parseXorExp();
        checkParens(TOKor, e2);
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
        check(TOKcolon);
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
            X(TOKpowass,    PowAssignExp);
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
 * Assume current token is ',', '(' or '['.
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
        while (token.value != endtok)
        {
                arg = parseAssignExp();
                arguments->push(arg);
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

    t = parseBasicType();
    t = parseBasicType2(t);
    if (t->ty == Taarray)
    {   TypeAArray *taa = (TypeAArray *)t;
        Type *index = taa->index;

        Expression *e = index->toExpression();
        if (e)
        {   arguments = new Expressions();
            arguments->push(e);
            t = new TypeDArray(taa->next);
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
        t = new TypeDArray(tsa->next);
    }
    else if (token.value == TOKlparen)
    {
        arguments = parseArguments();
    }
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
#if DMDV2
    precedence[TOKfile] = PREC_primary;
    precedence[TOKline] = PREC_primary;
#endif
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
#if DMDV2
    precedence[TOKtraits] = PREC_primary;
    precedence[TOKdefault] = PREC_primary;
    precedence[TOKoverloadset] = PREC_primary;
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


