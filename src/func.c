
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/func.c
 */

#include <stdio.h>
#include <assert.h>

#include "mars.h"
#include "init.h"
#include "declaration.h"
#include "attrib.h"
#include "expression.h"
#include "scope.h"
#include "mtype.h"
#include "aggregate.h"
#include "identifier.h"
#include "id.h"
#include "module.h"
#include "statement.h"
#include "template.h"
#include "hdrgen.h"
#include "target.h"
#include "parse.h"
#include "rmem.h"
#include "visitor.h"

Expression *addInvariant(Scope *sc, AggregateDeclaration *ad, VarDeclaration *vthis, bool direct);

void genCmain(Scope *sc);

/* A visitor to walk entire statements and provides ability to replace any sub-statements.
 */
class StatementRewriteWalker : public Visitor
{
    /* Point the currently visited statement.
     * By using replaceCurrent() method, you can replace AST during walking.
     */
    Statement **ps;
public:
    void visitStmt(Statement *&s) { ps = &s; s->accept(this); }
    void replaceCurrent(Statement *s) { *ps = s; }

    void visit(ErrorStatement *s) {  }
    void visit(PeelStatement *s)
    {
        if (s->s)
            visitStmt(s->s);
    }
    void visit(ExpStatement *s) {  }
    void visit(DtorExpStatement *s) {  }
    void visit(CompileStatement *s) {  }
    void visit(CompoundStatement *s)
    {
        if (s->statements && s->statements->dim)
        {
            for (size_t i = 0; i < s->statements->dim; i++)
            {
                if ((*s->statements)[i])
                    visitStmt((*s->statements)[i]);
            }
        }
    }
    void visit(CompoundDeclarationStatement *s) { visit((CompoundStatement *)s); }
    void visit(UnrolledLoopStatement *s)
    {
        if (s->statements && s->statements->dim)
        {
            for (size_t i = 0; i < s->statements->dim; i++)
            {
                if ((*s->statements)[i])
                    visitStmt((*s->statements)[i]);
            }
        }
    }
    void visit(ScopeStatement *s)
    {
        if (s->statement)
            visitStmt(s->statement);
    }
    void visit(WhileStatement *s)
    {
        if (s->body)
            visitStmt(s->body);
    }
    void visit(DoStatement *s)
    {
        if (s->body)
            visitStmt(s->body);
    }
    void visit(ForStatement *s)
    {
        if (s->init)
            visitStmt(s->init);
        if (s->body)
            visitStmt(s->body);
    }
    void visit(ForeachStatement *s)
    {
        if (s->body)
            visitStmt(s->body);
    }
    void visit(ForeachRangeStatement *s)
    {
        if (s->body)
            visitStmt(s->body);
    }
    void visit(IfStatement *s)
    {
        if (s->ifbody)
            visitStmt(s->ifbody);
        if (s->elsebody)
            visitStmt(s->elsebody);
    }
    void visit(ConditionalStatement *s) {  }
    void visit(PragmaStatement *s) {  }
    void visit(StaticAssertStatement *s) {  }
    void visit(SwitchStatement *s)
    {
        if (s->body)
            visitStmt(s->body);
    }
    void visit(CaseStatement *s)
    {
        if (s->statement)
            visitStmt(s->statement);
    }
    void visit(CaseRangeStatement *s)
    {
        if (s->statement)
            visitStmt(s->statement);
    }
    void visit(DefaultStatement *s)
    {
        if (s->statement)
            visitStmt(s->statement);
    }
    void visit(GotoDefaultStatement *s) {  }
    void visit(GotoCaseStatement *s) {  }
    void visit(SwitchErrorStatement *s) {  }
    void visit(ReturnStatement *s) {  }
    void visit(BreakStatement *s) {  }
    void visit(ContinueStatement *s) {  }
    void visit(SynchronizedStatement *s)
    {
        if (s->body)
            visitStmt(s->body);
    }
    void visit(WithStatement *s)
    {
        if (s->body)
            visitStmt(s->body);
    }
    void visit(TryCatchStatement *s)
    {
        if (s->body)
            visitStmt(s->body);
        if (s->catches && s->catches->dim)
        {
            for (size_t i = 0; i < s->catches->dim; i++)
            {
                Catch *c = (*s->catches)[i];
                if (c && c->handler)
                    visitStmt(c->handler);
            }
        }
    }
    void visit(TryFinallyStatement *s)
    {
        if (s->body)
            visitStmt(s->body);
        if (s->finalbody)
            visitStmt(s->finalbody);
    }
    void visit(OnScopeStatement *s) {  }
    void visit(ThrowStatement *s) {  }
    void visit(DebugStatement *s)
    {
        if (s->statement)
            visitStmt(s->statement);
    }
    void visit(GotoStatement *s) {  }
    void visit(LabelStatement *s)
    {
        if (s->statement)
            visitStmt(s->statement);
    }
    void visit(AsmStatement *s) {  }
    void visit(ImportStatement *s) {  }
};

/* Tweak all return statements and dtor call for nrvo_var, for correct NRVO.
 */
class NrvoWalker : public StatementRewriteWalker
{
public:
    FuncDeclaration *fd;
    Scope *sc;

    void visit(ReturnStatement *s)
    {
        // See if all returns are instead to be replaced with a goto returnLabel;
        if (fd->returnLabel)
        {
            /* Rewrite:
             *  return exp;
             * as:
             *  vresult = exp; goto Lresult;
             */
            GotoStatement *gs = new GotoStatement(s->loc, Id::returnLabel);
            gs->label = fd->returnLabel;

            Statement *s1 = gs;
            if (s->exp)
                s1 = new CompoundStatement(s->loc, new ExpStatement(s->loc, s->exp), gs);

            replaceCurrent(s1);
        }
    }
    void visit(TryFinallyStatement *s)
    {
        DtorExpStatement *des;
        if (fd->nrvo_can &&
            s->finalbody && (des = s->finalbody->isDtorExpStatement()) != NULL &&
            fd->nrvo_var == des->var)
        {
            /* Normally local variable dtors are called regardless exceptions.
             * But for nrvo_var, its dtor should be called only when exception is thrown.
             *
             * Rewrite:
             *      try { s->body; } finally { nrvo_var->edtor; }
             *      // equivalent with:
             *      //    s->body; scope(exit) nrvo_var->edtor;
             * as:
             *      try { s->body; } catch(__o) { nrvo_var->edtor; throw __o; }
             *      // equivalent with:
             *      //    s->body; scope(failure) nrvo_var->edtor;
             */
            Statement *sexception = new DtorExpStatement(Loc(), fd->nrvo_var->edtor, fd->nrvo_var);
            Identifier *id = Identifier::generateId("__o");

            Statement *handler = new PeelStatement(sexception);
            if (sexception->blockExit(fd, false) & BEfallthru)
            {
                ThrowStatement *ts = new ThrowStatement(Loc(), new IdentifierExp(Loc(), id));
                ts->internalThrow = true;
                handler = new CompoundStatement(Loc(), handler, ts);
            }

            Catches *catches = new Catches();
            Catch *ctch = new Catch(Loc(), NULL, id, handler);
            ctch->internalCatch = true;
            ctch->semantic(sc);     // Run semantic to resolve identifier '__o'
            catches->push(ctch);

            Statement *s2 = new TryCatchStatement(Loc(), s->body, catches);
            replaceCurrent(s2);
            s2->accept(this);
        }
        else
            StatementRewriteWalker::visit(s);
    }
};

/********************************* FuncDeclaration ****************************/

FuncDeclaration::FuncDeclaration(Loc loc, Loc endloc, Identifier *id, StorageClass storage_class, Type *type)
    : Declaration(id)
{
    //printf("FuncDeclaration(id = '%s', type = %p)\n", id->toChars(), type);
    //printf("storage_class = x%x\n", storage_class);
    this->storage_class = storage_class;
    this->type = type;
    if (type)
    {
        // Normalize storage_class, because function-type related attributes
        // are already set in the 'type' in parsing phase.
        this->storage_class &= ~(STC_TYPECTOR | STC_FUNCATTR);
    }
    this->loc = loc;
    this->endloc = endloc;
    fthrows = NULL;
    frequire = NULL;
    fdrequire = NULL;
    fdensure = NULL;
    outId = NULL;
    vresult = NULL;
    returnLabel = NULL;
    fensure = NULL;
    fbody = NULL;
    localsymtab = NULL;
    vthis = NULL;
    v_arguments = NULL;
#ifdef IN_GCC
    v_argptr = NULL;
    v_arguments_var = NULL;
#endif
    v_argsave = NULL;
    parameters = NULL;
    labtab = NULL;
    overnext = NULL;
    overnext0 = NULL;
    vtblIndex = -1;
    hasReturnExp = 0;
    naked = false;
    inlineStatusExp = ILSuninitialized;
    inlineStatusStmt = ILSuninitialized;
    inlineNest = 0;
    ctfeCode = NULL;
    isArrayOp = 0;
    semantic3Errors = false;
    fes = NULL;
    introducing = 0;
    tintro = NULL;
    /* The type given for "infer the return type" is a TypeFunction with
     * NULL for the return type.
     */
    inferRetType = (type && type->nextOf() == NULL);
    storage_class2 = 0;
    hasReturnExp = 0;
    nrvo_can = 1;
    nrvo_var = NULL;
    shidden = NULL;
    builtin = BUILTINunknown;
    tookAddressOf = 0;
    requiresClosure = false;
    flags = 0;
    returns = NULL;
    gotos = NULL;
}

Dsymbol *FuncDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("FuncDeclaration::syntaxCopy('%s')\n", toChars());
    FuncDeclaration *f =
        s ? (FuncDeclaration *)s
          : new FuncDeclaration(loc, endloc, ident, storage_class, type->syntaxCopy());
    f->outId = outId;
    f->frequire = frequire ? frequire->syntaxCopy() : NULL;
    f->fensure  = fensure  ? fensure->syntaxCopy()  : NULL;
    f->fbody    = fbody    ? fbody->syntaxCopy()    : NULL;
    assert(!fthrows); // deprecated
    return f;
}

// Do the semantic analysis on the external interface to the function.

