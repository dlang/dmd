
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
        buf.writeByte(0);

        const char *name = (const char *)buf.extractData();
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
    toCBuffer(&buf, &hgs);
    buf.writebyte(0);
    return buf.extractData();
}

void Statement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("Statement::toCBuffer()");
    buf->writenl();
    assert(0);
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
    struct UsesEH
    {
        static bool lambdaUsesEH(Statement *s, void *param)
        {
            return s->usesEHimpl();
        }
    };

    UsesEH ueh;
    return apply(&UsesEH::lambdaUsesEH, &ueh);
}

bool Statement::usesEHimpl()             { return false; }
bool TryCatchStatement::usesEHimpl()     { return true; }
bool TryFinallyStatement::usesEHimpl()   { return true; }
bool OnScopeStatement::usesEHimpl()      { return true; }
bool SynchronizedStatement::usesEHimpl() { return true; }

/* ============================================== */
// true if statement 'comes from' somewhere else, like a goto

bool Statement::comeFrom()
{
    struct ComeFrom
    {
        static bool lambdaComeFrom(Statement *s, void *param)
        {
            return s->comeFromImpl();
        }
    };

    ComeFrom cf;
    return apply(&ComeFrom::lambdaComeFrom, &cf);
}

bool Statement::comeFromImpl()        { return false; }
bool CaseStatement::comeFromImpl()    { return true; }
bool DefaultStatement::comeFromImpl() { return true; }
bool LabelStatement::comeFromImpl()   { return true; }
bool AsmStatement::comeFromImpl()     { return true; }

/* ============================================== */
// Return true if statement has executable code.

bool Statement::hasCode()
{
    struct HasCode
    {
        static bool lambdaHasCode(Statement *s, void *param)
        {
            return s->hasCodeImpl();
        }
    };

    HasCode hc;
    return apply(&HasCode::lambdaHasCode, &hc);
}

bool Statement::hasCodeImpl()         { return true; }
bool ExpStatement::hasCodeImpl()      { return exp != NULL; }
bool CompoundStatement::hasCodeImpl() { return false; }
bool ScopeStatement::hasCodeImpl()    { return false; }
bool ImportStatement::hasCodeImpl()   { return false; }


/* ============================================== */

/* Only valid after semantic analysis
 * If 'mustNotThrow' is true, generate an error if it throws
 */
int Statement::blockExit(bool mustNotThrow)
{
    printf("Statement::blockExit(%p)\n", this);
    printf("%s\n", toChars());
    assert(0);
    return BEany;
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

int ErrorStatement::blockExit(bool mustNotThrow)
{
    return BEany;
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
    Expression *e = exp ? exp->syntaxCopy() : NULL;
    ExpStatement *es = new ExpStatement(loc, e);
    return es;
}

void ExpStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (exp)
    {   exp->toCBuffer(buf, hgs);
        if (exp->op != TOKdeclaration)
        {   buf->writeByte(';');
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
        exp->discardValue();
        exp = exp->optimize(0);
        if (exp->op == TOKerror)
            return new ErrorStatement();
    }
    return this;
}

int ExpStatement::blockExit(bool mustNotThrow)
{   int result = BEfallthru;

    if (exp)
    {
        if (exp->op == TOKhalt)
            return BEhalt;
        if (exp->op == TOKassert)
        {   AssertExp *a = (AssertExp *)exp;

            if (a->e1->isBool(false))   // if it's an assert(0)
                return BEhalt;
        }
#if DMD_OBJC
        result |= exp->canThrow(mustNotThrow);
#else
        if (exp->canThrow(mustNotThrow))
            result |= BEthrow;
#endif
    }
    return result;
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
    Expression *e = exp ? exp->syntaxCopy() : NULL;
    DtorExpStatement *es = new DtorExpStatement(loc, e, var);
    return es;
}

/******************************** CompileStatement ***************************/

CompileStatement::CompileStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    this->exp = exp;
}

Statement *CompileStatement::syntaxCopy()
{
    Expression *e = exp->syntaxCopy();
    CompileStatement *es = new CompileStatement(loc, e);
    return es;
}

void CompileStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("mixin(");
    exp->toCBuffer(buf, hgs);
    buf->writestring(");");
    if (!hgs->FLinit.init)
        buf->writenl();
}

