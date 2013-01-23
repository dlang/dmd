
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
#include "id.h"
#include "expression.h"
#include "statement.h"
#include "hdrgen.h"

AggregateDeclaration *isAggregate(Type *t); // from opover.c

void checkFrameAccess(Loc loc, Scope *sc, AggregateDeclaration *ad)
{
    if (!ad->isnested)
        return;

    Dsymbol *s = sc->func;
    if (s)
    {
        Dsymbol *sparent = ad->toParent2();
        //printf("ad = %p %s [%s], parent:%p\n", ad, ad->toChars(), ad->loc.toChars(), ad->parent);
        //printf("sparent = %p %s [%s], parent: %s\n", sparent, sparent->toChars(), sparent->loc.toChars(), sparent->parent->toChars());

        while (s)
        {
            if (s == sparent)   // hit!
            {
                // Is it better moving this check to AggregateDeclaration:semantic?
                for (size_t i = 0; i < ad->fields.dim; i++)
                {   VarDeclaration *vd = ad->fields[i]->isVarDeclaration();
                    if (vd)
                        if (AggregateDeclaration *ad2 = isAggregate(vd->type))
                            if (ad2->isStructDeclaration())
                                checkFrameAccess(loc, sc, ad2);
                }
                return;
            }

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
    }
    error(loc, "cannot access frame pointer of %s", ad->toPrettyChars());
}

/********************************* Declaration ****************************/

Declaration::Declaration(Identifier *id)
    : Dsymbol(id)
{
    type = NULL;
    originalType = NULL;
    storage_class = STCundefined;
    protection = PROTundefined;
    linkage = LINKdefault;
    inuse = 0;
    sem = SemanticStart;
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
    return type->size();
}

int Declaration::isDelete()
{
    return FALSE;
}

int Declaration::isDataseg()
{
    return FALSE;
}

int Declaration::isThreadlocal()
{
    return FALSE;
}

int Declaration::isCodeseg()
{
    return FALSE;
}

enum PROT Declaration::prot()
{
    return protection;
}

/*************************************
 * Check to see if declaration can be modified in this context (sc).
 * Issue error if not.
 */

#if DMDV2

int Declaration::checkModify(Loc loc, Scope *sc, Type *t)
{
    if ((sc->flags & SCOPEcontract) && isParameter())
        error(loc, "cannot modify parameter '%s' in contract", toChars());

    if ((sc->flags & SCOPEcontract) && isResult())
        error(loc, "cannot modify result '%s' in contract", toChars());

    if (isCtorinit() && !t->isMutable() ||
        (storage_class & STCnodefaultctor))
    {   // It's only modifiable if inside the right constructor
        return modifyFieldVar(loc, sc, isVarDeclaration(), NULL);
    }
    else
    {
        VarDeclaration *v = isVarDeclaration();
        if (v && v->canassign)
            return TRUE;
    }
    return FALSE;
}
#endif

Dsymbol *Declaration::search(Loc loc, Identifier *ident, int flags)
{
    Dsymbol *s = Dsymbol::search(loc, ident, flags);
    if (!s && type)
    {
        s = type->toDsymbol(NULL);
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
    this->isexp = 0;
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
        {   Object *o = (*objects)[i];

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
        {   Type *t = (*types)[i];

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
            return tupletype->semantic(0, NULL);
    }

    return tupletype;
}

int TupleDeclaration::needThis()
{
    //printf("TupleDeclaration::needThis(%s)\n", toChars());
    for (size_t i = 0; i < objects->dim; i++)
    {   Object *o = (*objects)[i];
        if (o->dyncast() == DYNCAST_EXPRESSION)
        {   Expression *e = (Expression *)o;
            if (e->op == TOKdsymbol)
            {   DsymbolExp *ve = (DsymbolExp *)e;
                Declaration *d = ve->s->isDeclaration();
                if (d && d->needThis())
                {
                    return 1;
                }
            }
        }
    }
    return 0;
}


/********************************* TypedefDeclaration ****************************/

TypedefDeclaration::TypedefDeclaration(Loc loc, Identifier *id, Type *basetype, Initializer *init)
    : Declaration(id)
{
    this->type = new TypeTypedef(this);
    this->basetype = basetype->toBasetype();
    this->init = init;
    this->htype = NULL;
    this->hbasetype = NULL;
    this->loc = loc;
    this->sinit = NULL;
}

Dsymbol *TypedefDeclaration::syntaxCopy(Dsymbol *s)
{
    Type *basetype = this->basetype->syntaxCopy();

    Initializer *init = NULL;
    if (this->init)
        init = this->init->syntaxCopy();

    assert(!s);
    TypedefDeclaration *st;
    st = new TypedefDeclaration(loc, ident, basetype, init);

    // Syntax copy for header file
    if (!htype)      // Don't overwrite original
    {   if (type)    // Make copy for both old and new instances
        {   htype = type->syntaxCopy();
            st->htype = type->syntaxCopy();
        }
    }
    else            // Make copy of original for new instance
        st->htype = htype->syntaxCopy();
    if (!hbasetype)
    {   if (basetype)
        {   hbasetype = basetype->syntaxCopy();
            st->hbasetype = basetype->syntaxCopy();
        }
    }
    else
        st->hbasetype = hbasetype->syntaxCopy();

    return st;
}

void TypedefDeclaration::semantic(Scope *sc)
{
    //printf("TypedefDeclaration::semantic(%s) sem = %d\n", toChars(), sem);
    userAttributes = sc->userAttributes;
    if (sem == SemanticStart)
    {   sem = SemanticIn;
        parent = sc->parent;
        int errors = global.errors;
        Type *savedbasetype = basetype;
        basetype = basetype->semantic(loc, sc);
        if (errors != global.errors)
        {
            basetype = savedbasetype;
            sem = SemanticStart;
            return;
        }
        sem = SemanticDone;
#if DMDV2
        type = type->addStorageClass(storage_class);
#endif
        Type *savedtype = type;
        type = type->semantic(loc, sc);
        if (sc->parent->isFuncDeclaration() && init)
            semantic2(sc);
        if (errors != global.errors)
        {
            basetype = savedbasetype;
            type = savedtype;
            sem = SemanticStart;
            return;
        }
        storage_class |= sc->stc & STCdeprecated;
        userAttributes = sc->userAttributes;
    }
    else if (sem == SemanticIn)
    {
        error("circular definition");
    }
}

void TypedefDeclaration::semantic2(Scope *sc)
{
    //printf("TypedefDeclaration::semantic2(%s) sem = %d\n", toChars(), sem);
    if (sem == SemanticDone)
    {   sem = Semantic2Done;
        if (init)
        {
            Initializer *savedinit = init;
            int errors = global.errors;
            init = init->semantic(sc, basetype, INITinterpret);
            if (errors != global.errors)
            {
                init = savedinit;
                return;
            }

            ExpInitializer *ie = init->isExpInitializer();
            if (ie)
            {
                if (ie->exp->type == basetype)
                    ie->exp->type = type;
            }
        }
    }
}

const char *TypedefDeclaration::kind()
{
    return "typedef";
}

Type *TypedefDeclaration::getType()
{
    return type;
}

void TypedefDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("typedef ");
    basetype->toCBuffer(buf, ident, hgs);
    if (init)
    {
        buf->writestring(" = ");
        init->toCBuffer(buf, hgs);
    }
    buf->writeByte(';');
    buf->writenl();
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
    this->htype = NULL;
    this->haliassym = NULL;
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
    this->htype = NULL;
    this->haliassym = NULL;
    this->overnext = NULL;
    this->inSemantic = 0;
    assert(s);
}

Dsymbol *AliasDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("AliasDeclaration::syntaxCopy()\n");
    assert(!s);
    AliasDeclaration *sa;
    if (type)
        sa = new AliasDeclaration(loc, ident, type->syntaxCopy());
    else
        sa = new AliasDeclaration(loc, ident, aliassym->syntaxCopy(NULL));
    sa->storage_class = storage_class;

    // Syntax copy for header file
    if (!htype)     // Don't overwrite original
    {   if (type)       // Make copy for both old and new instances
        {   htype = type->syntaxCopy();
            sa->htype = type->syntaxCopy();
        }
    }
    else                        // Make copy of original for new instance
        sa->htype = htype->syntaxCopy();
    if (!haliassym)
    {   if (aliassym)
        {   haliassym = aliassym->syntaxCopy(s);
            sa->haliassym = aliassym->syntaxCopy(s);
        }
    }
    else
        sa->haliassym = haliassym->syntaxCopy(s);

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

#if DMDV1   // don't really know why this is here
    if (storage_class & STCconst)
        error("cannot be const");
#endif

    storage_class |= sc->stc & STCdeprecated;
    protection = sc->protection;
    userAttributes = sc->userAttributes;

    // Given:
    //  alias foo.bar.abc def;
    // it is not knowable from the syntax whether this is an alias
    // for a type or an alias for a symbol. It is up to the semantic()
    // pass to distinguish.
    // If it is a type, then type is set and getType() will return that
    // type. If it is a symbol, then aliassym is set and type is NULL -
    // toAlias() will return aliasssym.

    int errors = global.errors;
    Type *savedtype = type;

    Dsymbol *s;
    Type *t;
    Expression *e;

    /* This section is needed because resolve() will:
     *   const x = 3;
     *   alias x y;
     * try to alias y to 3.
     */
    s = type->toDsymbol(sc);
    if (s
#if DMDV2
        && ((s->getType() && type->equals(s->getType())) || s->isEnumMember())
#endif
        )
        goto L2;                        // it's a symbolic alias

#if DMDV2
    type = type->addStorageClass(storage_class);
    if (storage_class & (STCref | STCnothrow | STCpure | STCdisable))
    {   // For 'ref' to be attached to function types, and picked
        // up by Type::resolve(), it has to go into sc.
        sc = sc->push();
        sc->stc |= storage_class & (STCref | STCnothrow | STCpure | STCshared | STCdisable);
        type->resolve(loc, sc, &e, &t, &s);
        sc = sc->pop();
    }
    else
#endif
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
        ScopeDsymbol::multiplyDefined(0, overnext, this);
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
        FuncDeclaration *f = s->toAlias()->isFuncDeclaration();
        if (f)
        {
            if (overnext)
            {
                FuncAliasDeclaration *fa = new FuncAliasDeclaration(f);
                if (!fa->overloadInsert(overnext))
                    ScopeDsymbol::multiplyDefined(0, overnext, f);
                overnext = NULL;
                s = fa;
                s->parent = sc->parent;
            }
        }
        OverloadSet *o = s->toAlias()->isOverloadSet();
        if (o)
        {
            if (overnext)
            {
                o->push(overnext);
                overnext = NULL;
                s = o;
                s->parent = sc->parent;
            }
        }
        if (overnext)
            ScopeDsymbol::multiplyDefined(0, overnext, this);
        if (s == this)
        {
            assert(global.errors);
            s = NULL;
        }
        if (global.gag && errors != global.errors)
        {
            type = savedtype;
            overnext = savedovernext;
            aliassym = NULL;
            inSemantic = 0;
            return;
        }
    }
    //printf("setting aliassym %s to %s %s\n", toChars(), s->kind(), s->toChars());
    aliassym = s;
    this->inSemantic = 0;
}

