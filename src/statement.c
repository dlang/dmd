
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/statement.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "statement.h"
#include "expression.h"
#include "cond.h"
#include "init.h"
#include "staticassert.h"
#include "scope.h"
#include "declaration.h"
#include "aggregate.h"
#include "id.h"
#include "hdrgen.h"
#include "parse.h"
#include "template.h"
#include "attrib.h"
#include "import.h"

bool walkPostorder(Statement *s, StoppableVisitor *v);
StorageClass mergeFuncAttrs(StorageClass s1, FuncDeclaration *f);
bool checkEscapeRef(Scope *sc, Expression *e, bool gag);
VarDeclaration *copyToTemp(StorageClass stc, const char *name, Expression *e);

Identifier *fixupLabelName(Scope *sc, Identifier *ident)
{
    unsigned flags = (sc->flags & SCOPEcontract);
    const char *id = ident->toChars();
    if (flags && flags != SCOPEinvariant &&
        !(id[0] == '_' && id[1] == '_'))
    {
        /* CTFE requires FuncDeclaration::labtab for the interpretation.
         * So fixing the label name inside in/out contracts is necessary
         * for the uniqueness in labtab.
         */
        const char *prefix = flags == SCOPErequire ? "__in_" : "__out_";
        OutBuffer buf;
        buf.printf("%s%s", prefix, ident->toChars());

        const char *name = buf.extractString();
        ident = Identifier::idPool(name);
    }
    return ident;
}

LabelStatement *checkLabeledLoop(Scope *sc, Statement *statement)
{
    if (sc->slabel && sc->slabel->statement == statement)
    {
        return sc->slabel;
    }
    return NULL;
}

/******************************** Statement ***************************/

Statement::Statement(Loc loc)
    : loc(loc)
{
    // If this is an in{} contract scope statement (skip for determining
    //  inlineStatus of a function body for header content)
}

Statement *Statement::syntaxCopy()
{
    assert(0);
    return NULL;
}

void Statement::print()
{
    fprintf(stderr, "%s\n", toChars());
    fflush(stderr);
}

const char *Statement::toChars()
{
    HdrGenState hgs;

    OutBuffer buf;
    ::toCBuffer(this, &buf, &hgs);
    return buf.extractString();
}


void Statement::error(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::verror(loc, format, ap);
    va_end( ap );
}

void Statement::warning(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::vwarning(loc, format, ap);
    va_end( ap );
}

void Statement::deprecation(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::vdeprecation(loc, format, ap);
    va_end( ap );
}

bool Statement::hasBreak()
{
    //printf("Statement::hasBreak()\n");
    return false;
}

bool Statement::hasContinue()
{
    return false;
}

/* ============================================== */
// true if statement uses exception handling

bool Statement::usesEH()
{
    class UsesEH : public StoppableVisitor
    {
    public:
        void visit(Statement *s)             {}
        void visit(TryCatchStatement *s)     { stop = true; }
        void visit(TryFinallyStatement *s)   { stop = true; }
        void visit(OnScopeStatement *s)      { stop = true; }
        void visit(SynchronizedStatement *s) { stop = true; }
    };

    UsesEH ueh;
    return walkPostorder(this, &ueh);
}

/* ============================================== */
// true if statement 'comes from' somewhere else, like a goto

bool Statement::comeFrom()
{
    class ComeFrom : public StoppableVisitor
    {
    public:
        void visit(Statement *s)        {}
        void visit(CaseStatement *s)    { stop = true; }
        void visit(DefaultStatement *s) { stop = true; }
        void visit(LabelStatement *s)   { stop = true; }
        void visit(AsmStatement *s)     { stop = true; }
    };

    ComeFrom cf;
    return walkPostorder(this, &cf);
}

/* ============================================== */
// Return true if statement has executable code.

bool Statement::hasCode()
{
    class HasCode : public StoppableVisitor
    {
    public:
        void visit(Statement *s)         { stop = true; }
        void visit(ExpStatement *s)      { stop = s->exp != NULL; }
        void visit(CompoundStatement *s) {}
        void visit(ScopeStatement *s)    {}
        void visit(ImportStatement *s)   {}
    };

    HasCode hc;
    return walkPostorder(this, &hc);
}

/* ============================================== */

/* Only valid after semantic analysis
 * If 'mustNotThrow' is true, generate an error if it throws
 */
