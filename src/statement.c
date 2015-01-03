
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

#include "rmem.h"
#include "target.h"

#include "statement.h"
#include "expression.h"
#include "cond.h"
#include "init.h"
#include "staticassert.h"
#include "mtype.h"
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

Identifier *fixupLabelName(Scope *sc, Identifier *ident)
{
    unsigned flags = (sc->flags & SCOPEcontract);
    if (flags && flags != SCOPEinvariant &&
        !(ident->string[0] == '_' && ident->string[1] == '_'))
    {
        /* CTFE requires FuncDeclaration::labtab for the interpretation.
         * So fixing the label name inside in/out contracts is necessary
         * for the uniqueness in labtab.
         */
        const char *prefix = flags == SCOPErequire ? "__in_" : "__out_";
        OutBuffer buf;
        buf.printf("%s%s", prefix, ident->toChars());

        const char *name = buf.extractString();
        ident = Lexer::idPool(name);
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

char *Statement::toChars()
{
    HdrGenState hgs;

    OutBuffer buf;
    ::toCBuffer(this, &buf, &hgs);
    return buf.extractString();
}


Statement *Statement::semantic(Scope *sc)
{
    return this;
}

Statement *Statement::semanticNoScope(Scope *sc)
{
    //printf("Statement::semanticNoScope() %s\n", toChars());
    Statement *s = this;
    if (!s->isCompoundStatement() && !s->isScopeStatement())
    {
        s = new CompoundStatement(loc, this);           // so scopeCode() gets called
    }
    s = s->semantic(sc);
    return s;
}

// Same as semanticNoScope(), but do create a new scope

Statement *Statement::semanticScope(Scope *sc, Statement *sbreak, Statement *scontinue)
{
    Scope *scd = sc->push();
    if (sbreak)
        scd->sbreak = sbreak;
    if (scontinue)
        scd->scontinue = scontinue;
    Statement *s = semanticNoScope(scd);
    scd->pop();
    return s;
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
            //printf("CompoundStatement::blockExit(%p) %d\n", cs, cs->statements->dim);
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
                    result |= r & ~(BEbreak | BEcontinue);
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
            if (s->body)
            {
                result = s->body->blockExit(func, mustNotThrow);
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
            if (s->init)
            {
                result = s->init->blockExit(func, mustNotThrow);
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
            if (s->body)
            {
                int r = s->body->blockExit(func, mustNotThrow);
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
            if (s->body)
                result |= s->body->blockExit(func, mustNotThrow) & ~(BEbreak | BEcontinue);
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
        #if 0 // currently, no code is generated for Pragma's, so it's just fallthru
            if (arrayExpressionCanThrow(s->args, func, mustNotThrow))
                result |= BEthrow;
            if (s->body)
                result |= s->body->blockExit(func, mustNotThrow);
        #endif
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
            if (s->body)
            {
                result |= s->body->blockExit(func, mustNotThrow);
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
            result = s->body ? s->body->blockExit(func, mustNotThrow) : BEfallthru;
        }

        void visit(WithStatement *s)
        {
            result = BEnone;
            if (canThrow(s->exp, func, mustNotThrow))
                result = BEthrow;
            if (s->body)
                result |= s->body->blockExit(func, mustNotThrow);
            else
                result |= BEfallthru;
        }

        void visit(TryCatchStatement *s)
        {
            assert(s->body);
            result = s->body->blockExit(func, false);

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
                s->body->blockExit(func, mustNotThrow);
            }
            result |= catchresult;
        }

        void visit(TryFinallyStatement *s)
        {
            result = BEfallthru;
            if (s->body)
                result = s->body->blockExit(func, false);

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
                if (s->body && (result & BEthrow))
                    s->body->blockExit(func, mustNotThrow);
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

Statement *ErrorStatement::semantic(Scope *sc)
{
    return this;
}

/******************************** PeelStatement ***************************/

PeelStatement::PeelStatement(Statement *s)
    : Statement(s->loc)
{
    this->s = s;
}

Statement *PeelStatement::semantic(Scope *sc)
{
    /* "peel" off this wrapper, and don't run semantic()
     * on the result.
     */
    return s;
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

Statement *ExpStatement::semantic(Scope *sc)
{
    if (exp)
    {
        //printf("ExpStatement::semantic() %s\n", exp->toChars());

#if 0   // Doesn't work because of difficulty dealing with things like a.b.c!(args).Foo!(args)
        // See if this should be rewritten as a TemplateMixin
        if (exp->op == TOKdeclaration)
        {   DeclarationExp *de = (DeclarationExp *)exp;
            Dsymbol *s = de->declaration;

            printf("s: %s %s\n", s->kind(), s->toChars());
            VarDeclaration *v = s->isVarDeclaration();
            if (v)
            {
                printf("%s, %d\n", v->type->toChars(), v->type->ty);
            }
        }
#endif

        exp = exp->semantic(sc);
        exp = exp->addDtorHook(sc);
        exp = resolveProperties(sc, exp);
        discardValue(exp);
        exp = exp->optimize(0);
        exp = checkGC(sc, exp);
        if (exp->op == TOKerror)
            return new ErrorStatement();
    }
    return this;
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
            if (v && !v->noscope && !v->isDataseg())
            {
                Expression *e = v->edtor;
                if (e)
                {
                    //printf("dtor is: "); e->print();
#if 0
                    if (v->type->toBasetype()->ty == Tstruct)
                    {   /* Need a 'gate' to turn on/off destruction,
                         * in case v gets moved elsewhere.
                         */
                        Identifier *id = Lexer::uniqueId("__runDtor");
                        ExpInitializer *ie = new ExpInitializer(loc, new IntegerExp(1));
                        VarDeclaration *rd = new VarDeclaration(loc, Type::tint32, id, ie);
                        rd->storage_class |= STCtemp;
                        *sentry = new ExpStatement(loc, rd);
                        v->rundtor = rd;

                        /* Rewrite e as:
                         *  rundtor && e
                         */
                        Expression *ve = new VarExp(loc, v->rundtor);
                        e = new AndAndExp(loc, ve, e);
                        e->type = Type::tbool;
                    }
#endif
                    *sfinally = new DtorExpStatement(loc, e, v);
                }
                v->noscope = 1;         // don't add in dtor again
            }
        }
    }
    return this;
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
            Parser p(loc, sc->module, (utf8_t *)se->string, se->len, 0);
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

Statement *CompileStatement::semantic(Scope *sc)
{
    //printf("CompileStatement::semantic() %s\n", exp->toChars());
    Statements *a = flatten(sc);
    if (!a)
        return NULL;
    Statement *s = new CompoundStatement(loc, a);
    return s->semantic(sc);
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

Statement *CompoundStatement::semantic(Scope *sc)
{
    //printf("CompoundStatement::semantic(this = %p, sc = %p)\n", this, sc);

#if 0
    for (size_t i = 0; i < statements->dim; i++)
    {
        Statement *s = (*statements)[i];
        if (s)
            printf("[%d]: %s", i, s->toChars());
    }
#endif

    for (size_t i = 0; i < statements->dim; )
    {
        Statement *s = (*statements)[i];
        if (s)
        {
            Statements *flt = s->flatten(sc);
            if (flt)
            {
                statements->remove(i);
                statements->insert(i, flt);
                continue;
            }
            s = s->semantic(sc);
            (*statements)[i] = s;
            if (s)
            {
                Statement *sentry;
                Statement *sexception;
                Statement *sfinally;

                (*statements)[i] = s->scopeCode(sc, &sentry, &sexception, &sfinally);
                if (sentry)
                {
                    sentry = sentry->semantic(sc);
                    statements->insert(i, sentry);
                    i++;
                }
                if (sexception)
                    sexception = sexception->semantic(sc);
                if (sexception)
                {
                    if (i + 1 == statements->dim && !sfinally)
                    {
                    }
                    else
                    {
                        /* Rewrite:
                         *      s; s1; s2;
                         * As:
                         *      s;
                         *      try { s1; s2; }
                         *      catch (Throwable __o)
                         *      { sexception; throw __o; }
                         */
                        Statements *a = new Statements();
                        for (size_t j = i + 1; j < statements->dim; j++)
                        {
                            a->push((*statements)[j]);
                        }
                        Statement *body = new CompoundStatement(Loc(), a);
                        body = new ScopeStatement(Loc(), body);

                        Identifier *id = Lexer::uniqueId("__o");

                        Statement *handler = new PeelStatement(sexception);
                        if (sexception->blockExit(sc->func, false) & BEfallthru)
                        {
                            ThrowStatement *ts = new ThrowStatement(Loc(), new IdentifierExp(Loc(), id));
                            ts->internalThrow = true;
                            handler = new CompoundStatement(Loc(), handler, ts);
                        }

                        Catches *catches = new Catches();
                        Catch *ctch = new Catch(Loc(), NULL, id, handler);
                        ctch->internalCatch = true;
                        catches->push(ctch);

                        s = new TryCatchStatement(Loc(), body, catches);
                        if (sfinally)
                            s = new TryFinallyStatement(Loc(), s, sfinally);
                        s = s->semantic(sc);

                        statements->setDim(i + 1);
                        statements->push(s);
                        break;
                    }
                }
                else if (sfinally)
                {
                    if (0 && i + 1 == statements->dim)
                    {
                        statements->push(sfinally);
                    }
                    else
                    {
                        /* Rewrite:
                         *      s; s1; s2;
                         * As:
                         *      s; try { s1; s2; } finally { sfinally; }
                         */
                        Statements *a = new Statements();
                        for (size_t j = i + 1; j < statements->dim; j++)
                        {
                            a->push((*statements)[j]);
                        }
                        Statement *body = new CompoundStatement(Loc(), a);
                        s = new TryFinallyStatement(Loc(), body, sfinally);
                        s = s->semantic(sc);
                        statements->setDim(i + 1);
                        statements->push(s);
                        break;
                    }
                }
            }
            else
            {
                /* Remove NULL statements from the list.
                 */
                statements->remove(i);
                continue;
            }
        }
        i++;
    }
    for (size_t i = 0; i < statements->dim; ++i)
    {
    Lagain:
        Statement *s = (*statements)[i];
        if (!s)
            continue;

        Statement *se = s->isErrorStatement();
        if (se)
            return se;

        /* Bugzilla 11653: 'semantic' may return another CompoundStatement
         * (eg. CaseRangeStatement), so flatten it here.
         */
        Statements *flt = s->flatten(sc);
        if (flt)
        {
            statements->remove(i);
            statements->insert(i, flt);
            if (statements->dim <= i)
                break;
            goto Lagain;
        }
    }
    if (statements->dim == 1)
    {
        return (*statements)[0];
    }
    return this;
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

Statement *UnrolledLoopStatement::semantic(Scope *sc)
{
    //printf("UnrolledLoopStatement::semantic(this = %p, sc = %p)\n", this, sc);

    Scope *scd = sc->push();
    scd->sbreak = this;
    scd->scontinue = this;
    Statement *serror = NULL;
    for (size_t i = 0; i < statements->dim; i++)
    {
        Statement *s = (*statements)[i];
        if (s)
        {
            //printf("[%d]: %s\n", i, s->toChars());
            s = s->semantic(scd);
            (*statements)[i] = s;

            if (s && !serror)
                serror = s->isErrorStatement();
        }
    }

    scd->pop();
    return serror ? serror : this;
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

ScopeStatement::ScopeStatement(Loc loc, Statement *s)
    : Statement(loc)
{
    this->statement = s;
}

Statement *ScopeStatement::syntaxCopy()
{
    return new ScopeStatement(loc, statement ? statement->syntaxCopy() : NULL);
}

ReturnStatement *ScopeStatement::isReturnStatement()
{
    if (statement)
        return statement->isReturnStatement();
    return NULL;
}

Statement *ScopeStatement::semantic(Scope *sc)
{   ScopeDsymbol *sym;

    //printf("ScopeStatement::semantic(sc = %p)\n", sc);
    if (statement)
    {
        sym = new ScopeDsymbol();
        sym->parent = sc->scopesym;
        sc = sc->push(sym);

        Statements *a = statement->flatten(sc);
        if (a)
        {
            statement = new CompoundStatement(loc, a);
        }

        statement = statement->semantic(sc);
        if (statement)
        {
            if (statement->isErrorStatement())
            {
                sc->pop();
                return statement;
            }

            Statement *sentry;
            Statement *sexception;
            Statement *sfinally;

            statement = statement->scopeCode(sc, &sentry, &sexception, &sfinally);
            assert(!sentry);
            assert(!sexception);
            if (sfinally)
            {
                //printf("adding sfinally\n");
                sfinally = sfinally->semantic(sc);
                statement = new CompoundStatement(loc, statement, sfinally);
            }
        }

        sc->pop();
    }
    return this;
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
    body = b;
    this->endloc = endloc;
}

Statement *WhileStatement::syntaxCopy()
{
    return new WhileStatement(loc,
        condition->syntaxCopy(),
        body ? body->syntaxCopy() : NULL,
        endloc);
}

Statement *WhileStatement::semantic(Scope *sc)
{
    /* Rewrite as a for(;condition;) loop
     */

    Statement *s = new ForStatement(loc, NULL, condition, NULL, body, endloc);
    s = s->semantic(sc);
    return s;
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

DoStatement::DoStatement(Loc loc, Statement *b, Expression *c)
    : Statement(loc)
{
    body = b;
    condition = c;
}

Statement *DoStatement::syntaxCopy()
{
    return new DoStatement(loc,
        body ? body->syntaxCopy() : NULL,
        condition->syntaxCopy());
}

Statement *DoStatement::semantic(Scope *sc)
{
    sc->noctor++;
    if (body)
        body = body->semanticScope(sc, this, this);
    sc->noctor--;
    condition = condition->semantic(sc);
    condition = resolveProperties(sc, condition);
    condition = condition->optimize(WANTvalue);
    condition = checkGC(sc, condition);

    condition = condition->checkToBoolean(sc);

    if (condition->op == TOKerror)
        return new ErrorStatement();

    if (body && body->isErrorStatement())
        return body;

    return this;
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
    this->init = init;
    this->condition = condition;
    this->increment = increment;
    this->body = body;
    this->endloc = endloc;
    this->relatedLabeled = NULL;
}

Statement *ForStatement::syntaxCopy()
{
    return new ForStatement(loc,
        init ? init->syntaxCopy() : NULL,
        condition ? condition->syntaxCopy() : NULL,
        increment ? increment->syntaxCopy() : NULL,
        body->syntaxCopy(),
        endloc);
}

Statement *ForStatement::semantic(Scope *sc)
{
    //printf("ForStatement::semantic %s\n", toChars());

    if (init)
    {
        /* Rewrite:
         *  for (auto v1 = i1, v2 = i2; condition; increment) { ... }
         * to:
         *  { auto v1 = i1, v2 = i2; for (; condition; increment) { ... } }
         * then lowered to:
         *  auto v1 = i1;
         *  try {
         *    auto v2 = i2;
         *    try {
         *      for (; condition; increment) { ... }
         *    } finally { v2.~this(); }
         *  } finally { v1.~this(); }
         */
        Statements *ainit = new Statements();
        ainit->push(init), init = NULL;
        ainit->push(this);
        Statement *s = new CompoundStatement(loc, ainit);
        s = new ScopeStatement(loc, s);
        s = s->semantic(sc);
        if (!s->isErrorStatement())
        {
            if (LabelStatement *ls = checkLabeledLoop(sc, this))
                ls->gotoTarget = this;
            relatedLabeled = s;
        }
        return s;
    }
    assert(init == NULL);

    ScopeDsymbol *sym = new ScopeDsymbol();
    sym->parent = sc->scopesym;
    sc = sc->push(sym);

    sc->noctor++;
    if (condition)
    {
        condition = condition->semantic(sc);
        condition = resolveProperties(sc, condition);
        condition = condition->optimize(WANTvalue);
        condition = checkGC(sc, condition);
        condition = condition->checkToBoolean(sc);
    }
    if (increment)
    {
        increment = increment->semantic(sc);
        increment = resolveProperties(sc, increment);
        increment = increment->optimize(0);
        increment = checkGC(sc, increment);
    }

    sc->sbreak = this;
    sc->scontinue = this;
    if (body)
        body = body->semanticNoScope(sc);
    sc->noctor--;

    sc->pop();

    if (condition && condition->op == TOKerror ||
        increment && increment->op == TOKerror ||
        body      && body->isErrorStatement())
        return new ErrorStatement();

    return this;
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
    this->body = body;
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
        body ? body->syntaxCopy() : NULL,
        endloc);
}

Statement *ForeachStatement::semantic(Scope *sc)
{
    //printf("ForeachStatement::semantic() %p\n", this);
    ScopeDsymbol *sym;
    Statement *s = this;
    size_t dim = parameters->dim;
    TypeAArray *taa = NULL;
    Dsymbol *sapply = NULL;

    Type *tn = NULL;
    Type *tnv = NULL;

    func = sc->func;
    if (func->fes)
        func = func->fes->func;

    if (!inferAggregate(this, sc, sapply))
    {
        const char *msg = "";
        if (aggr->type && isAggregate(aggr->type))
        {
            msg = ", define opApply(), range primitives, or use .tupleof";
        }
        error("invalid foreach aggregate %s%s", aggr->toChars(), msg);
        return new ErrorStatement();
    }

    Dsymbol* sapplyOld = sapply;  // 'sapply' will be NULL if and after 'inferApplyArgTypes' errors

    /* Check for inference errors
     */
    if (!inferApplyArgTypes(this, sc, sapply))
    {
        /**
            Try and extract the parameter count of the opApply callback function, e.g.:
            int opApply(int delegate(int, float)) => 2 args
        */
        bool foundMismatch = false;
        size_t foreachParamCount = 0;
        if (sapplyOld)
        {
            if (FuncDeclaration *fd = sapplyOld->isFuncDeclaration())
            {
                int fvarargs;  // ignored (opApply shouldn't take variadics)
                Parameters *fparameters = fd->getParameters(&fvarargs);

                if (Parameter::dim(fparameters) == 1)
                {
                    // first param should be the callback function
                    Parameter *fparam = Parameter::getNth(fparameters, 0);
                    if ((fparam->type->ty == Tpointer || fparam->type->ty == Tdelegate) &&
                        fparam->type->nextOf()->ty == Tfunction)
                    {
                        TypeFunction *tf = (TypeFunction *)fparam->type->nextOf();
                        foreachParamCount = Parameter::dim(tf->parameters);
                        foundMismatch = true;
                    }
                }
            }
        }

        //printf("dim = %d, parameters->dim = %d\n", dim, parameters->dim);
        if (foundMismatch && dim != foreachParamCount)
        {
            const char *plural = foreachParamCount > 1 ? "s" : "";
            error("cannot infer argument types, expected %d argument%s, not %d",
                  foreachParamCount, plural, dim);
        }
        else
            error("cannot uniquely infer foreach argument types");

        return new ErrorStatement();
    }

    Type *tab = aggr->type->toBasetype();

    if (tab->ty == Ttuple)      // don't generate new scope for tuple loops
    {
        if (dim < 1 || dim > 2)
        {
            error("only one (value) or two (key,value) arguments for tuple foreach");
            return new ErrorStatement();
        }

        Type *paramtype = (*parameters)[dim-1]->type;
        if (paramtype)
        {
            paramtype = paramtype->semantic(loc, sc);
            if (paramtype->ty == Terror)
                return new ErrorStatement();
        }

        TypeTuple *tuple = (TypeTuple *)tab;
        Statements *statements = new Statements();
        //printf("aggr: op = %d, %s\n", aggr->op, aggr->toChars());
        size_t n;
        TupleExp *te = NULL;
        if (aggr->op == TOKtuple)       // expression tuple
        {
            te = (TupleExp *)aggr;
            n = te->exps->dim;
        }
        else if (aggr->op == TOKtype)   // type tuple
        {
            n = Parameter::dim(tuple->arguments);
        }
        else
            assert(0);
        for (size_t j = 0; j < n; j++)
        {
            size_t k = (op == TOKforeach) ? j : n - 1 - j;
            Expression *e = NULL;
            Type *t = NULL;
            if (te)
                e = (*te->exps)[k];
            else
                t = Parameter::getNth(tuple->arguments, k)->type;
            Parameter *p = (*parameters)[0];
            Statements *st = new Statements();

            if (dim == 2)
            {
                // Declare key
                if (p->storageClass & (STCout | STCref | STClazy))
                {
                    error("no storage class for key %s", p->ident->toChars());
                    return new ErrorStatement();
                }
                p->type = p->type->semantic(loc, sc);
                TY keyty = p->type->ty;
                if (keyty != Tint32 && keyty != Tuns32)
                {
                    if (global.params.is64bit)
                    {
                        if (keyty != Tint64 && keyty != Tuns64)
                        {
                            error("foreach: key type must be int or uint, long or ulong, not %s", p->type->toChars());
                            return new ErrorStatement();
                        }
                    }
                    else
                    {
                        error("foreach: key type must be int or uint, not %s", p->type->toChars());
                        return new ErrorStatement();
                    }
                }
                Initializer *ie = new ExpInitializer(Loc(), new IntegerExp(k));
                VarDeclaration *var = new VarDeclaration(loc, p->type, p->ident, ie);
                var->storage_class |= STCmanifest;
                DeclarationExp *de = new DeclarationExp(loc, var);
                st->push(new ExpStatement(loc, de));
                p = (*parameters)[1];  // value
            }
            // Declare value
            if (p->storageClass & (STCout | STClazy) ||
                p->storageClass & STCref && !te)
            {
                error("no storage class for value %s", p->ident->toChars());
                return new ErrorStatement();
            }
            Dsymbol *var;
            if (te)
            {
                Type *tb = e->type->toBasetype();
                Dsymbol *ds = NULL;
                if ((tb->ty == Tfunction || tb->ty == Tsarray) && e->op == TOKvar)
                    ds = ((VarExp *)e)->var;
                else if (e->op == TOKtemplate)
                    ds = ((TemplateExp *)e)->td;
                else if (e->op == TOKimport)
                    ds = ((ScopeExp *)e)->sds;
                else if (e->op == TOKfunction)
                {
                    FuncExp *fe = (FuncExp *)e;
                    ds = fe->td ? (Dsymbol *)fe->td : fe->fd;
                }

                if (ds)
                {
                    var = new AliasDeclaration(loc, p->ident, ds);
                    if (p->storageClass & STCref)
                    {
                        error("symbol %s cannot be ref", s->toChars());
                        return new ErrorStatement();
                    }
                    if (paramtype)
                    {
                        error("cannot specify element type for symbol %s", ds->toChars());
                        return new ErrorStatement();
                    }
                }
                else if (e->op == TOKtype)
                {
                    var = new AliasDeclaration(loc, p->ident, e->type);
                    if (paramtype)
                    {
                        error("cannot specify element type for type %s", e->type->toChars());
                        return new ErrorStatement();
                    }
                }
                else
                {
                    p->type = e->type;
                    if (paramtype)
                        p->type = paramtype;
                    Initializer *ie = new ExpInitializer(Loc(), e);
                    VarDeclaration *v = new VarDeclaration(loc, p->type, p->ident, ie);
                    if (p->storageClass & STCref)
                        v->storage_class |= STCref | STCforeach;
                    if (e->isConst() || e->op == TOKstring ||
                        e->op == TOKstructliteral || e->op == TOKarrayliteral)
                    {
                        if (v->storage_class & STCref)
                        {
                            error("constant value %s cannot be ref", ie->toChars());
                            return new ErrorStatement();
                        }
                        else
                            v->storage_class |= STCmanifest;
                    }
                    var = v;
                }
            }
            else
            {
                var = new AliasDeclaration(loc, p->ident, t);
                if (paramtype)
                {
                    error("cannot specify element type for symbol %s", s->toChars());
                    return new ErrorStatement();
                }
            }
            DeclarationExp *de = new DeclarationExp(loc, var);
            st->push(new ExpStatement(loc, de));

            st->push(body->syntaxCopy());
            s = new CompoundStatement(loc, st);
            s = new ScopeStatement(loc, s);
            statements->push(s);
        }

        s = new UnrolledLoopStatement(loc, statements);
        if (LabelStatement *ls = checkLabeledLoop(sc, this))
            ls->gotoTarget = s;
        if (te && te->e0)
            s = new CompoundStatement(loc,
                    new ExpStatement(te->e0->loc, te->e0), s);
        s = s->semantic(sc);
        return s;
    }

    sym = new ScopeDsymbol();
    sym->parent = sc->scopesym;
    sc = sc->push(sym);

    sc->noctor++;

    switch (tab->ty)
    {
        case Tarray:
        case Tsarray:
        {
            if (!checkForArgTypes())
                return this;

            if (dim < 1 || dim > 2)
            {
                error("only one or two arguments for array foreach");
                goto Lerror2;
            }

            /* Look for special case of parsing char types out of char type
             * array.
             */
            tn = tab->nextOf()->toBasetype();
            if (tn->ty == Tchar || tn->ty == Twchar || tn->ty == Tdchar)
            {
                int i = (dim == 1) ? 0 : 1;     // index of value
                Parameter *p = (*parameters)[i];
                p->type = p->type->semantic(loc, sc);
                p->type = p->type->addStorageClass(p->storageClass);
                tnv = p->type->toBasetype();
                if (tnv->ty != tn->ty &&
                    (tnv->ty == Tchar || tnv->ty == Twchar || tnv->ty == Tdchar))
                {
                    if (p->storageClass & STCref)
                    {
                        error("foreach: value of UTF conversion cannot be ref");
                        goto Lerror2;
                    }
                    if (dim == 2)
                    {
                        p = (*parameters)[0];
                        if (p->storageClass & STCref)
                        {
                            error("foreach: key cannot be ref");
                            goto Lerror2;
                        }
                    }
                    goto Lapply;
                }
            }

            for (size_t i = 0; i < dim; i++)
            {
                // Declare parameterss
                Parameter *p = (*parameters)[i];
                p->type = p->type->semantic(loc, sc);
                p->type = p->type->addStorageClass(p->storageClass);
                VarDeclaration *var;

                if (dim == 2 && i == 0)
                {
                    var = new VarDeclaration(loc, p->type->mutableOf(), Lexer::uniqueId("__key"), NULL);
                    var->storage_class |= STCtemp | STCforeach;
                    if (var->storage_class & (STCref | STCout))
                        var->storage_class |= STCnodtor;

                    key = var;
                    if (p->storageClass & STCref)
                    {
                        if (var->type->constConv(p->type) <= MATCHnomatch)
                        {
                            error("key type mismatch, %s to ref %s",
                                  var->type->toChars(), p->type->toChars());
                            goto Lerror2;
                        }
                    }
                    if (tab->ty == Tsarray)
                    {
                        TypeSArray *ta =  (TypeSArray *)tab;
                        IntRange dimrange = getIntRange(ta->dim);
                        if (!IntRange::fromType(var->type).contains(dimrange))
                        {
                            error("index type '%s' cannot cover index range 0..%llu", p->type->toChars(), ta->dim->toInteger());
                            goto Lerror2;
                        }
                        key->range = new IntRange(SignExtendedNumber(0), dimrange.imax);
                    }
                }
                else
                {
                    var = new VarDeclaration(loc, p->type, p->ident, NULL);
                    var->storage_class |= STCforeach;
                    var->storage_class |= p->storageClass & (STCin | STCout | STCref | STC_TYPECTOR);
                    if (var->storage_class & (STCref | STCout))
                        var->storage_class |= STCnodtor;

                    value = var;
                    if (var->storage_class & STCref)
                    {
                        if (aggr->checkModifiable(sc, 1) == 2)
                            var->storage_class |= STCctorinit;

                        Type *t = tab->nextOf();
                        if (t->constConv(p->type) <= MATCHnomatch)
                        {
                            error("argument type mismatch, %s to ref %s",
                                  t->toChars(), p->type->toChars());
                            goto Lerror2;
                        }
                    }
                }
            }

             /* Convert to a ForStatement
              *   foreach (key, value; a) body =>
              *   for (T[] tmp = a[], size_t key; key < tmp.length; ++key)
              *   { T value = tmp[k]; body }
              *
              *   foreach_reverse (key, value; a) body =>
              *   for (T[] tmp = a[], size_t key = tmp.length; key--; )
              *   { T value = tmp[k]; body }
              */
            Identifier *id = Lexer::uniqueId("__aggr");
            ExpInitializer *ie = new ExpInitializer(loc, new SliceExp(loc, aggr, NULL, NULL));
            VarDeclaration *tmp;
            if (aggr->op == TOKarrayliteral &&
                !((*parameters)[dim - 1]->storageClass & STCref))
            {
                ArrayLiteralExp *ale = (ArrayLiteralExp *)aggr;
                size_t edim = ale->elements ? ale->elements->dim : 0;
                aggr->type = tab->nextOf()->sarrayOf(edim);

                // for (T[edim] tmp = a, ...)
                tmp = new VarDeclaration(loc, aggr->type, id, ie);
            }
            else
                tmp = new VarDeclaration(loc, tab->nextOf()->arrayOf(), id, ie);
            tmp->storage_class |= STCtemp;

            Expression *tmp_length = new DotIdExp(loc, new VarExp(loc, tmp), Id::length);

            if (!key)
            {
                Identifier *idkey = Lexer::uniqueId("__key");
                key = new VarDeclaration(loc, Type::tsize_t, idkey, NULL);
                key->storage_class |= STCtemp;
            }
            if (op == TOKforeach_reverse)
                key->init = new ExpInitializer(loc, tmp_length);
            else
                key->init = new ExpInitializer(loc, new IntegerExp(loc, 0, key->type));

            Statements *cs = new Statements();
            cs->push(new ExpStatement(loc, tmp));
            cs->push(new ExpStatement(loc, key));
            Statement *forinit = new CompoundDeclarationStatement(loc, cs);

            Expression *cond;
            if (op == TOKforeach_reverse)
            {
                // key--
                cond = new PostExp(TOKminusminus, loc, new VarExp(loc, key));
            }
            else
            {
                // key < tmp.length
                cond = new CmpExp(TOKlt, loc, new VarExp(loc, key), tmp_length);
            }

            Expression *increment = NULL;
            if (op == TOKforeach)
            {
                // key += 1
                increment = new AddAssignExp(loc, new VarExp(loc, key), new IntegerExp(loc, 1, key->type));
            }

            // T value = tmp[key];
            value->init = new ExpInitializer(loc, new IndexExp(loc, new VarExp(loc, tmp), new VarExp(loc, key)));
            Statement *ds = new ExpStatement(loc, value);

            if (dim == 2)
            {
                Parameter *p = (*parameters)[0];
                if ((p->storageClass & STCref) && p->type->equals(key->type))
                {
                    key->range = NULL;
                    AliasDeclaration *v = new AliasDeclaration(loc, p->ident, key);
                    body = new CompoundStatement(loc, new ExpStatement(loc, v), body);
                }
                else
                {
                    ExpInitializer *ei = new ExpInitializer(loc, new IdentifierExp(loc, key->ident));
                    VarDeclaration *v = new VarDeclaration(loc, p->type, p->ident, ei);
                    v->storage_class |= STCforeach | (p->storageClass & STCref);
                    body = new CompoundStatement(loc, new ExpStatement(loc, v), body);
                    if (key->range && !p->type->isMutable())
                    {
                        /* Limit the range of the key to the specified range
                         */
                        v->range = new IntRange(key->range->imin, key->range->imax - SignExtendedNumber(1));
                    }
                }
            }
            body = new CompoundStatement(loc, ds, body);

            s = new ForStatement(loc, forinit, cond, increment, body, endloc);
            if (LabelStatement *ls = checkLabeledLoop(sc, this))
                ls->gotoTarget = s;
            s = s->semantic(sc);
            break;
        }

        case Taarray:
            if (op == TOKforeach_reverse)
                warning("cannot use foreach_reverse with an associative array");
            if (!checkForArgTypes())
                return this;

            taa = (TypeAArray *)tab;
            if (dim < 1 || dim > 2)
            {
                error("only one or two arguments for associative array foreach");
                goto Lerror2;
            }
            goto Lapply;

        case Tclass:
        case Tstruct:
            /* Prefer using opApply, if it exists
             */
            if (sapply)
                goto Lapply;

        {
            /* Look for range iteration, i.e. the properties
             * .empty, .popFront, .popBack, .front and .back
             *    foreach (e; aggr) { ... }
             * translates to:
             *    for (auto __r = aggr[]; !__r.empty; __r.popFront) {
             *        auto e = __r.front;
             *        ...
             *    }
             */
            AggregateDeclaration *ad = (tab->ty == Tclass)
                        ? (AggregateDeclaration *)((TypeClass  *)tab)->sym
                        : (AggregateDeclaration *)((TypeStruct *)tab)->sym;
            Identifier *idfront;
            Identifier *idpopFront;
            if (op == TOKforeach)
            {
                idfront = Id::Ffront;
                idpopFront = Id::FpopFront;
            }
            else
            {
                idfront = Id::Fback;
                idpopFront = Id::FpopBack;
            }
            Dsymbol *sfront = ad->search(Loc(), idfront);
            if (!sfront)
                goto Lapply;

            /* Generate a temporary __r and initialize it with the aggregate.
             */
            Identifier *rid = Identifier::generateId("__r");
            VarDeclaration *r = new VarDeclaration(loc, NULL, rid, new ExpInitializer(loc, aggr));
            r->storage_class |= STCtemp;
            Statement *init = new ExpStatement(loc, r);

            // !__r.empty
            Expression *e = new VarExp(loc, r);
            e = new DotIdExp(loc, e, Id::Fempty);
            Expression *condition = new NotExp(loc, e);

            // __r.next
            e = new VarExp(loc, r);
            Expression *increment = new CallExp(loc, new DotIdExp(loc, e, idpopFront));

            /* Declaration statement for e:
             *    auto e = __r.idfront;
             */
            e = new VarExp(loc, r);
            Expression *einit = new DotIdExp(loc, e, idfront);
            Statement *makeargs, *forbody;
            if (dim == 1)
            {
                Parameter *p = (*parameters)[0];
                VarDeclaration *ve = new VarDeclaration(loc, p->type, p->ident, new ExpInitializer(loc, einit));
                ve->storage_class |= STCforeach;
                ve->storage_class |= p->storageClass & (STCin | STCout | STCref | STC_TYPECTOR);

                DeclarationExp *de = new DeclarationExp(loc, ve);
                makeargs = new ExpStatement(loc, de);
            }
            else
            {
                Identifier *id = Lexer::uniqueId("__front");
                ExpInitializer *ei = new ExpInitializer(loc, einit);
                VarDeclaration *vd = new VarDeclaration(loc, NULL, id, ei);
                vd->storage_class |= STCtemp | STCctfe | STCref | STCforeach;

                makeargs = new ExpStatement(loc, new DeclarationExp(loc, vd));

                Declaration *d = sfront->isDeclaration();
                if (FuncDeclaration *f = d->isFuncDeclaration())
                {
                    if (!f->functionSemantic())
                        goto Lrangeerr;
                }
                Expression *ve = new VarExp(loc, vd);
                ve->type = d->type;
                if (ve->type->toBasetype()->ty == Tfunction)
                    ve->type = ve->type->toBasetype()->nextOf();
                if (!ve->type || ve->type->ty == Terror)
                    goto Lrangeerr;

                // Resolve inout qualifier of front type
                ve->type = ve->type->substWildTo(tab->mod);

                Expressions *exps = new Expressions();
                exps->push(ve);
                int pos = 0;
                while (exps->dim < dim)
                {
                    pos = expandAliasThisTuples(exps, pos);
                    if (pos == -1)
                        break;
                }
                if (exps->dim != dim)
                {
                    const char *plural = exps->dim > 1 ? "s" : "";
                    error("cannot infer argument types, expected %d argument%s, not %d",
                          exps->dim, plural, dim);
                    goto Lerror2;
                }

                for (size_t i = 0; i < dim; i++)
                {
                    Parameter *p = (*parameters)[i];
                    Expression *exp = (*exps)[i];
                #if 0
                    printf("[%d] p = %s %s, exp = %s %s\n", i,
                            p->type ? p->type->toChars() : "?", p->ident->toChars(),
                            exp->type->toChars(), exp->toChars());
                #endif
                    if (!p->type)
                        p->type = exp->type;
                    p->type = p->type->addStorageClass(p->storageClass)->semantic(loc, sc);
                    if (!exp->implicitConvTo(p->type))
                        goto Lrangeerr;

                    VarDeclaration *var = new VarDeclaration(loc, p->type, p->ident, new ExpInitializer(loc, exp));
                    var->storage_class |= STCctfe | STCref | STCforeach;
                    DeclarationExp *de = new DeclarationExp(loc, var);
                    makeargs = new CompoundStatement(loc, makeargs, new ExpStatement(loc, de));
                }

            }

            forbody = new CompoundStatement(loc,
                makeargs, this->body);

            s = new ForStatement(loc, init, condition, increment, forbody, endloc);
            if (LabelStatement *ls = checkLabeledLoop(sc, this))
                ls->gotoTarget = s;
#if 0
            printf("init: %s\n", init->toChars());
            printf("condition: %s\n", condition->toChars());
            printf("increment: %s\n", increment->toChars());
            printf("body: %s\n", forbody->toChars());
#endif
            s = s->semantic(sc);
            break;

        Lrangeerr:
            error("cannot infer argument types");
            goto Lerror2;
        }
        case Tdelegate:
            if (op == TOKforeach_reverse)
                deprecation("cannot use foreach_reverse with a delegate");
        Lapply:
        {
            Expression *ec;
            Expression *e;

            if (!checkForArgTypes())
            {
                body = body->semanticNoScope(sc);
                return this;
            }

            TypeFunction *tfld = NULL;
            if (sapply)
            {
                FuncDeclaration *fdapply = sapply->isFuncDeclaration();
                if (fdapply)
                {
                    assert(fdapply->type && fdapply->type->ty == Tfunction);
                    tfld = (TypeFunction *)fdapply->type->semantic(loc, sc);
                    goto Lget;
                }
                else if (tab->ty == Tdelegate)
                {
                    tfld = (TypeFunction *)tab->nextOf();
                Lget:
                    //printf("tfld = %s\n", tfld->toChars());
                    if (tfld->parameters->dim == 1)
                    {
                        Parameter *p = Parameter::getNth(tfld->parameters, 0);
                        if (p->type && p->type->ty == Tdelegate)
                        {
                            Type *t = p->type->semantic(loc, sc);
                            assert(t->ty == Tdelegate);
                            tfld = (TypeFunction *)t->nextOf();
                        }
                    }
                }
            }

            /* Turn body into the function literal:
             *  int delegate(ref T param) { body }
             */
            Parameters *params = new Parameters();
            for (size_t i = 0; i < dim; i++)
            {
                Parameter *p = (*parameters)[i];
                StorageClass stc = STCref;
                Identifier *id;

                p->type = p->type->semantic(loc, sc);
                p->type = p->type->addStorageClass(p->storageClass);
                if (tfld)
                {
                    Parameter *prm = Parameter::getNth(tfld->parameters, i);
                    //printf("\tprm = %s%s\n", (prm->storageClass&STCref?"ref ":""), prm->ident->toChars());
                    stc = prm->storageClass & STCref;
                    id = p->ident;    // argument copy is not need.
                    if ((p->storageClass & STCref) != stc)
                    {
                        if (!stc)
                        {
                            error("foreach: cannot make %s ref", p->ident->toChars());
                            goto Lerror2;
                        }
                        goto LcopyArg;
                    }
                }
                else if (p->storageClass & STCref)
                {
                    // default delegate parameters are marked as ref, then
                    // argument copy is not need.
                    id = p->ident;
                }
                else
                {
                    // Make a copy of the ref argument so it isn't
                    // a reference.
                LcopyArg:
                    id = Lexer::uniqueId("__applyArg", (int)i);

                    Initializer *ie = new ExpInitializer(Loc(), new IdentifierExp(Loc(), id));
                    VarDeclaration *v = new VarDeclaration(Loc(), p->type, p->ident, ie);
                    v->storage_class |= STCtemp;
                    s = new ExpStatement(Loc(), v);
                    body = new CompoundStatement(loc, s, body);
                }
                params->push(new Parameter(stc, p->type, id, NULL));
            }
            // Bugzilla 13840: Throwable nested function inside nothrow function is acceptable.
            StorageClass stc = mergeFuncAttrs(STCsafe | STCpure | STCnogc, func);
            tfld = new TypeFunction(params, Type::tint32, 0, LINKd, stc);
            cases = new Statements();
            gotos = new ScopeStatements();
            FuncLiteralDeclaration *fld = new FuncLiteralDeclaration(loc, Loc(), tfld, TOKdelegate, this);
            fld->fbody = body;
            Expression *flde = new FuncExp(loc, fld);
            flde = flde->semantic(sc);
            fld->tookAddressOf = 0;

            // Resolve any forward referenced goto's
            for (size_t i = 0; i < gotos->dim; i++)
            {
                GotoStatement *gs = (GotoStatement *)(*gotos)[i]->statement;
                if (!gs->label->statement)
                {
                    // 'Promote' it to this scope, and replace with a return
                    cases->push(gs);
                    s = new ReturnStatement(Loc(), new IntegerExp(cases->dim + 1));
                    (*gotos)[i]->statement = s;
                }
            }

            if (taa)
            {
                // Check types
                Parameter *p = (*parameters)[0];
                bool isRef = (p->storageClass & STCref) != 0;
                Type *ta = p->type;
                if (dim == 2)
                {
                    Type *ti = (isRef ? taa->index->addMod(MODconst) : taa->index);
                    if (isRef ? !ti->constConv(ta) : !ti->implicitConvTo(ta))
                    {
                        error("foreach: index must be type %s, not %s", ti->toChars(), ta->toChars());
                        goto Lerror2;
                    }
                    p = (*parameters)[1];
                    isRef = (p->storageClass & STCref) != 0;
                    ta = p->type;
                }
                Type *taav = taa->nextOf();
                if (isRef ? !taav->constConv(ta) : !taav->implicitConvTo(ta))
                {
                    error("foreach: value must be type %s, not %s", taav->toChars(), ta->toChars());
                    goto Lerror2;
                }

                /* Call:
                 *  extern(C) int _aaApply(void*, in size_t, int delegate(void*))
                 *      _aaApply(aggr, keysize, flde)
                 *
                 *  extern(C) int _aaApply2(void*, in size_t, int delegate(void*, void*))
                 *      _aaApply2(aggr, keysize, flde)
                 */
                static const char *name[2] = { "_aaApply", "_aaApply2" };
                static FuncDeclaration *fdapply[2] = { NULL, NULL };
                static TypeDelegate *fldeTy[2] = { NULL, NULL };

                unsigned char i = (dim == 2 ? 1 : 0);
                if (!fdapply[i])
                {
                    params = new Parameters;
                    params->push(new Parameter(0, Type::tvoid->pointerTo(), NULL, NULL));
                    params->push(new Parameter(STCin, Type::tsize_t, NULL, NULL));
                    Parameters* dgparams = new Parameters;
                    dgparams->push(new Parameter(0, Type::tvoidptr, NULL, NULL));
                    if (dim == 2)
                        dgparams->push(new Parameter(0, Type::tvoidptr, NULL, NULL));
                    fldeTy[i] = new TypeDelegate(new TypeFunction(dgparams, Type::tint32, 0, LINKd));
                    params->push(new Parameter(0, fldeTy[i], NULL, NULL));
                    fdapply[i] = FuncDeclaration::genCfunc(params, Type::tint32, name[i]);
                }

                ec = new VarExp(Loc(), fdapply[i]);
                Expressions *exps = new Expressions();
                exps->push(aggr);
                size_t keysize = (size_t)taa->index->size();
                keysize = (keysize + ((size_t)Target::ptrsize-1)) & ~((size_t)Target::ptrsize-1);
                // paint delegate argument to the type runtime expects
                if (!fldeTy[i]->equals(flde->type))
                {
                    flde = new CastExp(loc, flde, flde->type);
                    flde->type = fldeTy[i];
                }
                exps->push(new IntegerExp(Loc(), keysize, Type::tsize_t));
                exps->push(flde);
                e = new CallExp(loc, ec, exps);
                e->type = Type::tint32; // don't run semantic() on e
            }
            else if (tab->ty == Tarray || tab->ty == Tsarray)
            {
                /* Call:
                 *      _aApply(aggr, flde)
                 */
                static const char fntab[9][3] =
                { "cc","cw","cd",
                  "wc","cc","wd",
                  "dc","dw","dd"
                };
                const size_t BUFFER_LEN = 7+1+2+ sizeof(dim)*3 + 1;
                char fdname[BUFFER_LEN];
                int flag;

                switch (tn->ty)
                {
                    case Tchar:         flag = 0; break;
                    case Twchar:        flag = 3; break;
                    case Tdchar:        flag = 6; break;
                    default:            assert(0);
                }
                switch (tnv->ty)
                {
                    case Tchar:         flag += 0; break;
                    case Twchar:        flag += 1; break;
                    case Tdchar:        flag += 2; break;
                    default:            assert(0);
                }
                const char *r = (op == TOKforeach_reverse) ? "R" : "";
                int j = sprintf(fdname, "_aApply%s%.*s%llu", r, 2, fntab[flag], (ulonglong)dim);
                assert(j < BUFFER_LEN);

                FuncDeclaration *fdapply;
                TypeDelegate *dgty;
                params = new Parameters;
                params->push(new Parameter(STCin, tn->arrayOf(), NULL, NULL));
                Parameters* dgparams = new Parameters;
                dgparams->push(new Parameter(0, Type::tvoidptr, NULL, NULL));
                if (dim == 2)
                    dgparams->push(new Parameter(0, Type::tvoidptr, NULL, NULL));
                dgty = new TypeDelegate(new TypeFunction(dgparams, Type::tint32, 0, LINKd));
                params->push(new Parameter(0, dgty, NULL, NULL));
                fdapply = FuncDeclaration::genCfunc(params, Type::tint32, fdname);

                ec = new VarExp(Loc(), fdapply);
                Expressions *exps = new Expressions();
                if (tab->ty == Tsarray)
                   aggr = aggr->castTo(sc, tn->arrayOf());
                exps->push(aggr);
                // paint delegate argument to the type runtime expects
                if (!dgty->equals(flde->type)) {
                    flde = new CastExp(loc, flde, flde->type);
                    flde->type = dgty;
                }
                exps->push(flde);
                e = new CallExp(loc, ec, exps);
                e->type = Type::tint32; // don't run semantic() on e
            }
            else if (tab->ty == Tdelegate)
            {
                /* Call:
                 *      aggr(flde)
                 */
                Expressions *exps = new Expressions();
                exps->push(flde);
                if (aggr->op == TOKdelegate &&
                    ((DelegateExp *)aggr)->func->isNested())
                {
                    // See Bugzilla 3560
                    e = new CallExp(loc, ((DelegateExp *)aggr)->e1, exps);
                }
                else
                    e = new CallExp(loc, aggr, exps);
                e = e->semantic(sc);
                if (e->op == TOKerror)
                    goto Lerror2;
                if (e->type != Type::tint32)
                {
                    error("opApply() function for %s must return an int", tab->toChars());
                    goto Lerror2;
                }
            }
            else
            {
                assert(tab->ty == Tstruct || tab->ty == Tclass);
                Expressions *exps = new Expressions();
                assert(sapply);
                /* Call:
                 *  aggr.apply(flde)
                 */
                ec = new DotIdExp(loc, aggr, sapply->ident);
                exps->push(flde);
                e = new CallExp(loc, ec, exps);
                e = e->semantic(sc);
                if (e->op == TOKerror)
                    goto Lerror2;
                if (e->type != Type::tint32)
                {
                    error("opApply() function for %s must return an int", tab->toChars());
                    goto Lerror2;
                }
            }

            if (!cases->dim)
            {
                // Easy case, a clean exit from the loop
                e = new CastExp(loc, e, Type::tvoid);   // Bugzilla 13899
                s = new ExpStatement(loc, e);
            }
            else
            {
                // Construct a switch statement around the return value
                // of the apply function.
                Statements *a = new Statements();

                // default: break; takes care of cases 0 and 1
                s = new BreakStatement(Loc(), NULL);
                s = new DefaultStatement(Loc(), s);
                a->push(s);

                // cases 2...
                for (size_t i = 0; i < cases->dim; i++)
                {
                    s = (*cases)[i];
                    s = new CaseStatement(Loc(), new IntegerExp(i + 2), s);
                    a->push(s);
                }

                s = new CompoundStatement(loc, a);
                s = new SwitchStatement(loc, e, s, false);
            }
            s = s->semantic(sc);
            break;
        }
        case Terror:
        Lerror2:
            s = new ErrorStatement();
            break;

        default:
            error("foreach: %s is not an aggregate type", aggr->type->toChars());
            goto Lerror2;
    }
    sc->noctor--;
    sc->pop();
    return s;
}

bool ForeachStatement::checkForArgTypes()
{
    bool result = true;

    for (size_t i = 0; i < parameters->dim; i++)
    {
        Parameter *p = (*parameters)[i];
        if (!p->type)
        {
            error("cannot infer type for %s", p->ident->toChars());
            p->type = Type::terror;
            result = false;
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
    this->body = body;
    this->endloc = endloc;

    this->key = NULL;
}

Statement *ForeachRangeStatement::syntaxCopy()
{
    return new ForeachRangeStatement(loc, op,
        prm->syntaxCopy(),
        lwr->syntaxCopy(),
        upr->syntaxCopy(),
        body ? body->syntaxCopy() : NULL,
        endloc);
}

Statement *ForeachRangeStatement::semantic(Scope *sc)
{
    //printf("ForeachRangeStatement::semantic() %p\n", this);
    lwr = lwr->semantic(sc);
    lwr = resolveProperties(sc, lwr);
    lwr = lwr->optimize(WANTvalue);
    if (!lwr->type)
    {
        error("invalid range lower bound %s", lwr->toChars());
    Lerror:
        return new ErrorStatement();
    }

    upr = upr->semantic(sc);
    upr = resolveProperties(sc, upr);
    upr = upr->optimize(WANTvalue);
    if (!upr->type)
    {
        error("invalid range upper bound %s", upr->toChars());
        goto Lerror;
    }

    if (prm->type)
    {
        prm->type = prm->type->semantic(loc, sc);
        prm->type = prm->type->addStorageClass(prm->storageClass);
        lwr = lwr->implicitCastTo(sc, prm->type);

        if (upr->implicitConvTo(prm->type) || (prm->storageClass & STCref))
        {
            upr = upr->implicitCastTo(sc, prm->type);
        }
        else
        {
            // See if upr-1 fits in prm->type
            Expression *limit = new MinExp(loc, upr, new IntegerExp(1));
            limit = limit->semantic(sc);
            limit = limit->optimize(WANTvalue);
            if (!limit->implicitConvTo(prm->type))
            {
                upr = upr->implicitCastTo(sc, prm->type);
            }
        }
    }
    else
    {
        /* Must infer types from lwr and upr
         */
        Type *tlwr = lwr->type->toBasetype();
        if (tlwr->ty == Tstruct || tlwr->ty == Tclass)
        {
            /* Just picking the first really isn't good enough.
             */
            prm->type = lwr->type;
        }
        else if (lwr->type == upr->type)
        {
            /* Same logic as CondExp ?lwr:upr
             */
            prm->type = lwr->type;
        }
        else
        {
            AddExp ea(loc, lwr, upr);
            if (typeCombine(&ea, sc))
                return new ErrorStatement();
            prm->type = ea.type;
            lwr = ea.e1;
            upr = ea.e2;
        }
        prm->type = prm->type->addStorageClass(prm->storageClass);
    }
    if (prm->type->ty == Terror ||
        lwr->op == TOKerror ||
        upr->op == TOKerror)
    {
        return new ErrorStatement();
    }

    /* Convert to a for loop:
     *  foreach (key; lwr .. upr) =>
     *  for (auto key = lwr, auto tmp = upr; key < tmp; ++key)
     *
     *  foreach_reverse (key; lwr .. upr) =>
     *  for (auto tmp = lwr, auto key = upr; key-- > tmp;)
     */
    ExpInitializer *ie = new ExpInitializer(loc, (op == TOKforeach) ? lwr : upr);
    key = new VarDeclaration(loc, upr->type->mutableOf(), Lexer::uniqueId("__key"), ie);
    key->storage_class |= STCtemp;
    SignExtendedNumber lower = getIntRange(lwr).imin;
    SignExtendedNumber upper = getIntRange(upr).imax;
    if (lower <= upper)
    {
        key->range = new IntRange(lower, upper);
    }

    Identifier *id = Lexer::uniqueId("__limit");
    ie = new ExpInitializer(loc, (op == TOKforeach) ? upr : lwr);
    VarDeclaration *tmp = new VarDeclaration(loc, upr->type, id, ie);
    tmp->storage_class |= STCtemp;

    Statements *cs = new Statements();
    // Keep order of evaluation as lwr, then upr
    if (op == TOKforeach)
    {
        cs->push(new ExpStatement(loc, key));
        cs->push(new ExpStatement(loc, tmp));
    }
    else
    {
        cs->push(new ExpStatement(loc, tmp));
        cs->push(new ExpStatement(loc, key));
    }
    Statement *forinit = new CompoundDeclarationStatement(loc, cs);

    Expression *cond;
    if (op == TOKforeach_reverse)
    {
        cond = new PostExp(TOKminusminus, loc, new VarExp(loc, key));
        if (prm->type->isscalar())
        {
            // key-- > tmp
            cond = new CmpExp(TOKgt, loc, cond, new VarExp(loc, tmp));
        }
        else
        {
            // key-- != tmp
            cond = new EqualExp(TOKnotequal, loc, cond, new VarExp(loc, tmp));
        }
    }
    else
    {
        if (prm->type->isscalar())
        {
            // key < tmp
            cond = new CmpExp(TOKlt, loc, new VarExp(loc, key), new VarExp(loc, tmp));
        }
        else
        {
            // key != tmp
            cond = new EqualExp(TOKnotequal, loc, new VarExp(loc, key), new VarExp(loc, tmp));
        }
    }

    Expression *increment = NULL;
    if (op == TOKforeach)
        // key += 1
        //increment = new AddAssignExp(loc, new VarExp(loc, key), new IntegerExp(1));
        increment = new PreExp(TOKpreplusplus, loc, new VarExp(loc, key));

    if ((prm->storageClass & STCref) && prm->type->equals(key->type))
    {
        key->range = NULL;
        AliasDeclaration *v = new AliasDeclaration(loc, prm->ident, key);
        body = new CompoundStatement(loc, new ExpStatement(loc, v), body);
    }
    else
    {
        ie = new ExpInitializer(loc, new CastExp(loc, new VarExp(loc, key), prm->type));
        VarDeclaration *v = new VarDeclaration(loc, prm->type, prm->ident, ie);
        v->storage_class |= STCtemp | STCforeach | (prm->storageClass & STCref);
        body = new CompoundStatement(loc, new ExpStatement(loc, v), body);
        if (key->range && !prm->type->isMutable())
        {
            /* Limit the range of the key to the specified range
             */
            v->range = new IntRange(key->range->imin, key->range->imax - SignExtendedNumber(1));
        }
    }
    if (prm->storageClass & STCref)
    {
        if (key->type->constConv(prm->type) <= MATCHnomatch)
        {
            error("prmument type mismatch, %s to ref %s",
                  key->type->toChars(), prm->type->toChars());
            goto Lerror;
        }
    }

    ForStatement *s = new ForStatement(loc, forinit, cond, increment, body, endloc);
    if (LabelStatement *ls = checkLabeledLoop(sc, this))
        ls->gotoTarget = s;
    return s->semantic(sc);
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

IfStatement::IfStatement(Loc loc, Parameter *prm, Expression *condition, Statement *ifbody, Statement *elsebody)
    : Statement(loc)
{
    this->prm = prm;
    this->condition = condition;
    this->ifbody = ifbody;
    this->elsebody = elsebody;
    this->match = NULL;
}

Statement *IfStatement::syntaxCopy()
{
    return new IfStatement(loc,
        prm ? prm->syntaxCopy() : NULL,
        condition->syntaxCopy(),
        ifbody ? ifbody->syntaxCopy() : NULL,
        elsebody ? elsebody->syntaxCopy() : NULL);
}

Statement *IfStatement::semantic(Scope *sc)
{
    // Evaluate at runtime
    unsigned cs0 = sc->callSuper;
    unsigned cs1;
    unsigned *fi0 = sc->saveFieldInit();
    unsigned *fi1 = NULL;

    ScopeDsymbol *sym = new ScopeDsymbol();
    sym->parent = sc->scopesym;
    Scope *scd = sc->push(sym);
    if (prm)
    {
        /* Declare prm, which we will set to be the
         * result of condition.
         */

        match = new VarDeclaration(loc, prm->type, prm->ident, new ExpInitializer(loc, condition));
        match->parent = sc->func;
        match->storage_class |= prm->storageClass;

        DeclarationExp *de = new DeclarationExp(loc, match);
        VarExp *ve = new VarExp(Loc(), match);
        condition = new CommaExp(loc, de, ve);
        condition = condition->semantic(scd);

       if (match->edtor)
       {
            Statement *sdtor = new ExpStatement(loc, match->edtor);
            sdtor = new OnScopeStatement(loc, TOKon_scope_exit, sdtor);
            ifbody = new CompoundStatement(loc, sdtor, ifbody);
            match->noscope = 1;
       }
    }
    else
    {
        condition = condition->semantic(sc);
        condition = condition->addDtorHook(sc);
        condition = resolveProperties(sc, condition);
    }
    condition = checkGC(sc, condition);

    // Convert to boolean after declaring prm so this works:
    //  if (S prm = S()) {}
    // where S is a struct that defines opCast!bool.
    condition = condition->checkToBoolean(sc);

    // If we can short-circuit evaluate the if statement, don't do the
    // semantic analysis of the skipped code.
    // This feature allows a limited form of conditional compilation.
    condition = condition->optimize(WANTflags);
    ifbody = ifbody->semanticNoScope(scd);
    scd->pop();

    cs1 = sc->callSuper;
    fi1 = sc->fieldinit;
    sc->callSuper = cs0;
    sc->fieldinit = fi0;
    if (elsebody)
        elsebody = elsebody->semanticScope(sc, NULL, NULL);
    sc->mergeCallSuper(loc, cs1);
    sc->mergeFieldInit(loc, fi1);

    if (condition->op == TOKerror ||
        (ifbody && ifbody->isErrorStatement()) ||
        (elsebody && elsebody->isErrorStatement()))
    {
        return new ErrorStatement();
    }
    return this;
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

Statement *ConditionalStatement::semantic(Scope *sc)
{
    //printf("ConditionalStatement::semantic()\n");

    // If we can short-circuit evaluate the if statement, don't do the
    // semantic analysis of the skipped code.
    // This feature allows a limited form of conditional compilation.
    if (condition->include(sc, NULL))
    {
        DebugCondition *dc = condition->isDebugCondition();
        if (dc)
        {
            sc = sc->push();
            sc->flags |= SCOPEdebug;
            ifbody = ifbody->semantic(sc);
            sc->pop();
        }
        else
            ifbody = ifbody->semantic(sc);
        return ifbody;
    }
    else
    {
        if (elsebody)
            elsebody = elsebody->semantic(sc);
        return elsebody;
    }
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
    this->body = body;
}

Statement *PragmaStatement::syntaxCopy()
{
    return new PragmaStatement(loc, ident,
        Expression::arraySyntaxCopy(args),
        body ? body->syntaxCopy() : NULL);
}

Statement *PragmaStatement::semantic(Scope *sc)
{
    // Should be merged with PragmaDeclaration
    //printf("PragmaStatement::semantic() %s\n", toChars());
    //printf("body = %p\n", body);
    if (ident == Id::msg)
    {
        if (args)
        {
            for (size_t i = 0; i < args->dim; i++)
            {
                Expression *e = (*args)[i];

                sc = sc->startCTFE();
                e = e->semantic(sc);
                e = resolveProperties(sc, e);
                sc = sc->endCTFE();
                // pragma(msg) is allowed to contain types as well as expressions
                e = ctfeInterpretForPragmaMsg(e);
                if (e->op == TOKerror)
                {   errorSupplemental(loc, "while evaluating pragma(msg, %s)", (*args)[i]->toChars());
                    goto Lerror;
                }
                StringExp *se = e->toStringExp();
                if (se)
                {
                    se = se->toUTF8(sc);
                    fprintf(stderr, "%.*s", (int)se->len, (char *)se->string);
                }
                else
                    fprintf(stderr, "%s", e->toChars());
            }
            fprintf(stderr, "\n");
        }
    }
    else if (ident == Id::lib)
    {
#if 1
        /* Should this be allowed?
         */
        error("pragma(lib) not allowed as statement");
        goto Lerror;
#else
        if (!args || args->dim != 1)
        {
            error("string expected for library name");
            goto Lerror;
        }
        else
        {
            Expression *e = (*args)[0];

            sc = sc->startCTFE();
            e = e->semantic(sc);
            e = resolveProperties(sc, e);
            sc = sc->endCTFE();

            e = e->ctfeInterpret();
            (*args)[0] = e;
            StringExp *se = e->toStringExp();
            if (!se)
            {
                error("string expected for library name, not '%s'", e->toChars());
                goto Lerror;
            }
            else if (global.params.verbose)
            {
                char *name = (char *)mem.malloc(se->len + 1);
                memcpy(name, se->string, se->len);
                name[se->len] = 0;
                fprintf(global.stdmsg, "library   %s\n", name);
                mem.free(name);
            }
        }
#endif
    }
    else if (ident == Id::startaddress)
    {
        if (!args || args->dim != 1)
            error("function name expected for start address");
        else
        {
            Expression *e = (*args)[0];

            sc = sc->startCTFE();
            e = e->semantic(sc);
            e = resolveProperties(sc, e);
            sc = sc->endCTFE();

            e = e->ctfeInterpret();
            (*args)[0] = e;
            Dsymbol *sa = getDsymbol(e);
            if (!sa || !sa->isFuncDeclaration())
            {
                error("function name expected for start address, not '%s'", e->toChars());
                goto Lerror;
            }
            if (body)
            {
                body = body->semantic(sc);
                if (body->isErrorStatement())
                    return body;
            }
            return this;
        }
    }
    else
    {
        error("unrecognized pragma(%s)", ident->toChars());
        goto Lerror;
    }

    if (body)
    {
        body = body->semantic(sc);
    }
    return body;

Lerror:
    return new ErrorStatement();
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

Statement *StaticAssertStatement::semantic(Scope *sc)
{
    sa->semantic2(sc);
    return NULL;
}

/******************************** SwitchStatement ***************************/

SwitchStatement::SwitchStatement(Loc loc, Expression *c, Statement *b, bool isFinal)
    : Statement(loc)
{
    this->condition = c;
    this->body = b;
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
        body->syntaxCopy(),
        isFinal);
}

Statement *SwitchStatement::semantic(Scope *sc)
{
    //printf("SwitchStatement::semantic(%p)\n", this);
    tf = sc->tf;
    if (cases)
        return this;            // already run
    bool conditionError = false;
    condition = condition->semantic(sc);
    condition = resolveProperties(sc, condition);
    TypeEnum *te = NULL;
    // preserve enum type for final switches
    if (condition->type->ty == Tenum)
        te = (TypeEnum *)condition->type;
    if (condition->type->isString())
    {
        // If it's not an array, cast it to one
        if (condition->type->ty != Tarray)
        {
            condition = condition->implicitCastTo(sc, condition->type->nextOf()->arrayOf());
        }
        condition->type = condition->type->constOf();
    }
    else
    {
        condition = integralPromotions(condition, sc);
        if (condition->op != TOKerror && !condition->type->isintegral())
        {
            error("'%s' must be of integral or string type, it is a %s", condition->toChars(), condition->type->toChars());
            conditionError = true;;
        }
    }
    condition = condition->optimize(WANTvalue);
    condition = checkGC(sc, condition);
    if (condition->op == TOKerror)
        conditionError = true;

    bool needswitcherror = false;

    sc = sc->push();
    sc->sbreak = this;
    sc->sw = this;

    cases = new CaseStatements();
    sc->noctor++;       // BUG: should use Scope::mergeCallSuper() for each case instead
    body = body->semantic(sc);
    sc->noctor--;

    if (conditionError || body->isErrorStatement())
        goto Lerror;

    // Resolve any goto case's with exp
    for (size_t i = 0; i < gotoCases.dim; i++)
    {
        GotoCaseStatement *gcs = gotoCases[i];

        if (!gcs->exp)
        {
            gcs->error("no case statement following goto case;");
            goto Lerror;
        }

        for (Scope *scx = sc; scx; scx = scx->enclosing)
        {
            if (!scx->sw)
                continue;
            for (size_t j = 0; j < scx->sw->cases->dim; j++)
            {
                CaseStatement *cs = (*scx->sw->cases)[j];

                if (cs->exp->equals(gcs->exp))
                {
                    gcs->cs = cs;
                    goto Lfoundcase;
                }
            }
        }
        gcs->error("case %s not found", gcs->exp->toChars());
        goto Lerror;

     Lfoundcase:
        ;
    }

    if (isFinal)
    {
        Type *t = condition->type;
        Dsymbol *ds;
        EnumDeclaration *ed = NULL;
        if (t && ((ds = t->toDsymbol(sc)) != NULL))
            ed = ds->isEnumDeclaration();  // typedef'ed enum
        if (!ed && te && ((ds = te->toDsymbol(sc)) != NULL))
            ed = ds->isEnumDeclaration();
        if (ed)
        {
            size_t dim = ed->members->dim;
            for (size_t i = 0; i < dim; i++)
            {
                EnumMember *em = (*ed->members)[i]->isEnumMember();
                if (em)
                {
                    for (size_t j = 0; j < cases->dim; j++)
                    {
                        CaseStatement *cs = (*cases)[j];
                        if (cs->exp->equals(em->value) ||
                                (!cs->exp->type->isString() && !em->value->type->isString() &&
                                cs->exp->toInteger() == em->value->toInteger()))
                            goto L1;
                    }
                    error("enum member %s not represented in final switch", em->toChars());
                    goto Lerror;
                }
              L1:
                ;
            }
        }
        else
            needswitcherror = true;
    }

    if (!sc->sw->sdefault && (!isFinal || needswitcherror || global.params.useAssert))
    {
        hasNoDefault = 1;

        if (!isFinal && !body->isErrorStatement())
           deprecation("switch statement without a default is deprecated; use 'final switch' or add 'default: assert(0);' or add 'default: break;'");

        // Generate runtime error if the default is hit
        Statements *a = new Statements();
        CompoundStatement *cs;
        Statement *s;

        if (global.params.useSwitchError)
            s = new SwitchErrorStatement(loc);
        else
            s = new ExpStatement(loc, new HaltExp(loc));

        a->reserve(2);
        sc->sw->sdefault = new DefaultStatement(loc, s);
        a->push(body);
        if (body->blockExit(sc->func, false) & BEfallthru)
            a->push(new BreakStatement(Loc(), NULL));
        a->push(sc->sw->sdefault);
        cs = new CompoundStatement(loc, a);
        body = cs;
    }

    sc->pop();
    return this;

  Lerror:
    sc->pop();
    return new ErrorStatement();
}

bool SwitchStatement::hasBreak()
{
    return true;
}

/******************************** CaseStatement ***************************/

CaseStatement::CaseStatement(Loc loc, Expression *exp, Statement *s)
    : Statement(loc)
{
    this->exp = exp;
    this->statement = s;
    index = 0;
    cblock = NULL;
}

Statement *CaseStatement::syntaxCopy()
{
    return new CaseStatement(loc,
        exp->syntaxCopy(),
        statement->syntaxCopy());
}

Statement *CaseStatement::semantic(Scope *sc)
{
    SwitchStatement *sw = sc->sw;
    bool errors = false;

    //printf("CaseStatement::semantic() %s\n", toChars());
    sc = sc->startCTFE();
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    sc = sc->endCTFE();
    if (sw)
    {
        exp = exp->implicitCastTo(sc, sw->condition->type);
        exp = exp->optimize(WANTvalue);

        /* This is where variables are allowed as case expressions.
         */
        if (exp->op == TOKvar)
        {   VarExp *ve = (VarExp *)exp;
            VarDeclaration *v = ve->var->isVarDeclaration();
            Type *t = exp->type->toBasetype();
            if (v && (t->isintegral() || t->ty == Tclass))
            {   /* Flag that we need to do special code generation
                 * for this, i.e. generate a sequence of if-then-else
                 */
                sw->hasVars = 1;
                if (sw->isFinal)
                {
                    error("case variables not allowed in final switch statements");
                    errors = true;
                }
                goto L1;
            }
        }
        else
            exp = exp->ctfeInterpret();

        if (StringExp *se = exp->toStringExp())
            exp = se;
        else if (exp->op != TOKint64 && exp->op != TOKerror)
        {
            error("case must be a string or an integral constant, not %s", exp->toChars());
            errors = true;
        }

    L1:
        for (size_t i = 0; i < sw->cases->dim; i++)
        {
            CaseStatement *cs = (*sw->cases)[i];

            //printf("comparing '%s' with '%s'\n", exp->toChars(), cs->exp->toChars());
            if (cs->exp->equals(exp))
            {
                error("duplicate case %s in switch statement", exp->toChars());
                errors = true;
                break;
            }
        }

        sw->cases->push(this);

        // Resolve any goto case's with no exp to this case statement
        for (size_t i = 0; i < sw->gotoCases.dim; i++)
        {
            GotoCaseStatement *gcs = sw->gotoCases[i];

            if (!gcs->exp)
            {
                gcs->cs = this;
                sw->gotoCases.remove(i);        // remove from array
            }
        }

        if (sc->sw->tf != sc->tf)
        {
            error("switch and case are in different finally blocks");
            errors = true;
        }
    }
    else
    {
        error("case not in switch statement");
        errors = true;
    }
    statement = statement->semantic(sc);
    if (statement->isErrorStatement())
        return statement;
    if (errors || exp->op == TOKerror)
        return new ErrorStatement();
    return this;
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

Statement *CaseRangeStatement::semantic(Scope *sc)
{   SwitchStatement *sw = sc->sw;

    if (sw == NULL)
    {
        error("case range not in switch statement");
        return new ErrorStatement();
    }

    //printf("CaseRangeStatement::semantic() %s\n", toChars());
    bool errors = false;
    if (sw->isFinal)
    {
        error("case ranges not allowed in final switch");
        errors = true;
    }

    sc = sc->startCTFE();
    first = first->semantic(sc);
    first = resolveProperties(sc, first);
    sc = sc->endCTFE();
    first = first->implicitCastTo(sc, sw->condition->type);
    first = first->ctfeInterpret();

    sc = sc->startCTFE();
    last = last->semantic(sc);
    last = resolveProperties(sc, last);
    sc = sc->endCTFE();
    last = last->implicitCastTo(sc, sw->condition->type);
    last = last->ctfeInterpret();

    if (first->op == TOKerror || last->op == TOKerror || errors)
    {
        if (statement)
            statement->semantic(sc);
        return new ErrorStatement();
    }

    uinteger_t fval = first->toInteger();
    uinteger_t lval = last->toInteger();


    if ( (first->type->isunsigned()  &&  fval > lval) ||
        (!first->type->isunsigned()  &&  (sinteger_t)fval > (sinteger_t)lval))
    {
        error("first case %s is greater than last case %s",
            first->toChars(), last->toChars());
        errors = true;
        lval = fval;
    }

    if (lval - fval > 256)
    {
        error("had %llu cases which is more than 256 cases in case range", lval - fval);
        errors = true;
        lval = fval + 256;
    }

    if (errors)
        return new ErrorStatement();

    /* This works by replacing the CaseRange with an array of Case's.
     *
     * case a: .. case b: s;
     *    =>
     * case a:
     *   [...]
     * case b:
     *   s;
     */

    Statements *statements = new Statements();
    for (uinteger_t i = fval; i != lval + 1; i++)
    {
        Statement *s = statement;
        if (i != lval)                          // if not last case
            s = new ExpStatement(loc, (Expression *)NULL);
        Expression *e = new IntegerExp(loc, i, first->type);
        Statement *cs = new CaseStatement(loc, e, s);
        statements->push(cs);
    }
    Statement *s = new CompoundStatement(loc, statements);
    s = s->semantic(sc);
    return s;
}

/******************************** DefaultStatement ***************************/

DefaultStatement::DefaultStatement(Loc loc, Statement *s)
    : Statement(loc)
{
    this->statement = s;
#ifdef IN_GCC
    cblock = NULL;
#endif
}

Statement *DefaultStatement::syntaxCopy()
{
    return new DefaultStatement(loc, statement->syntaxCopy());
}

Statement *DefaultStatement::semantic(Scope *sc)
{
    //printf("DefaultStatement::semantic()\n");
    bool errors = false;
    if (sc->sw)
    {
        if (sc->sw->sdefault)
        {
            error("switch statement already has a default");
            errors = true;
        }
        sc->sw->sdefault = this;

        if (sc->sw->tf != sc->tf)
        {
            error("switch and default are in different finally blocks");
            errors = true;
        }
        if (sc->sw->isFinal)
        {
            error("default statement not allowed in final switch statement");
            errors = true;
        }
    }
    else
    {
        error("default not in switch statement");
        errors = true;
    }
    statement = statement->semantic(sc);
    if (errors || statement->isErrorStatement())
        return new ErrorStatement();
    return this;
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

Statement *GotoDefaultStatement::semantic(Scope *sc)
{
    sw = sc->sw;
    if (!sw)
    {
        error("goto default not in switch statement");
        return new ErrorStatement();
    }
    return this;
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

Statement *GotoCaseStatement::semantic(Scope *sc)
{
    if (!sc->sw)
    {
        error("goto case not in switch statement");
        return new ErrorStatement();
    }

    if (exp)
    {
        exp = exp->semantic(sc);
        exp = exp->implicitCastTo(sc, sc->sw->condition->type);
        exp = exp->optimize(WANTvalue);
        if (exp->op == TOKerror)
            return new ErrorStatement();
    }

    sc->sw->gotoCases.push(this);
    return this;
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

Statement *ReturnStatement::semantic(Scope *sc)
{
    //printf("ReturnStatement::semantic() %s\n", toChars());

    FuncDeclaration *fd = sc->parent->isFuncDeclaration();
    Scope *scx = sc;
    Expression *eorg = NULL;

    if (fd->fes)
        fd = fd->fes->func;             // fd is now function enclosing foreach

    TypeFunction *tf = (TypeFunction *)fd->type;
    assert(tf->ty == Tfunction);

    if (exp && exp->op == TOKvar && ((VarExp *)exp)->var == fd->vresult)
    {
        // return vresult;
        if (sc->fes)
        {
            assert(caseDim == 0);
            sc->fes->cases->push(this);
            return new ReturnStatement(Loc(), new IntegerExp(sc->fes->cases->dim + 1));
        }
        if (fd->returnLabel)
        {
            GotoStatement *gs = new GotoStatement(loc, Id::returnLabel);
            gs->label = fd->returnLabel;
            return gs;
        }

        if (!fd->returns)
            fd->returns = new ReturnStatements();
        fd->returns->push(this);
        return this;
    }

    Type *tret = tf->next;
    Type *tbret = tret ? tret->toBasetype() : NULL;

    bool inferRef = (tf->isref && (fd->storage_class & STCauto));
    Expression *e0 = NULL;

    bool errors = false;
    if (sc->flags & SCOPEcontract)
    {
        error("return statements cannot be in contracts");
        errors = true;
    }
    if (sc->os && sc->os->tok != TOKon_scope_failure)
    {
        error("return statements cannot be in %s bodies", Token::toChars(sc->os->tok));
        errors = true;
    }
    if (sc->tf)
    {
        error("return statements cannot be in finally bodies");
        errors = true;
    }

    if (fd->isCtorDeclaration())
    {
        if (exp)
        {
            error("cannot return expression from constructor");
            errors = true;
        }

        // Constructors implicitly do:
        //      return this;
        exp = new ThisExp(Loc());
        exp->type = tret;
    }
    else if (exp)
    {
        fd->hasReturnExp |= 1;

        FuncLiteralDeclaration *fld = fd->isFuncLiteralDeclaration();
        if (tret)
            exp = inferType(exp, tret);
        else if (fld && fld->treq)
            exp = inferType(exp, fld->treq->nextOf()->nextOf());
        exp = exp->semantic(sc);
        exp = resolveProperties(sc, exp);
        if (exp->type && exp->type->ty != Tvoid ||
            exp->op == TOKfunction || exp->op == TOKtype || exp->op == TOKtemplate)
        {
            if (!exp->rvalue()) // don't make error for void expression
                exp = new ErrorExp();
        }
        if (checkNonAssignmentArrayOp(exp))
            exp = new ErrorExp();
        if (exp->op == TOKcall)
            exp = valueNoDtor(exp);

        // Extract side-effect part
        exp = Expression::extractLast(exp, &e0);

        /* Void-return function can have void typed expression
         * on return statement.
         */
        if (tbret && tbret->ty == Tvoid || exp->type->ty == Tvoid)
        {
            if (exp->type->ty != Tvoid)
            {
                error("cannot return non-void from void function");
                errors = true;

                exp = new CastExp(loc, exp, Type::tvoid);
                exp = exp->semantic(sc);
            }

            /* Replace:
             *      return exp;
             * with:
             *      exp; return;
             */
            e0 = Expression::combine(e0, exp);
            exp = NULL;
        }
        if (e0)
            e0 = checkGC(sc, e0);
    }

    if (exp)
    {
        if (fd->inferRetType)       // infer return type
        {
            if (!tret)
            {
                tf->next = exp->type;
            }
            else if (tret->ty != Terror && !exp->type->equals(tret))
            {
                int m1 = exp->type->implicitConvTo(tret);
                int m2 = tret->implicitConvTo(exp->type);
                //printf("exp->type = %s m2<-->m1 tret %s\n", exp->type->toChars(), tret->toChars());
                //printf("m1 = %d, m2 = %d\n", m1, m2);

                if (m1 && m2)
                    ;
                else if (!m1 && m2)
                    tf->next = exp->type;
                else if (m1 && !m2)
                    ;
                else if (exp->op != TOKerror)
                {
                    error("mismatched function return type inference of %s and %s",
                        exp->type->toChars(), tret->toChars());
                    errors = true;
                    tf->next = Type::terror;
                }
            }

            tret = tf->next;
            tbret = tret->toBasetype();
        }

        if (inferRef)               // deduce 'auto ref'
        {
            /* Determine "refness" of function return:
             * if it's an lvalue, return by ref, else return by value
             */
            if (exp->isLvalue())
            {
                /* May return by ref
                 */
                unsigned olderrors = global.startGagging();
                exp->checkEscapeRef();
                if (global.endGagging(olderrors))
                    tf->isref = false;  // return by value
            }
            else
                tf->isref = false;      // return by value

            /* The "refness" is determined by all of return statements.
             * This means:
             *    return 3; return x;  // ok, x can be a value
             *    return x; return 3;  // ok, x can be a value
             */
        }

        // handle NRVO
        if (fd->nrvo_can && exp->op == TOKvar)
        {
            VarExp *ve = (VarExp *)exp;
            VarDeclaration *v = ve->var->isVarDeclaration();

            if (tf->isref)
            {
                // Function returns a reference
                if (!inferRef)
                    fd->nrvo_can = 0;
            }
            else if (!v || v->isOut() || v->isRef())
                fd->nrvo_can = 0;
            else if (fd->nrvo_var == NULL)
            {
                if (!v->isDataseg() && !v->isParameter() && v->toParent2() == fd)
                {
                    //printf("Setting nrvo to %s\n", v->toChars());
                    fd->nrvo_var = v;
                }
                else
                    fd->nrvo_can = 0;
            }
            else if (fd->nrvo_var != v)
                fd->nrvo_can = 0;
        }
        else //if (!exp->isLvalue())    // keep NRVO-ability
            fd->nrvo_can = 0;
    }
    else
    {
        // handle NRVO
        fd->nrvo_can = 0;

        // infer return type
        if (fd->inferRetType)
        {
            if (tf->next && tf->next->ty != Tvoid)
            {
                error("mismatched function return type inference of void and %s",
                    tf->next->toChars());
                errors = true;
            }
            tf->next = Type::tvoid;

            tret = tf->next;
            tbret = tret->toBasetype();
        }

        if (inferRef)               // deduce 'auto ref'
            tf->isref = false;

        if (tbret->ty != Tvoid)     // if non-void return
        {
            error("return expression expected");
            errors = true;
        }
        else if (fd->isMain())
        {
            // main() returns 0, even if it returns void
            exp = new IntegerExp(0);
        }
    }

    // If any branches have called a ctor, but this branch hasn't, it's an error
    if (sc->callSuper & CSXany_ctor &&
        !(sc->callSuper & (CSXthis_ctor | CSXsuper_ctor)))
    {
        error("return without calling constructor");
        errors = true;
    }
    sc->callSuper |= CSXreturn;
    if (sc->fieldinit)
    {
        AggregateDeclaration *ad = fd->isAggregateMember2();
        assert(ad);
        size_t dim = sc->fieldinit_dim;
        for (size_t i = 0; i < dim; i++)
        {
            VarDeclaration *v = ad->fields[i];
            bool mustInit = (v->storage_class & STCnodefaultctor ||
                             v->type->needsNested());
            if (mustInit && !(sc->fieldinit[i] & CSXthis_ctor))
            {
                error("an earlier return statement skips field %s initialization", v->toChars());
                errors = true;
            }
            sc->fieldinit[i] |= CSXreturn;
        }
    }

    if (errors)
        return new ErrorStatement();

    if (sc->fes)
    {
        if (!exp)
        {
            // Send out "case receiver" statement to the foreach.
            //  return exp;
            Statement *s = new ReturnStatement(Loc(), exp);
            sc->fes->cases->push(s);

            // Immediately rewrite "this" return statement as:
            //  return cases->dim+1;
            this->exp = new IntegerExp(sc->fes->cases->dim + 1);
            if (e0)
                return new CompoundStatement(loc, new ExpStatement(loc, e0), this);
            return this;
        }
        else
        {
            fd->buildResultVar(NULL, exp->type);
            fd->vresult->checkNestedReference(sc, Loc());

            // Send out "case receiver" statement to the foreach.
            //  return vresult;
            Statement *s = new ReturnStatement(Loc(), new VarExp(Loc(), fd->vresult));
            sc->fes->cases->push(s);

            // Save receiver index for the later rewriting from:
            //  return exp;
            // to:
            //  vresult = exp; retrun caseDim;
            caseDim = sc->fes->cases->dim + 1;
        }
    }
    if (exp)
    {
        if (!fd->returns)
            fd->returns = new ReturnStatements();
        fd->returns->push(this);
    }
    if (e0)
        return new CompoundStatement(loc, new ExpStatement(loc, e0), this);
    return this;
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

Statement *BreakStatement::semantic(Scope *sc)
{
    //printf("BreakStatement::semantic()\n");
    // If:
    //  break Identifier;
    if (ident)
    {
        ident = fixupLabelName(sc, ident);

        FuncDeclaration *thisfunc = sc->func;

        for (Scope *scx = sc; scx; scx = scx->enclosing)
        {
            if (scx->func != thisfunc)  // if in enclosing function
            {
                if (sc->fes)            // if this is the body of a foreach
                {
                    /* Post this statement to the fes, and replace
                     * it with a return value that caller will put into
                     * a switch. Caller will figure out where the break
                     * label actually is.
                     * Case numbers start with 2, not 0, as 0 is continue
                     * and 1 is break.
                     */
                    sc->fes->cases->push(this);
                    Statement *s = new ReturnStatement(Loc(), new IntegerExp(sc->fes->cases->dim + 1));
                    return s;
                }
                break;                  // can't break to it
            }

            LabelStatement *ls = scx->slabel;
            if (ls && ls->ident == ident)
            {
                Statement *s = ls->statement;

                if (!s || !s->hasBreak())
                    error("label '%s' has no break", ident->toChars());
                else if (ls->tf != sc->tf)
                    error("cannot break out of finally block");
                else
                    return this;
                return new ErrorStatement();
            }
        }
        error("enclosing label '%s' for break not found", ident->toChars());
        return new ErrorStatement();
    }
    else if (!sc->sbreak)
    {
        if (sc->os && sc->os->tok != TOKon_scope_failure)
        {
            error("break is not inside %s bodies", Token::toChars(sc->os->tok));
        }
        else if (sc->fes)
        {
            // Replace break; with return 1;
            Statement *s = new ReturnStatement(Loc(), new IntegerExp(1));
            return s;
        }
        else
            error("break is not inside a loop or switch");
        return new ErrorStatement();
    }
    return this;
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

Statement *ContinueStatement::semantic(Scope *sc)
{
    //printf("ContinueStatement::semantic() %p\n", this);
    if (ident)
    {
        ident = fixupLabelName(sc, ident);

        Scope *scx;
        FuncDeclaration *thisfunc = sc->func;

        for (scx = sc; scx; scx = scx->enclosing)
        {
            LabelStatement *ls;

            if (scx->func != thisfunc)  // if in enclosing function
            {
                if (sc->fes)            // if this is the body of a foreach
                {
                    for (; scx; scx = scx->enclosing)
                    {
                        ls = scx->slabel;
                        if (ls && ls->ident == ident && ls->statement == sc->fes)
                        {
                            // Replace continue ident; with return 0;
                            return new ReturnStatement(Loc(), new IntegerExp(0));
                        }
                    }

                    /* Post this statement to the fes, and replace
                     * it with a return value that caller will put into
                     * a switch. Caller will figure out where the break
                     * label actually is.
                     * Case numbers start with 2, not 0, as 0 is continue
                     * and 1 is break.
                     */
                    sc->fes->cases->push(this);
                    Statement *s = new ReturnStatement(Loc(), new IntegerExp(sc->fes->cases->dim + 1));
                    return s;
                }
                break;                  // can't continue to it
            }

            ls = scx->slabel;
            if (ls && ls->ident == ident)
            {
                Statement *s = ls->statement;

                if (!s || !s->hasContinue())
                    error("label '%s' has no continue", ident->toChars());
                else if (ls->tf != sc->tf)
                    error("cannot continue out of finally block");
                else
                    return this;
                return new ErrorStatement();
            }
        }
        error("enclosing label '%s' for continue not found", ident->toChars());
        return new ErrorStatement();
    }
    else if (!sc->scontinue)
    {
        if (sc->os && sc->os->tok != TOKon_scope_failure)
        {
            error("continue is not inside %s bodies", Token::toChars(sc->os->tok));
        }
        else if (sc->fes)
        {
            // Replace continue; with return 0;
            Statement *s = new ReturnStatement(Loc(), new IntegerExp(0));
            return s;
        }
        else
            error("continue is not inside a loop");
        return new ErrorStatement();
    }
    return this;
}

/******************************** SynchronizedStatement ***************************/

SynchronizedStatement::SynchronizedStatement(Loc loc, Expression *exp, Statement *body)
    : Statement(loc)
{
    this->exp = exp;
    this->body = body;
}

Statement *SynchronizedStatement::syntaxCopy()
{
    return new SynchronizedStatement(loc,
        exp ? exp->syntaxCopy() : NULL,
        body ? body->syntaxCopy() : NULL);
}

Statement *SynchronizedStatement::semantic(Scope *sc)
{
    if (exp)
    {
        exp = exp->semantic(sc);
        exp = resolveProperties(sc, exp);
        // exp = exp->optimize(0);  //?
        exp = checkGC(sc, exp);
        if (exp->op == TOKerror)
            goto Lbody;
        ClassDeclaration *cd = exp->type->isClassHandle();
        if (!cd)
        {
            error("can only synchronize on class objects, not '%s'", exp->type->toChars());
            return new ErrorStatement();
        }
        else if (cd->isInterfaceDeclaration())
        {   /* Cast the interface to an object, as the object has the monitor,
             * not the interface.
             */
            if (!ClassDeclaration::object)
            {
                error("missing or corrupt object.d");
                fatal();
            }

            Type *t = ClassDeclaration::object->type;
            t = t->semantic(Loc(), sc)->toBasetype();
            assert(t->ty == Tclass);

            exp = new CastExp(loc, exp, t);
            exp = exp->semantic(sc);
        }

#if 1
        /* Rewrite as:
         *  auto tmp = exp;
         *  _d_monitorenter(tmp);
         *  try { body } finally { _d_monitorexit(tmp); }
         */
        Identifier *id = Lexer::uniqueId("__sync");
        ExpInitializer *ie = new ExpInitializer(loc, exp);
        VarDeclaration *tmp = new VarDeclaration(loc, exp->type, id, ie);
        tmp->storage_class |= STCtemp;

        Statements *cs = new Statements();
        cs->push(new ExpStatement(loc, tmp));

        Parameters* args = new Parameters;
        args->push(new Parameter(0, ClassDeclaration::object->type, NULL, NULL));

        FuncDeclaration *fdenter = FuncDeclaration::genCfunc(args, Type::tvoid, Id::monitorenter, STCnothrow);
        Expression *e = new CallExp(loc, new VarExp(loc, fdenter), new VarExp(loc, tmp));
        e->type = Type::tvoid;                  // do not run semantic on e
        cs->push(new ExpStatement(loc, e));

        FuncDeclaration *fdexit = FuncDeclaration::genCfunc(args, Type::tvoid, Id::monitorexit, STCnothrow);
        e = new CallExp(loc, new VarExp(loc, fdexit), new VarExp(loc, tmp));
        e->type = Type::tvoid;                  // do not run semantic on e
        Statement *s = new ExpStatement(loc, e);
        s = new TryFinallyStatement(loc, body, s);
        cs->push(s);

        s = new CompoundStatement(loc, cs);
        return s->semantic(sc);
#endif
    }
    else
    {
        /* Generate our own critical section, then rewrite as:
         *  __gshared byte[CriticalSection.sizeof] critsec;
         *  _d_criticalenter(critsec.ptr);
         *  try { body } finally { _d_criticalexit(critsec.ptr); }
         */
        Identifier *id = Lexer::uniqueId("__critsec");
        Type *t = new TypeSArray(Type::tint8, new IntegerExp(Target::ptrsize + Target::critsecsize()));
        VarDeclaration *tmp = new VarDeclaration(loc, t, id, NULL);
        tmp->storage_class |= STCtemp | STCgshared | STCstatic;

        Statements *cs = new Statements();
        cs->push(new ExpStatement(loc, tmp));

        /* This is just a dummy variable for "goto skips declaration" error.
         * Backend optimizer could remove this unused variable.
         */
        VarDeclaration *v = new VarDeclaration(loc, Type::tvoidptr, Lexer::uniqueId("__sync"), NULL);
        v->semantic(sc);
        cs->push(new ExpStatement(loc, v));

        Parameters* args = new Parameters;
        args->push(new Parameter(0, t->pointerTo(), NULL, NULL));

        FuncDeclaration *fdenter = FuncDeclaration::genCfunc(args, Type::tvoid, Id::criticalenter);
        Expression *e = new DotIdExp(loc, new VarExp(loc, tmp), Id::ptr);
        e = e->semantic(sc);
        e = new CallExp(loc, new VarExp(loc, fdenter), e);
        e->type = Type::tvoid;                  // do not run semantic on e
        cs->push(new ExpStatement(loc, e));

        FuncDeclaration *fdexit = FuncDeclaration::genCfunc(args, Type::tvoid, Id::criticalexit);
        e = new DotIdExp(loc, new VarExp(loc, tmp), Id::ptr);
        e = e->semantic(sc);
        e = new CallExp(loc, new VarExp(loc, fdexit), e);
        e->type = Type::tvoid;                  // do not run semantic on e
        Statement *s = new ExpStatement(loc, e);
        s = new TryFinallyStatement(loc, body, s);
        cs->push(s);

        s = new CompoundStatement(loc, cs);
        return s->semantic(sc);
    }
Lbody:
    if (body)
        body = body->semantic(sc);
    if (body && body->isErrorStatement())
        return body;
    return this;
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

WithStatement::WithStatement(Loc loc, Expression *exp, Statement *body)
    : Statement(loc)
{
    this->exp = exp;
    this->body = body;
    wthis = NULL;
}

Statement *WithStatement::syntaxCopy()
{
    return new WithStatement(loc,
        exp->syntaxCopy(),
        body ? body->syntaxCopy() : NULL);
}

Statement *WithStatement::semantic(Scope *sc)
{
    ScopeDsymbol *sym;
    Initializer *init;

    //printf("WithStatement::semantic()\n");
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    // exp = exp_>optimize(0);  //?
    exp = checkGC(sc, exp);
    if (exp->op == TOKerror)
        return new ErrorStatement();
    if (exp->op == TOKimport)
    {
        sym = new WithScopeSymbol(this);
        sym->parent = sc->scopesym;
    }
    else if (exp->op == TOKtype)
    {
        Dsymbol *s = ((TypeExp *)exp)->type->toDsymbol(sc);
        if (!s || !s->isScopeDsymbol())
        {
            error("with type %s has no members", exp->toChars());
            return new ErrorStatement();
        }
        sym = new WithScopeSymbol(this);
        sym->parent = sc->scopesym;
    }
    else
    {
        Type *t = exp->type->toBasetype();

        Expression *olde = exp;
        if (t->ty == Tpointer)
        {
            exp = new PtrExp(loc, exp);
            exp = exp->semantic(sc);
            t = exp->type->toBasetype();
        }

        assert(t);
        t = t->toBasetype();
        if (t->isClassHandle())
        {
            init = new ExpInitializer(loc, exp);
            wthis = new VarDeclaration(loc, exp->type, Id::withSym, init);
            wthis->semantic(sc);

            sym = new WithScopeSymbol(this);
            sym->parent = sc->scopesym;
        }
        else if (t->ty == Tstruct)
        {
            if (!exp->isLvalue())
            {
                /* Re-write to
                 * {
                 *   auto __withtmp = exp
                 *   with(__withtmp)
                 *   {
                 *     ...
                 *   }
                 * }
                 */
                init = new ExpInitializer(loc, exp);
                wthis = new VarDeclaration(loc, exp->type, Lexer::uniqueId("__withtmp"), init);
                wthis->storage_class |= STCtemp;
                ExpStatement *es = new ExpStatement(loc, new DeclarationExp(loc, wthis));
                exp = new VarExp(loc, wthis);
                Statement *ss = new ScopeStatement(loc, new CompoundStatement(loc, es, this));
                return ss->semantic(sc);
            }
            Expression *e = exp->addressOf();
            init = new ExpInitializer(loc, e);
            wthis = new VarDeclaration(loc, e->type, Id::withSym, init);
            wthis->semantic(sc);
            sym = new WithScopeSymbol(this);
            // Need to set the scope to make use of resolveAliasThis
            sym->setScope(sc);
            sym->parent = sc->scopesym;
        }
        else
        {
            error("with expressions must be aggregate types or pointers to them, not '%s'", olde->type->toChars());
            return new ErrorStatement();
        }
    }

    if (body)
    {
        sym->scope = sc;
        sc = sc->push(sym);
        sc->insert(sym);
        body = body->semantic(sc);
        sc->pop();
        if (body && body->isErrorStatement())
            return body;
    }

    return this;
}

/******************************** TryCatchStatement ***************************/

TryCatchStatement::TryCatchStatement(Loc loc, Statement *body, Catches *catches)
    : Statement(loc)
{
    this->body = body;
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
    return new TryCatchStatement(loc, body->syntaxCopy(), a);
}

Statement *TryCatchStatement::semantic(Scope *sc)
{
    body = body->semanticScope(sc, NULL, NULL);
    assert(body);

    /* Even if body is empty, still do semantic analysis on catches
     */
    bool catchErrors = false;
    for (size_t i = 0; i < catches->dim; i++)
    {   Catch *c = (*catches)[i];
        c->semantic(sc);
        if (c->type->ty == Terror)
        {   catchErrors = true;
            continue;
        }

        // Determine if current catch 'hides' any previous catches
        for (size_t j = 0; j < i; j++)
        {   Catch *cj = (*catches)[j];
            char *si = c->loc.toChars();
            char *sj = cj->loc.toChars();

            if (c->type->toBasetype()->implicitConvTo(cj->type->toBasetype()))
            {
                error("catch at %s hides catch at %s", sj, si);
                catchErrors = true;
            }
        }
    }
    if (catchErrors)
        return new ErrorStatement();

    if (body->isErrorStatement())
        return body;

    /* If the try body never throws, we can eliminate any catches
     * of recoverable exceptions.
     */

    if (!(body->blockExit(sc->func, false) & BEthrow) && ClassDeclaration::exception)
    {
        for (size_t i = 0; i < catches->dim; i++)
        {   Catch *c = (*catches)[i];

            /* If catch exception type is derived from Exception
             */
            if (c->type->toBasetype()->implicitConvTo(ClassDeclaration::exception->type) &&
                (!c->handler || !c->handler->comeFrom()))
            {   // Remove c from the array of catches
                catches->remove(i);
                --i;
            }
        }
    }

    if (catches->dim == 0)
        return body->hasCode() ? body : NULL;

    return this;
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

void Catch::semantic(Scope *sc)
{
    //printf("Catch::semantic(%s)\n", ident->toChars());

#ifndef IN_GCC
    if (sc->os && sc->os->tok != TOKon_scope_failure)
    {
        // If enclosing is scope(success) or scope(exit), this will be placed in finally block.
        error(loc, "cannot put catch statement inside %s", Token::toChars(sc->os->tok));
    }
    if (sc->tf)
    {
        /* This is because the _d_local_unwind() gets the stack munged
         * up on this. The workaround is to place any try-catches into
         * a separate function, and call that.
         * To fix, have the compiler automatically convert the finally
         * body into a nested function.
         */
        error(loc, "cannot put catch statement inside finally block");
    }
#endif

    ScopeDsymbol *sym = new ScopeDsymbol();
    sym->parent = sc->scopesym;
    sc = sc->push(sym);

    if (!type)
    {
        // reference .object.Throwable
        TypeIdentifier *tid = new TypeIdentifier(Loc(), Id::empty);
        tid->addIdent(Id::object);
        tid->addIdent(Id::Throwable);
        type = tid;
    }
    type = type->semantic(loc, sc);
    ClassDeclaration *cd = type->toBasetype()->isClassHandle();
    if (!cd || ((cd != ClassDeclaration::throwable) && !ClassDeclaration::throwable->isBaseOf(cd, NULL)))
    {
        if (type != Type::terror)
        {
            error(loc, "can only catch class objects derived from Throwable, not '%s'", type->toChars());
            type = Type::terror;
        }
    }
    else if (sc->func &&
        !sc->intypeof &&
        !internalCatch &&
        cd != ClassDeclaration::exception &&
        !ClassDeclaration::exception->isBaseOf(cd, NULL) &&
        sc->func->setUnsafe())
    {
        error(loc, "can only catch class objects derived from Exception in @safe code, not '%s'", type->toChars());
        type = Type::terror;
    }
    else if (ident)
    {
        var = new VarDeclaration(loc, type, ident, NULL);
        var->semantic(sc);
        sc->insert(var);
    }
    handler = handler->semantic(sc);

    sc->pop();
}

/****************************** TryFinallyStatement ***************************/

TryFinallyStatement::TryFinallyStatement(Loc loc, Statement *body, Statement *finalbody)
    : Statement(loc)
{
    this->body = body;
    this->finalbody = finalbody;
}

TryFinallyStatement *TryFinallyStatement::create(Loc loc, Statement *body, Statement *finalbody)
{
    return new TryFinallyStatement(loc, body, finalbody);
}

Statement *TryFinallyStatement::syntaxCopy()
{
    return new TryFinallyStatement(loc,
        body->syntaxCopy(), finalbody->syntaxCopy());
}

Statement *TryFinallyStatement::semantic(Scope *sc)
{
    //printf("TryFinallyStatement::semantic()\n");
    body = body->semantic(sc);
    sc = sc->push();
    sc->tf = this;
    sc->sbreak = NULL;
    sc->scontinue = NULL;       // no break or continue out of finally block
    finalbody = finalbody->semanticNoScope(sc);
    sc->pop();
    if (!body)
        return finalbody;
    if (!finalbody)
        return body;
    if (body->blockExit(sc->func, false) == BEfallthru)
    {
        Statement *s = new CompoundStatement(loc, body, finalbody);
        return s;
    }
    return this;
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

Statement *OnScopeStatement::semantic(Scope *sc)
{
#ifndef IN_GCC
    if (tok != TOKon_scope_exit)
    {
        // scope(success) and scope(failure) are rewritten to try-catch(-finally) statement,
        // so the generated catch block cannot be placed in finally block.
        // See also Catch::semantic.
        if (sc->os && sc->os->tok != TOKon_scope_failure)
        {
            // If enclosing is scope(success) or scope(exit), this will be placed in finally block.
            error("cannot put %s statement inside %s", Token::toChars(tok), Token::toChars(sc->os->tok));
            return new ErrorStatement();
        }
        if (sc->tf)
        {
            error("cannot put %s statement inside finally block", Token::toChars(tok));
            return new ErrorStatement();
        }
    }
#endif

    sc = sc->push();
    sc->tf = NULL;
    sc->os = this;
    if (tok != TOKon_scope_failure)
    {
        // Jump out from scope(failure) block is allowed.
        sc->sbreak = NULL;
        sc->scontinue = NULL;
    }
    statement = statement->semanticNoScope(sc);
    sc->pop();

    if (!statement || statement->isErrorStatement())
        return statement;
    return this;
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
            Identifier *id = Lexer::uniqueId("__os");

            ExpInitializer *ie = new ExpInitializer(loc, new IntegerExp(Loc(), 0, Type::tbool));
            VarDeclaration *v = new VarDeclaration(loc, Type::tbool, id, ie);
            v->storage_class |= STCtemp;
            *sentry = new ExpStatement(loc, v);

            Expression *e = new IntegerExp(Loc(), 1, Type::tbool);
            e = new AssignExp(Loc(), new VarExp(Loc(), v), e);
            *sexception = new ExpStatement(Loc(), e);

            e = new VarExp(Loc(), v);
            e = new NotExp(Loc(), e);
            *sfinally = new IfStatement(Loc(), NULL, e, s, NULL);

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

Statement *ThrowStatement::semantic(Scope *sc)
{
    //printf("ThrowStatement::semantic()\n");

    FuncDeclaration *fd = sc->parent->isFuncDeclaration();
    fd->hasReturnExp |= 2;

    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    exp = checkGC(sc, exp);
    if (exp->op == TOKerror)
        return new ErrorStatement();
    ClassDeclaration *cd = exp->type->toBasetype()->isClassHandle();
    if (!cd || ((cd != ClassDeclaration::throwable) && !ClassDeclaration::throwable->isBaseOf(cd, NULL)))
    {
        error("can only throw class objects derived from Throwable, not type %s", exp->type->toChars());
        return new ErrorStatement();
    }

    return this;
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

Statement *DebugStatement::semantic(Scope *sc)
{
    if (statement)
    {
        sc = sc->push();
        sc->flags |= SCOPEdebug;
        statement = statement->semantic(sc);
        sc->pop();
    }
    return statement;
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

Statement *GotoStatement::semantic(Scope *sc)
{
    //printf("GotoStatement::semantic()\n");
    FuncDeclaration *fd = sc->func;

    ident = fixupLabelName(sc, ident);
    label = fd->searchLabel(ident);
    tf = sc->tf;
    os = sc->os;
    lastVar = sc->lastVar;

    if (!label->statement && sc->fes)
    {
        /* Either the goto label is forward referenced or it
         * is in the function that the enclosing foreach is in.
         * Can't know yet, so wrap the goto in a scope statement
         * so we can patch it later, and add it to a 'look at this later'
         * list.
         */
        ScopeStatement *ss = new ScopeStatement(loc, this);
        sc->fes->gotos->push(ss);       // 'look at this later' list
        return ss;
    }

    // Add to fwdref list to check later
    if (!label->statement)
    {
        if (!fd->gotos)
            fd->gotos = new GotoStatements();
        fd->gotos->push(this);
    }
    else if (checkLabel())
        return new ErrorStatement();

    return this;
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
    this->lblock = NULL;
    this->fwdrefs = NULL;
}

Statement *LabelStatement::syntaxCopy()
{
    return new LabelStatement(loc, ident, statement ? statement->syntaxCopy() : NULL);
}

Statement *LabelStatement::semantic(Scope *sc)
{
    //printf("LabelStatement::semantic()\n");
    FuncDeclaration *fd = sc->parent->isFuncDeclaration();

    ident = fixupLabelName(sc, ident);
    tf = sc->tf;
    os = sc->os;
    lastVar = sc->lastVar;

    LabelDsymbol *ls = fd->searchLabel(ident);
    if (ls->statement)
    {
        error("label '%s' already defined", ls->toChars());
        return new ErrorStatement();
    }
    else
        ls->statement = this;

    sc = sc->push();
    sc->scopesym = sc->enclosing->scopesym;
    sc->callSuper |= CSXlabel;
    if (sc->fieldinit)
    {
        size_t dim = sc->fieldinit_dim;
        for (size_t i = 0; i < dim; i++)
            sc->fieldinit[i] |= CSXlabel;
    }
    sc->slabel = this;
    if (statement)
        statement = statement->semantic(sc);
    sc->pop();

    return this;
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

CompoundAsmStatement *CompoundAsmStatement::semantic(Scope *sc)
{
    for (size_t i = 0; i < statements->dim; i++)
    {
        Statement *s = (*statements)[i];
        (*statements)[i] = s ? s->semantic(sc) : NULL;
    }

    assert(sc->func);
    // use setImpure/setGC when the deprecation cycle is over
    PURE purity;
    if (!(stc & STCpure) && (purity = sc->func->isPureBypassingInference()) != PUREimpure && purity != PUREfwdref)
        deprecation("asm statement is assumed to be impure - mark it with 'pure' if it is not");
    if (!(stc & STCnogc) && sc->func->isNogcBypassingInference())
        deprecation("asm statement is assumed to use the GC - mark it with '@nogc' if it does not");
    if (!(stc & (STCtrusted|STCsafe)) && sc->func->setUnsafe())
        error("asm statement is assumed to be @system - mark it with '@trusted' if it is not");

    return this;
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

Statement *ImportStatement::semantic(Scope *sc)
{
    for (size_t i = 0; i < imports->dim; i++)
    {
        Import *s = (*imports)[i]->isImport();
        assert(!s->aliasdecls.dim);
        for (size_t j = 0; j < s->names.dim; j++)
        {
            Identifier *name = s->names[j];
            Identifier *alias = s->aliases[j];

            if (!alias)
                alias = name;

            TypeIdentifier *tname = new TypeIdentifier(s->loc, name);
            AliasDeclaration *ad = new AliasDeclaration(s->loc, alias, tname);
            ad->import = s;

            s->aliasdecls.push(ad);
        }

        s->semantic(sc);
        s->semantic2(sc);
        sc->insert(s);

        for (size_t j = 0; j < s->aliasdecls.dim; j++)
        {
            sc->insert(s->aliasdecls[j]);
        }
    }
    return this;
}