void FuncDeclaration::semantic(Scope *sc)
{
    TypeFunction *f;
    AggregateDeclaration *ad;
    InterfaceDeclaration *id;

#if 0
    printf("FuncDeclaration::semantic(sc = %p, this = %p, '%s', linkage = %d)\n", sc, this, toPrettyChars(), sc->linkage);
    if (isFuncLiteralDeclaration())
        printf("\tFuncLiteralDeclaration()\n");
    printf("sc->parent = %s, parent = %s\n", sc->parent->toChars(), parent ? parent->toChars() : "");
    printf("type: %p, %s\n", type, type->toChars());
#endif

    if (semanticRun != PASSinit && isFuncLiteralDeclaration())
    {
        /* Member functions that have return types that are
         * forward references can have semantic() run more than
         * once on them.
         * See test\interface2.d, test20
         */
        return;
    }

    if (semanticRun >= PASSsemanticdone)
        return;
    assert(semanticRun <= PASSsemantic);
    semanticRun = PASSsemantic;

    parent = sc->parent;
    Dsymbol *parent = toParent();

    if (scope)
    {
        sc = scope;
        scope = NULL;
    }

    unsigned dprogress_save = Module::dprogress;

    foverrides.setDim(0);       // reset in case semantic() is being retried for this function

    storage_class |= sc->stc & ~STCref;
    ad = isThis();
    if (ad)
    {
        storage_class |= ad->storage_class & (STC_TYPECTOR | STCsynchronized);

        if (StructDeclaration *sd = ad->isStructDeclaration())
            sd->makeNested();
    }
    if (sc->func)
        storage_class |= sc->func->storage_class & STCdisable;
    // Remove prefix storage classes silently.
    if ((storage_class & STC_TYPECTOR) && !(ad || isNested()))
        storage_class &= ~STC_TYPECTOR;

    //printf("function storage_class = x%llx, sc->stc = x%llx, %x\n", storage_class, sc->stc, Declaration::isFinal());

    FuncLiteralDeclaration *fld = isFuncLiteralDeclaration();
    if (fld && fld->treq)
    {
        Type *treq = fld->treq;
        assert(treq->nextOf()->ty == Tfunction);
        if (treq->ty == Tdelegate)
            fld->tok = TOKdelegate;
        else if (treq->ty == Tpointer && treq->nextOf()->ty == Tfunction)
            fld->tok = TOKfunction;
        else
            assert(0);
        linkage = ((TypeFunction *)treq->nextOf())->linkage;
    }
    else
        linkage = sc->linkage;
    protection = sc->protection;
    userAttribDecl = sc->userAttribDecl;

    if (!originalType)
        originalType = type->syntaxCopy();
    if (!type->deco)
    {
        sc = sc->push();
        sc->stc |= storage_class & (STCdisable | STCdeprecated);  // forward to function type
        TypeFunction *tf = (TypeFunction *)type;

        if (sc->func)
        {
            /* If the parent is @safe, then this function defaults to safe too.
             */
            if (tf->trust == TRUSTdefault)
            {
                FuncDeclaration *fd = sc->func;

                /* If the parent's @safe-ty is inferred, then this function's @safe-ty needs
                 * to be inferred first.
                 * If this function's @safe-ty is inferred, then it needs to be infeerd first.
                 * (local template function inside @safe function can be inferred to @system).
                 */
                if (fd->isSafeBypassingInference() && !isInstantiated())
                    tf->trust = TRUSTsafe;              // default to @safe
            }

            /* If the nesting parent is pure, then this function defaults to pure too.
             */
            if (tf->purity == PUREimpure && (isNested() || isThis()))
            {
                FuncDeclaration *fd = NULL;
                for (Dsymbol *p = toParent2(); p; p = p->toParent2())
                {
                    if (AggregateDeclaration *adx = p->isAggregateDeclaration())
                    {
                        if (adx->isNested())
                            continue;
                        break;
                    }
                    if ((fd = p->isFuncDeclaration()) != NULL)
                        break;
                }

                /* If the parent's purity is inferred, then this function's purity needs
                 * to be inferred first.
                 */
                if (fd && fd->isPureBypassingInferenceX())
                    tf->purity = PUREfwdref;            // default to pure
            }
        }

        if (tf->isref)      sc->stc |= STCref;
        if (tf->isnothrow)  sc->stc |= STCnothrow;
        if (tf->isnogc)     sc->stc |= STCnogc;
        if (tf->isproperty) sc->stc |= STCproperty;
        if (tf->purity == PUREfwdref)   sc->stc |= STCpure;
        if (tf->trust != TRUSTdefault)
            sc->stc &= ~(STCsafe | STCsystem | STCtrusted);
        if (tf->trust == TRUSTsafe)     sc->stc |= STCsafe;
        if (tf->trust == TRUSTsystem)   sc->stc |= STCsystem;
        if (tf->trust == TRUSTtrusted)  sc->stc |= STCtrusted;

        if (isCtorDeclaration())
        {
            sc->flags |= SCOPEctor;

            Type *tret;
            if (!ad || parent->isUnionDeclaration())
            {
                error("constructors are only for class or struct definitions");
                tret = Type::tvoid;
            }
            else
            {
                tret = ad->handleType();
                assert(tret);
                tret = tret->addStorageClass(storage_class | sc->stc);
                tret = tret->addMod(type->mod);
            }
            tf->next = tret;

            if (ad && ad->isStructDeclaration())
                sc->stc |= STCref;
        }

        sc->linkage = linkage;

        if (!tf->isNaked() && !(isThis() || isNested()))
        {
            OutBuffer buf;
            MODtoBuffer(&buf, tf->mod);
            error("without 'this' cannot be %s", buf.peekString());
            tf->mod = 0;    // remove qualifiers
        }

        /* Apply const, immutable, wild and shared storage class
         * to the function type. Do this before type semantic.
         */
        StorageClass stc = storage_class;
        if (type->isImmutable())
            stc |= STCimmutable;
        if (type->isConst())
            stc |= STCconst;
        if (type->isShared() || storage_class & STCsynchronized)
            stc |= STCshared;
        if (type->isWild())
            stc |= STCwild;
        switch (stc & STC_TYPECTOR)
        {
            case STCimmutable:
            case STCimmutable | STCconst:
            case STCimmutable | STCwild:
            case STCimmutable | STCwild | STCconst:
            case STCimmutable | STCshared:
            case STCimmutable | STCshared | STCconst:
            case STCimmutable | STCshared | STCwild:
            case STCimmutable | STCshared | STCwild | STCconst:
                // Don't use immutableOf(), as that will do a merge()
                type = type->makeImmutable();
                break;

            case STCconst:
                type = type->makeConst();
                break;

            case STCwild:
                type = type->makeWild();
                break;

            case STCwild | STCconst:
                type = type->makeWildConst();
                break;

            case STCshared:
                type = type->makeShared();
                break;

            case STCshared | STCconst:
                type = type->makeSharedConst();
                break;

            case STCshared | STCwild:
                type = type->makeSharedWild();
                break;

            case STCshared | STCwild | STCconst:
                type = type->makeSharedWildConst();
                break;

            case 0:
                break;

            default:
                assert(0);
        }

        type = type->semantic(loc, sc);
        sc = sc->pop();
    }
    if (type->ty != Tfunction)
    {
        if (type->ty != Terror)
        {
            error("%s must be a function instead of %s", toChars(), type->toChars());
            type = Type::terror;
        }
        errors = true;
        return;
    }
    else
    {
        // Merge back function attributes into 'originalType'.
        // It's used for mangling, ddoc, and json output.
        TypeFunction *tfo = (TypeFunction *)originalType;
        TypeFunction *tfx = (TypeFunction *)type;
        tfo->mod        = tfx->mod;
        tfo->isref      = tfx->isref;
        tfo->isnothrow  = tfx->isnothrow;
        tfo->isnogc     = tfx->isnogc;
        tfo->isproperty = tfx->isproperty;
        tfo->purity     = tfx->purity;
        tfo->trust      = tfx->trust;

        storage_class &= ~(STC_TYPECTOR | STC_FUNCATTR);
    }

    f = (TypeFunction *)type;
    size_t nparams = Parameter::dim(f->parameters);

    if (storage_class & STCscope)
        error("functions cannot be scope");

    if (isAbstract() && !isVirtual())
    {
        const char *sfunc;
        if (isStatic())
            sfunc = "static";
        else if (protection.kind == PROTprivate || protection.kind == PROTpackage)
            sfunc = protectionToChars(protection.kind);
        else
            sfunc = "non-virtual";
        error("%s functions cannot be abstract", sfunc);
    }

    if (isOverride() && !isVirtual())
    {
        PROTKIND kind = prot().kind;
        if ((kind == PROTprivate || kind == PROTpackage) && isMember())
            error("%s method is not virtual and cannot override", protectionToChars(kind));
        else
            error("cannot override a non-virtual function");
    }

    if (isAbstract() && isFinalFunc())
        error("cannot be both final and abstract");
#if 0
    if (isAbstract() && fbody)
        error("abstract functions cannot have bodies");
#endif

#if 0
    if (isStaticConstructor() || isStaticDestructor())
    {
        if (!isStatic() || type->nextOf()->ty != Tvoid)
            error("static constructors / destructors must be static void");
        if (f->arguments && f->arguments->dim)
            error("static constructors / destructors must have empty parameter list");
        // BUG: check for invalid storage classes
    }
#endif

    id = parent->isInterfaceDeclaration();
    if (id)
    {
        storage_class |= STCabstract;

        if (isCtorDeclaration() ||
            isPostBlitDeclaration() ||
            isDtorDeclaration() ||
            isInvariantDeclaration() ||
            isNewDeclaration() || isDelete())
            error("constructors, destructors, postblits, invariants, new and delete functions are not allowed in interface %s", id->toChars());
        if (fbody && isVirtual())
            error("function body only allowed in final functions in interface %s", id->toChars());
    }

    if (UnionDeclaration *ud = parent->isUnionDeclaration())
    {
        if (isPostBlitDeclaration() ||
            isDtorDeclaration() ||
            isInvariantDeclaration())
            error("destructors, postblits and invariants are not allowed in union %s", ud->toChars());
    }

    /* Contracts can only appear without a body when they are virtual interface functions
     */
    if (!fbody && (fensure || frequire) && !(id && isVirtual()))
        error("in and out contracts require function body");

    if (StructDeclaration *sd = parent->isStructDeclaration())
    {
        if (isCtorDeclaration())
        {
            goto Ldone;
        }
    }

    if (ClassDeclaration *cd = parent->isClassDeclaration())
    {
        if (isCtorDeclaration())
        {
            goto Ldone;
        }

        if (storage_class & STCabstract)
            cd->isabstract = true;

        // if static function, do not put in vtbl[]
        if (!isVirtual())
        {
            //printf("\tnot virtual\n");
            goto Ldone;
        }
        // Suppress further errors if the return type is an error
        if (type->nextOf() == Type::terror)
            goto Ldone;

        bool may_override = false;
        for (size_t i = 0; i < cd->baseclasses->dim; i++)
        {
            BaseClass *b = (*cd->baseclasses)[i];
            ClassDeclaration *cbd = b->type->toBasetype()->isClassHandle();
            if (!cbd)
                continue;
            for (size_t j = 0; j < cbd->vtbl.dim; j++)
            {
                FuncDeclaration *f2 = cbd->vtbl[j]->isFuncDeclaration();
                if (!f2 || f2->ident != ident)
                    continue;
                if (cbd->parent && cbd->parent->isTemplateInstance())
                {
                    if (!f2->functionSemantic())
                        goto Ldone;
                }
                may_override = true;
            }
        }
        if (may_override && type->nextOf() == NULL)
        {
            /* If same name function exists in base class but 'this' is auto return,
             * cannot find index of base class's vtbl[] to override.
             */
            error("return type inference is not supported if may override base class function");
        }

        /* Find index of existing function in base class's vtbl[] to override
         * (the index will be the same as in cd's current vtbl[])
         */
        int vi = cd->baseClass ? findVtblIndex((Dsymbols*)&cd->baseClass->vtbl, (int)cd->baseClass->vtbl.dim)
                               : -1;

        bool doesoverride = false;
        switch (vi)
        {
            case -1:
        Lintro:
                /* Didn't find one, so
                 * This is an 'introducing' function which gets a new
                 * slot in the vtbl[].
                 */

                // Verify this doesn't override previous final function
                if (cd->baseClass)
                {
                    Dsymbol *s = cd->baseClass->search(loc, ident);
                    if (s)
                    {
                        FuncDeclaration *f2 = s->isFuncDeclaration();
                        if (f2)
                        {
                            f2 = f2->overloadExactMatch(type);
                            if (f2 && f2->isFinalFunc() && f2->prot().kind != PROTprivate)
                                error("cannot override final function %s", f2->toPrettyChars());
                        }
                    }
                }

                if (isFinalFunc())
                {
                    // Don't check here, as it may override an interface function
                    //if (isOverride())
                        //error("is marked as override, but does not override any function");
                    cd->vtblFinal.push(this);
                }
                else
                {
                    //printf("\tintroducing function\n");
                    introducing = 1;
                    if (cd->cpp && Target::reverseCppOverloads)
                    {
                        // with dmc, overloaded functions are grouped and in reverse order
                        vtblIndex = (int)cd->vtbl.dim;
                        for (size_t i = 0; i < cd->vtbl.dim; i++)
                        {
                            if (cd->vtbl[i]->ident == ident && cd->vtbl[i]->parent == parent)
                            {
                                vtblIndex = (int)i;
                                break;
                            }
                        }
                        // shift all existing functions back
                        for (size_t i = cd->vtbl.dim; i > vtblIndex; i--)
                        {
                            FuncDeclaration *fd = cd->vtbl[i-1]->isFuncDeclaration();
                            assert(fd);
                            fd->vtblIndex++;
                        }
                        cd->vtbl.insert(vtblIndex, this);
                    }
                    else
                    {
                        // Append to end of vtbl[]
                        vi = (int)cd->vtbl.dim;
                        cd->vtbl.push(this);
                        vtblIndex = vi;
                    }
                }
                break;

            case -2:    // can't determine because of fwd refs
                cd->sizeok = SIZEOKfwd; // can't finish due to forward reference
                Module::dprogress = dprogress_save;
                return;

            default:
            {   FuncDeclaration *fdv = cd->baseClass->vtbl[vi]->isFuncDeclaration();
                FuncDeclaration *fdc = cd->vtbl[vi]->isFuncDeclaration();
                // This function is covariant with fdv

                if (fdc == this)
                {
                    doesoverride = true;
                    break;
                }

                if (fdc->toParent() == parent)
                {
                    //printf("vi = %d,\tthis = %p %s %s @ [%s]\n\tfdc  = %p %s %s @ [%s]\n\tfdv  = %p %s %s @ [%s]\n",
                    //        vi, this, this->toChars(), this->type->toChars(), this->loc.toChars(),
                    //            fdc,  fdc ->toChars(), fdc ->type->toChars(), fdc ->loc.toChars(),
                    //            fdv,  fdv ->toChars(), fdv ->type->toChars(), fdv ->loc.toChars());

                    // fdc overrides fdv exactly, then this introduces new function.
                    if (fdc->type->mod == fdv->type->mod && this->type->mod != fdv->type->mod)
                        goto Lintro;
                }

                // This function overrides fdv
                if (fdv->isFinalFunc())
                    error("cannot override final function %s", fdv->toPrettyChars());

                doesoverride = true;
                if (!isOverride())
                    ::deprecation(loc, "implicitly overriding base class method %s with %s deprecated; add 'override' attribute",
                        fdv->toPrettyChars(), toPrettyChars());

                if (fdc->toParent() == parent)
                {
                    // If both are mixins, or both are not, then error.
                    // If either is not, the one that is not overrides the other.
                    bool thismixin = this->parent->isClassDeclaration() != NULL;
                    bool fdcmixin = fdc->parent->isClassDeclaration() != NULL;
                    if (thismixin == fdcmixin)
                    {
                        error("multiple overrides of same function");
                    }
                    else if (!thismixin)    // fdc overrides fdv
                    {   // this doesn't override any function
                        break;
                    }
                }
                cd->vtbl[vi] = this;
                vtblIndex = vi;

                /* Remember which functions this overrides
                 */
                foverrides.push(fdv);

                /* This works by whenever this function is called,
                 * it actually returns tintro, which gets dynamically
                 * cast to type. But we know that tintro is a base
                 * of type, so we could optimize it by not doing a
                 * dynamic cast, but just subtracting the isBaseOf()
                 * offset if the value is != null.
                 */

                if (fdv->tintro)
                    tintro = fdv->tintro;
                else if (!type->equals(fdv->type))
                {
                    /* Only need to have a tintro if the vptr
                     * offsets differ
                     */
                    int offset;
                    if (fdv->type->nextOf()->isBaseOf(type->nextOf(), &offset))
                    {
                        tintro = fdv->type;
                    }
                }
                break;
            }
        }

        /* Go through all the interface bases.
         * If this function is covariant with any members of those interface
         * functions, set the tintro.
         */
        for (size_t i = 0; i < cd->interfaces_dim; i++)
        {
            BaseClass *b = cd->interfaces[i];
            vi = findVtblIndex((Dsymbols *)&b->base->vtbl, (int)b->base->vtbl.dim);
            switch (vi)
            {
                case -1:
                    break;

                case -2:
                    cd->sizeok = SIZEOKfwd;     // can't finish due to forward reference
                    Module::dprogress = dprogress_save;
                    return;

                default:
                {   FuncDeclaration *fdv = (FuncDeclaration *)b->base->vtbl[vi];
                    Type *ti = NULL;

                    /* Remember which functions this overrides
                     */
                    foverrides.push(fdv);

                    /* Should we really require 'override' when implementing
                     * an interface function?
                     */
                    //if (!isOverride())
                        //warning(loc, "overrides base class function %s, but is not marked with 'override'", fdv->toPrettyChars());

                    if (fdv->tintro)
                        ti = fdv->tintro;
                    else if (!type->equals(fdv->type))
                    {
                        /* Only need to have a tintro if the vptr
                         * offsets differ
                         */
                        unsigned errors = global.errors;
                        global.gag++;            // suppress printing of error messages
                        int offset;
                        int baseOf = fdv->type->nextOf()->isBaseOf(type->nextOf(), &offset);
                        global.gag--;            // suppress printing of error messages
                        if (errors != global.errors)
                        {
                            // any error in isBaseOf() is a forward reference error, so we bail out
                            global.errors = errors;
                            cd->sizeok = SIZEOKfwd;    // can't finish due to forward reference
                            Module::dprogress = dprogress_save;
                            return;
                        }
                        if (baseOf)
                        {
                            ti = fdv->type;
                        }
                    }
                    if (ti)
                    {
                        if (tintro)
                        {
                            if (!tintro->nextOf()->equals(ti->nextOf()) &&
                                !tintro->nextOf()->isBaseOf(ti->nextOf(), NULL) &&
                                !ti->nextOf()->isBaseOf(tintro->nextOf(), NULL))
                            {
                                error("incompatible covariant types %s and %s", tintro->toChars(), ti->toChars());
                            }
                        }
                        tintro = ti;
                    }
                    goto L2;
                }
            }
        }

        if (!doesoverride && isOverride() && type->nextOf())
        {
            Dsymbol *s = NULL;
            for (size_t i = 0; i < cd->baseclasses->dim; i++)
            {
                s = (*cd->baseclasses)[i]->base->search_correct(ident);
                if (s) break;
            }

            if (s)
                error("does not override any function, did you mean to override '%s'?", s->toPrettyChars());
            else
                error("does not override any function");
        }

    L2: ;

        /* Go through all the interface bases.
         * Disallow overriding any final functions in the interface(s).
         */
        for (size_t i = 0; i < cd->interfaces_dim; i++)
        {
            BaseClass *b = cd->interfaces[i];
            if (b->base)
            {
                Dsymbol *s = search_function(b->base, ident);
                if (s)
                {
                    FuncDeclaration *f2 = s->isFuncDeclaration();
                    if (f2)
                    {
                        f2 = f2->overloadExactMatch(type);
                        if (f2 && f2->isFinalFunc() && f2->prot().kind != PROTprivate)
                            error("cannot override final function %s.%s", b->base->toChars(), f2->toPrettyChars());
                    }
                }
            }
        }
    }
    else if (isOverride() && !parent->isTemplateInstance())
        error("override only applies to class member functions");

    // Reflect this->type to f because it could be changed by findVtblIndex
    assert(type->ty == Tfunction);
    f = (TypeFunction *)type;

    /* Do not allow template instances to add virtual functions
     * to a class.
     */
    if (isVirtual())
    {
        TemplateInstance *ti = parent->isTemplateInstance();
        if (ti)
        {
            // Take care of nested templates
            while (1)
            {
                TemplateInstance *ti2 = ti->tempdecl->parent->isTemplateInstance();
                if (!ti2)
                    break;
                ti = ti2;
            }

            // If it's a member template
            ClassDeclaration *cd = ti->tempdecl->isClassMember();
            if (cd)
            {
                error("cannot use template to add virtual function to class '%s'", cd->toChars());
            }
        }
    }

    if (isMain())
    {
        // Check parameters to see if they are either () or (char[][] args)
        switch (nparams)
        {
            case 0:
                break;

            case 1:
            {
                Parameter *fparam0 = Parameter::getNth(f->parameters, 0);
                if (fparam0->type->ty != Tarray ||
                    fparam0->type->nextOf()->ty != Tarray ||
                    fparam0->type->nextOf()->nextOf()->ty != Tchar ||
                    fparam0->storageClass & (STCout | STCref | STClazy))
                    goto Lmainerr;
                break;
            }

            default:
                goto Lmainerr;
        }

        if (!f->nextOf())
            error("must return int or void");
        else if (f->nextOf()->ty != Tint32 && f->nextOf()->ty != Tvoid)
            error("must return int or void, not %s", f->nextOf()->toChars());
        if (f->varargs)
        {
        Lmainerr:
            error("parameters must be main() or main(string[] args)");
        }
    }

    if (isVirtual() && semanticRun != PASSsemanticdone)
    {
        /* Rewrite contracts as nested functions, then call them.
         * Doing it as nested functions means that overriding functions
         * can call them.
         */
        if (frequire)
        {
            /*   in { ... }
             * becomes:
             *   void __require() { ... }
             *   __require();
             */
            Loc loc = frequire->loc;
            TypeFunction *tf = new TypeFunction(NULL, Type::tvoid, 0, LINKd);
            tf->isnothrow = f->isnothrow;
            tf->isnogc = f->isnogc;
            tf->purity = f->purity;
            tf->trust = f->trust;
            FuncDeclaration *fd = new FuncDeclaration(loc, loc,
                Id::require, STCundefined, tf);
            fd->fbody = frequire;
            Statement *s1 = new ExpStatement(loc, fd);
            Expression *e = new CallExp(loc, new VarExp(loc, fd, 0), (Expressions *)NULL);
            Statement *s2 = new ExpStatement(loc, e);
            frequire = new CompoundStatement(loc, s1, s2);
            fdrequire = fd;
        }

        if (!outId && f->nextOf() && f->nextOf()->toBasetype()->ty != Tvoid)
            outId = Id::result; // provide a default

        if (fensure)
        {
            /*   out (result) { ... }
             * becomes:
             *   void __ensure(ref tret result) { ... }
             *   __ensure(result);
             */
            Loc loc = fensure->loc;
            Parameters *fparams = new Parameters();
            Parameter *p = NULL;
            if (outId)
            {
                p = new Parameter(STCref | STCconst, f->nextOf(), outId, NULL);
                fparams->push(p);
            }
            TypeFunction *tf = new TypeFunction(fparams, Type::tvoid, 0, LINKd);
            tf->isnothrow = f->isnothrow;
            tf->isnogc = f->isnogc;
            tf->purity = f->purity;
            tf->trust = f->trust;
            FuncDeclaration *fd = new FuncDeclaration(loc, loc,
                Id::ensure, STCundefined, tf);
            fd->fbody = fensure;
            Statement *s1 = new ExpStatement(loc, fd);
            Expression *eresult = NULL;
            if (outId)
                eresult = new IdentifierExp(loc, outId);
            Expression *e = new CallExp(loc, new VarExp(loc, fd, 0), eresult);
            Statement *s2 = new ExpStatement(loc, e);
            fensure = new CompoundStatement(loc, s1, s2);
            fdensure = fd;
        }
    }

Ldone:
    /* Purity and safety can be inferred for some functions by examining
     * the function body.
     */
    TemplateInstance *ti;
    if (fbody &&
        (isFuncLiteralDeclaration() ||
         isInstantiated() && !isVirtualMethod() &&
         !(ti = parent->isTemplateInstance(), ti && !ti->isTemplateMixin() && ti->tempdecl->ident != ident)))
    {
        if (f->purity == PUREimpure)        // purity not specified
            flags |= FUNCFLAGpurityInprocess;

        if (f->trust == TRUSTdefault)
            flags |= FUNCFLAGsafetyInprocess;

        if (!f->isnothrow)
            flags |= FUNCFLAGnothrowInprocess;

        if (!f->isnogc)
            flags |= FUNCFLAGnogcInprocess;

        if (!isVirtual() || introducing)
            flags |= FUNCFLAGreturnInprocess;
    }

    Module::dprogress++;
    semanticRun = PASSsemanticdone;

    /* Save scope for possible later use (if we need the
     * function internals)
     */
    scope = sc->copy();
    scope->setNoFree();

    static bool printedMain = false;  // semantic might run more than once
    if (global.params.verbose && !printedMain)
    {
        const char *type = isMain() ? "main" : isWinMain() ? "winmain" : isDllMain() ? "dllmain" : (const char *)NULL;
        Module *mod = sc->module;

        if (type && mod)
        {
            printedMain = true;
            const char *name = FileName::searchPath(global.path, mod->srcfile->toChars(), true);
            fprintf(global.stdmsg, "entry     %-10s\t%s\n", type, name);
        }
    }

    if (fbody && isMain() && sc->module->isRoot())
        genCmain(sc);

    assert(type->ty != Terror || errors);
}

void FuncDeclaration::semantic2(Scope *sc)
{
}

// Do the semantic analysis on the internals of the function.

