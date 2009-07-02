
// Copyright (c) 1999-2005 by Digital Mars
// All Rights Reserved
// initial header generation implementation by Dave Fladebo
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Routines to emit header files

#ifdef _DH

#define PRETTY_PRINT
//#define TEST_EMIT_ALL   // For Testing

#define LOG 0

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#if __DMC__
#include <complex.h>
#endif

#include "id.h"
#include "init.h"

#include "attrib.h"
#include "cond.h"
#include "enum.h"
#include "import.h"
#include "module.h"
#include "mtype.h"
#include "scope.h"
#include "staticassert.h"
#include "template.h"
#include "utf.h"
#include "version.h"

#include "declaration.h"
#include "aggregate.h"
#include "expression.h"
#include "statement.h"
#include "mtype.h"

struct HdrGenState
{
    int tpltMember;
    int inCallExp;
    int inPtrExp;
    int inSlcExp;
    int inDotExp;
    int inBinExp;
    int inArrExp;
    int emitInst;
    struct
    {
        int init;
        int decl;
    } FLinit;
};

void Module::genhdrbufr()
{
    HdrGenState hgs;
    int i;

    hdrbufr.printf("// D header file generated from '%s'", srcfile->toChars());
    hdrbufr.writenl();

    if (md)
    {
        hdrbufr.writestring("module ");
        if (md->packages)
        {   for (i = 0; i < md->packages->dim; i++)
            {   Identifier *pid = (Identifier *)md->packages->data[i];

                hdrbufr.writestring(pid->toChars());
                hdrbufr.writebyte('.');
            }
        }
        memset(&hgs, 0, sizeof(hgs));
        toHBuffer(&hdrbufr, &hgs);
        hdrbufr.writebyte(';');
        hdrbufr.writenl();
    }

    for (i = 0; i < members->dim; i++)
    {   Dsymbol *s = (Dsymbol *)members->data[i];

        memset(&hgs, 0, sizeof(hgs));
        s->toHBuffer(&hdrbufr, &hgs);
    }
}

void Module::genhdrfile()
{
#ifdef PRETTY_PRINT
    // Pretty print a little to make the code more readable for easier debugging.
    int i, j, indent = 0;
    const int indentStep = 4;
    OutBuffer tbuf, line, cs, de;
    char prev = NULL, curc = NULL, next = NULL;

    for (j = 0; j < indentStep; j++)
    {   cs.writebyte(' ');
        de.writebyte(' ');
    }

    cs.writestring("case ");
    de.writestring("default:");
    cs.fill0(1);
    de.fill0(1);

    if (hdrbufr.offset && (hdrbufr.data[hdrbufr.offset - 1] != '\n'))
        hdrbufr.writenl();

    for (i = 0; i < hdrbufr.offset; i++)    //HACK
    {
        prev = curc;
        curc = hdrbufr.data[i];
        next = (i < hdrbufr.offset - 1) ? hdrbufr.data[i+1] : NULL;
        switch (curc)
        {
        case '\r':
            break;
        case '\n':
            if (strstr((const char *)line.data,(const char *)cs.data) ||
               strstr((const char *)line.data,(const char *)de.data))
            {   OutBuffer tline;
                for (j = indentStep; j < line.offset; j++)
                    tline.writebyte(line.data[j]);
                tbuf.write(&tline);
            }
            else
                tbuf.write(&line);
            tbuf.writenl();
            line.reset();
            for (j = 0; j < indent; j++)
                line.writebyte(' ');
            break;
        case '{':
            indent += indentStep;
            line.writebyte(curc);
            break;
        case '}':
            if (indent)
            {   if (next == '\r' || next == '\n')
                    line.offset -= indentStep;
                indent -= indentStep;
            }
            line.writebyte(curc);
            break;
        default:
            line.writebyte(curc);
            break;
        }
    }
    // Transfer image to file
    hdrfile->setbuffer(tbuf.data, tbuf.offset);
    tbuf.data = hdrbufr.data = line.data = NULL;

#else
    // Transfer image to file
    hdrfile->setbuffer(hdrbufr.data, hdrbufr.offset);
    hdrbufr.data = NULL;
#endif

    hdrfile->writev();
}

/** Duplicated from template.c for now **/
static Expression *isExpression(Object *o)
{
    //return dynamic_cast<Expression *>(o);
    if (!o || o->dyncast() != DYNCAST_EXPRESSION)
	    return NULL;
    return (Expression *)o;
}

/** Duplicated from template.c for now **/
static Dsymbol *isDsymbol(Object *o)
{
    //return dynamic_cast<Dsymbol *>(o);
    if (!o || o->dyncast() != DYNCAST_DSYMBOL)
    	return NULL;
    return (Dsymbol *)o;
}

/** Duplicated from template.c for now **/
static Type *isType(Object *o)
{
    //return dynamic_cast<Type *>(o);
    if (!o || o->dyncast() != DYNCAST_TYPE)
	    return NULL;
    return (Type *)o;
}

//Moved from func.c
void FuncDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    // Don't emit this stuff
    if (isUnitTestDeclaration() || isInvariantDeclaration())
    {
        return;
    }

    if (!parent)	// not a member of a StorageClassDeclaration
    {
	if (isConst())
	    buf->writestring("const ");
	if (isStatic() &&
	   !isStaticCtorDeclaration() && 
	   !isStaticDtorDeclaration() &&
	   !isNewDeclaration() &&
	   !isDeleteDeclaration())
	    buf->writestring("static ");
    }

    Type *t = htype ? htype : type;
    t->toHBuffer(buf,ident, hgs);

#ifdef TEST_EMIT_ALL
    if (hbody)
#else
    // hcopyof points to the FuncDeclaration that has been through semantic analysis
    //  (the syntaxCopy has not).
    if (hbody && (hgs->tpltMember || (hcopyof && hcopyof->canInline(1,1))))
#endif
    {
        if (hrequire || hensure)
            buf->writenl();

        // in{}
        if (hrequire)
        {   buf->writestring("in");
            buf->writenl();
            hrequire->toHBuffer(buf, hgs);
        }

        // out{}
        if (hensure)
        {   buf->writestring("out");
            if (outId)
            {   buf->writebyte('(');
                buf->writestring(outId->toChars());
                buf->writebyte(')');
            }
            buf->writenl();
            hensure->toHBuffer(buf, hgs);
        }

        if (hrequire || hensure)
            buf->writestring("body");

        buf->writenl();
        buf->writebyte('{');
        buf->writenl();
        hbody->toHBuffer(buf, hgs);
        buf->writebyte('}');
        buf->writenl();
    }
    else
    {
        buf->writeByte(';');
        buf->writenl();
    }
}

void AttribDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   unsigned dd = 0;
    OutBuffer tbuf;

    if (decl)
    {   dd = decl->dim;
	for (unsigned i = 0; i < dd; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    //if (dd > 1)
	    //    buf->writestring("    ");
	    s->toHBuffer(&tbuf, hgs);
	}
        if (tbuf.offset)
        {   if (dd > 1)
            {	buf->writenl();
		buf->writeByte('{');
		buf->writenl();
            }
	    else
                buf->writebyte(' ');

            buf->write(&tbuf);

            if (dd > 1)
    	        buf->writeByte('}');
        }
    }
    else
    	buf->writeByte(':');

    if (!decl || (tbuf.offset && dd != 1))
        buf->writenl();
}

void StorageClassDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    // See declaration.h storage class code (isFinal, isConst, isStatic, etc...) 
    //  to determine storage class for aggragate data members
    //  this->stc stores the storage class

    struct SCstring
    {
	int stc;
	enum TOK tok;
    };

    static SCstring table[] =
    {
	{ STCauto,         TOKauto },
	{ STCstatic,       TOKstatic },
	{ STCextern,       TOKextern },
	{ STCconst,        TOKconst },
	{ STCfinal,        TOKfinal },
	{ STCabstract,     TOKabstract },
	{ STCsynchronized, TOKsynchronized },
	{ STCdeprecated,   TOKdeprecated },
	{ STCoverride,     TOKoverride },
    };

    OutBuffer tbuf;

    for (int i = 0; i < sizeof(table)/sizeof(table[0]); i++)
    {
	if (stc & table[i].stc)
	{
	    if (tbuf.offset)
		tbuf.writebyte(' ');
	    tbuf.writestring(Token::toChars(table[i].tok));
	}
    }

    buf->write(&tbuf);
    AttribDeclaration::toHBuffer(buf, hgs);
}

void LinkDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   char *p;

    switch (linkage)
    {
	case LINKd:		p = "D";		break;
	case LINKc:		p = "C";		break;
	case LINKcpp:		p = "C++";		break;
	case LINKwindows:	p = "Windows";		break;
	case LINKpascal:	p = "Pascal";		break;
	default:
	    assert(0);
	    break;
    }
    buf->writestring("extern (");
    buf->writestring(p);
    buf->writebyte(')');
    AttribDeclaration::toHBuffer(buf, hgs);
}

void ProtDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   char *p;
    OutBuffer tbuf;
    int i;
    int emit = 0;
    char c;

    AttribDeclaration::toHBuffer(&tbuf, hgs);
    for (int i = 0; i < tbuf.offset; i++)
    {   c = tbuf.data[i];
        // identifiers must have at least one of either '_' or alpha,
        //  or begin a new attribute scope with ':' or '{'
        if (c >= 'a' && c <= 'z' ||
           c >= 'A' && c <= 'Z' ||
           c == '_' || c == ':' || c == '{')
        {   emit = 1;
            break;
        }
    }
    if (emit)
    {
        switch (protection)
        {
	    case PROTprivate:	p = "private";		break;
	    case PROTpackage:	p = "package";		break;
	    case PROTprotected:	p = "protected";	break;
	    case PROTpublic:	p = "public";		break;
	    case PROTexport:	p = "export";		break;
	    default:
	        assert(0);
	        break;
        }

        buf->writestring(p);
        buf->write(&tbuf);
    }
}

void AlignDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("align(%d)", salign);
    AttribDeclaration::toHBuffer(buf, hgs);
}

void AnonDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf(isunion ? "union" : "struct");
    //AttribDeclaration::toHBuffer(buf);
    if (decl)
    {
	buf->writenl();
	buf->writeByte('{');
	buf->writenl();
	for (unsigned i = 0; i < decl->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    //buf->writestring("    ");
	    s->toHBuffer(buf, hgs);
	}
	buf->writeByte('}');
    }
    buf->writenl();
}

void PragmaDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("pragma(%s", ident->toChars());
    if (args)
    {
	for (size_t i = 0; i < args->dim; i++)
	{
	    Expression *e = (Expression *)args->data[i];

	    buf->writestring(", ");
	    e->toHBuffer(buf, hgs);
	}
    }
    buf->writestring(")");
    AttribDeclaration::toHBuffer(buf, hgs);
}

void ConditionalDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (decl || elsedecl)
    {
        int error = 0;
        int inc = condition->inc;
        if (!inc)
        {
            unsigned errors = global.errors;
            global.gag++;
            inc = condition->include(NULL,NULL);
            if (errors != global.errors)
            {   error = 1;
                inc = 0;            
            }
            global.gag--;
            global.errors = errors;
        }

        if (!error || inc)
        {
	    if (decl && condition->inc == 1)
	    {
		for (unsigned i = 0; i < decl->dim; i++)
		{
		    Dsymbol *s = (Dsymbol *)decl->data[i];

		    s->toHBuffer(buf, hgs);
		}
	    }
	    if (elsedecl && condition->inc == 2)
	    {
		for (unsigned i = 0; i < elsedecl->dim; i++)
		{
		    Dsymbol *s = (Dsymbol *)elsedecl->data[i];

		    s->toHBuffer(buf, hgs);
		}
	    }
        }
        else
        {
            OutBuffer ibuf, ebuf;
	    if (decl)
	    {
		for (unsigned i = 0; i < decl->dim; i++)
		{
		    Dsymbol *s = (Dsymbol *)decl->data[i];

		    s->toHBuffer(&ibuf, hgs);
		}
	    }
            if (elsedecl)
            {
                OutBuffer tbuf;
		for (unsigned i = 0; i < elsedecl->dim; i++)
		{
		    Dsymbol *s = (Dsymbol *)elsedecl->data[i];

		    s->toHBuffer(&tbuf, hgs);
		}
                if (tbuf.offset)
                {   ebuf.writestring("}\nelse\n{\n");
                    ebuf.write(&tbuf);
                }
            }
            if (ibuf.offset || ebuf.offset)
            {
                condition->toHBuffer(buf, hgs);
                buf->writenl();
                buf->writebyte('{');
                buf->writenl();
                if (ibuf.offset)
                    buf->write(&ibuf);
                if (ebuf.offset)
                    buf->write(&ebuf);
                buf->writebyte('}');
                buf->writenl();
            }
        }
    }
}

void ClassDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;
    int needcomma;
    int needcolon;
    int isAnon;

    needcomma = 0;
    needcolon = 1;
    isAnon = isAnonymous();

    if (!isAnon)
        buf->printf("%s %s", kind(), toChars());
    else
        buf->writebyte(' ');
    for (i = 0; i < baseclasses.dim; i++)
    {	BaseClass *b = (BaseClass *)baseclasses.data[i];
        ClassDeclaration *cd = b->base;

        if (!isAnon && cd && !strcmp(cd->ident->toChars(),"Object"))
            continue;
        if (!isAnon && needcolon)
            buf->writestring(" : ");
        needcolon = 0;
        if (needcomma)
	    buf->writeByte(',');
	needcomma = 1;

        if (cd)
        {   TemplateInstance *ti = cd->parent ?
		cd->parent->isTemplateInstance() : NULL;
            if (ti)
            {   hgs->emitInst++;
                ti->toHBuffer(buf,hgs);
                hgs->emitInst--;
            }
            else
                buf->writestring(cd->ident->toChars());
        }
        else
	{
	    b->type->toHBuffer(buf, NULL, hgs);
	}
    }
    buf->writenl();
    buf->writeByte('{');
    buf->writenl();
    for (i = 0; i < members->dim; i++)
    {  	Dsymbol *s = (Dsymbol *)members->data[i];

        s->toHBuffer(buf, hgs);
    }
    buf->writestring("}");
    if (!isAnon)
        buf->writenl();
}