int Statement::blockExit(FuncDeclaration *func, bool mustNotThrow)
{
    class BlockExit : public Visitor
    {
    public:
        FuncDeclaration *func;
        bool mustNotThrow;
        int result;

        BlockExit(FuncDeclaration *func, bool mustNotThrow)
            : func(func), mustNotThrow(mustNotThrow)
        {
            result = BEnone;
        }

        void visit(Statement *s)
        {
            printf("Statement::blockExit(%p)\n", s);
            printf("%s\n", s->toChars());
            assert(0);
            result = BEany;
        }

        void visit(ErrorStatement *s)
        {
            result = BEany;
        }

        void visit(ExpStatement *s)
        {
            result = BEfallthru;
            if (s->exp)
            {
                if (s->exp->op == TOKhalt)
                {
                    result = BEhalt;
                    return;
                }
                if (s->exp->op == TOKassert)
                {
                    AssertExp *a = (AssertExp *)s->exp;
                    if (a->e1->isBool(false))   // if it's an assert(0)
                    {
                        result = BEhalt;
                        return;
                    }
                }
                if (canThrow(s->exp, func, mustNotThrow))
                    result |= BEthrow;
            }
        }

        void visit(CompileStatement *s)
        {
            assert(global.errors);
            result = BEfallthru;
        }

        void visit(CompoundStatement *cs)
        {
            //printf("CompoundStatement::blockExit(%p) %d result = x%X\n", cs, cs->statements->dim, result);
            result = BEfallthru;
            Statement *slast = NULL;
            for (size_t i = 0; i < cs->statements->dim; i++)
            {
                Statement *s = (*cs->statements)[i];
                if (s)
                {
                    //printf("result = x%x\n", result);
                    //printf("s: %s\n", s->toChars());
                    if (global.params.warnings && result & BEfallthru && slast)
                    {
                        slast = slast->last();
                        if (slast && (slast->isCaseStatement() || slast->isDefaultStatement()) &&
                                     (s->isCaseStatement() || s->isDefaultStatement()))
                        {
                            // Allow if last case/default was empty
                            CaseStatement *sc = slast->isCaseStatement();
                            DefaultStatement *sd = slast->isDefaultStatement();
                            if (sc && (!sc->statement->hasCode() || sc->statement->isCaseStatement() || sc->statement->isErrorStatement()))
                                ;
                            else if (sd && (!sd->statement->hasCode() || sd->statement->isCaseStatement() || sd->statement->isErrorStatement()))
                                ;
                            else
                            {
                                const char *gototype = s->isCaseStatement() ? "case" : "default";
                                s->warning("switch case fallthrough - use 'goto %s;' if intended", gototype);
                            }
                        }
                    }

                    if (!(result & BEfallthru) && !s->comeFrom())
                    {
                        if (s->blockExit(func, mustNotThrow) != BEhalt && s->hasCode())
                            s->warning("statement is not reachable");
                    }
                    else
                    {
                        result &= ~BEfallthru;
                        result |= s->blockExit(func, mustNotThrow);
                    }
                    slast = s;
                }
            }
        }

        void visit(UnrolledLoopStatement *uls)
        {
            result = BEfallthru;
            for (size_t i = 0; i < uls->statements->dim; i++)
            {
                Statement *s = (*uls->statements)[i];
                if (s)
                {
                    int r = s->blockExit(func, mustNotThrow);
                    result |= r & ~(BEbreak | BEcontinue | BEfallthru);
                    if ((r & (BEfallthru | BEcontinue | BEbreak)) == 0)
                        result &= ~BEfallthru;
                }
            }
        }

        void visit(ScopeStatement *s)
        {
            //printf("ScopeStatement::blockExit(%p)\n", s->statement);
            result = s->statement ? s->statement->blockExit(func, mustNotThrow) : BEfallthru;
        }

        void visit(WhileStatement *s)
        {
            assert(global.errors);
            result = BEfallthru;
        }

        void visit(DoStatement *s)
        {
            if (s->_body)
            {
                result = s->_body->blockExit(func, mustNotThrow);
                if (result == BEbreak)
                {
                    result = BEfallthru;
                    return;
                }
                if (result & BEcontinue)
                    result |= BEfallthru;
            }
            else
                result = BEfallthru;
            if (result & BEfallthru)
            {
                if (canThrow(s->condition, func, mustNotThrow))
                    result |= BEthrow;
                if (!(result & BEbreak) && s->condition->isBool(true))
                    result &= ~BEfallthru;
            }
            result &= ~(BEbreak | BEcontinue);
        }

        void visit(ForStatement *s)
        {
            result = BEfallthru;
            if (s->_init)
            {
                result = s->_init->blockExit(func, mustNotThrow);
                if (!(result & BEfallthru))
                    return;
            }
            if (s->condition)
            {
                if (canThrow(s->condition, func, mustNotThrow))
                    result |= BEthrow;
                if (s->condition->isBool(true))
                    result &= ~BEfallthru;
                else if (s->condition->isBool(false))
                    return;
            }
            else
                result &= ~BEfallthru;  // the body must do the exiting
            if (s->_body)
            {
                int r = s->_body->blockExit(func, mustNotThrow);
                if (r & (BEbreak | BEgoto))
                    result |= BEfallthru;
                result |= r & ~(BEfallthru | BEbreak | BEcontinue);
            }
            if (s->increment && canThrow(s->increment, func, mustNotThrow))
                result |= BEthrow;
        }

        void visit(ForeachStatement *s)
        {
            result = BEfallthru;
            if (canThrow(s->aggr, func, mustNotThrow))
                result |= BEthrow;
            if (s->_body)
                result |= s->_body->blockExit(func, mustNotThrow) & ~(BEbreak | BEcontinue);
        }

        void visit(ForeachRangeStatement *s)
        {
            assert(global.errors);
            result = BEfallthru;
        }

        void visit(IfStatement *s)
        {
            //printf("IfStatement::blockExit(%p)\n", s);

            result = BEnone;
            if (canThrow(s->condition, func, mustNotThrow))
                result |= BEthrow;
            if (s->condition->isBool(true))
            {
                if (s->ifbody)
                    result |= s->ifbody->blockExit(func, mustNotThrow);
                else
                    result |= BEfallthru;
            }
            else if (s->condition->isBool(false))
            {
                if (s->elsebody)
                    result |= s->elsebody->blockExit(func, mustNotThrow);
                else
                    result |= BEfallthru;
            }
            else
            {
                if (s->ifbody)
                    result |= s->ifbody->blockExit(func, mustNotThrow);
                else
                    result |= BEfallthru;
                if (s->elsebody)
                    result |= s->elsebody->blockExit(func, mustNotThrow);
                else
                    result |= BEfallthru;
            }
            //printf("IfStatement::blockExit(%p) = x%x\n", s, result);
        }

        void visit(ConditionalStatement *s)
        {
            result = s->ifbody->blockExit(func, mustNotThrow);
            if (s->elsebody)
                result |= s->elsebody->blockExit(func, mustNotThrow);
        }

        void visit(PragmaStatement *s)
        {
            result = BEfallthru;
        }

        void visit(StaticAssertStatement *s)
        {
            result = BEfallthru;
        }

        void visit(SwitchStatement *s)
        {
            result = BEnone;
            if (canThrow(s->condition, func, mustNotThrow))
                result |= BEthrow;
            if (s->_body)
            {
                result |= s->_body->blockExit(func, mustNotThrow);
                if (result & BEbreak)
                {
                    result |= BEfallthru;
                    result &= ~BEbreak;
                }
            }
            else
                result |= BEfallthru;
        }

        void visit(CaseStatement *s)
        {
            result = s->statement->blockExit(func, mustNotThrow);
        }

        void visit(DefaultStatement *s)
        {
            result = s->statement->blockExit(func, mustNotThrow);
        }

        void visit(GotoDefaultStatement *s)
        {
            result = BEgoto;
        }

        void visit(GotoCaseStatement *s)
        {
            result = BEgoto;
        }

        void visit(SwitchErrorStatement *s)
        {
            // Switch errors are non-recoverable
            result = BEhalt;
        }

        void visit(ReturnStatement *s)
        {
            result = BEreturn;
            if (s->exp && canThrow(s->exp, func, mustNotThrow))
                result |= BEthrow;
        }

        void visit(BreakStatement *s)
        {
            //printf("BreakStatement::blockExit(%p) = x%x\n", s, s->ident ? BEgoto : BEbreak);
            result = s->ident ? BEgoto : BEbreak;
        }

        void visit(ContinueStatement *s)
        {
            result = s->ident ? BEgoto : BEcontinue;
        }

        void visit(SynchronizedStatement *s)
        {
            result = s->_body ? s->_body->blockExit(func, mustNotThrow) : BEfallthru;
        }

        void visit(WithStatement *s)
        {
            result = BEnone;
            if (canThrow(s->exp, func, mustNotThrow))
                result = BEthrow;
            if (s->_body)
                result |= s->_body->blockExit(func, mustNotThrow);
            else
                result |= BEfallthru;
        }

        void visit(TryCatchStatement *s)
        {
            assert(s->_body);
            result = s->_body->blockExit(func, false);

            int catchresult = 0;
            for (size_t i = 0; i < s->catches->dim; i++)
            {
                Catch *c = (*s->catches)[i];
                if (c->type == Type::terror)
                    continue;

                int cresult;
                if (c->handler)
                    cresult = c->handler->blockExit(func, mustNotThrow);
                else
                    cresult = BEfallthru;

                /* If we're catching Object, then there is no throwing
                 */
                Identifier *id = c->type->toBasetype()->isClassHandle()->ident;
                if (c->internalCatch && (cresult & BEfallthru))
                {
                    // Bugzilla 11542: leave blockExit flags of the body
                    cresult &= ~BEfallthru;
                }
                else if (id == Id::Object || id == Id::Throwable)
                {
                    result &= ~(BEthrow | BEerrthrow);
                }
                else if (id == Id::Exception)
                {
                    result &= ~BEthrow;
                }
                catchresult |= cresult;
            }
            if (mustNotThrow && (result & BEthrow))
            {
                // now explain why this is nothrow
                s->_body->blockExit(func, mustNotThrow);
            }
            result |= catchresult;
        }

        void visit(TryFinallyStatement *s)
        {
            result = BEfallthru;
            if (s->_body)
                result = s->_body->blockExit(func, false);

            // check finally body as well, it may throw (bug #4082)
            int finalresult = BEfallthru;
            if (s->finalbody)
                finalresult = s->finalbody->blockExit(func, false);

            // If either body or finalbody halts
            if (result == BEhalt)
                finalresult = BEnone;
            if (finalresult == BEhalt)
                result = BEnone;

            if (mustNotThrow)
            {
                // now explain why this is nothrow
                if (s->_body && (result & BEthrow))
                    s->_body->blockExit(func, mustNotThrow);
                if (s->finalbody && (finalresult & BEthrow))
                    s->finalbody->blockExit(func, mustNotThrow);
            }

        #if 0
            // Bugzilla 13201: Mask to prevent spurious warnings for
            // destructor call, exit of synchronized statement, etc.
            if (result == BEhalt && finalresult != BEhalt && s->finalbody &&
                s->finalbody->hasCode())
            {
                s->finalbody->warning("statement is not reachable");
            }
        #endif

            if (!(finalresult & BEfallthru))
                result &= ~BEfallthru;
            result |= finalresult & ~BEfallthru;
        }

        void visit(OnScopeStatement *s)
        {
            // At this point, this statement is just an empty placeholder
            result = BEfallthru;
        }

        void visit(ThrowStatement *s)
        {
            if (s->internalThrow)
            {
                // Bugzilla 8675: Allow throwing 'Throwable' object even if mustNotThrow.
                result = BEfallthru;
                return;
            }

            Type *t = s->exp->type->toBasetype();
            ClassDeclaration *cd = t->isClassHandle();
            assert(cd);

            if (cd == ClassDeclaration::errorException ||
                ClassDeclaration::errorException->isBaseOf(cd, NULL))
            {
                result = BEerrthrow;
                return;
            }
            if (mustNotThrow)
                s->error("%s is thrown but not caught", s->exp->type->toChars());

            result = BEthrow;
        }

        void visit(GotoStatement *s)
        {
            //printf("GotoStatement::blockExit(%p)\n", s);
            result = BEgoto;
        }

        void visit(LabelStatement *s)
        {
            //printf("LabelStatement::blockExit(%p)\n", s);
            result = s->statement ? s->statement->blockExit(func, mustNotThrow) : BEfallthru;
            if (s->breaks)
                result |= BEfallthru;
        }

        void visit(CompoundAsmStatement *s)
        {
            if (mustNotThrow && !(s->stc & STCnothrow))
                s->deprecation("asm statement is assumed to throw - mark it with 'nothrow' if it does not");

            // Assume the worst
            result = BEfallthru | BEreturn | BEgoto | BEhalt;
            if (!(s->stc & STCnothrow)) result |= BEthrow;
        }

        void visit(ImportStatement *s)
        {
            result = BEfallthru;
        }
    };

    BlockExit be(func, mustNotThrow);
    accept(&be);
    return be.result;
}

