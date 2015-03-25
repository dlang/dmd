
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/declaration.c
 */

#include <stdio.h>
#include <assert.h>

#include "init.h"
#include "declaration.h"
#include "attrib.h"
#include "mtype.h"
#include "template.h"
#include "scope.h"
#include "aggregate.h"
#include "module.h"
#include "import.h"
#include "id.h"
#include "expression.h"
#include "statement.h"
#include "ctfe.h"
#include "target.h"

Expression *getTypeInfo(Type *t, Scope *sc);

/************************************
 * Check to see the aggregate type is nested and its context pointer is
 * accessible from the current scope.
 * Returns true if error occurs.
 */
bool checkFrameAccess(Loc loc, Scope *sc, AggregateDeclaration *ad, size_t iStart = 0)
{
    Dsymbol *sparent = ad->toParent2();
    Dsymbol *s = sc->func;
    if (ad->isNested() && s)
    {
        //printf("ad = %p %s [%s], parent:%p\n", ad, ad->toChars(), ad->loc.toChars(), ad->parent);
        //printf("sparent = %p %s [%s], parent: %s\n", sparent, sparent->toChars(), sparent->loc.toChars(), sparent->parent->toChars());

        while (s)
        {
            if (s == sparent)   // hit!
                break;

            if (FuncDeclaration *fd = s->isFuncDeclaration())
            {
                if (!fd->isThis() && !fd->isNested())
                    break;
            }
            if (AggregateDeclaration *ad2 = s->isAggregateDeclaration())
            {
                if (ad2->storage_class & STCstatic)
                    break;
            }
            s = s->toParent2();
        }
        if (s != sparent)
        {
            error(loc, "cannot access frame pointer of %s", ad->toPrettyChars());
            return true;
        }
    }

    bool result = false;
    for (size_t i = iStart; i < ad->fields.dim; i++)
    {
        VarDeclaration *vd = ad->fields[i];
        Type *tb = vd->type->baseElemOf();
        if (tb->ty == Tstruct)
        {
            result |= checkFrameAccess(loc, sc, ((TypeStruct *)tb)->sym);
        }
    }
    return result;
}

/********************************* Declaration ****************************/

Declaration::Declaration(Identifier *id)
    : Dsymbol(id)
{
    type = NULL;
    originalType = NULL;
    storage_class = STCundefined;
    protection = Prot(PROTundefined);
    linkage = LINKdefault;
    inuse = 0;
    sem = SemanticStart;
    mangleOverride = NULL;
}

void Declaration::semantic(Scope *sc)
{
}

const char *Declaration::kind()
{
    return "declaration";
}

unsigned Declaration::size(Loc loc)
{
    assert(type);
    return (unsigned)type->size();
}

bool Declaration::isDelete()
{
    return false;
}

bool Declaration::isDataseg()
{
    return false;
}

bool Declaration::isThreadlocal()
{
    return false;
}

bool Declaration::isCodeseg()
{
    return false;
}

Prot Declaration::prot()
{
    return protection;
}

/*************************************
 * Check to see if declaration can be modified in this context (sc).
 * Issue error if not.
 */

int Declaration::checkModify(Loc loc, Scope *sc, Type *t, Expression *e1, int flag)
{
    VarDeclaration *v = isVarDeclaration();
    if (v && v->canassign)
        return 2;

    if (isParameter() || isResult())
    {
        for (Scope *scx = sc; scx; scx = scx->enclosing)
        {
            if (scx->func == parent && (scx->flags & SCOPEcontract))
            {
                const char *s = isParameter() && parent->ident != Id::ensure ? "parameter" : "result";
                if (!flag) error(loc, "cannot modify %s '%s' in contract", s, toChars());
                return 2;   // do not report type related errors
            }
        }
    }

    if (v && (isCtorinit() || isField()))
    {
        // It's only modifiable if inside the right constructor
        if ((storage_class & (STCforeach | STCref)) == (STCforeach | STCref))
            return 2;
        return modifyFieldVar(loc, sc, v, e1) ? 2 : 1;
    }
    return 1;
}

Dsymbol *Declaration::search(Loc loc, Identifier *ident, int flags)
{
    Dsymbol *s = Dsymbol::search(loc, ident, flags);
    if (!s && type)
    {
        s = type->toDsymbol(scope);
        if (s)
            s = s->search(loc, ident, flags);
    }
    return s;
}


/********************************* TupleDeclaration ****************************/

TupleDeclaration::TupleDeclaration(Loc loc, Identifier *id, Objects *objects)
    : Declaration(id)
{
    this->loc = loc;
    this->type = NULL;
    this->objects = objects;
    this->isexp = false;
    this->tupletype = NULL;
}

Dsymbol *TupleDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);
    return NULL;
}

const char *TupleDeclaration::kind()
{
    return "tuple";
}

Type *TupleDeclaration::getType()
{
    /* If this tuple represents a type, return that type
     */

    //printf("TupleDeclaration::getType() %s\n", toChars());
    if (isexp)
        return NULL;
    if (!tupletype)
    {
        /* It's only a type tuple if all the Object's are types
         */
        for (size_t i = 0; i < objects->dim; i++)
        {
            RootObject *o = (*objects)[i];
            if (o->dyncast() != DYNCAST_TYPE)
            {
                //printf("\tnot[%d], %p, %d\n", i, o, o->dyncast());
                return NULL;
            }
        }

        /* We know it's a type tuple, so build the TypeTuple
         */
        Types *types = (Types *)objects;
        Parameters *args = new Parameters();
        args->setDim(objects->dim);
        OutBuffer buf;
        int hasdeco = 1;
        for (size_t i = 0; i < types->dim; i++)
        {
            Type *t = (*types)[i];
            //printf("type = %s\n", t->toChars());
#if 0
            buf.printf("_%s_%d", ident->toChars(), i);
            char *name = (char *)buf.extractData();
            Identifier *id = new Identifier(name, TOKidentifier);
            Parameter *arg = new Parameter(STCin, t, id, NULL);
#else
            Parameter *arg = new Parameter(0, t, NULL, NULL);
#endif
            (*args)[i] = arg;
            if (!t->deco)
                hasdeco = 0;
        }

        tupletype = new TypeTuple(args);
        if (hasdeco)
            return tupletype->semantic(Loc(), NULL);
    }

    return tupletype;
}

bool TupleDeclaration::needThis()
{
    //printf("TupleDeclaration::needThis(%s)\n", toChars());
    for (size_t i = 0; i < objects->dim; i++)
    {
        RootObject *o = (*objects)[i];
        if (o->dyncast() == DYNCAST_EXPRESSION)
        {
            Expression *e = (Expression *)o;
            if (e->op == TOKdsymbol)
            {
                DsymbolExp *ve = (DsymbolExp *)e;
                Declaration *d = ve->s->isDeclaration();
                if (d && d->needThis())
                {
                    return true;
                }
            }
        }
    }
    return false;
}


/********************************* AliasDeclaration ****************************/

AliasDeclaration::AliasDeclaration(Loc loc, Identifier *id, Type *type)
    : Declaration(id)
{
    //printf("AliasDeclaration(id = '%s', type = %p)\n", id->toChars(), type);
    //printf("type = '%s'\n", type->toChars());
    this->loc = loc;
    this->type = type;
    this->aliassym = NULL;
    this->import = NULL;
    this->overnext = NULL;
    this->inSemantic = 0;
    assert(type);
}

AliasDeclaration::AliasDeclaration(Loc loc, Identifier *id, Dsymbol *s)
    : Declaration(id)
{
    //printf("AliasDeclaration(id = '%s', s = %p)\n", id->toChars(), s);
    assert(s != this);
    this->loc = loc;
    this->type = NULL;
    this->aliassym = s;
    this->import = NULL;
    this->overnext = NULL;
    this->inSemantic = 0;
    assert(s);
}

Dsymbol *AliasDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("AliasDeclaration::syntaxCopy()\n");
    assert(!s);
    AliasDeclaration *sa =
        type ? new AliasDeclaration(loc, ident, type->syntaxCopy())
             : new AliasDeclaration(loc, ident, aliassym->syntaxCopy(NULL));
    sa->storage_class = storage_class;
    return sa;
}