void FuncDeclaration::semantic3(Scope *sc)
{
    VarDeclaration *argptr = NULL;
    VarDeclaration *_arguments = NULL;
    int nerrors = global.errors;

    if (!parent)
    {
        if (global.errors)
            return;
        //printf("FuncDeclaration::semantic3(%s '%s', sc = %p)\n", kind(), toChars(), sc);
        assert(0);
    }
    //printf("FuncDeclaration::semantic3('%s.%s', %p, sc = %p, loc = %s)\n", parent->toChars(), toChars(), this, sc, loc.toChars());
    //fflush(stdout);
    //printf("storage class = x%x %x\n", sc->stc, storage_class);
    //{ static int x; if (++x == 2) *(char*)0=0; }
    //printf("\tlinkage = %d\n", sc->linkage);

    //printf(" sc->incontract = %d\n", (sc->flags & SCOPEcontract));
    if (semanticRun >= PASSsemantic3)
        return;
    semanticRun = PASSsemantic3;
    semantic3Errors = false;

    if (!type || type->ty != Tfunction)
        return;
    TypeFunction *f = (TypeFunction *)type;
    if (!inferRetType && f->next->ty == Terror)
        return;

    if (!fbody && inferRetType && !f->next)
    {
        error("has no function body with return type inference");
        return;
    }

    if (frequire)
    {
        for (size_t i = 0; i < foverrides.dim; i++)
        {
            FuncDeclaration *fdv = foverrides[i];

            if (fdv->fbody && !fdv->frequire)
            {
                error("cannot have an in contract when overriden function %s does not have an in contract", fdv->toPrettyChars());
                break;
            }
        }
    }

    frequire = mergeFrequire(frequire);
    fensure = mergeFensure(fensure, outId);

    if (fbody || frequire || fensure)
    {
        /* Symbol table into which we place parameters and nested functions,
         * solely to diagnose name collisions.
         */
        localsymtab = new DsymbolTable();

        // Establish function scope
        ScopeDsymbol *ss = new ScopeDsymbol();
        ss->parent = sc->scopesym;
        Scope *sc2 = sc->push(ss);
        sc2->func = this;
        sc2->parent = this;
        sc2->callSuper = 0;
        sc2->sbreak = NULL;
        sc2->scontinue = NULL;
        sc2->sw = NULL;
        sc2->fes = fes;
        sc2->linkage = LINKd;
        sc2->stc &= ~(STCauto | STCscope | STCstatic | STCabstract |
                        STCdeprecated | STCoverride |
                        STC_TYPECTOR | STCfinal | STCtls | STCgshared | STCref | STCreturn |
                        STCproperty | STCnothrow | STCpure | STCsafe | STCtrusted | STCsystem);
        sc2->protection = Prot(PROTpublic);
        sc2->explicitProtection = 0;
        sc2->structalign = STRUCTALIGN_DEFAULT;
        if (this->ident != Id::require && this->ident != Id::ensure)
            sc2->flags = sc->flags & ~SCOPEcontract;
        sc2->flags &= ~SCOPEcompile;
        sc2->tf = NULL;
        sc2->os = NULL;
        sc2->noctor = 0;
        sc2->userAttribDecl = NULL;
        if (sc2->intypeof == 1) sc2->intypeof = 2;
        sc2->fieldinit = NULL;
        sc2->fieldinit_dim = 0;

        if (isMember2())
        {
            FuncLiteralDeclaration *fld = isFuncLiteralDeclaration();
            if (fld && !sc->intypeof)
            {
                if (fld->tok == TOKreserved)
                    fld->tok = TOKfunction;
                if (isNested())
                {
                    error("cannot be class members");
                    return;
                }
            }
            assert(!isNested() || sc->intypeof);    // can't be both member and nested
        }

        // Declare 'this'
        AggregateDeclaration *ad = isThis();
        vthis = declareThis(sc2, ad);

        // Declare hidden variable _arguments[] and _argptr
        if (f->varargs == 1)
        {
#ifndef IN_GCC
            if (global.params.is64bit && !global.params.isWindows)
            {
                // Declare save area for varargs registers
                Type *t = new TypeIdentifier(loc, Id::va_argsave_t);
                t = t->semantic(loc, sc);
                if (t == Type::terror)
                {
                    error("must import core.vararg to use variadic functions");
                    return;
                }
                else
                {
                    v_argsave = new VarDeclaration(loc, t, Id::va_argsave, NULL);
                    v_argsave->storage_class |= STCtemp;
                    v_argsave->semantic(sc2);
                    sc2->insert(v_argsave);
                    v_argsave->parent = this;
                }
            }
#endif

            if (f->linkage == LINKd)
            {
                // Declare _arguments[]
                v_arguments = new VarDeclaration(Loc(), Type::typeinfotypelist->type, Id::_arguments_typeinfo, NULL);
                v_arguments->storage_class |= STCtemp | STCparameter;
                v_arguments->semantic(sc2);
                sc2->insert(v_arguments);
                v_arguments->parent = this;

                //Type *t = Type::typeinfo->type->constOf()->arrayOf();
                Type *t = Type::dtypeinfo->type->arrayOf();
                _arguments = new VarDeclaration(Loc(), t, Id::_arguments, NULL);
                _arguments->storage_class |= STCtemp;
                _arguments->semantic(sc2);
                sc2->insert(_arguments);
                _arguments->parent = this;
            }
            if (f->linkage == LINKd || (f->parameters && Parameter::dim(f->parameters)))
            {
                // Declare _argptr
                Type *t = Type::tvalist;
                argptr = new VarDeclaration(Loc(), t, Id::_argptr, NULL);
                argptr->storage_class |= STCtemp;
                argptr->semantic(sc2);
                sc2->insert(argptr);
                argptr->parent = this;
            }
        }

        /* Declare all the function parameters as variables
         * and install them in parameters[]
         */
        size_t nparams = Parameter::dim(f->parameters);
        if (nparams)
        {
            /* parameters[] has all the tuples removed, as the back end
             * doesn't know about tuples
             */
            parameters = new VarDeclarations();
            parameters->reserve(nparams);
            for (size_t i = 0; i < nparams; i++)
            {
                Parameter *fparam = Parameter::getNth(f->parameters, i);
                Identifier *id = fparam->ident;
                StorageClass stc = 0;
                if (!id)
                {
                    /* Generate identifier for un-named parameter,
                     * because we need it later on.
                     */
                    fparam->ident = id = Identifier::generateId("_param_", i);
                    stc |= STCtemp;
                }
                Type *vtype = fparam->type;
                VarDeclaration *v = new VarDeclaration(loc, vtype, id, NULL);
                //printf("declaring parameter %s of type %s\n", v->toChars(), v->type->toChars());
                stc |= STCparameter;
                if (f->varargs == 2 && i + 1 == nparams)
                    stc |= STCvariadic;
                stc |= fparam->storageClass & (STCin | STCout | STCref | STCreturn | STClazy | STCfinal | STC_TYPECTOR | STCnodtor);
                v->storage_class = stc;
                v->semantic(sc2);
                if (!sc2->insert(v))
                    error("parameter %s.%s is already defined", toChars(), v->toChars());
                else
                    parameters->push(v);
                localsymtab->insert(v);
                v->parent = this;
            }
        }

        // Declare the tuple symbols and put them in the symbol table,
        // but not in parameters[].
        if (f->parameters)
        {
            for (size_t i = 0; i < f->parameters->dim; i++)
            {
                Parameter *fparam = (*f->parameters)[i];

                if (!fparam->ident)
                    continue;                   // never used, so ignore
                if (fparam->type->ty == Ttuple)
                {
                    TypeTuple *t = (TypeTuple *)fparam->type;
                    size_t dim = Parameter::dim(t->arguments);
                    Objects *exps = new Objects();
                    exps->setDim(dim);
                    for (size_t j = 0; j < dim; j++)
                    {
                        Parameter *narg = Parameter::getNth(t->arguments, j);
                        assert(narg->ident);
                        VarDeclaration *v = sc2->search(Loc(), narg->ident, NULL)->isVarDeclaration();
                        assert(v);
                        Expression *e = new VarExp(v->loc, v);
                        (*exps)[j] = e;
                    }
                    assert(fparam->ident);
                    TupleDeclaration *v = new TupleDeclaration(loc, fparam->ident, exps);
                    //printf("declaring tuple %s\n", v->toChars());
                    v->isexp = true;
                    if (!sc2->insert(v))
                        error("parameter %s.%s is already defined", toChars(), v->toChars());
                    localsymtab->insert(v);
                    v->parent = this;
                }
            }
        }

        // Precondition invariant
        Statement *fpreinv = NULL;
        if (addPreInvariant())
        {
            Expression *e = addInvariant(sc, ad, vthis, isDtorDeclaration() != NULL);
            if (e)
                fpreinv = new ExpStatement(Loc(), e);
        }

        // Postcondition invariant
        Statement *fpostinv = NULL;
        if (addPostInvariant())
        {
            Expression *e = addInvariant(sc, ad, vthis, isCtorDeclaration() != NULL);
            if (e)
                fpostinv = new ExpStatement(Loc(), e);
        }

        Scope *scout = NULL;
        if (fensure || addPostInvariant())
        {
            if ((fensure && global.params.useOut) || fpostinv)
            {
                returnLabel = new LabelDsymbol(Id::returnLabel);
            }

            // scope of out contract (need for vresult->semantic)
            ScopeDsymbol *sym = new ScopeDsymbol();
            sym->parent = sc2->scopesym;
            scout = sc2->push(sym);
        }

        if (fbody)
        {
            ScopeDsymbol *sym = new ScopeDsymbol();
            sym->parent = sc2->scopesym;
            sc2 = sc2->push(sym);

            AggregateDeclaration *ad2 = isAggregateMember2();
            unsigned *fieldinit = NULL;

            /* If this is a class constructor
             */
            if (ad2 && isCtorDeclaration())
            {
                fieldinit = (unsigned *)mem.malloc(sizeof(unsigned) * ad2->fields.dim);
                sc2->fieldinit = fieldinit;
                sc2->fieldinit_dim = ad2->fields.dim;
                for (size_t i = 0; i < ad2->fields.dim; i++)
                {
                    VarDeclaration *v = ad2->fields[i];
                    v->ctorinit = 0;
                    sc2->fieldinit[i] = 0;
                }
            }

            if (!inferRetType && retStyle(f) != RETstack)
                nrvo_can = 0;

            bool inferRef = (f->isref && (storage_class & STCauto));

            fbody = fbody->semantic(sc2);
            if (!fbody)
                fbody = new CompoundStatement(Loc(), new Statements());

            assert(type == f);

            if (inferRetType)
            {
                // If no return type inferred yet, then infer a void
                if (!f->next)
                    f->next = Type::tvoid;
                if (f->checkRetType(loc))
                    fbody = new ErrorStatement();
            }
            if (returns && !fbody->isErrorStatement())
            {
                for (size_t i = 0; i < returns->dim; )
                {
                    Expression *exp = (*returns)[i]->exp;
                    if (exp->op == TOKvar && ((VarExp *)exp)->var == vresult)
                    {
                        exp->type = f->next;
                        // Remove `return vresult;` from returns
                        returns->remove(i);
                        continue;
                    }
                    if (inferRef && f->isref && !exp->type->constConv(f->next))     // Bugzilla 13336
                        f->isref = false;
                    i++;
                }
            }
            if (f->isref)   // Function returns a reference
            {
                if (storage_class & STCauto)
                    storage_class &= ~STCauto;
            }
            if (retStyle(f) != RETstack)
                nrvo_can = 0;

            if (fbody->isErrorStatement())
                ;
            else if (isStaticCtorDeclaration())
            {
                /* It's a static constructor. Ensure that all
                 * ctor consts were initialized.
                 */

                Dsymbol *p = toParent();
                ScopeDsymbol *pd = p->isScopeDsymbol();
                if (!pd)
                {
                    error("static constructor can only be member of struct/class/module, not %s %s", p->kind(), p->toChars());
                }
                else
                {
                    for (size_t i = 0; i < pd->members->dim; i++)
                    {
                        Dsymbol *s = (*pd->members)[i];
                        s->checkCtorConstInit();
                    }
                }
            }
            else if (ad2 && isCtorDeclaration())
            {
                ClassDeclaration *cd = ad2->isClassDeclaration();

                // Verify that all the ctorinit fields got initialized
                if (!(sc2->callSuper & CSXthis_ctor))
                {
                    for (size_t i = 0; i < ad2->fields.dim; i++)
                    {
                        VarDeclaration *v = ad2->fields[i];
                        if (v->ctorinit == 0)
                        {
                            /* Current bugs in the flow analysis:
                             * 1. union members should not produce error messages even if
                             *    not assigned to
                             * 2. structs should recognize delegating opAssign calls as well
                             *    as delegating calls to other constructors
                             */
                            if (v->isCtorinit() && !v->type->isMutable() && cd)
                                error("missing initializer for %s field %s", MODtoChars(v->type->mod), v->toChars());
                            else if (v->storage_class & STCnodefaultctor)
                                ::error(loc, "field %s must be initialized in constructor", v->toChars());
                            else if (v->type->needsNested())
                                ::error(loc, "field %s must be initialized in constructor, because it is nested struct", v->toChars());
                        }
                        else
                        {
                            bool mustInit = (v->storage_class & STCnodefaultctor ||
                                             v->type->needsNested());
                            if (mustInit && !(sc2->fieldinit[i] & CSXthis_ctor))
                            {
                                error("field %s must be initialized but skipped", v->toChars());
                            }
                        }
                    }
                }
                sc2->fieldinit = NULL;
                sc2->fieldinit_dim = 0;

                if (cd &&
                    !(sc2->callSuper & CSXany_ctor) &&
                    cd->baseClass && cd->baseClass->ctor)
                {
                    sc2->callSuper = 0;

                    // Insert implicit super() at start of fbody
                    if (!resolveFuncCall(Loc(), sc2, cd->baseClass->ctor, NULL, NULL, NULL, 1))
                    {
                        error("no match for implicit super() call in constructor");
                    }
                    else
                    {
                        Expression *e1 = new SuperExp(Loc());
                        Expression *e = new CallExp(Loc(), e1);
                        e = e->semantic(sc2);

                        Statement *s = new ExpStatement(Loc(), e);
                        fbody = new CompoundStatement(Loc(), s, fbody);
                    }
                }
                //printf("callSuper = x%x\n", sc2->callSuper);
            }

            int blockexit = BEnone;
            if (!fbody->isErrorStatement())
            {
                // Check for errors related to 'nothrow'.
                unsigned int nothrowErrors = global.errors;
                blockexit = fbody->blockExit(this, f->isnothrow);
                if (f->isnothrow && (global.errors != nothrowErrors))
                    ::error(loc, "%s '%s' is nothrow yet may throw", kind(), toPrettyChars());
                if (flags & FUNCFLAGnothrowInprocess)
                {
                    if (type == f) f = (TypeFunction *)f->copy();
                    f->isnothrow = !(blockexit & BEthrow);
                }
            }

            if (fbody->isErrorStatement())
                ;
            else if (ad2 && isCtorDeclaration())
            {
                /* Append:
                 *  return this;
                 * to function body
                 */
                if (blockexit & BEfallthru)
                {
                    Statement *s = new ReturnStatement(loc, NULL);
                    s = s->semantic(sc2);
                    fbody = new CompoundStatement(loc, fbody, s);
                }
            }
            else if (fes)
            {
                // For foreach(){} body, append a return 0;
                if (blockexit & BEfallthru)
                {
                    Expression *e = new IntegerExp(0);
                    Statement *s = new ReturnStatement(Loc(), e);
                    fbody = new CompoundStatement(Loc(), fbody, s);
                }
                assert(!returnLabel);
            }
            else
            {
                const bool inlineAsm = (hasReturnExp & 8) != 0;
                if ((blockexit & BEfallthru) && f->next->ty != Tvoid && !inlineAsm)
                {
                    Expression *e;
                    if (!hasReturnExp)
                        error("has no return statement, but is expected to return a value of type %s", f->next->toChars());
                    else
                        error("no return exp; or assert(0); at end of function");
                    if (global.params.useAssert &&
                        !global.params.useInline)
                    {
                        /* Add an assert(0, msg); where the missing return
                         * should be.
                         */
                        e = new AssertExp(
                              endloc,
                              new IntegerExp(0),
                              new StringExp(loc, (char *)"missing return expression")
                            );
                    }
                    else
                        e = new HaltExp(endloc);
                    e = new CommaExp(Loc(), e, f->next->defaultInit());
                    e = e->semantic(sc2);
                    Statement *s = new ExpStatement(Loc(), e);
                    fbody = new CompoundStatement(Loc(), fbody, s);
                }
            }

            if (returns && !fbody->isErrorStatement())
            {
                bool implicit0 = (f->next->ty == Tvoid && isMain());
                Type *tret = implicit0 ? Type::tint32 : f->next;
                assert(tret->ty != Tvoid);
                if (vresult || returnLabel)
                    buildResultVar(scout ? scout : sc2, tret);

                /* Cannot move this loop into NrvoWalker, because
                 * returns[i] may be in the nested delegate for foreach-body.
                 */
                for (size_t i = 0; i < returns->dim; i++)
                {
                    ReturnStatement *rs = (*returns)[i];
                    Expression *exp = rs->exp;

                    if (!exp->implicitConvTo(tret) &&
                        parametersIntersect(exp->type))
                    {
                        if (exp->type->immutableOf()->implicitConvTo(tret))
                            exp = exp->castTo(sc2, exp->type->immutableOf());
                        else if (exp->type->wildOf()->implicitConvTo(tret))
                            exp = exp->castTo(sc2, exp->type->wildOf());
                    }
                    exp = exp->implicitCastTo(sc2, tret);

                    if (f->isref)
                    {
                        // Function returns a reference
                        exp = exp->toLvalue(sc2, exp);
                        checkEscapeRef(sc2, exp, false);
                    }
                    else
                    {
                        exp = exp->optimize(WANTvalue);

                        /* Bugzilla 10789:
                         * If NRVO is not possible, all returned lvalues should call their postblits.
                         */
                        if (!nrvo_can && exp->isLvalue())
                            exp = callCpCtor(sc2, exp);

                        checkEscape(sc2, exp, false);
                    }

                    exp = checkGC(sc2, exp);

                    if (vresult)
                    {
                        // Create: return vresult = exp;
                        VarExp *ve = new VarExp(Loc(), vresult);
                        ve->type = vresult->type;
                        if (f->isref)
                            exp = new ConstructExp(rs->loc, ve, exp);
                        else
                            exp = new BlitExp(rs->loc, ve, exp);
                        exp->type = ve->type;

                        if (rs->caseDim)
                            exp = Expression::combine(exp, new IntegerExp(rs->caseDim));
                    }
                    else if (tintro && !tret->equals(tintro->nextOf()))
                    {
                        exp = exp->implicitCastTo(sc2, tintro->nextOf());
                    }
                    rs->exp = exp;
                }
            }
            if (nrvo_var || returnLabel)
            {
                NrvoWalker nw;
                nw.fd = this;
                nw.sc = sc2;
                nw.visitStmt(fbody);
            }

            if (fieldinit)
                mem.free(fieldinit);
            sc2 = sc2->pop();
        }

        Statement *freq = frequire;
        Statement *fens = fensure;

        /* Do the semantic analysis on the [in] preconditions and
         * [out] postconditions.
         */
        if (freq)
        {
            /* frequire is composed of the [in] contracts
             */
            ScopeDsymbol *sym = new ScopeDsymbol();
            sym->parent = sc2->scopesym;
            sc2 = sc2->push(sym);
            sc2->flags = (sc2->flags & ~SCOPEcontract) | SCOPErequire;

            // BUG: need to error if accessing out parameters
            // BUG: need to treat parameters as const
            // BUG: need to disallow returns and throws
            // BUG: verify that all in and ref parameters are read
            freq = freq->semantic(sc2);

            sc2 = sc2->pop();

            if (!global.params.useIn)
                freq = NULL;
        }

        if (fens)
        {
            /* fensure is composed of the [out] contracts
             */
            if (f->next->ty == Tvoid && outId)
                error("void functions have no result");

            if (fensure && f->next->ty != Tvoid)
                buildResultVar(scout, f->next);

            sc2 = scout;    //push
            sc2->flags = (sc2->flags & ~SCOPEcontract) | SCOPEensure;

            // BUG: need to treat parameters as const
            // BUG: need to disallow returns and throws
            if (inferRetType && fdensure && ((TypeFunction *)fdensure->type)->parameters)
            {
                // Return type was unknown in the first semantic pass
                Parameter *p = (*((TypeFunction *)fdensure->type)->parameters)[0];
                p->type = f->next;
            }
            fens = fens->semantic(sc2);

            sc2 = sc2->pop();

            if (!global.params.useOut)
                fens = NULL;
        }

        if (fbody && fbody->isErrorStatement())
            ;
        else
        {
            Statements *a = new Statements();

            // Merge in initialization of 'out' parameters
            if (parameters)
            {
                for (size_t i = 0; i < parameters->dim; i++)
                {
                    VarDeclaration *v = (*parameters)[i];
                    if (v->storage_class & STCout)
                    {
                        assert(v->init);
                        ExpInitializer *ie = v->init->isExpInitializer();
                        assert(ie);
                        if (ie->exp->op == TOKconstruct)
                            ie->exp->op = TOKassign; // construction occured in parameter processing
                        a->push(new ExpStatement(Loc(), ie->exp));
                    }
                }
            }

            if (argptr)
            {
                // Initialize _argptr
#ifdef IN_GCC
                // Handled in FuncDeclaration::toObjFile
                v_argptr = argptr;
                v_argptr->init = new VoidInitializer(loc);
#else
                Type *t = argptr->type;
                if (global.params.is64bit && !global.params.isWindows)
                {
                    // Initialize _argptr to point to v_argsave
                    Expression *e1 = new VarExp(Loc(), argptr);
                    Expression *e = new SymOffExp(Loc(), v_argsave, 6*8 + 8*16);
                    e->type = argptr->type;
                    e = new AssignExp(Loc(), e1, e);
                    e = e->semantic(sc);
                    a->push(new ExpStatement(Loc(), e));
                }
                else
                {
                    // Initialize _argptr to point past non-variadic arg
                    VarDeclaration *p;
                    unsigned offset = 0;
                    Expression *e;

                    Expression *e1 = new VarExp(Loc(), argptr);
                    // Find the last non-ref parameter
                    if (parameters && parameters->dim)
                    {
                        size_t lastNonref = parameters->dim -1;
                        p = (*parameters)[lastNonref];
                        /* The trouble with out and ref parameters is that taking
                         * the address of it doesn't work, because later processing
                         * adds in an extra level of indirection. So we skip over them.
                         */
                        while (p->storage_class & (STCout | STCref))
                        {
                            offset += Target::ptrsize;
                            if (lastNonref-- == 0)
                            {
                                p = v_arguments;
                                break;
                            }
                            p = (*parameters)[lastNonref];
                        }
                    }
                    else
                        p = v_arguments;            // last parameter is _arguments[]
                    if (global.params.is64bit && global.params.isWindows)
                    {
                        offset += Target::ptrsize;
                        if (p->storage_class & STClazy || p->type->size() > Target::ptrsize)
                        {
                            /* Necessary to offset the extra level of indirection the Win64
                             * ABI demands
                             */
                            e = new SymOffExp(Loc(),p,0);
                            e->type = Type::tvoidptr;
                            e = new AddrExp(Loc(), e);
                            e->type = Type::tvoidptr;
                            e = new AddExp(Loc(), e, new IntegerExp(offset));
                            e->type = Type::tvoidptr;
                            goto L1;
                        }
                    }
                    else if (p->storage_class & STClazy)
                    {
                        // If the last parameter is lazy, it's the size of a delegate
                        offset += Target::ptrsize * 2;
                    }
                    else
                        offset += p->type->size();
                    offset = (offset + Target::ptrsize - 1) & ~(Target::ptrsize - 1);  // assume stack aligns on pointer size
                    e = new SymOffExp(Loc(), p, offset);
                    e->type = Type::tvoidptr;
                    //e = e->semantic(sc);
                L1:
                    e = new AssignExp(Loc(), e1, e);
                    e->type = t;
                    a->push(new ExpStatement(Loc(), e));
                    p->isargptr = true;
                }
#endif
            }

            if (_arguments)
            {
#ifdef IN_GCC
                v_arguments_var = _arguments;
                v_arguments_var->init = new VoidInitializer(loc);
#endif
                /* Advance to elements[] member of TypeInfo_Tuple with:
                 *  _arguments = v_arguments.elements;
                 */
                Expression *e = new VarExp(Loc(), v_arguments);
                e = new DotIdExp(Loc(), e, Id::elements);
                Expression *e1 = new VarExp(Loc(), _arguments);
                e = new ConstructExp(Loc(), e1, e);
                e = e->semantic(sc2);
                a->push(new ExpStatement(Loc(), e));
            }

            // Merge contracts together with body into one compound statement

            if (freq || fpreinv)
            {
                if (!freq)
                    freq = fpreinv;
                else if (fpreinv)
                    freq = new CompoundStatement(Loc(), freq, fpreinv);

                a->push(freq);
            }

            if (fbody)
                a->push(fbody);

            if (fens || fpostinv)
            {
                if (!fens)
                    fens = fpostinv;
                else if (fpostinv)
                    fens = new CompoundStatement(Loc(), fpostinv, fens);

                LabelStatement *ls = new LabelStatement(Loc(), Id::returnLabel, fens);
                returnLabel->statement = ls;
                a->push(returnLabel->statement);

                if (f->next->ty != Tvoid && vresult)
                {
                    // Create: return vresult;
                    Expression *e = new VarExp(Loc(), vresult);
                    if (tintro)
                    {
                        e = e->implicitCastTo(sc, tintro->nextOf());
                        e = e->semantic(sc);
                    }
                    ReturnStatement *s = new ReturnStatement(Loc(), e);
                    a->push(s);
                }
            }
            if (isMain() && f->next->ty == Tvoid)
            {
                // Add a return 0; statement
                Statement *s = new ReturnStatement(Loc(), new IntegerExp(0));
                a->push(s);
            }

            Statement *sbody = new CompoundStatement(Loc(), a);
            /* Append destructor calls for parameters as finally blocks.
             */
            if (parameters)
            {
                for (size_t i = 0; i < parameters->dim; i++)
                {
                    VarDeclaration *v = (*parameters)[i];

                    if (v->storage_class & (STCref | STCout | STClazy))
                        continue;

                    if (v->noscope)
                        continue;

                    Expression *e = v->edtor;
                    if (e)
                    {
                        Statement *s = new ExpStatement(Loc(), e);
                        s = s->semantic(sc2);
                        unsigned int nothrowErrors = global.errors;
                        bool isnothrow = f->isnothrow & !(flags & FUNCFLAGnothrowInprocess);
                        int blockexit = s->blockExit(this, isnothrow);
                        if (f->isnothrow && (global.errors != nothrowErrors) )
                            ::error(loc, "%s '%s' is nothrow yet may throw", kind(), toPrettyChars());
                        if (flags & FUNCFLAGnothrowInprocess && blockexit & BEthrow)
                            f->isnothrow = false;
                        if (sbody->blockExit(this, f->isnothrow) == BEfallthru)
                            sbody = new CompoundStatement(Loc(), sbody, s);
                        else
                            sbody = new TryFinallyStatement(Loc(), sbody, s);
                    }
                }
            }
            // from this point on all possible 'throwers' are checked
            flags &= ~FUNCFLAGnothrowInprocess;

            if (isSynchronized())
            {
                /* Wrap the entire function body in a synchronized statement
                 */
                ClassDeclaration *cd = isThis() ? isThis()->isClassDeclaration() : parent->isClassDeclaration();

                if (cd)
                {
                    if (!global.params.is64bit &&
                        global.params.isWindows &&
                        !isStatic() && !sbody->usesEH() && !global.params.trace)
                    {
                        /* The back end uses the "jmonitor" hack for syncing;
                         * no need to do the sync at this level.
                         */
                    }
                    else
                    {
                        Expression *vsync;
                        if (isStatic())
                        {
                            // The monitor is in the ClassInfo
                            vsync = new DotIdExp(loc, new DsymbolExp(loc, cd), Id::classinfo);
                        }
                        else
                        {
                            // 'this' is the monitor
                            vsync = new VarExp(loc, vthis);
                        }
                        sbody = new PeelStatement(sbody);       // don't redo semantic()
                        sbody = new SynchronizedStatement(loc, vsync, sbody);
                        sbody = sbody->semantic(sc2);
                    }
                }
                else
                {
                    error("synchronized function %s must be a member of a class", toChars());
                }
            }

            // If declaration has no body, don't set sbody to prevent incorrect codegen.
            InterfaceDeclaration *id = parent->isInterfaceDeclaration();
            if (fbody || id && (fdensure || fdrequire) && isVirtual())
                fbody = sbody;
        }

        // Fix up forward-referenced gotos
        if (gotos)
        {
            for (size_t i = 0; i < gotos->dim; ++i)
            {
                (*gotos)[i]->checkLabel();
            }
        }

        if (naked && (fensure || frequire))
            error("naked assembly functions with contracts are not supported");

        sc2->callSuper = 0;
        sc2->pop();
    }

    if (needsClosure())
    {
        if (setGC())
            error("@nogc function allocates a closure with the GC");
        else
            printGCUsage(loc, "using closure causes GC allocation");
    }

    /* If function survived being marked as impure, then it is pure
     */
    if (flags & FUNCFLAGpurityInprocess)
    {
        flags &= ~FUNCFLAGpurityInprocess;
        if (type == f) f = (TypeFunction *)f->copy();
        f->purity = PUREfwdref;
    }

    if (flags & FUNCFLAGsafetyInprocess)
    {
        flags &= ~FUNCFLAGsafetyInprocess;
        if (type == f) f = (TypeFunction *)f->copy();
        f->trust = TRUSTsafe;
    }

    if (flags & FUNCFLAGnogcInprocess)
    {
        flags &= ~FUNCFLAGnogcInprocess;
        if (type == f) f = (TypeFunction *)f->copy();
        f->isnogc = true;
    }

    flags &= ~FUNCFLAGreturnInprocess;

    // reset deco to apply inference result to mangled name
    if (f != type)
        f->deco = NULL;

    // Do semantic type AFTER pure/nothrow inference.
    if (!f->deco && ident != Id::xopEquals && ident != Id::xopCmp)
    {
        sc = sc->push();
        sc->stc = 0;
        sc->linkage = linkage;  // Bugzilla 8496
        type = f->semantic(loc, sc);
        sc = sc->pop();
    }

    /* If this function had instantiated with gagging, error reproduction will be
     * done by TemplateInstance::semantic.
     * Otherwise, error gagging should be temporarily ungagged by functionSemantic3.
     */
    semanticRun = PASSsemantic3done;
    semantic3Errors = (global.errors != nerrors) || (fbody && fbody->isErrorStatement());
    if (type->ty == Terror)
        errors = true;
    //printf("-FuncDeclaration::semantic3('%s.%s', sc = %p, loc = %s)\n", parent->toChars(), toChars(), sc, loc.toChars());
    //fflush(stdout);
}