int AliasDeclaration::overloadInsert(Dsymbol *s)
{
    /* Don't know yet what the aliased symbol is, so assume it can
     * be overloaded and check later for correctness.
     */

    //printf("AliasDeclaration::overloadInsert('%s')\n", s->toChars());
    if (aliassym) // see test/test56.d
    {
        Dsymbol *a = aliassym->toAlias();
        FuncDeclaration *f = a->isFuncDeclaration();
        if (f)  // BUG: what if it's a template?
        {
            FuncAliasDeclaration *fa = new FuncAliasDeclaration(f);
            aliassym = fa;
            return fa->overloadInsert(s);
        }
    }

    if (overnext == NULL)
    {
        if (s == this)
        {
            return TRUE;
        }
        overnext = s;
        return TRUE;
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
    //printf("AliasDeclaration::toAlias('%s', this = %p, aliassym = %p, kind = '%s')\n", toChars(), this, aliassym, aliassym ? aliassym->kind() : "");
    assert(this != aliassym);
    //static int count; if (++count == 10) *(char*)0=0;
    if (inSemantic)
    {   error("recursive alias declaration");
        aliassym = new AliasDeclaration(loc, ident, Type::terror);
        type = Type::terror;
    }
    else if (aliassym || type->deco)
        ;   // semantic is already done.
    else if (scope)
        semantic(scope);
    Dsymbol *s = aliassym ? aliassym->toAlias() : this;
    return s;
}

void AliasDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("alias ");
#if 0
    if (hgs->hdrgen)
    {
        if (haliassym)
        {
            haliassym->toCBuffer(buf, hgs);
            buf->writeByte(' ');
            buf->writestring(ident->toChars());
        }
        else
            htype->toCBuffer(buf, ident, hgs);
    }
    else
#endif
    {
        if (aliassym)
        {
            aliassym->toCBuffer(buf, hgs);
            buf->writeByte(' ');
            buf->writestring(ident->toChars());
        }
        else
            type->toCBuffer(buf, ident, hgs);
    }
    buf->writeByte(';');
    buf->writenl();
}