void AliasDeclaration::semantic(Scope *sc)
{
    //printf("AliasDeclaration::semantic() %s\n", toChars());
    if (aliassym)
    {
        if (aliassym->isTemplateInstance())
            aliassym->semantic(sc);
        return;
    }
    this->inSemantic = 1;

    storage_class |= sc->stc & STCdeprecated;
    protection = sc->protection;
    userAttribDecl = sc->userAttribDecl;

    // Given:
    //  alias foo.bar.abc def;
    // it is not knowable from the syntax whether this is an alias
    // for a type or an alias for a symbol. It is up to the semantic()
    // pass to distinguish.
    // If it is a type, then type is set and getType() will return that
    // type. If it is a symbol, then aliassym is set and type is NULL -
    // toAlias() will return aliasssym.

    unsigned int errors = global.errors;
    Type *savedtype = type;

    Dsymbol *s;
    Type *t;
    Expression *e;

    // Ungag errors when not instantiated DeclDefs scope alias
    Ungag ungag(global.gag);
    //printf("%s parent = %s, gag = %d, instantiated = %d\n", toChars(), parent, global.gag, isInstantiated());
    if (parent && global.gag && !isInstantiated() && !toParent2()->isFuncDeclaration())
    {
        //printf("%s type = %s\n", toPrettyChars(), type->toChars());
        global.gag = 0;
    }

    /* This section is needed because resolve() will:
     *   const x = 3;
     *   alias x y;
     * try to alias y to 3.
     */
    s = type->toDsymbol(sc);
    if (s && s == this)
    {
        error("cannot resolve");
        s = NULL;
        type = Type::terror;
    }
    if (s && ((s->getType() && type->equals(s->getType())) || s->isEnumMember()))
        goto L2;                        // it's a symbolic alias

    type = type->addSTC(storage_class);
    if (storage_class & (STCref | STCnothrow | STCnogc | STCpure | STCdisable))
    {
        // For 'ref' to be attached to function types, and picked
        // up by Type::resolve(), it has to go into sc.
        sc = sc->push();
        sc->stc |= storage_class & (STCref | STCnothrow | STCnogc | STCpure | STCshared | STCdisable);
        type->resolve(loc, sc, &e, &t, &s);
        sc = sc->pop();
    }
    else
        type->resolve(loc, sc, &e, &t, &s);
    if (s)
    {
        goto L2;
    }
    else if (e)
    {
        // Try to convert Expression to Dsymbol
        s = getDsymbol(e);
        if (s)
            goto L2;

        if (e->op != TOKerror)
            error("cannot alias an expression %s", e->toChars());
        t = e->type;
    }
    else if (t)
    {
        type = t->semantic(loc, sc);
        //printf("\talias resolved to type %s\n", type->toChars());
    }
    if (overnext)
        ScopeDsymbol::multiplyDefined(Loc(), overnext, this);
    this->inSemantic = 0;

    if (global.gag && errors != global.errors)
        type = savedtype;
    return;

  L2:
    //printf("alias is a symbol %s %s\n", s->kind(), s->toChars());
    type = NULL;
    VarDeclaration *v = s->isVarDeclaration();
    if (0 && v && v->linkage == LINKdefault)
    {
        error("forward reference of %s", v->toChars());
        s = NULL;
    }
    else
    {
        Dsymbol *savedovernext = overnext;
        Dsymbol *sa = s->toAlias();
        if (FuncDeclaration *fd = sa->isFuncDeclaration())
        {
            if (overnext)
            {
                FuncAliasDeclaration *fa = new FuncAliasDeclaration(fd);
                if (!fa->overloadInsert(overnext))
                    ScopeDsymbol::multiplyDefined(Loc(), overnext, fd);
                overnext = NULL;
                s = fa;
                s->parent = sc->parent;
            }
        }
        else if (TemplateDeclaration *td = sa->isTemplateDeclaration())
        {
            if (overnext)
            {
                OverDeclaration *od = new OverDeclaration(td);
                if (!od->overloadInsert(overnext))
                    ScopeDsymbol::multiplyDefined(Loc(), overnext, td);
                overnext = NULL;
                s = od;
                s->parent = sc->parent;
            }
        }
        else if (OverDeclaration *od = sa->isOverDeclaration())
        {
            if (overnext)
            {
                OverDeclaration *od2 = new OverDeclaration(od);
                if (!od2->overloadInsert(overnext))
                    ScopeDsymbol::multiplyDefined(Loc(), overnext, od);
                overnext = NULL;
                s = od2;
                s->parent = sc->parent;
            }
        }
        else if (OverloadSet *os = sa->isOverloadSet())
        {
            if (overnext)
            {
                os->push(overnext);
                overnext = NULL;
                s = os;
                s->parent = sc->parent;
            }
        }
        if (overnext)
            ScopeDsymbol::multiplyDefined(Loc(), overnext, this);
        if (s == this)
        {
            assert(global.errors);
            s = NULL;
        }
        if (global.gag && errors != global.errors)
        {
            type = savedtype;
            overnext = savedovernext;
            s = NULL;
        }
    }
    //printf("setting aliassym %s to %s %s\n", toChars(), s->kind(), s->toChars());
    aliassym = s;
    this->inSemantic = 0;
}

bool AliasDeclaration::overloadInsert(Dsymbol *s)
{
    /* Don't know yet what the aliased symbol is, so assume it can
     * be overloaded and check later for correctness.
     */

    //printf("AliasDeclaration::overloadInsert('%s')\n", s->toChars());
    if (aliassym) // see test/test56.d
    {
        Dsymbol *sa = aliassym->toAlias();
        if (FuncDeclaration *fd = sa->isFuncDeclaration())
        {
            FuncAliasDeclaration *fa = new FuncAliasDeclaration(fd);
            aliassym = fa;
            return fa->overloadInsert(s);
        }
        if (TemplateDeclaration *td = sa->isTemplateDeclaration())
        {
            OverDeclaration *od = new OverDeclaration(td);
            aliassym = od;
            return od->overloadInsert(s);
        }
    }

    if (overnext == NULL)
    {
        if (s == this)
        {
            return true;
        }
        overnext = s;
        return true;
    }
    else
    {
        return overnext->overloadInsert(s);
    }
}

const char *AliasDeclaration::kind()
{
    return "alias";
}

Type *AliasDeclaration::getType()
{
    if (type)
        return type;
    return toAlias()->getType();
}

Dsymbol *AliasDeclaration::toAlias()
{
    //printf("[%s] AliasDeclaration::toAlias('%s', this = %p, aliassym = %p, kind = '%s', inSemantic = %d)\n",
    //    loc.toChars(), toChars(), this, aliassym, aliassym ? aliassym->kind() : "", inSemantic);
    assert(this != aliassym);
    //static int count; if (++count == 10) *(char*)0=0;
    if (inSemantic == 1 && type && scope)
    {
        inSemantic = 2;
        unsigned olderrors = global.errors;
        Dsymbol *s = type->toDsymbol(scope);
        //printf("[%s] type = %s, s = %p, this = %p\n", loc.toChars(), type->toChars(), s, this);
        if (global.errors != olderrors)
            goto Lerr;
        if (s)
        {
            s = s->toAlias();
            if (global.errors != olderrors)
                goto Lerr;
            aliassym = s;
            inSemantic = 0;
        }
        else
        {
            Type *t = type->semantic(loc, scope);
            if (t->ty == Terror)
                goto Lerr;
            if (global.errors != olderrors)
                goto Lerr;
            //printf("t = %s\n", t->toChars());
            inSemantic = 0;
        }
    }
    if (inSemantic)
    {
        error("recursive alias declaration");

    Lerr:
        // Avoid breaking "recursive alias" state during errors gagged
        if (global.gag)
            return this;

        aliassym = new AliasDeclaration(loc, ident, Type::terror);
        type = Type::terror;
        return aliassym;
    }

    if (aliassym || type->deco)
        ;   // semantic is already done.
    else if (import && import->scope)
    {
        /* If this is an internal alias for selective/renamed import,
         * resolve it under the correct scope.
         */
        import->semantic(NULL);
    }
    else if (scope)
        semantic(scope);
    inSemantic = 1;
    Dsymbol *s = aliassym ? aliassym->toAlias() : this;
    inSemantic = 0;
    return s;
}

/****************************** OverDeclaration **************************/

OverDeclaration::OverDeclaration(Dsymbol *s, bool hasOverloads)
    : Declaration(s->ident)
{
    this->aliassym = s;

    this->hasOverloads = hasOverloads;
    if (hasOverloads)
    {
        if (OverDeclaration *od = aliassym->isOverDeclaration())
            this->hasOverloads = od->hasOverloads;
    }
    else
    {
        // for internal use
        assert(!aliassym->isOverDeclaration());
    }
}

const char *OverDeclaration::kind()
{
    return "overload alias";    // todo
}

void OverDeclaration::semantic(Scope *sc)
{
}

bool OverDeclaration::equals(RootObject *o)
{
    if (this == o)
        return true;

    Dsymbol *s = isDsymbol(o);
    if (!s)
        return false;

    OverDeclaration *od1 = this;
    if (OverDeclaration *od2 = s->isOverDeclaration())
    {
        return od1->aliassym->equals(od2->aliassym) &&
               od1->hasOverloads == od2->hasOverloads;
    }
    if (aliassym == s)
    {
        if (hasOverloads)
            return true;
        if (FuncDeclaration *fd = s->isFuncDeclaration())
        {
            return fd->isUnique() != NULL;
        }
        if (TemplateDeclaration *td = s->isTemplateDeclaration())
        {
            return td->overnext == NULL;
        }
    }
    return false;
}