void Condition::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void StaticIfCondition::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("static if(");
    exp->toHBuffer(buf, hgs);
    buf->writeByte(')');
}

void IftypeCondition::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("iftype(");
    targ->toHBuffer(buf, id, hgs);
    if (tspec)
    {
	if (tok == TOKcolon)
	    buf->writestring(" : ");
	else
	    buf->writestring(" == ");
	tspec->toHBuffer(buf, NULL, hgs);
    }
    buf->writeByte(')');
}

void TypedefDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("typedef ");
    hbasetype->toHBuffer(buf, ident, hgs);
    TypeTypedef *td = (TypeTypedef *)this->htype;
    if (td)
    {
        if (td->sym->init)
        {
            Expression *e = td->defaultInit();
            if (e)
            {   buf->writestring(" = ");
                buf->writestring(e->toHChars(hgs));
            }
        }
    }
    buf->writeByte(';');
    buf->writenl();
}

void AliasDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("alias ");
    if (haliassym)
    {
        haliassym->toHBuffer(buf, hgs);
	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
    else
    	htype->toHBuffer(buf, ident, hgs);
    buf->writeByte(';');
    buf->writenl();
}

void VarDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    OutBuffer tbuf, tbuf2;

    if (!parent)	// not a member of a StorageClassDeclaration
    {
	if (isAuto())
	    tbuf.writestring("auto ");
	if (isConst())
	    tbuf.writestring("const ");
	if (isStatic())
	    tbuf.writestring("static ");
    }

    if (hgs->FLinit.init && hgs->FLinit.decl > 0)
    {
        tbuf.writebyte(',');
    }

    Type *t = htype ? htype : type;
    if (t && (!hgs->FLinit.init || !hgs->FLinit.decl))
    {
        t->toHBuffer(&tbuf, ident, hgs);
    }
    else
    {
	tbuf.writestring(ident->toHChars2());
    }

    // skip initializers for non-const globals
#ifdef TEST_EMIT_ALL
    if (1)
#else
    if (isConst() || !(parent && parent->isModule() && protection == PROTpublic))
#endif
    {
	Initializer *i = hinit ? hinit : init;
	if (i)
	{
	    i->toHBuffer(&tbuf2, hgs);
	    if (tbuf2.offset)
	    {   tbuf.writestring(" = ");
		tbuf.write(&tbuf2);
		if (!t) // implicit type
		{
		    ExpInitializer *ei = i->isExpInitializer();
		    if (ei && ei->exp && ei->exp->type)
		    {
			switch(ei->exp->type->ty)
			{
			case Tint64:
			    tbuf.writebyte('l');
			    break;
			case Tuns32:
			    tbuf.writebyte('u');
			    break;
			case Tuns64:
			    tbuf.writestring("lu");
			    break;
			case Tfloat32:
			    tbuf.writebyte('F');
			    break;
			case Tfloat80:
			    tbuf.writebyte('L');
			    break;
			default:
			    break;
			}
		    }
		}
	    }
	}
    }

    if (tbuf.offset)
    {   buf->write(&tbuf);
        if (!hgs->FLinit.init)
        {   buf->writeByte(';');
            buf->writenl();
        }
        else
        {
            hgs->FLinit.decl++;
        }
    }
}

void Dsymbol::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(toChars());
}

void EnumDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    buf->writestring("enum ");
    if (ident)
    {	buf->writestring(ident->toChars());
	buf->writeByte(' ');
    }
    if (memtype)
    {   buf->writestring(": ");
	memtype->toHBuffer(buf, NULL, hgs);
    }
    if (!members)
    {	buf->writeByte(';');
	buf->writenl();
	return;
    }
    buf->writenl();
    buf->writeByte('{');
    buf->writenl();
    for (i = 0; i < members->dim; i++)
    {   EnumMember *em = ((Dsymbol *)members->data[i])->isEnumMember();
	if (!em)
	    continue;
        //buf->writestring("    ");
	em->toHBuffer(buf, hgs);
	if (i < members->dim - 1)
	    buf->writeByte(',');
	buf->writenl();
    }
    buf->writeByte('}');
    buf->writenl();
}

void EnumMember::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    if (value)
    {
	buf->writestring(" = ");
	value->toHBuffer(buf, hgs);
    }
}

void argsToHBuffer(OutBuffer *buf, Array *arguments, HdrGenState *hgs)
{
    if (arguments)
    {
	for (int i = 0; i < arguments->dim; i++)
	{   Expression *arg = (Expression *)arguments->data[i];
	    if (arg)
	    {
		if (i)
		    buf->writeByte(',');
		arg->toHBuffer(buf, hgs);
	    }
	}
    }
}

char *Expression::toHChars(HdrGenState *hgs)
{   OutBuffer *buf;

    buf = new OutBuffer();
    toHBuffer(buf, hgs);
    return buf->toChars();
}

void Expression::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void IntegerExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void RealExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void ComplexExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void IdentifierExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toHChars2());
}

void DsymbolExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void ThisExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void SuperExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void NullExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void StringExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void TypeDotIdExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (type->ty == Tpointer || type->ty == Tarray)
        buf->writeByte('(');
    type->toHBuffer(buf, NULL, hgs);
    if (type->ty == Tpointer || type->ty == Tarray)
        buf->writeByte(')');
    buf->writeByte('.');
    buf->writestring(ident->toChars());
}

void TypeExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    type->toHBuffer(buf, NULL, hgs);
}

void ScopeExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (sds->isTemplateInstance())
    {
        sds->toHBuffer(buf, hgs);
    }
    else
    {
        buf->writestring(sds->kind());
        buf->writestring(" ");
        buf->writestring(sds->toChars());
    }
}

void NewExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    buf->writestring("new");
    if (newargs && newargs->dim)
    {
	    buf->writeByte('(');
	    argsToHBuffer(buf, newargs, hgs);
	    buf->writeByte(')');
    }
    buf->writebyte(' ');
    type->toHBuffer(buf, NULL, hgs);
    if (arguments && arguments->dim)
    {
	    buf->writeByte('(');
	    argsToHBuffer(buf, arguments, hgs);
	    buf->writeByte(')');
    }
}

void NewAnonClassExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    buf->writestring("new");
    if (newargs && newargs->dim)
    {
	    buf->writeByte('(');
	    argsToHBuffer(buf, newargs, hgs);
	    buf->writeByte(')');
    }
    buf->writestring(" class");
    if (arguments && arguments->dim)
    {
	    buf->writeByte('(');
	    argsToHBuffer(buf, arguments, hgs);
	    buf->writeByte(')');
    }
    //buf->writestring(" { }");
    if (cd)
    {
        cd->toHBuffer(buf, hgs);
    }
}

void SymOffExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void VarExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void FuncExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (fd->tok != TOKfunction && fd->tok != TOKdelegate)
    {
        buf->writestring(fd->toChars());
    }
    else
    {
        if (fd->tok == TOKfunction)
            buf->writestring("function ");
        else
            buf->writestring("delegate ");
        fd->type->toHBuffer(buf,NULL, hgs);
        if (fd->fbody && fd->hbody)
        {
            buf->writenl();
            buf->writebyte('{');
            buf->writenl();
            fd->hbody->toHBuffer(buf, hgs);
            buf->writebyte('}');
            buf->writenl();
        }
        else
        {
            buf->writeByte(';');
            buf->writenl();
        }
    }
}

void DeclarationExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    declaration->toHBuffer(buf, hgs);
}

void TypeidExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("typeid(");
    typeidType->toHBuffer(buf, NULL, hgs);
    buf->writeByte(')');
}

void HaltExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void IftypeExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("is(");
    targ->toHBuffer(buf, id, hgs);
    if (tspec)
    {
	if (tok == TOKcolon)
	    buf->writestring(" : ");
	else
	    buf->writestring(" == ");
	tspec->toHBuffer(buf, NULL, hgs);
    }
    buf->writeByte(')');
}

void UnaExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    int bracket = (op == TOKaddress && (hgs->inSlcExp || hgs->inArrExp));

    if (bracket)
        buf->writebyte('(');

    if (op == TOKaddress)
    {
        buf->writebyte('&');
    }
    else
    {   buf->writestring(Token::toChars(op));
        buf->writebyte(' ');
    }

    if (e1->isBinExp())
        buf->writebyte('(');
    e1->toHBuffer(buf, hgs);
    if (e1->isBinExp())
        buf->writebyte(')');

    if (bracket)
        buf->writebyte(')');

}

void BinExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    hgs->inBinExp++;

    //e1->toHBuffer(buf, hgs);
    //buf->writeByte(' ');
    //buf->writestring(Token::toChars(op));
    //buf->writeByte(' ');
    //e2->toHBuffer(buf, hgs);

    BinExp *be1 = e1->isBinExp();
    BinExp *be2 = e2->isBinExp();
    int opassign = (op == TOKassign  ||
                    op == TOKaddass  ||
                    op == TOKminass  ||
                    op == TOKmulass  ||
                    op == TOKdivass  ||
                    op == TOKmodass  ||
                    op == TOKshlass  ||
                    op == TOKshrass  ||
                    op == TOKcatass  ||
                    op == TOKandass  ||
                    op == TOKorass   ||
                    op == TOKxorass  ||
                    op == TOKushrass);

    int bracket1 = (be1 && !opassign);
    int bracket2 = (be2 && !opassign);

    if (hgs->inPtrExp)
        buf->writebyte('(');

    if (bracket1)
        buf->writebyte('(');
    e1->toHBuffer(buf, hgs);
    if (bracket1)
        buf->writebyte(')');
    buf->writeByte(' ');
    buf->writestring(Token::toChars(op));
    buf->writeByte(' ');
    if (bracket2)
        buf->writebyte('(');
    e2->toHBuffer(buf, hgs);
    if (bracket2)
        buf->writebyte(')');

    if (hgs->inPtrExp)
        buf->writebyte(')');

    hgs->inBinExp--;
}

void AssertExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("assert(");
    e1->toHBuffer(buf, hgs);
    buf->writeByte(')');
}

void DotIdExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    hgs->inDotExp++;

    int hasNew = (e1->op == TOKnew);
    if (!hasNew)
    {
        BinExp *be = e1->isBinExp();
        while (be)
        {
            if (be->e2 && be->e2->op == TOKnew)
            {   hasNew = 1;
                break;
            }
            be = be->e2->isBinExp();
        }
    }
    if (hasNew)
        buf->writebyte('(');
    e1->toHBuffer(buf, hgs);
    if (hasNew)
        buf->writebyte(')');
    buf->writeByte('.');
    buf->writestring(ident->toChars());

    hgs->inDotExp--;
}

void DotVarExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    e1->toHBuffer(buf, hgs);
    buf->writeByte('.');
    buf->writestring(var->toChars());
}

void DotTemplateInstanceExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    e1->toHBuffer(buf, hgs);
    buf->writeByte('.');
    ti->toHBuffer(buf, hgs);
}

void DelegateExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('&');
    if (!func->isNested())
    {	e1->toHBuffer(buf, hgs);
	buf->writeByte('.');
    }
    buf->writestring(func->toChars());
}

void DotTypeExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    e1->toHBuffer(buf, hgs);
    buf->writeByte('.');
    buf->writestring(sym->toChars());
}

void ArrowExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    e1->toHBuffer(buf, hgs);
    buf->writestring("->");
    buf->writestring(ident->toChars());
}

void CallExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    hgs->inCallExp++;
    e1->toHBuffer(buf, hgs);
    hgs->inCallExp--;

    buf->writeByte('(');
    argsToHBuffer(buf, arguments, hgs);
    buf->writeByte(')');
}

void PtrExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    int bracket = hgs->inDotExp || hgs->inCallExp;

    hgs->inPtrExp++;

    if (bracket)
        buf->writeByte('(');

    buf->writeByte('*');
    e1->toHBuffer(buf, hgs);

    if (bracket)
        buf->writeByte(')');

    hgs->inPtrExp--;
}

void CastExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    int brackets = (hgs->inBinExp || hgs->inDotExp || hgs->inArrExp || hgs->inSlcExp);

    if (brackets)
        buf->writebyte('(');

    buf->writestring("cast(");
    if (type && type->ty == Ttypedef)
	type->toHBuffer(buf, NULL, hgs);
    else
        to->toHBuffer(buf, NULL, hgs);
    buf->writestring(")(");
    e1->toHBuffer(buf, hgs);
    buf->writebyte(')');

    if (brackets)
        buf->writebyte(')');
}

void SliceExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    hgs->inSlcExp++;

    e1->toHBuffer(buf, hgs);
    buf->writeByte('[');
    if (upr || lwr)
    {
	    if (lwr)
	        lwr->toHBuffer(buf, hgs);
	    else
	        buf->writeByte('0');
	    buf->writestring("..");
	    if (upr)
	        upr->toHBuffer(buf, hgs);
	    else
	        buf->writestring("length");		// BUG: should be array.length
    }
    buf->writeByte(']');

    hgs->inSlcExp--;
}

void ArrayLengthExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    e1->toHBuffer(buf, hgs);
    buf->writestring(".length");
}

void ArrayExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    hgs->inArrExp++;

    e1->toHBuffer(buf, hgs);
    buf->writeByte('[');
    argsToHBuffer(buf, arguments, hgs);
    buf->writeByte(']');

    hgs->inArrExp--;
}

void IndexExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    e1->toHBuffer(buf, hgs);
    buf->writeByte('[');
    e2->toHBuffer(buf, hgs);
    buf->writeByte(']');
}

void PostIncExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    e1->toHBuffer(buf, hgs);
    buf->writestring("++");
}

void PostDecExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    e1->toHBuffer(buf, hgs);
    buf->writestring("--");
}

void CondExp::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    econd->toHBuffer(buf, hgs);
    buf->writestring(" ? ");
    e1->toHBuffer(buf, hgs);
    buf->writestring(" : ");
    e2->toHBuffer(buf, hgs);
}

char *Identifier::toHChars2()
{
    char *p = NULL;

    if (this == Id::ctor) p = "this";
    else if (this == Id::dtor) p = "~this";
    else if (this == Id::classInvariant) p = "invariant";
    else if (this == Id::unitTest) p = "unittest";
    else if (this == Id::staticCtor) p = "static this";
    else if (this == Id::staticDtor) p = "static ~this";
    else if (this == Id::dollar) p = "$";
    else if (this == Id::withSym) p = "with";
    else if (this == Id::result) p = "result";
    else if (this == Id::returnLabel) p = "return";
    else
	p = toChars();

    return p;
}

void Import::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    //object is imported by default
    if (strcmp(id->toChars(),"object"))
    {
	toCBuffer(buf);
    }
}

void VoidInitializer::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void StructInitializer::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writebyte('{');
    for (int i = 0; i < field.dim; i++)
    {
        if (i > 0) buf->writebyte(',');
        //VarDeclaration *v = (VarDeclaration *)field.data[i];
        //buf->writestring(v->ident->toChars());
        Identifier *id = (Identifier *)field.data[i];
        if (id)
        {
            buf->writestring(id->toChars());
            buf->writebyte(':');
        }
        Initializer *iz = (Initializer *)value.data[i];
        if (iz)
            iz->toHBuffer(buf, hgs);
    }
    buf->writebyte('}');
}

void ArrayInitializer::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writebyte('[');
    for (int i = 0; i < index.dim; i++)
    {
        if (i > 0) buf->writebyte(',');
        Expression *ex = (Expression *)index.data[i];
        if (ex)
        {
            ex->toHBuffer(buf, hgs);
            buf->writebyte(':');
        }
        Initializer *iz = (Initializer *)value.data[i];
        if (iz)
            iz->toHBuffer(buf, hgs);
    }
    buf->writebyte(']');
}

void ExpInitializer::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    exp->toHBuffer(buf, hgs);
}

void AsmStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    Token *t = tokens;
    while (t)
    {
        if (t->value == TOKstring)
            buf->writebyte('"');
        buf->writestring(t->toChars());
        if (t->value == TOKstring)
            buf->writebyte('"');
        if (t->next                          &&
           t->value != TOKmin               &&
           t->value != TOKcomma             &&
           t->next->value != TOKcomma       &&
           t->value != TOKlbracket          &&
           t->next->value != TOKlbracket    &&
           t->next->value != TOKrbracket    &&
           t->value != TOKlparen            &&
           t->next->value != TOKlparen      &&
           t->next->value != TOKrparen      &&
           t->value != TOKdot               &&
           t->next->value != TOKdot)
        {
            buf->writebyte(' ');
        }
        t = t->next;
    }
    buf->writebyte(';');
    buf->writenl();
}

void Type::toHBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    OutBuffer tbuf;

    toHBuffer2(&tbuf, ident, hgs);
    buf->write(&tbuf);
}

void Type::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    OutBuffer tbuf;
    toHBuffer2(&tbuf, NULL, hgs);
    buf->prependstring(tbuf.toChars());
    if (ident)
    {	buf->writeByte(' ');
    	buf->writestring(ident->toChars());
    }
}

void TypeBasic::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    toCBuffer2(buf, ident);
}

void TypeArray::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
#if 1
    OutBuffer buf2;
    toPrettyBracket(&buf2);
    buf->prependstring(buf2.toChars());
    if (ident)
    {   buf->writebyte(' ');
	buf->writestring(ident->toChars());
    }
    next->toHBuffer2(buf, NULL, hgs);
#elif 1
    // The D way
    Type *t;
    OutBuffer buf2;
    for (t = this; 1; t = t->next)
    {	TypeArray *ta;

	ta = dynamic_cast<TypeArray *>(t);
	if (!ta)
	    break;
	ta->toPrettyBracket(&buf2);
    }
    buf->prependstring(buf2.toChars());
    if (ident)
    {
	buf2.writestring(ident->toChars());
    }
    t->toHBuffer2(buf, NULL);
#else
    // The C way
    if (buf->offset)
    {	buf->bracket('(', ')');
	assert(!ident);
    }
    else if (ident)
	buf->writestring(ident->toChars());
    Type *t = this;
    do
    {	Expression *dim;
	buf->writeByte('[');
	dim = ((TypeSArray *)t)->dim;
	if (dim)
	    buf->printf("%d", dim->toInteger());
	buf->writeByte(']');
	t = t->next;
    } while (t->ty == Tsarray);
    t->toHBuffer2(buf, NULL);
#endif
}

void TypePointer::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    //printf("TypePointer::toCBuffer2() next = %d\n", next->ty);
    buf->prependstring("*");
    if (ident)
    {   buf->writebyte(' ');
	buf->writestring(ident->toChars());
    }
    next->toHBuffer2(buf, NULL, hgs);
}

void TypeReference::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    buf->prependstring("&");
    if (ident)
    {
	buf->writestring(ident->toChars());
    }
    next->toHBuffer2(buf, NULL, hgs);
}

void TypeFunction::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    if (buf->offset)
    {
	buf->bracket('(', ')');
	assert(!ident);
    }
    else
    {
	if (ident)
	{
	    buf->writestring(ident->toHChars2());
	    buf->prependbyte(' ');
	}
    }
    argsToHBuffer(buf, hgs);
    if (ident->toHChars2() == ident->toChars())
        next->toHBuffer2(buf, NULL, hgs);
}