Statement *Statement::last()
{
    return this;
}

/****************************************
 * If this statement has code that needs to run in a finally clause
 * at the end of the current scope, return that code in the form of
 * a Statement.
 * Output:
 *      *sentry         code executed upon entry to the scope
 *      *sexception     code executed upon exit from the scope via exception
 *      *sfinally       code executed in finally block
 */

Statement *Statement::scopeCode(Scope *sc, Statement **sentry, Statement **sexception, Statement **sfinally)
{
    //printf("Statement::scopeCode()\n");
    //print();
    *sentry = NULL;
    *sexception = NULL;
    *sfinally = NULL;
    return this;
}

/*********************************
 * Flatten out the scope by presenting the statement
 * as an array of statements.
 * Returns NULL if no flattening necessary.
 */

Statements *Statement::flatten(Scope *sc)
{
    return NULL;
}


/******************************** ErrorStatement ***************************/

ErrorStatement::ErrorStatement()
    : Statement(Loc())
{
    assert(global.gaggedErrors || global.errors);
}

Statement *ErrorStatement::syntaxCopy()
{
    return this;
}

/******************************** PeelStatement ***************************/

PeelStatement::PeelStatement(Statement *s)
    : Statement(s->loc)
{
    this->s = s;
}

/******************************** ExpStatement ***************************/

ExpStatement::ExpStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    this->exp = exp;
}

ExpStatement::ExpStatement(Loc loc, Dsymbol *declaration)
    : Statement(loc)
{
    this->exp = new DeclarationExp(loc, declaration);
}

ExpStatement *ExpStatement::create(Loc loc, Expression *exp)
{
    return new ExpStatement(loc, exp);
}

Statement *ExpStatement::syntaxCopy()
{
    return new ExpStatement(loc, exp ? exp->syntaxCopy() : NULL);
}