bool OverDeclaration::overloadInsert(Dsymbol *s)
{
    //printf("OverDeclaration::overloadInsert('%s') aliassym = %p, overnext = %p\n", s->toChars(), aliassym, overnext);
    if (overnext == NULL)
    {
        if (s == this)
        {
            return true;
        }
        overnext = s;
        return true;
    }
    else
    {
        return overnext->overloadInsert(s);
    }
}

Dsymbol *OverDeclaration::toAlias()
{
    return this;
}

Dsymbol *OverDeclaration::isUnique()
{
    if (!hasOverloads)
    {
        if (aliassym->isFuncDeclaration() ||
            aliassym->isTemplateDeclaration())
        {
            return aliassym;
        }
    }

  struct ParamUniqueSym
  {
    static int fp(void *param, Dsymbol *s)
    {
        Dsymbol **ps = (Dsymbol **)param;
        if (*ps)
        {
            *ps = NULL;
            return 1;   // ambiguous, done
        }
        else
        {
            *ps = s;
            return 0;
        }
    }
  };
    Dsymbol *result = NULL;
    overloadApply(aliassym, &result, &ParamUniqueSym::fp);
    return result;
}

/********************************* VarDeclaration ****************************/

VarDeclaration::VarDeclaration(Loc loc, Type *type, Identifier *id, Initializer *init)
    : Declaration(id)
{
    //printf("VarDeclaration('%s')\n", id->toChars());
    assert(id);
#ifdef DEBUG
    if (!type && !init)
    {
        printf("VarDeclaration('%s')\n", id->toChars());
        //*(char*)0=0;
    }
#endif
    assert(type || init);
    this->type = type;
    this->init = init;
    this->loc = loc;
    offset = 0;
    noscope = 0;
    isargptr = false;
    alignment = 0;
    ctorinit = 0;
    aliassym = NULL;
    onstack = 0;
    canassign = 0;
    overlapped = false;
    lastVar = NULL;
    ctfeAdrOnStack = -1;
    rundtor = NULL;
    edtor = NULL;
    range = NULL;
}

Dsymbol *VarDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("VarDeclaration::syntaxCopy(%s)\n", toChars());
    assert(!s);
    VarDeclaration *v = new VarDeclaration(loc,
            type ? type->syntaxCopy() : NULL,
            ident,
            init ? init->syntaxCopy() : NULL);
    v->storage_class = storage_class;
    return v;
}