Statements *CompileStatement::flatten(Scope *sc)
{
    //printf("CompileStatement::flatten() %s\n", exp->toChars());
    sc = sc->startCTFE();
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    sc = sc->endCTFE();
    exp = exp->ctfeInterpret();

    Statements *a = new Statements();
    if (exp->op != TOKerror)
    {
        StringExp *se = exp->toString();
        if (!se)
           error("argument to mixin must be a string, not (%s)", exp->toChars());
        else
        {
            se = se->toUTF8(sc);
            Parser p(loc, sc->module, (utf8_t *)se->string, se->len, 0);
            p.nextToken();

            while (p.token.value != TOKeof)
            {
                unsigned errors = global.errors;
                Statement *s = p.parseStatement(PSsemi | PScurlyscope);
                if (!s || global.errors != errors)
                    goto Lerror;
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

int CompileStatement::blockExit(bool mustNotThrow)
{
    assert(global.errors);
    return BEfallthru;
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
    {   Statement *s = (*statements)[i];
        if (s)
            s = s->syntaxCopy();
        (*a)[i] = s;
    }
    CompoundStatement *cs = new CompoundStatement(loc, a);
    return cs;
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

                        Statement *handler = sexception;
                        if (sexception->blockExit(false) & BEfallthru)
                        {   handler = new ThrowStatement(Loc(), new IdentifierExp(Loc(), id));
                            ((ThrowStatement *)handler)->internalThrow = true;
                            handler = new CompoundStatement(Loc(), sexception, handler);
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
    L1:
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
            goto L1;
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

void CompoundStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
        if (s)
            s->toCBuffer(buf, hgs);
    }
}

int CompoundStatement::blockExit(bool mustNotThrow)
{
    //printf("CompoundStatement::blockExit(%p) %d\n", this, statements->dim);
    int result = BEfallthru;
    Statement *slast = NULL;
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
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
                    if (sc && (!sc->statement->hasCode() || sc->statement->isCaseStatement()))
                        ;
                    else if (sd && (!sd->statement->hasCode() || sd->statement->isCaseStatement()))
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
                if (s->blockExit(mustNotThrow) != BEhalt && s->hasCode())
                    s->warning("statement is not reachable");
            }
            else
            {
                result &= ~BEfallthru;
                result |= s->blockExit(mustNotThrow);
            }
            slast = s;
        }
    }
    return result;
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
    {   Statement *s = (*statements)[i];
        if (s)
            s = s->syntaxCopy();
        (*a)[i] = s;
    }
    CompoundDeclarationStatement *cs = new CompoundDeclarationStatement(loc, a);
    return cs;
}

void CompoundDeclarationStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    bool anywritten = false;
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
        ExpStatement *ds;
        if (s &&
            (ds = s->isExpStatement()) != NULL &&
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
    {   Statement *s = (*statements)[i];
        if (s)
            s = s->syntaxCopy();
        (*a)[i] = s;
    }
    UnrolledLoopStatement *cs = new UnrolledLoopStatement(loc, a);
    return cs;
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

void UnrolledLoopStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("unrolled {");
    buf->writenl();
    buf->level++;

    for (size_t i = 0; i < statements->dim; i++)
    {
        Statement *s;

        s = (*statements)[i];
        if (s)
            s->toCBuffer(buf, hgs);
    }

    buf->level--;
    buf->writeByte('}');
    buf->writenl();
}

bool UnrolledLoopStatement::hasBreak()
{
    return true;
}

bool UnrolledLoopStatement::hasContinue()
{
    return true;
}

int UnrolledLoopStatement::blockExit(bool mustNotThrow)
{
    int result = BEfallthru;
    for (size_t i = 0; i < statements->dim; i++)
    {   Statement *s = (*statements)[i];
        if (s)
        {
            int r = s->blockExit(mustNotThrow);
            result |= r & ~(BEbreak | BEcontinue);
        }
    }
    return result;
}


/******************************** ScopeStatement ***************************/

ScopeStatement::ScopeStatement(Loc loc, Statement *s)
    : Statement(loc)
{
    this->statement = s;
}

Statement *ScopeStatement::syntaxCopy()
{
    Statement *s;

    s = statement ? statement->syntaxCopy() : NULL;
    s = new ScopeStatement(loc, s);
    return s;
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

int ScopeStatement::blockExit(bool mustNotThrow)
{
    //printf("ScopeStatement::blockExit(%p)\n", statement);
    return statement ? statement->blockExit(mustNotThrow) : BEfallthru;
}


void ScopeStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('{');
    buf->writenl();
    buf->level++;

    if (statement)
        statement->toCBuffer(buf, hgs);

    buf->level--;
    buf->writeByte('}');
    buf->writenl();
}

/******************************** WhileStatement ***************************/

WhileStatement::WhileStatement(Loc loc, Expression *c, Statement *b)
    : Statement(loc)
{
    condition = c;
    body = b;
}

Statement *WhileStatement::syntaxCopy()
{
    WhileStatement *s = new WhileStatement(loc, condition->syntaxCopy(), body ? body->syntaxCopy() : NULL);
    return s;
}


Statement *WhileStatement::semantic(Scope *sc)
{
    /* Rewrite as a for(;condition;) loop
     */

    Statement *s = new ForStatement(loc, NULL, condition, NULL, body);
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

int WhileStatement::blockExit(bool mustNotThrow)
{
    assert(global.errors);
    return BEfallthru;
}


void WhileStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("while (");
    condition->toCBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    if (body)
        body->toCBuffer(buf, hgs);
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
    DoStatement *s = new DoStatement(loc, body ? body->syntaxCopy() : NULL, condition->syntaxCopy());
    return s;
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

int DoStatement::blockExit(bool mustNotThrow)
{   int result;

    if (body)
    {   result = body->blockExit(mustNotThrow);
        if (result == BEbreak)
            return BEfallthru;
        if (result & BEcontinue)
            result |= BEfallthru;
    }
    else
        result = BEfallthru;
    if (result & BEfallthru)
    {
#if DMD_OBJC
        result |= condition->canThrow(mustNotThrow);
#else
        if (condition->canThrow(mustNotThrow))
            result |= BEthrow;
#endif
        if (!(result & BEbreak) && condition->isBool(true))
            result &= ~BEfallthru;
    }
    result &= ~(BEbreak | BEcontinue);
    return result;
}


void DoStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("do");
    buf->writenl();
    if (body)
        body->toCBuffer(buf, hgs);
    buf->writestring("while (");
    condition->toCBuffer(buf, hgs);
    buf->writestring(");");
    buf->writenl();
}

/******************************** ForStatement ***************************/

ForStatement::ForStatement(Loc loc, Statement *init, Expression *condition, Expression *increment, Statement *body)
    : Statement(loc)
{
    this->init = init;
    this->condition = condition;
    this->increment = increment;
    this->body = body;
    this->relatedLabeled = NULL;
}

Statement *ForStatement::syntaxCopy()
{
    Statement *i = NULL;
    if (init)
        i = init->syntaxCopy();
    Expression *c = NULL;
    if (condition)
        c = condition->syntaxCopy();
    Expression *inc = NULL;
    if (increment)
        inc = increment->syntaxCopy();
    ForStatement *s = new ForStatement(loc, i, c, inc, body->syntaxCopy());
    return s;
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
    {   condition = condition->semantic(sc);
        condition = resolveProperties(sc, condition);
        condition = condition->optimize(WANTvalue);
        condition = condition->checkToBoolean(sc);
    }
    if (increment)
    {   increment = increment->semantic(sc);
        increment = resolveProperties(sc, increment);
        increment = increment->optimize(0);
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

int ForStatement::blockExit(bool mustNotThrow)
{   int result = BEfallthru;

    if (init)
    {   result = init->blockExit(mustNotThrow);
        if (!(result & BEfallthru))
            return result;
    }
    if (condition)
    {
#if DMD_OBJC
        result |= condition->canThrow(mustNotThrow);
#else
        if (condition->canThrow(mustNotThrow))
            result |= BEthrow;
#endif
        if (condition->isBool(true))
            result &= ~BEfallthru;
        else if (condition->isBool(false))
            return result;
    }
    else
        result &= ~BEfallthru;  // the body must do the exiting
    if (body)
    {   int r = body->blockExit(mustNotThrow);
        if (r & (BEbreak | BEgoto))
            result |= BEfallthru;
        result |= r & ~(BEfallthru | BEbreak | BEcontinue);
    }
#if DMD_OBJC
    if (increment)
        result |= increment->canThrow(mustNotThrow);
#else
    if (increment && increment->canThrow(mustNotThrow))
        result |= BEthrow;
#endif
    return result;
}


void ForStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("for (");
    if (init)
    {
        hgs->FLinit.init++;
        init->toCBuffer(buf, hgs);
        hgs->FLinit.init--;
    }
    else
        buf->writebyte(';');
    if (condition)
    {   buf->writebyte(' ');
        condition->toCBuffer(buf, hgs);
    }
    buf->writebyte(';');
    if (increment)
    {   buf->writebyte(' ');
        increment->toCBuffer(buf, hgs);
    }
    buf->writebyte(')');
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    buf->level++;
    body->toCBuffer(buf, hgs);
    buf->level--;
    buf->writebyte('}');
    buf->writenl();
}

/******************************** ForeachStatement ***************************/

ForeachStatement::ForeachStatement(Loc loc, TOK op, Parameters *arguments,
        Expression *aggr, Statement *body)
    : Statement(loc)
{
    this->op = op;
    this->arguments = arguments;
    this->aggr = aggr;
    this->body = body;

    this->key = NULL;
    this->value = NULL;

    this->func = NULL;

    this->cases = NULL;
    this->gotos = NULL;
}

Statement *ForeachStatement::syntaxCopy()
{
    Parameters *args = Parameter::arraySyntaxCopy(arguments);
    Expression *exp = aggr->syntaxCopy();
    ForeachStatement *s = new ForeachStatement(loc, op, args, exp,
        body ? body->syntaxCopy() : NULL);
    return s;
}

Statement *ForeachStatement::semantic(Scope *sc)
{
    //printf("ForeachStatement::semantic() %p\n", this);
    ScopeDsymbol *sym;
    Statement *s = this;
    size_t dim = arguments->dim;
    TypeAArray *taa = NULL;
    Dsymbol *sapply = NULL;

    Type *tn = NULL;
    Type *tnv = NULL;

    func = sc->func;
    if (func->fes)
        func = func->fes->func;

    if (!inferAggregate(sc, sapply))
    {
        error("invalid foreach aggregate %s", aggr->toChars());
    Lerror:
        return new ErrorStatement();
    }

    /* Check for inference errors
     */
    if (!inferApplyArgTypes(sc, sapply))
    {
        //printf("dim = %d, arguments->dim = %d\n", dim, arguments->dim);
        error("cannot uniquely infer foreach argument types");
        goto Lerror;
    }

    Type *tab = aggr->type->toBasetype();

    if (tab->ty == Ttuple)      // don't generate new scope for tuple loops
    {
        if (dim < 1 || dim > 2)
        {
            error("only one (value) or two (key,value) arguments for tuple foreach");
            goto Lerror;
        }

        Type *argtype = (*arguments)[dim-1]->type;
        if (argtype)
        {   argtype = argtype->semantic(loc, sc);
            if (argtype->ty == Terror)
                goto Lerror;
        }

        TypeTuple *tuple = (TypeTuple *)tab;
        Statements *statements = new Statements();
        //printf("aggr: op = %d, %s\n", aggr->op, aggr->toChars());
        size_t n;
        TupleExp *te = NULL;
        if (aggr->op == TOKtuple)       // expression tuple
        {   te = (TupleExp *)aggr;
            n = te->exps->dim;
        }
        else if (aggr->op == TOKtype)   // type tuple
        {
            n = Parameter::dim(tuple->arguments);
        }
        else
            assert(0);
        for (size_t j = 0; j < n; j++)
        {   size_t k = (op == TOKforeach) ? j : n - 1 - j;
            Expression *e = NULL;
            Type *t = NULL;
            if (te)
                e = (*te->exps)[k];
            else
                t = Parameter::getNth(tuple->arguments, k)->type;
            Parameter *arg = (*arguments)[0];
            Statements *st = new Statements();

            if (dim == 2)
            {   // Declare key
                if (arg->storageClass & (STCout | STCref | STClazy))
                {   error("no storage class for key %s", arg->ident->toChars());
                    goto Lerror;
                }
                arg->type = arg->type->semantic(loc, sc);
                TY keyty = arg->type->ty;
                if (keyty != Tint32 && keyty != Tuns32)
                {
                    if (global.params.is64bit)
                    {
                        if (keyty != Tint64 && keyty != Tuns64)
                        {   error("foreach: key type must be int or uint, long or ulong, not %s", arg->type->toChars());
                            goto Lerror;
                        }
                    }
                    else
                    {   error("foreach: key type must be int or uint, not %s", arg->type->toChars());
                        goto Lerror;
                    }
                }
                Initializer *ie = new ExpInitializer(Loc(), new IntegerExp(k));
                VarDeclaration *var = new VarDeclaration(loc, arg->type, arg->ident, ie);
                var->storage_class |= STCmanifest;
                DeclarationExp *de = new DeclarationExp(loc, var);
                st->push(new ExpStatement(loc, de));
                arg = (*arguments)[1];  // value
            }
            // Declare value
            if (arg->storageClass & (STCout | STClazy) ||
                arg->storageClass & STCref && !te)
            {
                error("no storage class for value %s", arg->ident->toChars());
                goto Lerror;
            }
            Dsymbol *var;
            if (te)
            {   Type *tb = e->type->toBasetype();
                Dsymbol *ds = NULL;
                if ((tb->ty == Tfunction || tb->ty == Tsarray) && e->op == TOKvar)
                    ds = ((VarExp *)e)->var;
                else if (e->op == TOKtemplate)
                    ds =((TemplateExp *)e)->td;
                else if (e->op == TOKimport)
                    ds =((ScopeExp *)e)->sds;

                if (ds)
                {
                    var = new AliasDeclaration(loc, arg->ident, ds);
                    if (arg->storageClass & STCref)
                    {   error("symbol %s cannot be ref", s->toChars());
                        goto Lerror;
                    }
                    if (argtype)
                    {   error("cannot specify element type for symbol %s", ds->toChars());
                        goto Lerror;
                    }
                }
                else if (e->op == TOKtype)
                {
                    var = new AliasDeclaration(loc, arg->ident, e->type);
                    if (argtype)
                    {   error("cannot specify element type for type %s", e->type->toChars());
                        goto Lerror;
                    }
                }
                else
                {
                    arg->type = e->type;
                    if (argtype)
                        arg->type = argtype;
                    Initializer *ie = new ExpInitializer(Loc(), e);
                    VarDeclaration *v = new VarDeclaration(loc, arg->type, arg->ident, ie);
                    if (arg->storageClass & STCref)
                        v->storage_class |= STCref | STCforeach;
                    if (e->isConst() || e->op == TOKstring ||
                        e->op == TOKstructliteral || e->op == TOKarrayliteral)
                    {   if (v->storage_class & STCref)
                        {   error("constant value %s cannot be ref", ie->toChars());
                            goto Lerror;
                        }
                        else
                            v->storage_class |= STCmanifest;
                    }
                    var = v;
                }
            }
            else
            {
                var = new AliasDeclaration(loc, arg->ident, t);
                if (argtype)
                {   error("cannot specify element type for symbol %s", s->toChars());
                    goto Lerror;
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

Lagain:
    switch (tab->ty)
    {
        case Tarray:
        case Tsarray:
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
                Parameter *arg = (*arguments)[i];
                arg->type = arg->type->semantic(loc, sc);
                arg->type = arg->type->addStorageClass(arg->storageClass);
                tnv = arg->type->toBasetype();
                if (tnv->ty != tn->ty &&
                    (tnv->ty == Tchar || tnv->ty == Twchar || tnv->ty == Tdchar))
                {
                    if (arg->storageClass & STCref)
                    {   error("foreach: value of UTF conversion cannot be ref");
                        goto Lerror2;
                    }
                    if (dim == 2)
                    {   arg = (*arguments)[0];
                        if (arg->storageClass & STCref)
                        {   error("foreach: key cannot be ref");
                            goto Lerror2;
                        }
                    }
                    goto Lapply;
                }
            }

            for (size_t i = 0; i < dim; i++)
            {   // Declare args
                Parameter *arg = (*arguments)[i];
                arg->type = arg->type->semantic(loc, sc);
                arg->type = arg->type->addStorageClass(arg->storageClass);
                VarDeclaration *var;

                if (dim == 2 && i == 0)
                {
                    var = new VarDeclaration(loc, arg->type->mutableOf(), Lexer::uniqueId("__key"), NULL);
                    var->storage_class |= STCtemp | STCforeach;
                    if (var->storage_class & (STCref | STCout))
                        var->storage_class |= STCnodtor;

                    key = var;
                    if (arg->storageClass & STCref)
                    {
                        if (!var->type->immutableOf()->equals(arg->type->immutableOf()) ||
                            !MODimplicitConv(var->type->mod, arg->type->mod))
                        {
                            error("key type mismatch, %s to ref %s",
                                  var->type->toChars(), arg->type->toChars());
                            goto Lerror2;
                        }
                    }
                    TypeSArray *ta = tab->ty == Tsarray ? (TypeSArray *)tab : NULL;
                    if (ta && !IntRange::fromType(var->type).contains(ta->dim->getIntRange()))
                    {
                        error("index type '%s' cannot cover index range 0..%llu", arg->type->toChars(), ta->dim->toInteger());
                    }
                }
                else
                {
                    var = new VarDeclaration(loc, arg->type, arg->ident, NULL);
                    var->storage_class |= STCforeach;
                    var->storage_class |= arg->storageClass & (STCin | STCout | STCref | STC_TYPECTOR);
                    if (var->storage_class & (STCref | STCout))
                        var->storage_class |= STCnodtor;

                    value = var;
                    if (var->storage_class & STCref)
                    {
                        /* Reference to immutable data should be marked as const
                         */
                        if (aggr->checkModifiable(sc, 1) == 2)
                            var->storage_class |= STCctorinit;
                        else if (!tn->isMutable())
                            var->storage_class |= STCconst;

                        Type *t = tab->nextOf();
                        if (!t->immutableOf()->equals(arg->type->immutableOf()) ||
                            !MODimplicitConv(t->mod, arg->type->mod))
                        {
                            error("argument type mismatch, %s to ref %s",
                                  t->toChars(), arg->type->toChars());
                            goto Lerror2;
                        }
                    }
                }
#if 0
                DeclarationExp *de = new DeclarationExp(loc, var);
                de->semantic(sc);
#endif
            }

#if 1
        {
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
            VarDeclaration *tmp = new VarDeclaration(loc, tab->nextOf()->arrayOf(), id, ie);
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
                key->init = new ExpInitializer(loc, new IntegerExp(loc, 0, NULL));

            Statements *cs = new Statements();
            cs->push(new ExpStatement(loc, tmp));
            cs->push(new ExpStatement(loc, key));
            Statement *forinit = new CompoundDeclarationStatement(loc, cs);

            Expression *cond;
            if (op == TOKforeach_reverse)
                // key--
                cond = new PostExp(TOKminusminus, loc, new VarExp(loc, key));
            else
                // key < tmp.length
                cond = new CmpExp(TOKlt, loc, new VarExp(loc, key), tmp_length);

            Expression *increment = NULL;
            if (op == TOKforeach)
                // key += 1
                increment = new AddAssignExp(loc, new VarExp(loc, key), new IntegerExp(loc, 1, NULL));

            // T value = tmp[key];
            value->init = new ExpInitializer(loc, new IndexExp(loc, new VarExp(loc, tmp), new VarExp(loc, key)));
            Statement *ds = new ExpStatement(loc, value);

            if (dim == 2)
            {   Parameter *arg = (*arguments)[0];
                if ((arg->storageClass & STCref) && arg->type->equals(key->type))
                {
                    AliasDeclaration *v = new AliasDeclaration(loc, arg->ident, key);
                    body = new CompoundStatement(loc, new ExpStatement(loc, v), body);
                }
                else
                {
                    ExpInitializer *ei = new ExpInitializer(loc, new IdentifierExp(loc, key->ident));
                    VarDeclaration *v = new VarDeclaration(loc, arg->type, arg->ident, ei);
                    v->storage_class |= STCforeach | (arg->storageClass & STCref);
                    body = new CompoundStatement(loc, new ExpStatement(loc, v), body);
                }
            }
            body = new CompoundStatement(loc, ds, body);

            s = new ForStatement(loc, forinit, cond, increment, body);
            if (LabelStatement *ls = checkLabeledLoop(sc, this))
                ls->gotoTarget = s;
            s = s->semantic(sc);
            break;
        }
#else
            if (tab->nextOf()->implicitConvTo(value->type) < MATCHconst)
            {
                if (aggr->op == TOKstring)
                    aggr = aggr->implicitCastTo(sc, value->type->arrayOf());
                else
                    error("foreach: %s is not an array of %s",
                        tab->toChars(), value->type->toChars());
            }

            if (key)
            {
                if (key->type->ty != Tint32 && key->type->ty != Tuns32)
                {
                    if (global.params.is64bit)
                    {
                        if (key->type->ty != Tint64 && key->type->ty != Tuns64)
                            error("foreach: key type must be int or uint, long or ulong, not %s", key->type->toChars());
                    }
                    else
                        error("foreach: key type must be int or uint, not %s", key->type->toChars());
                }

                if (key->storage_class & (STCout | STCref))
                    error("foreach: key cannot be out or ref");
            }

            sc->sbreak = this;
            sc->scontinue = this;
            body = body->semantic(sc);
            break;
#endif

        case Taarray:
            if (!checkForArgTypes())
                return this;

            taa = (TypeAArray *)tab;
            if (dim < 1 || dim > 2)
            {
                error("only one or two arguments for associative array foreach");
                goto Lerror2;
            }

            /* This only works if Key or Value is a static array.
             */
            tab = taa->getImpl()->type;
            goto Lagain;

        case Tclass:
        case Tstruct:
            /* Prefer using opApply, if it exists
             */
            if (sapply)
                goto Lapply;

        {   /* Look for range iteration, i.e. the properties
             * .empty, .popFront, .popBack, .front and .back
             *    foreach (e; aggr) { ... }
             * translates to:
             *    for (auto __r = aggr[]; !__r.empty; __r.popFront)
             *    {   auto e = __r.front;
             *        ...
             *    }
             */
            AggregateDeclaration *ad = (tab->ty == Tclass)
                        ? (AggregateDeclaration *)((TypeClass  *)tab)->sym
                        : (AggregateDeclaration *)((TypeStruct *)tab)->sym;
            Identifier *idfront;
            Identifier *idpopFront;
            if (op == TOKforeach)
            {   idfront = Id::Ffront;
                idpopFront = Id::FpopFront;
            }
            else
            {   idfront = Id::Fback;
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
                Parameter *arg = (*arguments)[0];
                VarDeclaration *ve = new VarDeclaration(loc, arg->type, arg->ident, new ExpInitializer(loc, einit));
                ve->storage_class |= STCforeach;
                ve->storage_class |= arg->storageClass & (STCin | STCout | STCref | STC_TYPECTOR);

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

                Expression *ve = new VarExp(loc, vd);
                ve->type = sfront->isDeclaration()->type;
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
                    goto Lrangeerr;

                for (size_t i = 0; i < dim; i++)
                {
                    Parameter *arg = (*arguments)[i];
                    Expression *exp = (*exps)[i];
                #if 0
                    printf("[%d] arg = %s %s, exp = %s %s\n", i,
                            arg->type ? arg->type->toChars() : "?", arg->ident->toChars(),
                            exp->type->toChars(), exp->toChars());
                #endif
                    if (!arg->type)
                        arg->type = exp->type;
                    arg->type = arg->type->addStorageClass(arg->storageClass);
                    if (!exp->implicitConvTo(arg->type))
                        goto Lrangeerr;

                    VarDeclaration *var = new VarDeclaration(loc, arg->type, arg->ident, new ExpInitializer(loc, exp));
                    var->storage_class |= STCctfe | STCref | STCforeach;
                    DeclarationExp *de = new DeclarationExp(loc, var);
                    makeargs = new CompoundStatement(loc, makeargs, new ExpStatement(loc, de));
                }

            }

            forbody = new CompoundStatement(loc,
                makeargs, this->body);

            s = new ForStatement(loc, init, condition, increment, forbody);
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
        Lapply:
        {
            Expression *ec;
            Expression *e;

            if (!checkForArgTypes())
            {   body = body->semanticNoScope(sc);
                return this;
            }

            TypeFunction *tfld = NULL;
            if (sapply)
            {   FuncDeclaration *fdapply = sapply->isFuncDeclaration();
                if (fdapply)
                {   assert(fdapply->type && fdapply->type->ty == Tfunction);
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
                        {   Type *t = p->type->semantic(loc, sc);
                            assert(t->ty == Tdelegate);
                            tfld = (TypeFunction *)t->nextOf();
                        }
                    }
                }
            }

            /* Turn body into the function literal:
             *  int delegate(ref T arg) { body }
             */
            Parameters *args = new Parameters();
            for (size_t i = 0; i < dim; i++)
            {   Parameter *arg = (*arguments)[i];
                StorageClass stc = STCref;
                Identifier *id;

                arg->type = arg->type->semantic(loc, sc);
                arg->type = arg->type->addStorageClass(arg->storageClass);
                if (tfld)
                {   Parameter *prm = Parameter::getNth(tfld->parameters, i);
                    //printf("\tprm = %s%s\n", (prm->storageClass&STCref?"ref ":""), prm->ident->toChars());
                    stc = prm->storageClass & STCref;
                    id = arg->ident;    // argument copy is not need.
                    if ((arg->storageClass & STCref) != stc)
                    {   if (!stc)
                        {   error("foreach: cannot make %s ref", arg->ident->toChars());
                            goto Lerror2;
                        }
                        goto LcopyArg;
                    }
                }
                else if (arg->storageClass & STCref)
                {   // default delegate parameters are marked as ref, then
                    // argument copy is not need.
                    id = arg->ident;
                }
                else
                {   // Make a copy of the ref argument so it isn't
                    // a reference.
                LcopyArg:
                    id = Lexer::uniqueId("__applyArg", (int)i);

                    Initializer *ie = new ExpInitializer(Loc(), new IdentifierExp(Loc(), id));
                    VarDeclaration *v = new VarDeclaration(Loc(), arg->type, arg->ident, ie);
                    v->storage_class |= STCtemp;
                    s = new ExpStatement(Loc(), v);
                    body = new CompoundStatement(loc, s, body);
                }
                args->push(new Parameter(stc, arg->type, id, NULL));
            }
            tfld = new TypeFunction(args, Type::tint32, 0, LINKd);
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
                Parameter *arg = (*arguments)[0];
                if (dim == 2)
                {
                    if (arg->storageClass & STCref)
                    {   error("foreach: index cannot be ref");
                        goto Lerror2;
                    }
                    if (!taa->index->implicitConvTo(arg->type))
                    {   error("foreach: index must be type %s, not %s", taa->index->toChars(), arg->type->toChars());
                        goto Lerror2;
                    }
                    arg = (*arguments)[1];
                }
                if ((!arg->type->equals(taa->nextOf()) && (arg->storageClass & STCref)) ||
                    !taa->nextOf()->implicitConvTo(arg->type))
                {   error("foreach: value must be type %s, not %s", taa->nextOf()->toChars(), arg->type->toChars());
                    goto Lerror2;
                }
                /* Call:
                 *      _aaApply(aggr, keysize, flde)
                 */
                static const char *name[2] = { "_aaApply", "_aaApply2" };
                static FuncDeclaration *fdapply[2] = { NULL, NULL };
                static TypeDelegate *fldeTy[2] = { NULL, NULL };

                unsigned char i = dim == 2;
                if (!fdapply[i]) {
                    args = new Parameters;
                    args->push(new Parameter(STCin, Type::tvoid->pointerTo(), NULL, NULL));
                    args->push(new Parameter(STCin, Type::tsize_t, NULL, NULL));
                    Parameters* dgargs = new Parameters;
                    dgargs->push(new Parameter(STCin, Type::tvoidptr, NULL, NULL));
                    if (dim == 2)
                        dgargs->push(new Parameter(STCin, Type::tvoidptr, NULL, NULL));
                    fldeTy[i] = new TypeDelegate(new TypeFunction(dgargs, Type::tint32, 0, LINKd));
                    args->push(new Parameter(STCin, fldeTy[i], NULL, NULL));
                    fdapply[i] = FuncDeclaration::genCfunc(args, Type::tint32, name[i]);
                }

                ec = new VarExp(Loc(), fdapply[i]);
                Expressions *exps = new Expressions();
                exps->push(aggr);
                size_t keysize = (size_t)taa->index->size();
                keysize = (keysize + ((size_t)Target::ptrsize-1)) & ~((size_t)Target::ptrsize-1);
                // paint delegate argument to the type runtime expects
                if (!fldeTy[i]->equals(flde->type)) {
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
                args = new Parameters;
                args->push(new Parameter(STCin, tn->arrayOf(), NULL, NULL));
                Parameters* dgargs = new Parameters;
                dgargs->push(new Parameter(STCin, Type::tvoidptr, NULL, NULL));
                if (dim == 2)
                    dgargs->push(new Parameter(STCin, Type::tvoidptr, NULL, NULL));
                dgty = new TypeDelegate(new TypeFunction(dgargs, Type::tint32, 0, LINKd));
                args->push(new Parameter(STCin, dgty, NULL, NULL));
                fdapply = FuncDeclaration::genCfunc(args, Type::tint32, fdname);

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
                    // See Bugzilla 3560
                    e = new CallExp(loc, ((DelegateExp *)aggr)->e1, exps);
                else
                    e = new CallExp(loc, aggr, exps);
                e = e->semantic(sc);
                if (e->type != Type::tint32)
                {   error("opApply() function for %s must return an int", tab->toChars());
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
                if (e->type != Type::tint32)
                {   error("opApply() function for %s must return an int", tab->toChars());
                    goto Lerror2;
                }
            }

            if (!cases->dim)
                // Easy case, a clean exit from the loop
                s = new ExpStatement(loc, e);
            else
            {   // Construct a switch statement around the return value
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
{   bool result = true;

    for (size_t i = 0; i < arguments->dim; i++)
    {   Parameter *arg = (*arguments)[i];
        if (!arg->type)
        {
            error("cannot infer type for %s", arg->ident->toChars());
            arg->type = Type::terror;
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

int ForeachStatement::blockExit(bool mustNotThrow)
{   int result = BEfallthru;

#if DMD_OBJC
    result |= aggr->canThrow(mustNotThrow);
#else
    if (aggr->canThrow(mustNotThrow))
        result |= BEthrow;
#endif

    if (body)
    {
        result |= body->blockExit(mustNotThrow) & ~(BEbreak | BEcontinue);
    }
    return result;
}


void ForeachStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(Token::toChars(op));
    buf->writestring(" (");
    for (size_t i = 0; i < arguments->dim; i++)
    {
        Parameter *a = (*arguments)[i];
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
    aggr->toCBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    buf->level++;
    if (body)
        body->toCBuffer(buf, hgs);
    buf->level--;
    buf->writebyte('}');
    buf->writenl();
}

/**************************** ForeachRangeStatement ***************************/


ForeachRangeStatement::ForeachRangeStatement(Loc loc, TOK op, Parameter *arg,
        Expression *lwr, Expression *upr, Statement *body)
    : Statement(loc)
{
    this->op = op;
    this->arg = arg;
    this->lwr = lwr;
    this->upr = upr;
    this->body = body;

    this->key = NULL;
}

Statement *ForeachRangeStatement::syntaxCopy()
{
    ForeachRangeStatement *s = new ForeachRangeStatement(loc, op,
        arg->syntaxCopy(),
        lwr->syntaxCopy(),
        upr->syntaxCopy(),
        body ? body->syntaxCopy() : NULL);
    return s;
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

    if (arg->type)
    {
        arg->type = arg->type->semantic(loc, sc);
        arg->type = arg->type->addStorageClass(arg->storageClass);
        lwr = lwr->implicitCastTo(sc, arg->type);
        upr = upr->implicitCastTo(sc, arg->type);
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
            arg->type = lwr->type;
        }
        else if (lwr->type == upr->type)
        {
            /* Same logic as CondExp ?lwr:upr
             */
            arg->type = lwr->type;
        }
        else
        {
            AddExp ea(loc, lwr, upr);
            Expression *e = ea.typeCombine(sc);
            arg->type = ea.type;
            lwr = ea.e1;
            upr = ea.e2;
        }
        arg->type = arg->type->addStorageClass(arg->storageClass);
    }

    /* Convert to a for loop:
     *  foreach (key; lwr .. upr) =>
     *  for (auto key = lwr, auto tmp = upr; key < tmp; ++key)
     *
     *  foreach_reverse (key; lwr .. upr) =>
     *  for (auto tmp = lwr, auto key = upr; key-- > tmp;)
     */

    ExpInitializer *ie = new ExpInitializer(loc, (op == TOKforeach) ? lwr : upr);
    key = new VarDeclaration(loc, arg->type->mutableOf(), Lexer::uniqueId("__key"), ie);
    key->storage_class |= STCtemp;

    Identifier *id = Lexer::uniqueId("__limit");
    ie = new ExpInitializer(loc, (op == TOKforeach) ? upr : lwr);
    VarDeclaration *tmp = new VarDeclaration(loc, arg->type, id, ie);
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
        if (arg->type->isscalar())
            // key-- > tmp
            cond = new CmpExp(TOKgt, loc, cond, new VarExp(loc, tmp));
        else
            // key-- != tmp
            cond = new EqualExp(TOKnotequal, loc, cond, new VarExp(loc, tmp));
    }
    else
    {
        if (arg->type->isscalar())
            // key < tmp
            cond = new CmpExp(TOKlt, loc, new VarExp(loc, key), new VarExp(loc, tmp));
        else
            // key != tmp
            cond = new EqualExp(TOKnotequal, loc, new VarExp(loc, key), new VarExp(loc, tmp));
    }

    Expression *increment = NULL;
    if (op == TOKforeach)
        // key += 1
        //increment = new AddAssignExp(loc, new VarExp(loc, key), new IntegerExp(1));
        increment = new PreExp(TOKpreplusplus, loc, new VarExp(loc, key));

    if ((arg->storageClass & STCref) && arg->type->equals(key->type))
    {
        AliasDeclaration *v = new AliasDeclaration(loc, arg->ident, key);
        body = new CompoundStatement(loc, new ExpStatement(loc, v), body);
    }
    else
    {
        ie = new ExpInitializer(loc, new IdentifierExp(loc, key->ident));
        VarDeclaration *v = new VarDeclaration(loc, arg->type, arg->ident, ie);
        v->storage_class |= STCtemp | STCforeach | (arg->storageClass & STCref);
        body = new CompoundStatement(loc, new ExpStatement(loc, v), body);
    }
    if (arg->storageClass & STCref)
    {
        if (!key->type->immutableOf()->equals(arg->type->immutableOf()) ||
            !MODimplicitConv(key->type->mod, arg->type->mod))
        {
            error("argument type mismatch, %s to ref %s",
                  key->type->toChars(), arg->type->toChars());
        }
    }

    ForStatement *s = new ForStatement(loc, forinit, cond, increment, body);
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

int ForeachRangeStatement::blockExit(bool mustNotThrow)
{
    assert(global.errors);
    return BEfallthru;
}


void ForeachRangeStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(Token::toChars(op));
    buf->writestring(" (");

    if (arg->type)
        arg->type->toCBuffer(buf, arg->ident, hgs);
    else
        buf->writestring(arg->ident->toChars());

    buf->writestring("; ");
    lwr->toCBuffer(buf, hgs);
    buf->writestring(" .. ");
    upr->toCBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    buf->level++;
    if (body)
        body->toCBuffer(buf, hgs);
    buf->level--;
    buf->writebyte('}');
    buf->writenl();
}


/******************************** IfStatement ***************************/

IfStatement::IfStatement(Loc loc, Parameter *arg, Expression *condition, Statement *ifbody, Statement *elsebody)
    : Statement(loc)
{
    this->arg = arg;
    this->condition = condition;
    this->ifbody = ifbody;
    this->elsebody = elsebody;
    this->match = NULL;
}

Statement *IfStatement::syntaxCopy()
{
    Statement *i = NULL;
    if (ifbody)
        i = ifbody->syntaxCopy();

    Statement *e = NULL;
    if (elsebody)
        e = elsebody->syntaxCopy();

    Parameter *a = arg ? arg->syntaxCopy() : NULL;
    IfStatement *s = new IfStatement(loc, a, condition->syntaxCopy(), i, e);
    return s;
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
    if (arg)
    {   /* Declare arg, which we will set to be the
         * result of condition.
         */

        match = new VarDeclaration(loc, arg->type, arg->ident, new ExpInitializer(loc, condition));
        match->parent = sc->func;
        match->storage_class |= arg->storageClass;

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

    // Convert to boolean after declaring arg so this works:
    //  if (S arg = S()) {}
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

int IfStatement::blockExit(bool mustNotThrow)
{
    //printf("IfStatement::blockExit(%p)\n", this);

    int result = BEnone;
#if DMD_OBJC
    result |= condition->canThrow(mustNotThrow);
#else
    if (condition->canThrow(mustNotThrow))
        result |= BEthrow;
#endif
    if (condition->isBool(true))
    {
        if (ifbody)
            result |= ifbody->blockExit(mustNotThrow);
        else
            result |= BEfallthru;
    }
    else if (condition->isBool(false))
    {
        if (elsebody)
            result |= elsebody->blockExit(mustNotThrow);
        else
            result |= BEfallthru;
    }
    else
    {
        if (ifbody)
            result |= ifbody->blockExit(mustNotThrow);
        else
            result |= BEfallthru;
        if (elsebody)
            result |= elsebody->blockExit(mustNotThrow);
        else
            result |= BEfallthru;
    }
    //printf("IfStatement::blockExit(%p) = x%x\n", this, result);
    return result;
}


void IfStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("if (");
    if (arg)
    {
        if (arg->type)
            arg->type->toCBuffer(buf, arg->ident, hgs);
        else
        {
            buf->writestring("auto ");
            buf->writestring(arg->ident->toChars());
        }
        buf->writestring(" = ");
    }
    condition->toCBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    if (!ifbody->isScopeStatement())
        buf->level++;
    ifbody->toCBuffer(buf, hgs);
    if (!ifbody->isScopeStatement())
        buf->level--;
    if (elsebody)
    {
        buf->writestring("else");
        buf->writenl();
        if (!elsebody->isScopeStatement())
            buf->level++;
        elsebody->toCBuffer(buf, hgs);
        if (!elsebody->isScopeStatement())
            buf->level--;
    }
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
    Statement *e = NULL;
    if (elsebody)
        e = elsebody->syntaxCopy();
    ConditionalStatement *s = new ConditionalStatement(loc,
                condition->syntaxCopy(), ifbody->syntaxCopy(), e);
    return s;
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

int ConditionalStatement::blockExit(bool mustNotThrow)
{
    int result = ifbody->blockExit(mustNotThrow);
    if (elsebody)
        result |= elsebody->blockExit(mustNotThrow);
    return result;
}

void ConditionalStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    condition->toCBuffer(buf, hgs);
    buf->writenl();
    buf->writeByte('{');
    buf->writenl();
    buf->level++;
    if (ifbody)
        ifbody->toCBuffer(buf, hgs);
    buf->level--;
    buf->writeByte('}');
    buf->writenl();
    if (elsebody)
    {
        buf->writestring("else");
        buf->writenl();
        buf->writeByte('{');
        buf->level++;
        buf->writenl();
        elsebody->toCBuffer(buf, hgs);
        buf->level--;
        buf->writeByte('}');
        buf->writenl();
    }
    buf->writenl();
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
    Statement *b = NULL;
    if (body)
        b = body->syntaxCopy();
    PragmaStatement *s = new PragmaStatement(loc,
                ident, Expression::arraySyntaxCopy(args), b);
    return s;
}

Statement *PragmaStatement::semantic(Scope *sc)
{   // Should be merged with PragmaDeclaration
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
                StringExp *se = e->toString();
                if (se)
                {
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
#else
        if (!args || args->dim != 1)
            error("string expected for library name");
        else
        {
            Expression *e = (*args)[0];

            sc = sc->startCTFE();
            e = e->semantic(sc);
            e = resolveProperties(sc, e);
            sc = sc->endCTFE();

            e = e->ctfeInterpret();
            (*args)[0] = e;
            StringExp *se = e->toString();
            if (!se)
                error("string expected for library name, not '%s'", e->toChars());
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
                error("function name expected for start address, not '%s'", e->toChars());
            if (body)
            {
                body = body->semantic(sc);
            }
            return this;
        }
    }
    else
        error("unrecognized pragma(%s)", ident->toChars());
Lerror:
    if (body)
    {
        body = body->semantic(sc);
    }
    return body;
}

int PragmaStatement::blockExit(bool mustNotThrow)
{
    int result = BEfallthru;
#if 0 // currently, no code is generated for Pragma's, so it's just fallthru
#if DMD_OBJC
    result |= arrayExpressionCanThrow(args);
#else
    if (arrayExpressionCanThrow(args))
        result |= BEthrow;
#endif
    if (body)
        result |= body->blockExit(mustNotThrow);
#endif
    return result;
}


void PragmaStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("pragma (");
    buf->writestring(ident->toChars());
    if (args && args->dim)
    {
        buf->writestring(", ");
        argsToCBuffer(buf, args, hgs);
    }
    buf->writeByte(')');
    if (body)
    {
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;

        body->toCBuffer(buf, hgs);

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


/******************************** StaticAssertStatement ***************************/

StaticAssertStatement::StaticAssertStatement(StaticAssert *sa)
    : Statement(sa->loc)
{
    this->sa = sa;
}

Statement *StaticAssertStatement::syntaxCopy()
{
    StaticAssertStatement *s = new StaticAssertStatement((StaticAssert *)sa->syntaxCopy(NULL));
    return s;
}

Statement *StaticAssertStatement::semantic(Scope *sc)
{
    sa->semantic2(sc);
    return NULL;
}

int StaticAssertStatement::blockExit(bool mustNotThrow)
{
    return BEfallthru;
}

void StaticAssertStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    sa->toCBuffer(buf, hgs);
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
    //printf("SwitchStatement::syntaxCopy(%p)\n", this);
    SwitchStatement *s = new SwitchStatement(loc,
        condition->syntaxCopy(), body->syntaxCopy(), isFinal);
    return s;
}

Statement *SwitchStatement::semantic(Scope *sc)
{
    //printf("SwitchStatement::semantic(%p)\n", this);
    tf = sc->tf;
    if (cases)
        return this;            // already run
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
        condition = condition->integralPromotions(sc);
        if (condition->op != TOKerror && !condition->type->isintegral())
            error("'%s' must be of integral or string type, it is a %s", condition->toChars(), condition->type->toChars());
    }
    condition = condition->optimize(WANTvalue);

    sc = sc->push();
    sc->sbreak = this;
    sc->sw = this;

    cases = new CaseStatements();
    sc->noctor++;       // BUG: should use Scope::mergeCallSuper() for each case instead
    body = body->semantic(sc);
    sc->noctor--;

    // Resolve any goto case's with exp
    for (size_t i = 0; i < gotoCases.dim; i++)
    {
        GotoCaseStatement *gcs = gotoCases[i];

        if (!gcs->exp)
        {
            gcs->error("no case statement following goto case;");
            break;
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

     Lfoundcase:
        ;
    }

    bool needswitcherror = false;
    if (isFinal)
    {   Type *t = condition->type;
        while (t && t->ty == Ttypedef)
        {   // Don't use toBasetype() because that will skip past enums
            t = ((TypeTypedef *)t)->sym->basetype;
        }
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
                }
              L1:
                ;
            }
        }
        else
            needswitcherror = true;
    }

    if (!sc->sw->sdefault && (!isFinal || needswitcherror || global.params.useAssert))
    {   hasNoDefault = 1;

        if (!isFinal && !body->isErrorStatement())
           deprecation("non-final switch statement without a default is deprecated");

        // Generate runtime error if the default is hit
        Statements *a = new Statements();
        CompoundStatement *cs;
        Statement *s;

        if (global.params.useSwitchError)
            s = new SwitchErrorStatement(loc);
        else
        {   Expression *e = new HaltExp(loc);
            s = new ExpStatement(loc, e);
        }

        a->reserve(2);
        sc->sw->sdefault = new DefaultStatement(loc, s);
        a->push(body);
        if (body->blockExit(false) & BEfallthru)
            a->push(new BreakStatement(Loc(), NULL));
        a->push(sc->sw->sdefault);
        cs = new CompoundStatement(loc, a);
        body = cs;
    }

    sc->pop();
    return this;
}

bool SwitchStatement::hasBreak()
{
    return true;
}

int SwitchStatement::blockExit(bool mustNotThrow)
{   int result = BEnone;
#if DMD_OBJC
    result |= condition->canThrow(mustNotThrow);
#else
    if (condition->canThrow(mustNotThrow))
        result |= BEthrow;
#endif

    if (body)
    {   result |= body->blockExit(mustNotThrow);
        if (result & BEbreak)
        {   result |= BEfallthru;
            result &= ~BEbreak;
        }
    }
    else
        result |= BEfallthru;

    return result;
}


void SwitchStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(isFinal ? "final switch (" : "switch (");
    condition->toCBuffer(buf, hgs);
    buf->writebyte(')');
    buf->writenl();
    if (body)
    {
        if (!body->isScopeStatement())
        {
            buf->writebyte('{');
            buf->writenl();
            buf->level++;
            body->toCBuffer(buf, hgs);
            buf->level--;
            buf->writebyte('}');
            buf->writenl();
        }
        else
        {
            body->toCBuffer(buf, hgs);
        }
    }
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
    CaseStatement *s = new CaseStatement(loc, exp->syntaxCopy(), statement->syntaxCopy());
    return s;
}

Statement *CaseStatement::semantic(Scope *sc)
{
    SwitchStatement *sw = sc->sw;

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
                    error("case variables not allowed in final switch statements");
                goto L1;
            }
        }
        else
            exp = exp->ctfeInterpret();

        if (exp->op != TOKstring && exp->op != TOKint64 && exp->op != TOKerror)
        {
            error("case must be a string or an integral constant, not %s", exp->toChars());
            exp = new ErrorExp();
        }

    L1:
        for (size_t i = 0; i < sw->cases->dim; i++)
        {
            CaseStatement *cs = (*sw->cases)[i];

            //printf("comparing '%s' with '%s'\n", exp->toChars(), cs->exp->toChars());
            if (cs->exp->equals(exp))
            {   error("duplicate case %s in switch statement", exp->toChars());
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
            error("switch and case are in different finally blocks");
    }
    else
        error("case not in switch statement");
    statement = statement->semantic(sc);
    return this;
}

int CaseStatement::compare(RootObject *obj)
{
    // Sort cases so we can do an efficient lookup
    CaseStatement *cs2 = (CaseStatement *)(obj);

    return exp->compare(cs2->exp);
}

int CaseStatement::blockExit(bool mustNotThrow)
{
    return statement->blockExit(mustNotThrow);
}


void CaseStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("case ");
    exp->toCBuffer(buf, hgs);
    buf->writebyte(':');
    buf->writenl();
    statement->toCBuffer(buf, hgs);
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
    CaseRangeStatement *s = new CaseRangeStatement(loc,
        first->syntaxCopy(), last->syntaxCopy(), statement->syntaxCopy());
    return s;
}

Statement *CaseRangeStatement::semantic(Scope *sc)
{   SwitchStatement *sw = sc->sw;

    if (sw == NULL)
    {
        error("case range not in switch statement");
        return NULL;
    }

    //printf("CaseRangeStatement::semantic() %s\n", toChars());
    if (sw->isFinal)
        error("case ranges not allowed in final switch");

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

    if (first->op == TOKerror || last->op == TOKerror)
        return statement ? statement->semantic(sc) : NULL;

    uinteger_t fval = first->toInteger();
    uinteger_t lval = last->toInteger();


    if ( (first->type->isunsigned()  &&  fval > lval) ||
        (!first->type->isunsigned()  &&  (sinteger_t)fval > (sinteger_t)lval))
    {
        error("first case %s is greater than last case %s",
            first->toChars(), last->toChars());
        lval = fval;
    }

    if (lval - fval > 256)
    {   error("had %llu cases which is more than 256 cases in case range", lval - fval);
        lval = fval + 256;
    }

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

void CaseRangeStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("case ");
    first->toCBuffer(buf, hgs);
    buf->writestring(": .. case ");
    last->toCBuffer(buf, hgs);
    buf->writebyte(':');
    buf->writenl();
    statement->toCBuffer(buf, hgs);
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
    DefaultStatement *s = new DefaultStatement(loc, statement->syntaxCopy());
    return s;
}

Statement *DefaultStatement::semantic(Scope *sc)
{
    //printf("DefaultStatement::semantic()\n");
    if (sc->sw)
    {
        if (sc->sw->sdefault)
        {
            error("switch statement already has a default");
        }
        sc->sw->sdefault = this;

        if (sc->sw->tf != sc->tf)
            error("switch and default are in different finally blocks");

        if (sc->sw->isFinal)
            error("default statement not allowed in final switch statement");
    }
    else
        error("default not in switch statement");
    statement = statement->semantic(sc);
    return this;
}

int DefaultStatement::blockExit(bool mustNotThrow)
{
    return statement->blockExit(mustNotThrow);
}


void DefaultStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("default:");
    buf->writenl();
    statement->toCBuffer(buf, hgs);
}

/******************************** GotoDefaultStatement ***************************/

GotoDefaultStatement::GotoDefaultStatement(Loc loc)
    : Statement(loc)
{
    sw = NULL;
}

Statement *GotoDefaultStatement::syntaxCopy()
{
    GotoDefaultStatement *s = new GotoDefaultStatement(loc);
    return s;
}

Statement *GotoDefaultStatement::semantic(Scope *sc)
{
    sw = sc->sw;
    if (!sw)
        error("goto default not in switch statement");
    return this;
}

int GotoDefaultStatement::blockExit(bool mustNotThrow)
{
    return BEgoto;
}


void GotoDefaultStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("goto default;");
    buf->writenl();
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
    Expression *e = exp ? exp->syntaxCopy() : NULL;
    GotoCaseStatement *s = new GotoCaseStatement(loc, e);
    return s;
}

Statement *GotoCaseStatement::semantic(Scope *sc)
{
    if (exp)
        exp = exp->semantic(sc);

    if (!sc->sw)
        error("goto case not in switch statement");
    else
    {
        sc->sw->gotoCases.push(this);
        if (exp)
        {
            exp = exp->implicitCastTo(sc, sc->sw->condition->type);
            exp = exp->optimize(WANTvalue);
        }
    }
    return this;
}

int GotoCaseStatement::blockExit(bool mustNotThrow)
{
    return BEgoto;
}


void GotoCaseStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("goto case");
    if (exp)
    {   buf->writebyte(' ');
        exp->toCBuffer(buf, hgs);
    }
    buf->writebyte(';');
    buf->writenl();
}

/******************************** SwitchErrorStatement ***************************/

SwitchErrorStatement::SwitchErrorStatement(Loc loc)
    : Statement(loc)
{
}

int SwitchErrorStatement::blockExit(bool mustNotThrow)
{
    // Switch errors are non-recoverable
    return BEhalt;
}


void SwitchErrorStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("SwitchErrorStatement::toCBuffer()");
    buf->writenl();
}

/******************************** ReturnStatement ***************************/

ReturnStatement::ReturnStatement(Loc loc, Expression *exp)
    : Statement(loc)
{
    this->exp = exp;
    this->implicit0 = 0;
}

Statement *ReturnStatement::syntaxCopy()
{
    Expression *e = NULL;
    if (exp)
        e = exp->syntaxCopy();
    ReturnStatement *s = new ReturnStatement(loc, e);
    return s;
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

    Type *tret = tf->next;
    if (fd->tintro)
        /* We'll be implicitly casting the return expression to tintro
         */
        tret = fd->tintro->nextOf();
    Type *tbret = NULL;

    if (tret)
        tbret = tret->toBasetype();

    // main() returns 0, even if it returns void
    if (!exp && (!tbret || tbret->ty == Tvoid) && fd->isMain())
    {   implicit0 = 1;
        exp = new IntegerExp(0);
    }

    if ((sc->flags & SCOPEcontract) || (scx->flags & SCOPEcontract))
        error("return statements cannot be in contracts");
    if (sc->tf || scx->tf)
        error("return statements cannot be in finally, scope(exit) or scope(success) bodies");

    if (fd->isCtorDeclaration())
    {
        // Constructors implicitly do:
        //      return this;
        if (exp && exp->op != TOKthis)
            error("cannot return expression from constructor");
        exp = new ThisExp(Loc());
        exp->type = tret;
    }

    if (!exp)
        fd->nrvo_can = 0;

    if (exp)
    {
        fd->hasReturnExp |= 1;

        FuncLiteralDeclaration *fld = fd->isFuncLiteralDeclaration();
        if (tret)
            exp = exp->inferType(tbret);
        else if (fld && fld->treq)
            exp = exp->inferType(fld->treq->nextOf()->nextOf());
        exp = exp->semantic(sc);
        exp = resolveProperties(sc, exp);
        if (!exp->rvalue(true)) // don't make error for void expression
            exp = new ErrorExp();
        if (exp->op == TOKcall)
            exp = valueNoDtor(exp);

        // deduce 'auto ref'
        if (tf->isref && (fd->storage_class & STCauto))
        {
            /* Determine "refness" of function return:
             * if it's an lvalue, return by ref, else return by value
             */
            if (exp->isLvalue())
            {
                /* Return by ref
                 * (but first ensure it doesn't fail the "check for
                 * escaping reference" test)
                 */
                unsigned errors = global.startGagging();
                exp->checkEscapeRef();
                if (global.endGagging(errors))
                    tf->isref = false;  // return by value
            }
            else
                tf->isref = false;      // return by value
            fd->storage_class &= ~STCauto;
        }
        if (!tf->isref)
            exp = exp->optimize(WANTvalue);

        // handle NRVO
        if (fd->nrvo_can && exp->op == TOKvar)
        {
            VarExp *ve = (VarExp *)exp;
            VarDeclaration *v = ve->var->isVarDeclaration();

            if (tf->isref)
                // Function returns a reference
                fd->nrvo_can = 0;
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
        else
            fd->nrvo_can = 0;

        // infer return type
        if (fd->inferRetType)
        {
            Type *tfret = tf->nextOf();
            if (tfret)
            {
                if (tfret != Type::terror)
                {
                    if (!exp->type->equals(tfret))
                    {
                        int m1 = exp->type->implicitConvTo(tfret);
                        int m2 = tfret->implicitConvTo(exp->type);
                        //printf("exp->type = %s m2<-->m1 tret %s\n", exp->type->toChars(), tfret->toChars());
                        //printf("m1 = %d, m2 = %d\n", m1, m2);

                        if (m1 && m2)
                            ;
                        else if (!m1 && m2)
                            tf->next = exp->type;
                        else if (m1 && !m2)
                            ;
                        else if (exp->op != TOKerror)
                            error("mismatched function return type inference of %s and %s",
                                exp->type->toChars(), tfret->toChars());
                    }
                }

                /* The "refness" is determined by the first return statement,
                 * not all of them. This means:
                 *    return 3; return x;  // ok, x can be a value
                 *    return x; return 3;  // error, 3 is not an lvalue
                 */
            }
            else
                tf->next = exp->type;

            if (!fd->tintro)
            {
                tret = tf->next;
                tbret = tret->toBasetype();
            }
        }

        if (tbret->ty != Tvoid)
        {
            if (!exp->type->implicitConvTo(tret) &&
                fd->parametersIntersect(exp->type))
            {
                if (exp->type->immutableOf()->implicitConvTo(tret))
                    exp = exp->castTo(sc, exp->type->immutableOf());
                else if (exp->type->wildOf()->implicitConvTo(tret))
                    exp = exp->castTo(sc, exp->type->wildOf());
            }
            if (fd->tintro)
                exp = exp->implicitCastTo(sc, tf->next);

            // eorg isn't casted to tret (== fd->tintro->nextOf())
            if (fd->returnLabel)
                eorg = exp->copy();
            exp = exp->implicitCastTo(sc, tret);

            if (!tf->isref)
                exp = exp->optimize(WANTvalue);

            if (!fd->returns)
                fd->returns = new ReturnStatements();
            fd->returns->push(this);
        }
    }
    else if (fd->inferRetType)
    {
        if (tf->next)
        {
            if (tf->next->ty != Tvoid)
                error("mismatched function return type inference of void and %s",
                    tf->next->toChars());
        }
        tf->next = Type::tvoid;

        tret = Type::tvoid;
        tbret = tret;
    }
    else if (tbret->ty != Tvoid)        // if non-void return
        error("return expression expected");

    if (sc->fes)
    {
        Statement *s;

        if (exp && !implicit0)
        {
            exp = exp->implicitCastTo(sc, tret);
        }
        if (!exp || exp->op == TOKint64 || exp->op == TOKfloat64 ||
            exp->op == TOKimaginary80 || exp->op == TOKcomplex80 ||
            exp->op == TOKthis || exp->op == TOKsuper || exp->op == TOKnull ||
            exp->op == TOKstring)
        {
            sc->fes->cases->push(this);
            // Construct: return cases->dim+1;
            s = new ReturnStatement(Loc(), new IntegerExp(sc->fes->cases->dim + 1));
        }
        else if (tf->next->toBasetype() == Type::tvoid)
        {
            s = new ReturnStatement(Loc(), NULL);
            sc->fes->cases->push(s);

            // Construct: { exp; return cases->dim + 1; }
            Statement *s1 = new ExpStatement(loc, exp);
            Statement *s2 = new ReturnStatement(Loc(), new IntegerExp(sc->fes->cases->dim + 1));
            s = new CompoundStatement(loc, s1, s2);
        }
        else
        {
            // Construct: return vresult;
            if (!fd->vresult)
            {
                // Declare vresult
                Scope *sco = fd->scout ? fd->scout : scx;
                if (!fd->outId)
                    fd->outId = Id::result;
                VarDeclaration *v = new VarDeclaration(loc, tret, fd->outId, NULL);
                if (fd->outId == Id::result)
                    v->storage_class |= STCtemp;
                v->noscope = 1;
                v->storage_class |= STCresult;
                if (tf->isref)
                    v->storage_class |= STCref | STCforeach;
                v->semantic(sco);
                if (!sco->insert(v))
                    assert(0);
                v->parent = fd;
                fd->vresult = v;
            }

            s = new ReturnStatement(Loc(), new VarExp(Loc(), fd->vresult));
            sc->fes->cases->push(s);

            // Construct: { vresult = exp; return cases->dim + 1; }
            exp = new ConstructExp(loc, new VarExp(Loc(), fd->vresult), exp);
            exp = exp->semantic(sc);
            Statement *s1 = new ExpStatement(loc, exp);
            Statement *s2 = new ReturnStatement(Loc(), new IntegerExp(sc->fes->cases->dim + 1));
            s = new CompoundStatement(loc, s1, s2);
        }
        return s;
    }

    if (exp)
    {
        if (tf->isref && !fd->isCtorDeclaration())
        {
            // Function returns a reference
            exp = exp->toLvalue(sc, exp);
            exp->checkEscapeRef();
        }
        else
        {
            //exp->dump(0);
            //exp->print();
            exp->checkEscape();
        }

        if (fd->returnLabel && tbret->ty != Tvoid)
        {
            fd->buildResultVar();
            VarExp *v = new VarExp(Loc(), fd->vresult);

            assert(eorg);
            exp = new ConstructExp(loc, v, eorg);
            exp = exp->semantic(sc);
        }
    }

    // If any branches have called a ctor, but this branch hasn't, it's an error
    if (sc->callSuper & CSXany_ctor &&
        !(sc->callSuper & (CSXthis_ctor | CSXsuper_ctor)))
        error("return without calling constructor");
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
                error("an earlier return statement skips field %s initialization", v->toChars());

            sc->fieldinit[i] |= CSXreturn;
        }
    }

    // See if all returns are instead to be replaced with a goto returnLabel;
    if (fd->returnLabel)
    {
        GotoStatement *gs = new GotoStatement(loc, Id::returnLabel);

        gs->label = fd->returnLabel;
        if (exp)
        {   /* Replace: return exp;
             * with:    exp; goto returnLabel;
             */
            Statement *s = new ExpStatement(Loc(), exp);
            return new CompoundStatement(loc, s, gs);
        }
        return gs;
    }

    if (exp && tbret->ty == Tvoid && !implicit0)
    {
        if (exp->type->ty != Tvoid)
        {
            error("cannot return non-void from void function");
        }

        /* Replace:
         *      return exp;
         * with:
         *      cast(void)exp; return;
         */
        Expression *ce = new CastExp(loc, exp, Type::tvoid);
        Statement *s = new ExpStatement(loc, ce);
        s = s->semantic(sc);

        exp = NULL;
        return new CompoundStatement(loc, s, this);
    }

    return this;
}

int ReturnStatement::blockExit(bool mustNotThrow)
{   int result = BEreturn;

#if DMD_OBJC
    if (exp)
        result |= exp->canThrow(mustNotThrow);
#else
    if (exp && exp->canThrow(mustNotThrow))
        result |= BEthrow;
#endif
    return result;
}


void ReturnStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("return ");
    if (exp)
        exp->toCBuffer(buf, hgs);
    buf->writeByte(';');
    buf->writenl();
}