Statement *ExpStatement::scopeCode(Scope *sc, Statement **sentry, Statement **sexception, Statement **sfinally)
{
    //printf("ExpStatement::scopeCode()\n");
    //print();

    *sentry = NULL;
    *sexception = NULL;
    *sfinally = NULL;

    if (exp)
    {
        if (exp->op == TOKdeclaration)
        {
            DeclarationExp *de = (DeclarationExp *)(exp);
            VarDeclaration *v = de->declaration->isVarDeclaration();
            if (v && !v->isDataseg())
            {
                if (v->needsScopeDtor())
                {
                    //printf("dtor is: "); v->edtor->print();
                    *sfinally = new DtorExpStatement(loc, v->edtor, v);
                    v->storage_class |= STCnodtor; // don't add in dtor again
                }
            }
        }
    }
    return this;
}

/****************************************
 * Convert TemplateMixin members (== Dsymbols) to Statements.
 */
Statement *toStatement(Dsymbol *s)
{
    class ToStmt : public Visitor
    {
    public:
        Statement *result;

        ToStmt()
        {
            this->result = NULL;
        }

        Statement *visitMembers(Loc loc, Dsymbols *a)
        {
            if (!a)
                return NULL;

            Statements *statements = new Statements();
            for (size_t i = 0; i < a->dim; i++)
            {
                statements->push(toStatement((*a)[i]));
            }
            return new CompoundStatement(loc, statements);
        }

        void visit(Dsymbol *s)
        {
            ::error(Loc(), "Internal Compiler Error: cannot mixin %s %s\n", s->kind(), s->toChars());
            result = new ErrorStatement();
        }

        void visit(TemplateMixin *tm)
        {
            Statements *a = new Statements();
            for (size_t i = 0; i < tm->members->dim; i++)
            {
                Statement *s = toStatement((*tm->members)[i]);
                if (s)
                    a->push(s);
            }
            result = new CompoundStatement(tm->loc, a);
        }

        /* An actual declaration symbol will be converted to DeclarationExp
         * with ExpStatement.
         */
        Statement *declStmt(Dsymbol *s)
        {
            DeclarationExp *de = new DeclarationExp(s->loc, s);
            de->type = Type::tvoid;     // avoid repeated semantic
            return new ExpStatement(s->loc, de);
        }
        void visit(VarDeclaration *d)       { result = declStmt(d); }
        void visit(AggregateDeclaration *d) { result = declStmt(d); }
        void visit(FuncDeclaration *d)      { result = declStmt(d); }
        void visit(EnumDeclaration *d)      { result = declStmt(d); }
        void visit(AliasDeclaration *d)     { result = declStmt(d); }
        void visit(TemplateDeclaration *d)  { result = declStmt(d); }

        /* All attributes have been already picked by the semantic analysis of
         * 'bottom' declarations (function, struct, class, etc).
         * So we don't have to copy them.
         */
        void visit(StorageClassDeclaration *d)  { result = visitMembers(d->loc, d->decl); }
        void visit(DeprecatedDeclaration *d)    { result = visitMembers(d->loc, d->decl); }
        void visit(LinkDeclaration *d)          { result = visitMembers(d->loc, d->decl); }
        void visit(ProtDeclaration *d)          { result = visitMembers(d->loc, d->decl); }
        void visit(AlignDeclaration *d)         { result = visitMembers(d->loc, d->decl); }
        void visit(UserAttributeDeclaration *d) { result = visitMembers(d->loc, d->decl); }

        void visit(StaticAssert *s) {}
        void visit(Import *s) {}
        void visit(PragmaDeclaration *d) {}

        void visit(ConditionalDeclaration *d)
        {
            result = visitMembers(d->loc, d->include(NULL, NULL));
        }

        void visit(CompileDeclaration *d)
        {
            result = visitMembers(d->loc, d->include(NULL, NULL));
        }
    };

    if (!s)
        return NULL;

    ToStmt v;
    s->accept(&v);
    return v.result;
}

Statements *ExpStatement::flatten(Scope *sc)
{
    /* Bugzilla 14243: expand template mixin in statement scope
     * to handle variable destructors.
     */
    if (exp && exp->op == TOKdeclaration)
    {
        Dsymbol *d = ((DeclarationExp *)exp)->declaration;
        if (TemplateMixin *tm = d->isTemplateMixin())
        {
            Expression *e = exp->semantic(sc);
            if (e->op == TOKerror || tm->errors)
            {
                Statements *a = new Statements();
                a->push(new ErrorStatement());
                return a;
            }
            assert(tm->members);

            Statement *s = toStatement(tm);
        #if 0
            OutBuffer buf;
            buf.doindent = 1;
            HdrGenState hgs;
            hgs.hdrgen = true;
            toCBuffer(s, &buf, &hgs);
            printf("tm ==> s = %s\n", buf.peekString());
        #endif
            Statements *a = new Statements();
            a->push(s);
            return a;
        }
    }
    return NULL;
}

/******************************** DtorExpStatement ***************************/

DtorExpStatement::DtorExpStatement(Loc loc, Expression *exp, VarDeclaration *v)
    : ExpStatement(loc, exp)
{
    this->var = v;
}

Statement *DtorExpStatement::syntaxCopy()
{
    return new DtorExpStatement(loc, exp ? exp->syntaxCopy() : NULL, var);
}

/******************************** CompileStatement ***************************/

CompileStatement::CompileStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    this->exp = exp;
}

Statement *CompileStatement::syntaxCopy()
{
    return new CompileStatement(loc, exp->syntaxCopy());
}

Statements *CompileStatement::flatten(Scope *sc)
{
    //printf("CompileStatement::flatten() %s\n", exp->toChars());
    sc = sc->startCTFE();
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    sc = sc->endCTFE();

    Statements *a = new Statements();
    if (exp->op != TOKerror)
    {
        Expression *e = exp->ctfeInterpret();
        StringExp *se = e->toStringExp();
        if (!se)
           error("argument to mixin must be a string, not (%s) of type %s", exp->toChars(), exp->type->toChars());
        else
        {
            se = se->toUTF8(sc);
            unsigned errors = global.errors;
            Parser p(loc, sc->_module, (utf8_t *)se->string, se->len, 0);
            p.nextToken();

            while (p.token.value != TOKeof)
            {
                Statement *s = p.parseStatement(PSsemi | PScurlyscope);
                if (!s || p.errors)
                {
                    assert(!p.errors || global.errors != errors); // make sure we caught all the cases
                    goto Lerror;
                }
                a->push(s);
            }
            return a;
        }
    }
Lerror:
    a->push(new ErrorStatement());
    return a;
}

/******************************** CompoundStatement ***************************/

