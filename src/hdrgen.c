
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
#include "hdrgen.h"

void argsToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs);
void sizeToCBuffer(OutBuffer *buf, HdrGenState *hgs, Expression *e);
void toBufferShort(Type *t, OutBuffer *buf, HdrGenState *hgs);
void expToCBuffer(OutBuffer *buf, HdrGenState *hgs, Expression *e, PREC pr);
void toCBuffer(Module *m, OutBuffer *buf, HdrGenState *hgs);

void genhdrfile(Module *m)
{
    OutBuffer hdrbufr;
    hdrbufr.doindent = 1;

    hdrbufr.printf("// D import file generated from '%s'", m->srcfile->toChars());
    hdrbufr.writenl();

    HdrGenState hgs;
    memset(&hgs, 0, sizeof(hgs));
    hgs.hdrgen = 1;

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
        if (m->md->isdeprecated)
        {
            if (m->md->msg)
            {
                buf->writestring("deprecated(");
                toCBuffer(m->md->msg, buf, hgs);
                buf->writestring(") ");
            }
            else
                buf->writestring("deprecated ");
        }
        buf->writestring("module ");
        buf->writestring(m->md->toChars());
        buf->writeByte(';');
        buf->writenl();
    }

    for (size_t i = 0; i < m->members->dim; i++)
    {
        Dsymbol *s = (*m->members)[i];
        s->toCBuffer(buf, hgs);
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
            s->exp->toCBuffer(buf, hgs);
            if (s->exp->op != TOKdeclaration)
            {
                buf->writeByte(';');
                if (!hgs->FLinit.init)
                    buf->writenl();
            }
        }
        else
        {
            buf->writeByte(';');
            if (!hgs->FLinit.init)
                buf->writenl();
        }
    }

    void visit(CompileStatement *s)
    {
        buf->writestring("mixin(");
        s->exp->toCBuffer(buf, hgs);
        buf->writestring(");");
        if (!hgs->FLinit.init)
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
                            v->type->toCBuffer(buf, v->ident, hgs);
                        else
                            buf->writestring(v->ident->toChars());
                    }

                    if (v->init)
                    {   buf->writestring(" = ");
                        ExpInitializer *ie = v->init->isExpInitializer();
                        if (ie && (ie->exp->op == TOKconstruct || ie->exp->op == TOKblit))
                            ((AssignExp *)ie->exp)->e2->toCBuffer(buf, hgs);
                        else
                            v->init->toCBuffer(buf, hgs);
                    }
                }
                else
                    d->toCBuffer(buf, hgs);
                anywritten = true;
            }
        }
        buf->writeByte(';');
        if (!hgs->FLinit.init)
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
        s->condition->toCBuffer(buf, hgs);
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
        s->condition->toCBuffer(buf, hgs);
        buf->writestring(");");
        buf->writenl();
    }

    void visit(ForStatement *s)
    {
        buf->writestring("for (");
        if (s->init)
        {
            hgs->FLinit.init++;
            s->init->accept(this);
            hgs->FLinit.init--;
        }
        else
            buf->writeByte(';');
        if (s->condition)
        {
            buf->writeByte(' ');
            s->condition->toCBuffer(buf, hgs);
        }
        buf->writeByte(';');
        if (s->increment)
        {
            buf->writeByte(' ');
            s->increment->toCBuffer(buf, hgs);
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
                a->type->toCBuffer(buf, a->ident, hgs);
            else
                buf->writestring(a->ident->toChars());
        }
        buf->writestring("; ");
        s->aggr->toCBuffer(buf, hgs);
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
            s->arg->type->toCBuffer(buf, s->arg->ident, hgs);
        else
            buf->writestring(s->arg->ident->toChars());

        buf->writestring("; ");
        s->lwr->toCBuffer(buf, hgs);
        buf->writestring(" .. ");
        s->upr->toCBuffer(buf, hgs);
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
                s->arg->type->toCBuffer(buf, s->arg->ident, hgs);
            else
            {
                buf->writestring("auto ");
                buf->writestring(s->arg->ident->toChars());
            }
            buf->writestring(" = ");
        }
        s->condition->toCBuffer(buf, hgs);
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
        s->condition->toCBuffer(buf, hgs);
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
        s->sa->toCBuffer(buf, hgs);
    }

    void visit(SwitchStatement *s)
    {
        buf->writestring(s->isFinal ? "final switch (" : "switch (");
        s->condition->toCBuffer(buf, hgs);
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
        s->exp->toCBuffer(buf, hgs);
        buf->writeByte(':');
        buf->writenl();
        s->statement->accept(this);
    }

    void visit(CaseRangeStatement *s)
    {
        buf->writestring("case ");
        s->first->toCBuffer(buf, hgs);
        buf->writestring(": .. case ");
        s->last->toCBuffer(buf, hgs);
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
            s->exp->toCBuffer(buf, hgs);
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
            s->exp->toCBuffer(buf, hgs);
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
            s->exp->toCBuffer(buf, hgs);
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
        s->exp->toCBuffer(buf, hgs);
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
        s->exp->toCBuffer(buf, hgs);
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
            imp->toCBuffer(buf, hgs);
        }
    }

    void visit(Catch *c)
    {
        buf->writestring("catch");
        if (c->type)
        {
            buf->writeByte('(');
            c->type->toCBuffer(buf, c->ident, hgs);
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
        Parameter::argsToCBuffer(buf, hgs, t->parameters, t->varargs);

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
                ti->toCBuffer(buf, hgs);
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
        t->tempinst->toCBuffer(buf, hgs);
        visitTypeQualifiedHelper(t);
    }

    void visit(TypeTypeof *t)
    {
        buf->writestring("typeof(");
        t->exp->toCBuffer(buf, hgs);
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
            buf->writestring((hgs->fullQualification) ? ti->toPrettyChars() : ti->toChars());
        else
            buf->writestring((hgs->fullQualification) ? t->sym->toPrettyChars() : t->sym->toChars());
    }

    void visit(TypeClass *t)
    {
        TemplateInstance *ti = t->sym->parent->isTemplateInstance();
        if (ti && ti->toAlias() == t->sym)
            buf->writestring((hgs->fullQualification) ? ti->toPrettyChars() : ti->toChars());
        else
            buf->writestring((hgs->fullQualification) ? t->sym->toPrettyChars() : t->sym->toChars());
    }

    void visit(TypeTuple *t)
    {
        Parameter::argsToCBuffer(buf, hgs, t->arguments, 0);
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
        /* In order to get an exact representation, try converting it
         * to decimal then back again. If it matches, use it.
         * If it doesn't, fall back to hex, which is
         * always exact.
         * Longest string is for -real.max:
         * "-1.18973e+4932\0".length == 17
         * "-0xf.fffffffffffffffp+16380\0".length == 28
         */
        const size_t BUFFER_LEN = 32;
        char buffer[BUFFER_LEN];
        ld_sprint(buffer, 'g', value);
        assert(strlen(buffer) < BUFFER_LEN);

        real_t r = Port::strtold(buffer, NULL);
        if (r != value)                     // if exact duplication
            ld_sprint(buffer, 'a', value);
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
                    if (!hgs->console)
                        buf->writeByte('\\');
                default:
                    if (c <= 0xFF)
                    {
                        if (c <= 0x7F && (isprint(c) || hgs->console))
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
        e->type->toCBuffer(buf, NULL, hgs);
    }

    void visit(ScopeExp *e)
    {
        if (e->sds->isTemplateInstance())
        {
            e->sds->toCBuffer(buf, hgs);
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
        e->newtype->toCBuffer(buf, NULL, hgs);
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
        {
            e->cd->toCBuffer(buf, hgs);
        }
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
            e->e0->toCBuffer(buf, hgs);
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
        e->fd->toCBuffer(buf, hgs);
        //buf->writestring(e->fd->toChars());
    }

    void visit(DeclarationExp *e)
    {
        e->declaration->toCBuffer(buf, hgs);
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
        e->targ->toCBuffer(buf, e->id, hgs);
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
            e->tspec->toCBuffer(buf, NULL, hgs);
        }
        if (e->parameters)
        {
            for (size_t i = 0; i < e->parameters->dim; i++)
            {
                buf->writestring(", ");
                TemplateParameter *tp = (*e->parameters)[i];
                tp->toCBuffer(buf, hgs);
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
        e->ti->toCBuffer(buf, hgs);
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
            e->e1->toCBuffer(buf, hgs);
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
            e->to->toCBuffer(buf, NULL, hgs);
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
        e->to->toCBuffer(buf, NULL, hgs);
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
            tp->toCBuffer(buf, hgs);
        }
        buf->writeByte(')');
    }
    Parameter::argsToCBuffer(buf, hgs, tf->parameters, tf->varargs);
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

    //if (precedence[e->op] == 0) e->print();
    /* Despite precedence, we don't allow a<b<c expressions.
     * They must be parenthesized.
     */
    if (precedence[e->op] < pr ||
        (pr == PREC_rel && precedence[e->op] == pr))
    {
        buf->writeByte('(');
        e->toCBuffer(buf, hgs);
        buf->writeByte(')');
    }
    else
        e->toCBuffer(buf, hgs);
}

/**************************************************
 * Write out argument list to buf.
 */

void argsToCBuffer(OutBuffer *buf, Expressions *expressions, HdrGenState *hgs)
{
    if (expressions)
    {
        for (size_t i = 0; i < expressions->dim; i++)
        {   Expression *e = (*expressions)[i];

            if (i)
                buf->writestring(", ");
            if (e)
                expToCBuffer(buf, hgs, e, PREC_assign);
        }
    }
}