bool FuncDeclaration::functionSemantic()
{
    if (!scope)
        return true;

    if (!originalType)      // semantic not yet run
    {
        TemplateInstance *spec = isSpeculative();
        unsigned olderrs = global.errors;
        unsigned oldgag = global.gag;
        if (global.gag && !spec)
            global.gag = 0;
        semantic(scope);
        global.gag = oldgag;
        if (spec && global.errors != olderrs)
            spec->errors = (global.errors - olderrs != 0);
        if (olderrs != global.errors)   // if errors compiling this function
            return false;
    }

    // if inferring return type, sematic3 needs to be run
    if (inferRetType && type && !type->nextOf())
        return functionSemantic3();

    TemplateInstance *ti;
    if (isInstantiated() && !isVirtualMethod() &&
        !(ti = parent->isTemplateInstance(), ti && !ti->isTemplateMixin() && ti->tempdecl->ident != ident))
    {
        AggregateDeclaration *ad = isMember2();
        if (ad && ad->sizeok != SIZEOKdone)
        {
            /* Currently dmd cannot resolve forward references per methods,
             * then setting SIZOKfwd is too conservative and would break existing code.
             * So, just stop method attributes inference until ad->semantic() done.
             */
            //ad->sizeok = SIZEOKfwd;
        }
        else
            return functionSemantic3();
    }

    return true;
}

bool FuncDeclaration::functionSemantic3()
{
    if (semanticRun < PASSsemantic3 && scope)
    {
        /* Forward reference - we need to run semantic3 on this function.
         * If errors are gagged, and it's not part of a template instance,
         * we need to temporarily ungag errors.
         */
        TemplateInstance *spec = isSpeculative();
        unsigned olderrs = global.errors;
        unsigned oldgag = global.gag;
        if (global.gag && !spec)
            global.gag = 0;
        semantic3(scope);
        global.gag = oldgag;

        // If it is a speculatively-instantiated template, and errors occur,
        // we need to mark the template as having errors.
        if (spec && global.errors != olderrs)
            spec->errors = (global.errors - olderrs != 0);
        if (olderrs != global.errors)   // if errors compiling this function
            return false;
    }

    return true;
}

VarDeclaration *FuncDeclaration::declareThis(Scope *sc, AggregateDeclaration *ad)
{
    if (ad && !isFuncLiteralDeclaration())
    {
        VarDeclaration *v;
        {
            Type *thandle = ad->handleType();
            assert(thandle);
            thandle = thandle->addMod(type->mod);
            thandle = thandle->addStorageClass(storage_class);
            v = new ThisDeclaration(loc, thandle);
            v->storage_class |= STCparameter;
            if (thandle->ty == Tstruct)
            {
                v->storage_class |= STCref;

                // if member function is marked 'inout', then 'this' is 'return ref'
                if (type->ty == Tfunction && ((TypeFunction *)type)->iswild & 2)
                    v->storage_class |= STCreturn;
            }
            if (type->ty == Tfunction && ((TypeFunction *)type)->isreturn)
                v->storage_class |= STCreturn;

            v->semantic(sc);
            if (!sc->insert(v))
                assert(0);
            v->parent = this;
            return v;
        }
    }
    else if (isNested())
    {
        /* The 'this' for a nested function is the link to the
         * enclosing function's stack frame.
         * Note that nested functions and member functions are disjoint.
         */
        VarDeclaration *v = new ThisDeclaration(loc, Type::tvoid->pointerTo());
        v->storage_class |= STCparameter;
        v->semantic(sc);
        if (!sc->insert(v))
            assert(0);
        v->parent = this;
        return v;
    }

    return NULL;
}

bool FuncDeclaration::equals(RootObject *o)
{
    if (this == o)
        return true;

    Dsymbol *s = isDsymbol(o);
    if (s)
    {
        FuncDeclaration *fd1 = this;
        FuncDeclaration *fd2 = s->isFuncDeclaration();
        if (!fd2)
            return false;

        FuncAliasDeclaration *fa1 = fd1->isFuncAliasDeclaration();
        FuncAliasDeclaration *fa2 = fd2->isFuncAliasDeclaration();
        if (fa1 && fa2)
        {
            return fa1->toAliasFunc()->equals(fa2->toAliasFunc()) &&
                   fa1->hasOverloads == fa2->hasOverloads;
        }

        if (fa1 && (fd1 = fa1->toAliasFunc())->isUnique() && !fa1->hasOverloads)
            fa1 = NULL;
        if (fa2 && (fd2 = fa2->toAliasFunc())->isUnique() && !fa2->hasOverloads)
            fa2 = NULL;
        if ((fa1 != NULL) != (fa2 != NULL))
            return false;

        return fd1->toParent()->equals(fd2->toParent()) &&
            fd1->ident->equals(fd2->ident) && fd1->type->equals(fd2->type);
    }
    return false;
}

/****************************************************
 * Declare result variable lazily.
 */

void FuncDeclaration::buildResultVar(Scope *sc, Type *tret)
{
    if (!vresult)
    {
        Loc loc = fensure ? fensure->loc : this->loc;

        /* If inferRetType is true, tret may not be a correct return type yet.
         * So, in here it may be a temporary type for vresult, and after
         * fbody->semantic() running, vresult->type might be modified.
         */
        vresult = new VarDeclaration(loc, tret, outId ? outId : Id::result, NULL);
        vresult->noscope = true;

        if (outId == Id::result)
            vresult->storage_class |= STCtemp;
        if (!isVirtual())
            vresult->storage_class |= STCconst;
        vresult->storage_class |= STCresult;

        // set before the semantic() for checkNestedReference()
        vresult->parent = this;
    }

    if (sc && vresult->sem == SemanticStart)
    {
        assert(type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)type;
        if (tf->isref)
            vresult->storage_class |= STCref | STCforeach;
        vresult->type = tret;

        vresult->semantic(sc);

        if (!sc->insert(vresult))
            error("out result %s is already defined", vresult->toChars());
        assert(vresult->parent == this);
    }
}

/****************************************************
 * Merge into this function the 'in' contracts of all it overrides.
 * 'in's are OR'd together, i.e. only one of them needs to pass.
 */

Statement *FuncDeclaration::mergeFrequire(Statement *sf)
{
    /* If a base function and its override both have an IN contract, then
     * only one of them needs to succeed. This is done by generating:
     *
     * void derived.in() {
     *  try {
     *    base.in();
     *  }
     *  catch () {
     *    ... body of derived.in() ...
     *  }
     * }
     *
     * So if base.in() doesn't throw, derived.in() need not be executed, and the contract is valid.
     * If base.in() throws, then derived.in()'s body is executed.
     */

    /* Implementing this is done by having the overriding function call
     * nested functions (the fdrequire functions) nested inside the overridden
     * function. This requires that the stack layout of the calling function's
     * parameters and 'this' pointer be in the same place (as the nested
     * function refers to them).
     * This is easy for the parameters, as they are all on the stack in the same
     * place by definition, since it's an overriding function. The problem is
     * getting the 'this' pointer in the same place, since it is a local variable.
     * We did some hacks in the code generator to make this happen:
     *  1. always generate exception handler frame, or at least leave space for it
     *     in the frame (Windows 32 SEH only)
     *  2. always generate an EBP style frame
     *  3. since 'this' is passed in a register that is subsequently copied into
     *     a stack local, allocate that local immediately following the exception
     *     handler block, so it is always at the same offset from EBP.
     */
    for (size_t i = 0; i < foverrides.dim; i++)
    {
        FuncDeclaration *fdv = foverrides[i];

        /* The semantic pass on the contracts of the overridden functions must
         * be completed before code generation occurs (bug 3602).
         */
        if (fdv->fdrequire && fdv->fdrequire->semanticRun != PASSsemantic3done)
        {
            assert(fdv->scope);
            Scope *sc = fdv->scope->push();
            sc->stc &= ~STCoverride;
            fdv->semantic3(sc);
            sc->pop();
        }

        sf = fdv->mergeFrequire(sf);
        if (sf && fdv->fdrequire)
        {
            //printf("fdv->frequire: %s\n", fdv->frequire->toChars());
            /* Make the call:
             *   try { __require(); }
             *   catch { frequire; }
             */
            Expression *eresult = NULL;
            Expression *e = new CallExp(loc, new VarExp(loc, fdv->fdrequire, 0), eresult);
            Statement *s2 = new ExpStatement(loc, e);

            Catch *c = new Catch(loc, NULL, NULL, sf);
            c->internalCatch = true;
            Catches *catches = new Catches();
            catches->push(c);
            sf = new TryCatchStatement(loc, s2, catches);
        }
        else
            return NULL;
    }
    return sf;
}

/****************************************************
 * Merge into this function the 'out' contracts of all it overrides.
 * 'out's are AND'd together, i.e. all of them need to pass.
 */