CompoundStatement::CompoundStatement(Loc loc, Statements *s)
    : Statement(loc)
{
    statements = s;
}

CompoundStatement::CompoundStatement(Loc loc, Statement *s1, Statement *s2)
    : Statement(loc)
{
    statements = new Statements();
    statements->reserve(2);
    statements->push(s1);
    statements->push(s2);
}

CompoundStatement::CompoundStatement(Loc loc, Statement *s1)
    : Statement(loc)
{
    statements = new Statements();
    statements->push(s1);
}

CompoundStatement *CompoundStatement::create(Loc loc, Statement *s1, Statement *s2)
{
    return new CompoundStatement(loc, s1, s2);
}

Statement *CompoundStatement::syntaxCopy()
{
    Statements *a = new Statements();
    a->setDim(statements->dim);
    for (size_t i = 0; i < statements->dim; i++)
    {
        Statement *s = (*statements)[i];
        (*a)[i] = s ? s->syntaxCopy() : NULL;
    }
    return new CompoundStatement(loc, a);
}

Statements *CompoundStatement::flatten(Scope *sc)
{
    return statements;
}

ReturnStatement *CompoundStatement::isReturnStatement()
{
    ReturnStatement *rs = NULL;

    for (size_t i = 0; i < statements->dim; i++)
    {
        Statement *s = (*statements)[i];
        if (s)
        {
            rs = s->isReturnStatement();
            if (rs)
                break;
        }
    }
    return rs;
}

Statement *CompoundStatement::last()
{
    Statement *s = NULL;

    for (size_t i = statements->dim; i; --i)
    {   s = (*statements)[i - 1];
        if (s)
        {
            s = s->last();
            if (s)
                break;
        }
    }
    return s;
}

/******************************** CompoundDeclarationStatement ***************************/

CompoundDeclarationStatement::CompoundDeclarationStatement(Loc loc, Statements *s)
    : CompoundStatement(loc, s)
{
    statements = s;
}

Statement *CompoundDeclarationStatement::syntaxCopy()
{
    Statements *a = new Statements();
    a->setDim(statements->dim);
    for (size_t i = 0; i < statements->dim; i++)
    {
        Statement *s = (*statements)[i];
        (*a)[i] = s ? s->syntaxCopy() : NULL;
    }
    return new CompoundDeclarationStatement(loc, a);
}

/**************************** UnrolledLoopStatement ***************************/

UnrolledLoopStatement::UnrolledLoopStatement(Loc loc, Statements *s)
    : Statement(loc)
{
    statements = s;
}

Statement *UnrolledLoopStatement::syntaxCopy()
{
    Statements *a = new Statements();
    a->setDim(statements->dim);
    for (size_t i = 0; i < statements->dim; i++)
    {
        Statement *s = (*statements)[i];
        (*a)[i] = s ? s->syntaxCopy() : NULL;
    }
    return new UnrolledLoopStatement(loc, a);
}

bool UnrolledLoopStatement::hasBreak()
{
    return true;
}

bool UnrolledLoopStatement::hasContinue()
{
    return true;
}

/******************************** ScopeStatement ***************************/

ScopeStatement::ScopeStatement(Loc loc, Statement *s, Loc endloc)
    : Statement(loc)
{
    this->statement = s;
    this->endloc = endloc;
}

Statement *ScopeStatement::syntaxCopy()
{
    return new ScopeStatement(loc, statement ? statement->syntaxCopy() : NULL, endloc);
}

ReturnStatement *ScopeStatement::isReturnStatement()
{
    if (statement)
        return statement->isReturnStatement();
    return NULL;
}

bool ScopeStatement::hasBreak()
{
    //printf("ScopeStatement::hasBreak() %s\n", toChars());
    return statement ? statement->hasBreak() : false;
}

bool ScopeStatement::hasContinue()
{
    return statement ? statement->hasContinue() : false;
}

/******************************** WhileStatement ***************************/

WhileStatement::WhileStatement(Loc loc, Expression *c, Statement *b, Loc endloc)
    : Statement(loc)
{
    condition = c;
    _body = b;
    this->endloc = endloc;
}

Statement *WhileStatement::syntaxCopy()
{
    return new WhileStatement(loc,
        condition->syntaxCopy(),
        _body ? _body->syntaxCopy() : NULL,
        endloc);
}

bool WhileStatement::hasBreak()
{
    return true;
}

bool WhileStatement::hasContinue()
{
    return true;
}

/******************************** DoStatement ***************************/

DoStatement::DoStatement(Loc loc, Statement *b, Expression *c, Loc endloc)
    : Statement(loc)
{
    _body = b;
    condition = c;
    this->endloc = endloc;
}

Statement *DoStatement::syntaxCopy()
{
    return new DoStatement(loc,
        _body ? _body->syntaxCopy() : NULL,
        condition->syntaxCopy(),
        endloc);
}

bool DoStatement::hasBreak()
{
    return true;
}

bool DoStatement::hasContinue()
{
    return true;
}

/******************************** ForStatement ***************************/

ForStatement::ForStatement(Loc loc, Statement *init, Expression *condition, Expression *increment, Statement *body, Loc endloc)
    : Statement(loc)
{
    this->_init = init;
    this->condition = condition;
    this->increment = increment;
    this->_body = body;
    this->endloc = endloc;
    this->relatedLabeled = NULL;
}

Statement *ForStatement::syntaxCopy()
{
    return new ForStatement(loc,
        _init ? _init->syntaxCopy() : NULL,
        condition ? condition->syntaxCopy() : NULL,
        increment ? increment->syntaxCopy() : NULL,
        _body->syntaxCopy(),
        endloc);
}

Statement *ForStatement::scopeCode(Scope *sc, Statement **sentry, Statement **sexception, Statement **sfinally)
{
    //printf("ForStatement::scopeCode()\n");
    Statement::scopeCode(sc, sentry, sexception, sfinally);
    return this;
}

bool ForStatement::hasBreak()
{
    //printf("ForStatement::hasBreak()\n");
    return true;
}

bool ForStatement::hasContinue()
{
    return true;
}

/******************************** ForeachStatement ***************************/

ForeachStatement::ForeachStatement(Loc loc, TOK op, Parameters *parameters,
        Expression *aggr, Statement *body, Loc endloc)
    : Statement(loc)
{
    this->op = op;
    this->parameters = parameters;
    this->aggr = aggr;
    this->_body = body;
    this->endloc = endloc;

    this->key = NULL;
    this->value = NULL;

    this->func = NULL;

    this->cases = NULL;
    this->gotos = NULL;
}