/********************************* VarDeclaration ****************************/

VarDeclaration::VarDeclaration(Loc loc, Type *type, Identifier *id, Initializer *init)
    : Declaration(id)
{
    //printf("VarDeclaration('%s')\n", id->toChars());
#ifdef DEBUG
    if (!type && !init)
    {   printf("VarDeclaration('%s')\n", id->toChars());
        //*(char*)0=0;
    }
#endif
    assert(type || init);
    this->type = type;
    this->init = init;
    this->htype = NULL;
    this->hinit = NULL;
    this->loc = loc;
    offset = 0;
    noscope = 0;
#if DMDV2
    isargptr = FALSE;
#endif
#if DMDV1
    nestedref = 0;
#endif
    alignment = 0;
    ctorinit = 0;
    aliassym = NULL;
    onstack = 0;
    canassign = 0;
    ctfeAdrOnStack = -1;
#if DMDV2
    rundtor = NULL;
    edtor = NULL;
#endif
}

Dsymbol *VarDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("VarDeclaration::syntaxCopy(%s)\n", toChars());

    VarDeclaration *sv;
    if (s)
    {   sv = (VarDeclaration *)s;
    }
    else
    {
        Initializer *init = NULL;
        if (this->init)
        {   init = this->init->syntaxCopy();
            //init->isExpInitializer()->exp->print();
            //init->isExpInitializer()->exp->dump(0);
        }

        sv = new VarDeclaration(loc, type ? type->syntaxCopy() : NULL, ident, init);
        sv->storage_class = storage_class;
    }

    // Syntax copy for header file
    if (!htype)      // Don't overwrite original
    {   if (type)    // Make copy for both old and new instances
        {   htype = type->syntaxCopy();
            sv->htype = type->syntaxCopy();
        }
    }
    else            // Make copy of original for new instance
        sv->htype = htype->syntaxCopy();
    if (!hinit)
    {   if (init)
        {   hinit = init->syntaxCopy();
            sv->hinit = init->syntaxCopy();
        }
    }
    else
        sv->hinit = hinit->syntaxCopy();

    return sv;
}