Statement *FuncDeclaration::mergeFensure(Statement *sf, Identifier *oid)
{
    /* Same comments as for mergeFrequire(), except that we take care
     * of generating a consistent reference to the 'result' local by
     * explicitly passing 'result' to the nested function as a reference
     * argument.
     * This won't work for the 'this' parameter as it would require changing
     * the semantic code for the nested function so that it looks on the parameter
     * list for the 'this' pointer, something that would need an unknown amount
     * of tweaking of various parts of the compiler that I'd rather leave alone.
     */
    for (size_t i = 0; i < foverrides.dim; i++)
    {
        FuncDeclaration *fdv = foverrides[i];

        /* The semantic pass on the contracts of the overridden functions must
         * be completed before code generation occurs (bug 3602 and 5230).
         */
        if (fdv->fdensure && fdv->fdensure->semanticRun != PASSsemantic3done)
        {
            assert(fdv->scope);
            Scope *sc = fdv->scope->push();
            sc->stc &= ~STCoverride;
            fdv->semantic3(sc);
            sc->pop();
        }

        sf = fdv->mergeFensure(sf, oid);
        if (fdv->fdensure)
        {
            //printf("fdv->fensure: %s\n", fdv->fensure->toChars());
            // Make the call: __ensure(result)
            Expression *eresult = NULL;
            if (outId)
            {
                eresult = new IdentifierExp(loc, oid);

                Type *t1 = fdv->type->nextOf()->toBasetype();
                Type *t2 = this->type->nextOf()->toBasetype();
                if (t1->isBaseOf(t2, NULL))
                {
                    /* Making temporary reference variable is necessary
                     * in covariant return.
                     * See bugzilla 5204 and 10479.
                     */
                    ExpInitializer *ei = new ExpInitializer(Loc(), eresult);
                    VarDeclaration *v = new VarDeclaration(Loc(), t1, Identifier::generateId("__covres"), ei);
                    v->storage_class |= STCtemp;
                    DeclarationExp *de = new DeclarationExp(Loc(), v);
                    VarExp *ve = new VarExp(Loc(), v);
                    eresult = new CommaExp(Loc(), de, ve);
                }
            }
            Expression *e = new CallExp(loc, new VarExp(loc, fdv->fdensure, 0), eresult);
            Statement *s2 = new ExpStatement(loc, e);

            if (sf)
            {
                sf = new CompoundStatement(sf->loc, s2, sf);
            }
            else
                sf = s2;
        }
    }
    return sf;
}

/****************************************************
 * Determine if 'this' overrides fd.
 * Return !=0 if it does.
 */

int FuncDeclaration::overrides(FuncDeclaration *fd)
{   int result = 0;

    if (fd->ident == ident)
    {
        int cov = type->covariant(fd->type);
        if (cov)
        {   ClassDeclaration *cd1 = toParent()->isClassDeclaration();
            ClassDeclaration *cd2 = fd->toParent()->isClassDeclaration();

            if (cd1 && cd2 && cd2->isBaseOf(cd1, NULL))
                result = 1;
        }
    }
    return result;
}

/*************************************************
 * Find index of function in vtbl[0..dim] that
 * this function overrides.
 * Prefer an exact match to a covariant one.
 * Returns:
 *      -1      didn't find one
 *      -2      can't determine because of forward references
 */

int FuncDeclaration::findVtblIndex(Dsymbols *vtbl, int dim)
{
    FuncDeclaration *mismatch = NULL;
    StorageClass mismatchstc = 0;
    int mismatchvi = -1;
    int exactvi = -1;
    int bestvi = -1;
    for (int vi = 0; vi < dim; vi++)
    {
        FuncDeclaration *fdv = (*vtbl)[vi]->isFuncDeclaration();
        if (fdv && fdv->ident == ident)
        {
            if (type->equals(fdv->type))        // if exact match
            {
                if (fdv->parent->isClassDeclaration())
                    return vi;                  // no need to look further

                if (exactvi >= 0)
                {
                    error("cannot determine overridden function");
                    return exactvi;
                }
                exactvi = vi;

                bestvi = vi;
                continue;
            }

            StorageClass stc = 0;
            int cov = type->covariant(fdv->type, &stc);
            //printf("\tbaseclass cov = %d\n", cov);
            switch (cov)
            {
                case 0:         // types are distinct
                    break;

                case 1:
                    bestvi = vi;        // covariant, but not identical
                    break;              // keep looking for an exact match

                case 2:
                    mismatchvi = vi;
                    mismatchstc = stc;
                    mismatch = fdv;     // overrides, but is not covariant
                    break;              // keep looking for an exact match

                case 3:
                    return -2;  // forward references

                default:
                    assert(0);
            }
        }
    }
    if (bestvi == -1 && mismatch)
    {
        //type->print();
        //mismatch->type->print();
        //printf("%s %s\n", type->deco, mismatch->type->deco);
        //printf("stc = %llx\n", mismatchstc);
        if (mismatchstc)
        {   // Fix it by modifying the type to add the storage classes
            type = type->addStorageClass(mismatchstc);
            bestvi = mismatchvi;
        }
    }
    return bestvi;
}

/****************************************************
 * Overload this FuncDeclaration with the new one f.
 * Return true if successful; i.e. no conflict.
 */

bool FuncDeclaration::overloadInsert(Dsymbol *s)
{
    //printf("FuncDeclaration::overloadInsert(s = %s) this = %s\n", s->toChars(), toChars());
    assert(s != this);

    AliasDeclaration *ad = s->isAliasDeclaration();
    if (ad)
    {
        if (overnext)
            return overnext->overloadInsert(ad);
        if (!ad->aliassym && ad->type->ty != Tident && ad->type->ty != Tinstance)
        {
            //printf("\tad = '%s'\n", ad->type->toChars());
            return false;
        }
        overnext = ad;
        //printf("\ttrue: no conflict\n");
        return true;
    }
    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (td)
    {
        if (!td->funcroot)
            td->funcroot = this;
        if (overnext)
            return overnext->overloadInsert(td);
        overnext = td;
        return true;
    }
    FuncDeclaration *fd = s->isFuncDeclaration();
    if (!fd)
        return false;

#if 0
    /* Disable this check because:
     *  const void foo();
     * semantic() isn't run yet on foo(), so the const hasn't been
     * applied yet.
     */
    if (type)
    {   printf("type = %s\n", type->toChars());
        printf("fd->type = %s\n", fd->type->toChars());
    }
    // fd->type can be NULL for overloaded constructors
    if (type && fd->type &&
        fd->type->covariant(type) &&
        fd->type->mod == type->mod &&
        !isFuncAliasDeclaration())
    {
        //printf("\tfalse: conflict %s\n", kind());
        return false;
    }
#endif

    if (overnext)
    {
        td = overnext->isTemplateDeclaration();
        if (td)
            fd->overloadInsert(td);
        else
            return overnext->overloadInsert(fd);
    }
    overnext = fd;
    //printf("\ttrue: no conflict\n");
    return true;
}

/***************************************************
 * Visit each overloaded function/template in turn, and call
 * (*fp)(param, s) on it.
 * Exit when no more, or (*fp)(param, f) returns nonzero.
 * Returns:
 *      ==0     continue
 *      !=0     done
 */

int overloadApply(Dsymbol *fstart, void *param, int (*fp)(void *, Dsymbol *))
{
    Dsymbol *d;
    Dsymbol *next;
    for (d = fstart; d; d = next)
    {
        if (OverDeclaration *od = d->isOverDeclaration())
        {
            if (od->hasOverloads)
            {
                if (int r = overloadApply(od->aliassym, param, fp))
                    return r;
            }
            else
            {
                if (int r = (*fp)(param, od->aliassym))
                    return r;
            }
            next = od->overnext;
        }
        else if (FuncAliasDeclaration *fa = d->isFuncAliasDeclaration())
        {
            if (fa->hasOverloads)
            {
                if (int r = overloadApply(fa->funcalias, param, fp))
                    return r;
            }
            else
            {
                FuncDeclaration *fd = fa->toAliasFunc();
                if (!fd)
                {
                    d->error("is aliased to a function");
                    break;
                }
                if (int r = (*fp)(param, fd))
                    return r;
            }
            next = fa->overnext;
        }
        else if (AliasDeclaration *ad = d->isAliasDeclaration())
        {
            next = ad->toAlias();
            if (next == ad)
                break;
            if (next == fstart)
                break;
        }
        else if (TemplateDeclaration *td = d->isTemplateDeclaration())
        {
            if (int r = (*fp)(param, td))
                return r;
            next = td->overnext;
        }
        else
        {
            FuncDeclaration *fd = d->isFuncDeclaration();
            if (!fd)
            {
                d->error("is aliased to a function");
                break;              // BUG: should print error message?
            }
            if (int r = (*fp)(param, fd))
                return r;
            next = fd->overnext;
        }
    }
    return 0;
}

/********************************************
 * If there are no overloads of function f, return that function,
 * otherwise return NULL.
 */

FuncDeclaration *FuncDeclaration::isUnique()
{
  struct ParamUnique
  {
    static int fp(void *param, Dsymbol *s)
    {
        FuncDeclaration *f = s->isFuncDeclaration();
        if (!f)
            return 0;
        FuncDeclaration **pf = (FuncDeclaration **)param;

        if (*pf)
        {
            *pf = NULL;
            return 1;               // ambiguous, done
        }
        else
        {
            *pf = f;
            return 0;
        }
    }
  };
    FuncDeclaration *result = NULL;
    overloadApply(this, &result, &ParamUnique::fp);
    return result;
}

/********************************************
 * Find function in overload list that exactly matches t.
 */

FuncDeclaration *FuncDeclaration::overloadExactMatch(Type *t)
{
  struct ParamExact
  {
    Type *t;            // type to match
    FuncDeclaration *f; // return value

    static int fp(void *param, Dsymbol *s)
    {
        FuncDeclaration *f = s->isFuncDeclaration();
        if (!f)
            return 0;
        ParamExact *p = (ParamExact *)param;
        Type *t = p->t;

        if (t->equals(f->type))
        {
            p->f = f;
            return 1;
        }

        /* Allow covariant matches, as long as the return type
         * is just a const conversion.
         * This allows things like pure functions to match with an impure function type.
         */
        if (t->ty == Tfunction)
        {   TypeFunction *tf = (TypeFunction *)f->type;
            if (tf->covariant(t) == 1 &&
                tf->nextOf()->implicitConvTo(t->nextOf()) >= MATCHconst)
            {
                p->f = f;
                return 1;
            }
        }
        return 0;
    }
  };
    ParamExact p;
    p.t = t;
    p.f = NULL;
    overloadApply(this, &p, &ParamExact::fp);
    return p.f;
}

static void MODMatchToBuffer(OutBuffer *buf, unsigned char lhsMod, unsigned char rhsMod)
{
    bool bothMutable = ((lhsMod & rhsMod) == 0);
    bool sharedMismatch = ((lhsMod ^ rhsMod) & MODshared) != 0;
    bool sharedMismatchOnly = ((lhsMod ^ rhsMod) == MODshared);

    if (lhsMod & MODshared)
        buf->writestring("shared ");
    else if (sharedMismatch && !(lhsMod & MODimmutable))
        buf->writestring("non-shared ");

    if (bothMutable && sharedMismatchOnly)
    { }
    else if (lhsMod & MODimmutable)
        buf->writestring("immutable ");
    else if (lhsMod & MODconst)
        buf->writestring("const ");
    else if (lhsMod & MODwild)
        buf->writestring("inout ");
    else
        buf->writestring("mutable ");
}

/********************************************
 * Returns true if function was declared
 * directly or indirectly in a unittest block
 */
bool FuncDeclaration::inUnittest()
{
    Dsymbol *f = this;
    do
    {
        if (f->isUnitTestDeclaration())
            return true;
        f = f->toParent();
    } while (f);

    return false;
}

/********************************************
 * find function template root in overload list
 */

TemplateDeclaration *FuncDeclaration::findTemplateDeclRoot()
{
    FuncDeclaration *f = this;
    while (f && f->overnext)
    {
        //printf("f->overnext = %p %s\n", f->overnext, f->overnext->toChars());
        TemplateDeclaration *td = f->overnext->isTemplateDeclaration();
        if (td)
            return td;
        f = f->overnext->isFuncDeclaration();
    }
    return NULL;
}

/*************************************
 * Determine partial specialization order of 'this' vs g.
 * This is very similar to TemplateDeclaration::leastAsSpecialized().
 * Returns:
 *      match   'this' is at least as specialized as g
 *      0       g is more specialized than 'this'
 */

MATCH FuncDeclaration::leastAsSpecialized(FuncDeclaration *g)
{
#define LOG_LEASTAS     0

#if LOG_LEASTAS
    printf("%s.leastAsSpecialized(%s)\n", toChars(), g->toChars());
    printf("%s, %s\n", type->toChars(), g->type->toChars());
#endif

    /* This works by calling g() with f()'s parameters, and
     * if that is possible, then f() is at least as specialized
     * as g() is.
     */

    TypeFunction *tf = (TypeFunction *)type;
    TypeFunction *tg = (TypeFunction *)g->type;
    size_t nfparams = Parameter::dim(tf->parameters);

    /* If both functions have a 'this' pointer, and the mods are not
     * the same and g's is not const, then this is less specialized.
     */
    if (needThis() && g->needThis() && tf->mod != tg->mod)
    {
        if (isCtorDeclaration())
        {
            if (!MODimplicitConv(tg->mod, tf->mod))
                return MATCHnomatch;
        }
        else
        {
            if (!MODimplicitConv(tf->mod, tg->mod))
                return MATCHnomatch;
        }
    }

    /* Create a dummy array of arguments out of the parameters to f()
     */
    Expressions args;
    args.setDim(nfparams);
    for (size_t u = 0; u < nfparams; u++)
    {
        Parameter *p = Parameter::getNth(tf->parameters, u);
        Expression *e;
        if (p->storageClass & (STCref | STCout))
        {
            e = new IdentifierExp(Loc(), p->ident);
            e->type = p->type;
        }
        else
            e = p->type->defaultInitLiteral(Loc());
        args[u] = e;
    }

    MATCH m = (MATCH) tg->callMatch(NULL, &args, 1);
    if (m > MATCHnomatch)
    {
        /* A variadic parameter list is less specialized than a
         * non-variadic one.
         */
        if (tf->varargs && !tg->varargs)
            goto L1;    // less specialized

#if LOG_LEASTAS
        printf("  matches %d, so is least as specialized\n", m);
#endif
        return m;
    }
  L1:
#if LOG_LEASTAS
    printf("  doesn't match, so is not as specialized\n");
#endif
    return MATCHnomatch;
}

/// Walk through candidate template overloads and print them in the diagnostics.
struct TemplateCandidateWalker
{
    Loc loc;
    int numToDisplay;  // max num of overloads to print (-v overrides this).

    /// Count template overloads.
    struct CountWalker
    {
        int numOverloads;

        static int fp(void *param, Dsymbol *s)
        {
            CountWalker *p = (CountWalker *)param;
            ++(p->numOverloads);
            return 0;
        }
    };

    static int fp(void *param, Dsymbol *s)
    {
        TemplateDeclaration *t = s->isTemplateDeclaration();
        if (!t) return 0;

        TemplateCandidateWalker *p = (TemplateCandidateWalker *)param;

        ::errorSupplemental(t->loc, "%s", t->toPrettyChars());

        if (!global.params.verbose && --(p->numToDisplay) == 0 && t->overnext)
        {
            // Too many overloads to sensibly display.
            // Just show count of remaining overloads.
            CountWalker cw;
            cw.numOverloads = 0;
            overloadApply(t->overnext, &cw, &CountWalker::fp);

            if (cw.numOverloads > 0)
                ::errorSupplemental(p->loc, "... (%d more, -v to show) ...", cw.numOverloads);

            return 1;  // stop iterating
        }

        return 0;
    }
};

/// Walk through candidate template overloads and print them in the diagnostics.
struct FuncCandidateWalker
{
    Loc loc;
    int numToDisplay;  // max num of overloads to print (-v overrides this).

    /// Count function overloads.
    struct CountWalker
    {
        int numOverloads;

        static int fp(void *param, Dsymbol *s)
        {
            CountWalker *p = (CountWalker *)param;

            if (s->isFuncDeclaration())
                ++(p->numOverloads);

            return 0;
        }
    };

    static int fp(void *param, Dsymbol *s)
    {
        FuncDeclaration *f = s->isFuncDeclaration();
        if (!f || f->errors || f->type->ty == Terror)
            return 0;

        FuncCandidateWalker *p = (FuncCandidateWalker *)param;
        TypeFunction *tf = (TypeFunction *)f->type;

        ::errorSupplemental(f->loc, "%s%s", f->toPrettyChars(),
            parametersTypeToChars(tf->parameters, tf->varargs));

        if (!global.params.verbose && --(p->numToDisplay) == 0 && f->overnext)
        {
            CountWalker cw;
            cw.numOverloads = 0;
            overloadApply(f->overnext, &cw, &CountWalker::fp);

            if (cw.numOverloads > 0)
                ::errorSupplemental(p->loc, "... (%d more, -v to show) ...", cw.numOverloads);

            return 1;  // stop iterating
        }

        return 0;
    }
};

/*******************************************
 * Given a symbol that could be either a FuncDeclaration or
 * a function template, resolve it to a function symbol.
 *      loc             instantiation location
 *      sc              instantiation scope
 *      tiargs          initial list of template arguments
 *      tthis           if !NULL, the 'this' pointer argument
 *      fargs           arguments to function
 *      flags           1: do not issue error message on no match, just return NULL
 *                      2: overloadResolve only
 */