void VarDeclaration::semantic(Scope *sc)
{
#if 0
    printf("VarDeclaration::semantic('%s', parent = '%s') sem = %d\n", toChars(), sc->parent ? sc->parent->toChars() : NULL, sem);
    printf(" type = %s\n", type ? type->toChars() : "null");
    printf(" stc = x%x\n", sc->stc);
    printf(" storage_class = x%llx\n", storage_class);
    printf("linkage = %d\n", sc->linkage);
    //if (strcmp(toChars(), "mul") == 0) halt();
#endif

//    if (sem > SemanticStart)
//      return;
//    sem = SemanticIn;

    if (sem >= SemanticDone)
        return;

    Scope *scx = NULL;
    if (scope)
    {
        sc = scope;
        scx = sc;
        scope = NULL;
    }

    /* Pick up storage classes from context, but skip synchronized
     */
    storage_class |= (sc->stc & ~STCsynchronized);
    if (storage_class & STCextern && init)
        error("extern symbols cannot have initializers");

    userAttribDecl = sc->userAttribDecl;

    AggregateDeclaration *ad = isThis();
    if (ad)
        storage_class |= ad->storage_class & STC_TYPECTOR;

    /* If auto type inference, do the inference
     */
    int inferred = 0;
    if (!type)
    {
        inuse++;

        // Infering the type requires running semantic,
        // so mark the scope as ctfe if required
        bool needctfe = (storage_class & (STCmanifest | STCstatic)) != 0;
        if (needctfe) sc = sc->startCTFE();

        //printf("inferring type for %s with init %s\n", toChars(), init->toChars());
        init = init->inferType(sc);
        type = init->toExpression()->type;

        if (needctfe) sc = sc->endCTFE();

        inuse--;
        inferred = 1;

        /* This is a kludge to support the existing syntax for RAII
         * declarations.
         */
        storage_class &= ~STCauto;
        originalType = type->syntaxCopy();
    }
    else
    {
        if (!originalType)
            originalType = type->syntaxCopy();

        /* Prefix function attributes of variable declaration can affect
         * its type:
         *      pure nothrow void function() fp;
         *      static assert(is(typeof(fp) == void function() pure nothrow));
         */
        Scope *sc2 = sc->push();
        sc2->stc |= (storage_class & STC_FUNCATTR);
        inuse++;
        type = type->semantic(loc, sc2);
        inuse--;
        sc2->pop();
    }
    //printf(" semantic type = %s\n", type ? type->toChars() : "null");

    type->checkDeprecated(loc, sc);
    linkage = sc->linkage;
    this->parent = sc->parent;
    //printf("this = %p, parent = %p, '%s'\n", this, parent, parent->toChars());
    protection = sc->protection;

    /* If scope's alignment is the default, use the type's alignment,
     * otherwise the scope overrrides.
     */
    alignment = sc->structalign;
    if (alignment == STRUCTALIGN_DEFAULT)
        alignment = type->alignment();          // use type's alignment

    //printf("sc->stc = %x\n", sc->stc);
    //printf("storage_class = x%x\n", storage_class);

    // Calculate type size + safety checks
    if (sc->func && !sc->intypeof && !isMember())
    {
        if (storage_class & STCgshared)
        {
            if (sc->func->setUnsafe())
                error("__gshared not allowed in safe functions; use shared");
        }
        if (init && init->isVoidInitializer() &&
            type->hasPointers())    // get type size
        {
            if (sc->func->setUnsafe())
                error("void initializers for pointers not allowed in safe functions");
        }
    }

    Dsymbol *parent = toParent();

    Type *tb = type->toBasetype();
    Type *tbn = tb->baseElemOf();
    if (tb->ty == Tvoid && !(storage_class & STClazy))
    {
        if (inferred)
        {
            error("type %s is inferred from initializer %s, and variables cannot be of type void",
                type->toChars(), init->toChars());
        }
        else
            error("variables cannot be of type void");
        type = Type::terror;
        tb = type;
    }
    if (tb->ty == Tfunction)
    {
        error("cannot be declared to be a function");
        type = Type::terror;
        tb = type;
    }
    if (tb->ty == Tstruct)
    {
        TypeStruct *ts = (TypeStruct *)tb;
        if (!ts->sym->members)
        {
            error("no definition of struct %s", ts->toChars());
        }
    }
    if ((storage_class & STCauto) && !inferred)
        error("storage class 'auto' has no effect if type is not inferred, did you mean 'scope'?");

    if (tb->ty == Ttuple)
    {
        /* Instead, declare variables for each of the tuple elements
         * and add those.
         */
        TypeTuple *tt = (TypeTuple *)tb;
        size_t nelems = Parameter::dim(tt->arguments);
        Expression *ie = (init && !init->isVoidInitializer()) ? init->toExpression() : NULL;
        if (ie) ie = ie->semantic(sc);

        if (nelems > 0 && ie)
        {
            Expressions *iexps = new Expressions();
            iexps->push(ie);

            Expressions *exps = new Expressions();

            for (size_t pos = 0; pos < iexps->dim; pos++)
            {
            Lexpand1:
                Expression *e = (*iexps)[pos];
                Parameter *arg = Parameter::getNth(tt->arguments, pos);
                arg->type = arg->type->semantic(loc, sc);
                //printf("[%d] iexps->dim = %d, ", pos, iexps->dim);
                //printf("e = (%s %s, %s), ", Token::tochars[e->op], e->toChars(), e->type->toChars());
                //printf("arg = (%s, %s)\n", arg->toChars(), arg->type->toChars());

                if (e != ie)
                {
                if (iexps->dim > nelems)
                    goto Lnomatch;
                if (e->type->implicitConvTo(arg->type))
                    continue;
                }

                if (e->op == TOKtuple)
                {
                    TupleExp *te = (TupleExp *)e;
                    if (iexps->dim - 1 + te->exps->dim > nelems)
                        goto Lnomatch;

                    iexps->remove(pos);
                    iexps->insert(pos, te->exps);
                    (*iexps)[pos] = Expression::combine(te->e0, (*iexps)[pos]);
                    goto Lexpand1;
                }
                else if (isAliasThisTuple(e))
                {
                    Identifier *id = Identifier::generateId("__tup");
                    ExpInitializer *ei = new ExpInitializer(e->loc, e);
                    VarDeclaration *v = new VarDeclaration(loc, NULL, id, ei);
                    v->storage_class = STCtemp | STCctfe | STCref | STCforeach;
                    VarExp *ve = new VarExp(loc, v);
                    ve->type = e->type;

                    exps->setDim(1);
                    (*exps)[0] = ve;
                    expandAliasThisTuples(exps, 0);

                    for (size_t u = 0; u < exps->dim ; u++)
                    {
                    Lexpand2:
                        Expression *ee = (*exps)[u];
                        arg = Parameter::getNth(tt->arguments, pos + u);
                        arg->type = arg->type->semantic(loc, sc);
                        //printf("[%d+%d] exps->dim = %d, ", pos, u, exps->dim);
                        //printf("ee = (%s %s, %s), ", Token::tochars[ee->op], ee->toChars(), ee->type->toChars());
                        //printf("arg = (%s, %s)\n", arg->toChars(), arg->type->toChars());

                        size_t iexps_dim = iexps->dim - 1 + exps->dim;
                        if (iexps_dim > nelems)
                            goto Lnomatch;
                        if (ee->type->implicitConvTo(arg->type))
                            continue;

                        if (expandAliasThisTuples(exps, u) != -1)
                            goto Lexpand2;
                    }

                    if ((*exps)[0] != ve)
                    {
                        Expression *e0 = (*exps)[0];
                        (*exps)[0] = new CommaExp(loc, new DeclarationExp(loc, v), e0);
                        (*exps)[0]->type = e0->type;

                        iexps->remove(pos);
                        iexps->insert(pos, exps);
                        goto Lexpand1;
                    }
                }
            }
            if (iexps->dim < nelems)
                goto Lnomatch;

            ie = new TupleExp(init->loc, iexps);
        }
Lnomatch:

        if (ie && ie->op == TOKtuple)
        {
            TupleExp *te = (TupleExp *)ie;
            size_t tedim = te->exps->dim;
            if (tedim != nelems)
            {
                ::error(loc, "tuple of %d elements cannot be assigned to tuple of %d elements", (int)tedim, (int)nelems);
                for (size_t u = tedim; u < nelems; u++) // fill dummy expression
                    te->exps->push(new ErrorExp());
            }
        }

        Objects *exps = new Objects();
        exps->setDim(nelems);
        for (size_t i = 0; i < nelems; i++)
        {
            Parameter *arg = Parameter::getNth(tt->arguments, i);

            OutBuffer buf;
            buf.printf("__%s_field_%llu", ident->toChars(), (ulonglong)i);
            const char *name = buf.extractString();
            Identifier *id = Identifier::idPool(name);

            Initializer *ti;
            if (ie)
            {
                Expression *einit = ie;
                if (ie->op == TOKtuple)
                {
                    TupleExp *te = (TupleExp *)ie;
                    einit = (*te->exps)[i];
                    if (i == 0)
                        einit = Expression::combine(te->e0, einit);
                }
                ti = new ExpInitializer(einit->loc, einit);
            }
            else
                ti = init ? init->syntaxCopy() : NULL;

            VarDeclaration *v = new VarDeclaration(loc, arg->type, id, ti);
            v->storage_class |= STCtemp | storage_class;
            if (arg->storageClass & STCparameter)
                v->storage_class |= arg->storageClass;
            //printf("declaring field %s of type %s\n", v->toChars(), v->type->toChars());
            v->semantic(sc);

            if (sc->scopesym)
            {
                //printf("adding %s to %s\n", v->toChars(), sc->scopesym->toChars());
                if (sc->scopesym->members)
                    sc->scopesym->members->push(v);
            }

            Expression *e = new DsymbolExp(loc, v);
            (*exps)[i] = e;
        }
        TupleDeclaration *v2 = new TupleDeclaration(loc, ident, exps);
        v2->parent = this->parent;
        v2->isexp = true;
        aliassym = v2;
        sem = SemanticDone;
        return;
    }

    /* Storage class can modify the type
     */
    type = type->addStorageClass(storage_class);

    /* Adjust storage class to reflect type
     */
    if (type->isConst())
    {
        storage_class |= STCconst;
        if (type->isShared())
            storage_class |= STCshared;
    }
    else if (type->isImmutable())
        storage_class |= STCimmutable;
    else if (type->isShared())
        storage_class |= STCshared;
    else if (type->isWild())
        storage_class |= STCwild;

    if (storage_class & (STCmanifest | STCstatic | STCgshared))
    {
    }
    else if (isSynchronized())
    {
        error("variable %s cannot be synchronized", toChars());
    }
    else if (isOverride())
    {
        error("override cannot be applied to variable");
    }
    else if (isAbstract())
    {
        error("abstract cannot be applied to variable");
    }
    else if (storage_class & STCfinal)
    {
        error("final cannot be applied to variable, perhaps you meant const?");
    }

    if (storage_class & (STCstatic | STCextern | STCmanifest | STCtemplateparameter | STCtls | STCgshared | STCctfe))
    {
    }
    else
    {
        AggregateDeclaration *aad = parent->isAggregateDeclaration();
        if (aad)
        {
            if (global.params.vfield &&
                storage_class & (STCconst | STCimmutable) && init && !init->isVoidInitializer())
            {
                const char *p = loc.toChars();
                const char *s = (storage_class & STCimmutable) ? "immutable" : "const";
                fprintf(global.stdmsg, "%s: %s.%s is %s field\n", p ? p : "", ad->toPrettyChars(), toChars(), s);
            }
            storage_class |= STCfield;
            if (tbn->ty == Tstruct && ((TypeStruct *)tbn)->sym->noDefaultCtor)
            {
                if (!isThisDeclaration() && !init)
                    aad->noDefaultCtor = true;
            }
        }

        InterfaceDeclaration *id = parent->isInterfaceDeclaration();
        if (id)
        {
            error("field not allowed in interface");
        }

        /* Templates cannot add fields to aggregates
         */
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
            AggregateDeclaration *ad2 = ti->tempdecl->isMember();
            if (ad2 && storage_class != STCundefined)
            {
                error("cannot use template to add field to aggregate '%s'", ad2->toChars());
            }
        }
    }

    if ((storage_class & (STCref | STCparameter | STCforeach)) == STCref &&
        ident != Id::This)
    {
        error("only parameters or foreach declarations can be ref");
    }

    if (type->hasWild())
    {
        if (storage_class & (STCstatic | STCextern | STCtls | STCgshared | STCmanifest | STCfield) ||
            isDataseg()
            )
        {
            error("only parameters or stack based variables can be inout");
        }
        FuncDeclaration *func = sc->func;
        if (func)
        {
            if (func->fes)
                func = func->fes->func;
            bool isWild = false;
            for (FuncDeclaration *fd = func; fd; fd = fd->toParent2()->isFuncDeclaration())
            {
                if (((TypeFunction *)fd->type)->iswild)
                {
                    isWild = true;
                    break;
                }
            }
            if (!isWild)
            {
                error("inout variables can only be declared inside inout functions");
            }
        }
    }

    if (!(storage_class & (STCctfe | STCref | STCresult)) && tbn->ty == Tstruct &&
        ((TypeStruct *)tbn)->sym->noDefaultCtor)
    {
        if (!init)
        {
            if (isField())
            {
                /* For fields, we'll check the constructor later to make sure it is initialized
                 */
                storage_class |= STCnodefaultctor;
            }
            else if (storage_class & STCparameter)
                ;
            else
                error("default construction is disabled for type %s", type->toChars());
        }
    }

    FuncDeclaration *fd = parent->isFuncDeclaration();
    if (type->isscope() && !noscope)
    {
        if (storage_class & (STCfield | STCout | STCref | STCstatic | STCmanifest | STCtls | STCgshared) || !fd)
        {
            error("globals, statics, fields, manifest constants, ref and out parameters cannot be scope");
        }

        if (!(storage_class & STCscope))
        {
            if (!(storage_class & STCparameter) && ident != Id::withSym)
                error("reference to scope class must be scope");
        }
    }

    if (!init && !fd)
    {
        // If not mutable, initializable by constructor only
        storage_class |= STCctorinit;
    }

    if (init)
        storage_class |= STCinit;     // remember we had an explicit initializer
    else if (storage_class & STCmanifest)
        error("manifest constants must have initializers");

    bool isBlit = false;
    if (!init && !sc->inunion && !(storage_class & (STCstatic | STCgshared | STCextern)) && fd &&
        (!(storage_class & (STCfield | STCin | STCforeach | STCparameter | STCresult))
         || (storage_class & STCout)) &&
        type->size() != 0)
    {
        // Provide a default initializer
        //printf("Providing default initializer for '%s'\n", toChars());
        if (type->needsNested())
        {
            Type *tv = type;
            while (tv->toBasetype()->ty == Tsarray)
                tv = tv->toBasetype()->nextOf();
            assert(tv->toBasetype()->ty == Tstruct);

            /* Nested struct requires valid enclosing frame pointer.
             * In StructLiteralExp::toElem(), it's calculated.
             */

            checkFrameAccess(loc, sc, ((TypeStruct *)tv->toBasetype())->sym);

            Expression *e = tv->defaultInitLiteral(loc);
            Expression *e1 = new VarExp(loc, this);
            e = new BlitExp(loc, e1, e);
            e = e->semantic(sc);
            init = new ExpInitializer(loc, e);
            goto Ldtor;
        }
        else if (type->ty == Tstruct &&
            ((TypeStruct *)type)->sym->zeroInit == 1)
        {
            /* If a struct is all zeros, as a special case
             * set it's initializer to the integer 0.
             * In AssignExp::toElem(), we check for this and issue
             * a memset() to initialize the struct.
             * Must do same check in interpreter.
             */
            Expression *e = new IntegerExp(loc, 0, Type::tint32);
            Expression *e1;
            e1 = new VarExp(loc, this);
            e = new BlitExp(loc, e1, e);
            e->type = e1->type;         // don't type check this, it would fail
            init = new ExpInitializer(loc, e);
            goto Ldtor;
        }
        else if (type->baseElemOf()->ty == Tvoid)
        {
            error("%s does not have a default initializer", type->toChars());
        }
        else
        {
            init = getExpInitializer();
        }
        // Default initializer is always a blit
        isBlit = true;
    }

    if (init)
    {
        sc = sc->push();
        sc->stc &= ~(STC_TYPECTOR | STCpure | STCnothrow | STCnogc | STCref | STCdisable);

        ExpInitializer *ei = init->isExpInitializer();
        if (ei)     // Bugzilla 13424: Preset the required type to fail in FuncLiteralDeclaration::semantic3
            ei->exp = inferType(ei->exp, type);

        // If inside function, there is no semantic3() call
        if (sc->func || sc->intypeof == 1)
        {
            // If local variable, use AssignExp to handle all the various
            // possibilities.
            if (fd &&
                !(storage_class & (STCmanifest | STCstatic | STCtls | STCgshared | STCextern)) &&
                !init->isVoidInitializer())
            {
                //printf("fd = '%s', var = '%s'\n", fd->toChars(), toChars());
                if (!ei)
                {
                    ArrayInitializer *ai = init->isArrayInitializer();
                    Expression *e;
                    if (ai && tb->ty == Taarray)
                        e = ai->toAssocArrayLiteral();
                    else
                        e = init->toExpression();
                    if (!e)
                    {
                        // Run semantic, but don't need to interpret
                        init = init->semantic(sc, type, INITnointerpret);
                        e = init->toExpression();
                        if (!e)
                        {
                            error("is not a static and cannot have static initializer");
                            return;
                        }
                    }
                    ei = new ExpInitializer(init->loc, e);
                    init = ei;
                }

                Expression *e1 = new VarExp(loc, this);
                if (isBlit)
                    ei->exp = new BlitExp(loc, e1, ei->exp);
                else
                    ei->exp = new ConstructExp(loc, e1, ei->exp);
                canassign++;
                ei->exp = ei->exp->semantic(sc);
                canassign--;
                ei->exp->optimize(WANTvalue);

                if (isScope())
                {
                    Expression *ex = ei->exp;
                    while (ex->op == TOKcomma)
                        ex = ((CommaExp *)ex)->e2;
                    if (ex->op == TOKblit || ex->op == TOKconstruct)
                        ex = ((AssignExp *)ex)->e2;
                    if (ex->op == TOKnew)
                    {
                        // See if initializer is a NewExp that can be allocated on the stack
                        NewExp *ne = (NewExp *)ex;
                        if (!(ne->newargs && ne->newargs->dim > 1) && type->toBasetype()->ty == Tclass)
                        {
                            ne->onstack = 1;
                            onstack = 1;
                            if (type->isBaseOf(ne->newtype->semantic(loc, sc), NULL))
                                onstack = 2;
                        }
                    }
                    else if (ex->op == TOKfunction)
                    {
                        // or a delegate that doesn't escape a reference to the function
                        FuncDeclaration *f = ((FuncExp *)ex)->fd;
                        f->tookAddressOf--;
                    }
                }
            }
            else
            {
                // Bugzilla 14166: Don't run CTFE for the temporary variables inside typeof
                init = init->semantic(sc, type, sc->intypeof == 1 ? INITnointerpret : INITinterpret);
            }
        }
        else if (parent->isAggregateDeclaration())
        {
            scope = scx ? scx : sc->copy();
            scope->setNoFree();
        }
        else if (storage_class & (STCconst | STCimmutable | STCmanifest) ||
                 type->isConst() || type->isImmutable())
        {
            /* Because we may need the results of a const declaration in a
             * subsequent type, such as an array dimension, before semantic2()
             * gets ordinarily run, try to run semantic2() now.
             * Ignore failure.
             */

            if (!inferred)
            {
                unsigned errors = global.errors;
                inuse++;
                if (ei)
                {
                    Expression *exp = ei->exp->syntaxCopy();

                    bool needctfe = isDataseg() || (storage_class & STCmanifest);
                    if (needctfe) sc = sc->startCTFE();
                    exp = exp->semantic(sc);
                    exp = resolveProperties(sc, exp);
                    if (needctfe) sc = sc->endCTFE();

                    Type *tb2 = type->toBasetype();
                    Type *ti = exp->type->toBasetype();

                    /* The problem is the following code:
                     *  struct CopyTest {
                     *     double x;
                     *     this(double a) { x = a * 10.0;}
                     *     this(this) { x += 2.0; }
                     *  }
                     *  const CopyTest z = CopyTest(5.3);  // ok
                     *  const CopyTest w = z;              // not ok, postblit not run
                     *  static assert(w.x == 55.0);
                     * because the postblit doesn't get run on the initialization of w.
                     */
                    if (ti->ty == Tstruct)
                    {
                        StructDeclaration *sd = ((TypeStruct *)ti)->sym;
                        /* Look to see if initializer involves a copy constructor
                         * (which implies a postblit)
                         */
                         // there is a copy constructor
                         // and exp is the same struct
                        if (sd->postblit &&
                            tb2->toDsymbol(NULL) == sd)
                        {
                            // The only allowable initializer is a (non-copy) constructor
                            if (exp->isLvalue())
                                error("of type struct %s uses this(this), which is not allowed in static initialization", tb2->toChars());
                        }
                    }
                    ei->exp = exp;
                }
                init = init->semantic(sc, type, INITinterpret);
                inuse--;
                if (global.errors > errors)
                {
                    init = new ErrorInitializer();
                    type = Type::terror;
                }
            }
            else
            {
                scope = scx ? scx : sc->copy();
                scope->setNoFree();
            }
        }
        sc = sc->pop();
    }

