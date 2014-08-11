
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Dave Fladebo
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/hdrgen.c
 */

// Routines to emit header files

#define TEST_EMIT_ALL  0        // For Testing

#define LOG 0

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "rmem.h"

#include "id.h"
#include "init.h"

#include "attrib.h"
#include "cond.h"
#include "doc.h"
#include "enum.h"
#include "import.h"
#include "module.h"
#include "mtype.h"
#include "parse.h"
#include "scope.h"
#include "staticassert.h"
#include "target.h"
#include "template.h"
#include "utf.h"
#include "version.h"

#include "declaration.h"
#include "aggregate.h"
#include "expression.h"
#include "ctfe.h"
#include "statement.h"
#include "aliasthis.h"
#include "nspace.h"
#include "hdrgen.h"

void sizeToCBuffer(OutBuffer *buf, HdrGenState *hgs, Expression *e);
void toBufferShort(Type *t, OutBuffer *buf, HdrGenState *hgs);
void expToCBuffer(OutBuffer *buf, HdrGenState *hgs, Expression *e, PREC pr);
void toCBuffer(Module *m, OutBuffer *buf, HdrGenState *hgs);
void ObjectToCBuffer(OutBuffer *buf, HdrGenState *hgs, RootObject *oarg);

void genhdrfile(Module *m)
{
    OutBuffer hdrbufr;
    hdrbufr.doindent = 1;

    hdrbufr.printf("// D import file generated from '%s'", m->srcfile->toChars());
    hdrbufr.writenl();

    HdrGenState hgs;
    hgs.hdrgen = true;

    toCBuffer(m, &hdrbufr, &hgs);

    // Transfer image to file
    m->hdrfile->setbuffer(hdrbufr.data, hdrbufr.offset);
    hdrbufr.data = NULL;

    ensurePathToNameExists(Loc(), m->hdrfile->toChars());
    writeFile(m->loc, m->hdrfile);
}


void toCBuffer(Module *m, OutBuffer *buf, HdrGenState *hgs)
{
    if (m->md)
    {
        buf->writestring("module ");
        buf->writestring(m->md->toChars());
        buf->writeByte(';');
        buf->writenl();
    }

    for (size_t i = 0; i < m->members->dim; i++)
    {
        Dsymbol *s = (*m->members)[i];
        ::toCBuffer(s, buf, hgs);
    }
}

class PrettyPrintVisitor : public Visitor
{
public:
    OutBuffer *buf;
    HdrGenState *hgs;
    unsigned char modMask;

    PrettyPrintVisitor(OutBuffer *buf, HdrGenState *hgs)
        : buf(buf), hgs(hgs), modMask(0)
    {
    }

    void visit(Statement *s)
    {
        buf->printf("Statement::toCBuffer()");
        buf->writenl();
        assert(0);
    }

    void visit(ErrorStatement *s)
    {
        buf->printf("__error__");
        buf->writenl();
    }

    void visit(ExpStatement *s)
    {
        if (s->exp)
        {
            s->exp->accept(this);
            if (s->exp->op != TOKdeclaration)
            {
                buf->writeByte(';');
                if (!hgs->forStmtInit)
                    buf->writenl();
            }
        }
        else
        {
            buf->writeByte(';');
            if (!hgs->forStmtInit)
                buf->writenl();
        }
    }

    void visit(CompileStatement *s)
    {
        buf->writestring("mixin(");
        s->exp->accept(this);
        buf->writestring(");");
        if (!hgs->forStmtInit)
            buf->writenl();
    }

    void visit(CompoundStatement *s)
    {
        for (size_t i = 0; i < s->statements->dim; i++)
        {
            Statement *sx = (*s->statements)[i];
            if (sx)
                sx->accept(this);
        }
    }

    void visit(CompoundDeclarationStatement *s)
    {
        bool anywritten = false;
        for (size_t i = 0; i < s->statements->dim; i++)
        {
            Statement *sx = (*s->statements)[i];
            ExpStatement *ds;
            if (sx &&
                (ds = sx->isExpStatement()) != NULL &&
                ds->exp->op == TOKdeclaration)
            {
                DeclarationExp *de = (DeclarationExp *)ds->exp;
                Declaration *d = de->declaration->isDeclaration();
                assert(d);
                VarDeclaration *v = d->isVarDeclaration();
                if (v)
                {
                    /* This essentially copies the part of VarDeclaration::toCBuffer()
                     * that does not print the type.
                     * Should refactor this.
                     */
                    if (anywritten)
                    {
                        buf->writestring(", ");
                        buf->writestring(v->ident->toChars());
                    }
                    else
                    {
                        StorageClassDeclaration::stcToCBuffer(buf, v->storage_class);
                        if (v->type)
                            toCBuffer(v->type, buf, v->ident, hgs);
                        else
                            buf->writestring(v->ident->toChars());
                    }

                    if (v->init)
                    {
                        buf->writestring(" = ");
                        ExpInitializer *ie = v->init->isExpInitializer();
                        if (ie && (ie->exp->op == TOKconstruct || ie->exp->op == TOKblit))
                            ((AssignExp *)ie->exp)->e2->accept(this);
                        else
                            v->init->accept(this);
                    }
                }
                else
                    d->accept(this);
                anywritten = true;
            }
        }
        buf->writeByte(';');
        if (!hgs->forStmtInit)
            buf->writenl();
    }

