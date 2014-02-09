
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// Initial header generation implementation by Dave Fladebo
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Routines to emit header files

#define TEST_EMIT_ALL  0        // For Testing

#define LOG 0

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "rmem.h"

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
#include "hdrgen.h"

void argsToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs);
void sizeToCBuffer(OutBuffer *buf, HdrGenState *hgs, Expression *e);
void functionToCBuffer2(TypeFunction *t, OutBuffer *buf, HdrGenState *hgs, unsigned char modMask, const char *kind);

void Module::genhdrfile()
{
    OutBuffer hdrbufr;
    hdrbufr.doindent = 1;

    hdrbufr.printf("// D import file generated from '%s'", srcfile->toChars());
    hdrbufr.writenl();

    HdrGenState hgs;
    memset(&hgs, 0, sizeof(hgs));
    hgs.hdrgen = 1;

    toCBuffer(&hdrbufr, &hgs);

    // Transfer image to file
    hdrfile->setbuffer(hdrbufr.data, hdrbufr.offset);
    hdrbufr.data = NULL;

    ensurePathToNameExists(Loc(), hdrfile->toChars());
    writeFile(loc, hdrfile);
}


void Module::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (md)
    {
        buf->writestring("module ");
        buf->writestring(md->toChars());
        buf->writeByte(';');
        buf->writenl();
    }

    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];

        s->toCBuffer(buf, hgs);
    }
}

class PrettyPrintVisitor : public Visitor
{
public:
    OutBuffer *buf;
    HdrGenState *hgs;

    Identifier *ident; // for printing "Type ident" of variables/parameters
    unsigned char modMask;

    PrettyPrintVisitor(OutBuffer *buf, HdrGenState *hgs, Identifier *ident, unsigned char modMask)
        : buf(buf), hgs(hgs), ident(ident), modMask(modMask)
    {
    }

    void visit(Statement *s)
    {
        buf->printf("Statement::toCBuffer()");
        buf->writenl();
        assert(0);
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
        t->accept(this);
        modMask = save;
    }

    void visit(Type *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        buf->writestring(t->toChars());
    }

    void visit(TypeBasic *t)
    {
        //printf("TypeBasic::toCBuffer2(modMask = %d, t->mod = %d)\n", modMask, t->mod);
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        buf->writestring(t->dstring);
    }

    void visit(TypeVector *t)
    {
        //printf("TypeVector::toCBuffer2(modMask = %d, t->mod = %d)\n", modMask, t->mod);
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        buf->writestring("__vector(");
        visitWithMask(t->basetype, t->mod);
        buf->writestring(")");
    }

    void visit(TypeSArray *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        visitWithMask(t->next, t->mod);
        buf->writeByte('[');
        sizeToCBuffer(buf, hgs, t->dim);
        buf->writeByte(']');
    }

    void visit(TypeDArray *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
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
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        visitWithMask(t->next, t->mod);
        buf->writeByte('[');
        visitWithMask(t->index, 0);
        buf->writeByte(']');
    }

    void visit(TypePointer *t)
    {
        //printf("TypePointer::toCBuffer2() next = %d\n", t->next->ty);
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        visitWithMask(t->next, t->mod);
        if (t->next->ty != Tfunction)
            buf->writeByte('*');
    }

    void visit(TypeReference *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
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
        functionToCBuffer2(t, buf, hgs, modMask, "function");
        t->inuse--;
    }

    void visit(TypeDelegate *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }

        functionToCBuffer2((TypeFunction *)t->next, buf, hgs, modMask, "delegate");
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
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        buf->writestring(t->ident->toChars());
        visitTypeQualifiedHelper(t);
    }

    void visit(TypeInstance *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        t->tempinst->toCBuffer(buf, hgs);
        visitTypeQualifiedHelper(t);
    }

    void visit(TypeTypeof *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        buf->writestring("typeof(");
        t->exp->toCBuffer(buf, hgs);
        buf->writeByte(')');
        visitTypeQualifiedHelper(t);
    }

    void visit(TypeReturn *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        buf->writestring("typeof(return)");
        visitTypeQualifiedHelper(t);
    }

    void visit(TypeEnum *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        buf->writestring(t->sym->toChars());
    }

    void visit(TypeTypedef *t)
    {
        //printf("TypeTypedef::toCBuffer2() '%s'\n", t->sym->toChars());
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        buf->writestring(t->sym->toChars());
    }

    void visit(TypeStruct *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        TemplateInstance *ti = t->sym->parent->isTemplateInstance();
        if (ti && ti->toAlias() == t->sym)
            buf->writestring(ti->toChars());
        else
            buf->writestring(t->sym->toChars());
    }

    void visit(TypeClass *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        TemplateInstance *ti = t->sym->parent->isTemplateInstance();
        if (ti && ti->toAlias() == t->sym)
            buf->writestring(ti->toChars());
        else
            buf->writestring(t->sym->toChars());
    }

    void visit(TypeTuple *t)
    {
        Parameter::argsToCBuffer(buf, hgs, t->arguments, 0);
    }

    void visit(TypeSlice *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        visitWithMask(t->next, t->mod);

        buf->writeByte('[');
        sizeToCBuffer(buf, hgs, t->lwr);
        buf->writestring(" .. ");
        sizeToCBuffer(buf, hgs, t->upr);
        buf->writeByte(']');
    }

    void visit(TypeNull *t)
    {
        if (modMask != t->mod)
        {
            t->toCBuffer3(buf, hgs, modMask);
            return;
        }
        buf->writestring("typeof(null)");
    }
};