Ldtor:
    /* Build code to execute destruction, if necessary
     */
    edtor = callScopeDtor(sc);
    if (edtor)
    {
        if (sc->func && storage_class & (STCstatic | STCgshared))
            edtor = edtor->semantic(sc->module->scope);
        else
            edtor = edtor->semantic(sc);

#if 0 // currently disabled because of std.stdio.stdin, stdout and stderr
        if (isDataseg() && !(storage_class & STCextern))
            error("static storage variables cannot have destructors");
#endif
    }

    sem = SemanticDone;

    if (type->toBasetype()->ty == Terror)
        errors = true;
}

void VarDeclaration::semantic2(Scope *sc)
{
    if (sem < SemanticDone && inuse)
        return;

    //printf("VarDeclaration::semantic2('%s')\n", toChars());
        // Inside unions, default to void initializers
    if (!init && sc->inunion && !toParent()->isFuncDeclaration())
    {
        AggregateDeclaration *aad = parent->isAggregateDeclaration();
        if (aad)
        {
            if (aad->fields[0] == this)
            {
                int hasinit = 0;
                for (size_t i = 1; i < aad->fields.dim; i++)
                {
                    if (aad->fields[i]->init &&
                        !aad->fields[i]->init->isVoidInitializer())
                    {
                        hasinit = 1;
                        break;
                    }
                }
                if (!hasinit)
                    init = new ExpInitializer(loc, type->defaultInitLiteral(loc));
            }
            else
                init = new VoidInitializer(loc);
        }
    }
    if (init && !toParent()->isFuncDeclaration())
    {
        inuse++;
#if 0
        ExpInitializer *ei = init->isExpInitializer();
        if (ei)
        {
            ei->exp->print();
            printf("type = %p\n", ei->exp->type);
        }
#endif
        // Bugzilla 14166: Don't run CTFE for the temporary variables inside typeof
        init = init->semantic(sc, type, sc->intypeof == 1 ? INITnointerpret : INITinterpret);
        inuse--;
    }
    if (storage_class & STCmanifest)
    {
    #if 0
        if ((type->ty == Tclass)&&type->isMutable())
        {
            error("is mutable. Only const and immutable class enum are allowed, not %s", type->toChars());
        }
        else if (type->ty == Tpointer && type->nextOf()->ty == Tstruct && type->nextOf()->isMutable())
        {
            ExpInitializer *ei = init->isExpInitializer();
            if (ei->exp->op == TOKaddress && ((AddrExp *)ei->exp)->e1->op == TOKstructliteral)
            {
                error("is a pointer to mutable struct. Only pointers to const or immutable struct enum are allowed, not %s", type->toChars());
            }
        }
    #else
        if (type->ty == Tclass && init)
        {
            ExpInitializer *ei = init->isExpInitializer();
            if (ei->exp->op == TOKclassreference)
                error(": Unable to initialize enum with class or pointer to struct. Use static const variable instead.");
        }
        else if (type->ty == Tpointer && type->nextOf()->ty == Tstruct)
        {
            ExpInitializer *ei = init->isExpInitializer();
            if (ei && ei->exp->op == TOKaddress && ((AddrExp *)ei->exp)->e1->op == TOKstructliteral)
            {
                error(": Unable to initialize enum with class or pointer to struct. Use static const variable instead.");
            }
        }
    #endif
    }
    else if (init && isThreadlocal())
    {
        if ((type->ty == Tclass) && type->isMutable() && !type->isShared())
        {
            ExpInitializer *ei = init->isExpInitializer();
            if (ei && ei->exp->op == TOKclassreference)
                error("is mutable. Only const or immutable class thread local variable are allowed, not %s", type->toChars());
        }
        else if (type->ty == Tpointer && type->nextOf()->ty == Tstruct && type->nextOf()->isMutable() &&!type->nextOf()->isShared())
        {
            ExpInitializer *ei = init->isExpInitializer();
            if (ei && ei->exp->op == TOKaddress && ((AddrExp *)ei->exp)->e1->op == TOKstructliteral)
            {
                error("is a pointer to mutable struct. Only pointers to const, immutable or shared struct thread local variable are allowed, not %s", type->toChars());
            }
        }
    }
    sem = Semantic2Done;
}