void VarDeclaration::semantic(Scope *sc)
{
#if 0
    printf("VarDeclaration::semantic('%s', parent = '%s')\n", toChars(), sc->parent->toChars());
    printf(" type = %s\n", type ? type->toChars() : "null");
    printf(" stc = x%x\n", sc->stc);
    printf(" storage_class = x%llx\n", storage_class);
    printf("linkage = %d\n", sc->linkage);
    //if (strcmp(toChars(), "mul") == 0) halt();
#endif

//    if (sem > SemanticStart)
//      return;
//    sem = SemanticIn;

    if (scope)
    {   sc = scope;
        scope = NULL;
    }

    /* Pick up storage classes from context, but skip synchronized
     */
    storage_class |= (sc->stc & ~STCsynchronized);
    if (storage_class & STCextern && init)
        error("extern symbols cannot have initializers");

    userAttributes = sc->userAttributes;

    AggregateDeclaration *ad = isThis();
    if (ad)
        storage_class |= ad->storage_class & STC_TYPECTOR;

    /* If auto type inference, do the inference
     */
    int inferred = 0;
    if (!type)
    {   inuse++;

        //printf("inferring type for %s with init %s\n", toChars(), init->toChars());
        ArrayInitializer *ai = init->isArrayInitializer();
        if (ai)
        {   Expression *e;
            if (ai->isAssociativeArray())
                e = ai->toAssocArrayLiteral();
            else
                e = init->toExpression();
            if (!e)
            {
                error("cannot infer type from initializer");
                e = new ErrorExp();
            }
            init = new ExpInitializer(e->loc, e);
            type = init->inferType(sc);
            if (type->ty == Tsarray)
                type = type->nextOf()->arrayOf();
        }
        else
            type = init->inferType(sc);

//      type = type->semantic(loc, sc);

        inuse--;
        inferred = 1;

        if (init->isArrayInitializer() && type->toBasetype()->ty == Tsarray)
        {   // Prefer array literals to give a T[] type rather than a T[dim]
            type = type->toBasetype()->nextOf()->arrayOf();
        }

        /* This is a kludge to support the existing syntax for RAII
         * declarations.
         */
        storage_class &= ~STCauto;
        originalType = type->syntaxCopy();
    }
    else
    {   if (!originalType)
            originalType = type->syntaxCopy();
        type = type->semantic(loc, sc);
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

#if DMDV2
    // Safety checks
    if (sc->func && !sc->intypeof)
    {
        if (storage_class & STCgshared)
        {
            if (sc->func->setUnsafe())
                error("__gshared not allowed in safe functions; use shared");
        }
        if (init && init->isVoidInitializer() && type->hasPointers())
        {
            if (sc->func->setUnsafe())
                error("void initializers for pointers not allowed in safe functions");
        }
        if (type->hasPointers() && type->toDsymbol(sc))
        {
            Dsymbol *s = type->toDsymbol(sc);
            if (s)
            {
                AggregateDeclaration *ad2 = s->isAggregateDeclaration();
                if (ad2 && ad2->hasUnions)
                {
                    if (sc->func->setUnsafe())
                        error("unions containing pointers are not allowed in @safe functions");
                }
            }
        }
    }
#endif

    Dsymbol *parent = toParent();
    FuncDeclaration *fd = parent->isFuncDeclaration();

    Type *tb = type->toBasetype();
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
    {   error("cannot be declared to be a function");
        type = Type::terror;
        tb = type;
    }
    if (tb->ty == Tstruct)
    {   TypeStruct *ts = (TypeStruct *)tb;

        if (!ts->sym->members)
        {
            error("no definition of struct %s", ts->toChars());
        }
    }
    if ((storage_class & STCauto) && !inferred)
       error("storage class 'auto' has no effect if type is not inferred, did you mean 'scope'?");

    if (tb->ty == Ttuple)
    {   /* Instead, declare variables for each of the tuple elements
         * and add those.
         */
        TypeTuple *tt = (TypeTuple *)tb;
        size_t nelems = Parameter::dim(tt->arguments);
        Objects *exps = new Objects();
        exps->setDim(nelems);
        Expression *ie = init ? init->toExpression() : NULL;
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
                    goto Lexpand1;
                }
                else if (isAliasThisTuple(e))
                {
                    Identifier *id = Lexer::uniqueId("__tup");
                    ExpInitializer *ei = new ExpInitializer(e->loc, e);
                    VarDeclaration *v = new VarDeclaration(loc, NULL, id, ei);
                    v->storage_class = STCctfe | STCref | STCforeach;
                    VarExp *ve = new VarExp(loc, v);
                    ve->type = e->type;

                    exps->setDim(1);
                    (*exps)[0] = ve;
                    expandAliasThisTuples(exps, 0);

                    for (size_t u = 0; u < exps->dim ; u++)
                    {
                    Lexpand2:
                        Expression *ee = (*exps)[u];
                        Parameter *arg = Parameter::getNth(tt->arguments, pos + u);
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
        {   size_t tedim = ((TupleExp *)ie)->exps->dim;
            if (tedim != nelems)
            {   ::error(loc, "tuple of %d elements cannot be assigned to tuple of %d elements", (int)tedim, (int)nelems);
                for (size_t u = tedim; u < nelems; u++) // fill dummy expression
                    ((TupleExp *)ie)->exps->push(new ErrorExp());
            }
        }

        for (size_t i = 0; i < nelems; i++)
        {   Parameter *arg = Parameter::getNth(tt->arguments, i);

            OutBuffer buf;
            buf.printf("_%s_field_%llu", ident->toChars(), (ulonglong)i);
            buf.writeByte(0);
            const char *name = (const char *)buf.extractData();
            Identifier *id = Lexer::idPool(name);

            Expression *einit = ie;
            if (ie && ie->op == TOKtuple)
            {   einit = (*((TupleExp *)ie)->exps)[i];
            }
            Initializer *ti = init;
            if (einit)
            {   ti = new ExpInitializer(einit->loc, einit);
            }

            VarDeclaration *v = new VarDeclaration(loc, arg->type, id, ti);
            if (arg->storageClass & STCparameter)
                v->storage_class |= arg->storageClass;
            //printf("declaring field %s of type %s\n", v->toChars(), v->type->toChars());
            v->semantic(sc);

            if (sc->scopesym)
            {   //printf("adding %s to %s\n", v->toChars(), sc->scopesym->toChars());
                if (sc->scopesym->members)
                    sc->scopesym->members->push(v);
            }

            Expression *e = new DsymbolExp(loc, v);
            (*exps)[i] = e;
        }
        TupleDeclaration *v2 = new TupleDeclaration(loc, ident, exps);
        v2->parent = this->parent;
        v2->isexp = 1;
        aliassym = v2;
        return;
    }

    /* Storage class can modify the type
     */
    type = type->addStorageClass(storage_class);

    /* Adjust storage class to reflect type
     */
    if (type->isConst())
    {   storage_class |= STCconst;
        if (type->isShared())
            storage_class |= STCshared;
    }
    else if (type->isImmutable())
        storage_class |= STCimmutable;
    else if (type->isShared())
        storage_class |= STCshared;
    else if (type->isWild())
        storage_class |= STCwild;

    if (isSynchronized())
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
#if DMDV2
            assert(!(storage_class & (STCextern | STCstatic | STCtls | STCgshared)));

            if (storage_class & (STCconst | STCimmutable) && init)
            {
                if (!tb->isTypeBasic())
                    storage_class |= STCstatic;
            }
            else
#endif
            {
                storage_class |= STCfield;
#if DMDV2
                if (tb->ty == Tstruct && ((TypeStruct *)tb)->sym->noDefaultCtor ||
                    tb->ty == Tclass  && ((TypeClass  *)tb)->sym->noDefaultCtor)
                    aad->noDefaultCtor = TRUE;
#endif
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

#if DMDV2
    if ((storage_class & (STCref | STCparameter | STCforeach)) == STCref &&
        ident != Id::This)
    {
        error("only parameters or foreach declarations can be ref");
    }

    if (type->hasWild() &&
        !(type->ty == Tpointer && type->nextOf()->ty == Tfunction || type->ty == Tdelegate))
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
            if (!((TypeFunction *)func->type)->iswild)
            {
                error("inout variables can only be declared inside inout functions");
            }
        }
    }

    if (!(storage_class & (STCctfe | STCref)) && tb->ty == Tstruct &&
        ((TypeStruct *)tb)->sym->noDefaultCtor)
    {
        if (!init)
        {   if (storage_class & STCfield)
                /* For fields, we'll check the constructor later to make sure it is initialized
                 */
                storage_class |= STCnodefaultctor;
            else if (storage_class & STCparameter)
                ;
            else
                error("initializer required for type %s", type->toChars());
        }
    }
#endif

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
    {   // If not mutable, initializable by constructor only
        storage_class |= STCctorinit;
    }

    if (init)
        storage_class |= STCinit;     // remember we had an explicit initializer
    else if (storage_class & STCmanifest)
        error("manifest constants must have initializers");

    enum TOK op = TOKconstruct;
    if (!init && !sc->inunion && !isStatic() && fd &&
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
            e = new ConstructExp(loc, e1, e);
            e = e->semantic(sc);
            init = new ExpInitializer(loc, e);
            goto Ldtor;
        }
        else if (type->ty == Tstruct &&
            ((TypeStruct *)type)->sym->zeroInit == 1)
        {   /* If a struct is all zeros, as a special case
             * set it's initializer to the integer 0.
             * In AssignExp::toElem(), we check for this and issue
             * a memset() to initialize the struct.
             * Must do same check in interpreter.
             */
            Expression *e = new IntegerExp(loc, 0, Type::tint32);
            Expression *e1;
            e1 = new VarExp(loc, this);
            e = new ConstructExp(loc, e1, e);
            e->type = e1->type;         // don't type check this, it would fail
            init = new ExpInitializer(loc, e);
            goto Ldtor;
        }
        else if (type->ty == Ttypedef)
        {   TypeTypedef *td = (TypeTypedef *)type;
            if (td->sym->init)
            {   init = td->sym->init;
                ExpInitializer *ie = init->isExpInitializer();
                if (ie)
                    // Make copy so we can modify it
                    init = new ExpInitializer(ie->loc, ie->exp);
            }
            else
                init = getExpInitializer();
        }
        else
        {
            init = getExpInitializer();
        }
        // Default initializer is always a blit
        op = TOKblit;
    }

    if (init)
    {
        sc = sc->push();
        sc->stc &= ~(STC_TYPECTOR | STCpure | STCnothrow | STCref | STCdisable);

        ArrayInitializer *ai = init->isArrayInitializer();
        if (ai && tb->ty == Taarray)
        {
            Expression *e = ai->toAssocArrayLiteral();
            init = new ExpInitializer(e->loc, e);
        }

        StructInitializer *si = init->isStructInitializer();
        ExpInitializer *ei = init->isExpInitializer();

        if (ei && isScope())
        {
            // See if initializer is a NewExp that can be allocated on the stack
            if (ei->exp->op == TOKnew)
            {   NewExp *ne = (NewExp *)ei->exp;
                if (!(ne->newargs && ne->newargs->dim))
                {   ne->onstack = 1;
                    onstack = 1;
                    if (type->isBaseOf(ne->newtype->semantic(loc, sc), NULL))
                        onstack = 2;
                }
            }
            // or a delegate that doesn't escape a reference to the function
            else if (ei->exp->op == TOKfunction)
            {   FuncDeclaration *f = ((FuncExp *)ei->exp)->fd;
                f->tookAddressOf--;
            }
        }

        // If inside function, there is no semantic3() call
        if (sc->func)
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
                    Expression *e = init->toExpression();
                    if (!e)
                    {
                        // Run semantic, but don't need to interpret
                        init = init->semantic(sc, type, INITnointerpret);
                        e = init->toExpression();
                        if (!e)
                        {   error("is not a static and cannot have static initializer");
                            return;
                        }
                    }
                    ei = new ExpInitializer(init->loc, e);
                    init = ei;
                }

                Expression *e1 = new VarExp(loc, this);

                Type *t = type->toBasetype();
                if (ei && !inferred)
                    ei->exp = ei->exp->inferType(t);

            Linit2:
                if (t->ty == Tsarray && !(storage_class & (STCref | STCout)))
                {
                    ei->exp = ei->exp->semantic(sc);
                    if (!ei->exp->implicitConvTo(type))
                    {
                        dinteger_t dim = ((TypeSArray *)t)->dim->toInteger();
                        // If multidimensional static array, treat as one large array
                        while (1)
                        {
                            t = t->nextOf()->toBasetype();
                            if (t->ty != Tsarray)
                                break;
                            dim *= ((TypeSArray *)t)->dim->toInteger();
                            e1->type = new TypeSArray(t->nextOf(), new IntegerExp(0, dim, Type::tindex));
                        }
                    }
                    e1 = new SliceExp(loc, e1, NULL, NULL);
                }
                else if (t->ty == Tstruct)
                {
                    ei->exp = ei->exp->semantic(sc);
                    ei->exp = resolveProperties(sc, ei->exp);
                    StructDeclaration *sd = ((TypeStruct *)t)->sym;
#if DMDV2
                    Expression** pinit = &ei->exp;
                    while ((*pinit)->op == TOKcomma)
                    {
                        pinit = &((CommaExp *)*pinit)->e2;
                    }

                    /* Look to see if initializer is a call to the constructor
                     */
                    if (sd->ctor &&             // there are constructors
                        (*pinit)->type->ty == Tstruct && // rvalue is the same struct
                        ((TypeStruct *)(*pinit)->type)->sym == sd &&
                        (*pinit)->op == TOKcall)
                    {
                        /* Look for form of constructor call which is:
                         *    *__ctmp.ctor(arguments...)
                         */
                        if (1)
                        {   CallExp *ce = (CallExp *)(*pinit);
                            if (ce->e1->op == TOKdotvar)
                            {   DotVarExp *dve = (DotVarExp *)ce->e1;
                                if (dve->var->isCtorDeclaration())
                                {   /* It's a constructor call, currently constructing
                                     * a temporary __ctmp.
                                     */
                                    /* Before calling the constructor, initialize
                                     * variable with a bit copy of the default
                                     * initializer
                                     */

                                    /* Remove ref if this declaration is ref binding.
                                     * ref Type __self = (__ctmp = 0, __ctmp).this(...);
                                     * ->  Type __self = (__self = 0, __self.this(...));
                                     */
                                    storage_class &= ~(STCref | STCforeach | STCparameter);

                                    Expression *e;
                                    if (sd->zeroInit == 1)
                                    {
                                        e = new ConstructExp(loc, new VarExp(loc, this), new IntegerExp(loc, 0, Type::tint32));
                                    }
                                    else if (sd->isNested())
                                    {   e = new AssignExp(loc, new VarExp(loc, this), t->defaultInitLiteral(loc));
                                        e->op = TOKblit;
                                    }
                                    else
                                    {   e = new AssignExp(loc, new VarExp(loc, this), t->defaultInit(loc));
                                        e->op = TOKblit;
                                    }
                                    e->type = t;

                                    /* Replace __ctmp being constructed with e1.
                                     * We need to copy constructor call expression,
                                     * because it may be used in other place.
                                     */
                                    DotVarExp *dvx = (DotVarExp *)dve->copy();
                                    dvx->e1 = e1;
                                    CallExp *cx = (CallExp *)ce->copy();
                                    cx->e1 = dvx;

                                    (*pinit) = new CommaExp(loc, e, cx);
                                    (*pinit) = (*pinit)->semantic(sc);
                                    goto Ldtor;
                                }
                            }
                        }
                    }

                    /* Look for ((S tmp = S()),tmp) and replace it with just S()
                     */
                    Expression *e2 = ei->exp->isTemp();
                    if (e2)
                    {
                        ei->exp = e2;
                        goto Linit2;
                    }
#endif
                    if (!ei->exp->implicitConvTo(type))
                    {
                        Type *ti = ei->exp->type->toBasetype();
                        // Look for constructor first
                        if (sd->ctor &&
                            /* Initializing with the same type is done differently
                             */
                            !(ti->ty == Tstruct && t->toDsymbol(sc) == ti->toDsymbol(sc)))
                        {
                           // Rewrite as e1.ctor(arguments)
                            Expression *ector = new DotIdExp(loc, e1, Id::ctor);
                            ei->exp = new CallExp(loc, ector, ei->exp);
                            /* Before calling the constructor, initialize
                             * variable with a bit copy of the default
                             * initializer
                             */
                            Expression *e = new AssignExp(loc, e1, t->defaultInit(loc));
                            e->op = TOKblit;
                            e->type = t;
                            ei->exp = new CommaExp(loc, e, ei->exp);
                        }
                        else
                        /* Look for static opCall
                         * See bugzilla 2702 for more discussion
                         */
                        // Don't cast away invariant or mutability in initializer
                        if (search_function(sd, Id::call) &&
                            /* Initializing with the same type is done differently
                             */
                            !(ti->ty == Tstruct && t->toDsymbol(sc) == ti->toDsymbol(sc)))
                        {   // Rewrite as e1.call(arguments)
                            Expression *e = typeDotIdExp(ei->exp->loc, t, Id::call);
                            ei->exp = new CallExp(loc, e, ei->exp);
                        }
                    }
                }
                ei->exp = new AssignExp(loc, e1, ei->exp);
                ei->exp->op = op;
                canassign++;
                ei->exp = ei->exp->semantic(sc);
                canassign--;
                ei->exp->optimize(WANTvalue);
            }
            else
            {
                init = init->semantic(sc, type, INITinterpret);
            }
        }
        else if (storage_class & (STCconst | STCimmutable | STCmanifest) ||
                 type->isConst() || type->isImmutable())
        {
            /* Because we may need the results of a const declaration in a
             * subsequent type, such as an array dimension, before semantic2()
             * gets ordinarily run, try to run semantic2() now.
             * Ignore failure.
             */

            if (!global.errors && !inferred)
            {
                unsigned errors = global.startGagging();
                Expression *exp;
                Initializer *i2 = init;
                inuse++;
                if (ei)
                {
                    exp = ei->exp->syntaxCopy();
                    exp = exp->semantic(sc);
                    exp = resolveProperties(sc, exp);
#if DMDV2
                    Type *tb = type->toBasetype();
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
                    {   StructDeclaration *sd = ((TypeStruct *)ti)->sym;
                        /* Look to see if initializer involves a copy constructor
                         * (which implies a postblit)
                         */
                        if (sd->cpctor &&               // there is a copy constructor
                            tb->equals(ti))             // rvalue is the same struct
                        {
                            // The only allowable initializer is a (non-copy) constructor
                            if (exp->op == TOKcall)
                            {
                                CallExp *ce = (CallExp *)exp;
                                if (ce->e1->op == TOKdotvar)
                                {
                                    DotVarExp *dve = (DotVarExp *)ce->e1;
                                    if (dve->var->isCtorDeclaration())
                                        goto LNoCopyConstruction;
                                }
                            }
                            global.gag--;
                            error("of type struct %s uses this(this), which is not allowed in static initialization", tb->toChars());
                            global.gag++;

                          LNoCopyConstruction:
                            ;
                        }
                    }

                    // Look for implicit constructor call
                    if (tb->ty == Tstruct &&
                        !(ti->ty == Tstruct && tb->toDsymbol(sc) == ti->toDsymbol(sc)) &&
                        !exp->implicitConvTo(type))
                    {
                        StructDeclaration *sd = ((TypeStruct *)tb)->sym;
                        if (sd->ctor)
                        {   // Look for constructor first
                            // Rewrite as e1.ctor(arguments)
                            Expression *e;
                            e = new StructLiteralExp(loc, sd, NULL, NULL);
                            e = new DotIdExp(loc, e, Id::ctor);
                            e = new CallExp(loc, e, exp);
                            e = e->semantic(sc);
                            exp = e->ctfeInterpret();
                        }
                    }
#endif
                    exp = exp->implicitCastTo(sc, type);
                }
                else if (si || ai)
                {   i2 = init->syntaxCopy();
                    i2 = i2->semantic(sc, type, INITinterpret);
                }
                inuse--;
                if (global.endGagging(errors))    // if errors happened
                {
#if DMDV2
                    /* Save scope for later use, to try again
                     */
                    scope = new Scope(*sc);
                    scope->setNoFree();
#endif
                }
                else if (ei)
                {
                    if (isDataseg() || (storage_class & STCmanifest))
                        exp = exp->ctfeInterpret();
                    else
                        exp = exp->optimize(WANTvalue);
                    switch (exp->op)
                    {
                        case TOKint64:
                        case TOKfloat64:
                        case TOKstring:
                        case TOKarrayliteral:
                        case TOKassocarrayliteral:
                        case TOKstructliteral:
                        case TOKnull:
                            ei->exp = exp;          // no errors, keep result
                            break;

                        default:
#if DMDV2
                            /* Save scope for later use, to try again
                             */
                            scope = new Scope(*sc);
                            scope->setNoFree();
#endif
                            break;
                    }
                }
                else
                    init = i2;          // no errors, keep result
            }
        }
        else if (parent->isAggregateDeclaration())
        {
            scope = new Scope(*sc);
            scope->setNoFree();
        }
        sc = sc->pop();
    }