void toCBuffer(Statement *s, OutBuffer *buf, HdrGenState *hgs)
{
    PrettyPrintVisitor v(buf, hgs, NULL, 0);
    s->accept(&v);
}

void Type::toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    toCBuffer2(buf, hgs, 0);
    if (ident)
    {
        buf->writeByte(' ');
        buf->writestring(ident->toChars());
    }
}

void TypeError::toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    buf->writestring("_error_");
}

void Type::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, unsigned char modMask)
{
    PrettyPrintVisitor v(buf, hgs, NULL, modMask);
    accept(&v);
}

void Type::toCBuffer3(OutBuffer *buf, HdrGenState *hgs, unsigned char modMask)
{
    if (modMask != this->mod)
    {
        unsigned char m = this->mod & ~(this->mod & modMask);
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

        toCBuffer2(buf, hgs, this->mod);

        if (m & (MODconst | MODimmutable))
            buf->writeByte(')');
        if (m & MODwild)
            buf->writeByte(')');
        if (m & MODshared)
            buf->writeByte(')');
    }
}

void TypeFunction::toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    toCBufferWithAttributes(buf, ident, hgs, this, NULL);
}

void TypeFunction::toCBufferWithAttributes(OutBuffer *buf, Identifier *ident, HdrGenState* hgs, TypeFunction *attrs, TemplateDeclaration *td)
{
    //printf("TypeFunction::toCBuffer() this = %p\n", this);
    if (inuse)
    {   inuse = 2;              // flag error to caller
        return;
    }
    inuse++;

    /* Use 'storage class' style for attributes
     */
    if (attrs->mod)
    {
        MODtoBuffer(buf, attrs->mod);
        buf->writeByte(' ');
    }

    if (attrs->purity)
        buf->writestring("pure ");
    if (attrs->isnothrow)
        buf->writestring("nothrow ");
    if (attrs->isproperty)
        buf->writestring("@property ");
    if (attrs->isref)
        buf->writestring("ref ");

    switch (attrs->trust)
    {
        case TRUSTsystem:
            buf->writestring("@system ");
            break;

        case TRUSTtrusted:
            buf->writestring("@trusted ");
            break;

        case TRUSTsafe:
            buf->writestring("@safe ");
            break;
        default: break;
    }

    if (hgs->ddoc != 1)
    {
        const char *p = NULL;
        switch (attrs->linkage)
        {
            case LINKd:         p = NULL;       break;
            case LINKc:         p = "C";        break;
            case LINKwindows:   p = "Windows";  break;
            case LINKpascal:    p = "Pascal";   break;
            case LINKcpp:       p = "C++";      break;
            default:
                assert(0);
        }
        if (!hgs->hdrgen && p)
        {
            buf->writestring("extern (");
            buf->writestring(p);
            buf->writestring(") ");
        }
    }

    if (!ident || ident->toHChars2() == ident->toChars())
    {   if (next)
            next->toCBuffer2(buf, hgs, 0);
        else if (hgs->ddoc)
            buf->writestring("auto");
    }

    if (ident)
    {
        if (next || hgs->ddoc)
            buf->writeByte(' ');
        buf->writestring(ident->toHChars2());
    }

    if (td)
    {   buf->writeByte('(');
        for (size_t i = 0; i < td->origParameters->dim; i++)
        {
            TemplateParameter *tp = (*td->origParameters)[i];
            if (i)
                buf->writestring(", ");
            tp->toCBuffer(buf, hgs);
        }
        buf->writeByte(')');
    }
    Parameter::argsToCBuffer(buf, hgs, parameters, varargs);
    inuse--;
}

// kind is inserted before the argument list and will usually be "function" or "delegate".
void functionToCBuffer2(TypeFunction *t, OutBuffer *buf, HdrGenState *hgs, unsigned char modMask, const char *kind)
{
    if (hgs->ddoc != 1)
    {
        const char *p = NULL;
        switch (t->linkage)
        {
            case LINKd:         p = NULL;       break;
            case LINKc:         p = "C";        break;
            case LINKwindows:   p = "Windows";  break;
            case LINKpascal:    p = "Pascal";   break;
            case LINKcpp:       p = "C++";      break;
            default:
                assert(0);
        }
        if (!hgs->hdrgen && p)
        {
            buf->writestring("extern (");
            buf->writestring(p);
            buf->writestring(") ");
        }
    }
    if (t->next)
    {
        t->next->toCBuffer2(buf, hgs, 0);
        buf->writeByte(' ');
    }
    buf->writestring(kind);
    Parameter::argsToCBuffer(buf, hgs, t->parameters, t->varargs);

    /* Use postfix style for attributes
     */
    if (modMask != t->mod)
    {
        t->modToBuffer(buf);
    }
    if (t->purity)
        buf->writestring(" pure");
    if (t->isnothrow)
        buf->writestring(" nothrow");
    if (t->isproperty)
        buf->writestring(" @property");
    if (t->isref)
        buf->writestring(" ref");

    switch (t->trust)
    {
        case TRUSTsystem:
            buf->writestring(" @system");
            break;

        case TRUSTtrusted:
            buf->writestring(" @trusted");
            break;

        case TRUSTsafe:
            buf->writestring(" @safe");
            break;
        default: break;
    }
}
