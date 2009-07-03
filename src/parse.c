
// Compiler implementation of the D programming language
// Copyright (c) 1999-2007 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "mem.h"
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

// How multiple declarations are parsed.
// If 1, treat as C.
// If 0, treat:
//	int *p, i;
// as:
//	int* p;
//	int* i;
#define CDECLSYNTAX	0

// Support C cast syntax:
//	(type)(expression)
#define CCASTSYNTAX	1

// Support C array declarations, such as
//	int a[3][4];
#define CARRAYDECL	1

// Support left-to-right array declarations
#define LTORARRAYDECL	1


Parser::Parser(Module *module, unsigned char *base, unsigned length, int doDocComment)
    : Lexer(module, base, 0, length, doDocComment, 0)
{
    //printf("Parser::Parser()\n");
    md = NULL;
    linkage = LINKd;
    endloc = 0;
    inBrackets = 0;
    //nextToken();		// start up the scanner
}

Array *Parser::parseModule()
{
    Array *decldefs;

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
	    Array *a = NULL;
	    Identifier *id;

	    id = token.ident;
	    while (nextToken() == TOKdot)
	    {
		if (!a)
		    a = new Array();
		a->push(id);
		nextToken();
		if (token.value != TOKidentifier)
		{   error("Identifier expected following package");
		    goto Lerr;
		}
		id = token.ident;
	    }

	    md = new ModuleDeclaration(a, id);

	    if (token.value != TOKsemicolon)
		error("';' expected following module declaration instead of %s", token.toChars());
	    nextToken();
	    addComment(mod, comment);
	}
    }

    decldefs = parseDeclDefs(0);
    if (token.value != TOKeof)
    {	error("unrecognized declaration");
	goto Lerr;
    }
    return decldefs;

Lerr:
    while (token.value != TOKsemicolon && token.value != TOKeof)
	nextToken();
    nextToken();
    return new Array();
}