Statement *ForeachStatement::syntaxCopy()
{
    return new ForeachStatement(loc, op,
        Parameter::arraySyntaxCopy(parameters),
        aggr->syntaxCopy(),
        _body ? _body->syntaxCopy() : NULL,
        endloc);
}

bool ForeachStatement::checkForArgTypes()
{
    bool result = false;

    for (size_t i = 0; i < parameters->dim; i++)
    {
        Parameter *p = (*parameters)[i];
        if (!p->type)
        {
            error("cannot infer type for %s", p->ident->toChars());
            p->type = Type::terror;
            result = true;
        }
    }
    return result;
}

bool ForeachStatement::hasBreak()
{
    return true;
}

bool ForeachStatement::hasContinue()
{
    return true;
}

/**************************** ForeachRangeStatement ***************************/


ForeachRangeStatement::ForeachRangeStatement(Loc loc, TOK op, Parameter *prm,
        Expression *lwr, Expression *upr, Statement *body, Loc endloc)
    : Statement(loc)
{
    this->op = op;
    this->prm = prm;
    this->lwr = lwr;
    this->upr = upr;
    this->_body = body;
    this->endloc = endloc;

    this->key = NULL;
}

Statement *ForeachRangeStatement::syntaxCopy()
{
    return new ForeachRangeStatement(loc, op,
        prm->syntaxCopy(),
        lwr->syntaxCopy(),
        upr->syntaxCopy(),
        _body ? _body->syntaxCopy() : NULL,
        endloc);
}

bool ForeachRangeStatement::hasBreak()
{
    return true;
}

bool ForeachRangeStatement::hasContinue()
{
    return true;
}

/******************************** IfStatement ***************************/

IfStatement::IfStatement(Loc loc, Parameter *prm, Expression *condition, Statement *ifbody, Statement *elsebody, Loc endloc)
    : Statement(loc)
{
    this->prm = prm;
    this->condition = condition;
    this->ifbody = ifbody;
    this->elsebody = elsebody;
    this->endloc = endloc;
    this->match = NULL;
}

Statement *IfStatement::syntaxCopy()
{
    return new IfStatement(loc,
        prm ? prm->syntaxCopy() : NULL,
        condition->syntaxCopy(),
        ifbody ? ifbody->syntaxCopy() : NULL,
        elsebody ? elsebody->syntaxCopy() : NULL,
        endloc);
}

/******************************** ConditionalStatement ***************************/

ConditionalStatement::ConditionalStatement(Loc loc, Condition *condition, Statement *ifbody, Statement *elsebody)
    : Statement(loc)
{
    this->condition = condition;
    this->ifbody = ifbody;
    this->elsebody = elsebody;
}

Statement *ConditionalStatement::syntaxCopy()
{
    return new ConditionalStatement(loc,
        condition->syntaxCopy(),
        ifbody->syntaxCopy(),
        elsebody ? elsebody->syntaxCopy() : NULL);
}

Statements *ConditionalStatement::flatten(Scope *sc)
{
    Statement *s;

    //printf("ConditionalStatement::flatten()\n");
    if (condition->include(sc, NULL))
    {
        DebugCondition *dc = condition->isDebugCondition();
        if (dc)
            s = new DebugStatement(loc, ifbody);
        else
            s = ifbody;
    }
    else
        s = elsebody;

    Statements *a = new Statements();
    a->push(s);
    return a;
}

/******************************** PragmaStatement ***************************/

PragmaStatement::PragmaStatement(Loc loc, Identifier *ident, Expressions *args, Statement *body)
    : Statement(loc)
{
    this->ident = ident;
    this->args = args;
    this->_body = body;
}

Statement *PragmaStatement::syntaxCopy()
{
    return new PragmaStatement(loc, ident,
        Expression::arraySyntaxCopy(args),
        _body ? _body->syntaxCopy() : NULL);
}

/******************************** StaticAssertStatement ***************************/

StaticAssertStatement::StaticAssertStatement(StaticAssert *sa)
    : Statement(sa->loc)
{
    this->sa = sa;
}

Statement *StaticAssertStatement::syntaxCopy()
{
    return new StaticAssertStatement((StaticAssert *)sa->syntaxCopy(NULL));
}

/******************************** SwitchStatement ***************************/

SwitchStatement::SwitchStatement(Loc loc, Expression *c, Statement *b, bool isFinal)
    : Statement(loc)
{
    this->condition = c;
    this->_body = b;
    this->isFinal = isFinal;
    sdefault = NULL;
    tf = NULL;
    cases = NULL;
    hasNoDefault = 0;
    hasVars = 0;
}

Statement *SwitchStatement::syntaxCopy()
{
    return new SwitchStatement(loc,
        condition->syntaxCopy(),
        _body->syntaxCopy(),
        isFinal);
}

bool SwitchStatement::hasBreak()
{
    return true;
}

static bool checkVar(SwitchStatement *s, VarDeclaration *vd)
{
    if (!vd || vd->isDataseg() || (vd->storage_class & STCmanifest))
        return false;

    VarDeclaration *last = s->lastVar;
    while (last && last != vd)
        last = last->lastVar;
    if (last == vd)
    {
        // All good, the label's scope has no variables
    }
    else if (vd->storage_class & STCexptemp)
    {
        // Lifetime ends at end of expression, so no issue with skipping the statement
    }
    else if (vd->ident == Id::withSym)
    {
        s->error("'switch' skips declaration of 'with' temporary at %s", vd->loc.toChars());
        return true;
    }
    else
    {
        s->error("'switch' skips declaration of variable %s at %s", vd->toPrettyChars(), vd->loc.toChars());
        return true;
    }

    return false;
}

bool SwitchStatement::checkLabel()
{
    if (sdefault && checkVar(this, sdefault->lastVar))
        return true;

    for (size_t i = 0; i < cases->dim; i++)
    {
        CaseStatement *scase = (*cases)[i];
        if (scase && checkVar(this, scase->lastVar))
            return true;
    }
    return false;
}

/******************************** CaseStatement ***************************/

CaseStatement::CaseStatement(Loc loc, Expression *exp, Statement *s)
    : Statement(loc)
{
    this->exp = exp;
    this->statement = s;
    index = 0;
}

Statement *CaseStatement::syntaxCopy()
{
    return new CaseStatement(loc,
        exp->syntaxCopy(),
        statement->syntaxCopy());
}

int CaseStatement::compare(RootObject *obj)
{
    // Sort cases so we can do an efficient lookup
    CaseStatement *cs2 = (CaseStatement *)(obj);

    return exp->compare(cs2->exp);
}