Ldtor:
    /* Build code to execute destruction, if necessary
     */
    edtor = callScopeDtor(sc);
    if (edtor)
    {
        edtor = edtor->semantic(sc);

#if 0 // currently disabled because of std.stdio.stdin, stdout and stderr
        if (isDataseg() && !(storage_class & STCextern))
            error("static storage variables cannot have destructors");
#endif
    }

    sem = SemanticDone;
}

void VarDeclaration::semantic2(Scope *sc)
{
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
    {   inuse++;
#if 0
        ExpInitializer *ei = init->isExpInitializer();
        if (ei)
        {
            ei->exp->dump(0);
            printf("type = %p\n", ei->exp->type);
        }
#endif
        init = init->semantic(sc, type, INITinterpret);
        inuse--;
    }
    sem = Semantic2Done;
}

void VarDeclaration::setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion)
{
    //printf("VarDeclaration::setFieldOffset(ad = %s) %s\n", ad->toChars(), toChars());

    if (aliassym)
    {   // If this variable was really a tuple, set the offsets for the tuple fields
        TupleDeclaration *v2 = aliassym->isTupleDeclaration();
        assert(v2);
        for (size_t i = 0; i < v2->objects->dim; i++)
        {   Object *o = (*v2->objects)[i];
            assert(o->dyncast() == DYNCAST_EXPRESSION);
            Expression *e = (Expression *)o;
            assert(e->op == TOKdsymbol);
            DsymbolExp *se = (DsymbolExp *)e;
            se->s->setFieldOffset(ad, poffset, isunion);
        }
        return;
    }

    if (!(storage_class & STCfield))
        return;
    assert(!(storage_class & (STCstatic | STCextern | STCparameter | STCtls)));

    /* Fields that are tuples appear both as part of TupleDeclarations and
     * as members. That means ignore them if they are already a field.
     */
    if (offset)
        return;         // already a field
    for (size_t i = 0; i < ad->fields.dim; i++)
    {
        if (ad->fields[i] == this)
            return;     // already a field
    }

    // Check for forward referenced types which will fail the size() call
    Type *t = type->toBasetype();
    if (storage_class & STCref)
    {   // References are the size of a pointer
        t = Type::tvoidptr;
    }
    if (t->ty == Tstruct)
    {   TypeStruct *ts = (TypeStruct *)t;
#if DMDV2
        if (ts->sym == ad)
        {
            ad->error("cannot have field %s with same struct type", toChars());
        }
#endif

        if (ts->sym->sizeok != SIZEOKdone && ts->sym->scope)
            ts->sym->semantic(NULL);
        if (ts->sym->sizeok != SIZEOKdone)
        {
            ad->sizeok = SIZEOKfwd;         // cannot finish; flag as forward referenced
            return;
        }
    }
    if (t->ty == Tident)
    {
        ad->sizeok = SIZEOKfwd;             // cannot finish; flag as forward referenced
        return;
    }
#if DMDV2
    else if (t->ty == Tsarray)
    {
        Type *tv = t->toBasetype();
        while (tv->ty == Tsarray)
        {
            tv = tv->nextOf()->toBasetype();
        }
        if (tv->ty == Tstruct)
        {
            TypeStruct *ts = (TypeStruct *)tv;
            if (ad == ts->sym)
            {
                ad->error("cannot have field %s with same struct type", toChars());
                return;
            }
        }
    }
#endif

    unsigned memsize      = t->size(loc);            // size of member
    unsigned memalignsize = t->alignsize();          // size of member for alignment purposes

    offset = AggregateDeclaration::placeField(poffset, memsize, memalignsize, alignment,
                &ad->structsize, &ad->alignsize, isunion);

    //printf("\t%s: alignsize = %d\n", toChars(), alignsize);

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

void VarDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    StorageClassDeclaration::stcToCBuffer(buf, storage_class);

    /* If changing, be sure and fix CompoundDeclarationStatement::toCBuffer()
     * too.
     */
    if (type)
        type->toCBuffer(buf, ident, hgs);
    else
        buf->writestring(ident->toChars());
    if (init)
    {   buf->writestring(" = ");
#if DMDV2
        ExpInitializer *ie = init->isExpInitializer();
        if (ie && (ie->exp->op == TOKconstruct || ie->exp->op == TOKblit))
            ((AssignExp *)ie->exp)->e2->toCBuffer(buf, hgs);
        else
#endif
            init->toCBuffer(buf, hgs);
    }
    buf->writeByte(';');
    buf->writenl();
}