/******************************** BreakStatement ***************************/

BreakStatement::BreakStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
}

Statement *BreakStatement::syntaxCopy()
{
    BreakStatement *s = new BreakStatement(loc, ident);
    return s;
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

                if (!s->hasBreak())
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
        if (sc->fes)
        {
            // Replace break; with return 1;
            Statement *s = new ReturnStatement(Loc(), new IntegerExp(1));
            return s;
        }
        error("break is not inside a loop or switch");
        return new ErrorStatement();
    }
    return this;
}

int BreakStatement::blockExit(bool mustNotThrow)
{
    //printf("BreakStatement::blockExit(%p) = x%x\n", this, ident ? BEgoto : BEbreak);
    return ident ? BEgoto : BEbreak;
}


void BreakStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("break");
    if (ident)
    {   buf->writebyte(' ');
        buf->writestring(ident->toChars());
    }
    buf->writebyte(';');
    buf->writenl();
}

/******************************** ContinueStatement ***************************/

ContinueStatement::ContinueStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
}

Statement *ContinueStatement::syntaxCopy()
{
    ContinueStatement *s = new ContinueStatement(loc, ident);
    return s;
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

                if (!s->hasContinue())
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
        if (sc->fes)
        {
            // Replace continue; with return 0;
            Statement *s = new ReturnStatement(Loc(), new IntegerExp(0));
            return s;
        }
        error("continue is not inside a loop");
    }
    return this;
}