/******************************** CaseRangeStatement ***************************/


CaseRangeStatement::CaseRangeStatement(Loc loc, Expression *first,
        Expression *last, Statement *s)
    : Statement(loc)
{
    this->first = first;
    this->last = last;
    this->statement = s;
}

Statement *CaseRangeStatement::syntaxCopy()
{
    return new CaseRangeStatement(loc,
        first->syntaxCopy(),
        last->syntaxCopy(),
        statement->syntaxCopy());
}

/******************************** DefaultStatement ***************************/

DefaultStatement::DefaultStatement(Loc loc, Statement *s)
    : Statement(loc)
{
    this->statement = s;
}

Statement *DefaultStatement::syntaxCopy()
{
    return new DefaultStatement(loc, statement->syntaxCopy());
}

/******************************** GotoDefaultStatement ***************************/

GotoDefaultStatement::GotoDefaultStatement(Loc loc)
    : Statement(loc)
{
    sw = NULL;
}

Statement *GotoDefaultStatement::syntaxCopy()
{
    return new GotoDefaultStatement(loc);
}

/******************************** GotoCaseStatement ***************************/

GotoCaseStatement::GotoCaseStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    cs = NULL;
    this->exp = exp;
}

Statement *GotoCaseStatement::syntaxCopy()
{
    return new GotoCaseStatement(loc, exp ? exp->syntaxCopy() : NULL);
}

/******************************** SwitchErrorStatement ***************************/

SwitchErrorStatement::SwitchErrorStatement(Loc loc)
    : Statement(loc)
{
}

/******************************** ReturnStatement ***************************/

ReturnStatement::ReturnStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    this->exp = exp;
    this->caseDim = 0;
}

Statement *ReturnStatement::syntaxCopy()
{
    return new ReturnStatement(loc, exp ? exp->syntaxCopy() : NULL);
}

/******************************** BreakStatement ***************************/

BreakStatement::BreakStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
}

Statement *BreakStatement::syntaxCopy()
{
    return new BreakStatement(loc, ident);
}

/******************************** ContinueStatement ***************************/

ContinueStatement::ContinueStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
}

Statement *ContinueStatement::syntaxCopy()
{
    return new ContinueStatement(loc, ident);
}

/******************************** SynchronizedStatement ***************************/

SynchronizedStatement::SynchronizedStatement(Loc loc, Expression *exp, Statement *body)
    : Statement(loc)
{
    this->exp = exp;
    this->_body = body;
}

Statement *SynchronizedStatement::syntaxCopy()
{
    return new SynchronizedStatement(loc,
        exp ? exp->syntaxCopy() : NULL,
        _body ? _body->syntaxCopy() : NULL);
}

bool SynchronizedStatement::hasBreak()
{
    return false; //true;
}

bool SynchronizedStatement::hasContinue()
{
    return false; //true;
}

/******************************** WithStatement ***************************/

WithStatement::WithStatement(Loc loc, Expression *exp, Statement *body, Loc endloc)
    : Statement(loc)
{
    this->exp = exp;
    this->_body = body;
    this->endloc = endloc;
    wthis = NULL;
}

Statement *WithStatement::syntaxCopy()
{
    return new WithStatement(loc,
        exp->syntaxCopy(),
        _body ? _body->syntaxCopy() : NULL, endloc);
}

/******************************** TryCatchStatement ***************************/

TryCatchStatement::TryCatchStatement(Loc loc, Statement *body, Catches *catches)
    : Statement(loc)
{
    this->_body = body;
    this->catches = catches;
}

Statement *TryCatchStatement::syntaxCopy()
{
    Catches *a = new Catches();
    a->setDim(catches->dim);
    for (size_t i = 0; i < a->dim; i++)
    {
        Catch *c = (*catches)[i];
        (*a)[i] = c->syntaxCopy();
    }
    return new TryCatchStatement(loc, _body->syntaxCopy(), a);
}

bool TryCatchStatement::hasBreak()
{
    return false;
}

/******************************** Catch ***************************/

Catch::Catch(Loc loc, Type *t, Identifier *id, Statement *handler)
{
    //printf("Catch(%s, loc = %s)\n", id->toChars(), loc.toChars());
    this->loc = loc;
    this->type = t;
    this->ident = id;
    this->handler = handler;
    var = NULL;
    internalCatch = false;
}

Catch *Catch::syntaxCopy()
{
    Catch *c = new Catch(loc,
        type ? type->syntaxCopy() : NULL,
        ident,
        (handler ? handler->syntaxCopy() : NULL));
    c->internalCatch = internalCatch;
    return c;
}

/****************************** TryFinallyStatement ***************************/

TryFinallyStatement::TryFinallyStatement(Loc loc, Statement *body, Statement *finalbody)
    : Statement(loc)
{
    this->_body = body;
    this->finalbody = finalbody;
}

TryFinallyStatement *TryFinallyStatement::create(Loc loc, Statement *body, Statement *finalbody)
{
    return new TryFinallyStatement(loc, body, finalbody);
}

Statement *TryFinallyStatement::syntaxCopy()
{
    return new TryFinallyStatement(loc,
        _body->syntaxCopy(), finalbody->syntaxCopy());
}

bool TryFinallyStatement::hasBreak()
{
    return false; //true;
}

bool TryFinallyStatement::hasContinue()
{
    return false; //true;
}

/****************************** OnScopeStatement ***************************/

OnScopeStatement::OnScopeStatement(Loc loc, TOK tok, Statement *statement)
    : Statement(loc)
{
    this->tok = tok;
    this->statement = statement;
}

Statement *OnScopeStatement::syntaxCopy()
{
    return new OnScopeStatement(loc, tok, statement->syntaxCopy());
}

Statement *OnScopeStatement::scopeCode(Scope *sc, Statement **sentry, Statement **sexception, Statement **sfinally)
{
    //printf("OnScopeStatement::scopeCode()\n");
    //print();
    *sentry = NULL;
    *sexception = NULL;
    *sfinally = NULL;

    Statement *s = new PeelStatement(statement);

    switch (tok)
    {
        case TOKon_scope_exit:
            *sfinally = s;
            break;

        case TOKon_scope_failure:
            *sexception = s;
            break;

        case TOKon_scope_success:
        {
            /* Create:
             *  sentry:   bool x = false;
             *  sexception:    x = true;
             *  sfinally: if (!x) statement;
             */
            VarDeclaration *v = copyToTemp(0, "__os", new IntegerExp(Loc(), 0, Type::tbool));
            *sentry = new ExpStatement(loc, v);

            Expression *e = new IntegerExp(Loc(), 1, Type::tbool);
            e = new AssignExp(Loc(), new VarExp(Loc(), v), e);
            *sexception = new ExpStatement(Loc(), e);

            e = new VarExp(Loc(), v);
            e = new NotExp(Loc(), e);
            *sfinally = new IfStatement(Loc(), NULL, e, s, NULL, Loc());

            break;
        }

        default:
            assert(0);
    }
    return NULL;
}