Array *Parser::parseDeclDefs(int once)
{   Dsymbol *s;
    Array *decldefs;
    Array *a;
    Array *aelse;
    enum PROT prot;
    unsigned stc;
    Condition *condition;
    unsigned char *comment;

    //printf("Parser::parseDeclDefs()\n");
    decldefs = new Array();
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
	    {	Loc loc = this->loc;
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

	    CASE_BASIC_TYPES:
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
#if 1
		s = parseInvariant();
#else
		if (peek(&token)->value == TOKlcurly)
		    s = parseInvariant();
		else
		{
		    stc = STCinvariant;
		    goto Lstc;
		}
#endif
		break;

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

	    case TOKconst:	  stc = STCconst;	 goto Lstc;
	    case TOKfinal:	  stc = STCfinal;	 goto Lstc;
	    case TOKauto:	  stc = STCauto;	 goto Lstc;
	    case TOKscope:	  stc = STCscope;	 goto Lstc;
	    case TOKoverride:	  stc = STCoverride;	 goto Lstc;
	    case TOKabstract:	  stc = STCabstract;	 goto Lstc;
	    case TOKsynchronized: stc = STCsynchronized; goto Lstc;
	    case TOKdeprecated:   stc = STCdeprecated;	 goto Lstc;

	    Lstc:
		nextToken();
	    Lstc2:
		switch (token.value)
		{
		    case TOKconst:	  stc |= STCconst;	 goto Lstc;
		    case TOKfinal:	  stc |= STCfinal;	 goto Lstc;
		    case TOKauto:	  stc |= STCauto;	 goto Lstc;
		    case TOKscope:	  stc |= STCscope;	 goto Lstc;
		    case TOKoverride:	  stc |= STCoverride;	 goto Lstc;
		    case TOKabstract:	  stc |= STCabstract;	 goto Lstc;
		    case TOKsynchronized: stc |= STCsynchronized; goto Lstc;
		    case TOKdeprecated:   stc |= STCdeprecated;	 goto Lstc;
		    //case TOKinvariant:    stc |= STCinvariant;   goto Lstc;
		    default:
			break;
		}

		/* Look for auto initializers:
		 *	storage_class identifier = initializer;
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
	    case TOKprivate:	prot = PROTprivate;	goto Lprot;
	    case TOKpackage:	prot = PROTpackage;	goto Lprot;
	    case TOKprotected:	prot = PROTprotected;	goto Lprot;
	    case TOKpublic:	prot = PROTpublic;	goto Lprot;
	    case TOKexport:	prot = PROTexport;	goto Lprot;

	    Lprot:
		nextToken();
		a = parseBlock();
		s = new ProtDeclaration(prot, a);
		break;

	    case TOKalign:
	    {	unsigned n;

		s = NULL;
		nextToken();
		if (token.value == TOKlparen)
		{
		    nextToken();
		    if (token.value == TOKint32v)
			n = (unsigned)token.uns64value;
		    else
		    {	error("integer expected, not %s", token.toChars());
			n = 1;
		    }
		    nextToken();
		    check(TOKrparen);
		}
		else
		    n = global.structalign;		// default

		a = parseBlock();
		s = new AlignDeclaration(n, a);
		break;
	    }

	    case TOKpragma:
	    {	Identifier *ident;
		Expressions *args = NULL;

		nextToken();
		check(TOKlparen);
		if (token.value != TOKidentifier)
		{   error("pragma(identifier expected");
		    goto Lerror;
		}
		ident = token.ident;
		nextToken();
		if (token.value == TOKcomma)
		    args = parseArguments();	// pragma(identifier, args...)
		else
		    check(TOKrparen);		// pragma(identifier)

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
		    {	error("identifier or integer expected, not %s", token.toChars());
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
		    {	error("identifier or integer expected, not %s", token.toChars());
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
		a = parseBlock();
		aelse = NULL;
		if (token.value == TOKelse)
		{   nextToken();
		    aelse = parseBlock();
		}
		s = new ConditionalDeclaration(condition, a, aelse);
		break;

	    case TOKsemicolon:		// empty declaration
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


/********************************************
 * Parse declarations after an align, protection, or extern decl.
 */

Array *Parser::parseBlock()
{
    Array *a = NULL;
    Dsymbol *s;

    //printf("parseBlock()\n");
    switch (token.value)
    {
	case TOKsemicolon:
	    error("declaration expected following attribute, not ';'");
	    nextToken();
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
	    a = parseDeclDefs(0);	// grab declarations up to closing curly bracket
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
    {	nextToken();
	msg = parseAssignExp();
    }
    check(TOKrparen);
    check(TOKsemicolon);
    return new StaticAssert(loc, exp, msg);
}


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
	else
	{
	    error("valid linkage identifiers are D, C, C++, Pascal, Windows");
	    link = LINKd;
	}
    }
    else
    {
	link = LINKd;		// default
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
 *	static if (expression)
 *	    body
 *	else
 *	    body
 */

Condition *Parser::parseStaticIfCondition()
{   Expression *exp;
    Condition *condition;
    Array *aif;
    Array *aelse;
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
 *	this(arguments) { body }
 * Current token is 'this'.
 */

CtorDeclaration *Parser::parseCtor()
{
    CtorDeclaration *f;
    Arguments *arguments;
    int varargs;
    Loc loc = this->loc;

    nextToken();
    arguments = parseParameters(&varargs);
    f = new CtorDeclaration(loc, 0, arguments, varargs);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse a destructor definition:
 *	~this() { body }
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
 *	static this() { body }
 * Current token is 'this'.
 */

StaticCtorDeclaration *Parser::parseStaticCtor()
{
    StaticCtorDeclaration *f;
    Loc loc = this->loc;

    nextToken();
    check(TOKlparen);
    check(TOKrparen);

    f = new StaticCtorDeclaration(loc, 0);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse a static destructor definition:
 *	static ~this() { body }
 * Current token is '~'.
 */

StaticDtorDeclaration *Parser::parseStaticDtor()
{
    StaticDtorDeclaration *f;
    Loc loc = this->loc;

    nextToken();
    check(TOKthis);
    check(TOKlparen);
    check(TOKrparen);

    f = new StaticDtorDeclaration(loc, 0);
    parseContracts(f);
    return f;
}

/*****************************************
 * Parse an invariant definition:
 *	invariant { body }
 * Current token is 'invariant'.
 */

InvariantDeclaration *Parser::parseInvariant()
{
    InvariantDeclaration *f;
    Loc loc = this->loc;

    nextToken();
    if (token.value == TOKlparen)	// optional ()
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
 *	unittest { body }
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
 *	new(arguments) { body }
 * Current token is 'new'.
 */

NewDeclaration *Parser::parseNew()
{
    NewDeclaration *f;
    Arguments *arguments;
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
 *	delete(arguments) { body }
 * Current token is 'delete'.
 */

DeleteDeclaration *Parser::parseDelete()
{
    DeleteDeclaration *f;
    Arguments *arguments;
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

Arguments *Parser::parseParameters(int *pvarargs)
{
    Arguments *arguments = new Arguments();
    int varargs = 0;
    int hasdefault = 0;

    check(TOKlparen);
    while (1)
    {   Type *tb;
	Identifier *ai;
	Type *at;
	Argument *a;
	unsigned storageClass;
	Expression *ae;

	ai = NULL;
	storageClass = STCin;		// parameter is "in" by default
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
		if (token.value == TOKassign)	// = defaultArg
		{   nextToken();
		    ae = parseAssignExp();
		    hasdefault = 1;
		}
		else
		{   if (hasdefault)
			error("default argument expected for %s",
				ai ? ai->toChars() : at->toChars());
		}
		if (token.value == TOKdotdotdot)
		{   /* This is:
		     *	at ai ...
		     */

		    if (storageClass & (STCout | STCref))
			error("variadic argument cannot be out or ref");
		    varargs = 2;
		    a = new Argument(storageClass, at, ai, ae);
		    arguments->push(a);
		    nextToken();
		    break;
		}
		a = new Argument(storageClass, at, ai, ae);
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
    Type *t;
    Loc loc = this->loc;

    //printf("Parser::parseEnum()\n");
    nextToken();
    if (token.value == TOKidentifier)
    {	id = token.ident;
	nextToken();
    }
    else
	id = NULL;

    if (token.value == TOKcolon)
    {
	nextToken();
	t = parseBasicType();
    }
    else
	t = NULL;

    e = new EnumDeclaration(loc, id, t);
    if (token.value == TOKsemicolon && id)
 	nextToken();
    else if (token.value == TOKlcurly)
    {
	//printf("enum definition\n");
	e->members = new Array();
	nextToken();
	unsigned char *comment = token.blockComment;
	while (token.value != TOKrcurly)
	{
	    if (token.value == TOKidentifier)
	    {	EnumMember *em;
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
		em = new EnumMember(loc, ident, value);
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
	    else
	    {	error("enum member expected");
		nextToken();
	    }
	}
	nextToken();
    }
    else
	error("enum declaration is invalid");

    return e;
}

Dsymbol *Parser::parseAggregate()
{   AggregateDeclaration *a = NULL;
    int anon = 0;
    enum TOK tok;
    Identifier *id;
    TemplateParameters *tpl = NULL;

    //printf("Parser::parseAggregate()\n");
    tok = token.value;
    nextToken();
    if (token.value != TOKidentifier)
    {	id = NULL;
    }
    else
    {	id = token.ident;
	nextToken();

	if (token.value == TOKlparen)
	{   // Class template declaration.

	    // Gather template parameter list
	    tpl = parseTemplateParameterList();
	}
    }

    Loc loc = this->loc;
    switch (tok)
    {	case TOKclass:
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
    { 	nextToken();
    }
    else if (token.value == TOKlcurly)
    {
	//printf("aggregate definition\n");
	nextToken();
	Array *decl = parseDeclDefs(0);
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
    {	Array *decldefs;
	TemplateDeclaration *tempdecl;

	// Wrap a template around the aggregate declaration
	decldefs = new Array();
	decldefs->push(a);
	tempdecl = new TemplateDeclaration(loc, id, tpl, decldefs);
	return tempdecl;
    }

    return a;
}

/*******************************************
 */

BaseClasses *Parser::parseBaseClasses()
{
    enum PROT protection = PROTpublic;
    BaseClasses *baseclasses = new BaseClasses();

    for (; 1; nextToken())
    {
	switch (token.value)
	{
	    case TOKidentifier:
		break;
	    case TOKprivate:
		protection = PROTprivate;
		continue;
	    case TOKpackage:
		protection = PROTpackage;
		continue;
	    case TOKprotected:
		protection = PROTprotected;
		continue;
	    case TOKpublic:
		protection = PROTpublic;
		continue;
	    default:
		error("base classes expected instead of %s", token.toChars());
		return NULL;
	}
	BaseClass *b = new BaseClass(parseBasicType(), protection);
	baseclasses->push(b);
	if (token.value != TOKcomma)
	    break;
	protection = PROTpublic;
    }
    return baseclasses;
}

/**************************************
 * Parse a TemplateDeclaration.
 */

TemplateDeclaration *Parser::parseTemplateDeclaration()
{
    TemplateDeclaration *tempdecl;
    Identifier *id;
    TemplateParameters *tpl;
    Array *decldefs;
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
    {	error("members of template declaration expected");
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

    tempdecl = new TemplateDeclaration(loc, id, tpl, decldefs);
    return tempdecl;

Lerr:
    return NULL;
}

/******************************************
 * Parse template parameter list.
 */

TemplateParameters *Parser::parseTemplateParameterList()
{
    TemplateParameters *tpl;

    if (token.value != TOKlparen)
    {   error("parenthesized TemplateParameterList expected following TemplateIdentifier");
	goto Lerr;
    }
    tpl = new TemplateParameters();
    nextToken();

    // Get array of TemplateParameters
    if (token.value != TOKrparen)
    {	int isvariadic = 0;

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
	    {	// AliasParameter
		nextToken();
		if (token.value != TOKidentifier)
		{   error("Identifier expected for template parameter");
		    goto Lerr;
		}
		tp_ident = token.ident;
		nextToken();
		if (token.value == TOKcolon)	// : Type
		{
		    nextToken();
		    tp_spectype = parseBasicType();
		    tp_spectype = parseDeclarator(tp_spectype, NULL);
		}
		if (token.value == TOKassign)	// = Type
		{
		    nextToken();
		    tp_defaulttype = parseBasicType();
		    tp_defaulttype = parseDeclarator(tp_defaulttype, NULL);
		}
		tp = new TemplateAliasParameter(loc, tp_ident, tp_spectype, tp_defaulttype);
	    }
	    else if (t->value == TOKcolon || t->value == TOKassign ||
		     t->value == TOKcomma || t->value == TOKrparen)
	    {	// TypeParameter
		if (token.value != TOKidentifier)
		{   error("Identifier expected for template parameter");
		    goto Lerr;
		}
		tp_ident = token.ident;
		nextToken();
		if (token.value == TOKcolon)	// : Type
		{
		    nextToken();
		    tp_spectype = parseBasicType();
		    tp_spectype = parseDeclarator(tp_spectype, NULL);
		}
		if (token.value == TOKassign)	// = Type
		{
		    nextToken();
		    tp_defaulttype = parseBasicType();
		    tp_defaulttype = parseDeclarator(tp_defaulttype, NULL);
		}
		tp = new TemplateTypeParameter(loc, tp_ident, tp_spectype, tp_defaulttype);
	    }
	    else if (token.value == TOKidentifier && t->value == TOKdotdotdot)
	    {	// ident...
		if (isvariadic)
		    error("variadic template parameter must be last");
		isvariadic = 1;
		tp_ident = token.ident;
		nextToken();
		nextToken();
		tp = new TemplateTupleParameter(loc, tp_ident);
	    }
	    else
	    {	// ValueParameter
		tp_valtype = parseBasicType();
		tp_valtype = parseDeclarator(tp_valtype, &tp_ident);
		if (!tp_ident)
		{
		    error("no identifier for template value parameter");
		    goto Lerr;
		}
		if (token.value == TOKcolon)	// : CondExpression
		{
		    nextToken();
		    tp_specvalue = parseCondExp();
		}
		if (token.value == TOKassign)	// = CondExpression
		{
		    nextToken();
		    tp_defaultvalue = parseCondExp();
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
    return tpl;

Lerr:
    return NULL;
}

/******************************************
 * Parse template mixin.
 *	mixin Foo;
 *	mixin Foo!(args);
 *	mixin a.b.c!(args).Foo!(args);
 *	mixin Foo!(args) identifier;
 *	mixin typeof(expr).identifier!(args);
 */

Dsymbol *Parser::parseMixin()
{
    TemplateMixin *tm;
    Identifier *id;
    Type *tqual;
    Objects *tiargs;
    Array *idents;

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
	    check(TOKdot);
	}
	if (token.value != TOKidentifier)
	{
	    error("identifier expected, not %s", token.toChars());
	    goto Lerr;
	}
	id = token.ident;
	nextToken();
    }

    idents = new Array();
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
    if (token.value != TOKsemicolon)
	error("';' expected after mixin");
    nextToken();

    return tm;

Lerr:
    return NULL;
}

/******************************************
 * Parse template argument list.
 * Input:
 * 	current token is opening '('
 * Output:
 *	current token is one after closing ')'
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
	    {	// Type
		Type *ta;

		// Get TemplateArgument
		ta = parseBasicType();
		ta = parseDeclarator(ta, NULL);
		tiargs->push(ta);
	    }
	    else
	    {	// Expression
		Expression *ea;

		ea = parseAssignExp();
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

Import *Parser::parseImport(Array *decldefs, int isstatic)
{   Import *s;
    Identifier *id;
    Identifier *aliasid = NULL;
    Array *a;
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
		a = new Array();
	    a->push(id);
	    nextToken();
	    if (token.value != TOKidentifier)
	    {   error("Identifier expected following package");
		break;
	    }
	    id = token.ident;
	    nextToken();
	}

	s = new Import(loc, a, token.ident, aliasid, isstatic);
	decldefs->push(s);

	/* Look for
	 *	: alias=name, alias=name;
	 * syntax.
	 */
	if (token.value == TOKcolon)
	{
	    do
	    {	Identifier *name;
		Identifier *alias;

		nextToken();
		if (token.value != TOKidentifier)
		{   error("Identifier expected following :");
		    break;
		}
		alias = token.ident;
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
	    break;	// no comma-separated imports of this form
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

Type *Parser::parseBasicType()
{   Type *t;
    Identifier *id;
    TypeQualified *tid;
    TemplateInstance *tempinst;

    //printf("parseBasicType()\n");
    switch (token.value)
    {
	CASE_BASIC_TYPES_X(t):
	    nextToken();
	    break;

	case TOKidentifier:
	    id = token.ident;
	    nextToken();
	    if (token.value == TOKnot)
	    {
		nextToken();
		tempinst = new TemplateInstance(loc, id);
		tempinst->tiargs = parseTemplateArgumentList();
		tid = new TypeInstance(loc, tempinst);
		goto Lident2;
	    }
	Lident:
	    tid = new TypeIdentifier(loc, id);
	Lident2:
	    while (token.value == TOKdot)
	    {	nextToken();
		if (token.value != TOKidentifier)
		{   error("identifier expected following '.' instead of '%s'", token.toChars());
		    break;
		}
		id = token.ident;
		nextToken();
		if (token.value == TOKnot)
		{
		    nextToken();
		    tempinst = new TemplateInstance(loc, id);
		    tempinst->tiargs = parseTemplateArgumentList();
		    tid->addIdent((Identifier *)tempinst);
		}
		else
		    tid->addIdent(id);
	    }
	    t = tid;
	    break;

	case TOKdot:
	    id = Id::empty;
	    goto Lident;

	case TOKtypeof:
	{   Expression *exp;

	    nextToken();
	    check(TOKlparen);
	    exp = parseExpression();
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
		    t = new TypeDArray(t);			// []
		    nextToken();
		}
		else if (isDeclaration(&token, 0, TOKrbracket, NULL))
		{   // It's an associative array declaration
		    Type *index;

		    //printf("it's an associative array\n");
		    index = parseBasicType();
		    index = parseDeclarator(index, NULL);	// [ type ]
		    t = new TypeAArray(t, index);
		    check(TOKrbracket);
		}
		else
		{
		    //printf("it's [expression]\n");
		    inBrackets++;
		    Expression *e = parseExpression();		// [ expression ]
		    if (token.value == TOKslice)
		    {	Expression *e2;

			nextToken();
			e2 = parseExpression();			// [ exp .. exp ]
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
			ta = new TypeDArray(t);			// []
			nextToken();
		    }
		    else if (isDeclaration(&token, 0, TOKrbracket, NULL))
		    {   // It's an associative array declaration
			Type *index;

			//printf("it's an associative array\n");
			index = parseBasicType();
			index = parseDeclarator(index, NULL);	// [ type ]
			check(TOKrbracket);
			ta = new TypeAArray(t, index);
		    }
		    else
		    {
			//printf("it's [expression]\n");
			Expression *e = parseExpression();	// [ expression ]
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
	    {	// Handle delegate declaration:
		//	t delegate(parameter list)
		//	t function(parameter list)
		Arguments *arguments;
		int varargs;
		enum TOK save = token.value;

		nextToken();
		arguments = parseParameters(&varargs);
		t = new TypeFunction(arguments, t, varargs, linkage);
		if (save == TOKdelegate)
		    t = new TypeDelegate(t);
		else
		    t = new TypePointer(t);	// pointer to function
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
	    nextToken();
	    ts = parseDeclarator(t, pident);
	    check(TOKrparen);
	    break;

	default:
	    ts = t;
	    break;
    }

    while (1)
    {
	switch (token.value)
	{
#if CARRAYDECL
	    case TOKlbracket:
	    {	// This is the old C-style post [] syntax.
		nextToken();
		if (token.value == TOKrbracket)
		{
		    ta = new TypeDArray(t);			// []
		    nextToken();
		}
		else if (isDeclaration(&token, 0, TOKrbracket, NULL))
		{   // It's an associative array declaration
		    Type *index;

		    //printf("it's an associative array\n");
		    index = parseBasicType();
		    index = parseDeclarator(index, NULL);	// [ type ]
		    check(TOKrbracket);
		    ta = new TypeAArray(t, index);
		}
		else
		{
		    //printf("it's [expression]\n");
		    Expression *e = parseExpression();		// [ expression ]
		    ta = new TypeSArray(t, e);
		    check(TOKrbracket);
		}
		Type **pt;
		for (pt = &ts; *pt != t; pt = &(*pt)->next)
		    ;
		*pt = ta;
		continue;
	    }
#endif
	    case TOKlparen:
	    {	Arguments *arguments;
		int varargs;
		Type **pt;

		if (tpl)
		{
		    /* Look ahead to see if this is (...)(...),
		     * i.e. a function template declaration
		     */
		    if (peekPastParen(&token)->value == TOKlparen)
		    {   // It's a function template declaration
			//printf("function template declaration\n");

			// Gather template parameter list
			*tpl = parseTemplateParameterList();
		    }
		}

		arguments = parseParameters(&varargs);
		ta = new TypeFunction(arguments, t, varargs, linkage);
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
 * Return array of Declaration *'s.
 */

Array *Parser::parseDeclarations()
{
    enum STC storage_class;
    enum STC stc;
    Type *ts;
    Type *t;
    Type *tfirst;
    Identifier *ident;
    Array *a;
    enum TOK tok;
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
	    case TOKconst:	stc = STCconst;		 goto L1;
	    case TOKstatic:	stc = STCstatic;	 goto L1;
	    case TOKfinal:	stc = STCfinal;		 goto L1;
	    case TOKauto:	stc = STCauto;		 goto L1;
	    case TOKscope:	stc = STCscope;		 goto L1;
	    case TOKoverride:	stc = STCoverride;	 goto L1;
	    case TOKabstract:	stc = STCabstract;	 goto L1;
	    case TOKsynchronized: stc = STCsynchronized; goto L1;
	    case TOKdeprecated: stc = STCdeprecated;	 goto L1;
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

    a = new Array();

    /* Look for auto initializers:
     *	storage_class identifier = initializer;
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
    {	AggregateDeclaration *s;

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
	    Initializer *init;

	    init = NULL;
	    if (token.value == TOKassign)
	    {
		nextToken();
		init = parseInitializer();
	    }
	    if (tok == TOKtypedef)
		v = new TypedefDeclaration(loc, ident, t, init);
	    else
	    {	if (init)
		    error("alias cannot have initializer");
		v = new AliasDeclaration(loc, ident, t);
	    }
	    v->storage_class = storage_class;
	    if (link == linkage)
		a->push(v);
	    else
	    {
		Array *ax = new Array();
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
	{   FuncDeclaration *f;
	    Dsymbol *s;

	    f = new FuncDeclaration(loc, 0, ident, storage_class, t);
	    addComment(f, comment);
	    parseContracts(f);
	    addComment(f, NULL);
	    if (link == linkage)
	    {
		s = f;
	    }
	    else
	    {
		Array *ax = new Array();
		ax->push(f);
		s = new LinkDeclaration(link, ax);
	    }
	    if (tpl)			// it's a function template
	    {   Array *decldefs;
		TemplateDeclaration *tempdecl;

		// Wrap a template around the aggregate declaration
		decldefs = new Array();
		decldefs->push(s);
		tempdecl = new TemplateDeclaration(loc, s->ident, tpl, decldefs);
		s = tempdecl;
	    }
	    addComment(s, comment);
	    a->push(s);
	}
	else
	{   VarDeclaration *v;
	    Initializer *init;

	    init = NULL;
	    if (token.value == TOKassign)
	    {
		nextToken();
		init = parseInitializer();
	    }
	    v = new VarDeclaration(loc, t, ident, init);
	    v->storage_class = storage_class;
	    if (link == linkage)
		a->push(v);
	    else
	    {
		Array *ax = new Array();
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
 * Parse contracts following function declaration.
 */

void Parser::parseContracts(FuncDeclaration *f)
{
    Type *tb;
    enum LINK linksave = linkage;

    // The following is irrelevant, as it is overridden by sc->linkage in
    // TypeFunction::semantic
    linkage = LINKd;		// nested functions have D linkage
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

#if 0	// Do we want this for function declarations, so we can do:
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
		tb = parseBasicType();
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
	    error("semicolon expected following function declaration");
	    break;
    }
    linkage = linksave;
}

/*****************************************
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

		    default:
			continue;
		}
		break;
	    }

	    is = new StructInitializer(loc);
	    nextToken();
	    comma = 0;
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
			    nextToken();	// skip over ':'
			}
			else
			{   id = NULL;
			}
			value = parseInitializer();
			is->addInit(id, value);
			comma = 1;
			continue;

		    case TOKcomma:
			nextToken();
			comma = 2;
			continue;

		    case TOKrcurly:		// allow trailing comma's
			nextToken();
			break;

		    default:
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
	    ia = new ArrayInitializer(loc);
	    nextToken();
	    comma = 0;
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
			nextToken();
			comma = 2;
			continue;

		    case TOKrbracket:		// allow trailing comma's
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
 * Input:
 *	flags	PSxxxx
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
	    // Need to look ahead to see if it is a declaration, label, or expression
	    t = peek(&token);
	    if (t->value == TOKcolon)
	    {	// It's a label
		Identifier *ident;

		ident = token.ident;
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
	Lexp:
	{   Expression *exp;

	    exp = parseExpression();
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

	CASE_BASIC_TYPES:
	case TOKtypedef:
	case TOKalias:
	case TOKconst:
	case TOKauto:
	case TOKextern:
	case TOKfinal:
	case TOKinvariant:
//	case TOKtypeof:
	Ldeclaration:
	{   Array *a;

	    a = parseDeclarations();
	    if (a->dim > 1)
	    {
		Statements *as = new Statements();
		as->reserve(a->dim);
		for (int i = 0; i < a->dim; i++)
		{
		    Dsymbol *d = (Dsymbol *)a->data[i];
		    s = new DeclarationStatement(loc, d);
		    as->push(s);
		}
		s = new CompoundStatement(loc, as);
	    }
	    else if (a->dim == 1)
	    {
		Dsymbol *d = (Dsymbol *)a->data[0];
		s = new DeclarationStatement(loc, d);
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
	    s = new DeclarationStatement(loc, d);
	    break;
	}

	case TOKenum:
	{   Dsymbol *d;

	    d = parseEnum();
	    s = new DeclarationStatement(loc, d);
	    break;
	}

	case TOKmixin:
	{   t = peek(&token);
	    if (t->value == TOKlparen)
	    {	// mixin(string)
		nextToken();
		check(TOKlparen, "mixin");
		Expression *e = parseAssignExp();
		check(TOKrparen);
		check(TOKsemicolon);
		s = new CompileStatement(loc, e);
		break;
	    }
	    Dsymbol *d = parseMixin();
	    s = new DeclarationStatement(loc, d);
	    break;
	}

	case TOKlcurly:
	{   Statements *statements;

	    nextToken();
	    statements = new Statements();
	    while (token.value != TOKrcurly)
	    {
		statements->push(parseStatement(PSsemi | PScurlyscope));
	    }
	    endloc = this->loc;
	    s = new CompoundStatement(loc, statements);
	    if (flags & (PSscope | PScurlyscope))
		s = new ScopeStatement(loc, s);
	    nextToken();
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
	    s = new ExpStatement(loc, NULL);
	    break;

	case TOKdo:
	{   Statement *body;
	    Expression *condition;

	    nextToken();
	    body = parseStatement(PSscope);
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
	    {	init = NULL;
		nextToken();
	    }
	    else
	    {	init = parseStatement(0);
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
	    {	increment = NULL;
		nextToken();
	    }
	    else
	    {	increment = parseExpression();
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
	    Arguments *arguments;

	    Statement *d;
	    Statement *body;
	    Expression *aggr;

	    nextToken();
	    check(TOKlparen);

	    arguments = new Arguments();

	    while (1)
	    {
		Type *tb;
		Identifier *ai = NULL;
		Type *at;
		unsigned storageClass;
		Argument *a;

		storageClass = STCin;
		if (token.value == TOKinout || token.value == TOKref)
		{   storageClass = STCref;
		    nextToken();
		}
		if (token.value == TOKidentifier)
		{
		    Token *t = peek(&token);
		    if (t->value == TOKcomma || t->value == TOKsemicolon)
		    {	ai = token.ident;
			at = NULL;		// infer argument type
			nextToken();
			goto Larg;
		    }
		}
		tb = parseBasicType();
		at = parseDeclarator(tb, &ai);
		if (!ai)
		    error("no identifier for declarator %s", at->toChars());
	      Larg:
		a = new Argument(storageClass, at, ai, NULL);
		arguments->push(a);
		if (token.value == TOKcomma)
		{   nextToken();
		    continue;
		}
		break;
	    }
	    check(TOKsemicolon);

	    aggr = parseExpression();
	    check(TOKrparen);
	    body = parseStatement(0);
	    s = new ForeachStatement(loc, op, arguments, aggr, body);
	    break;
	}

	case TOKif:
	{   Argument *arg = NULL;
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
			arg = new Argument(STCin, NULL, token.ident, NULL);
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
		arg = new Argument(STCin, at, ai, NULL);
	    }

	    // Check for " ident;"
	    else if (token.value == TOKidentifier)
	    {
		Token *t = peek(&token);
		if (t->value == TOKcomma || t->value == TOKsemicolon)
		{
		    arg = new Argument(STCin, NULL, token.ident, NULL);
		    nextToken();
		    nextToken();
		    if (1 || !global.params.useDeprecated)
			error("if (v; e) is deprecated, use if (auto v = e)");
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
	    s = new IfStatement(loc, arg, condition, ifbody, elsebody);
	    break;
	}

	case TOKscope:
	    if (peek(&token)->value != TOKlparen)
		goto Ldeclaration;		// scope used as storage class
	    nextToken();
	    check(TOKlparen);
	    if (token.value != TOKidentifier)
	    {	error("scope identifier expected");
		goto Lerror;
	    }
	    else
	    {	TOK t = TOKon_scope_exit;
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
	    if (token.value == TOKcomma)
		args = parseArguments();	// pragma(identifier, args...);
	    else
		check(TOKrparen);		// pragma(identifier);
	    if (token.value == TOKsemicolon)
	    {	nextToken();
		body = NULL;
	    }
	    else
		body = parseStatement(PSsemi);
	    s = new PragmaStatement(loc, ident, args, body);
	    break;
	}

	case TOKswitch:
	{   Expression *condition;
	    Statement *body;

	    nextToken();
	    check(TOKlparen);
	    condition = parseExpression();
	    check(TOKrparen);
	    body = parseStatement(PSscope);
	    s = new SwitchStatement(loc, condition, body);
	    break;
	}

	case TOKcase:
	{   Expression *exp;
	    Statements *statements;
	    Array cases;	// array of Expression's

	    while (1)
	    {
		nextToken();
		exp = parseAssignExp();
		cases.push(exp);
		if (token.value != TOKcomma)
		    break;
	    }
	    check(TOKcolon);

	    statements = new Statements();
	    while (token.value != TOKcase &&
		   token.value != TOKdefault &&
		   token.value != TOKrcurly)
	    {
		statements->push(parseStatement(PSsemi | PScurlyscope));
	    }
	    s = new CompoundStatement(loc, statements);
	    s = new ScopeStatement(loc, s);

	    // Keep cases in order by building the case statements backwards
	    for (int i = cases.dim; i; i--)
	    {
		exp = (Expression *)cases.data[i - 1];
		s = new CaseStatement(loc, exp, s);
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
	    {	ident = token.ident;
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
	    {	ident = token.ident;
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
	    Array *catches = NULL;
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
		if (token.value == TOKlcurly)
		{
		    t = NULL;
		    id = NULL;
		}
		else
		{
		    check(TOKlparen);
		    t = parseBasicType();
		    id = NULL;
		    t = parseDeclarator(t, &id);
		    check(TOKrparen);
		}
		handler = parseStatement(0);
		c = new Catch(loc, t, id, handler);
		if (!catches)
		    catches = new Array();
		catches->push(c);
	    }

	    if (token.value == TOKfinally)
	    {	nextToken();
		finalbody = parseStatement(0);
	    }

	    s = body;
	    if (!catches && !finalbody)
		error("catch or finally expected following try");
	    else
	    {	if (catches)
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

void Parser::check(enum TOK value, char *string)
{
    if (token.value != value)
	error("found '%s' when expecting '%s' following '%s'",
	    token.toChars(), Token::toChars(value), string);
    nextToken();
}

/************************************
 * Determine if the scanner is sitting on the start of a declaration.
 * Input:
 *	needId	0	no identifier
 *		1	identifier optional
 *		2	must have identifier
 */

int Parser::isDeclaration(Token *t, int needId, enum TOK endtok, Token **pt)
{
    int haveId = 0;

    if (!isBasicType(&t))
	return FALSE;
    if (!isDeclarator(&t, &haveId, endtok))
	return FALSE;
    if ( needId == 1 ||
	(needId == 0 && !haveId) ||
	(needId == 2 &&  haveId))
    {	if (pt)
	    *pt = t;
	return TRUE;
    }
    else
	return FALSE;
}

int Parser::isBasicType(Token **pt)
{
    // This code parallels parseBasicType()
    Token *t = *pt;
    Token *t2;
    int parens;

    switch (t->value)
    {
	CASE_BASIC_TYPES:
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
    return TRUE;

Lfalse:
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
	    case TOKand:
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
		    {	t = peek(t);
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
		    return FALSE;		// () is not a declarator

		/* Regard ( identifier ) as not a declarator
		 * BUG: what about ( *identifier ) in
		 *	f(*p)(x);
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
 *	instance foo.bar(parameters...)
 * Output:
 *	if (pt), *pt is set to the token following the closing )
 * Returns:
 *	1	it's valid instance syntax
 *	0	invalid instance syntax
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
 *	t is on opening (
 * Output:
 *	*pt is set to closing token, which is ')' on success
 * Returns:
 *	!=0	successful
 *	0	some parsing error
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
	    case TOKsemicolon:
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

/********************************* Expression Parser ***************************/

Expression *Parser::parsePrimaryExp()
{   Expression *e;
    Type *t;
    Identifier *id;
    enum TOK save;
    Loc loc = this->loc;

    switch (token.value)
    {
	case TOKidentifier:
	    id = token.ident;
	    nextToken();
	    if (token.value == TOKnot && peek(&token)->value == TOKlparen)
	    {	// identifier!(template-argument-list)
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
		    {	if (token.postfix != postfix)
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

	CASE_BASIC_TYPES_X(t):
	    nextToken();
	L1:
	    check(TOKdot, t->toChars());
	    if (token.value != TOKidentifier)
	    {   error("found '%s' when expecting identifier following '%s.'", token.toChars(), t->toChars());
		goto Lerr;
	    }
	    e = new TypeDotIdExp(loc, t, token.ident);
	    nextToken();
	    break;

	case TOKtypeof:
	{   Expression *exp;

	    nextToken();
	    check(TOKlparen);
	    exp = parseExpression();
	    check(TOKrparen);
	    t = new TypeTypeof(loc, exp);
	    if (token.value == TOKdot)
		goto L1;
	    e = new TypeExp(loc, t);
	    break;
	}

	case TOKtypeid:
	{   Type *t;

	    nextToken();
	    check(TOKlparen, "typeid");
	    t = parseBasicType();
	    t = parseDeclarator(t,NULL);	// ( type )
	    check(TOKrparen);
	    e = new TypeidExp(loc, t);
	    break;
	}

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
	    e = new IftypeExp(loc, targ, ident, tok, tspec, tok2);
	    break;
	}

	case TOKassert:
	{   Expression *msg = NULL;

	    nextToken();
	    check(TOKlparen, "assert");
	    e = parseAssignExp();
	    if (token.value == TOKcomma)
	    {	nextToken();
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
	    {	// (arguments) { statements... }
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
	     *	[ value, value, value ... ]
	     *	[ key:value, key:value, key:value ... ]
	     */
	    Expressions *values = new Expressions();
	    Expressions *keys = NULL;

	    nextToken();
	    if (token.value != TOKrbracket)
	    {
		while (1)
		{
		    Expression *e = parseAssignExp();
		    if (token.value == TOKcolon && (keys || values->dim == 0))
		    {	nextToken();
			if (!keys)
			    keys = new Expressions();
			keys->push(e);
			e = parseAssignExp();
		    }
		    else if (keys)
		    {	error("'key:value' expected for associative array literal");
			delete keys;
			keys = NULL;
		    }
		    values->push(e);
		    if (token.value == TOKrbracket)
			break;
		    check(TOKcomma);
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
	    Arguments *arguments;
	    int varargs;
	    FuncLiteralDeclaration *fd;
	    Type *t;

	    if (token.value == TOKlcurly)
	    {
		t = NULL;
		varargs = 0;
		arguments = new Arguments();
	    }
	    else
	    {
		if (token.value == TOKlparen)
		    t = NULL;
		else
		{
		    t = parseBasicType();
		    t = parseBasicType2(t);	// function return type
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
	    {	// array dereferences:
		//	array[index]
		//	array[]
		//	array[lwr .. upr]
		Expression *index;
		Expression *upr;

		inBrackets++;
		nextToken();
		if (token.value == TOKrbracket)
		{   // array[]
		    e = new SliceExp(loc, e, NULL, NULL);
		    nextToken();
		}
		else
		{
		    index = parseAssignExp();
		    if (token.value == TOKslice)
		    {	// array[lwr .. upr]
			nextToken();
			upr = parseAssignExp();
			e = new SliceExp(loc, e, index, upr);
		    }
		    else
		    {	// array[index, i2, i3, i4, ...]
			Expressions *arguments = new Expressions();
			arguments->push(index);
			if (token.value == TOKcomma)
			{
			    nextToken();
			    while (1)
			    {   Expression *arg;

				arg = parseAssignExp();
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

	case TOKcast:				// cast(type) expression
	{   Type *t;

	    nextToken();
	    check(TOKlparen);
	    t = parseBasicType();
	    t = parseDeclarator(t,NULL);	// ( type )
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
		tk = peek(tk);		// skip over right parenthesis
		switch (tk->value)
		{
		    case TOKdot:
		    case TOKplusplus:
		    case TOKminusminus:
		    case TOKnot:
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
		    CASE_BASIC_TYPES:		// (type)int.size
		    {	// (type) una_exp
			Type *t;

			nextToken();
			t = parseBasicType();
			t = parseDeclarator(t,NULL);
			check(TOKrparen);

			// if .identifier
			if (token.value == TOKdot)
			{
			    nextToken();
			    if (token.value != TOKidentifier)
			    {   error("Identifier expected following (type).");
				return NULL;
			    }
			    e = new TypeDotIdExp(loc, t, token.ident);
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
	    case TOKdiv:   nextToken(); e2 = parseUnaryExp(); e = new DivExp(loc,e,e2); continue;
	    case TOKmod:  nextToken(); e2 = parseUnaryExp(); e = new ModExp(loc,e,e2); continue;

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
    {	enum TOK value = token.value;

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

    //printf("Parser::parseExpression()\n");
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
	    while (1)
	    {
		arg = parseAssignExp();
		arguments->push(arg);
		if (token.value == endtok)
		    break;
		check(TOKcomma);
	    }
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
	    Array *decl = parseDeclDefs(0);
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
}


/********************************* ***************************/