void VarDeclaration::setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion)
{
    //printf("VarDeclaration::setFieldOffset(ad = %s) %s\n", ad->toChars(), toChars());

    if (aliassym)
    {
        // If this variable was really a tuple, set the offsets for the tuple fields
        TupleDeclaration *v2 = aliassym->isTupleDeclaration();
        assert(v2);
        for (size_t i = 0; i < v2->objects->dim; i++)
        {
            RootObject *o = (*v2->objects)[i];
            assert(o->dyncast() == DYNCAST_EXPRESSION);
            Expression *e = (Expression *)o;
            assert(e->op == TOKdsymbol);
            DsymbolExp *se = (DsymbolExp *)e;
            se->s->setFieldOffset(ad, poffset, isunion);
        }
        return;
    }

    if (!isField())
        return;
    assert(!(storage_class & (STCstatic | STCextern | STCparameter | STCtls)));

    /* Fields that are tuples appear both as part of TupleDeclarations and
     * as members. That means ignore them if they are already a field.
     */
    if (offset)
    {
        // already a field
        *poffset = ad->structsize;  // Bugzilla 13613
        return;
    }
    for (size_t i = 0; i < ad->fields.dim; i++)
    {
        if (ad->fields[i] == this)
        {
            // already a field
            *poffset = ad->structsize;  // Bugzilla 13613
            return;
        }
    }

    // Check for forward referenced types which will fail the size() call
    Type *t = type->toBasetype();
    if (storage_class & STCref)
    {
        // References are the size of a pointer
        t = Type::tvoidptr;
    }
    if (t->ty == Tstruct || t->ty == Tsarray)
    {
        Type *tv = t->baseElemOf();
        if (tv->ty == Tstruct)
        {
            TypeStruct *ts = (TypeStruct *)tv;
            if (ts->sym == ad)
            {
                const char *s = (t->ty == Tsarray) ? "static array of " : "";
                ad->error("cannot have field %s with %ssame struct type", toChars(), s);
                return;
            }
            if (ts->sym->sizeok != SIZEOKdone && ts->sym->scope)
                ts->sym->semantic(NULL);
            if (ts->sym->sizeok != SIZEOKdone)
            {
                ad->sizeok = SIZEOKfwd;         // cannot finish; flag as forward referenced
                return;
            }
        }
    }
    if (t->ty == Tident)
    {
        ad->sizeok = SIZEOKfwd;             // cannot finish; flag as forward referenced
        return;
    }
    if (t->ty == Terror)
        return;


    unsigned memsize      = (unsigned)t->size(loc);  // size of member
    unsigned memalignsize = Target::fieldalign(t);   // size of member for alignment purposes

    offset = AggregateDeclaration::placeField(poffset, memsize, memalignsize, alignment,
                &ad->structsize, &ad->alignsize, isunion);

    //printf("\t%s: memalignsize = %d\n", toChars(), memalignsize);

    //printf(" addField '%s' to '%s' at offset %d, size = %d\n", toChars(), ad->toChars(), offset, memsize);
    ad->fields.push(this);
}

const char *VarDeclaration::kind()
{
    return "variable";
}

Dsymbol *VarDeclaration::toAlias()
{
    //printf("VarDeclaration::toAlias('%s', this = %p, aliassym = %p)\n", toChars(), this, aliassym);
    assert(this != aliassym);
    Dsymbol *s = aliassym ? aliassym->toAlias() : this;
    return s;
}

AggregateDeclaration *VarDeclaration::isThis()
{
    AggregateDeclaration *ad = NULL;

    if (!(storage_class & (STCstatic | STCextern | STCmanifest | STCtemplateparameter |
                           STCtls | STCgshared | STCctfe)))
    {
        for (Dsymbol *s = this; s; s = s->parent)
        {
            ad = s->isMember();
            if (ad)
                break;
            if (!s->parent || !s->parent->isTemplateMixin()) break;
        }
    }
    return ad;
}

bool VarDeclaration::needThis()
{
    //printf("VarDeclaration::needThis(%s, x%x)\n", toChars(), storage_class);
    return isField();
}

bool VarDeclaration::isExport()
{
    return protection.kind == PROTexport;
}

bool VarDeclaration::isImportedSymbol()
{
    if (protection.kind == PROTexport && !init &&
        (storage_class & STCstatic || parent->isModule()))
        return true;
    return false;
}

void VarDeclaration::checkCtorConstInit()
{
#if 0 /* doesn't work if more than one static ctor */
    if (ctorinit == 0 && isCtorinit() && !isField())
        error("missing initializer in static constructor for const variable");
#endif
}

bool lambdaCheckForNestedRef(Expression *e, Scope *sc);

/************************************
 * Check to see if this variable is actually in an enclosing function
 * rather than the current one.
 * Returns true if error occurs.
 */