/******************************** ThrowStatement ***************************/

ThrowStatement::ThrowStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    this->exp = exp;
    this->internalThrow = false;
}

Statement *ThrowStatement::syntaxCopy()
{
    ThrowStatement *s = new ThrowStatement(loc, exp->syntaxCopy());
    s->internalThrow = internalThrow;
    return s;
}

/******************************** DebugStatement **************************/

DebugStatement::DebugStatement(Loc loc, Statement *statement)
    : Statement(loc)
{
    this->statement = statement;
}

Statement *DebugStatement::syntaxCopy()
{
    return new DebugStatement(loc,
        statement ? statement->syntaxCopy() : NULL);
}

Statements *DebugStatement::flatten(Scope *sc)
{
    Statements *a = statement ? statement->flatten(sc) : NULL;
    if (a)
    {
        for (size_t i = 0; i < a->dim; i++)
        {   Statement *s = (*a)[i];

            s = new DebugStatement(loc, s);
            (*a)[i] = s;
        }
    }

    return a;
}

/******************************** GotoStatement ***************************/

GotoStatement::GotoStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
    this->label = NULL;
    this->tf = NULL;
    this->os = NULL;
    this->lastVar = NULL;
}

Statement *GotoStatement::syntaxCopy()
{
    return new GotoStatement(loc, ident);
}

bool GotoStatement::checkLabel()
{
    if (!label->statement)
    {
        error("label '%s' is undefined", label->toChars());
        return true;
    }

    if (label->statement->os != os)
    {
        if (os && os->tok == TOKon_scope_failure && !label->statement->os)
        {
            // Jump out from scope(failure) block is allowed.
        }
        else
        {
            if (label->statement->os)
                error("cannot goto in to %s block", Token::toChars(label->statement->os->tok));
            else
                error("cannot goto out of %s block", Token::toChars(os->tok));
            return true;
        }
    }

    if (label->statement->tf != tf)
    {
        error("cannot goto in or out of finally block");
        return true;
    }

    VarDeclaration *vd = label->statement->lastVar;
    if (!vd || vd->isDataseg() || (vd->storage_class & STCmanifest))
        return false;

    VarDeclaration *last = lastVar;
    while (last && last != vd)
        last = last->lastVar;
    if (last == vd)
    {
        // All good, the label's scope has no variables
    }
    else if (vd->ident == Id::withSym)
    {
        error("goto skips declaration of with temporary at %s", vd->loc.toChars());
        return true;
    }
    else
    {
        error("goto skips declaration of variable %s at %s", vd->toPrettyChars(), vd->loc.toChars());
        return true;
    }

    return false;
}

/******************************** LabelStatement ***************************/

LabelStatement::LabelStatement(Loc loc, Identifier *ident, Statement *statement)
    : Statement(loc)
{
    this->ident = ident;
    this->statement = statement;
    this->tf = NULL;
    this->os = NULL;
    this->lastVar = NULL;
    this->gotoTarget = NULL;
    this->breaks = false;
}

Statement *LabelStatement::syntaxCopy()
{
    return new LabelStatement(loc, ident, statement ? statement->syntaxCopy() : NULL);
}

Statement *LabelStatement::scopeCode(Scope *sc, Statement **sentry, Statement **sexit, Statement **sfinally)
{
    //printf("LabelStatement::scopeCode()\n");
    if (statement)
        statement = statement->scopeCode(sc, sentry, sexit, sfinally);
    else
    {
        *sentry = NULL;
        *sexit = NULL;
        *sfinally = NULL;
    }
    return this;
}

Statements *LabelStatement::flatten(Scope *sc)
{
    Statements *a = NULL;

    if (statement)
    {
        a = statement->flatten(sc);
        if (a)
        {
            if (!a->dim)
            {
                a->push(new ExpStatement(loc, (Expression *)NULL));
            }

            // reuse 'this' LabelStatement
            this->statement = (*a)[0];
            (*a)[0] = this;
        }
    }

    return a;
}

/******************************** LabelDsymbol ***************************/

LabelDsymbol::LabelDsymbol(Identifier *ident)
        : Dsymbol(ident)
{
    statement = NULL;
}

LabelDsymbol *LabelDsymbol::create(Identifier *ident)
{
    return new LabelDsymbol(ident);
}

LabelDsymbol *LabelDsymbol::isLabel()           // is this a LabelDsymbol()?
{
    return this;
}


/************************ AsmStatement ***************************************/

AsmStatement::AsmStatement(Loc loc, Token *tokens)
    : Statement(loc)
{
    this->tokens = tokens;
    asmcode = NULL;
    asmalign = 0;
    refparam = false;
    naked = false;
    regs = 0;
}

Statement *AsmStatement::syntaxCopy()
{
    return new AsmStatement(loc, tokens);
}

/************************ CompoundAsmStatement ***************************************/

CompoundAsmStatement::CompoundAsmStatement(Loc loc, Statements *s, StorageClass stc)
    : CompoundStatement(loc, s)
{
    this->stc = stc;
}

CompoundAsmStatement *CompoundAsmStatement::syntaxCopy()
{
    Statements *a = new Statements();
    a->setDim(statements->dim);
    for (size_t i = 0; i < statements->dim; i++)
    {
        Statement *s = (*statements)[i];
        (*a)[i] = s ? s->syntaxCopy() : NULL;
    }
    return new CompoundAsmStatement(loc, a, stc);
}

Statements *CompoundAsmStatement::flatten(Scope *sc)
{
    return NULL;
}

/************************ ImportStatement ***************************************/

ImportStatement::ImportStatement(Loc loc, Dsymbols *imports)
    : Statement(loc)
{
    this->imports = imports;
}

Statement *ImportStatement::syntaxCopy()
{
    Dsymbols *m = new Dsymbols();
    m->setDim(imports->dim);
    for (size_t i = 0; i < imports->dim; i++)
    {
        Dsymbol *s = (*imports)[i];
        (*m)[i] = s->syntaxCopy(NULL);
    }
    return new ImportStatement(loc, m);
}