    void visit(UnrolledLoopStatement *s)
    {
        buf->writestring("unrolled {");
        buf->writenl();
        buf->level++;

        for (size_t i = 0; i < s->statements->dim; i++)
        {
            Statement *sx = (*s->statements)[i];
            if (sx)
                sx->accept(this);
        }

        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    void visit(ScopeStatement *s)
    {
        buf->writeByte('{');
        buf->writenl();
        buf->level++;

        if (s->statement)
            s->statement->accept(this);

        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    void visit(WhileStatement *s)
    {
        buf->writestring("while (");
        s->condition->accept(this);
        buf->writeByte(')');
        buf->writenl();
        if (s->body)
            s->body->accept(this);
    }

    void visit(DoStatement *s)
    {
        buf->writestring("do");
        buf->writenl();
        if (s->body)
            s->body->accept(this);
        buf->writestring("while (");
        s->condition->accept(this);
        buf->writestring(");");
        buf->writenl();
    }

    void visit(ForStatement *s)
    {
        buf->writestring("for (");
        if (s->init)
        {
            hgs->forStmtInit++;
            s->init->accept(this);
            hgs->forStmtInit--;
        }
        else
            buf->writeByte(';');
        if (s->condition)
        {
            buf->writeByte(' ');
            s->condition->accept(this);
        }
        buf->writeByte(';');
        if (s->increment)
        {
            buf->writeByte(' ');
            s->increment->accept(this);
        }
        buf->writeByte(')');
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        s->body->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    void visit(ForeachStatement *s)
    {
        buf->writestring(Token::toChars(s->op));
        buf->writestring(" (");
        for (size_t i = 0; i < s->arguments->dim; i++)
        {
            Parameter *a = (*s->arguments)[i];
            if (i)
                buf->writestring(", ");
            if (a->storageClass & STCref)
                buf->writestring((char*)"ref ");
            if (a->type)
                toCBuffer(a->type, buf, a->ident, hgs);
            else
                buf->writestring(a->ident->toChars());
        }
        buf->writestring("; ");
        s->aggr->accept(this);
        buf->writeByte(')');
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        if (s->body)
            s->body->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    void visit(ForeachRangeStatement *s)
    {
        buf->writestring(Token::toChars(s->op));
        buf->writestring(" (");

        if (s->arg->type)
            toCBuffer(s->arg->type, buf, s->arg->ident, hgs);
        else
            buf->writestring(s->arg->ident->toChars());

        buf->writestring("; ");
        s->lwr->accept(this);
        buf->writestring(" .. ");
        s->upr->accept(this);
        buf->writeByte(')');
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        if (s->body)
            s->body->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    void visit(IfStatement *s)
    {
        buf->writestring("if (");
        if (s->arg)
        {
            if (s->arg->type)
                toCBuffer(s->arg->type, buf, s->arg->ident, hgs);
            else
            {
                buf->writestring("auto ");
                buf->writestring(s->arg->ident->toChars());
            }
            buf->writestring(" = ");
        }
        s->condition->accept(this);
        buf->writeByte(')');
        buf->writenl();
        if (!s->ifbody->isScopeStatement())
            buf->level++;
        s->ifbody->accept(this);
        if (!s->ifbody->isScopeStatement())
            buf->level--;
        if (s->elsebody)
        {
            buf->writestring("else");
            buf->writenl();
            if (!s->elsebody->isScopeStatement())
                buf->level++;
            s->elsebody->accept(this);
            if (!s->elsebody->isScopeStatement())
                buf->level--;
        }
    }

    void visit(ConditionalStatement *s)
    {
        s->condition->accept(this);
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        if (s->ifbody)
            s->ifbody->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
        if (s->elsebody)
        {
            buf->writestring("else");
            buf->writenl();
            buf->writeByte('{');
            buf->level++;
            buf->writenl();
            s->elsebody->accept(this);
            buf->level--;
            buf->writeByte('}');
            buf->writenl();
        }
        buf->writenl();
    }

    void visit(PragmaStatement *s)
    {
        buf->writestring("pragma (");
        buf->writestring(s->ident->toChars());
        if (s->args && s->args->dim)
        {
            buf->writestring(", ");
            argsToCBuffer(buf, s->args, hgs);
        }
        buf->writeByte(')');
        if (s->body)
        {
            buf->writenl();
            buf->writeByte('{');
            buf->writenl();
            buf->level++;

            s->body->accept(this);

            buf->level--;
            buf->writeByte('}');
            buf->writenl();
        }
        else
        {
            buf->writeByte(';');
            buf->writenl();
        }
    }

    void visit(StaticAssertStatement *s)
    {
        s->sa->accept(this);
    }

    void visit(SwitchStatement *s)
    {
        buf->writestring(s->isFinal ? "final switch (" : "switch (");
        s->condition->accept(this);
        buf->writeByte(')');
        buf->writenl();
        if (s->body)
        {
            if (!s->body->isScopeStatement())
            {
                buf->writeByte('{');
                buf->writenl();
                buf->level++;
                s->body->accept(this);
                buf->level--;
                buf->writeByte('}');
                buf->writenl();
            }
            else
            {
                s->body->accept(this);
            }
        }
    }

    void visit(CaseStatement *s)
    {
        buf->writestring("case ");
        s->exp->accept(this);
        buf->writeByte(':');
        buf->writenl();
        s->statement->accept(this);
    }

    void visit(CaseRangeStatement *s)
    {
        buf->writestring("case ");
        s->first->accept(this);
        buf->writestring(": .. case ");
        s->last->accept(this);
        buf->writeByte(':');
        buf->writenl();
        s->statement->accept(this);
    }

    void visit(DefaultStatement *s)
    {
        buf->writestring("default:");
        buf->writenl();
        s->statement->accept(this);
    }

    void visit(GotoDefaultStatement *s)
    {
        buf->writestring("goto default;");
        buf->writenl();
    }

    void visit(GotoCaseStatement *s)
    {
        buf->writestring("goto case");
        if (s->exp)
        {
            buf->writeByte(' ');
            s->exp->accept(this);
        }
        buf->writeByte(';');
        buf->writenl();
    }

    void visit(SwitchErrorStatement *s)
    {
        buf->writestring("SwitchErrorStatement::toCBuffer()");
        buf->writenl();
    }

    void visit(ReturnStatement *s)
    {
        buf->printf("return ");
        if (s->exp)
            s->exp->accept(this);
        buf->writeByte(';');
        buf->writenl();
    }

    void visit(BreakStatement *s)
    {
        buf->writestring("break");
        if (s->ident)
        {
            buf->writeByte(' ');
            buf->writestring(s->ident->toChars());
        }
        buf->writeByte(';');
        buf->writenl();
    }

    void visit(ContinueStatement *s)
    {
        buf->writestring("continue");
        if (s->ident)
        {
            buf->writeByte(' ');
            buf->writestring(s->ident->toChars());
        }
        buf->writeByte(';');
        buf->writenl();
    }

    void visit(SynchronizedStatement *s)
    {
        buf->writestring("synchronized");
        if (s->exp)
        {
            buf->writeByte('(');
            s->exp->accept(this);
            buf->writeByte(')');
        }
        if (s->body)
        {
            buf->writeByte(' ');
            s->body->accept(this);
        }
    }

    void visit(WithStatement *s)
    {
        buf->writestring("with (");
        s->exp->accept(this);
        buf->writestring(")");
        buf->writenl();
        if (s->body)
            s->body->accept(this);
    }

    void visit(TryCatchStatement *s)
    {
        buf->writestring("try");
        buf->writenl();
        if (s->body)
            s->body->accept(this);
        for (size_t i = 0; i < s->catches->dim; i++)
        {
            Catch *c = (*s->catches)[i];
            visit(c);
        }
    }

    void visit(TryFinallyStatement *s)
    {
        buf->writestring("try");
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        s->body->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
        buf->writestring("finally");
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        s->finalbody->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    void visit(OnScopeStatement *s)
    {
        buf->writestring(Token::toChars(s->tok));
        buf->writeByte(' ');
        s->statement->accept(this);
    }

    void visit(ThrowStatement *s)
    {
        buf->printf("throw ");
        s->exp->accept(this);
        buf->writeByte(';');
        buf->writenl();
    }

    void visit(DebugStatement *s)
    {
        if (s->statement)
        {
            s->statement->accept(this);
        }
    }

    void visit(GotoStatement *s)
    {
        buf->writestring("goto ");
        buf->writestring(s->ident->toChars());
        buf->writeByte(';');
        buf->writenl();
    }

    void visit(LabelStatement *s)
    {
        buf->writestring(s->ident->toChars());
        buf->writeByte(':');
        buf->writenl();
        if (s->statement)
            s->statement->accept(this);
    }

    void visit(AsmStatement *s)
    {
        buf->writestring("asm { ");
        Token *t = s->tokens;
        buf->level++;
        while (t)
        {
            buf->writestring(t->toChars());
            if (t->next                         &&
                t->value != TOKmin              &&
                t->value != TOKcomma            &&
                t->next->value != TOKcomma      &&
                t->value != TOKlbracket         &&
                t->next->value != TOKlbracket   &&
                t->next->value != TOKrbracket   &&
                t->value != TOKlparen           &&
                t->next->value != TOKlparen     &&
                t->next->value != TOKrparen     &&
                t->value != TOKdot              &&
                t->next->value != TOKdot)
            {
                buf->writeByte(' ');
            }
            t = t->next;
        }
        buf->level--;
        buf->writestring("; }");
        buf->writenl();
    }

    void visit(ImportStatement *s)
    {
        for (size_t i = 0; i < s->imports->dim; i++)
        {
            Dsymbol *imp = (*s->imports)[i];
            imp->accept(this);
        }
    }

    void visit(Catch *c)
    {
        buf->writestring("catch");
        if (c->type)
        {
            buf->writeByte('(');
            toCBuffer(c->type, buf, c->ident, hgs);
            buf->writeByte(')');
        }
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        if (c->handler)
            c->handler->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    ////////////////////////////////////////////////////////////////////////////

    void visitWithMask(Type *t, unsigned char mod)
    {
        unsigned char save = modMask;
        modMask = mod;

        // Tuples and functions don't use the type constructor syntax
        if (modMask == t->mod ||
            t->ty == Tfunction ||
            t->ty == Ttuple)
        {
            t->accept(this);
        }
        else
        {
            unsigned char m = t->mod & ~(t->mod & modMask);
            if (m & MODshared)
            {
                MODtoBuffer(buf, MODshared);
                buf->writeByte('(');
            }
            if (m & MODwild)
            {
                MODtoBuffer(buf, MODwild);
                buf->writeByte('(');
            }
            if (m & (MODconst | MODimmutable))
            {
                MODtoBuffer(buf, m & (MODconst | MODimmutable));
                buf->writeByte('(');
            }

            t->accept(this);

            if (m & (MODconst | MODimmutable))
                buf->writeByte(')');
            if (m & MODwild)
                buf->writeByte(')');
            if (m & MODshared)
                buf->writeByte(')');
        }
        modMask = save;
    }

    void visit(Type *t)
    {
        printf("t = %p, ty = %d\n", t, t->ty);
        assert(0);
    }

    void visit(TypeBasic *t)
    {
        //printf("TypeBasic::toCBuffer2(modMask = %d, t->mod = %d)\n", modMask, t->mod);
        buf->writestring(t->dstring);
    }

    void visit(TypeVector *t)
    {
        //printf("TypeVector::toCBuffer2(modMask = %d, t->mod = %d)\n", modMask, t->mod);
        buf->writestring("__vector(");
        visitWithMask(t->basetype, t->mod);
        buf->writestring(")");
    }

    void visit(TypeSArray *t)
    {
        visitWithMask(t->next, t->mod);
        buf->writeByte('[');
        sizeToCBuffer(buf, hgs, t->dim);
        buf->writeByte(']');
    }

    void visit(TypeDArray *t)
    {
        if (t->equals(t->tstring))
            buf->writestring("string");
        else
        {
            visitWithMask(t->next, t->mod);
            buf->writestring("[]");
        }
    }

    void visit(TypeAArray *t)
    {
        visitWithMask(t->next, t->mod);
        buf->writeByte('[');
        visitWithMask(t->index, 0);
        buf->writeByte(']');
    }

    void visit(TypePointer *t)
    {
        //printf("TypePointer::toCBuffer2() next = %d\n", t->next->ty);
        visitWithMask(t->next, t->mod);
        if (t->next->ty != Tfunction)
            buf->writeByte('*');
    }

    void visit(TypeReference *t)
    {
        visitWithMask(t->next, t->mod);
        buf->writeByte('&');
    }

    void visit(TypeFunction *t)
    {
        //printf("TypeFunction::toCBuffer2() t = %p, ref = %d\n", t, t->isref);
        if (t->inuse)
        {
            t->inuse = 2;              // flag error to caller
            return;
        }
        t->inuse++;
        visitFuncIdent(t, "function");
        t->inuse--;
    }

    // callback for TypeFunction::attributesApply, prepends spaces
    struct PreAppendStrings
    {
        OutBuffer *buf;

        static int fp(void *param, const char *str)
        {
            PreAppendStrings *p = (PreAppendStrings *)param;
            p->buf->writeByte(' ');
            p->buf->writestring(str);
            return 0;
        }
    };

    void visitFuncIdent(TypeFunction *t, const char *ident)
    {
        if (t->linkage > LINKd && hgs->ddoc != 1 && !hgs->hdrgen)
        {
            linkageToBuffer(buf, t->linkage);
            buf->writeByte(' ');
        }

        if (t->next)
        {
            visitWithMask(t->next, 0);
            buf->writeByte(' ');
        }
        buf->writestring(ident);
        parametersToCBuffer(buf, hgs, t->parameters, t->varargs);

        /* Use postfix style for attributes
         */
        if (modMask != t->mod)
        {
            t->modToBuffer(buf);
        }

        PreAppendStrings pas;
        pas.buf = buf;
        t->attributesApply(&pas, &PreAppendStrings::fp);
    }

    void visit(TypeDelegate *t)
    {
        visitFuncIdent((TypeFunction *)t->next, "delegate");
    }

    void visitTypeQualifiedHelper(TypeQualified *t)
    {
        for (size_t i = 0; i < t->idents.dim; i++)
        {
            RootObject *id = t->idents[i];
            buf->writeByte('.');

            if (id->dyncast() == DYNCAST_DSYMBOL)
            {
                TemplateInstance *ti = (TemplateInstance *)id;
                ti->accept(this);
            }
            else
                buf->writestring(id->toChars());
        }
    }

    void visit(TypeIdentifier *t)
    {
        buf->writestring(t->ident->toChars());
        visitTypeQualifiedHelper(t);
    }

    void visit(TypeInstance *t)
    {
        t->tempinst->accept(this);
        visitTypeQualifiedHelper(t);
    }

    void visit(TypeTypeof *t)
    {
        buf->writestring("typeof(");
        t->exp->accept(this);
        buf->writeByte(')');
        visitTypeQualifiedHelper(t);
    }

    void visit(TypeReturn *t)
    {
        buf->writestring("typeof(return)");
        visitTypeQualifiedHelper(t);
    }

    void visit(TypeEnum *t)
    {
        buf->writestring(t->sym->toChars());
    }

    void visit(TypeTypedef *t)
    {
        //printf("TypeTypedef::toCBuffer2() '%s'\n", t->sym->toChars());
        buf->writestring(t->sym->toChars());
    }

    void visit(TypeStruct *t)
    {
        TemplateInstance *ti = t->sym->parent->isTemplateInstance();
        if (ti && ti->toAlias() == t->sym)
            buf->writestring(hgs->fullQual ? ti->toPrettyChars() : ti->toChars());
        else
            buf->writestring(hgs->fullQual ? t->sym->toPrettyChars() : t->sym->toChars());
    }

    void visit(TypeClass *t)
    {
        TemplateInstance *ti = t->sym->parent->isTemplateInstance();
        if (ti && ti->toAlias() == t->sym)
            buf->writestring(hgs->fullQual ? ti->toPrettyChars() : ti->toChars());
        else
            buf->writestring(hgs->fullQual ? t->sym->toPrettyChars() : t->sym->toChars());
    }

    void visit(TypeTuple *t)
    {
        parametersToCBuffer(buf, hgs, t->arguments, 0);
    }

    void visit(TypeSlice *t)
    {
        visitWithMask(t->next, t->mod);

        buf->writeByte('[');
        sizeToCBuffer(buf, hgs, t->lwr);
        buf->writestring(" .. ");
        sizeToCBuffer(buf, hgs, t->upr);
        buf->writeByte(']');
    }

    void visit(TypeNull *t)
    {
        buf->writestring("typeof(null)");
    }

    ////////////////////////////////////////////////////////////////////////////

    void visit(Dsymbol *s)
    {
        buf->writestring(s->toChars());
    }

    void visit(StaticAssert *s)
    {
        buf->writestring(s->kind());
        buf->writeByte('(');
        s->exp->accept(this);
        if (s->msg)
        {
            buf->writestring(", ");
            s->msg->accept(this);
        }
        buf->writestring(");");
        buf->writenl();
    }

    void visit(DebugSymbol *s)
    {
        buf->writestring("debug = ");
        if (s->ident)
            buf->writestring(s->ident->toChars());
        else
            buf->printf("%u", s->level);
        buf->writestring(";");
        buf->writenl();
    }

    void visit(VersionSymbol *s)
    {
        buf->writestring("version = ");
        if (s->ident)
            buf->writestring(s->ident->toChars());
        else
            buf->printf("%u", s->level);
        buf->writestring(";");
        buf->writenl();
    }

    void visit(EnumMember *em)
    {
        if (em->type)
            ::toCBuffer(em->type, buf, em->ident, hgs);
        else
            buf->writestring(em->ident->toChars());
        if (em->value)
        {
            buf->writestring(" = ");
            em->value->accept(this);
        }
    }

    void visit(Import *imp)
    {
        if (hgs->hdrgen && imp->id == Id::object)
            return;         // object is imported by default

        if (imp->isstatic)
            buf->writestring("static ");
        buf->writestring("import ");
        if (imp->aliasId)
        {
            buf->printf("%s = ", imp->aliasId->toChars());
        }
        if (imp->packages && imp->packages->dim)
        {
            for (size_t i = 0; i < imp->packages->dim; i++)
            {
                Identifier *pid = (*imp->packages)[i];
                buf->printf("%s.", pid->toChars());
            }
        }
        buf->printf("%s", imp->id->toChars());
        if (imp->names.dim)
        {
            buf->writestring(" : ");
            for (size_t i = 0; i < imp->names.dim; i++)
            {
                if (i)
                    buf->writestring(", ");

                Identifier *name = imp->names[i];
                Identifier *alias = imp->aliases[i];
                if (alias)
                    buf->printf("%s = %s", alias->toChars(), name->toChars());
                else
                    buf->printf("%s", name->toChars());
            }
        }
        buf->printf(";");
        buf->writenl();
    }

    void visit(AliasThis *d)
    {
        buf->writestring("alias ");
        buf->writestring(d->ident->toChars());
        buf->writestring(" this;\n");
    }

    void visit(AttribDeclaration *d)
    {
        if (!d->decl)
        {
            buf->writeByte(';');
            buf->writenl();
            return;
        }

        if (d->decl->dim == 0)
            buf->writestring("{}");
        else if (hgs->hdrgen && d->decl->dim == 1 && (*d->decl)[0]->isUnitTestDeclaration())
        {
            // hack for bugzilla 8081
            buf->writestring("{}");
        }
        else if (d->decl->dim == 1)
            ((*d->decl)[0])->accept(this);
        else
        {
            buf->writenl();
            buf->writeByte('{');
            buf->writenl();
            buf->level++;
            for (size_t i = 0; i < d->decl->dim; i++)
                (*d->decl)[i]->accept(this);
            buf->level--;
            buf->writeByte('}');
        }
        buf->writenl();
    }

    void visit(StorageClassDeclaration *d)
    {
        StorageClassDeclaration::stcToCBuffer(buf, d->stc);
        visit((AttribDeclaration *)d);
    }

    void visit(DeprecatedDeclaration *d)
    {
        buf->writestring("deprecated(");
        d->msg->accept(this);
        buf->writestring(") ");
        visit((AttribDeclaration *)d);
    }

    void visit(LinkDeclaration *d)
    {
        const char *p;

        switch (d->linkage)
        {
            case LINKd:             p = "D";                break;
            case LINKc:             p = "C";                break;
            case LINKcpp:           p = "C++";              break;
            case LINKwindows:       p = "Windows";          break;
            case LINKpascal:        p = "Pascal";           break;
            default:
                assert(0);
                break;
        }
        buf->writestring("extern (");
        buf->writestring(p);
        buf->writestring(") ");
        visit((AttribDeclaration *)d);
    }

    void visit(ProtDeclaration *d)
    {
        protectionToBuffer(buf, d->protection);
        buf->writeByte(' ');
        visit((AttribDeclaration *)d);
    }

    void visit(AlignDeclaration *d)
    {
        if (d->salign == STRUCTALIGN_DEFAULT)
            buf->printf("align");
        else
            buf->printf("align (%d)", d->salign);
        visit((AttribDeclaration *)d);
    }

    void visit(AnonDeclaration *d)
    {
        buf->printf(d->isunion ? "union" : "struct");
        buf->writenl();
        buf->writestring("{");
        buf->writenl();
        buf->level++;
        if (d->decl)
        {
            for (size_t i = 0; i < d->decl->dim; i++)
                (*d->decl)[i]->accept(this);
        }
        buf->level--;
        buf->writestring("}");
        buf->writenl();
    }

    void visit(PragmaDeclaration *d)
    {
        buf->printf("pragma (%s", d->ident->toChars());
        if (d->args && d->args->dim)
        {
            buf->writestring(", ");
            argsToCBuffer(buf, d->args, hgs);
        }
        buf->writeByte(')');
        visit((AttribDeclaration *)d);
    }

    void visit(ConditionalDeclaration *d)
    {
        d->condition->accept(this);
        if (d->decl || d->elsedecl)
        {
            buf->writenl();
            buf->writeByte('{');
            buf->writenl();
            buf->level++;
            if (d->decl)
            {
                for (size_t i = 0; i < d->decl->dim; i++)
                    (*d->decl)[i]->accept(this);
            }
            buf->level--;
            buf->writeByte('}');
            if (d->elsedecl)
            {
                buf->writenl();
                buf->writestring("else");
                buf->writenl();
                buf->writeByte('{');
                buf->writenl();
                buf->level++;
                for (size_t i = 0; i < d->elsedecl->dim; i++)
                    (*d->elsedecl)[i]->accept(this);
                buf->level--;
                buf->writeByte('}');
            }
        }
        else
            buf->writeByte(':');
        buf->writenl();
    }

    void visit(CompileDeclaration *d)
    {
        buf->writestring("mixin(");
        d->exp->accept(this);
        buf->writestring(");");
        buf->writenl();
    }

    void visit(UserAttributeDeclaration *d)
    {
        buf->writestring("@(");
        argsToCBuffer(buf, d->atts, hgs);
        buf->writeByte(')');
        visit((AttribDeclaration *)d);
    }

    void visit(TemplateDeclaration *d)
    {
    #if 0 // Should handle template functions for doc generation
        if (onemember && onemember->isFuncDeclaration())
            buf->writestring("foo ");
    #endif
        if (hgs->hdrgen && d->members && d->members->dim == 1)
        {
            Dsymbol *s1 = (*d->members)[0];

            FuncDeclaration *fd = s1->isFuncDeclaration();
            if (fd && fd->type && fd->type->ty == Tfunction && fd->ident == d->ident)
            {
                StorageClassDeclaration::stcToCBuffer(buf, fd->storage_class);
                functionToBufferFull((TypeFunction *)fd->type, buf, d->ident, hgs, d);

                if (d->constraint)
                {
                    buf->writestring(" if (");
                    d->constraint->accept(this);
                    buf->writeByte(')');
                }

                hgs->tpltMember++;
                bodyToCBuffer(fd);
                hgs->tpltMember--;
                return;
            }

            AggregateDeclaration *ad = s1->isAggregateDeclaration();
            if (ad)
            {
                buf->writestring(ad->kind());
                buf->writeByte(' ');
                buf->writestring(ad->ident->toChars());
                buf->writeByte('(');
                for (size_t i = 0; i < d->parameters->dim; i++)
                {
                    TemplateParameter *tp = (*d->parameters)[i];
                    if (hgs->ddoc)
                        tp = (*d->origParameters)[i];
                    if (i)
                        buf->writestring(", ");
                    tp->accept(this);
                }
                buf->writeByte(')');

                if (d->constraint)
                {
                    buf->writestring(" if (");
                    d->constraint->accept(this);
                    buf->writeByte(')');
                }

                 ClassDeclaration *cd = ad->isClassDeclaration();
                if (cd && cd->baseclasses->dim)
                {
                    buf->writestring(" : ");
                    for (size_t i = 0; i < cd->baseclasses->dim; i++)
                    {
                        BaseClass *b = (*cd->baseclasses)[i];
                        if (i)
                            buf->writestring(", ");
                        ::toCBuffer(b->type, buf, NULL, hgs);
                    }
                }

                hgs->tpltMember++;
                if (ad->members)
                {
                    buf->writenl();
                    buf->writeByte('{');
                    buf->writenl();
                    buf->level++;
                    for (size_t i = 0; i < ad->members->dim; i++)
                        (*ad->members)[i]->accept(this);
                    buf->level--;
                    buf->writestring("}");
                }
                else
                    buf->writeByte(';');
                buf->writenl();
                hgs->tpltMember--;
                return;
            }
        }

        if (hgs->ddoc)
            buf->writestring(d->kind());
        else
            buf->writestring("template");
        buf->writeByte(' ');
        buf->writestring(d->ident->toChars());
        buf->writeByte('(');
        for (size_t i = 0; i < d->parameters->dim; i++)
        {
            TemplateParameter *tp = (*d->parameters)[i];
            if (hgs->ddoc)
                tp = (*d->origParameters)[i];
            if (i)
                buf->writestring(", ");
            tp->accept(this);
        }
        buf->writeByte(')');
        if (d->constraint)
        {
            buf->writestring(" if (");
            d->constraint->accept(this);
            buf->writeByte(')');
        }

        if (hgs->hdrgen)
        {
            hgs->tpltMember++;
            buf->writenl();
            buf->writeByte('{');
            buf->writenl();
            buf->level++;
            for (size_t i = 0; i < d->members->dim; i++)
                (*d->members)[i]->accept(this);
            buf->level--;
            buf->writeByte('}');
            buf->writenl();
            hgs->tpltMember--;
        }
    }

    void visit(TemplateInstance *ti)
    {
        buf->writestring(ti->name->toChars());
        toCBufferTiargs(ti);
    }

    void visit(TemplateMixin *tm)
    {
        buf->writestring("mixin ");

        ::toCBuffer(tm->tqual, buf, NULL, hgs);
        toCBufferTiargs(tm);

        if (tm->ident && memcmp(tm->ident->string, "__mixin", 7) != 0)
        {
            buf->writeByte(' ');
            buf->writestring(tm->ident->toChars());
        }
        buf->writeByte(';');
        buf->writenl();
    }

    void toCBufferTiargs(TemplateInstance *ti)
    {
        buf->writeByte('!');
        if (ti->nest)
        {
            buf->writestring("(...)");
            return;
        }
        if (!ti->tiargs)
        {
            buf->writestring("()");
            return;
        }

        if (ti->tiargs->dim == 1)
        {
            RootObject *oarg = (*ti->tiargs)[0];
            if (Type *t = isType(oarg))
            {
                if (t->equals(Type::tstring) ||
                    t->mod == 0 &&
                    (t->isTypeBasic() ||
                     t->ty == Tident && ((TypeIdentifier *)t)->idents.dim == 0))
                {
                    buf->writestring(t->toChars());
                    return;
                }
            }
            else if (Expression *e = isExpression(oarg))
            {
                if (e->op == TOKint64 ||
                    e->op == TOKfloat64 ||
                    e->op == TOKnull ||
                    e->op == TOKstring ||
                    e->op == TOKthis)
                {
                    buf->writestring(e->toChars());
                    return;
                }
            }
        }
        buf->writeByte('(');
        ti->nest++;
        for (size_t i = 0; i < ti->tiargs->dim; i++)
        {
            if (i)
                buf->writestring(", ");
            RootObject *oarg = (*ti->tiargs)[i];
            ObjectToCBuffer(buf, hgs, oarg);
        }
        ti->nest--;
        buf->writeByte(')');
    }

    void visit(EnumDeclaration *d)
    {
        buf->writestring("enum ");
        if (d->ident)
        {
            buf->writestring(d->ident->toChars());
            buf->writeByte(' ');
        }
        if (d->memtype)
        {
            buf->writestring(": ");
            ::toCBuffer(d->memtype, buf, NULL, hgs);
        }
        if (!d->members)
        {
            buf->writeByte(';');
            buf->writenl();
            return;
        }
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        for (size_t i = 0; i < d->members->dim; i++)
        {
            EnumMember *em = (*d->members)[i]->isEnumMember();
            if (!em)
                continue;
            em->accept(this);
            buf->writeByte(',');
            buf->writenl();
        }
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    void visit(Nspace *d)
    {
        buf->writestring("extern (C++, ");
        buf->writestring(d->ident->string);
        buf->writeByte(')');
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        for (size_t i = 0; i < d->members->dim; i++)
            (*d->members)[i]->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    void visit(StructDeclaration *d)
    {
        buf->printf("%s ", d->kind());
        if (!d->isAnonymous())
            buf->writestring(d->toChars());
        if (!d->members)
        {
            buf->writeByte(';');
            buf->writenl();
            return;
        }
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        for (size_t i = 0; i < d->members->dim; i++)
            (*d->members)[i]->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }

    void visit(ClassDeclaration *d)
    {
        if (!d->isAnonymous())
        {
            buf->printf("%s ", d->kind());
            buf->writestring(d->toChars());
            if (d->baseclasses->dim)
                buf->writestring(" : ");
        }
        for (size_t i = 0; i < d->baseclasses->dim; i++)
        {
            if (i)
                buf->writestring(", ");
            (*d->baseclasses)[i]->type->accept(this);
        }
        if (d->members)
        {
            buf->writenl();
            buf->writeByte('{');
            buf->writenl();
            buf->level++;
            for (size_t i = 0; i < d->members->dim; i++)
                (*d->members)[i]->accept(this);
            buf->level--;
            buf->writestring("}");
        }
        else
            buf->writeByte(';');
        buf->writenl();
    }

    void visit(TypedefDeclaration *d)
    {
        buf->writestring("typedef ");
        ::toCBuffer(d->basetype, buf, d->ident, hgs);
        if (d->init)
        {
            buf->writestring(" = ");
            d->init->accept(this);
        }
        buf->writeByte(';');
        buf->writenl();
    }

    void visit(AliasDeclaration *d)
    {
        buf->writestring("alias ");
        if (d->aliassym)
        {
            d->aliassym->accept(this);
            buf->writeByte(' ');
            buf->writestring(d->ident->toChars());
        }
        else
            ::toCBuffer(d->type, buf, d->ident, hgs);
        buf->writeByte(';');
        buf->writenl();
    }

    void visit(VarDeclaration *d)
    {
        StorageClassDeclaration::stcToCBuffer(buf, d->storage_class);

        /* If changing, be sure and fix CompoundDeclarationStatement::toCBuffer()
         * too.
         */
        if (d->type)
            ::toCBuffer(d->type, buf, d->ident, hgs);
        else
            buf->writestring(d->ident->toChars());
        if (d->init)
        {
            buf->writestring(" = ");
            ExpInitializer *ie = d->init->isExpInitializer();
            if (ie && (ie->exp->op == TOKconstruct || ie->exp->op == TOKblit))
                ((AssignExp *)ie->exp)->e2->accept(this);
            else
                d->init->accept(this);
        }
        buf->writeByte(';');
        buf->writenl();
    }

    void visit(FuncDeclaration *f)
    {
        //printf("FuncDeclaration::toCBuffer() '%s'\n", toChars());

        StorageClassDeclaration::stcToCBuffer(buf, f->storage_class);
        ::toCBuffer(f->type, buf, f->ident, hgs);
        if (hgs->hdrgen == 1)
        {
            if (f->storage_class & STCauto)
            {
                hgs->autoMember++;
                bodyToCBuffer(f);
                hgs->autoMember--;
            }
            else if (hgs->tpltMember == 0 && !global.params.useInline)
                buf->writestring(";");
            else
                bodyToCBuffer(f);
        }
        else
            bodyToCBuffer(f);
        buf->writenl();
    }

    void bodyToCBuffer(FuncDeclaration *f)
    {
        if (!f->fbody || (hgs->hdrgen && !global.params.useInline && !hgs->autoMember && !hgs->tpltMember))
        {
            buf->writeByte(';');
            buf->writenl();
            return;
        }

        int savetlpt = hgs->tpltMember;
        int saveauto = hgs->autoMember;
        hgs->tpltMember = 0;
        hgs->autoMember = 0;

        buf->writenl();

        // in{}
        if (f->frequire)
        {
            buf->writestring("in");
            buf->writenl();
            f->frequire->accept(this);
        }

        // out{}
        if (f->fensure)
        {
            buf->writestring("out");
            if (f->outId)
            {
                buf->writeByte('(');
                buf->writestring(f->outId->toChars());
                buf->writeByte(')');
            }
            buf->writenl();
            f->fensure->accept(this);
        }

        if (f->frequire || f->fensure)
        {
            buf->writestring("body");
            buf->writenl();
        }

        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        f->fbody->accept(this);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();

        hgs->tpltMember = savetlpt;
        hgs->autoMember = saveauto;
    }

    void visit(FuncLiteralDeclaration *f)
    {
        if (f->type->ty == Terror)
        {
            buf->writestring("__error");
            return;
        }

        if (f->tok != TOKreserved)
        {
            buf->writestring(f->kind());
            buf->writeByte(' ');
        }

        TypeFunction *tf = (TypeFunction *)f->type;
        // Don't print tf->mod, tf->trust, and tf->linkage
        if (!f->inferRetType && tf->next)
            toBufferShort(tf->next, buf, hgs);
        parametersToCBuffer(buf, hgs, tf->parameters, tf->varargs);

        CompoundStatement *cs = f->fbody->isCompoundStatement();
        Statement *s1;
        if (f->semanticRun >= PASSsemantic3done && cs)
        {
            s1 = (*cs->statements)[cs->statements->dim - 1];
        }
        else
            s1 = !cs ? f->fbody : NULL;
        ReturnStatement *rs = s1 ? s1->isReturnStatement() : NULL;
        if (rs && rs->exp)
        {
            buf->writestring(" => ");
            rs->exp->accept(this);
        }
        else
        {
            hgs->tpltMember++;
            bodyToCBuffer(f);
            hgs->tpltMember--;
        }
    }

    void visit(PostBlitDeclaration *d)
    {
        buf->writestring("this(this)");
        bodyToCBuffer(d);
    }

    void visit(DtorDeclaration *d)
    {
        buf->writestring("~this()");
        bodyToCBuffer(d);
    }

    void visit(StaticCtorDeclaration *d)
    {
        if (d->isSharedStaticCtorDeclaration())
            buf->writestring("shared ");
        if (hgs->hdrgen && !hgs->tpltMember)
        {
            buf->writestring("static this();");
            buf->writenl();
            return;
        }
        buf->writestring("static this()");
        bodyToCBuffer(d);
    }

    void visit(StaticDtorDeclaration *d)
    {
        if (hgs->hdrgen)
            return;
        if (d->isSharedStaticDtorDeclaration())
            buf->writestring("shared ");
        buf->writestring("static ~this()");
        bodyToCBuffer(d);
    }

    void visit(InvariantDeclaration *d)
    {
        if (hgs->hdrgen)
            return;
        buf->writestring("invariant");
        bodyToCBuffer(d);
    }

    void visit(UnitTestDeclaration *d)
    {
        if (hgs->hdrgen)
            return;
        buf->writestring("unittest");
        bodyToCBuffer(d);
    }

    void visit(NewDeclaration *d)
    {
        buf->writestring("new");
        parametersToCBuffer(buf, hgs, d->arguments, d->varargs);
        bodyToCBuffer(d);
    }

    void visit(DeleteDeclaration *d)
    {
        buf->writestring("delete");
        parametersToCBuffer(buf, hgs, d->arguments, 0);
        bodyToCBuffer(d);
    }

    ////////////////////////////////////////////////////////////////////////////

    void visit(ErrorInitializer *iz)
    {
        buf->writestring("__error__");
    }

    void visit(VoidInitializer *iz)
    {
        buf->writestring("void");
    }

    void visit(StructInitializer *si)
    {
        //printf("StructInitializer::toCBuffer()\n");
        buf->writeByte('{');
        for (size_t i = 0; i < si->field.dim; i++)
        {
            if (i)
                buf->writestring(", ");
            if (Identifier *id = si->field[i])
            {
                buf->writestring(id->toChars());
                buf->writeByte(':');
            }
            if (Initializer *iz = si->value[i])
                iz->accept(this);
        }
        buf->writeByte('}');
    }

    void visit(ArrayInitializer *ai)
    {
        buf->writeByte('[');
        for (size_t i = 0; i < ai->index.dim; i++)
        {
            if (i)
                buf->writestring(", ");
            if (Expression *ex = ai->index[i])
            {
                ex->accept(this);
                buf->writeByte(':');
            }
            if (Initializer *iz = ai->value[i])
                iz->accept(this);
        }
        buf->writeByte(']');
    }

    void visit(ExpInitializer *ei)
    {
        ei->exp->accept(this);
    }

    ////////////////////////////////////////////////////////////////////////////

    void visit(Expression *e)
    {
        buf->writestring(Token::toChars(e->op));
    }

    void visit(IntegerExp *e)
    {
        dinteger_t v = e->toInteger();

        if (e->type)
        {
            Type *t = e->type;
        L1:
            switch (t->ty)
            {
                case Tenum:
                {
                    TypeEnum *te = (TypeEnum *)t;
                    buf->printf("cast(%s)", te->sym->toChars());
                    t = te->sym->memtype;
                    goto L1;
                }

                case Ttypedef:
                {
                    TypeTypedef *tt = (TypeTypedef *)t;
                    buf->printf("cast(%s)", tt->sym->toChars());
                    t = tt->sym->basetype;
                    goto L1;
                }

                case Twchar:        // BUG: need to cast(wchar)
                case Tdchar:        // BUG: need to cast(dchar)
                    if ((uinteger_t)v > 0xFF)
                    {
                        buf->printf("'\\U%08x'", v);
                        break;
                    }
                case Tchar:
                {
                    size_t o = buf->offset;
                    if (v == '\'')
                        buf->writestring("'\\''");
                    else if (isprint((int)v) && v != '\\')
                        buf->printf("'%c'", (int)v);
                    else
                        buf->printf("'\\x%02x'", (int)v);
                    if (hgs->ddoc)
                        escapeDdocString(buf, o);
                    break;
                }

                case Tint8:
                    buf->writestring("cast(byte)");
                    goto L2;

                case Tint16:
                    buf->writestring("cast(short)");
                    goto L2;

                case Tint32:
                L2:
                    buf->printf("%d", (int)v);
                    break;

                case Tuns8:
                    buf->writestring("cast(ubyte)");
                    goto L3;

                case Tuns16:
                    buf->writestring("cast(ushort)");
                    goto L3;

                case Tuns32:
                L3:
                    buf->printf("%uu", (unsigned)v);
                    break;

                case Tint64:
                    buf->printf("%lldL", v);
                    break;

                case Tuns64:
                L4:
                    buf->printf("%lluLU", v);
                    break;

                case Tbool:
                    buf->writestring((char *)(v ? "true" : "false"));
                    break;

                case Tpointer:
                    buf->writestring("cast(");
                    buf->writestring(t->toChars());
                    buf->writeByte(')');
                    if (Target::ptrsize == 4)
                        goto L3;
                    else if (Target::ptrsize == 8)
                        goto L4;
                    else
                        assert(0);

                default:
                    /* This can happen if errors, such as
                     * the type is painted on like in fromConstInitializer().
                     */
                    if (!global.errors)
                    {
    #ifdef DEBUG
                        t->print();
    #endif
                        assert(0);
                    }
                    break;
            }
        }
        else if (v & 0x8000000000000000LL)
            buf->printf("0x%llx", v);
        else
            buf->printf("%lld", v);
    }

    void visit(ErrorExp *e)
    {
        buf->writestring("__error");
    }

    void floatToBuffer(Type *type, real_t value)
    {
        /** sizeof(value)*3 is because each byte of mantissa is max
        of 256 (3 characters). The string will be "-M.MMMMe-4932".
        (ie, 8 chars more than mantissa). Plus one for trailing \0.
        Plus one for rounding. */
        const size_t BUFFER_LEN = sizeof(value) * 3 + 8 + 1 + 1;
        char buffer[BUFFER_LEN];
        ld_sprint(buffer, 'g', value);
        assert(strlen(buffer) < BUFFER_LEN);

        if (hgs->hdrgen)
        {
            real_t r = Port::strtold(buffer, NULL);
            if (r != value)                     // if exact duplication
                ld_sprint(buffer, 'a', value);
        }
        buf->writestring(buffer);

        if (type)
        {
            Type *t = type->toBasetype();
            switch (t->ty)
            {
                case Tfloat32:
                case Timaginary32:
                case Tcomplex32:
                    buf->writeByte('F');
                    break;

                case Tfloat80:
                case Timaginary80:
                case Tcomplex80:
                    buf->writeByte('L');
                    break;

                default:
                    break;
            }
            if (t->isimaginary())
                buf->writeByte('i');
        }
    }

    void visit(RealExp *e)
    {
        floatToBuffer(e->type, e->value);
    }

    void visit(ComplexExp *e)
    {
        /* Print as:
         *  (re+imi)
         */
        buf->writeByte('(');
        floatToBuffer(e->type, creall(e->value));
        buf->writeByte('+');
        floatToBuffer(e->type, cimagl(e->value));
        buf->writestring("i)");
    }

    void visit(IdentifierExp *e)
    {
        if (hgs->hdrgen || hgs->ddoc)
            buf->writestring(e->ident->toHChars2());
        else
            buf->writestring(e->ident->toChars());
    }

    void visit(DsymbolExp *e)
    {
        buf->writestring(e->s->toChars());
    }

    void visit(ThisExp *e)
    {
        buf->writestring("this");
    }

    void visit(SuperExp *e)
    {
        buf->writestring("super");
    }

    void visit(NullExp *e)
    {
        buf->writestring("null");
    }

    void visit(StringExp *e)
    {
        buf->writeByte('"');
        size_t o = buf->offset;
        for (size_t i = 0; i < e->len; i++)
        {
            unsigned c = e->charAt(i);
            switch (c)
            {
                case '"':
                case '\\':
                    buf->writeByte('\\');
                default:
                    if (c <= 0xFF)
                    {
                        if (c <= 0x7F && isprint(c))
                            buf->writeByte(c);
                        else
                            buf->printf("\\x%02x", c);
                    }
                    else if (c <= 0xFFFF)
                        buf->printf("\\x%02x\\x%02x", c & 0xFF, c >> 8);
                    else
                        buf->printf("\\x%02x\\x%02x\\x%02x\\x%02x",
                            c & 0xFF, (c >> 8) & 0xFF, (c >> 16) & 0xFF, c >> 24);
                    break;
            }
        }
        if (hgs->ddoc)
            escapeDdocString(buf, o);
        buf->writeByte('"');
        if (e->postfix)
            buf->writeByte(e->postfix);
    }

    void visit(ArrayLiteralExp *e)
    {
        buf->writeByte('[');
        argsToCBuffer(buf, e->elements, hgs);
        buf->writeByte(']');
    }

    void visit(AssocArrayLiteralExp *e)
    {
        buf->writeByte('[');
        for (size_t i = 0; i < e->keys->dim; i++)
        {
            Expression *key = (*e->keys)[i];
            Expression *value = (*e->values)[i];

            if (i)
                buf->writestring(", ");
            expToCBuffer(buf, hgs, key, PREC_assign);
            buf->writeByte(':');
            expToCBuffer(buf, hgs, value, PREC_assign);
        }
        buf->writeByte(']');
    }

    void visit(StructLiteralExp *e)
    {
        buf->writestring(e->sd->toChars());
        buf->writeByte('(');

        // CTFE can generate struct literals that contain an AddrExp pointing
        // to themselves, need to avoid infinite recursion:
        // struct S { this(int){ this.s = &this; } S* s; }
        // const foo = new S(0);
        if (e->stageflags & stageToCBuffer)
            buf->writestring("<recursion>");
        else
        {
            int old = e->stageflags;
            e->stageflags |= stageToCBuffer;
            argsToCBuffer(buf, e->elements, hgs);
            e->stageflags = old;
        }

        buf->writeByte(')');
    }

    void visit(TypeExp *e)
    {
        toCBuffer(e->type, buf, NULL, hgs);
    }

    void visit(ScopeExp *e)
    {
        if (e->sds->isTemplateInstance())
        {
            e->sds->accept(this);
        }
        else if (hgs != NULL && hgs->ddoc)
        {
            // fixes bug 6491
            Module *module = e->sds->isModule();
            if (module)
                buf->writestring(module->md->toChars());
            else
                buf->writestring(e->sds->toChars());
        }
        else
        {
            buf->writestring(e->sds->kind());
            buf->writestring(" ");
            buf->writestring(e->sds->toChars());
        }
    }

    void visit(TemplateExp *e)
    {
        buf->writestring(e->td->toChars());
    }

    void visit(NewExp *e)
    {
        if (e->thisexp)
        {
            expToCBuffer(buf, hgs, e->thisexp, PREC_primary);
            buf->writeByte('.');
        }
        buf->writestring("new ");
        if (e->newargs && e->newargs->dim)
        {
            buf->writeByte('(');
            argsToCBuffer(buf, e->newargs, hgs);
            buf->writeByte(')');
        }
        toCBuffer(e->newtype, buf, NULL, hgs);
        if (e->arguments && e->arguments->dim)
        {
            buf->writeByte('(');
            argsToCBuffer(buf, e->arguments, hgs);
            buf->writeByte(')');
        }
    }

    void visit(NewAnonClassExp *e)
    {
        if (e->thisexp)
        {
            expToCBuffer(buf, hgs, e->thisexp, PREC_primary);
            buf->writeByte('.');
        }
        buf->writestring("new");
        if (e->newargs && e->newargs->dim)
        {
            buf->writeByte('(');
            argsToCBuffer(buf, e->newargs, hgs);
            buf->writeByte(')');
        }
        buf->writestring(" class ");
        if (e->arguments && e->arguments->dim)
        {
            buf->writeByte('(');
            argsToCBuffer(buf, e->arguments, hgs);
            buf->writeByte(')');
        }
        //buf->writestring(" { }");
        if (e->cd)
            e->cd->accept(this);
    }

    void visit(SymOffExp *e)
    {
        if (e->offset)
            buf->printf("(& %s+%u)", e->var->toChars(), e->offset);
        else if (e->var->isTypeInfoDeclaration())
            buf->printf("%s", e->var->toChars());
        else
            buf->printf("& %s", e->var->toChars());
    }

    void visit(VarExp *e)
    {
        buf->writestring(e->var->toChars());
    }

    void visit(OverExp *e)
    {
        buf->writestring(e->vars->ident->toChars());
    }

    void visit(TupleExp *e)
    {
        if (e->e0)
        {
            buf->writeByte('(');
            e->e0->accept(this);
            buf->writestring(", tuple(");
            argsToCBuffer(buf, e->exps, hgs);
            buf->writestring("))");
        }
        else
        {
            buf->writestring("tuple(");
            argsToCBuffer(buf, e->exps, hgs);
            buf->writeByte(')');
        }
    }

    void visit(FuncExp *e)
    {
        e->fd->accept(this);
        //buf->writestring(e->fd->toChars());
    }

    void visit(DeclarationExp *e)
    {
        e->declaration->accept(this);
    }

    void visit(TypeidExp *e)
    {
        buf->writestring("typeid(");
        ObjectToCBuffer(buf, hgs, e->obj);
        buf->writeByte(')');
    }

    void visit(TraitsExp *e)
    {
        buf->writestring("__traits(");
        buf->writestring(e->ident->toChars());
        if (e->args)
        {
            for (size_t i = 0; i < e->args->dim; i++)
            {
                buf->writestring(", ");;
                RootObject *oarg = (*e->args)[i];
                ObjectToCBuffer(buf, hgs, oarg);
            }
        }
        buf->writeByte(')');
    }

    void visit(HaltExp *e)
    {
        buf->writestring("halt");
    }

    void visit(IsExp *e)
    {
        buf->writestring("is(");
        toCBuffer(e->targ, buf, e->id, hgs);
        if (e->tok2 != TOKreserved)
        {
            buf->printf(" %s %s", Token::toChars(e->tok), Token::toChars(e->tok2));
        }
        else if (e->tspec)
        {
            if (e->tok == TOKcolon)
                buf->writestring(" : ");
            else
                buf->writestring(" == ");
            toCBuffer(e->tspec, buf, NULL, hgs);
        }
        if (e->parameters)
        {
            for (size_t i = 0; i < e->parameters->dim; i++)
            {
                buf->writestring(", ");
                TemplateParameter *tp = (*e->parameters)[i];
                tp->accept(this);
            }
        }
        buf->writeByte(')');
    }

    void visit(UnaExp *e)
    {
        buf->writestring(Token::toChars(e->op));
        expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
    }

    void visit(BinExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
        buf->writeByte(' ');
        buf->writestring(Token::toChars(e->op));
        buf->writeByte(' ');
        expToCBuffer(buf, hgs, e->e2, (PREC)(precedence[e->op] + 1));
    }

    void visit(CompileExp *e)
    {
        buf->writestring("mixin(");
        expToCBuffer(buf, hgs, e->e1, PREC_assign);
        buf->writeByte(')');
    }

    void visit(FileExp *e)
    {
        buf->writestring("import(");
        expToCBuffer(buf, hgs, e->e1, PREC_assign);
        buf->writeByte(')');
    }

    void visit(AssertExp *e)
    {
        buf->writestring("assert(");
        expToCBuffer(buf, hgs, e->e1, PREC_assign);
        if (e->msg)
        {
            buf->writestring(", ");
            expToCBuffer(buf, hgs, e->msg, PREC_assign);
        }
        buf->writeByte(')');
    }

    void visit(DotIdExp *e)
    {
        //printf("DotIdExp::toCBuffer()\n");
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writeByte('.');
        buf->writestring(e->ident->toChars());
    }

    void visit(DotTemplateExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writeByte('.');
        buf->writestring(e->td->toChars());
    }

    void visit(DotVarExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writeByte('.');
        buf->writestring(e->var->toChars());
    }

    void visit(DotTemplateInstanceExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writeByte('.');
        e->ti->accept(this);
    }

    void visit(DelegateExp *e)
    {
        buf->writeByte('&');
        if (!e->func->isNested())
        {
            expToCBuffer(buf, hgs, e->e1, PREC_primary);
            buf->writeByte('.');
        }
        buf->writestring(e->func->toChars());
    }

    void visit(DotTypeExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writeByte('.');
        buf->writestring(e->sym->toChars());
    }

    void visit(CallExp *e)
    {
        if (e->e1->op == TOKtype)
        {
            /* Avoid parens around type to prevent forbidden cast syntax:
             *   (sometype)(arg1)
             * This is ok since types in constructor calls
             * can never depend on parens anyway
             */
            e->e1->accept(this);
        }
        else
            expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
        buf->writeByte('(');
        argsToCBuffer(buf, e->arguments, hgs);
        buf->writeByte(')');
    }

    void visit(PtrExp *e)
    {
        buf->writeByte('*');
        expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
    }

    void visit(DeleteExp *e)
    {
        buf->writestring("delete ");
        expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
    }

    void visit(CastExp *e)
    {
        buf->writestring("cast(");
        if (e->to)
            toCBuffer(e->to, buf, NULL, hgs);
        else
        {
            MODtoBuffer(buf, e->mod);
        }
        buf->writeByte(')');
        expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
    }

    void visit(VectorExp *e)
    {
        buf->writestring("cast(");
        toCBuffer(e->to, buf, NULL, hgs);
        buf->writeByte(')');
        expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
    }

    void visit(SliceExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
        buf->writeByte('[');
        if (e->upr || e->lwr)
        {
            if (e->lwr)
                sizeToCBuffer(buf, hgs, e->lwr);
            else
                buf->writeByte('0');
            buf->writestring("..");
            if (e->upr)
                sizeToCBuffer(buf, hgs, e->upr);
            else
                buf->writestring("$");
        }
        buf->writeByte(']');
    }

    void visit(ArrayLengthExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writestring(".length");
    }

    void visit(IntervalExp *e)
    {
        expToCBuffer(buf, hgs, e->lwr, PREC_assign);
        buf->writestring("..");
        expToCBuffer(buf, hgs, e->upr, PREC_assign);
    }

    void visit(DelegatePtrExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writestring(".ptr");
    }

    void visit(DelegateFuncptrExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writestring(".funcptr");
    }

    void visit(ArrayExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writeByte('[');
        argsToCBuffer(buf, e->arguments, hgs);
        buf->writeByte(']');
    }

    void visit(DotExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writeByte('.');
        expToCBuffer(buf, hgs, e->e2, PREC_primary);
    }

    void visit(IndexExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writeByte('[');
        sizeToCBuffer(buf, hgs, e->e2);
        buf->writeByte(']');
    }

    void visit(PostExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
        buf->writestring(Token::toChars(e->op));
    }

    void visit(PreExp *e)
    {
        buf->writestring(Token::toChars(e->op));
        expToCBuffer(buf, hgs, e->e1, precedence[e->op]);
    }

    void visit(RemoveExp *e)
    {
        expToCBuffer(buf, hgs, e->e1, PREC_primary);
        buf->writestring(".remove(");
        expToCBuffer(buf, hgs, e->e2, PREC_assign);
        buf->writestring(")");
    }

    void visit(CondExp *e)
    {
        expToCBuffer(buf, hgs, e->econd, PREC_oror);
        buf->writestring(" ? ");
        expToCBuffer(buf, hgs, e->e1, PREC_expr);
        buf->writestring(" : ");
        expToCBuffer(buf, hgs, e->e2, PREC_cond);
    }

    void visit(DefaultInitExp *e)
    {
        buf->writestring(Token::toChars(e->subop));
    }

    void visit(ClassReferenceExp *e)
    {
        buf->writestring(e->value->toChars());
    }

    ////////////////////////////////////////////////////////////////////////////

    void visit(TemplateTypeParameter *tp)
    {
        buf->writestring(tp->ident->toChars());
        if (tp->specType)
        {
            buf->writestring(" : ");
            ::toCBuffer(tp->specType, buf, NULL, hgs);
        }
        if (tp->defaultType)
        {
            buf->writestring(" = ");
            ::toCBuffer(tp->defaultType, buf, NULL, hgs);
        }
    }

    void visit(TemplateThisParameter *tp)
    {
        buf->writestring("this ");
        visit((TemplateTypeParameter *)tp);
    }

    void visit(TemplateAliasParameter *tp)
    {
        buf->writestring("alias ");
        if (tp->specType)
        {
            HdrGenState hgs1;
            ::toCBuffer(tp->specType, buf, tp->ident, &hgs1);
        }
        else
            buf->writestring(tp->ident->toChars());
        if (tp->specAlias)
        {
            buf->writestring(" : ");
            ObjectToCBuffer(buf, hgs, tp->specAlias);
        }
        if (tp->defaultAlias)
        {
            buf->writestring(" = ");
            ObjectToCBuffer(buf, hgs, tp->defaultAlias);
        }
    }

    void visit(TemplateValueParameter *tp)
    {
        ::toCBuffer(tp->valType, buf, tp->ident, hgs);
        if (tp->specValue)
        {
            buf->writestring(" : ");
            tp->specValue->accept(this);
        }
        if (tp->defaultValue)
        {
            buf->writestring(" = ");
            tp->defaultValue->accept(this);
        }
    }

    void visit(TemplateTupleParameter *tp)
    {
        buf->writestring(tp->ident->toChars());
        buf->writestring("...");
    }

    ////////////////////////////////////////////////////////////////////////////

    void visit(DebugCondition *c)
    {
        if (c->ident)
            buf->printf("debug (%s)", c->ident->toChars());
        else
            buf->printf("debug (%u)", c->level);
    }

    void visit(VersionCondition *c)
    {
        if (c->ident)
            buf->printf("version (%s)", c->ident->toChars());
        else
            buf->printf("version (%u)", c->level);
    }

    void visit(StaticIfCondition *c)
    {
        buf->writestring("static if (");
        c->exp->accept(this);
        buf->writeByte(')');
    }
};

void toCBuffer(Statement *s, OutBuffer *buf, HdrGenState *hgs)
{
    PrettyPrintVisitor v(buf, hgs);
    s->accept(&v);
}

void toCBuffer(Type *t, OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    if (t->ty == Tfunction)
    {
        functionToBufferFull((TypeFunction *)t, buf, ident, hgs, NULL);
        return;
    }
    if (t->ty == Terror)
    {
        buf->writestring("_error_");
        return;
    }

    toBufferShort(t, buf, hgs);
    if (ident)
    {
        buf->writeByte(' ');
        buf->writestring(ident->toChars());
    }
}

void toCBuffer(Dsymbol *s, OutBuffer *buf, HdrGenState *hgs)
{
    PrettyPrintVisitor v(buf, hgs);
    s->accept(&v);
}

// used from TemplateInstance::toChars() and TemplateMixin::toChars()
void toCBufferInstance(TemplateInstance *ti, OutBuffer *buf, bool qualifyTypes)
{
    HdrGenState hgs;
    hgs.fullQual = qualifyTypes;
    PrettyPrintVisitor v(buf, &hgs);
    v.visit(ti);
}

void toCBuffer(Initializer *iz, OutBuffer *buf, HdrGenState *hgs)
{
    PrettyPrintVisitor v(buf, hgs);
    iz->accept(&v);
}

// Bypass the special printing of function and error types
void toBufferShort(Type *t, OutBuffer *buf, HdrGenState *hgs)
{
    PrettyPrintVisitor v(buf, hgs);
    v.visitWithMask(t, 0);
}

void trustToBuffer(OutBuffer *buf, TRUST trust)
{
    const char *p = trustToChars(trust);
    if (p)
        buf->writestring(p);
}

const char *trustToChars(TRUST trust)
{
    switch (trust)
    {
        case TRUSTdefault:  return NULL;
        case TRUSTsystem:   return "@system";
        case TRUSTtrusted:  return "@trusted";
        case TRUSTsafe:     return "@safe";
        default:            assert(0);
    }
    return NULL;    // never reached
}

void linkageToBuffer(OutBuffer *buf, LINK linkage)
{
    const char *p = linkageToChars(linkage);
    if (p)
    {
        buf->writestring("extern (");
        buf->writestring(p);
        buf->writeByte(')');
    }
}

const char *linkageToChars(LINK linkage)
{
    switch (linkage)
    {
        case LINKdefault:   return NULL;
        case LINKd:         return "D";
        case LINKc:         return "C";
        case LINKcpp:       return "C++";
        case LINKwindows:   return "Windows";
        case LINKpascal:    return "Pascal";
        default:            assert(0);
    }
    return NULL;    // never reached
}

void protectionToBuffer(OutBuffer *buf, PROT prot)
{
    const char *p = protectionToChars(prot);
    if (p)
        buf->writestring(p);
}

const char *protectionToChars(PROT prot)
{
    switch (prot)
    {
        case PROTundefined: return NULL;
        case PROTnone:      return "none";
        case PROTprivate:   return "private";
        case PROTpackage:   return "package";
        case PROTprotected: return "protected";
        case PROTpublic:    return "public";
        case PROTexport:    return "export";
        default:            assert(0);
    }
    return NULL;    // never reached
}

// callback for TypeFunction::attributesApply, avoids 'ref' in ctors and appends spaces
struct PostAppendStrings
{
    bool isCtor;
    OutBuffer *buf;

    static int fp(void *param, const char *str)
    {
        PostAppendStrings *p = (PostAppendStrings *)param;

        // don't write 'ref' for ctors
        if (p->isCtor && strcmp(str, "ref") == 0)
            return 0;

        p->buf->writestring(str);
        p->buf->writeByte(' ');
        return 0;
    }
};

// Print the full function signature with correct ident, attributes and template args
void functionToBufferFull(TypeFunction *tf, OutBuffer *buf, Identifier *ident,
        HdrGenState* hgs, TemplateDeclaration *td)
{
    //printf("TypeFunction::toCBuffer() this = %p\n", this);
    if (tf->inuse)
    {
        tf->inuse = 2;              // flag error to caller
        return;
    }
    tf->inuse++;

    /* Use 'storage class' style for attributes
     */
    if (tf->mod)
    {
        MODtoBuffer(buf, tf->mod);
        buf->writeByte(' ');
    }

    PostAppendStrings pas;
    pas.isCtor = (ident == Id::ctor);
    pas.buf = buf;
    tf->attributesApply(&pas, &PostAppendStrings::fp);

    if (tf->linkage > LINKd && hgs->ddoc != 1 && !hgs->hdrgen)
    {
        linkageToBuffer(buf, tf->linkage);
        buf->writeByte(' ');
    }

    if (ident && ident->toHChars2() != ident->toChars())
    {
    }
    else if (tf->next)
    {
        toBufferShort(tf->next, buf, hgs);
        if (ident)
            buf->writeByte(' ');
    }
    else if (hgs->ddoc)
        buf->writestring("auto ");

    if (ident)
        buf->writestring(ident->toHChars2());

    if (td)
    {
        buf->writeByte('(');
        for (size_t i = 0; i < td->origParameters->dim; i++)
        {
            TemplateParameter *tp = (*td->origParameters)[i];
            if (i)
                buf->writestring(", ");
            ::toCBuffer(tp, buf, hgs);
        }
        buf->writeByte(')');
    }
    parametersToCBuffer(buf, hgs, tf->parameters, tf->varargs);
    tf->inuse--;
}

// ident is inserted before the argument list and will be "function" or "delegate" for a type
void functionToBufferWithIdent(TypeFunction *t, OutBuffer *buf, const char *ident)
{
    HdrGenState hgs;
    PrettyPrintVisitor v(buf, &hgs);
    v.visitFuncIdent(t, ident);
}

void toCBuffer(Expression *e, OutBuffer *buf, HdrGenState *hgs)
{
    PrettyPrintVisitor v(buf, hgs);
    e->accept(&v);
}

void sizeToCBuffer(OutBuffer *buf, HdrGenState *hgs, Expression *e)
{
    if (e->type == Type::tsize_t)
    {
        Expression *ex = (e->op == TOKcast ? ((CastExp *)e)->e1 : e);
        ex = ex->optimize(WANTvalue);

        dinteger_t uval = ex->op == TOKint64 ? ex->toInteger() : (dinteger_t)-1;
        if ((sinteger_t)uval >= 0)
        {
            dinteger_t sizemax;
            if (Target::ptrsize == 4)
                sizemax = 0xFFFFFFFFUL;
            else if (Target::ptrsize == 8)
                sizemax = 0xFFFFFFFFFFFFFFFFULL;
            else
                assert(0);
            if (uval <= sizemax && uval <= 0x7FFFFFFFFFFFFFFFULL)
            {
                buf->printf("%llu", uval);
                return;
            }
        }
    }
    expToCBuffer(buf, hgs, e, PREC_assign);
}


/**************************************************
 * Write expression out to buf, but wrap it
 * in ( ) if its precedence is less than pr.
 */

void expToCBuffer(OutBuffer *buf, HdrGenState *hgs, Expression *e, PREC pr)
{
#ifdef DEBUG
    if (precedence[e->op] == PREC_zero)
        printf("precedence not defined for token '%s'\n",Token::tochars[e->op]);
#endif
    assert(precedence[e->op] != PREC_zero);
    assert(pr != PREC_zero);

    PrettyPrintVisitor v(buf, hgs);

    //if (precedence[e->op] == 0) e->print();
    /* Despite precedence, we don't allow a<b<c expressions.
     * They must be parenthesized.
     */
    if (precedence[e->op] < pr ||
        (pr == PREC_rel && precedence[e->op] == pr))
    {
        buf->writeByte('(');
        e->accept(&v);
        buf->writeByte(')');
    }
    else
        e->accept(&v);
}

/**************************************************
 * Write out argument list to buf.
 */
void argsToCBuffer(OutBuffer *buf, Expressions *expressions, HdrGenState *hgs)
{
    if (!expressions || !expressions->dim)
        return;

    for (size_t i = 0; i < expressions->dim; i++)
    {
        if (i)
            buf->writestring(", ");
        if (Expression *e = (*expressions)[i])
            expToCBuffer(buf, hgs, e, PREC_assign);
    }
}

/**************************************************
 * Write out argument types to buf.
 */
void argExpTypesToCBuffer(OutBuffer *buf, Expressions *arguments)
{
    if (!arguments || !arguments->dim)
        return;

    HdrGenState hgs;
    for (size_t i = 0; i < arguments->dim; i++)
    {
        if (i)
            buf->writestring(", ");
        toBufferShort((*arguments)[i]->type, buf, &hgs);
    }
}

void toCBuffer(TemplateParameter *tp, OutBuffer *buf, HdrGenState *hgs)
{
    PrettyPrintVisitor v(buf, hgs);
    tp->accept(&v);
}

/****************************************
 * This makes a 'pretty' version of the template arguments.
 * It's analogous to genIdent() which makes a mangled version.
 */
void ObjectToCBuffer(OutBuffer *buf, HdrGenState *hgs, RootObject *oarg)
{
    //printf("ObjectToCBuffer()\n");

    /* The logic of this should match what genIdent() does. The _dynamic_cast()
     * function relies on all the pretty strings to be unique for different classes
     * (see Bugzilla 7375).
     * Perhaps it would be better to demangle what genIdent() does.
     */
    if (Type *t = isType(oarg))
    {
        //printf("\tt: %s ty = %d\n", t->toChars(), t->ty);
        toCBuffer(t, buf, NULL, hgs);
    }
    else if (Expression *e = isExpression(oarg))
    {
        if (e->op == TOKvar)
            e = e->optimize(WANTvalue);         // added to fix Bugzilla 7375
        toCBuffer(e, buf, hgs);
    }
    else if (Dsymbol *s = isDsymbol(oarg))
    {
        const char *p = s->ident ? s->ident->toChars() : s->toChars();
        buf->writestring(p);
    }
    else if (Tuple *v = isTuple(oarg))
    {
        Objects *args = &v->objects;
        for (size_t i = 0; i < args->dim; i++)
        {
            if (i)
                buf->writestring(", ");
            ObjectToCBuffer(buf, hgs, (*args)[i]);
        }
    }
    else if (!oarg)
    {
        buf->writestring("NULL");
    }
    else
    {
#ifdef DEBUG
        printf("bad Object = %p\n", oarg);
#endif
        assert(0);
    }
}

void arrayObjectsToBuffer(OutBuffer *buf, Objects *objects)
{
    if (!objects || !objects->dim)
        return;

    HdrGenState hgs;
    for (size_t i = 0; i < objects->dim; i++)
    {
        if (i)
            buf->writestring(", ");
        ObjectToCBuffer(buf, &hgs, (*objects)[i]);
    }
}

const char *parametersTypeToChars(Parameters *parameters, int varargs)
{
    OutBuffer buf;
    HdrGenState hgs;
    parametersToCBuffer(&buf, &hgs, parameters, varargs);
    return buf.extractString();
}

void parametersToCBuffer(OutBuffer *buf, HdrGenState *hgs, Parameters *parameters, int varargs)
{
    buf->writeByte('(');
    if (parameters)
    {
        size_t dim = Parameter::dim(parameters);
        for (size_t i = 0; i < dim; i++)
        {
            if (i)
                buf->writestring(", ");
            Parameter *fparam = Parameter::getNth(parameters, i);

            if (fparam->storageClass & STCauto)
                buf->writestring("auto ");

            if (fparam->storageClass & STCout)
                buf->writestring("out ");
            else if (fparam->storageClass & STCref)
                buf->writestring("ref ");
            else if (fparam->storageClass & STCin)
                buf->writestring("in ");
            else if (fparam->storageClass & STClazy)
                buf->writestring("lazy ");
            else if (fparam->storageClass & STCalias)
                buf->writestring("alias ");

            StorageClass stc = fparam->storageClass;
            if (fparam->type && fparam->type->mod & MODshared)
                stc &= ~STCshared;

            StorageClassDeclaration::stcToCBuffer(buf,
                stc & (STCconst | STCimmutable | STCwild | STCshared | STCscope));

            if (fparam->storageClass & STCalias)
            {
                if (fparam->ident)
                    buf->writestring(fparam->ident->toChars());
            }
            else if (fparam->type->ty == Tident &&
                     ((TypeIdentifier *)fparam->type)->ident->len > 3 &&
                     strncmp(((TypeIdentifier *)fparam->type)->ident->string, "__T", 3) == 0)
            {
                // print parameter name, instead of undetermined type parameter
                buf->writestring(fparam->ident->toChars());
            }
            else
                ::toCBuffer(fparam->type, buf, fparam->ident, hgs);
            if (fparam->defaultArg)
            {
                buf->writestring(" = ");
                ::toCBuffer(fparam->defaultArg, buf, hgs);
            }
        }
        if (varargs)
        {
            if (parameters->dim && varargs == 1)
                buf->writestring(", ");
            buf->writestring("...");
        }
    }
    buf->writeByte(')');
}