int ContinueStatement::blockExit(bool mustNotThrow)
{
    return ident ? BEgoto : BEcontinue;
}


void ContinueStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("continue");
    if (ident)
    {   buf->writebyte(' ');
        buf->writestring(ident->toChars());
    }
    buf->writebyte(';');
    buf->writenl();
}

/******************************** SynchronizedStatement ***************************/

SynchronizedStatement::SynchronizedStatement(Loc loc, Expression *exp, Statement *body)
    : Statement(loc)
{
    this->exp = exp;
    this->body = body;
    this->esync = NULL;
}

SynchronizedStatement::SynchronizedStatement(Loc loc, elem *esync, Statement *body)
    : Statement(loc)
{
    this->exp = NULL;
    this->body = body;
    this->esync = esync;
}

Statement *SynchronizedStatement::syntaxCopy()
{
    Expression *e = exp ? exp->syntaxCopy() : NULL;
    SynchronizedStatement *s = new SynchronizedStatement(loc, e, body ? body->syntaxCopy() : NULL);
    return s;
}

Statement *SynchronizedStatement::semantic(Scope *sc)
{
    if (exp)
    {
        exp = exp->semantic(sc);
        exp = resolveProperties(sc, exp);
        if (exp->op == TOKerror)
            goto Lbody;
        ClassDeclaration *cd = exp->type->isClassHandle();
        if (!cd)
        {
            error("can only synchronize on class objects, not '%s'", exp->type->toChars());
            return new ErrorStatement();
        }
#if DMD_OBJC
        else if (cd->objc)
        { /* interface declaration not a special case in Objective-C */ }
#endif
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
        args->push(new Parameter(STCin, ClassDeclaration::object->type, NULL, NULL));

        FuncDeclaration *fdenter = FuncDeclaration::genCfunc(args, Type::tvoid, Id::monitorenter);
#if DMD_OBJC
        if (cd && cd->objc) // replace with Objective-C's equivalent function
            fdenter = FuncDeclaration::genCfunc(args, Type::tvoid, Id::objc_sync_enter);
#endif
        Expression *e = new CallExp(loc, new VarExp(loc, fdenter), new VarExp(loc, tmp));
        e->type = Type::tvoid;                  // do not run semantic on e
        cs->push(new ExpStatement(loc, e));

        FuncDeclaration *fdexit = FuncDeclaration::genCfunc(args, Type::tvoid, Id::monitorexit);
#if DMD_OBJC
        if (cd && cd->objc) // replace with Objective-C's equivalent function
            fdexit = FuncDeclaration::genCfunc(args, Type::tvoid, Id::objc_sync_exit);
#endif
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
        args->push(new Parameter(STCin, t->pointerTo(), NULL, NULL));

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

int SynchronizedStatement::blockExit(bool mustNotThrow)
{
    return body ? body->blockExit(mustNotThrow) : BEfallthru;
}


void SynchronizedStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("synchronized");
    if (exp)
    {   buf->writebyte('(');
        exp->toCBuffer(buf, hgs);
        buf->writebyte(')');
    }
    if (body)
    {
        buf->writebyte(' ');
        body->toCBuffer(buf, hgs);
    }
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
    WithStatement *s = new WithStatement(loc, exp->syntaxCopy(), body ? body->syntaxCopy() : NULL);
    return s;
}

Statement *WithStatement::semantic(Scope *sc)
{   ScopeDsymbol *sym;
    Initializer *init;

    //printf("WithStatement::semantic()\n");
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
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
        Type *t = exp->type;
        t = t->toBasetype();

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
                init = new ExpInitializer(loc, exp);
                wthis = new VarDeclaration(loc, exp->type, Lexer::uniqueId("__withtmp"), init);
                wthis->storage_class |= STCtemp;
                exp = new CommaExp(loc, new DeclarationExp(loc, wthis), new VarExp(loc, wthis));
                exp = exp->semantic(sc);
            }
            Expression *e = exp->addressOf(sc);
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
        sc = sc->push(sym);
        sc->insert(sym);
        body = body->semantic(sc);
        sc->pop();
        if (body && body->isErrorStatement())
            return body;
    }

    return this;
}

void WithStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("with (");
    exp->toCBuffer(buf, hgs);
    buf->writestring(")");
    buf->writenl();
    if (body)
        body->toCBuffer(buf, hgs);
}

int WithStatement::blockExit(bool mustNotThrow)
{
    int result = BEnone;
#if DMD_OBJC
    result |= exp->canThrow(mustNotThrow);
#else
    if (exp->canThrow(mustNotThrow))
        result = BEthrow;
#endif
    if (body)
        result |= body->blockExit(mustNotThrow);
    else
        result |= BEfallthru;
    return result;
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
        c = c->syntaxCopy();
        (*a)[i] = c;
    }
    TryCatchStatement *s = new TryCatchStatement(loc, body->syntaxCopy(), a);
    return s;
}

Statement *TryCatchStatement::semantic(Scope *sc)
{
    body = body->semanticScope(sc, NULL /*this*/, NULL);
    assert(body);

    /* Even if body is empty, still do semantic analysis on catches
     */
    bool catchErrors = false;
#if DMD_OBJC
    Catches *newCatches = NULL;
    Catches *objcCatches = NULL;
#endif
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

#if DMD_OBJC
        // check if catching Objective-C exception, if so rewrite as one catch
        // for all wrapped Objective-C exceptions and check Objective-C type
        // in code.
        ClassDeclaration *cd = c->type->toBasetype()->isClassHandle();
        if (cd && cd->objc)
        {
            if (newCatches == NULL)
            {   // create new catches array, fill up to were we are, don't add this one
                objcCatches = new Catches;
                newCatches = new Catches;
                newCatches->push(NULL); // reserve first catch for later
                for (size_t j = 0; j < i; ++j)
                    newCatches->push(catches->tdata()[j]);
            }
            c->handler = new PeelStatement(c->handler);
            objcCatches->push(c);
        }
        else if (newCatches)
            newCatches->push(c);
#endif
    }