FuncDeclaration *resolveFuncCall(Loc loc, Scope *sc, Dsymbol *s,
        Objects *tiargs,
        Type *tthis,
        Expressions *fargs,
        int flags)
{
    if (!s)
        return NULL;                    // no match

#if 0
    printf("resolveFuncCall('%s')\n", s->toChars());
    if (fargs)
    {
        for (size_t i = 0; i < fargs->dim; i++)
        {
            Expression *arg = (*fargs)[i];
            assert(arg->type);
            printf("\t%s: ", arg->toChars());
            arg->type->print();
        }
    }
#endif

    if (tiargs && arrayObjectIsError(tiargs) ||
        fargs  && arrayObjectIsError((Objects *)fargs))
    {
        return NULL;
    }

    Match m;
    memset(&m, 0, sizeof(m));
    m.last = MATCHnomatch;

    functionResolve(&m, s, loc, sc, tiargs, tthis, fargs);

    if (m.last > MATCHnomatch && m.lastf)
    {
        if (m.count == 1)   // exactly one match
        {
            if (!(flags & 1))
                m.lastf->functionSemantic();
            return m.lastf;
        }
        if ((flags & 2) && !tthis && m.lastf->needThis())
        {
            return m.lastf;
        }
    }

    /* Failed to find a best match.
     * Do nothing or print error.
     */
    if (m.last <= MATCHnomatch)
    {
        // error was caused on matched function
        if (m.count == 1)
            return m.lastf;

        // if do not print error messages
        if (flags & 1)
            return NULL;    // no match
    }

    FuncDeclaration *fd = s->isFuncDeclaration();
    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (td && td->funcroot)
        s = fd = td->funcroot;

    OutBuffer tiargsBuf;
    arrayObjectsToBuffer(&tiargsBuf, tiargs);

    OutBuffer fargsBuf;
    fargsBuf.writeByte('(');
    argExpTypesToCBuffer(&fargsBuf, fargs);
    fargsBuf.writeByte(')');
    if (tthis)
        tthis->modToBuffer(&fargsBuf);

    const int numOverloadsDisplay = 5; // sensible number to display

    if (!m.lastf && !(flags & 1))   // no match
    {
        if (td && !fd)  // all of overloads are templates
        {
            ::error(loc, "%s %s.%s cannot deduce function from argument types !(%s)%s, candidates are:",
                    td->kind(), td->parent->toPrettyChars(), td->ident->toChars(),
                    tiargsBuf.peekString(), fargsBuf.peekString());

            // Display candidate templates (even if there are no multiple overloads)
            TemplateCandidateWalker tcw;
            tcw.loc = loc;
            tcw.numToDisplay = numOverloadsDisplay;
            overloadApply(td, &tcw, &TemplateCandidateWalker::fp);
        }
        else
        {
            assert(fd);

            bool hasOverloads = fd->overnext != NULL;
            TypeFunction *tf = (TypeFunction *)fd->type;
            if (tthis && !MODimplicitConv(tthis->mod, tf->mod)) // modifier mismatch
            {
                OutBuffer thisBuf, funcBuf;
                MODMatchToBuffer(&thisBuf, tthis->mod, tf->mod);
                MODMatchToBuffer(&funcBuf, tf->mod, tthis->mod);
                if (hasOverloads)
                    ::error(loc, "None of the overloads of '%s' are callable using a %sobject, candidates are:",
                        fd->ident->toChars(), thisBuf.peekString());
                else
                    ::error(loc, "%smethod %s is not callable using a %sobject",
                        funcBuf.peekString(), fd->toPrettyChars(), thisBuf.peekString());
            }
            else
            {
                //printf("tf = %s, args = %s\n", tf->deco, (*fargs)[0]->type->deco);
                if (hasOverloads)
                    ::error(loc, "None of the overloads of '%s' are callable using argument types %s, candidates are:",
                            fd->ident->toChars(), fargsBuf.peekString());
                else
                    fd->error(loc, "%s%s is not callable using argument types %s",
                        parametersTypeToChars(tf->parameters, tf->varargs),
                        tf->modToChars(),
                        fargsBuf.peekString());
            }

            // Display candidate functions
            if (hasOverloads)
            {
                FuncCandidateWalker fcw;
                fcw.loc = loc;
                fcw.numToDisplay = numOverloadsDisplay;
                overloadApply(fd, &fcw, &FuncCandidateWalker::fp);
            }
        }
    }
    else if (m.nextf)
    {
        TypeFunction *tf1 = (TypeFunction *)m.lastf->type;
        TypeFunction *tf2 = (TypeFunction *)m.nextf->type;
        const char *lastprms = parametersTypeToChars(tf1->parameters, tf1->varargs);
        const char *nextprms = parametersTypeToChars(tf2->parameters, tf2->varargs);
        ::error(loc, "%s.%s called with argument types %s matches both:\n"
                     "%s:     %s%s\nand:\n%s:     %s%s",
                s->parent->toPrettyChars(), s->ident->toChars(),
                fargsBuf.peekString(),
                m.lastf->loc.toChars(), m.lastf->toPrettyChars(), lastprms,
                m.nextf->loc.toChars(), m.nextf->toPrettyChars(), nextprms);
    }
    return NULL;
}

/********************************
 * Labels are in a separate scope, one per function.
 */

LabelDsymbol *FuncDeclaration::searchLabel(Identifier *ident)
{   Dsymbol *s;

    if (!labtab)
        labtab = new DsymbolTable();    // guess we need one

    s = labtab->lookup(ident);
    if (!s)
    {
        s = new LabelDsymbol(ident);
        labtab->insert(s);
    }
    return (LabelDsymbol *)s;
}

/****************************************
 * If non-static member function that has a 'this' pointer,
 * return the aggregate it is a member of.
 * Otherwise, return NULL.
 */

AggregateDeclaration *FuncDeclaration::isThis()
{
    //printf("+FuncDeclaration::isThis() '%s'\n", toChars());
    AggregateDeclaration *ad = NULL;
    if ((storage_class & STCstatic) == 0 && !isFuncLiteralDeclaration())
    {
        ad = isMember2();
    }
    //printf("-FuncDeclaration::isThis() %p\n", ad);
    return ad;
}

AggregateDeclaration *FuncDeclaration::isMember2()
{
    //printf("+FuncDeclaration::isMember2() '%s'\n", toChars());
    AggregateDeclaration *ad = NULL;
    for (Dsymbol *s = this; s; s = s->parent)
    {
        //printf("\ts = '%s', parent = '%s', kind = %s\n", s->toChars(), s->parent->toChars(), s->parent->kind());
        ad = s->isMember();
        if (ad)
        {
            break;
        }
        if (!s->parent ||
            (!s->parent->isTemplateInstance()))
        {
            break;
        }
    }
    //printf("-FuncDeclaration::isMember2() %p\n", ad);
    return ad;
}

/*****************************************
 * Determine lexical level difference from 'this' to nested function 'fd'.
 * Error if this cannot call fd.
 * Returns:
 *      0       same level
 *      >0      decrease nesting by number
 *      -1      increase nesting by 1 (fd is nested within 'this')
 *      -2      error
 */

int FuncDeclaration::getLevel(Loc loc, Scope *sc, FuncDeclaration *fd)
{
    int level;
    Dsymbol *s;
    Dsymbol *fdparent;

    //printf("FuncDeclaration::getLevel(fd = '%s')\n", fd->toChars());
    fdparent = fd->toParent2();
    if (fdparent == this)
        return -1;
    s = this;
    level = 0;
    while (fd != s && fdparent != s->toParent2())
    {
        //printf("\ts = %s, '%s'\n", s->kind(), s->toChars());
        FuncDeclaration *thisfd = s->isFuncDeclaration();
        if (thisfd)
        {
            if (!thisfd->isNested() && !thisfd->vthis && !sc->intypeof)
                goto Lerr;
        }
        else
        {
            AggregateDeclaration *thiscd = s->isAggregateDeclaration();
            if (thiscd)
            {
                /* AggregateDeclaration::isNested returns true only when
                 * it has a hidden pointer.
                 * But, calling the function belongs unrelated lexical scope
                 * is still allowed inside typeof.
                 *
                 * struct Map(alias fun) {
                 *   typeof({ return fun(); }) RetType;
                 *   // No member function makes Map struct 'not nested'.
                 * }
                 */
                if (!thiscd->isNested() && !sc->intypeof)
                    goto Lerr;
            }
            else
                goto Lerr;
        }

        s = s->toParent2();
        assert(s);
        level++;
    }
    return level;

Lerr:
    // Don't give error if in template constraint
    if (!(sc->flags & SCOPEconstraint))
    {
        const char *xstatic = isStatic() ? "static " : "";
        // better diagnostics for static functions
        ::error(loc, "%s%s %s cannot access frame of function %s",
            xstatic, kind(), toPrettyChars(), fd->toPrettyChars());
        return -2;
    }
    return 1;
}

const char *FuncDeclaration::toPrettyChars(bool QualifyTypes)
{
    if (isMain())
        return "D main";
    else
        return Dsymbol::toPrettyChars(QualifyTypes);
}

/** for diagnostics, e.g. 'int foo(int x, int y) pure' */
const char *FuncDeclaration::toFullSignature()
{
    OutBuffer buf;
    functionToBufferWithIdent((TypeFunction *)type, &buf, toChars());
    return buf.extractString();
}

bool FuncDeclaration::isMain()
{
    return ident == Id::main &&
        linkage != LINKc && !isMember() && !isNested();
}

bool FuncDeclaration::isWinMain()
{
    //printf("FuncDeclaration::isWinMain() %s\n", toChars());
#if 0
    bool x = ident == Id::WinMain &&
        linkage != LINKc && !isMember();
    printf("%s\n", x ? "yes" : "no");
    return x;
#else
    return ident == Id::WinMain &&
        linkage != LINKc && !isMember();
#endif
}

bool FuncDeclaration::isDllMain()
{
    return ident == Id::DllMain &&
        linkage != LINKc && !isMember();
}

bool FuncDeclaration::isExport()
{
    return protection.kind == PROTexport;
}

bool FuncDeclaration::isImportedSymbol()
{
    //printf("isImportedSymbol()\n");
    //printf("protection = %d\n", protection);
    return (protection.kind == PROTexport) && !fbody;
}

// Determine if function goes into virtual function pointer table

bool FuncDeclaration::isVirtual()
{
    if (toAliasFunc() != this)
        return toAliasFunc()->isVirtual();

    Dsymbol *p = toParent();
#if 0
    printf("FuncDeclaration::isVirtual(%s)\n", toChars());
    printf("isMember:%p isStatic:%d private:%d ctor:%d !Dlinkage:%d\n", isMember(), isStatic(), protection == PROTprivate, isCtorDeclaration(), linkage != LINKd);
    printf("result is %d\n",
        isMember() &&
        !(isStatic() || protection == PROTprivate || protection == PROTpackage) &&
        p->isClassDeclaration() &&
        !(p->isInterfaceDeclaration() && isFinalFunc()));
#endif
    return isMember() &&
        !(isStatic() || protection.kind == PROTprivate || protection.kind == PROTpackage) &&
        p->isClassDeclaration() &&
        !(p->isInterfaceDeclaration() && isFinalFunc());
}

// Determine if a function is pedantically virtual

bool FuncDeclaration::isVirtualMethod()
{
    if (toAliasFunc() != this)
        return toAliasFunc()->isVirtualMethod();

    //printf("FuncDeclaration::isVirtualMethod() %s\n", toChars());
    if (!isVirtual())
        return false;
    // If it's a final method, and does not override anything, then it is not virtual
    if (isFinalFunc() && foverrides.dim == 0)
    {
        return false;
    }
    return true;
}

bool FuncDeclaration::isFinalFunc()
{
    if (toAliasFunc() != this)
        return toAliasFunc()->isFinalFunc();

    ClassDeclaration *cd;
#if 0
    printf("FuncDeclaration::isFinalFunc(%s), %x\n", toChars(), Declaration::isFinal());
    printf("%p %d %d %d\n", isMember(), isStatic(), Declaration::isFinal(), ((cd = toParent()->isClassDeclaration()) != NULL && cd->storage_class & STCfinal));
    printf("result is %d\n",
        isMember() &&
        (Declaration::isFinal() ||
         ((cd = toParent()->isClassDeclaration()) != NULL && cd->storage_class & STCfinal)));
    if (cd)
        printf("\tmember of %s\n", cd->toChars());
#endif
    return isMember() &&
        (Declaration::isFinal() ||
         ((cd = toParent()->isClassDeclaration()) != NULL && cd->storage_class & STCfinal));
}

bool FuncDeclaration::isCodeseg()
{
    return true;                // functions are always in the code segment
}

bool FuncDeclaration::isOverloadable()
{
    return true;                // functions can be overloaded
}

bool FuncDeclaration::hasOverloads()
{
    return overnext != NULL;
}

PURE FuncDeclaration::isPure()
{
    //printf("FuncDeclaration::isPure() '%s'\n", toChars());
    assert(type->ty == Tfunction);
    TypeFunction *tf = (TypeFunction *)type;
    if (flags & FUNCFLAGpurityInprocess)
        setImpure();
    if (tf->purity == PUREfwdref)
        tf->purityLevel();
    PURE purity = tf->purity;
    if (purity > PUREweak && isNested())
        purity = PUREweak;
    if (purity > PUREweak && needThis())
    {   // The attribute of the 'this' reference affects purity strength
        if (type->mod & MODimmutable)
            ;
        else if (type->mod & (MODconst | MODwild) && purity >= PUREconst)
            purity = PUREconst;
        else
            purity = PUREweak;
    }
    tf->purity = purity;
    // ^ This rely on the current situation that every FuncDeclaration has a
    //   unique TypeFunction.
    return purity;
}

PURE FuncDeclaration::isPureBypassingInference()
{
    if (flags & FUNCFLAGpurityInprocess)
        return PUREfwdref;
    else
        return isPure();
}

bool FuncDeclaration::isPureBypassingInferenceX()
{
    return !(flags & FUNCFLAGpurityInprocess) && isPure() != PUREimpure;
}

/**************************************
 * The function is doing something impure,
 * so mark it as impure.
 * If there's a purity error, return true.
 */
bool FuncDeclaration::setImpure()
{
    if (flags & FUNCFLAGpurityInprocess)
    {
        flags &= ~FUNCFLAGpurityInprocess;
        if (fes)
            fes->func->setImpure();
    }
    else if (isPure())
        return true;
    return false;
}

bool FuncDeclaration::isSafe()
{
    assert(type->ty == Tfunction);
    if (flags & FUNCFLAGsafetyInprocess)
        setUnsafe();
    return ((TypeFunction *)type)->trust == TRUSTsafe;
}

bool FuncDeclaration::isSafeBypassingInference()
{
    return !(flags & FUNCFLAGsafetyInprocess) && isSafe();
}

bool FuncDeclaration::isTrusted()
{
    assert(type->ty == Tfunction);
    if (flags & FUNCFLAGsafetyInprocess)
        setUnsafe();
    return ((TypeFunction *)type)->trust == TRUSTtrusted;
}

/**************************************
 * The function is doing something unsave,
 * so mark it as unsafe.
 * If there's a safe error, return true.
 */
bool FuncDeclaration::setUnsafe()
{
    if (flags & FUNCFLAGsafetyInprocess)
    {
        flags &= ~FUNCFLAGsafetyInprocess;
        ((TypeFunction *)type)->trust = TRUSTsystem;
        if (fes)
            fes->func->setUnsafe();
    }
    else if (isSafe())
        return true;
    return false;
}

bool FuncDeclaration::isNogc()
{
    assert(type->ty == Tfunction);
    if (flags & FUNCFLAGnogcInprocess)
        setGC();
    return ((TypeFunction *)type)->isnogc;
}

bool FuncDeclaration::isNogcBypassingInference()
{
    return !(flags & FUNCFLAGnogcInprocess) && isNogc();
}

/**************************************
 * The function is doing something that may allocate with the GC,
 * so mark it as not nogc (not no-how).
 * Returns:
 *      true if function is marked as @nogc, meaning a user error occurred
 */
bool FuncDeclaration::setGC()
{
    if (flags & FUNCFLAGnogcInprocess)
    {
        flags &= ~FUNCFLAGnogcInprocess;
        ((TypeFunction *)type)->isnogc = false;
        if (fes)
            fes->func->setGC();
    }
    else if (isNogc())
        return true;
    return false;
}

/**************************************
 * Returns an indirect type one step from t.
 */

Type *getIndirection(Type *t)
{
    t = t->baseElemOf();
    if (t->ty == Tarray || t->ty == Tpointer)
        return t->nextOf()->toBasetype();
    if (t->ty == Taarray || t->ty == Tclass)
        return t;
    if (t->ty == Tstruct)
        return t->hasPointers() ? t : NULL; // TODO

    // should consider TypeDelegate?
    return NULL;
}

/**************************************
 * Returns true if memory reachable through a reference B to a value of type tb,
 * which has been constructed with a reference A to a value of type ta
 * available, can alias memory reachable from A based on the types involved
 * (either directly or via any number of indirections).
 *
 * Note that this relation is not symmetric in the two arguments. For example,
 * a const(int) reference can point to a pre-existing int, but not the other
 * way round.
 */
bool traverseIndirections(Type *ta, Type *tb, void *p = NULL, bool reversePass = false)
{
    Type *source = ta;
    Type *target = tb;
    if (reversePass)
    {
        source = tb;
        target = ta;
    }

    if (source->constConv(target))
        return true;
    else if (target->ty == Tvoid && MODimplicitConv(source->mod, target->mod))
        return true;

    // No direct match, so try breaking up one of the types (starting with tb).
    Type *tbb = tb->toBasetype()->baseElemOf();
    if (tbb != tb)
        return traverseIndirections(ta, tbb, p, reversePass);

    // context date to detect circular look up
    struct Ctxt
    {
        Ctxt *prev;
        Type *type;
    };
    Ctxt *ctxt = (Ctxt *)p;

    if (tb->ty == Tclass || tb->ty == Tstruct)
    {
        for (Ctxt *c = ctxt; c; c = c->prev)
            if (tb == c->type) return false;
        Ctxt c;
        c.prev = ctxt;
        c.type = tb;

        AggregateDeclaration *sym = tb->toDsymbol(NULL)->isAggregateDeclaration();
        for (size_t i = 0; i < sym->fields.dim; i++)
        {
            VarDeclaration *v = sym->fields[i];
            Type *tprmi = v->type->addMod(tb->mod);
            //printf("\ttb = %s, tprmi = %s\n", tb->toChars(), tprmi->toChars());
            if (traverseIndirections(ta, tprmi, &c, reversePass))
                return true;
        }
    }
    else if (tb->ty == Tarray || tb->ty == Taarray || tb->ty == Tpointer)
    {
        Type *tind = tb->nextOf();
        if (traverseIndirections(ta, tind, ctxt, reversePass))
            return true;
    }
    else if (tb->hasPointers())
    {
        // FIXME: function pointer/delegate types should be considered.
        return true;
    }

    // Still no match, so try breaking up ta if we have note done so yet.
    if (!reversePass)
        return traverseIndirections(tb, ta, ctxt, true);

    return false;
}

/********************************************
 * Returns true if the function return value has no indirection
 * which comes from the parameters.
 */

bool FuncDeclaration::isolateReturn()
{
    assert(type->ty == Tfunction);
    TypeFunction *tf = (TypeFunction *)type;
    assert(tf->next);

    Type *treti = tf->next;
    treti = tf->isref ? treti : getIndirection(treti);
    if (!treti)
        return true;    // target has no mutable indirection
    return parametersIntersect(treti);
}

/********************************************
 * Returns true if an object typed t can have indirections
 * which come from the parameters.
 */

bool FuncDeclaration::parametersIntersect(Type *t)
{
    assert(t);
    if (!isPureBypassingInference() || isNested())
        return false;

    assert(type->ty == Tfunction);
    TypeFunction *tf = (TypeFunction *)type;

    //printf("parametersIntersect(%s) t = %s\n", tf->toChars(), t->toChars());

    size_t dim = Parameter::dim(tf->parameters);
    for (size_t i = 0; i < dim; i++)
    {
        Parameter *fparam = Parameter::getNth(tf->parameters, i);
        if (!fparam->type)
            continue;
        Type *tprmi = (fparam->storageClass & (STClazy | STCout | STCref))
                ? fparam->type : getIndirection(fparam->type);
        if (!tprmi)
            continue;   // there is no mutable indirection

        //printf("\t[%d] tprmi = %d %s\n", i, tprmi->ty, tprmi->toChars());
        if (traverseIndirections(tprmi, t))
            return false;
    }
    if (AggregateDeclaration *ad = isCtorDeclaration() ? NULL : isThis())
    {
        Type *tthis = ad->getType()->addMod(tf->mod);
        //printf("\ttthis = %s\n", tthis->toChars());
        if (traverseIndirections(tthis, t))
            return false;
    }

    return true;
}