void TypeFunction::argsToHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('(');
    if (arguments)
    {	int i;
	OutBuffer argbuf;

	for (i = 0; i < arguments->dim; i++)
	{   Argument *arg;

	    if (i)
		buf->writeByte(',');
	    arg = (Argument *)arguments->data[i];
	    if (arg->inout == Out)
		buf->writestring("out ");
	    else if (arg->inout == InOut)
		buf->writestring("inout ");
	    argbuf.reset();
	    arg->type->toHBuffer2(&argbuf, arg->ident, hgs);
	    if (arg->defaultArg)
	    {
		argbuf.writestring(" = ");
		arg->defaultArg->toHBuffer(&argbuf, hgs);
	    }
	    buf->write(&argbuf);
	}
	if (varargs)
	{
	    if (i && varargs == 1)
		buf->writeByte(',');
	    buf->writestring("...");
	}
    }
    buf->writeByte(')');
}

void TypeDelegate::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
#if 1
    OutBuffer args;
    TypeFunction *tf = (TypeFunction *)next;

    tf->argsToHBuffer(&args, hgs);
    buf->prependstring(args.toChars());
    buf->prependstring(" delegate");
    if (ident)
    {   buf->writebyte(' ');
	    buf->writestring(ident->toChars());
    }
    next->next->toHBuffer2(buf, NULL, hgs);
#else
    next->toHBuffer2(buf, Id::delegate, hgs);
    if (ident)
    	buf->writestring(ident->toChars());
#endif
}

void TypeQualified::toHBuffer2Helper(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    int i;

    for (i = 0; i < idents.dim; i++)
    {	Identifier *id = (Identifier *)idents.data[i];

	buf->writeByte('.');

	if (id->dyncast() != DYNCAST_IDENTIFIER)
	{
	    TemplateInstance *ti = (TemplateInstance *)id;
	    ti->toHBuffer(buf, hgs);
	}
	else
	    buf->writestring(id->toChars());
    }
}

void TypeIdentifier::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    OutBuffer tbuf;

    tbuf.writestring(this->ident->toChars());
    toHBuffer2Helper(&tbuf, NULL, hgs);
    buf->prependstring(tbuf.toChars());
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

void TypeInstance::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    OutBuffer tbuf;

    tempinst->toHBuffer(&tbuf, hgs);
    toHBuffer2Helper(&tbuf, NULL, hgs);
    buf->prependstring(tbuf.toChars());
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

void TypeTypeof::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    OutBuffer tbuf;

    tbuf.writestring("typeof(");
    exp->toHBuffer(&tbuf, hgs);
    tbuf.writeByte(')');
    toHBuffer2Helper(&tbuf, NULL, hgs);
    buf->prependstring(tbuf.toChars());
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

void TypeEnum::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    buf->prependstring(sym->toChars());
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

void TypeTypedef::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    buf->prependstring(sym->toChars());
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

void TypeStruct::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    buf->prependbyte(' ');
    buf->prependstring(sym->toChars());
    if (ident)
	buf->writestring(ident->toChars());
}

void TypeClass::toHBuffer2(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    if (ident == Id::This)
        return;

    buf->prependbyte(' ');
    buf->prependstring(sym->toChars());
    if (ident)
    	buf->writestring(ident->toChars());
}

void Statement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toHBuffer(buf, hgs);
    buf->writenl();
}

void ExpStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (exp)
	exp->toHBuffer(buf, hgs);
    buf->writeByte(';');
    if (!hgs->FLinit.init)
        buf->writenl();
}

void DeclarationStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    exp->toHBuffer(buf, hgs);
}

void CompoundStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;
    static int asmBlock = 0;

    for (i = 0; i < statements->dim; i++)
    {	Statement *s;

	s = (Statement *) statements->data[i];
	if (s)
        {   if (!asmBlock && s->isAsmStatement())
            {   asmBlock = 1;
                buf->writestring("asm");
                buf->writenl();
                buf->writebyte('{');
                buf->writenl();
            }
	    s->toHBuffer(buf, hgs);
        }
    }

    if (asmBlock)
    {   buf->writebyte('}');
        buf->writenl();
        asmBlock = 0;
    }
}

void ScopeStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('{');
    buf->writenl();

    if (statement)
    	statement->toHBuffer(buf, hgs);

    buf->writeByte('}');
    buf->writenl();
}

void ScopeStatement::toHBuffer2(OutBuffer *buf, HdrGenState *hgs)
{
    if (statement)
    	statement->toHBuffer(buf, hgs);
}

void WhileStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("while(");
    condition->toHBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    body->toHBuffer(buf, hgs);
}

void DoStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("do");
    buf->writenl();
    body->toHBuffer(buf, hgs);
    buf->writestring("while(");
    condition->toHBuffer(buf, hgs);
    buf->writebyte(')');
}

void ForStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("for(");
    if (init)
    {
        hgs->FLinit.init++;
        hgs->FLinit.decl = 0;
        init->toHBuffer(buf, hgs);
        if (hgs->FLinit.decl > 0)
            buf->writebyte(';');
        hgs->FLinit.decl = 0;
        hgs->FLinit.init--;
    }
    else
        buf->writebyte(';');
    if (condition)
    {   buf->writebyte(' ');
        condition->toHBuffer(buf, hgs);
    }
    buf->writebyte(';');
    if (increment)
    {   buf->writebyte(' ');
        increment->toHBuffer(buf, hgs);
    }
    buf->writebyte(')');
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    body->toHBuffer(buf, hgs);
    buf->writebyte('}');
    buf->writenl();
}

void ForeachStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("foreach(");
    int i;
    for (int i = 0; i < arguments->dim; i++)
    {
        Argument *a = (Argument *)arguments->data[i];
        if (i)
            buf->writestring(", ");
        if (a->inout == InOut)
            buf->writestring("inout ");
	a->type->toHBuffer(buf, a->ident, hgs);
    }
    buf->writestring("; ");
    aggr->toHBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    if (body)
    {   body->toHBuffer(buf, hgs);
    }
    buf->writebyte('}');
    buf->writenl();
}

void IfStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("if(");
    condition->toHBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    ifbody->toHBuffer(buf, hgs);
    if (elsebody)
    {   buf->writestring("else");
        buf->writenl();
        elsebody->toHBuffer(buf, hgs);
    }
}

void ConditionalStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    int error = 0;
    int inc = condition->inc;
    if (!inc)
    {
        unsigned errors = global.errors;
        global.gag++;
        inc = condition->include(NULL,NULL);
        if (errors != global.errors)
        {   error = 1;
            inc = 0;            
        }
        global.gag--;
        global.errors = errors;
    }

    if (!error || inc)
    {
        // Emit just conditional code (version and debug)
        if (inc == 1)
        {
            ifbody->toHBuffer(buf, hgs);
        }
	else
	{
            if (elsebody)
                elsebody->toHBuffer(buf, hgs);
        }
    }
    else
    {
        // Emit everything (iftype and static if).
        //  These can always be resolved by the symbol file end-user compiler
        OutBuffer ibuf, ebuf;
        ifbody->toHBuffer(&ibuf, hgs);
        if (elsebody)
        {
            OutBuffer tbuf;
            elsebody->toHBuffer(&tbuf, hgs);
            if (tbuf.offset)
            {   ebuf.writebyte('}');
                ebuf.writenl();
                ebuf.writestring("else");
                ebuf.writenl();
                ebuf.writebyte('{');
                ebuf.writenl();
                ebuf.write(&tbuf);
            }
        }
        if (ibuf.offset || ebuf.offset)
        {
            condition->toHBuffer(buf, hgs);
            buf->writenl();
            buf->writebyte('{');
            buf->writenl();
            if (ibuf.offset)
                buf->write(&ibuf);
            if (ebuf.offset)
                buf->write(&ebuf);
            buf->writebyte('}');
            buf->writenl();
        }
    }
}

void PragmaStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("PragmaStatement::toHBuffer()");
    buf->writenl();
}

void StaticAssertStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    sa->toHBuffer(buf, hgs);
}

void SwitchStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("switch(");
    condition->toHBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    if (body)
    {   if (!body->isScopeStatement())
        {   buf->writebyte('{');
            buf->writenl();
            buf->writebyte('}');
            buf->writenl();
        }
        else
        {
            body->toHBuffer(buf, hgs);
        }
    }
}

void CaseStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("case ");
    exp->toHBuffer(buf, hgs);
    buf->writebyte(':');
    buf->writenl();
    ScopeStatement *ss = statement->isScopeStatement();
    if (ss)
        statement->toHBuffer2(buf, hgs);
    else
        statement->toHBuffer(buf, hgs);
}

void DefaultStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    OutBuffer tbuf;
    ScopeStatement *ss = statement->isScopeStatement();
    if (ss)
        statement->toHBuffer2(&tbuf, hgs);
    else
        statement->toHBuffer(&tbuf, hgs);

    if (tbuf.offset)
    {   buf->writestring("default:");
        buf->writenl();
        buf->write(&tbuf);
    }
}

void GotoDefaultStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("goto default;");
    buf->writenl();
}

void GotoCaseStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("goto case");
    if (exp)
    {   buf->writebyte(' ');
        exp->toHBuffer(buf, hgs);
    }
    buf->writebyte(';');
    buf->writenl();
}

void SwitchErrorStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("SwitchErrorStatement::toHBuffer()");
    buf->writenl();
}

void ReturnStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("return ");
    if (exp)
	exp->toHBuffer(buf, hgs);
    buf->writeByte(';');
    buf->writenl();
}

void BreakStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("break;");
    buf->writenl();
}

void ContinueStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("continue");
    if (ident)
    {   buf->writebyte(' ');
        buf->writestring(ident->toChars());
    }
    buf->writebyte(';');
    buf->writenl();
}

void SynchronizedStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("synchronized");
    if (exp)
    {   buf->writebyte('(');
        exp->toHBuffer(buf, hgs);
        buf->writebyte(')');
    }
    if (body)
    {
        buf->writebyte(' ');
        body->toHBuffer(buf, hgs);
    }
}

void WithStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("with(");
    exp->toHBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    body->toHBuffer(buf, hgs);
}

void TryCatchStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("try");
    buf->writenl();
    if (body)
        body->toHBuffer(buf, hgs);
    int i;
    for (i = 0; i < catches->dim; i++)
    {
        Catch *c = (Catch *)catches->data[i];
        c->toHBuffer(buf, hgs);
    }
}

void Catch::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("catch");
    if (type)
    {   buf->writebyte('(');
	type->toHBuffer(buf, ident, hgs);
        buf->writebyte(')');
    }
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    handler->toHBuffer(buf, hgs);
    buf->writebyte('}');
    buf->writenl();
}

void TryFinallyStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (!body->isTryCatchStatement())
    {   buf->printf("try");
        buf->writenl();
    }
    //buf->writebyte('{');
    //buf->writenl();
    body->toHBuffer(buf, hgs);
    //buf->writebyte('}');
    //buf->writenl();
    buf->writestring("finally");
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    finalbody->toHBuffer(buf, hgs);
    buf->writeByte('}');
    buf->writenl();
}

void ThrowStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("throw ");
    exp->toHBuffer(buf, hgs);
    buf->writeByte(';');
    buf->writenl();
}

void VolatileStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("volatile");
    if (statement)
    {   if (statement->isScopeStatement())
            buf->writenl();
        else
            buf->writebyte(' ');
        statement->toHBuffer(buf, hgs);
    }
}

void GotoStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("goto ");
    //label->toHBuffer(buf, hgs);
    buf->writestring(ident->toChars());
    buf->writebyte(';');
    buf->writenl();
}

void LabelStatement::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    buf->writebyte(':');
    buf->writenl();
    if (statement)
        statement->toHBuffer(buf, hgs);
}

void StaticAssert::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(kind());
    buf->writeByte('(');
    exp->toHBuffer(buf, hgs);
    buf->writestring(");");
    buf->writenl();
}

void StructDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{   int i;

    buf->printf("%s %s", kind(), toChars());
    if (!members)
    {
	buf->writeByte(';');
	buf->writenl();
	return;
    }
    buf->writenl();
    buf->writeByte('{');
    buf->writenl();
    for (i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];

    //buf->writestring("    ");
	s->toHBuffer(buf, hgs);
    }
    buf->writeByte('}');
    buf->writenl();
}

char *TemplateDeclaration::toHChars(HdrGenState *hgs)
{
    OutBuffer buf;
    char *s;

    toHBuffer(&buf, hgs);
    s = buf.toChars();
    buf.data = NULL;
    return s;
}

void TemplateDeclaration::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    int i;

    hgs->tpltMember++;

    buf->writestring("template ");
    buf->writestring(ident->toChars());
    buf->writeByte('(');
    for (i = 0; i < parameters->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	if (i)
	    buf->writeByte(',');
        tp->toHBuffer(buf, hgs);
    }
    buf->writeByte(')');
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    for (i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (Dsymbol *)members->data[i];
        s->toHBuffer(buf, hgs);  // need to check ident here to replace built-in identifiers (i.e.: '_ctor')
    }
    buf->writebyte('}');
    buf->writenl();

    hgs->tpltMember--;
}

void TemplateTypeParameter::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    if (specType)
    {
	buf->writestring(" : ");
	specType->toHBuffer(buf, NULL, hgs);
    }
    if (defaultType)
    {
	buf->writestring(" = ");
	defaultType->toHBuffer(buf, NULL, hgs);
    }
}

void TemplateAliasParameter::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("alias ");
    buf->writestring(ident->toChars());
    if (specAliasT)
    {
	buf->writestring(" : ");
	specAliasT->toHBuffer(buf, NULL, hgs);
    }
    if (defaultAlias)
    {
	buf->writestring(" = ");
	defaultAlias->toHBuffer(buf, NULL, hgs);
    }
}