bool VarDeclaration::checkNestedReference(Scope *sc, Loc loc)
{
    //printf("VarDeclaration::checkNestedReference() %s\n", toChars());
    if (parent && !isDataseg() && parent != sc->parent &&
        !(storage_class & STCmanifest))
    {
        // The function that this variable is in
        FuncDeclaration *fdv = toParent()->isFuncDeclaration();
        // The current function
        FuncDeclaration *fdthis = sc->parent->isFuncDeclaration();

        if (fdv && fdthis && fdv != fdthis)
        {
            // Add fdthis to nestedrefs[] if not already there
            for (size_t i = 0; 1; i++)
            {
                if (i == nestedrefs.dim)
                {
                    nestedrefs.push(fdthis);
                    break;
                }
                if (nestedrefs[i] == fdthis)
                    break;
            }

            if (fdthis->ident != Id::ensure)
            {
                /* __ensure is always called directly,
                 * so it never becomes closure.
                 */

                //printf("\tfdv = %s\n", fdv->toChars());
                //printf("\tfdthis = %s\n", fdthis->toChars());

                if (loc.filename)
                {
                    int lv = fdthis->getLevel(loc, sc, fdv);
                    if (lv == -2)   // error
                        return true;
                    if (lv > 0 &&
                        fdv->isPureBypassingInference() >= PUREweak &&
                        fdthis->isPureBypassingInference() == PUREfwdref &&
                        fdthis->isInstantiated())
                    {
                        /* Bugzilla 9148 and 14039:
                         *  void foo() pure {
                         *    int x;
                         *    void bar()() {  // default is impure
                         *      x = 1;  // access to enclosing pure function context
                         *              // means that bar should have weak purity.
                         *    }
                         *  }
                         */
                        fdthis->flags &= ~FUNCFLAGpurityInprocess;
                        if (fdthis->type->ty == Tfunction)
                        {
                            TypeFunction *tf = (TypeFunction *)fdthis->type;
                            if (tf->deco)
                            {
                                tf = (TypeFunction *)tf->copy();
                                tf->purity = PUREfwdref;
                                tf->deco = NULL;
                                tf->deco = tf->merge()->deco;
                            }
                            else
                                tf->purity = PUREfwdref;
                            fdthis->type = tf;
                        }
                    }
                }

                // Function literals from fdthis to fdv must be delegates
                for (Dsymbol *s = fdthis; s && s != fdv; s = s->toParent2())
                {
                    // function literal has reference to enclosing scope is delegate
                    if (FuncLiteralDeclaration *fld = s->isFuncLiteralDeclaration())
                    {
                        fld->tok = TOKdelegate;
                    }
                }

                // Add this to fdv->closureVars[] if not already there
                for (size_t i = 0; 1; i++)
                {
                    if (i == fdv->closureVars.dim)
                    {
                        if (!sc->intypeof && !(sc->flags & SCOPEcompile))
                            fdv->closureVars.push(this);
                        break;
                    }
                    if (fdv->closureVars[i] == this)
                        break;
                }

                //printf("fdthis is %s\n", fdthis->toChars());
                //printf("var %s in function %s is nested ref\n", toChars(), fdv->toChars());
                // __dollar creates problems because it isn't a real variable Bugzilla 3326
                if (ident == Id::dollar)
                {
                    ::error(loc, "cannnot use $ inside a function literal");
                    return true;
                }

                if (ident == Id::withSym)       // Bugzilla 1759
                {
                    ExpInitializer *ez = init->isExpInitializer();
                    assert(ez);
                    Expression *e = ez->exp;
                    if (e->op == TOKconstruct || e->op == TOKblit)
                        e = ((AssignExp *)e)->e2;
                    return lambdaCheckForNestedRef(e, sc);
                }
            }
        }
    }
    return false;
}

/****************************
 * Get ExpInitializer for a variable, if there is one.
 */

ExpInitializer *VarDeclaration::getExpInitializer()
{
    ExpInitializer *ei;

    if (init)
        ei = init->isExpInitializer();
    else
    {
        Expression *e = type->defaultInit(loc);
        if (e)
            ei = new ExpInitializer(loc, e);
        else
            ei = NULL;
    }
    return ei;
}

/*******************************************
 * If variable has a constant expression initializer, get it.
 * Otherwise, return NULL.
 */

Expression *VarDeclaration::getConstInitializer(bool needFullType)
{
    assert(type && init);

    // Ungag errors when not speculative
    unsigned oldgag = global.gag;
    if (global.gag)
    {
        Dsymbol *sym = toParent()->isAggregateDeclaration();
        if (sym && !sym->isSpeculative())
            global.gag = 0;
    }

    if (scope)
    {
        inuse++;
        init = init->semantic(scope, type, INITinterpret);
        scope = NULL;
        inuse--;
    }
    Expression *e = init->toExpression(needFullType ? type : NULL);

    global.gag = oldgag;
    return e;
}

/*************************************
 * Return true if we can take the address of this variable.
 */

bool VarDeclaration::canTakeAddressOf()
{
    return !(storage_class & STCmanifest);
}


/*******************************
 * Does symbol go into data segment?
 * Includes extern variables.
 */

bool VarDeclaration::isDataseg()
{
#if 0
    printf("VarDeclaration::isDataseg(%p, '%s')\n", this, toChars());
    printf("%llx, isModule: %p, isTemplateInstance: %p\n", storage_class & (STCstatic | STCconst), parent->isModule(), parent->isTemplateInstance());
    printf("parent = '%s'\n", parent->toChars());
#endif
    if (!canTakeAddressOf())
        return false;
    Dsymbol *parent = toParent();
    if (!parent && !(storage_class & STCstatic))
    {
        error("forward referenced");
        type = Type::terror;
        return false;
    }
    return (storage_class & (STCstatic | STCextern | STCtls | STCgshared) ||
           parent->isModule() ||
           parent->isTemplateInstance());
}

/************************************
 * Does symbol go into thread local storage?
 */

bool VarDeclaration::isThreadlocal()
{
    //printf("VarDeclaration::isThreadlocal(%p, '%s')\n", this, toChars());
    /* Data defaults to being thread-local. It is not thread-local
     * if it is immutable, const or shared.
     */
    bool i = isDataseg() &&
        !(storage_class & (STCimmutable | STCconst | STCshared | STCgshared));
    //printf("\treturn %d\n", i);
    return i;
}

/********************************************
 * Can variable be read and written by CTFE?
 */

bool VarDeclaration::isCTFE()
{
    return (storage_class & STCctfe) != 0; // || !isDataseg();
}

bool VarDeclaration::hasPointers()
{
    //printf("VarDeclaration::hasPointers() %s, ty = %d\n", toChars(), type->ty);
    return (!isDataseg() && type->hasPointers());
}

/******************************************
 * Return true if variable needs to call the destructor.
 */

bool VarDeclaration::needsAutoDtor()
{
    //printf("VarDeclaration::needsAutoDtor() %s\n", toChars());

    if (noscope || !edtor)
        return false;

    return true;
}


/******************************************
 * If a variable has a scope destructor call, return call for it.
 * Otherwise, return NULL.
 */

Expression *VarDeclaration::callScopeDtor(Scope *sc)
{
    //printf("VarDeclaration::callScopeDtor() %s\n", toChars());

    // Destruction of STCfield's is handled by buildDtor()
    if (noscope || storage_class & (STCnodtor | STCref | STCout | STCfield))
    {
        return NULL;
    }

    Expression *e = NULL;

    // Destructors for structs and arrays of structs
    Type *tv = type->baseElemOf();
    if (tv->ty == Tstruct)
    {
        TypeStruct *ts = (TypeStruct *)tv;
        StructDeclaration *sd = ts->sym;
        if (sd->dtor)
        {
            if (type->toBasetype()->ty == Tsarray)
            {
                // Typeinfo.destroy(cast(void*)&v);
                Expression *ea = new SymOffExp(loc, this, 0, 0);
                ea = new CastExp(loc, ea, Type::tvoid->pointerTo());
                Expressions *args = new Expressions();
                args->push(ea);

                Expression *et = getTypeInfo(type, sc);
                et = new DotIdExp(loc, et, Id::destroy);

                e = new CallExp(loc, et, args);
            }
            else
            {
                e = new VarExp(loc, this);
                /* This is a hack so we can call destructors on const/immutable objects.
                 * Need to add things like "const ~this()" and "immutable ~this()" to
                 * fix properly.
                 */
                e->type = e->type->mutableOf();
                e = new DotVarExp(loc, e, sd->dtor, 0);
                e = new CallExp(loc, e);
            }
            return e;
        }
    }

    // Destructors for classes
    if (storage_class & (STCauto | STCscope))
    {
        for (ClassDeclaration *cd = type->isClassHandle();
             cd;
             cd = cd->baseClass)
        {
            /* We can do better if there's a way with onstack
             * classes to determine if there's no way the monitor
             * could be set.
             */
            //if (cd->isInterfaceDeclaration())
                //error("interface %s cannot be scope", cd->toChars());

            if (cd->cpp)
            {
                // Destructors are not supported on extern(C++) classes
                break;
            }
            if (1 || onstack || cd->dtors.dim)  // if any destructors
            {
                // delete this;
                Expression *ec;

                ec = new VarExp(loc, this);
                e = new DeleteExp(loc, ec);
                e->type = Type::tvoid;
                break;
            }
        }
    }
    return e;
}

/******************************************
 */

void ObjectNotFound(Identifier *id)
{
    Type::error(Loc(), "%s not found. object.d may be incorrectly installed or corrupt.", id->toChars());
    fatal();
}

/******************************** SymbolDeclaration ********************************/

SymbolDeclaration::SymbolDeclaration(Loc loc, StructDeclaration *dsym)
        : Declaration(dsym->ident)
{
    this->loc = loc;
    this->dsym = dsym;
    storage_class |= STCconst;
}

/********************************* ClassInfoDeclaration ****************************/

ClassInfoDeclaration::ClassInfoDeclaration(ClassDeclaration *cd)
    : VarDeclaration(Loc(), Type::typeinfoclass->type, cd->ident, NULL)
{
    this->cd = cd;
    storage_class = STCstatic | STCgshared;
}