// Determine if function needs
// a static frame pointer to its lexically enclosing function

bool FuncDeclaration::isNested()
{
    FuncDeclaration *f = toAliasFunc();
    //printf("\ttoParent2() = '%s'\n", f->toParent2()->toChars());
    return ((f->storage_class & STCstatic) == 0) &&
           (f->linkage == LINKd) &&
           (f->toParent2()->isFuncDeclaration() != NULL);
}

bool FuncDeclaration::needThis()
{
    //printf("FuncDeclaration::needThis() '%s'\n", toChars());
    return toAliasFunc()->isThis() != NULL;
}

bool FuncDeclaration::addPreInvariant()
{
    AggregateDeclaration *ad = isThis();
    ClassDeclaration *cd = ad ? ad->isClassDeclaration() : NULL;
    return (ad && !(cd && cd->isCPPclass()) &&
            global.params.useInvariants &&
            (protection.kind == PROTprotected || protection.kind == PROTpublic || protection.kind == PROTexport) &&
            !naked);
}

bool FuncDeclaration::addPostInvariant()
{
    AggregateDeclaration *ad = isThis();
    ClassDeclaration *cd = ad ? ad->isClassDeclaration() : NULL;
    return (ad && !(cd && cd->isCPPclass()) &&
            ad->inv &&
            global.params.useInvariants &&
            (protection.kind == PROTprotected || protection.kind == PROTpublic || protection.kind == PROTexport) &&
            !naked);
}

/********************************************************
 * Generate Expression to call the invariant.
 * Input:
 *      ad      aggregate with the invariant
 *      vthis   variable with 'this'
 *      direct  call invariant directly
 */
Expression *addInvariant(Scope *sc, AggregateDeclaration *ad, VarDeclaration *vthis, bool direct)
{
    Expression *e = NULL;
    if (direct)
    {
        // Call invariant directly only if it exists
        FuncDeclaration *inv = ad->inv;
        ClassDeclaration *cd = ad->isClassDeclaration();

        while (!inv && cd)
        {
            cd = cd->baseClass;
            if (!cd)
                break;
            inv = cd->inv;
        }
        if (inv)
        {
        #if 1
            // Workaround for bugzilla 13394: For the correct mangling,
            // run attribute inference on inv if needed.
            inv->functionSemantic();
        #endif

            //e = new DsymbolExp(Loc(), inv);
            //e = new CallExp(Loc(), e);
            //e = e->semantic(sc2);

            /* Bugzilla 13113: Currently virtual invariant calls completely
             * bypass attribute enforcement.
             * Change the behavior of pre-invariant call by following it.
             */
            e = new ThisExp(Loc());
            e->type = vthis->type;
            e = new DotVarExp(Loc(), e, inv, 0);
            e->type = inv->type;
            e = new CallExp(Loc(), e);
            e->type = Type::tvoid;
        }
    }
    else
    {
    #if 1
        // Workaround for bugzilla 13394: For the correct mangling,
        // run attribute inference on inv if needed.
        if (ad->isStructDeclaration() && ad->inv)
            ad->inv->functionSemantic();
    #endif

        // Call invariant virtually
        Expression *v = new ThisExp(Loc());
        v->type = vthis->type;
        if (ad->isStructDeclaration())
            v = v->addressOf();
        Expression *se = new StringExp(Loc(), (char *)"null this");
        se = se->semantic(sc);
        se->type = Type::tchar->arrayOf();
        e = new AssertExp(Loc(), v, se);
    }
    return e;
}

/**********************************
 * Generate a FuncDeclaration for a runtime library function.
 */

FuncDeclaration *FuncDeclaration::genCfunc(Parameters *fparams, Type *treturn, const char *name, StorageClass stc)
{
    return genCfunc(fparams, treturn, Identifier::idPool(name), stc);
}

FuncDeclaration *FuncDeclaration::genCfunc(Parameters *fparams, Type *treturn, Identifier *id, StorageClass stc)
{
    FuncDeclaration *fd;
    TypeFunction *tf;
    Dsymbol *s;
    static DsymbolTable *st = NULL;

    //printf("genCfunc(name = '%s')\n", id->toChars());
    //printf("treturn\n\t"); treturn->print();

    // See if already in table
    if (!st)
        st = new DsymbolTable();
    s = st->lookup(id);
    if (s)
    {
        fd = s->isFuncDeclaration();
        assert(fd);
        assert(fd->type->nextOf()->equals(treturn));
    }
    else
    {
        tf = new TypeFunction(fparams, treturn, 0, LINKc, stc);
        fd = new FuncDeclaration(Loc(), Loc(), id, STCstatic, tf);
        fd->protection = Prot(PROTpublic);
        fd->linkage = LINKc;

        st->insert(fd);
    }
    return fd;
}

const char *FuncDeclaration::kind()
{
    return "function";
}

/*********************************************
 * In the current function, we are calling 'this' function.
 * 1. Check to see if the current function can call 'this' function, issue error if not.
 * 2. If the current function is not the parent of 'this' function, then add
 *    the current function to the list of siblings of 'this' function.
 * 3. If the current function is a literal, and it's accessing an uplevel scope,
 *    then mark it as a delegate.
 */

bool FuncDeclaration::checkNestedReference(Scope *sc, Loc loc)
{
    //printf("FuncDeclaration::checkNestedReference() %s\n", toPrettyChars());
    if (parent && parent != sc->parent && this->isNested() &&
        this->ident != Id::require && this->ident != Id::ensure)
    {
        // The function that this function is in
        FuncDeclaration *fdv2 = toParent2()->isFuncDeclaration();

        // The current function
        FuncDeclaration *fdthis = sc->parent->isFuncDeclaration();

        //printf("this = %s in [%s]\n", this->toChars(), this->loc.toChars());
        //printf("fdv2 = %s in [%s]\n", fdv2->toChars(), fdv2->loc.toChars());
        //printf("fdthis = %s in [%s]\n", fdthis->toChars(), fdthis->loc.toChars());

        if (fdv2 && fdthis && fdv2 != fdthis)
        {
            // Add this function to the list of those which called us
            if (fdthis != this)
            {
                bool found = false;
                for (size_t i = 0; i < siblingCallers.dim; ++i)
                {
                    if (siblingCallers[i] == fdthis)
                        found = true;
                }
                if (!found)
                {
                    //printf("\tadding sibling %s\n", fdthis->toPrettyChars());
                    if (!sc->intypeof && !(sc->flags & SCOPEcompile))
                        siblingCallers.push(fdthis);
                }
            }
        }

        FuncDeclaration *fdv = toParent2()->isFuncDeclaration();
        if (fdv && fdthis && fdv != fdthis)
        {
            int lv = fdthis->getLevel(loc, sc, fdv);
            if (lv == -2)
                return false;   // error
            if (lv == -1)
                return true;    // downlevel call
            if (lv == 0)
                return true;    // same level call

            // Uplevel call

            // BUG: may need to walk up outer scopes like Declaration::checkNestedReference() does

            // function literal has reference to enclosing scope is delegate
            if (FuncLiteralDeclaration *fld = fdthis->isFuncLiteralDeclaration())
                fld->tok = TOKdelegate;
        }
    }
    return true;
}

/* For all functions between outerFunc and f, mark them as needing
 * a closure.
 */
void markAsNeedingClosure(Dsymbol *f, FuncDeclaration *outerFunc)
{
    for (Dsymbol *sx = f; sx && sx != outerFunc; sx = sx->parent)
    {
        FuncDeclaration *fy = sx->isFuncDeclaration();
        if (fy && fy->closureVars.dim)
        {
            /* fy needs a closure if it has closureVars[],
             * because the frame pointer in the closure will be accessed.
             */
            fy->requiresClosure = true;
        }
    }
}


/* Given a nested function f inside a function outerFunc, check
 * if any sibling callers of f have escaped. If so, mark
 * all the enclosing functions as needing closures.
 * Return true if any closures were detected.
 * This is recursive: we need to check the callers of our siblings.
 * Note that nested functions can only call lexically earlier nested
 * functions, so loops are impossible.
 */
bool checkEscapingSiblings(FuncDeclaration *f, FuncDeclaration *outerFunc, void *p = NULL)
{
    struct PrevSibling
    {
        PrevSibling *p;
        FuncDeclaration *f;
    };

    PrevSibling ps;
    ps.p = (PrevSibling *)p;
    ps.f = f;

    //printf("checkEscapingSiblings(f = %s, outerfunc = %s)\n", f->toChars(), outerFunc->toChars());
    bool bAnyClosures = false;
    for (size_t i = 0; i < f->siblingCallers.dim; ++i)
    {
        FuncDeclaration *g = f->siblingCallers[i];
        if (g->isThis() || g->tookAddressOf)
        {
            markAsNeedingClosure(g, outerFunc);
            bAnyClosures = true;
        }

        PrevSibling *prev = (PrevSibling *)p;
        while (1)
        {
            if (!prev)
            {
                bAnyClosures |= checkEscapingSiblings(g, outerFunc, &ps);
                break;
            }
            if (prev->f == g)
                break;
            prev = prev->p;
        }
    }
    //printf("\t%d\n", bAnyClosures);
    return bAnyClosures;
}


/*******************************
 * Look at all the variables in this function that are referenced
 * by nested functions, and determine if a closure needs to be
 * created for them.
 */

bool FuncDeclaration::needsClosure()
{
    /* Need a closure for all the closureVars[] if any of the
     * closureVars[] are accessed by a
     * function that escapes the scope of this function.
     * We take the conservative approach and decide that a function needs
     * a closure if it:
     * 1) is a virtual function
     * 2) has its address taken
     * 3) has a parent that escapes
     * 4) calls another nested function that needs a closure
     * -or-
     * 5) this function returns a local struct/class
     *
     * Note that since a non-virtual function can be called by
     * a virtual one, if that non-virtual function accesses a closure
     * var, the closure still has to be taken. Hence, we check for isThis()
     * instead of isVirtual(). (thanks to David Friedman)
     */

    //printf("FuncDeclaration::needsClosure() %s\n", toChars());

    if (requiresClosure)
        goto Lyes;

    for (size_t i = 0; i < closureVars.dim; i++)
    {   VarDeclaration *v = closureVars[i];
        assert(v->isVarDeclaration());
        //printf("\tv = %s\n", v->toChars());

        for (size_t j = 0; j < v->nestedrefs.dim; j++)
        {   FuncDeclaration *f = v->nestedrefs[j];
            assert(f != this);

            //printf("\t\tf = %s, isVirtual=%d, isThis=%p, tookAddressOf=%d\n", f->toChars(), f->isVirtual(), f->isThis(), f->tookAddressOf);

            /* Look to see if f escapes. We consider all parents of f within
             * this, and also all siblings which call f; if any of them escape,
             * so does f.
             * Mark all affected functions as requiring closures.
             */
            for (Dsymbol *s = f; s && s != this; s = s->parent)
            {
                FuncDeclaration *fx = s->isFuncDeclaration();
                if (fx && (fx->isThis() || fx->tookAddressOf))
                {
                    //printf("\t\tfx = %s, isVirtual=%d, isThis=%p, tookAddressOf=%d\n", fx->toChars(), fx->isVirtual(), fx->isThis(), fx->tookAddressOf);

                    /* Mark as needing closure any functions between this and f
                     */
                    markAsNeedingClosure( (fx == f) ? fx->parent : fx, this);

                    goto Lyes;
                }

                /* We also need to check if any sibling functions that
                 * called us, have escaped. This is recursive: we need
                 * to check the callers of our siblings.
                 */
                if (fx && checkEscapingSiblings(fx, this))
                    goto Lyes;
            }
        }
    }

    /* Look for case (5)
     */
    if (closureVars.dim)
    {
        assert(type->ty == Tfunction);
        Type *tret = ((TypeFunction *)type)->next;
        assert(tret);
        tret = tret->toBasetype();
        //printf("\t\treturning %s\n", tret->toChars());
        if (tret->ty == Tclass || tret->ty == Tstruct)
        {   Dsymbol *st = tret->toDsymbol(NULL);
            //printf("\t\treturning class/struct %s\n", tret->toChars());
            for (Dsymbol *s = st->parent; s; s = s->parent)
            {
                //printf("\t\t\tparent = %s %s\n", s->kind(), s->toChars());
                if (s == this)
                {   //printf("\t\treturning local %s\n", st->toChars());
                    goto Lyes;
                }
            }
        }
    }

    return false;

Lyes:
    //printf("\tneeds closure\n");
    return true;
}

/***********************************************
 * Determine if function's variables are referenced by a function
 * nested within it.
 */

bool FuncDeclaration::hasNestedFrameRefs()
{
    if (closureVars.dim)
        return true;

    /* If a virtual method has contracts, assume its variables are referenced
     * by those contracts, even if they aren't. Because they might be referenced
     * by the overridden or overriding function's contracts.
     * This can happen because frequire and fensure are implemented as nested functions,
     * and they can be called directly by an overriding function and the overriding function's
     * context had better match, or Bugzilla 7337 will bite.
     */
    if ((fdrequire || fdensure) && isVirtualMethod())
        return true;

    if (foverrides.dim && isVirtualMethod())
    {
        for (size_t i = 0; i < foverrides.dim; i++)
        {
            FuncDeclaration *fdv = foverrides[i];
            if (fdv->hasNestedFrameRefs())
                return true;
        }
    }

    return false;
}

/*********************************************
 * Return the function's parameter list, and whether
 * it is variadic or not.
 */

Parameters *FuncDeclaration::getParameters(int *pvarargs)
{
    Parameters *fparameters = NULL;
    int fvarargs = 0;

    if (type)
    {
        assert(type->ty == Tfunction);
        TypeFunction *fdtype = (TypeFunction *)type;
        fparameters = fdtype->parameters;
        fvarargs = fdtype->varargs;
    }
    if (pvarargs)
        *pvarargs = fvarargs;
    return fparameters;
}


/****************************** FuncAliasDeclaration ************************/

// Used as a way to import a set of functions from another scope into this one.

FuncAliasDeclaration::FuncAliasDeclaration(FuncDeclaration *funcalias, bool hasOverloads)
    : FuncDeclaration(funcalias->loc, funcalias->endloc, funcalias->ident,
        funcalias->storage_class, funcalias->type)
{
    assert(funcalias != this);
    this->funcalias = funcalias;

    this->hasOverloads = hasOverloads;
    if (hasOverloads)
    {
        if (FuncAliasDeclaration *fad = funcalias->isFuncAliasDeclaration())
            this->hasOverloads = fad->hasOverloads;
    }
    else
    {   // for internal use
        assert(!funcalias->isFuncAliasDeclaration());
        this->hasOverloads = false;
    }
    userAttribDecl = funcalias->userAttribDecl;
}

const char *FuncAliasDeclaration::kind()
{
    return "function alias";
}

FuncDeclaration *FuncAliasDeclaration::toAliasFunc()
{
    return funcalias->toAliasFunc();
}


/****************************** FuncLiteralDeclaration ************************/

FuncLiteralDeclaration::FuncLiteralDeclaration(Loc loc, Loc endloc, Type *type,
        TOK tok, ForeachStatement *fes, Identifier *id)
    : FuncDeclaration(loc, endloc, NULL, STCundefined, type)
{
    this->ident = id ? id : Id::empty;
    this->tok = tok;
    this->fes = fes;
    this->treq = NULL;
    //printf("FuncLiteralDeclaration() id = '%s', type = '%s'\n", this->ident->toChars(), type->toChars());
}

Dsymbol *FuncLiteralDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("FuncLiteralDeclaration::syntaxCopy('%s')\n", toChars());
    assert(!s);
    FuncLiteralDeclaration *f = new FuncLiteralDeclaration(loc, endloc,
        type->syntaxCopy(), tok, fes, ident);
    f->treq = treq;     // don't need to copy
    return FuncDeclaration::syntaxCopy(f);
}

bool FuncLiteralDeclaration::isNested()
{
    //printf("FuncLiteralDeclaration::isNested() '%s'\n", toChars());
    return (tok != TOKfunction);
}

bool FuncLiteralDeclaration::isVirtual()
{
    return false;
}

bool FuncLiteralDeclaration::addPreInvariant()
{
    return false;
}

bool FuncLiteralDeclaration::addPostInvariant()
{
    return false;
}

/*******************************
 * Modify all expression type of return statements to tret.
 *
 * On function literals, return type may be modified based on the context type
 * after its semantic3 is done, in FuncExp::implicitCastTo.
 *
 *  A function() dg = (){ return new B(); } // OK if is(B : A) == true
 *
 * If B to A conversion is convariant that requires offseet adjusting,
 * all return statements should be adjusted to return expressions typed A.
 */
void FuncLiteralDeclaration::modifyReturns(Scope *sc, Type *tret)
{
    class RetWalker : public StatementRewriteWalker
    {
    public:
        Scope *sc;
        Type *tret;
        FuncLiteralDeclaration *fld;

        void visit(ReturnStatement *s)
        {
            Expression *exp = s->exp;
            if (exp && !exp->type->equals(tret))
            {
                s->exp = exp->castTo(sc, tret);
            }
        }
    };

    if (semanticRun < PASSsemantic3done)
        return;

    if (fes)
        return;

    RetWalker w;
    w.sc = sc;
    w.tret = tret;
    w.fld = this;
    fbody->accept(&w);

    // Also update the inferred function type to match the new return type.
    // This is required so the code generator does not try to cast the
    // modified returns back to the original type.
    if (inferRetType && type->nextOf() != tret)
        ((TypeFunction *)type)->next = tret;
}

const char *FuncLiteralDeclaration::kind()
{
    // GCC requires the (char*) casts
    return (tok != TOKfunction) ? (char*)"delegate" : (char*)"function";
}

const char *FuncLiteralDeclaration::toPrettyChars(bool QualifyTypes)
{
    if (parent)
    {
        TemplateInstance *ti = parent->isTemplateInstance();
        if (ti)
            return ti->tempdecl->toPrettyChars(QualifyTypes);
    }
    return Dsymbol::toPrettyChars(QualifyTypes);
}

/********************************* CtorDeclaration ****************************/

CtorDeclaration::CtorDeclaration(Loc loc, Loc endloc, StorageClass stc, Type *type)
    : FuncDeclaration(loc, endloc, Id::ctor, stc, type)
{
    //printf("CtorDeclaration(loc = %s) %s\n", loc.toChars(), toChars());
}

Dsymbol *CtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    CtorDeclaration *f = new CtorDeclaration(loc, endloc, storage_class, type->syntaxCopy());
    return FuncDeclaration::syntaxCopy(f);
}