#if DMD_OBJC
    if (newCatches)
    {
        assert(objcCatches);
        assert(objcCatches->dim > 0);
        Catch *objcCatch = objcMakeCatch(loc, objcCatches, sc);
        objcCatch->semantic(sc);

        // set previously reserved first catch for handling Objective-C wrapper
        newCatches->tdata()[0] = objcCatch;
        catches = newCatches;

        // Make sure all Objective-C exceptions from body are rethrown in D
        if (body->blockExit(false) & BEthrowobjc)
        {
            body = new PeelStatement(body);
            body = new ObjcExceptionBridge(loc, body, THROWd);
            body = body->semantic(sc);
        }
    }
#endif
    if (catchErrors)
        return new ErrorStatement();

    if (body->isErrorStatement())
        return body;

    /* If the try body never throws, we can eliminate any catches
     * of recoverable exceptions.
     */

    if (!(body->blockExit(false) & BEthrow) && ClassDeclaration::exception)
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

int TryCatchStatement::blockExit(bool mustNotThrow)
{
    assert(body);
    int result = body->blockExit(false);

    int catchresult = 0;
    for (size_t i = 0; i < catches->dim; i++)
    {
        Catch *c = (*catches)[i];
        if (c->type == Type::terror)
            continue;

        catchresult |= c->blockExit(mustNotThrow);

        /* If we're catching Object, then there is no throwing
         */
        Identifier *id = c->type->toBasetype()->isClassHandle()->ident;
        if (id == Id::Object || id == Id::Throwable)
        {
            result &= ~(BEthrow | BEerrthrow);
        }
        if (id == Id::Exception)
        {
            result &= ~BEthrow;
        }
    }
#if DMD_OBJC
    if (mustNotThrow && (result & BEthrowany))
#else
    if (mustNotThrow && (result & BEthrow))
#endif
    {
        body->blockExit(mustNotThrow); // now explain why this is nothrow
    }
    return result | catchresult;
}


void TryCatchStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("try");
    buf->writenl();
    if (body)
        body->toCBuffer(buf, hgs);
    for (size_t i = 0; i < catches->dim; i++)
    {
        Catch *c = (*catches)[i];
        c->toCBuffer(buf, hgs);
    }
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
        (type ? type->syntaxCopy() : NULL),
        ident,
        (handler ? handler->syntaxCopy() : NULL));
    c->internalCatch = internalCatch;
    return c;
}

void Catch::semantic(Scope *sc)
{
    //printf("Catch::semantic(%s)\n", ident->toChars());

#ifndef IN_GCC
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
        type = new TypeIdentifier(Loc(), Id::Throwable);
    type = type->semantic(loc, sc);
    ClassDeclaration *cd = type->toBasetype()->isClassHandle();
#if DMD_OBJC
    if (cd && cd->objc) // allow catching of Objective-C exceptions
    {}
    else
#endif
    if (!cd || ((cd != ClassDeclaration::throwable) && !ClassDeclaration::throwable->isBaseOf(cd, NULL)))
    {
        if (type != Type::terror)
        {   error(loc, "can only catch class objects derived from Throwable, not '%s'", type->toChars());
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

int Catch::blockExit(bool mustNotThrow)
{
    return handler ? handler->blockExit(mustNotThrow) : BEfallthru;
}

void Catch::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("catch");
    if (type)
    {   buf->writebyte('(');
        type->toCBuffer(buf, ident, hgs);
        buf->writebyte(')');
    }
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    buf->level++;
    if (handler)
        handler->toCBuffer(buf, hgs);
    buf->level--;
    buf->writebyte('}');
    buf->writenl();
}

/****************************** TryFinallyStatement ***************************/

TryFinallyStatement::TryFinallyStatement(Loc loc, Statement *body, Statement *finalbody)
    : Statement(loc)
{
    this->body = body;
    this->finalbody = finalbody;
#if DMD_OBJC
    this->objcdisable = 0;
#endif
}

TryFinallyStatement *TryFinallyStatement::create(Loc loc, Statement *body, Statement *finalbody)
{
    return new TryFinallyStatement(loc, body, finalbody);
}

Statement *TryFinallyStatement::syntaxCopy()
{
    TryFinallyStatement *s = new TryFinallyStatement(loc,
        body->syntaxCopy(), finalbody->syntaxCopy());
    return s;
}

Statement *TryFinallyStatement::semantic(Scope *sc)
{
    //printf("TryFinallyStatement::semantic()\n");
    body = body->semantic(sc);
#if DMD_OBJC
    // Make sure all Objective-C exceptions from body are rethrown in D
    if (!objcdisable && body && (body->blockExit(false) & BEthrowobjc))
    {
        body = new PeelStatement(body);
        body = new ObjcExceptionBridge(loc, body, THROWd);
        body = body->semantic(sc);
    }
#endif
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
    if (body->blockExit(false) == BEfallthru)
    {   Statement *s = new CompoundStatement(loc, body, finalbody);
        return s;
    }
    return this;
}

void TryFinallyStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("try");
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    buf->level++;
    body->toCBuffer(buf, hgs);
    buf->level--;
    buf->writebyte('}');
    buf->writenl();
    buf->writestring("finally");
    buf->writenl();
    buf->writebyte('{');
    buf->writenl();
    buf->level++;
    finalbody->toCBuffer(buf, hgs);
    buf->level--;
    buf->writeByte('}');
    buf->writenl();
}

bool TryFinallyStatement::hasBreak()
{
    return false; //true;
}

bool TryFinallyStatement::hasContinue()
{
    return false; //true;
}

int TryFinallyStatement::blockExit(bool mustNotThrow)
{
    int result = BEfallthru;
    if (body)
        result = body->blockExit(mustNotThrow);
    // check finally body as well, it may throw (bug #4082)
    if (finalbody)
    {
        int finalresult = finalbody->blockExit(mustNotThrow);
        if (!(finalresult & BEfallthru))
            result &= ~BEfallthru;
        result |= finalresult & ~BEfallthru;
    }
    return result;
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
    OnScopeStatement *s = new OnScopeStatement(loc,
        tok, statement->syntaxCopy());
    return s;
}

Statement *OnScopeStatement::semantic(Scope *sc)
{
    /* semantic is called on results of scopeCode() */
    return this;
}

int OnScopeStatement::blockExit(bool mustNotThrow)
{   // At this point, this statement is just an empty placeholder
    return BEfallthru;
}

void OnScopeStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(Token::toChars(tok));
    buf->writebyte(' ');
    statement->toCBuffer(buf, hgs);
}

Statement *OnScopeStatement::scopeCode(Scope *sc, Statement **sentry, Statement **sexception, Statement **sfinally)
{
    //printf("OnScopeStatement::scopeCode()\n");
    //print();
    *sentry = NULL;
    *sexception = NULL;
    *sfinally = NULL;
    switch (tok)
    {
        case TOKon_scope_exit:
            *sfinally = statement;
            break;

        case TOKon_scope_failure:
            *sexception = statement;
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
            *sfinally = new IfStatement(Loc(), NULL, e, statement, NULL);

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
    if (exp->op == TOKerror)
        return new ErrorStatement();
    ClassDeclaration *cd = exp->type->toBasetype()->isClassHandle();
#if DMD_OBJC
    if (cd && cd->objc) // allow throwing of Objective-C exceptions
    {   // FIXME: must derive from NSException
    }
    else
#endif
    if (!cd || ((cd != ClassDeclaration::throwable) && !ClassDeclaration::throwable->isBaseOf(cd, NULL)))
    {
        error("can only throw class objects derived from Throwable, not type %s", exp->type->toChars());
        return new ErrorStatement();
    }

    return this;
}

int ThrowStatement::blockExit(bool mustNotThrow)
{
    Type *t = exp->type->toBasetype();
    ClassDeclaration *cd = t->isClassHandle();
    assert(cd);

    if (cd == ClassDeclaration::errorException ||
        ClassDeclaration::errorException->isBaseOf(cd, NULL))
    {
        return BEerrthrow;
    }
    // Bugzilla 8675
    // Throwing Errors is allowed even if mustNotThrow
    if (!internalThrow && mustNotThrow)
        error("%s is thrown but not caught", exp->type->toChars());

    return BEthrow;
}


void ThrowStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("throw ");
    exp->toCBuffer(buf, hgs);
    buf->writeByte(';');
    buf->writenl();
}

/******************************** DebugStatement **************************/

DebugStatement::DebugStatement(Loc loc, Statement *statement)
    : Statement(loc)
{
    this->statement = statement;
}

Statement *DebugStatement::syntaxCopy()
{
    DebugStatement *s = new DebugStatement(loc,
                statement ? statement->syntaxCopy() : NULL);
    return s;
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

void DebugStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (statement)
    {
        statement->toCBuffer(buf, hgs);
    }
}


/******************************** GotoStatement ***************************/

GotoStatement::GotoStatement(Loc loc, Identifier *ident)
    : Statement(loc)
{
    this->ident = ident;
    this->label = NULL;
    this->tf = NULL;
    this->lastVar = NULL;
    this->fd = NULL;
}

Statement *GotoStatement::syntaxCopy()
{
    GotoStatement *s = new GotoStatement(loc, ident);
    return s;
}

Statement *GotoStatement::semantic(Scope *sc)
{
    FuncDeclaration *fd = sc->func;
    //printf("GotoStatement::semantic()\n");
    ident = fixupLabelName(sc, ident);

    this->lastVar = sc->lastVar;
    this->fd = sc->func;
    tf = sc->tf;
    label = fd->searchLabel(ident);
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

int GotoStatement::blockExit(bool mustNotThrow)
{
    //printf("GotoStatement::blockExit(%p)\n", this);
    return BEgoto;
}


void GotoStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("goto ");
    buf->writestring(ident->toChars());
    buf->writebyte(';');
    buf->writenl();
}

/******************************** LabelStatement ***************************/

LabelStatement::LabelStatement(Loc loc, Identifier *ident, Statement *statement)
    : Statement(loc)
{
    this->ident = ident;
    this->statement = statement;
    this->tf = NULL;
    this->gotoTarget = NULL;
    this->lastVar = NULL;
    this->lblock = NULL;
    this->fwdrefs = NULL;
}

Statement *LabelStatement::syntaxCopy()
{
    LabelStatement *s = new LabelStatement(loc, ident, statement->syntaxCopy());
    return s;
}