Dsymbol *ClassInfoDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);          // should never be produced by syntax
    return NULL;
}

void ClassInfoDeclaration::semantic(Scope *sc)
{
}

/********************************* TypeInfoDeclaration ****************************/

TypeInfoDeclaration::TypeInfoDeclaration(Type *tinfo, int internal)
    : VarDeclaration(Loc(), Type::dtypeinfo->type, tinfo->getTypeInfoIdent(internal), NULL)
{
    this->tinfo = tinfo;
    storage_class = STCstatic | STCgshared;
    protection = Prot(PROTpublic);
    linkage = LINKc;
}

TypeInfoDeclaration *TypeInfoDeclaration::create(Type *tinfo, int internal)
{
    return new TypeInfoDeclaration(tinfo, internal);
}

Dsymbol *TypeInfoDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);          // should never be produced by syntax
    return NULL;
}

void TypeInfoDeclaration::semantic(Scope *sc)
{
    assert(linkage == LINKc);
}

char *TypeInfoDeclaration::toChars()
{
    //printf("TypeInfoDeclaration::toChars() tinfo = %s\n", tinfo->toChars());
    OutBuffer buf;
    buf.writestring("typeid(");
    buf.writestring(tinfo->toChars());
    buf.writeByte(')');
    return buf.extractString();
}

/***************************** TypeInfoConstDeclaration **********************/

TypeInfoConstDeclaration::TypeInfoConstDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoconst)
    {
        ObjectNotFound(Id::TypeInfo_Const);
    }
    type = Type::typeinfoconst->type;
}

TypeInfoConstDeclaration *TypeInfoConstDeclaration::create(Type *tinfo)
{
    return new TypeInfoConstDeclaration(tinfo);
}

/***************************** TypeInfoInvariantDeclaration **********************/

TypeInfoInvariantDeclaration::TypeInfoInvariantDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoinvariant)
    {
        ObjectNotFound(Id::TypeInfo_Invariant);
    }
    type = Type::typeinfoinvariant->type;
}

TypeInfoInvariantDeclaration *TypeInfoInvariantDeclaration::create(Type *tinfo)
{
    return new TypeInfoInvariantDeclaration(tinfo);
}

/***************************** TypeInfoSharedDeclaration **********************/

TypeInfoSharedDeclaration::TypeInfoSharedDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoshared)
    {
        ObjectNotFound(Id::TypeInfo_Shared);
    }
    type = Type::typeinfoshared->type;
}

TypeInfoSharedDeclaration *TypeInfoSharedDeclaration::create(Type *tinfo)
{
    return new TypeInfoSharedDeclaration(tinfo);
}

/***************************** TypeInfoWildDeclaration **********************/

TypeInfoWildDeclaration::TypeInfoWildDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfowild)
    {
        ObjectNotFound(Id::TypeInfo_Wild);
    }
    type = Type::typeinfowild->type;
}

TypeInfoWildDeclaration *TypeInfoWildDeclaration::create(Type *tinfo)
{
    return new TypeInfoWildDeclaration(tinfo);
}

/***************************** TypeInfoStructDeclaration **********************/

TypeInfoStructDeclaration::TypeInfoStructDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfostruct)
    {
        ObjectNotFound(Id::TypeInfo_Struct);
    }
    type = Type::typeinfostruct->type;
}

TypeInfoStructDeclaration *TypeInfoStructDeclaration::create(Type *tinfo)
{
    return new TypeInfoStructDeclaration(tinfo);
}

/***************************** TypeInfoClassDeclaration ***********************/

TypeInfoClassDeclaration::TypeInfoClassDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoclass)
    {
        ObjectNotFound(Id::TypeInfo_Class);
    }
    type = Type::typeinfoclass->type;
}

TypeInfoClassDeclaration *TypeInfoClassDeclaration::create(Type *tinfo)
{
    return new TypeInfoClassDeclaration(tinfo);
}

/***************************** TypeInfoInterfaceDeclaration *******************/

TypeInfoInterfaceDeclaration::TypeInfoInterfaceDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfointerface)
    {
        ObjectNotFound(Id::TypeInfo_Interface);
    }
    type = Type::typeinfointerface->type;
}

TypeInfoInterfaceDeclaration *TypeInfoInterfaceDeclaration::create(Type *tinfo)
{
    return new TypeInfoInterfaceDeclaration(tinfo);
}

/***************************** TypeInfoPointerDeclaration *********************/

TypeInfoPointerDeclaration::TypeInfoPointerDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfopointer)
    {
        ObjectNotFound(Id::TypeInfo_Pointer);
    }
    type = Type::typeinfopointer->type;
}

TypeInfoPointerDeclaration *TypeInfoPointerDeclaration::create(Type *tinfo)
{
    return new TypeInfoPointerDeclaration(tinfo);
}

/***************************** TypeInfoArrayDeclaration ***********************/

TypeInfoArrayDeclaration::TypeInfoArrayDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoarray)
    {
        ObjectNotFound(Id::TypeInfo_Array);
    }
    type = Type::typeinfoarray->type;
}

TypeInfoArrayDeclaration *TypeInfoArrayDeclaration::create(Type *tinfo)
{
    return new TypeInfoArrayDeclaration(tinfo);
}

/***************************** TypeInfoStaticArrayDeclaration *****************/

TypeInfoStaticArrayDeclaration::TypeInfoStaticArrayDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfostaticarray)
    {
        ObjectNotFound(Id::TypeInfo_StaticArray);
    }
    type = Type::typeinfostaticarray->type;
}

TypeInfoStaticArrayDeclaration *TypeInfoStaticArrayDeclaration::create(Type *tinfo)
{
    return new TypeInfoStaticArrayDeclaration(tinfo);
}

/***************************** TypeInfoAssociativeArrayDeclaration ************/

TypeInfoAssociativeArrayDeclaration::TypeInfoAssociativeArrayDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoassociativearray)
    {
        ObjectNotFound(Id::TypeInfo_AssociativeArray);
    }
    type = Type::typeinfoassociativearray->type;
}

TypeInfoAssociativeArrayDeclaration *TypeInfoAssociativeArrayDeclaration::create(Type *tinfo)
{
    return new TypeInfoAssociativeArrayDeclaration(tinfo);
}

/***************************** TypeInfoVectorDeclaration ***********************/

TypeInfoVectorDeclaration::TypeInfoVectorDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfovector)
    {
        ObjectNotFound(Id::TypeInfo_Vector);
    }
    type = Type::typeinfovector->type;
}

TypeInfoVectorDeclaration *TypeInfoVectorDeclaration::create(Type *tinfo)
{
    return new TypeInfoVectorDeclaration(tinfo);
}

/***************************** TypeInfoEnumDeclaration ***********************/

TypeInfoEnumDeclaration::TypeInfoEnumDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoenum)
    {
        ObjectNotFound(Id::TypeInfo_Enum);
    }
    type = Type::typeinfoenum->type;
}

TypeInfoEnumDeclaration *TypeInfoEnumDeclaration::create(Type *tinfo)
{
    return new TypeInfoEnumDeclaration(tinfo);
}

/***************************** TypeInfoFunctionDeclaration ********************/

TypeInfoFunctionDeclaration::TypeInfoFunctionDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfofunction)
    {
        ObjectNotFound(Id::TypeInfo_Function);
    }
    type = Type::typeinfofunction->type;
}

TypeInfoFunctionDeclaration *TypeInfoFunctionDeclaration::create(Type *tinfo)
{
    return new TypeInfoFunctionDeclaration(tinfo);
}

/***************************** TypeInfoDelegateDeclaration ********************/

TypeInfoDelegateDeclaration::TypeInfoDelegateDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfodelegate)
    {
        ObjectNotFound(Id::TypeInfo_Delegate);
    }
    type = Type::typeinfodelegate->type;
}

TypeInfoDelegateDeclaration *TypeInfoDelegateDeclaration::create(Type *tinfo)
{
    return new TypeInfoDelegateDeclaration(tinfo);
}

/***************************** TypeInfoTupleDeclaration **********************/

TypeInfoTupleDeclaration::TypeInfoTupleDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfotypelist)
    {
        ObjectNotFound(Id::TypeInfo_Tuple);
    }
    type = Type::typeinfotypelist->type;
}

TypeInfoTupleDeclaration *TypeInfoTupleDeclaration::create(Type *tinfo)
{
    return new TypeInfoTupleDeclaration(tinfo);
}

/********************************* ThisDeclaration ****************************/

// For the "this" parameter to member functions

ThisDeclaration::ThisDeclaration(Loc loc, Type *t)
   : VarDeclaration(loc, t, Id::This, NULL)
{
    noscope = 1;
}

Dsymbol *ThisDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);          // should never be produced by syntax
    return NULL;
}