AggregateDeclaration *VarDeclaration::isThis()
{
    AggregateDeclaration *ad = NULL;

    if (!(storage_class & (STCstatic | STCextern | STCmanifest | STCtemplateparameter |
                           STCtls | STCgshared | STCctfe)))
    {
        if ((storage_class & (STCconst | STCimmutable | STCwild)) && init)
            return NULL;

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

int VarDeclaration::needThis()
{
    //printf("VarDeclaration::needThis(%s, x%x)\n", toChars(), storage_class);
    return storage_class & STCfield;
}

int VarDeclaration::isImportedSymbol()
{
    if (protection == PROTexport && !init &&
        (storage_class & STCstatic || parent->isModule()))
        return TRUE;
    return FALSE;
}

void VarDeclaration::checkCtorConstInit()
{
#if 0 /* doesn't work if more than one static ctor */
    if (ctorinit == 0 && isCtorinit() && !(storage_class & STCfield))
        error("missing initializer in static constructor for const variable");
#endif
}

/************************************
 * Check to see if this variable is actually in an enclosing function
 * rather than the current one.
 */

void VarDeclaration::checkNestedReference(Scope *sc, Loc loc)
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
                    fdthis->getLevel(loc, sc, fdv);

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
                    ::error(loc, "cannnot use $ inside a function literal");
            }
        }
    }
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

