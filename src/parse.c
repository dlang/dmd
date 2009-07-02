
// Copyright (c) 1999-2003 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include "mem.h"
#include "lexer.h"
#include "parse.h"
#include "init.h"
#include "attrib.h"
#include "debcond.h"
#include "template.h"
#include "staticassert.h"

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

// Support D cast syntax:
//	cast(type)(expression)
#define DCASTSYNTAX	1

// Support C array declarations, such as
//	int a[3][4];
#define CARRAYDECL	1

// Support left-to-right array declarations
#define LTORARRAYDECL	1

// Suppor references
#define REFERENCES	0

/************************************
 * These control how parseStatement() works.
 */

enum ParseStatementFlags
{
    PSsemi = 1,		// empty ';' statements are allowed
    PSscope = 2,	// start a new scope
    PScurly = 4,	// { } statement is required
    PScurlyscope = 8,	// { } starts a new scope
};


Parser::Parser(Module *module, unsigned char *base, unsigned length)
    : Lexer(module, base, length)
{
    //printf("Parser::Parser()\n");
    md = NULL;
    linkage = LINKd;
    endloc = 0;
    nextToken();		// start up the scanner
}

Array *Parser::parseModule()
{
    Array *decldefs;

    // ModuleDeclation leads off
    if (token.value == TOKmodule)
    {
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
    enum PROT prot;
    unsigned stc;

    //printf("Parser::parseDeclDefs()\n");
    decldefs = new Array();
    do
    {
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
		s = parseImport(decldefs);
		break;

	    case TOKtemplate:
		s = (Dsymbol *)parseTemplateDeclaration();
		break;

	    case TOKinstance:
		if (isDeclaration(&token, 2, TOKreserved, NULL))
		{
		    //printf("it's a declaration\n");
		    goto Ldeclaration;
		}
		else
		{
		    // instance foo(bar) ident;

		    TemplateInstance *ti;

		    //printf("it's an alias\n");
		    ti = parseTemplateInstance();
		    s = (Dsymbol *)ti;
		    if (ti)
		    {   if (token.value == TOKidentifier)
			{
			    s = (Dsymbol *)new AliasDeclaration(loc, token.ident, ti);
			    nextToken();
			}
		    }
		    if (token.value != TOKsemicolon)
			error("';' expected after template instance");
		}
		break;

	    CASE_BASIC_TYPES:
	    case TOKalias:
	    case TOKtypedef:
	    case TOKidentifier:
	    Ldeclaration:
		a = parseDeclaration();
		decldefs->append(a);
		continue;

	    case TOKthis:
		s = parseCtor();
		break;

	    case TOKtilde:
		s = parseDtor();
		break;

	    case TOKinvariant:
		s = parseInvariant();
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
		else
		{   stc = STCstatic;
		    goto Lstc2;
		}
		break;

	    case TOKconst:	  stc = STCconst;	 goto Lstc;
	    case TOKfinal:	  stc = STCfinal;	 goto Lstc;
	    case TOKauto:	  stc = STCauto;	 goto Lstc;
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
		    case TOKoverride:	  stc |= STCoverride;	 goto Lstc;
		    case TOKabstract:	  stc |= STCabstract;	 goto Lstc;
		    case TOKsynchronized: stc |= STCsynchronized; goto Lstc;
		    case TOKdeprecated:   stc |= STCdeprecated;	 goto Lstc;
		}
		a = parseBlock();
		s = new StorageClassDeclaration(stc, a);
		break;


	    case TOKprivate:	prot = PROTprivate;	goto Lprot;
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

	    case TOKextern:
	    {	enum LINK link = LINKdefault;
		enum LINK linksave;

		s = NULL;
		nextToken();
		if (token.value == TOKlparen)
		{
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
			    break;
			}
		    }
		    else
		    {
			link = LINKd;		// default
		    }
		    check(TOKrparen);
		}
		else
		{   stc = STCextern;
		    goto Lstc2;
		}
		linksave = linkage;
		linkage = link;
		a = parseBlock();
		linkage = linksave;
		s = new LinkDeclaration(link, a);
		break;
	    }

	    case TOKdebug:
	    {	DebugCondition *condition;
		Array *aelse;

		nextToken();
		if (token.value == TOKassign)
		{
		    nextToken();
		    if (token.value == TOKidentifier)
			s = new DebugSymbol(token.ident);
		    else if (token.value == TOKint32v)
			s = new DebugSymbol((unsigned)token.uns64value);
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
		else if (token.value == TOKlparen)
		{
		    nextToken();
		    condition = parseDebugCondition();
		    check(TOKrparen);
		}
		else
		    condition = new DebugCondition(1, NULL);
		a = parseBlock();
		aelse = NULL;
		if (token.value == TOKelse)
		{   nextToken();
		    aelse = parseBlock();
		}
		s = new DebugDeclaration(condition, a, aelse);
		break;
	    }

	    case TOKversion:
	    {	VersionCondition *condition;
		Array *aelse;

		nextToken();
		if (token.value == TOKassign)
		{
		    nextToken();
		    if (token.value == TOKidentifier)
			s = new VersionSymbol(token.ident);
		    else if (token.value == TOKint32v)
			s = new VersionSymbol((unsigned)token.uns64value);
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
		else if (token.value == TOKlparen)
		{
		    nextToken();
		    condition = parseVersionCondition();
		    check(TOKrparen);
		}
		else
		{   error("(condition) expected following version");
		    condition = NULL;
		}
		a = parseBlock();
		aelse = NULL;
		if (token.value == TOKelse)
		{   nextToken();
		    aelse = parseBlock();
		}
		s = new VersionDeclaration(condition, a, aelse);
		break;
	    }

	    case TOKsemicolon:		// empty declaration
		nextToken();
		continue;

	    default:
		error("Declaration expected, not '%s'\n",token.toChars());
		while (token.value != TOKsemicolon && token.value != TOKeof)
		    nextToken();
		nextToken();
		s = NULL;
		continue;
	}
	if (s)
	    decldefs->push(s);
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
#if 1
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

    //printf("parseStaticAssert()\n");
    nextToken();
    check(TOKlparen);
    exp = parseExpression();
    check(TOKrparen);
    check(TOKsemicolon);
    return new StaticAssert(loc, exp);
}