void CtorDeclaration::semantic(Scope *sc)
{
    //printf("CtorDeclaration::semantic() %s\n", toChars());
    if (scope)
    {
        sc = scope;
        scope = NULL;
    }

    sc = sc->push();
    sc->stc &= ~STCstatic;              // not a static constructor
    sc->flags |= SCOPEctor;

    FuncDeclaration::semantic(sc);

    sc->pop();

    if (errors)
        return;

    TypeFunction *tf = (TypeFunction *)type;
    assert(tf && tf->ty == Tfunction);

    Dsymbol *parent = toParent2();
    AggregateDeclaration *ad = parent->isAggregateDeclaration();

    /* See if it's the default constructor
     * But, template constructor should not become a default constructor.
     */
    if (ad && tf->varargs == 0 && Parameter::dim(tf->parameters) == 0
        && (!this->parent->isTemplateInstance() || this->parent->isTemplateMixin()))
    {
        StructDeclaration *sd = ad->isStructDeclaration();
        if (sd)
        {
            if (fbody || !(storage_class & STCdisable))
            {
                error("default constructor for structs only allowed with @disable and no body");
                storage_class |= STCdisable;
                fbody = NULL;
            }
            sd->noDefaultCtor = true;
        }
        else
        {
            ad->defaultCtor = this;
        }
    }
}

const char *CtorDeclaration::kind()
{
    return "constructor";
}

char *CtorDeclaration::toChars()
{
    return (char *)"this";
}

bool CtorDeclaration::isVirtual()
{
    return false;
}

bool CtorDeclaration::addPreInvariant()
{
    return false;
}

bool CtorDeclaration::addPostInvariant()
{
    return (isThis() && vthis && global.params.useInvariants);
}


/********************************* PostBlitDeclaration ****************************/

PostBlitDeclaration::PostBlitDeclaration(Loc loc, Loc endloc, StorageClass stc, Identifier *id)
    : FuncDeclaration(loc, endloc, id, stc, NULL)
{
}

Dsymbol *PostBlitDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    PostBlitDeclaration *dd = new PostBlitDeclaration(loc, endloc, storage_class, ident);
    return FuncDeclaration::syntaxCopy(dd);
}

void PostBlitDeclaration::semantic(Scope *sc)
{
    //printf("PostBlitDeclaration::semantic() %s\n", toChars());
    //printf("ident: %s, %s, %p, %p\n", ident->toChars(), Id::dtor->toChars(), ident, Id::dtor);
    //printf("stc = x%llx\n", sc->stc);
    if (scope)
    {
        sc = scope;
        scope = NULL;
    }
    parent = sc->parent;
    Dsymbol *parent = toParent();
    StructDeclaration *ad = parent->isStructDeclaration();
    if (!ad)
    {
        error("post blits are only for struct/union definitions, not %s %s", parent->kind(), parent->toChars());
    }
    else if (ident == Id::_postblit && semanticRun < PASSsemantic)
        ad->postblits.push(this);

    if (!type)
        type = new TypeFunction(NULL, Type::tvoid, false, LINKd, storage_class);

    sc = sc->push();
    sc->stc &= ~STCstatic;              // not static
    sc->linkage = LINKd;

    FuncDeclaration::semantic(sc);

    sc->pop();
}

bool PostBlitDeclaration::overloadInsert(Dsymbol *s)
{
    return false;       // cannot overload postblits
}

bool PostBlitDeclaration::addPreInvariant()
{
    return false;
}

bool PostBlitDeclaration::addPostInvariant()
{
    return (isThis() && vthis && global.params.useInvariants);
}

bool PostBlitDeclaration::isVirtual()
{
    return false;
}

/********************************* DtorDeclaration ****************************/

DtorDeclaration::DtorDeclaration(Loc loc, Loc endloc)
    : FuncDeclaration(loc, endloc, Id::dtor, STCundefined, NULL)
{
}

DtorDeclaration::DtorDeclaration(Loc loc, Loc endloc, StorageClass stc, Identifier *id)
    : FuncDeclaration(loc, endloc, id, stc, NULL)
{
}

Dsymbol *DtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    DtorDeclaration *dd = new DtorDeclaration(loc, endloc, storage_class, ident);
    return FuncDeclaration::syntaxCopy(dd);
}

void DtorDeclaration::semantic(Scope *sc)
{
    //printf("DtorDeclaration::semantic() %s\n", toChars());
    //printf("ident: %s, %s, %p, %p\n", ident->toChars(), Id::dtor->toChars(), ident, Id::dtor);
    if (scope)
    {
        sc = scope;
        scope = NULL;
    }
    parent = sc->parent;
    Dsymbol *parent = toParent();
    AggregateDeclaration *ad = parent->isAggregateDeclaration();
    if (!ad)
    {
        error("destructors are only for class/struct/union definitions, not %s %s", parent->kind(), parent->toChars());
    }
    else if (ident == Id::dtor && semanticRun < PASSsemantic)
        ad->dtors.push(this);

    if (!type)
        type = new TypeFunction(NULL, Type::tvoid, false, LINKd, storage_class);

    sc = sc->push();
    sc->stc &= ~STCstatic;              // not a static destructor
    sc->linkage = LINKd;

    FuncDeclaration::semantic(sc);

    sc->pop();
}

bool DtorDeclaration::overloadInsert(Dsymbol *s)
{
    return false;       // cannot overload destructors
}

bool DtorDeclaration::addPreInvariant()
{
    return (isThis() && vthis && global.params.useInvariants);
}

bool DtorDeclaration::addPostInvariant()
{
    return false;
}

const char *DtorDeclaration::kind()
{
    return "destructor";
}

char *DtorDeclaration::toChars()
{
    return (char *)"~this";
}

bool DtorDeclaration::isVirtual()
{
    // false so that dtor's don't get put into the vtbl[]
    return false;
}

/********************************* StaticCtorDeclaration ****************************/

StaticCtorDeclaration::StaticCtorDeclaration(Loc loc, Loc endloc, StorageClass stc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId("_staticCtor"), STCstatic | stc, NULL)
{
}

StaticCtorDeclaration::StaticCtorDeclaration(Loc loc, Loc endloc, const char *name, StorageClass stc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId(name), STCstatic | stc, NULL)
{
}

Dsymbol *StaticCtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    StaticCtorDeclaration *scd = new StaticCtorDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(scd);
}

void StaticCtorDeclaration::semantic(Scope *sc)
{
    //printf("StaticCtorDeclaration::semantic()\n");

    if (scope)
    {
        sc = scope;
        scope = NULL;
    }

    if (!type)
        type = new TypeFunction(NULL, Type::tvoid, false, LINKd, storage_class);

    /* If the static ctor appears within a template instantiation,
     * it could get called multiple times by the module constructors
     * for different modules. Thus, protect it with a gate.
     */
    if (isInstantiated() && semanticRun < PASSsemantic)
    {
        /* Add this prefix to the function:
         *      static int gate;
         *      if (++gate != 1) return;
         * Note that this is not thread safe; should not have threads
         * during static construction.
         */
        VarDeclaration *v = new VarDeclaration(Loc(), Type::tint32, Id::gate, NULL);
        v->storage_class = STCtemp | (isSharedStaticCtorDeclaration() ? STCstatic : STCtls);
        Statements *sa = new Statements();
        Statement *s = new ExpStatement(Loc(), v);
        sa->push(s);
        Expression *e = new IdentifierExp(Loc(), v->ident);
        e = new AddAssignExp(Loc(), e, new IntegerExp(1));
        e = new EqualExp(TOKnotequal, Loc(), e, new IntegerExp(1));
        s = new IfStatement(Loc(), NULL, e, new ReturnStatement(Loc(), NULL), NULL);
        sa->push(s);
        if (fbody)
            sa->push(fbody);
        fbody = new CompoundStatement(Loc(), sa);
    }

    FuncDeclaration::semantic(sc);

    // We're going to need ModuleInfo
    Module *m = getModule();
    if (!m)
        m = sc->module;
    if (m)
    {   m->needmoduleinfo = 1;
        //printf("module1 %s needs moduleinfo\n", m->toChars());
    }
}

AggregateDeclaration *StaticCtorDeclaration::isThis()
{
    return NULL;
}

bool StaticCtorDeclaration::isVirtual()
{
    return false;
}

bool StaticCtorDeclaration::hasStaticCtorOrDtor()
{
    return true;
}

bool StaticCtorDeclaration::addPreInvariant()
{
    return false;
}

bool StaticCtorDeclaration::addPostInvariant()
{
    return false;
}

/********************************* SharedStaticCtorDeclaration ****************************/

SharedStaticCtorDeclaration::SharedStaticCtorDeclaration(Loc loc, Loc endloc, StorageClass stc)
    : StaticCtorDeclaration(loc, endloc, "_sharedStaticCtor", stc)
{
}

Dsymbol *SharedStaticCtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    SharedStaticCtorDeclaration *scd = new SharedStaticCtorDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(scd);
}

/********************************* StaticDtorDeclaration ****************************/

StaticDtorDeclaration::StaticDtorDeclaration(Loc loc, Loc endloc, StorageClass stc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId("_staticDtor"), STCstatic | stc, NULL)
{
    vgate = NULL;
}

StaticDtorDeclaration::StaticDtorDeclaration(Loc loc, Loc endloc, const char *name, StorageClass stc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId(name), STCstatic | stc, NULL)
{
    vgate = NULL;
}

Dsymbol *StaticDtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    StaticDtorDeclaration *sdd = new StaticDtorDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(sdd);
}

void StaticDtorDeclaration::semantic(Scope *sc)
{
    if (scope)
    {
        sc = scope;
        scope = NULL;
    }

    if (!type)
        type = new TypeFunction(NULL, Type::tvoid, false, LINKd, storage_class);

    /* If the static ctor appears within a template instantiation,
     * it could get called multiple times by the module constructors
     * for different modules. Thus, protect it with a gate.
     */
    if (isInstantiated() && semanticRun < PASSsemantic)
    {
        /* Add this prefix to the function:
         *      static int gate;
         *      if (--gate != 0) return;
         * Increment gate during constructor execution.
         * Note that this is not thread safe; should not have threads
         * during static destruction.
         */
        VarDeclaration *v = new VarDeclaration(Loc(), Type::tint32, Id::gate, NULL);
        v->storage_class = STCtemp | (isSharedStaticDtorDeclaration() ? STCstatic : STCtls);
        Statements *sa = new Statements();
        Statement *s = new ExpStatement(Loc(), v);
        sa->push(s);
        Expression *e = new IdentifierExp(Loc(), v->ident);
        e = new AddAssignExp(Loc(), e, new IntegerExp(-1));
        e = new EqualExp(TOKnotequal, Loc(), e, new IntegerExp(0));
        s = new IfStatement(Loc(), NULL, e, new ReturnStatement(Loc(), NULL), NULL);
        sa->push(s);
        if (fbody)
            sa->push(fbody);
        fbody = new CompoundStatement(Loc(), sa);
        vgate = v;
    }

    FuncDeclaration::semantic(sc);

    // We're going to need ModuleInfo
    Module *m = getModule();
    if (!m)
        m = sc->module;
    if (m)
    {   m->needmoduleinfo = 1;
        //printf("module2 %s needs moduleinfo\n", m->toChars());
    }
}

AggregateDeclaration *StaticDtorDeclaration::isThis()
{
    return NULL;
}

bool StaticDtorDeclaration::isVirtual()
{
    return false;
}

bool StaticDtorDeclaration::hasStaticCtorOrDtor()
{
    return true;
}

bool StaticDtorDeclaration::addPreInvariant()
{
    return false;
}

bool StaticDtorDeclaration::addPostInvariant()
{
    return false;
}

/********************************* SharedStaticDtorDeclaration ****************************/

SharedStaticDtorDeclaration::SharedStaticDtorDeclaration(Loc loc, Loc endloc, StorageClass stc)
    : StaticDtorDeclaration(loc, endloc, "_sharedStaticDtor", stc)
{
}

Dsymbol *SharedStaticDtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    SharedStaticDtorDeclaration *sdd = new SharedStaticDtorDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(sdd);
}

/********************************* InvariantDeclaration ****************************/

InvariantDeclaration::InvariantDeclaration(Loc loc, Loc endloc, StorageClass stc, Identifier *id)
    : FuncDeclaration(loc, endloc,
                      id ? id : Identifier::generateId("__invariant"),
                      stc, NULL)
{
}

Dsymbol *InvariantDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    InvariantDeclaration *id = new InvariantDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(id);
}

void InvariantDeclaration::semantic(Scope *sc)
{
    if (scope)
    {
        sc = scope;
        scope = NULL;
    }
    parent = sc->parent;
    Dsymbol *parent = toParent();
    AggregateDeclaration *ad = parent->isAggregateDeclaration();
    if (!ad)
    {
        error("invariants are only for struct/union/class definitions");
        return;
    }
    if (ident != Id::classInvariant && semanticRun < PASSsemantic)
    {
        ad->invs.push(this);
    }
    if (!type)
        type = new TypeFunction(NULL, Type::tvoid, false, LINKd, storage_class);

    sc = sc->push();
    sc->stc &= ~STCstatic;              // not a static invariant
    sc->stc |= STCconst;                // invariant() is always const
    sc->flags = (sc->flags & ~SCOPEcontract) | SCOPEinvariant;
    sc->linkage = LINKd;

    FuncDeclaration::semantic(sc);

    sc->pop();
}

bool InvariantDeclaration::isVirtual()
{
    return false;
}

bool InvariantDeclaration::addPreInvariant()
{
    return false;
}

bool InvariantDeclaration::addPostInvariant()
{
    return false;
}

/********************************* UnitTestDeclaration ****************************/

/*******************************
 * Generate unique unittest function Id so we can have multiple
 * instances per module.
 */

static Identifier *unitTestId(Loc loc)
{
    OutBuffer buf;
    buf.printf("__unittestL%u_", loc.linnum);
    return Identifier::generateId(buf.peekString());
}

UnitTestDeclaration::UnitTestDeclaration(Loc loc, Loc endloc, StorageClass stc, char *codedoc)
    : FuncDeclaration(loc, endloc, unitTestId(loc), stc, NULL)
{
    this->codedoc = codedoc;
}

Dsymbol *UnitTestDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    UnitTestDeclaration *utd = new UnitTestDeclaration(loc, endloc, storage_class, codedoc);
    return FuncDeclaration::syntaxCopy(utd);
}

void UnitTestDeclaration::semantic(Scope *sc)
{
    protection = sc->protection;

    if (scope)
    {
        sc = scope;
        scope = NULL;
    }

    if (!isInstantiated() && inNonRoot())
        return;

    if (global.params.useUnitTests)
    {
        if (!type)
            type = new TypeFunction(NULL, Type::tvoid, false, LINKd, storage_class);
        Scope *sc2 = sc->push();
        sc2->linkage = LINKd;
        FuncDeclaration::semantic(sc2);
        sc2->pop();
    }

#if 0
    // We're going to need ModuleInfo even if the unit tests are not
    // compiled in, because other modules may import this module and refer
    // to this ModuleInfo.
    // (This doesn't make sense to me?)
    Module *m = getModule();
    if (!m)
        m = sc->module;
    if (m)
    {
        //printf("module3 %s needs moduleinfo\n", m->toChars());
        m->needmoduleinfo = 1;
    }
#endif
}

AggregateDeclaration *UnitTestDeclaration::isThis()
{
    return NULL;
}

bool UnitTestDeclaration::isVirtual()
{
    return false;
}

bool UnitTestDeclaration::addPreInvariant()
{
    return false;
}

bool UnitTestDeclaration::addPostInvariant()
{
    return false;
}

/********************************* NewDeclaration ****************************/

NewDeclaration::NewDeclaration(Loc loc, Loc endloc, StorageClass stc, Parameters *fparams, int varargs)
    : FuncDeclaration(loc, endloc, Id::classNew, STCstatic | stc, NULL)
{
    this->parameters = fparams;
    this->varargs = varargs;
}

Dsymbol *NewDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    NewDeclaration *f = new NewDeclaration(loc, endloc,
        storage_class, Parameter::arraySyntaxCopy(parameters), varargs);
    return FuncDeclaration::syntaxCopy(f);
}

void NewDeclaration::semantic(Scope *sc)
{
    //printf("NewDeclaration::semantic()\n");

    if (scope)
    {
        sc = scope;
        scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *parent = toParent();
    ClassDeclaration *cd = parent->isClassDeclaration();
    if (!cd && !parent->isStructDeclaration())
    {
        error("new allocators only are for class or struct definitions");
    }
    Type *tret = Type::tvoid->pointerTo();
    if (!type)
        type = new TypeFunction(parameters, tret, varargs, LINKd, storage_class);

    type = type->semantic(loc, sc);
    assert(type->ty == Tfunction);

    // Check that there is at least one argument of type size_t
    TypeFunction *tf = (TypeFunction *)type;
    if (Parameter::dim(tf->parameters) < 1)
    {
        error("at least one argument of type size_t expected");
    }
    else
    {
        Parameter *p = Parameter::getNth(tf->parameters, 0);
        if (!p->type->equals(Type::tsize_t))
            error("first argument must be type size_t, not %s", p->type->toChars());
    }

    FuncDeclaration::semantic(sc);
}

const char *NewDeclaration::kind()
{
    return "allocator";
}

bool NewDeclaration::isVirtual()
{
    return false;
}

bool NewDeclaration::addPreInvariant()
{
    return false;
}

bool NewDeclaration::addPostInvariant()
{
    return false;
}

/********************************* DeleteDeclaration ****************************/

DeleteDeclaration::DeleteDeclaration(Loc loc, Loc endloc, StorageClass stc, Parameters *fparams)
    : FuncDeclaration(loc, endloc, Id::classDelete, STCstatic | stc, NULL)
{
    this->parameters = fparams;
}

Dsymbol *DeleteDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    DeleteDeclaration *f = new DeleteDeclaration(loc, endloc,
            storage_class, Parameter::arraySyntaxCopy(parameters));
    return FuncDeclaration::syntaxCopy(f);
}

void DeleteDeclaration::semantic(Scope *sc)
{
    //printf("DeleteDeclaration::semantic()\n");

    if (scope)
    {
        sc = scope;
        scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *parent = toParent();
    ClassDeclaration *cd = parent->isClassDeclaration();
    if (!cd && !parent->isStructDeclaration())
    {
        error("new allocators only are for class or struct definitions");
    }
    if (!type)
        type = new TypeFunction(parameters, Type::tvoid, 0, LINKd, storage_class);

    type = type->semantic(loc, sc);
    assert(type->ty == Tfunction);

    // Check that there is only one argument of type void*
    TypeFunction *tf = (TypeFunction *)type;
    if (Parameter::dim(tf->parameters) != 1)
    {
        error("one argument of type void* expected");
    }
    else
    {
        Parameter *p = Parameter::getNth(tf->parameters, 0);
        if (!p->type->equals(Type::tvoid->pointerTo()))
            error("one argument of type void* expected, not %s", p->type->toChars());
    }

    FuncDeclaration::semantic(sc);
}

const char *DeleteDeclaration::kind()
{
    return "deallocator";
}

bool DeleteDeclaration::isDelete()
{
    return true;
}

bool DeleteDeclaration::isVirtual()
{
    return false;
}

bool DeleteDeclaration::addPreInvariant()
{
    return false;
}

bool DeleteDeclaration::addPostInvariant()
{
    return false;
}