Expression *VarDeclaration::getConstInitializer()
{
    if ((isConst() || isImmutable() || storage_class & STCmanifest) &&
        storage_class & STCinit)
    {
        ExpInitializer *ei = getExpInitializer();
        if (ei)
            return ei->exp;
        else if (init)
        {
            return init->toExpression();
        }
    }

    return NULL;
}

/*************************************
 * Return !=0 if we can take the address of this variable.
 */

int VarDeclaration::canTakeAddressOf()
{
#if 0
    /* Global variables and struct/class fields of the form:
     *  const int x = 3;
     * are not stored and hence cannot have their address taken.
     */
    if ((isConst() || isImmutable()) &&
        storage_class & STCinit &&
        (!(storage_class & (STCstatic | STCextern)) || (storage_class & STCfield)) &&
        (!parent || toParent()->isModule() || toParent()->isTemplateInstance()) &&
        type->toBasetype()->isTypeBasic()
       )
    {
        return 0;
    }
#else
    if (storage_class & STCmanifest)
        return 0;
#endif
    return 1;
}


/*******************************
 * Does symbol go into data segment?
 * Includes extern variables.
 */

int VarDeclaration::isDataseg()
{
#if 0
    printf("VarDeclaration::isDataseg(%p, '%s')\n", this, toChars());
    printf("%llx, isModule: %p, isTemplateInstance: %p\n", storage_class & (STCstatic | STCconst), parent->isModule(), parent->isTemplateInstance());
    printf("parent = '%s'\n", parent->toChars());
#endif
    if (storage_class & STCmanifest)
        return 0;
    Dsymbol *parent = this->toParent();
    if (!parent && !(storage_class & STCstatic))
    {   error("forward referenced");
        type = Type::terror;
        return 0;
    }
    return canTakeAddressOf() &&
        (storage_class & (STCstatic | STCextern | STCtls | STCgshared) ||
         toParent()->isModule() ||
         toParent()->isTemplateInstance());
}