/**************************************
 * Parse a debug conditional
 */

DebugCondition *Parser::parseDebugCondition()
{
    unsigned level = 1;
    Identifier *id = NULL;

    if (token.value == TOKidentifier)
	id = token.ident;
    else if (token.value == TOKint32v)
	level = (unsigned)token.uns64value;
    else
	error("identifier or integer expected, not %s", token.toChars());
    nextToken();

    return new DebugCondition(level, id);
}

/**************************************
 * Parse a version conditional
 */

VersionCondition *Parser::parseVersionCondition()
{
    unsigned level = 1;
    Identifier *id = NULL;

    if (token.value == TOKidentifier)
	id = token.ident;
    else if (token.value == TOKint32v)
	level = (unsigned)token.uns64value;
    else
	error("identifier or integer expected, not %s", token.toChars());
    nextToken();

    return new VersionCondition(level, id);
}

/*****************************************
 * Parse a constructor definition:
 *	this(arguments) { body }
 * Current token is 'this'.
 */

CtorDeclaration *Parser::parseCtor()
{
    CtorDeclaration *f;
    Array *arguments;
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
    //check(TOKlparen);		// don't require ()
    //check(TOKrparen);

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
    Array *arguments;
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
    Array *arguments;
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

Array *Parser::parseParameters(int *pvarargs)
{
    Array *arguments;
    int varargs;

    arguments = new Array();
    varargs = 0;

    check(TOKlparen);
    while (1)
    {   Type *tb;
	Identifier *ai;
	Type *at;
	Argument *a;
	enum InOut inout;

	ai = NULL;
	inout = In;			// parameter is "in" by default
	switch (token.value)
	{
	    case TOKrparen:
		break;

	    case TOKdotdotdot:
		varargs = 1;
		nextToken();
		break;

	    case TOKin:
		inout = In;
		nextToken();
		goto L1;

	    case TOKout:
		inout = Out;
		nextToken();
		goto L1;

	    case TOKinout:
		inout = InOut;
		nextToken();
		goto L1;

	    default:
	    L1:
		tb = parseBasicType();
		at = parseDeclarator(tb, &ai);
		a = new Argument(at, ai, inout);
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

    e = new EnumDeclaration(id, t);
    if (token.value == TOKsemicolon)
 	nextToken();
    else if (token.value == TOKlcurly)
    {
	//printf("enum definition\n");
	e->members = new Array();
	nextToken();
	while (token.value != TOKrcurly)
	{
	    if (token.value == TOKidentifier)
	    {	EnumMember *em;
		Expression *value;
		Identifier *ident;

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
		    check(TOKcomma);
	    }
	    else
	    {	error("enum member expected");
		nextToken();
	    }
	}
	nextToken();
    }
    else
	error("{ enum members } expected");

    return e;
}

AggregateDeclaration *Parser::parseAggregate()
{   AggregateDeclaration *a;
    enum TOK tok;
    Identifier *id;

    //printf("Parser::parseAggregate()\n");
    tok = token.value;
    nextToken();
    if (token.value != TOKidentifier)
    {	id = NULL;
    }
    else
    {	id = token.ident;
	nextToken();
    }

    switch (tok)
    {	case TOKclass:
	case TOKinterface:
	{
	    Array *baseclasses = NULL;
	    BaseClass *b;

	    if (!id)
		error("anonymous classes not allowed");

	    // Collect base class(es)
	    b = NULL;
	    if (token.value == TOKcolon)
	    {   enum PROT protection = PROTpublic;

		baseclasses = new Array();
		while (1)
		{
		    nextToken();
		    switch (token.value)
		    {
			case TOKidentifier:
			case TOKinstance:
			    break;
			case TOKprivate:
			    protection = PROTprivate;
			    continue;
			case TOKprotected:
			    protection = PROTprotected;
			    continue;
			case TOKpublic:
			    protection = PROTpublic;
			    continue;
			default:
			    error("base classes expected following ':'");
			    return NULL;
		    }
		    b = new BaseClass(parseBasicType(), protection);
		    baseclasses->push(b);
		    if (token.value != TOKcomma)
			break;
		    protection = PROTpublic;
		}
		if (token.value != TOKlcurly)
		    error("members expected");
	    }

	    if (tok == TOKclass)
		a = new ClassDeclaration(id, baseclasses);
	    else
		a = new InterfaceDeclaration(id, baseclasses);
	    break;
	}

	case TOKstruct:
	    a = new StructDeclaration(id);
	    break;

	case TOKunion:
	    a = new UnionDeclaration(id);
	    break;

	default:
	    assert(0);
	    break;
    }
    if (token.value == TOKsemicolon)
 	nextToken();
    else if (token.value == TOKlcurly)
    {
	//printf("aggregate definition\n");
	nextToken();
	a->members = parseDeclDefs(0);
	if (token.value != TOKrcurly)
	    error("struct member expected");
	nextToken();
    }

    return a;
}

/**************************************
 * Parse a TemplateDeclaration.
 */

TemplateDeclaration *Parser::parseTemplateDeclaration()
{
    TemplateDeclaration *tempdecl;
    Identifier *id;
    Array *tpl;
    Array *decldefs;
    Loc loc = this->loc;

    nextToken();
    if (token.value != TOKidentifier)
    {   error("TemplateIdentifier expected following template");
	goto Lerr;
    }
    id = token.ident;
    nextToken();
    if (token.value != TOKlparen)
    {   error("parenthesized TemplateParameterList expected following TemplateIdentifier '%s'", id->toChars());
	goto Lerr;
    }
    tpl = new Array();
    nextToken();

    // Get TemplateParameterList
    if (token.value != TOKrparen)
    {
	while (1)
	{   TemplateParameter *tp;
	    Identifier *tp_ident = NULL;
	    Type *tp_spectype = NULL;
	    Type *tp_valtype = NULL;
	    Expression *tp_specvalue = NULL;
	    Token *t;

	    // Get TemplateParameter

	    // First, look ahead to see if it is a TypeParameter or a ValueParameter
	    t = peek(&token);
	    if (t->value == TOKcolon || t->value == TOKcomma || t->value == TOKrparen)
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
		if (token.value == TOKcolon)	// : AssignExpression
		{
		    nextToken();
		    tp_specvalue = parseAssignExp();
		}
	    }
	    tp = new TemplateParameter(tp_ident, tp_spectype, tp_valtype, tp_specvalue);
	    tpl->push(tp);
	    if (token.value != TOKcomma)
		break;
	    nextToken();
	}
    }
    check(TOKrparen);

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


/**************************************
 * Parse a TemplateInstance.
 */

TemplateInstance *Parser::parseTemplateInstance()
{
    TemplateInstance *tempinst;
    Identifier *id;

    //printf("parseTemplateInstance()\n");
    nextToken();
    if (token.value == TOKdot)
    {
	id = Id::empty;
    }
    else if (token.value == TOKidentifier)
    {	id = token.ident;
	nextToken();
    }
    else
    {   error("TemplateIdentifier expected following instance");
	goto Lerr;
    }
    tempinst = new TemplateInstance(id);
    while (token.value == TOKdot)
    {   nextToken();
	if (token.value == TOKidentifier)
	    tempinst->addIdent(token.ident);
	else
	{   error("identifier expected following '.' instead of '%s'", token.toChars());
	    goto Lerr;
	}
	nextToken();
    }
    if (token.value != TOKlparen)
    {   error("parenthesized TemplateArgumentList expected following TemplateIdentifier");
	goto Lerr;
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
		tempinst->tiargs.push(ta);
	    }
	    else
	    {	// Expression
		Expression *ea;

		ea = parseAssignExp();
		tempinst->tiargs.push(ea);
	    }
	    if (token.value != TOKcomma)
		break;
	    nextToken();
	}
    }
    check(TOKrparen);

    return tempinst;

Lerr:
    return NULL;
}


Import *Parser::parseImport(Array *decldefs)
{   Import *s;
    Identifier *id;
    Array *a;
    Loc loc;

    //printf("Parser::parseImport()\n");
    do
    {
	nextToken();
	if (token.value != TOKidentifier)
	{   error("Identifier expected following import");
	    break;
	}

	loc = this->loc;
	a = NULL;
	id = token.ident;
	while (nextToken() == TOKdot)
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
	}

	s = new Import(loc, a, token.ident);
	decldefs->push(s);
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

    //printf("parseBasicType()\n");
    switch (token.value)
    {
	CASE_BASIC_TYPES_X(t):
	    nextToken();
	    break;

	case TOKidentifier:
	    id = token.ident;
	    nextToken();
	Lident:
	{
	    TypeIdentifier *ti;

	    ti = new TypeIdentifier(loc, id);
	    while (token.value == TOKdot)
	    {	nextToken();
		if (token.value == TOKidentifier)
		    ti->addIdent(token.ident);
		else
		{   error("identifier expected following '.' instead of '%s'", token.toChars());
		    break;
		}
		nextToken();
	    }
	    t = ti;
	    break;
	}

	case TOKdot:
	    id = Id::empty;
	    goto Lident;

	case TOKinstance:
	{   TemplateInstance *tempinst;
	    TypeInstance *ti;

	    tempinst = parseTemplateInstance();
	    if (!tempinst)		// if error
	    {	t = Type::tvoid;
		break;
	    }

	    ti = new TypeInstance(loc, tempinst);
	    while (token.value == TOKdot)
	    {	nextToken();
		if (token.value == TOKidentifier)
		{   //printf("adding ident '%s'\n", token.ident->toChars());
		    ti->addIdent(token.ident);
		}
		else
		{   error("identifier expected following '.' instead of '%s'", token.toChars());
		    break;
		}
		nextToken();
	    }
	    t = ti;
	    break;
	}

	default:
	    error("basic type expected, not %s", token.toChars());
	    t = Type::tint32;
	    break;
    }
    return t;
}

Type *Parser::parseBasicType2(Type *t)
{   Expression *e;
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

#if REFERENCES
	    case TOKand:
		t = new TypeReference(t);
		nextToken();
		continue;
#endif
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
		    e = parseExpression();			// [ expression ]
		    t = new TypeSArray(t,e);
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
			e = parseExpression();			// [ expression ]
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
		Array *arguments;
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

Type *Parser::parseDeclarator(Type *t, Identifier **pident)
{   Expression *e;
    Type *ts;
    Type *ta;
    Type **pt;

    //printf("parseDeclarator(t = %p)\n", t);
    while (1)
    {
	switch (token.value)
	{
	    case TOKmul:
		t = new TypePointer(t);
		nextToken();
		continue;

#if REFERENCES
	    case TOKand:
		t = new TypeReference(t);
		nextToken();
		continue;
#endif

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
		    e = parseExpression();			// [ expression ]
		    t = new TypeSArray(t,e);
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
			e = parseExpression();			// [ expression ]
			ta = new TypeSArray(t,e);
			check(TOKrbracket);
		    }
		    for (pt = &ts; *pt != t; pt = &(*pt)->next)
			;
		    *pt = ta;
		}
		t = ts;
		continue;
#endif

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

	    case TOKdelegate:
	    case TOKfunction:
	    {	// Handle delegate declaration:
		//	t delegate(parameter list)
		//	t function(parameter list)
		Array *arguments;
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

    while (1)
    {
	switch (token.value)
	{
#if CARRAYDECL
	    case TOKlbracket:
		// This is the old C-style post [] syntax.
		// Should we disallow it?
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
		    e = parseExpression();			// [ expression ]
		    ta = new TypeSArray(t,e);
		    check(TOKrbracket);
		}
		for (pt = &ts; *pt != t; pt = &(*pt)->next)
		    ;
		*pt = ta;
		continue;
#endif
	    case TOKlparen:
	    {	Array *arguments;
		int varargs;

		arguments = parseParameters(&varargs);
		ta = new TypeFunction(arguments, t, varargs, linkage);
		for (pt = &ts; *pt != t; pt = &(*pt)->next)
		    ;
		*pt = ta;
		continue;
	    }
	}
	break;
    }

    return ts;
}

/**********************************
 * Return array of Declaration *'s.
 */

Array *Parser::parseDeclaration()
{
    enum STC storage_class;
    enum STC sc;
    Type *ts;
    Type *t;
    Type *tfirst;
    Identifier *ident;
    Array *a;
    enum TOK tok;

    //printf("parseDeclaration()\n");
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
	    case TOKconst:	sc = STCconst;		goto L1;
	    case TOKstatic:	sc = STCstatic;		goto L1;
	    case TOKfinal:	sc = STCfinal;		goto L1;
	    case TOKauto:	sc = STCauto;		goto L1;
	    case TOKoverride:	sc = STCoverride;	goto L1;
	    case TOKabstract:	sc = STCabstract;	goto L1;
	    case TOKsynchronized: sc = STCsynchronized;	goto L1;
	    case TOKdeprecated: sc = STCdeprecated;	goto L1;
	    L1:
		if (storage_class & sc)
		    error("redundant storage class '%s'", token.toChars());
		storage_class = (STC) (storage_class | sc);
		nextToken();
		continue;
	}
	break;
    }

    a = new Array();
    ts = parseBasicType();
    ts = parseBasicType2(ts);
    tfirst = NULL;

    while (1)
    {
	Loc loc = this->loc;

	ident = NULL;
	t = parseDeclarator(ts,&ident);
	assert(t);
	if (!tfirst)
	    tfirst = t;
	else if (t != tfirst)
	    error("multiple declarations must have the same type, not %s and %s",
		tfirst->toChars(), t->toChars());
	if (!ident)
	    error("no identifier for declarator");

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
		v = new TypedefDeclaration(ident, t, init);
	    else
	    {	if (init)
		    error("alias cannot have initializer");
		v = new AliasDeclaration(loc, ident, t);
	    }
	    v->storage_class = storage_class;
	    a->push(v);
	    switch (token.value)
	    {   case TOKsemicolon:
		    nextToken();
		    break;

		case TOKcomma:
		    nextToken();
		    continue;

		default:
		    error("semicolon expected to close %s declaration", Token::toChars(tok));
		    break;
	    }
	}
	else if (t->ty == Tfunction)
	{   FuncDeclaration *f;

	    f = new FuncDeclaration(loc, 0, ident, storage_class, t);
	    a->push(f);
	    parseContracts(f);
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
	    a->push(v);
	    switch (token.value)
	    {   case TOKsemicolon:
		    nextToken();
		    break;

		case TOKcomma:
		    nextToken();
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

    linkage = LINKd;		// nested functions have D linkage
L1:
    switch (token.value)
    {
	case TOKlcurly:
	    if (f->frequire || f->fensure)
		error("must use body keyword after in or out");
	    f->fbody = parseStatement(PSsemi);
	    f->endloc = endloc;
	    break;

	case TOKbody:
	    nextToken();
	    f->fbody = parseStatement(PScurly);
	    f->endloc = endloc;
	    break;

	case TOKsemicolon:
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

    switch (token.value)
    {
	case TOKlcurly:
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
			//error("found %s instead of field initializer", token.toChars());
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
			error("found %s instead of array initializer", token.toChars());
			break;
		}
		break;
	    }
	    return ia;

	default:
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
	    if (isDeclaration(&token, 2, TOKreserved, NULL))
	    {
		goto Ldeclaration;

	    }
	    else
	    {   Expression *exp;

		exp = parseExpression();
		check(TOKsemicolon);
		s = new ExpStatement(loc, exp);
	    }
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
#if DCASTSYNTAX
	case TOKcast:
#endif
	case TOKmul:
	case TOKmin:
	case TOKadd:
	case TOKplusplus:
	case TOKminusminus:
	case TOKnew:
	case TOKdelete:
	case TOKdelegate:
	case TOKfunction:
	Lexp:
	{   Expression *exp;

	    exp = parseExpression();
	    check(TOKsemicolon);
	    s = new ExpStatement(loc, exp);
	    break;
	}

	case TOKinstance:
	    /* Three cases:
	     *	1) Declaration
	     *	2) Template Instance Alias
	     *	3) Expression
	     */
	    if (isDeclaration(&token, 2, TOKreserved, NULL))
	    {
		//printf("it's a declaration\n");
		goto Ldeclaration;
	    }
	    else
	    {
		if (isTemplateInstance(&token, &t) && t->value == TOKidentifier)
		{   // case 2
		    TemplateInstance *ti;
		    AliasDeclaration *a;

		    ti = parseTemplateInstance();
		    assert(ti);
		    assert(token.value == TOKidentifier);

		    a = new AliasDeclaration(loc, token.ident, ti);
		    s = new DeclarationStatement(loc, a);
		    nextToken();
		    if (token.value != TOKsemicolon)
			error("';' expected after template instance, not %s", token.toChars());
		}
		else
		    goto Lexp;		// case 3
	    }
	    break;

	case TOKstatic:
	{   // Look ahead to see if it's static assert()
	    Token *t;

	    t = peek(&token);
	    if (t->value == TOKassert)
	    {
		nextToken();
		s = new StaticAssertStatement(parseStaticAssert());
		break;
	    }
	    goto Ldeclaration;
	}

	CASE_BASIC_TYPES:
	case TOKtypedef:
	case TOKalias:
	case TOKconst:
	case TOKauto:
	Ldeclaration:
	{   Array *a;

	    a = parseDeclaration();
	    if (a->dim > 1)
	    {
		Array *as = new Array();
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

	case TOKlcurly:
	{   Array *statements;

	    nextToken();
	    statements = new Array();
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
		check(TOKsemicolon);
	    }
	    if (token.value == TOKrparen)
	    {	increment = NULL;
		nextToken();
	    }
	    else
	    {	increment = parseExpression();
		check(TOKrparen);
	    }
	    body = parseStatement(0);
	    s = new ForStatement(loc, init, condition, increment, body);
	    break;
	}

	case TOKforeach:
	{
	    Type *tb;
	    Identifier *ai;
	    Type *at;
	    Argument *a;
	    enum InOut inout;

	    Statement *d;
	    Statement *body;
	    Expression *aggr;

	    nextToken();
	    check(TOKlparen);

	    inout = In;
	    if (token.value == TOKinout)
	    {	inout = InOut;
		nextToken();
	    }
	    tb = parseBasicType();
	    at = parseDeclarator(tb, &ai);
	    a = new Argument(at, ai, inout);

	    check(TOKsemicolon);

	    aggr = parseExpression();
	    check(TOKrparen);
	    body = parseStatement(0);
	    s = new ForeachStatement(loc, a, aggr, body);
	    break;
	}

	case TOKif:
	{   Expression *condition;
	    Statement *ifbody;
	    Statement *elsebody;

	    nextToken();
	    check(TOKlparen);
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
	    s = new IfStatement(loc, condition, ifbody, elsebody);
	    break;
	}

	case TOKdebug:
	{   Condition *condition;
	    Statement *ifbody;
	    Statement *elsebody;

	    nextToken();
	    if (token.value == TOKlparen)
	    {
		nextToken();
		condition = parseDebugCondition();
		check(TOKrparen);
	    }
	    else
		condition = new DebugCondition(1, NULL);
	    ifbody = parseStatement(PSsemi);
	    if (token.value == TOKelse)
	    {
		nextToken();
		elsebody = parseStatement(PSsemi);
	    }
	    else
		elsebody = NULL;
	    s = new ConditionalStatement(loc, condition, ifbody, elsebody);
	    break;
	}

	case TOKversion:
	{   Condition *condition;
	    Statement *ifbody;
	    Statement *elsebody;

	    nextToken();
	    if (token.value == TOKlparen)
	    {
		nextToken();
		condition = parseVersionCondition();
		check(TOKrparen);
	    }
	    else
	    {	error("(condition) expected after version");
		condition = NULL;
	    }
	    ifbody = parseStatement(PSsemi);
	    if (token.value == TOKelse)
	    {
		nextToken();
		elsebody = parseStatement(PSsemi);
	    }
	    else
		elsebody = NULL;
	    s = new ConditionalStatement(loc, condition, ifbody, elsebody);
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
	    Array *statements;

	    nextToken();
	    exp = parseExpression();
	    check(TOKcolon);

	    statements = new Array();
	    while (token.value != TOKcase &&
		   token.value != TOKdefault &&
		   token.value != TOKrcurly)
	    {
		statements->push(parseStatement(PSsemi | PScurlyscope));
	    }
	    s = new CompoundStatement(loc, statements);
	    s = new ScopeStatement(loc, s);
	    s = new CaseStatement(loc, exp, s);
	    break;
	}

	case TOKdefault:
	{
	    Array *statements;

	    nextToken();
	    check(TOKcolon);

	    statements = new Array();
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
	    check(TOKsemicolon);
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
	    check(TOKsemicolon);
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
	    check(TOKsemicolon);
	    s = new ContinueStatement(loc, ident);
	    break;
	}

	case TOKgoto:
	{   Identifier *ident;

	    nextToken();
	    if (token.value != TOKidentifier)
	    {	error("Identifier expected following goto");
		ident = NULL;
	    }
	    else
	    {	ident = token.ident;
		nextToken();
	    }
	    check(TOKsemicolon);
	    s = new GotoStatement(loc, ident);
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
	    check(TOKsemicolon);
	    s = new ThrowStatement(loc, exp);
	    break;
	}

	case TOKvolatile:
	    nextToken();
	    s = parseStatement(PSsemi | PSscope);
	    s = new VolatileStatement(loc, s);
	    break;

	case TOKasm:
	{   Array *statements;
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
	    statements = new Array();
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
	    while (token.value != TOKsemicolon && token.value != TOKeof)
		nextToken();
	    nextToken();
	    s = NULL;
	    break;
    }

    return s;
}

void Parser::check(enum TOK value)
{
    if (token.value != value)
	error("found '%s' when expecting '%s'", token.toChars(), Token::toChars(value));
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

    switch (t->value)
    {
	CASE_BASIC_TYPES:
	    t = peek(t);
	    break;

	case TOKidentifier:
	    while (1)
	    {
		t = peek(t);
		if (t->value == TOKdot)
		{
	Ldot:
		    t = peek(t);
		    if (t->value != TOKidentifier)
			goto Lfalse;
		}
		else
		    break;
	    }
	    break;

	case TOKdot:
	    goto Ldot;

	case TOKinstance:
	    // Handle cases like:
	    //	instance Foo(int).bar x;
	    // But remember that:
	    //	instance Foo(int) x;
	    // is not a type, but is an AliasDeclaration declaration.
	    if (!isTemplateInstance(t, &t))
		goto Lfalse;		// invalid syntax for template instance
	    if (t->value == TOKdot)
		goto Ldot;
	    goto Lfalse;

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
		    if (!isExpression(&t))
			return FALSE;
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
		    return FALSE;
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
		t = peek(t);
	    default:
		if (!isBasicType(&t))
		    return FALSE;
		tmp = FALSE;
		if (!isDeclarator(&t, &tmp, TOKreserved))
		    return FALSE;
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
    int nest = 0;

    for (;; t = peek(t))
    {
	switch (t->value)
	{
	    case TOKlbracket:
		nest++;
		continue;

	    case TOKrbracket:
		if (--nest >= 0)
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
    {   int parencnt = 0;

	while (1)
	{
	    t = peek(t);
	    switch (t->value)
	    {
		case TOKlparen:
		    ++parencnt;
		    continue;
		case TOKrparen:
		    if (--parencnt < 0)
			break;
		    continue;
		case TOKcomma:
		    if (parencnt)
			continue;
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


/********************************* Expression Parser ***************************/

Expression *Parser::parsePrimaryExp()
{   Expression *e;
    Type *t;
    Loc loc = this->loc;

    switch (token.value)
    {
	case TOKidentifier:
	    e = new IdentifierExp(loc, token.ident);
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
	    e = new ImaginaryExp(loc, token.float80value, Type::timaginary32);
	    nextToken();
	    break;

	case TOKimaginary64v:
	    e = new ImaginaryExp(loc, token.float80value, Type::timaginary64);
	    nextToken();
	    break;

	case TOKimaginary80v:
	    e = new ImaginaryExp(loc, token.float80value, Type::timaginary80);
	    nextToken();
	    break;

	case TOKnull:
	    e = new NullExp(loc);
	    nextToken();
	    break;

	case TOKtrue:
	    e = new IntegerExp(loc, 1, Type::tbit);
	    nextToken();
	    break;

	case TOKfalse:
	    e = new IntegerExp(loc, 0, Type::tbit);
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

	    // cat adjacent strings
	    s = token.ustring;
	    len = token.len;
	    while (1)
	    {
		nextToken();
		if (token.value == TOKstring)
		{   unsigned len1;
		    unsigned len2;
		    unsigned char *s2;

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
	    e = new StringExp(loc, s, len);
	    break;
	}

	CASE_BASIC_TYPES_X(t):
	    nextToken();
	    check(TOKdot);
	    if (token.value != TOKidentifier)
	    {   error("Identifier expected following struct");
		return NULL;
	    }
	    e = new TypeDotIdExp(loc, t, token.ident);
	    nextToken();
	    break;

	case TOKassert:
	    nextToken();
	    check(TOKlparen);
	    e = parseAssignExp();
	    check(TOKrparen);
	    e = new AssertExp(loc, e);
	    break;

	case TOKinstance:
	{   TemplateInstance *tempinst;
	    TypeInstance *ti;

	    tempinst = parseTemplateInstance();
	    if (!tempinst)
		return NULL;
	    e = new ScopeExp(loc, tempinst);
#if 0
	    ti = new TypeInstance(loc, tempinst);
	    check(TOKdot);
	    if (token.value != TOKidentifier)
	    {   error("Identifier expected following struct");
		return NULL;
	    }
	    ti->addIdent(token.ident);
	    e = new TypeExp(loc, ti);
	    nextToken();
#endif
	    break;
	}

	case TOKfunction:
	case TOKdelegate:
	{
	    /* function type(parameters) { body }
	     * delegate type(parameters) { body }
	     */
	    Array *arguments;
	    int varargs;
	    FuncLiteralDeclaration *fd;
	    Type *t;
	    enum TOK save = token.value;

	    nextToken();
	    if (token.value == TOKlparen)
		t = Type::tvoid;		// default to void return type
	    else
	    {
		t = parseBasicType();
		t = parseBasicType2(t);		// function return type
	    }
	    arguments = parseParameters(&varargs);
	    t = new TypeFunction(arguments, t, varargs, linkage);
	    fd = new FuncLiteralDeclaration(loc, 0, t, save, NULL);
	    parseContracts(fd);
	    e = new FuncExp(loc, fd);
	    break;
	}

	default:
	    error("expression expected, not '%s'", token.toChars());
	    e = NULL;
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
		    e = new DotIdExp(loc, e, token.ident);
		else
		    error("identifier expected following '.', not '%s'", token.toChars());
		break;

	    case TOKarrow:
		nextToken();
		if (token.value == TOKidentifier)
		    e = new ArrowExp(loc, e, token.ident);
		else
		    error("identifier expected following '->', not '%s'", token.toChars());
		break;

	    case TOKplusplus:
		e = new PostIncExp(loc, e);
		break;

	    case TOKminusminus:
		e = new PostDecExp(loc, e);
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

		nextToken();
		if (token.value == TOKrbracket)
		{   // array[]
		    e = new SliceExp(loc, e, NULL, NULL);
		    nextToken();
		}
		else
		{
		    index = parseExpression();
		    if (token.value == TOKrange)
		    {	// array[lwr .. upr]
			nextToken();
			upr = parseExpression();
			e = new SliceExp(loc, e, index, upr);
		    }
		    else
		    {	// array[index]
			e = new IndexExp(loc, e, index);
		    }
		    check(TOKrbracket);
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
	{   Type *t;
	    Array *newargs;
	    Array *arguments;

	    nextToken();
	    newargs = NULL;
	    if (token.value == TOKlparen)
	    {
		newargs = parseArguments();
	    }

#if LTORARRAYDECL
	    t = parseBasicType();
	    t = parseBasicType2(t);
	    if (t->ty == Taarray)
	    {
		Type *index = ((TypeAArray *)t)->index;

		if (index->ty == Tident)
		{
		    TypeIdentifier *ti = (TypeIdentifier *)index;
		    int i;
		    Expression *e;
		    Identifier *id = (Identifier *)ti->idents.data[0];

		    e = new IdentifierExp(loc, id);
		    for (i = 1; i < ti->idents.dim; i++)
		    {
			id = (Identifier *)ti->idents.data[i];
			e = new DotIdExp(loc, e, id);
		    }

		    arguments = new Array();
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

		arguments = new Array();
		arguments->push(e);
		t = new TypeDArray(t->next);
	    }
	    else
	    {
		arguments = parseArguments();
	    }
#else
	    t = parseBasicType();
	    while (token.value == TOKmul)
	    {	t = new TypePointer(t);
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
	    else
		arguments = parseArguments();
#endif
	    e = new NewExp(loc, newargs, t, arguments);
	    break;
	}
#if DCASTSYNTAX
	case TOKcast:				// cast(type) expression
	{   Type *t;

	    nextToken();
	    check(TOKlparen);
	    t = parseBasicType();
	    t = parseDeclarator(t,NULL);	// ( type )
	    check(TOKrparen);

	    // if .identifier
	    if (token.value == TOKdot)
	    {
		nextToken();
		if (token.value != TOKidentifier)
		{   error("Identifier expected following cast(type).");
		    return NULL;
		}
		e = new TypeDotIdExp(loc, t, token.ident);
		nextToken();
	    }
	    else
	    {
		e = parseUnaryExp();
		e = new CastExp(loc, e, t);
	    }

	    break;
	}
#endif
	case TOKlparen:
	{   Token *tk;

	    nextToken();
#if CCASTSYNTAX
	    // If cast
	    if (isDeclaration(&token, 0, TOKrparen, &tk))
	    {
		tk = peek(tk);		// skip over right parenthesis
		switch (tk->value)
		{
		    case TOKdot:
		    case TOKplusplus:
		    case TOKminusminus:
		    case TOKnot:
		    case TOKtilde:
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
		    case TOKand:
		    case TOKmul:
		    case TOKmin:
		    case TOKadd:
		    case TOKfunction:
		    case TOKdelegate:
		    CASE_BASIC_TYPES:
		    {	// (type) una_exp
			Type *t;

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
			}
			else
			{
			    e = parseUnaryExp();
			    e = new CastExp(loc, e, t);
			}
			return e;
		    }
		}
	    }
#endif
	    // ( expression )
	    e = parseExpression();
	    check(TOKrparen);
	    e = parsePostExp(e);
	    break;
	}
	default:
	    e = parsePrimaryExp();
	    break;
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
	    case TOKnotidentity:
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

Expression *Parser::parseAndExp()
{   Expression *e;
    Expression *e2;
    Loc loc = this->loc;

    e = parseEqualExp();
    while (token.value == TOKand)
    {
	nextToken();
	e2 = parseEqualExp();
	e = new AndExp(loc,e,e2);
	loc = this->loc;
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
 * Assume current token is '('.
 */

Array *Parser::parseArguments()
{   // function call
    Array *arguments;
    Expression *arg;

    arguments = new Array();
    if (token.value == TOKlparen)
    {
	nextToken();
	if (token.value != TOKrparen)
	{
	    while (1)
	    {
		arg = parseAssignExp();
		arguments->push(arg);
		if (token.value == TOKrparen)
		    break;
		check(TOKcomma);
	    }
	}
	check(TOKrparen);
    }
    return arguments;
}

/********************************* ***************************/