Statement *LabelStatement::semantic(Scope *sc)
{
    FuncDeclaration *fd = sc->parent->isFuncDeclaration();

    this->lastVar = sc->lastVar;
    //printf("LabelStatement::semantic()\n");
    ident = fixupLabelName(sc, ident);

    LabelDsymbol *ls = fd->searchLabel(ident);
    if (ls->statement)
    {
        error("Label '%s' already defined", ls->toChars());
        return new ErrorStatement();
    }
    else
        ls->statement = this;
    tf = sc->tf;
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
        statement = statement->semanticNoScope(sc);
    sc->pop();
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


int LabelStatement::blockExit(bool mustNotThrow)
{
    //printf("LabelStatement::blockExit(%p)\n", this);
    return statement ? statement->blockExit(mustNotThrow) : BEfallthru;
}


void LabelStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    buf->writebyte(':');
    buf->writenl();
    if (statement)
        statement->toCBuffer(buf, hgs);
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


int AsmStatement::blockExit(bool mustNotThrow)
{
    if (mustNotThrow)
        error("asm statements are assumed to throw", toChars());
    // Assume the worst
    return BEfallthru | BEthrow | BEreturn | BEgoto | BEhalt;
}

void AsmStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("asm { ");
    Token *t = tokens;
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
            buf->writebyte(' ');
        }
        t = t->next;
    }
    buf->level--;
    buf->writestring("; }");
    buf->writenl();
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

int ImportStatement::blockExit(bool mustNotThrow)
{
    return BEfallthru;
}

void ImportStatement::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    for (size_t i = 0; i < imports->dim; i++)
    {
        Dsymbol *s = (*imports)[i];
        s->toCBuffer(buf, hgs);
    }
}

#if DMD_OBJC

// Special catch for handling wrapped Objective-C exceptions: unwrap them
// and pass to matching handler, or rethrow.

Catch *objcMakeCatch(Loc loc, Catches *objccatches, Scope *sc)
{
    assert(objccatches->dim);

    // Construct a handler with a switch statement for various possible
    // Objective-C matches
    //
    // catch (... __ex) {
    //    void*[__count] __objc_ex_cls_ref = [A.class, B.class];
    //    void* __objc_ex = _dobjc_exception_extract(cast(void*)__ex);
    //    switch (_dobjc_exception_select(__objc_ex, __objc_ex_cls_ref))
    //    {
    //        case 0: A e = cast(A)__objc_ex; ..handler..; break;
    //        case 1: B e = cast(B)__objc_ex; ..handler..; break;
    //        default: throw __ex;
    //    }
    // }

    Statements *h = new Statements();

    // void*[__count] __objc_ex_cls_ref = [A.class, B.class];
    Expressions *clsrefs = new Expressions();
    Expressions *creflist = new Expressions();
    for (size_t i = 0; i < objccatches->dim; i++)
    {
        Catch *c = objccatches->tdata()[i];
        assert(c->type->ty == Tclass);
        creflist->push(new CastExp(0, new ObjcClassRefExp(0, ((TypeClass *)c->type)->sym), Type::tvoidptr));
    }
    VarDeclaration *varobjcexclsref = new VarDeclaration(loc, new TypeSArray(Type::tvoidptr, new IntegerExp(objccatches->dim)), Lexer::uniqueId("__objc_ex_cls_ref"), new ExpInitializer(loc, new ArrayLiteralExp(loc, creflist)));
    varobjcexclsref->parent = sc->parent;
    sc->insert(varobjcexclsref);
    Statement *objcexclsref = new ExpStatement(loc, new DeclarationExp(loc, varobjcexclsref));
    h->push(objcexclsref);

    // void* __objc_ex = _dobjc_exception_extract(cast(void*)__ex);
    Identifier *idex = Lexer::uniqueId("__ex");
    FuncDeclaration *eextractfun = FuncDeclaration::genCfunc(Type::tvoidptr, "_dobjc_exception_extract", Type::tvoidptr);
    Expression *eextract = new CallExp(0, new VarExp(0, eextractfun), new CastExp(0, new IdentifierExp(0, idex), Type::tvoidptr));
    VarDeclaration *varobjcex = new VarDeclaration(loc, Type::tvoidptr, Lexer::uniqueId("__objc_ex"), new ExpInitializer(loc, eextract));
    varobjcex->parent = sc->parent;
    sc->insert(varobjcex);
    Statement *objcex = new ExpStatement(loc, new DeclarationExp(loc, varobjcex));
    h->push(objcex);

    // (_dobjc_exception_select(__objc_ex, __objc_ex_cls_ref))
    Parameters *selectparams = new Parameters();
    selectparams->push(new Parameter(STCin, Type::tvoidptr, NULL, NULL));
    selectparams->push(new Parameter(STCin, new TypeDArray(Type::tvoidptr), NULL, NULL));
    FuncDeclaration *fselect = FuncDeclaration::genCfunc(selectparams, Type::tsize_t, "_dobjc_exception_select");
    Expression *argobjcex = new VarExp(Loc(), varobjcex);
    Expression *argcrefarray = new VarExp(Loc(), varobjcexclsref);
    Expression *eselect = new CallExp(Loc(), new VarExp(Loc(), fselect), argobjcex, argcrefarray);

    // switch's body
    Statements *a = new Statements();

    // default: throw cast(Throwable)cast(void*)__e;
    {
        Statement *s = new ThrowStatement(0, new CastExp(0, new CastExp(0, new IdentifierExp(0, idex), Type::tvoidptr), ClassDeclaration::throwable->type));
        a->push(new DefaultStatement(0, s));
    }

    // cases 0...
    for (size_t i = 0; i < objccatches->dim; i++)
    {
        Catch *c = objccatches->tdata()[i];

        // create handler for this case
        ExpInitializer *iinex = new ExpInitializer(loc, new CastExp(0, new VarExp(0, varobjcex), c->type));
        VarDeclaration *varinex = new VarDeclaration(loc, c->type, c->ident, iinex);
        varinex->parent = sc->parent;
        sc->insert(varinex);
        Statement *s = new ExpStatement(loc, new DeclarationExp(loc, varinex));
        s = new CompoundStatement(0, s, c->handler);
        s = new CompoundStatement(0, s, new BreakStatement(0, NULL));
        s = new CaseStatement(0, new IntegerExp(i), s);
        a->push(s);
    }

    Statement *sw = new SwitchStatement(loc, eselect, new CompoundStatement(loc, a), false);
    h->push(sw);
    Statement *handler = new CompoundStatement(loc, h);

    Type *catchType = NULL;
    if (ClassDeclaration::objcthrowable == NULL)
        error(loc, "Missing ObjcThrowable declaration in object.d");
    else
        catchType = ClassDeclaration::objcthrowable->type;
    return new Catch(loc, catchType, idex, handler);
}

/************************ ObjcExceptionBridge *******************************/
// Either convert D exceptions to Objective-C ones, or the reverse depending
// on throw mode.

ObjcExceptionBridge::ObjcExceptionBridge(Loc loc, Statement *body, ObjcThrowMode mode)
    : Statement(loc)
{
    this->body = body;
    this->mode = mode;
}

Statement *ObjcExceptionBridge::syntaxCopy()
{
    return new ObjcExceptionBridge(loc, body->syntaxCopy(), mode);
}

int ObjcExceptionBridge::blockExit(bool mustNotThrow)
{
    int result = body->blockExit(mustNotThrow);
    if (mode == THROWobjc)
    {   if (result & BEthrow)
        {
            result &= ~BEthrow;
            result |= BEthrowobjc;
        }
    }
    else if (mode == THROWd)
    {   if (result & BEthrowobjc)
        {
            result &= ~BEthrowobjc;
            result |= BEthrow;
        }
    }
    return result;
}

void ObjcExceptionBridge::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    // this is a transparent expression
    return body->toCBuffer(buf, hgs);
}

Statement *ObjcExceptionBridge::semantic(Scope *sc)
{
    if (wrapped)
        return this; // already done

    body = body->semantic(sc);

    if (mode == THROWobjc)
    {
        // Rewrite as this:
        //
        // try
        //    body;
        // catch (... __ex)
        // {
        //    _dobjc_throwAs_objc(__ex);
        //    halt;
        // }

        Identifier *idex = Lexer::uniqueId("__ex");
        FuncDeclaration *fhandler = FuncDeclaration::genCfunc(Type::tvoid, "_dobjc_throwAs_objc", Type::tvoidptr);
        Statement *handler = new ExpStatement(loc, new CallExp(loc, new VarExp(0, fhandler), new CastExp(loc, new IdentifierExp(loc, idex), Type::tvoidptr)));
        handler = new CompoundStatement(loc, handler, new ExpStatement(loc, new HaltExp(loc)));

        Catch *c = new Catch(loc, NULL, idex, handler);
        Catches *catches = new Catches();
        catches->push(c);

        wrapped = new TryCatchStatement(loc, new PeelStatement(body), catches);
        wrapped->semantic(sc);
        return this;
    }
    else if (mode == THROWd)
    {
        // Rewrite as this (Apple Objective-C Legacy Runtime ABI):
        //
        // size_t[__edatalen] __dobjc_ex_data;
        // objc_exception_try_enter(__dobjc_ex_data.ptr);
        // if (!_setjmp(__dobjc_ex_data.ptr)) {
        //    try // D-ABI only
        //        body
        //    finally
        //        objc_exception_try_exit(__dobjc_ex_data.ptr);
        // } else {
        //    _dobjc_throwAs_d(objc_exception_extract(__dobjc_ex_data.ptr));
        //    halt;
        // }

        Statements *a = new Statements();

        // determine platform-specific setjmp data size
        int jblen;
        if (!global.params.is64bit)
            jblen = 18;
        else
        {   error("64-bit Objective-C exception ABI unsupported");
            fatal();
        }
        // derive edata length from jblen
        int edatalen = jblen + 4;

        FuncDeclaration *ftry_enter = FuncDeclaration::genCfunc(Type::tvoid, "objc_exception_try_enter", Type::tvoidptr);
        FuncDeclaration *fsetjmp = FuncDeclaration::genCfunc(Type::tuns32, "_setjmp", Type::tvoidptr);
        FuncDeclaration *ftry_exit = FuncDeclaration::genCfunc(Type::tvoid, "objc_exception_try_exit", Type::tvoidptr);
        FuncDeclaration *fextract = FuncDeclaration::genCfunc(Type::tvoidptr, "objc_exception_extract", Type::tvoidptr);
        FuncDeclaration *fthrowd = FuncDeclaration::genCfunc(Type::tvoid, "_dobjc_throwAs_d", Type::tvoidptr);

        TypeSArray *tedata = new TypeSArray(Type::tsize_t, new IntegerExp(loc, edatalen, Type::tsize_t));
        VarDeclaration *varedata = new VarDeclaration(loc, tedata, Lexer::uniqueId("__dobjc_ex_data"), new VoidInitializer(loc));
        varedata->semantic(sc);
        a->push(new ExpStatement(loc, new DeclarationExp(loc, varedata)));
        a->push(new ExpStatement(loc, new CallExp(loc, new VarExp(0, ftry_enter), new DotIdExp(loc, new VarExp(loc, varedata), Id::ptr))));

        Expression *cond = new CallExp(loc, new VarExp(0, fsetjmp), new DotIdExp(loc, new VarExp(loc, varedata), Id::ptr));
        cond = new NotExp(loc, cond);
        Statement *etry_exit = new ExpStatement(loc, new CallExp(loc, new VarExp(0, ftry_exit), new DotIdExp(loc, new VarExp(loc, varedata), Id::ptr)));
        TryFinallyStatement *ifbody = new TryFinallyStatement(loc, new PeelStatement(body), etry_exit);
        ifbody->objcdisable = 1; // make try-finally D-EH-only
        Statement *elsebody = new ExpStatement(loc, new CallExp(loc, new VarExp(0, fthrowd), new CallExp(loc, new VarExp(0, fextract), new DotIdExp(loc, new VarExp(loc, varedata), Id::ptr))));
        elsebody = new CompoundStatement(loc, elsebody, new ExpStatement(loc, new HaltExp(loc)));
        a->push(new IfStatement(loc, NULL, cond, ifbody, elsebody));

        wrapped = new CompoundStatement(loc, a);
        wrapped = wrapped->semantic(sc);
        return this;
    }
    assert(0);
}

int ObjcExceptionBridge::usesEH()
{
    return 1;
}

#endif