/************************************
 * Does symbol go into thread local storage?
 */

int VarDeclaration::isThreadlocal()
{
    //printf("VarDeclaration::isThreadlocal(%p, '%s')\n", this, toChars());
#if 0 //|| TARGET_OSX
    /* To be thread-local, must use the __thread storage class.
     * BUG: OSX doesn't support thread local yet.
     */
    return isDataseg() &&
        (storage_class & (STCtls | STCconst | STCimmutable | STCshared | STCgshared)) == STCtls;
#else
    /* Data defaults to being thread-local. It is not thread-local
     * if it is immutable, const or shared.
     */
    int i = isDataseg() &&
        !(storage_class & (STCimmutable | STCconst | STCshared | STCgshared));
    //printf("\treturn %d\n", i);
    return i;
#endif
}

/********************************************
 * Can variable be read and written by CTFE?
 */

int VarDeclaration::isCTFE()
{
    return (storage_class & STCctfe) != 0; // || !isDataseg();
}

int VarDeclaration::hasPointers()
{
    //printf("VarDeclaration::hasPointers() %s, ty = %d\n", toChars(), type->ty);
    return (!isDataseg() && type->hasPointers());
}

/******************************************
 * Return TRUE if variable needs to call the destructor.
 */

int VarDeclaration::needsAutoDtor()
{
    //printf("VarDeclaration::needsAutoDtor() %s\n", toChars());

    if (noscope || !edtor)
        return FALSE;

    return TRUE;
}


/******************************************
 * If a variable has a scope destructor call, return call for it.
 * Otherwise, return NULL.
 */

Expression *VarDeclaration::callScopeDtor(Scope *sc)
{   Expression *e = NULL;

    //printf("VarDeclaration::callScopeDtor() %s\n", toChars());

    // Destruction of STCfield's is handled by buildDtor()
    if (noscope || storage_class & (STCnodtor | STCref | STCout | STCfield))
    {
        return NULL;
    }

    // Destructors for structs and arrays of structs
    bool array = false;
    Type *tv = type->toBasetype();
    while (tv->ty == Tsarray)
    {   TypeSArray *ta = (TypeSArray *)tv;
        array = true;
        tv = tv->nextOf()->toBasetype();
    }
    if (tv->ty == Tstruct)
    {   TypeStruct *ts = (TypeStruct *)tv;
        StructDeclaration *sd = ts->sym;
        if (sd->dtor)
        {
            if (array)
            {
                // Typeinfo.destroy(cast(void*)&v);
                Expression *ea = new SymOffExp(loc, this, 0, 0);
                ea = new CastExp(loc, ea, Type::tvoid->pointerTo());
                Expressions *args = new Expressions();
                args->push(ea);

                Expression *et = type->getTypeInfo(sc);
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
    Type::error(0, "%s not found. object.d may be incorrectly installed or corrupt.", id->toChars());
    fatal();
}


/********************************* ClassInfoDeclaration ****************************/

ClassInfoDeclaration::ClassInfoDeclaration(ClassDeclaration *cd)
    : VarDeclaration(0, ClassDeclaration::classinfo->type, cd->ident, NULL)
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

/********************************* ModuleInfoDeclaration ****************************/

ModuleInfoDeclaration::ModuleInfoDeclaration(Module *mod)
    : VarDeclaration(0, Module::moduleinfo->type, mod->ident, NULL)
{
    this->mod = mod;
    storage_class = STCstatic | STCgshared;
}

Dsymbol *ModuleInfoDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);          // should never be produced by syntax
    return NULL;
}

void ModuleInfoDeclaration::semantic(Scope *sc)
{
}

/********************************* TypeInfoDeclaration ****************************/

TypeInfoDeclaration::TypeInfoDeclaration(Type *tinfo, int internal)
    : VarDeclaration(0, Type::typeinfo->type, tinfo->getTypeInfoIdent(internal), NULL)
{
    this->tinfo = tinfo;
    storage_class = STCstatic | STCgshared;
    protection = PROTpublic;
    linkage = LINKc;
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

/***************************** TypeInfoConstDeclaration **********************/

#if DMDV2
TypeInfoConstDeclaration::TypeInfoConstDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoconst)
    {
        ObjectNotFound(Id::TypeInfo_Const);
    }
    type = Type::typeinfoconst->type;
}
#endif

/***************************** TypeInfoInvariantDeclaration **********************/

#if DMDV2
TypeInfoInvariantDeclaration::TypeInfoInvariantDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoinvariant)
    {
        ObjectNotFound(Id::TypeInfo_Invariant);
    }
    type = Type::typeinfoinvariant->type;
}
#endif

/***************************** TypeInfoSharedDeclaration **********************/

#if DMDV2
TypeInfoSharedDeclaration::TypeInfoSharedDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfoshared)
    {
        ObjectNotFound(Id::TypeInfo_Shared);
    }
    type = Type::typeinfoshared->type;
}
#endif

/***************************** TypeInfoWildDeclaration **********************/

#if DMDV2
TypeInfoWildDeclaration::TypeInfoWildDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfowild)
    {
        ObjectNotFound(Id::TypeInfo_Wild);
    }
    type = Type::typeinfowild->type;
}
#endif

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

/***************************** TypeInfoTypedefDeclaration *********************/

TypeInfoTypedefDeclaration::TypeInfoTypedefDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
    if (!Type::typeinfotypedef)
    {
        ObjectNotFound(Id::TypeInfo_Typedef);
    }
    type = Type::typeinfotypedef->type;
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