void TemplateValueParameter::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    valType->toHBuffer(buf, ident, hgs);
    if (specValue)
    {
	buf->writestring(" : ");
	specValue->toHBuffer(buf, hgs);
    }
    if (defaultValue)
    {
	buf->writestring(" = ");
	defaultValue->toHBuffer(buf, hgs);
    }
}

char *TemplateInstance::toHChars(HdrGenState *hgs)
{
    OutBuffer buf;
    char *s;

    toHBuffer(&buf, hgs);
    s = buf.toChars();
    buf.data = NULL;
    return s;
}

void TemplateInstance::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    // Don't emit instances
    if (!hgs->emitInst && this->inst)
        return;

    int i;

    for (i = 0; i < idents.dim; i++)
    {   Identifier *id = (Identifier *)idents.data[i];

    	if (i)
	    buf->writeByte('.');
	buf->writestring(id->toChars());
    }
    buf->writestring("!(");

    for (i = 0; i < tiargs->dim; i++)
    {
	if (i)
	    buf->writeByte(',');
	Object *oarg = (Object *)tiargs->data[i];
	Type *t = isType(oarg);
	Expression *e = isExpression(oarg);
	Dsymbol *s = isDsymbol(oarg);
	if (t)
	    t->toHBuffer(buf, NULL, hgs);
	else if (e)
	    e->toHBuffer(buf, hgs);
	else if (s)
	{
	    char *p = s->ident ? s->ident->toChars() : s->toChars();
	    buf->writestring(p);
	}
	else if (!oarg)
	{
	    buf->writestring("NULL");
	}
	else
	{
	    assert(0);
	}
    }
    buf->writeByte(')');
}

void TemplateMixin::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("mixin ");
    int i;
    for (i = 0; i < idents->dim; i++)
    {   Identifier *id = (Identifier *)idents->data[i];

    	if (i)
	    buf->writeByte('.');
	buf->writestring(id->toChars());
    }
    if (tiargs && tiargs->dim)
    {
        buf->writestring("!(");
        for (i = 0; i < tiargs->dim; i++)
        {   if (i)
                buf->writebyte(',');
	    Object *oarg = (Object *)tiargs->data[i];
	    Type *t = isType(oarg);
	    Expression *e = isExpression(oarg);
	    Dsymbol *s = isDsymbol(oarg);
	    if (t)
		t->toHBuffer(buf, NULL, hgs);
	    else if (e)
		e->toHBuffer(buf, hgs);
	    else if (s)
	    {
		char *p = s->ident ? s->ident->toChars() : s->toChars();
		buf->writestring(p);
	    }
	    else if (!oarg)
	    {
		buf->writestring("NULL");
	    }
	    else
	    {
		assert(0);
	    }
        }
        buf->writebyte(')');
    }
    else if (tdtypes.dim)
    {
        buf->writestring("!(");
        for (i = 0; i < tdtypes.dim; i++)
        {   if (i)
                buf->writebyte(',');
	    Object *oarg = (Object *)tdtypes.data[i];
	    Type *t = isType(oarg);
	    Expression *e = isExpression(oarg);
	    Dsymbol *s = isDsymbol(oarg);
	    if (t)
		t->toHBuffer(buf, NULL, hgs);
	    else if (e)
		e->toHBuffer(buf, hgs);
	    else if (s)
	    {
		char *p = s->ident ? s->ident->toChars() : s->toChars();
		buf->writestring(p);
	    }
	    else if (!oarg)
	    {
		buf->writestring("NULL");
	    }
	    else
	    {
		assert(0);
	    }
        }
        buf->writebyte(')');
    }
    if (tempdecl)
    {
        Identifier *tid = genIdent();
        int res = strcmp(ident->toChars(),tid->toChars());
        if (res)
        {   buf->writebyte(' ');
            buf->writestring(ident->toChars());
        }
    }
    buf->writebyte(';');
    buf->writenl();
}

void DebugSymbol::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

void VersionSymbol::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf);
}

/*************************************/

Type *TypeFunction::hdrSyntaxCopy()
{
    Type *treturn = NULL;
    if (next)
        treturn = next->syntaxCopy();
    Array *args = Argument::arraySyntaxCopy(arguments);
    Type *t = new TypeFunction(args, treturn, varargs, linkage);
    return t;
}

void FuncDeclaration::hdrSyntaxCopy(FuncDeclaration *f)
{
    // Initialize pointer back to original FuncDeclaration
    if (!hcopyof)
        hcopyof = this;

    // New copy points back to original
    f->hcopyof = hcopyof;

    // Syntax copy for header file
	if (!hbody)	    // Don't overwrite original
    {	if (fbody)   // Make copy for both old and new instances
		{   hbody = fbody->syntaxCopy();
			f->hbody = fbody->syntaxCopy();
		}
    }
    else    	    // Make copy of original for new instance
    {
		f->hbody = hbody->syntaxCopy();
    }

    if (!htype)
    {   TypeFunction *tf = (TypeFunction *)type;

        if (!tf)
        {   CtorDeclaration *cd = NULL;
            DtorDeclaration *dd = NULL;
            StaticCtorDeclaration *scd = NULL;
            StaticDtorDeclaration *sdd = NULL;
            NewDeclaration *nd = NULL;
            DeleteDeclaration *ld = NULL;
            if ((cd = isCtorDeclaration()))
                tf = new TypeFunction(cd->arguments,cd->type,cd->varargs,LINKd);
            else if ((dd = isDtorDeclaration()))
                tf = new TypeFunction(NULL,dd->type,NULL,LINKd);
            else if ((scd = isStaticCtorDeclaration()))
                tf = new TypeFunction(NULL,scd->type,NULL,LINKd);
            else if ((sdd = isStaticDtorDeclaration()))
                tf = new TypeFunction(NULL,sdd->type,NULL,LINKd);
            else if ((nd = isNewDeclaration()))
                tf = new TypeFunction(nd->arguments,nd->type,nd->varargs,LINKd);
            else if ((ld = isDeleteDeclaration()))
                tf = new TypeFunction(ld->arguments,ld->type,NULL,LINKd);
        }

        if (tf)
        {   htype = tf->hdrSyntaxCopy();
            f->htype = tf->hdrSyntaxCopy();
        }
    }
    else
    {
        f->htype = ((TypeFunction *)htype)->hdrSyntaxCopy();
    }

    if (!hrequire)
    {	if (frequire)
	{   hrequire = frequire->syntaxCopy();
	    f->hrequire = frequire->syntaxCopy();
	}
    }
    else
    {
	f->hrequire = hrequire->syntaxCopy();
    }

    if (!hensure)
    {	if (fensure)
	{   hensure = fensure->syntaxCopy();
	    f->hensure = fensure->syntaxCopy();
	}
    }
    else
    {
	f->hensure = hensure->syntaxCopy();
    }
}

/*************************************/

#endif // #ifdef _DH
