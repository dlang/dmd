
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Handle template implementation

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "aav.h"
#include "rmem.h"
#include "stringtable.h"

#include "mtype.h"
#include "template.h"
#include "init.h"
#include "expression.h"
#include "scope.h"
#include "module.h"
#include "aggregate.h"
#include "declaration.h"
#include "dsymbol.h"
#include "mars.h"
#include "dsymbol.h"
#include "identifier.h"
#include "hdrgen.h"
#include "id.h"
#include "attrib.h"

#define LOG     0

#define IDX_NOTFOUND (0x12345678)               // index is not found

size_t templateParameterLookup(Type *tparam, TemplateParameters *parameters);
int arrayObjectMatch(Objects *oa1, Objects *oa2);
hash_t arrayObjectHash(Objects *oa1);

/********************************************
 * These functions substitute for dynamic_cast. dynamic_cast does not work
 * on earlier versions of gcc.
 */

Expression *isExpression(RootObject *o)
{
    //return dynamic_cast<Expression *>(o);
    if (!o || o->dyncast() != DYNCAST_EXPRESSION)
        return NULL;
    return (Expression *)o;
}

Dsymbol *isDsymbol(RootObject *o)
{
    //return dynamic_cast<Dsymbol *>(o);
    if (!o || o->dyncast() != DYNCAST_DSYMBOL)
        return NULL;
    return (Dsymbol *)o;
}

Type *isType(RootObject *o)
{
    //return dynamic_cast<Type *>(o);
    if (!o || o->dyncast() != DYNCAST_TYPE)
        return NULL;
    return (Type *)o;
}

Tuple *isTuple(RootObject *o)
{
    //return dynamic_cast<Tuple *>(o);
    if (!o || o->dyncast() != DYNCAST_TUPLE)
        return NULL;
    return (Tuple *)o;
}

Parameter *isParameter(RootObject *o)
{
    //return dynamic_cast<Parameter *>(o);
    if (!o || o->dyncast() != DYNCAST_PARAMETER)
        return NULL;
    return (Parameter *)o;
}

/**************************************
 * Is this Object an error?
 */
int isError(RootObject *o)
{
    Type *t = isType(o);
    if (t)
        return (t->ty == Terror);
    Expression *e = isExpression(o);
    if (e)
        return (e->op == TOKerror || !e->type || e->type->ty== Terror);
    Tuple *v = isTuple(o);
    if (v)
        return arrayObjectIsError(&v->objects);
    Dsymbol *s = isDsymbol(o);
    if (s->errors)
        return 1;
    return 0;
}

/**************************************
 * Are any of the Objects an error?
 */
int arrayObjectIsError(Objects *args)
{
    for (size_t i = 0; i < args->dim; i++)
    {
        RootObject *o = (*args)[i];
        if (isError(o))
            return 1;
    }
    return 0;
}

/***********************
 * Try to get arg as a type.
 */

Type *getType(RootObject *o)
{
    Type *t = isType(o);
    if (!t)
    {   Expression *e = isExpression(o);
        if (e)
            t = e->type;
    }
    return t;
}

Dsymbol *getDsymbol(RootObject *oarg)
{
    //printf("getDsymbol()\n");
    //printf("e %p s %p t %p v %p\n", isExpression(oarg), isDsymbol(oarg), isType(oarg), isTuple(oarg));

    Dsymbol *sa;
    Expression *ea = isExpression(oarg);
    if (ea)
    {   // Try to convert Expression to symbol
        if (ea->op == TOKvar)
            sa = ((VarExp *)ea)->var;
        else if (ea->op == TOKfunction)
        {
            if (((FuncExp *)ea)->td)
                sa = ((FuncExp *)ea)->td;
            else
                sa = ((FuncExp *)ea)->fd;
        }
        else
            sa = NULL;
    }
    else
    {   // Try to convert Type to symbol
        Type *ta = isType(oarg);
        if (ta)
            sa = ta->toDsymbol(NULL);
        else
            sa = isDsymbol(oarg);       // if already a symbol
    }
    return sa;
}

/***********************
 * Try to get value from manifest constant
 */

Expression *getValue(Expression *e)
{
    if (e && e->op == TOKvar)
    {
        VarDeclaration *v = ((VarExp *)e)->var->isVarDeclaration();
        if (v && v->storage_class & STCmanifest)
        {
            e = v->getConstInitializer();
        }
    }
    return e;
}
Expression *getValue(Dsymbol *&s)
{
    Expression *e = NULL;
    if (s)
    {
        VarDeclaration *v = s->isVarDeclaration();
        if (v && v->storage_class & STCmanifest)
        {
            e = v->getConstInitializer();
        }
    }
    return e;
}

/******************************
 * If o1 matches o2, return 1.
 * Else, return 0.
 */

int match(RootObject *o1, RootObject *o2)
{
    Type *t1 = isType(o1);
    Type *t2 = isType(o2);
    Dsymbol *s1 = isDsymbol(o1);
    Dsymbol *s2 = isDsymbol(o2);
    Expression *e1 = s1 ? getValue(s1) : getValue(isExpression(o1));
    Expression *e2 = s2 ? getValue(s2) : getValue(isExpression(o2));
    Tuple *u1 = isTuple(o1);
    Tuple *u2 = isTuple(o2);

    //printf("\t match t1 %p t2 %p, e1 %p e2 %p, s1 %p s2 %p, u1 %p u2 %p\n", t1,t2,e1,e2,s1,s2,u1,u2);

    /* A proper implementation of the various equals() overrides
     * should make it possible to just do o1->equals(o2), but
     * we'll do that another day.
     */

    /* Manifest constants should be compared by their values,
     * at least in template arguments.
     */

    if (t1)
    {
        //printf("t1 = %s\n", t1->toChars());
        //printf("t2 = %s\n", t2->toChars());
        if (!t2 || !t1->equals(t2))
            goto Lnomatch;
    }
    else if (e1)
    {
#if 0
        if (e1 && e2)
        {
            printf("match %d\n", e1->equals(e2));
            printf("\te1 = %p %s %s %s\n", e1, e1->type->toChars(), Token::toChars(e1->op), e1->toChars());
            printf("\te2 = %p %s %s %s\n", e2, e2->type->toChars(), Token::toChars(e2->op), e2->toChars());
        }
#endif
        if (!e2)
            goto Lnomatch;
        if (!e1->equals(e2))
            goto Lnomatch;
    }
    else if (s1)
    {
        if (s2)
        {
            if (!s1->equals(s2))
                goto Lnomatch;
            if (s1->parent != s2->parent &&
                !s1->isFuncDeclaration() &&
                !s2->isFuncDeclaration())
            {
                goto Lnomatch;
            }
        }
        else
            goto Lnomatch;
    }
    else if (u1)
    {
        if (!u2)
            goto Lnomatch;
        if (!arrayObjectMatch(&u1->objects, &u2->objects))
            goto Lnomatch;
    }
    //printf("match\n");
    return 1;   // match

Lnomatch:
    //printf("nomatch\n");
    return 0;   // nomatch;
}


/************************************
 * Match an array of them.
 */
int arrayObjectMatch(Objects *oa1, Objects *oa2)
{
    if (oa1 == oa2)
        return 1;
    if (oa1->dim != oa2->dim)
        return 0;
    for (size_t j = 0; j < oa1->dim; j++)
    {   RootObject *o1 = (*oa1)[j];
        RootObject *o2 = (*oa2)[j];
        if (!match(o1, o2))
        {
            return 0;
        }
    }
    return 1;
}


/************************************
 * Return hash of Objects.
 */
hash_t arrayObjectHash(Objects *oa1)
{
    hash_t hash = 0;
    for (size_t j = 0; j < oa1->dim; j++)
    {   /* Must follow the logic of match()
         */
        RootObject *o1 = (*oa1)[j];
        if (Type *t1 = isType(o1))
            hash += (size_t)t1->deco;
        else
        {
            Dsymbol *s1 = isDsymbol(o1);
            Expression *e1 = s1 ? getValue(s1) : getValue(isExpression(o1));
            if (e1)
            {
                if (e1->op == TOKint64)
                {
                    IntegerExp *ne = (IntegerExp *)e1;
                    hash += (size_t)ne->value;
                }
            }
            else if (s1)
            {
                FuncAliasDeclaration *fa1 = s1->isFuncAliasDeclaration();
                if (fa1)
                    s1 = fa1->toAliasFunc();
                hash += (size_t)(void *)s1->getIdent() + (size_t)(void *)s1->parent;
            }
            else if (Tuple *u1 = isTuple(o1))
                hash += arrayObjectHash(&u1->objects);
        }
    }
    return hash;
}


/****************************************
 * This makes a 'pretty' version of the template arguments.
 * It's analogous to genIdent() which makes a mangled version.
 */

void ObjectToCBuffer(OutBuffer *buf, HdrGenState *hgs, RootObject *oarg)
{
    //printf("ObjectToCBuffer()\n");
    Type *t = isType(oarg);
    Expression *e = isExpression(oarg);
    Dsymbol *s = isDsymbol(oarg);
    Tuple *v = isTuple(oarg);
    /* The logic of this should match what genIdent() does. The _dynamic_cast()
     * function relies on all the pretty strings to be unique for different classes
     * (see Bugzilla 7375).
     * Perhaps it would be better to demangle what genIdent() does.
     */
    if (t)
    {   //printf("\tt: %s ty = %d\n", t->toChars(), t->ty);
        t->toCBuffer(buf, NULL, hgs);
    }
    else if (e)
    {
        if (e->op == TOKvar)
            e = e->optimize(WANTvalue);         // added to fix Bugzilla 7375
        e->toCBuffer(buf, hgs);
    }
    else if (s)
    {
        char *p = s->ident ? s->ident->toChars() : s->toChars();
        buf->writestring(p);
    }
    else if (v)
    {
        Objects *args = &v->objects;
        for (size_t i = 0; i < args->dim; i++)
        {
            if (i)
                buf->writestring(", ");
            RootObject *o = (*args)[i];
            ObjectToCBuffer(buf, hgs, o);
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

RootObject *objectSyntaxCopy(RootObject *o)
{
    if (!o)
        return NULL;
    Type *t = isType(o);
    if (t)
        return t->syntaxCopy();
    Expression *e = isExpression(o);
    if (e)
        return e->syntaxCopy();
    return o;
}


/* ======================== TemplateDeclaration ============================= */

TemplateDeclaration::TemplateDeclaration(Loc loc, Identifier *id,
        TemplateParameters *parameters, Expression *constraint, Dsymbols *decldefs, bool ismixin, bool literal)
    : ScopeDsymbol(id)
{
#if LOG
    printf("TemplateDeclaration(this = %p, id = '%s')\n", this, id->toChars());
#endif
#if 0
    if (parameters)
        for (int i = 0; i < parameters->dim; i++)
        {   TemplateParameter *tp = (*parameters)[i];
            //printf("\tparameter[%d] = %p\n", i, tp);
            TemplateTypeParameter *ttp = tp->isTemplateTypeParameter();

            if (ttp)
            {
                printf("\tparameter[%d] = %s : %s\n", i, tp->ident->toChars(), ttp->specType ? ttp->specType->toChars() : "");
            }
        }
#endif
    this->loc = loc;
    this->parameters = parameters;
    this->origParameters = parameters;
    this->constraint = constraint;
    this->members = decldefs;
    this->overnext = NULL;
    this->overroot = NULL;
    this->funcroot = NULL;
    this->onemember = NULL;
    this->literal = literal;
    this->ismixin = ismixin;
    this->isstatic = true;
    this->previous = NULL;
    this->protection = PROTundefined;
    this->numinstances = 0;

    // Compute in advance for Ddoc's use
    // Bugzilla 11153: ident could be NULL if parsing fails.
    if (members && ident)
    {
        Dsymbol *s;
        if (Dsymbol::oneMembers(members, &s, ident) && s)
        {
            onemember = s;
            s->parent = this;
        }
    }
}

Dsymbol *TemplateDeclaration::syntaxCopy(Dsymbol *)
{
    //printf("TemplateDeclaration::syntaxCopy()\n");
    TemplateDeclaration *td;
    TemplateParameters *p;

    p = NULL;
    if (parameters)
    {
        p = new TemplateParameters();
        p->setDim(parameters->dim);
        for (size_t i = 0; i < p->dim; i++)
        {   TemplateParameter *tp = (*parameters)[i];
            (*p)[i] = tp->syntaxCopy();
        }
    }
    Expression *e = NULL;
    if (constraint)
        e = constraint->syntaxCopy();
    Dsymbols *d = Dsymbol::arraySyntaxCopy(members);
    td = new TemplateDeclaration(loc, ident, p, e, d, ismixin, literal);
    return td;
}

void TemplateDeclaration::semantic(Scope *sc)
{
#if LOG
    printf("TemplateDeclaration::semantic(this = %p, id = '%s')\n", this, ident->toChars());
    printf("sc->stc = %llx\n", sc->stc);
    printf("sc->module = %s\n", sc->module->toChars());
#endif
    if (semanticRun != PASSinit)
        return;         // semantic() already run
    semanticRun = PASSsemantic;

    // Remember templates defined in module object that we need to know about
    if (sc->module && sc->module->ident == Id::object)
    {
        if (ident == Id::AssociativeArray)
            Type::associativearray = this;
        else if (ident == Id::RTInfo)
            Type::rtinfo = this;
    }

    if (/*global.params.useArrayBounds &&*/ sc->module)
    {
        // Generate this function as it may be used
        // when template is instantiated in other modules
        sc->module->toModuleArray();
    }

    if (/*global.params.useAssert &&*/ sc->module)
    {
        // Generate this function as it may be used
        // when template is instantiated in other modules
        sc->module->toModuleAssert();
    }

    if (sc->module)
    {
        // Generate this function as it may be used
        // when template is instantiated in other modules
        sc->module->toModuleUnittest();
    }

    /* Remember Scope for later instantiations, but make
     * a copy since attributes can change.
     */
    if (!this->scope)
    {
        this->scope = new Scope(*sc);
        this->scope->setNoFree();
    }

    // Set up scope for parameters
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = sc->parent;
    Scope *paramscope = sc->push(paramsym);
    paramscope->stc = 0;

    if (!parent)
        parent = sc->parent;

    isstatic = toParent()->isModule() ||
               toParent()->isFuncDeclaration() && (scope->stc & STCstatic);

    protection = sc->protection;

    if (global.params.doDocComments)
    {
        origParameters = new TemplateParameters();
        origParameters->setDim(parameters->dim);
        for (size_t i = 0; i < parameters->dim; i++)
        {
            TemplateParameter *tp = (*parameters)[i];
            (*origParameters)[i] = tp->syntaxCopy();
        }
    }

    for (size_t i = 0; i < parameters->dim; i++)
    {
        TemplateParameter *tp = (*parameters)[i];

        tp->declareParameter(paramscope);
    }

    for (size_t i = 0; i < parameters->dim; i++)
    {
        TemplateParameter *tp = (*parameters)[i];

        tp->semantic(paramscope, parameters);
        if (i + 1 != parameters->dim && tp->isTemplateTupleParameter())
        {
            error("template tuple parameter must be last one");
            errors = true;
        }
    }

    paramscope->pop();

    // Compute again
    onemember = NULL;
    if (members)
    {
        Dsymbol *s;
        if (Dsymbol::oneMembers(members, &s, ident) && s)
        {
            onemember = s;
            s->parent = this;
        }
    }

    /* BUG: should check:
     *  o no virtual functions or non-static data members of classes
     */
}

const char *TemplateDeclaration::kind()
{
    return (onemember && onemember->isAggregateDeclaration())
                ? onemember->kind()
                : (char *)"template";
}

/**********************************
 * Overload existing TemplateDeclaration 'this' with the new one 's'.
 * Return true if successful; i.e. no conflict.
 */

bool TemplateDeclaration::overloadInsert(Dsymbol *s)
{
#if LOG
    printf("TemplateDeclaration::overloadInsert('%s')\n", s->toChars());
#endif
    FuncDeclaration *fd = s->isFuncDeclaration();
    if (fd)
    {
        if (funcroot)
            return funcroot->overloadInsert(fd);
        funcroot = fd;
        return funcroot->overloadInsert(this);
    }

    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (!td)
        return false;

    TemplateDeclaration *pthis = this;
    TemplateDeclaration **ptd;
    for (ptd = &pthis; *ptd; ptd = &(*ptd)->overnext)
    {
#if 0
        // Conflict if TemplateParameter's match
        // Will get caught anyway later with TemplateInstance, but
        // should check it now.
        TemplateDeclaration *f2 = *ptd;

        if (td->parameters->dim != f2->parameters->dim)
            goto Lcontinue;

        for (size_t i = 0; i < td->parameters->dim; i++)
        {   TemplateParameter *p1 = (*td->parameters)[i];
            TemplateParameter *p2 = (*f2->parameters)[i];

            if (!p1->overloadMatch(p2))
                goto Lcontinue;
        }

#if LOG
        printf("\tfalse: conflict\n");
#endif
        return false;

     Lcontinue:
        ;
#endif
    }

    td->overroot = this;
    *ptd = td;
#if LOG
    printf("\ttrue: no conflict\n");
#endif
    return true;
}

/****************************
 * Declare all the function parameters as variables
 * and add them to the scope
 */
void TemplateDeclaration::makeParamNamesVisibleInConstraint(Scope *paramscope, Expressions *fargs)
{
    /* We do this ONLY if there is only one function in the template.
     */
    FuncDeclaration *fd = onemember && onemember->toAlias() ?
        onemember->toAlias()->isFuncDeclaration() : NULL;
    if (fd)
    {
        /*
            Making parameters is similar to FuncDeclaration::semantic3
         */
        paramscope->parent = fd;

        TypeFunction *tf = (TypeFunction *)fd->type->syntaxCopy();

        // Shouldn't run semantic on default arguments and return type.
        for (size_t i = 0; i<tf->parameters->dim; i++)
            (*tf->parameters)[i]->defaultArg = NULL;
        tf->next = NULL;

        // Resolve parameter types and 'auto ref's.
        tf->fargs = fargs;
        tf = (TypeFunction *)tf->semantic(loc, paramscope);

        Parameters *fparameters = tf->parameters;
        int fvarargs = tf->varargs;

        size_t nfparams = Parameter::dim(fparameters); // Num function parameters
        for (size_t i = 0; i < nfparams; i++)
        {
            Parameter *fparam = Parameter::getNth(fparameters, i);
            // Remove addMod same as func.d L1065 of FuncDeclaration::semantic3
            fparam->storageClass &= (STCin | STCout | STCref | STClazy | STCfinal | STC_TYPECTOR | STCnodtor);
            fparam->storageClass |= STCparameter;
            if (fvarargs == 2 && i + 1 == nfparams)
                fparam->storageClass |= STCvariadic;
        }
        for (size_t i = 0; i < fparameters->dim; i++)
        {
            Parameter *fparam = (*fparameters)[i];
            if (!fparam->ident)
                continue;                       // don't add it, if it has no name
            VarDeclaration *v = new VarDeclaration(loc, fparam->type, fparam->ident, NULL);
            v->storage_class = fparam->storageClass;
            v->semantic(paramscope);
            if (!paramscope->insert(v))
                error("parameter %s.%s is already defined", toChars(), v->toChars());
            else
                v->parent = fd;
        }
    }
}

/***************************************
 * Given that ti is an instance of this TemplateDeclaration,
 * deduce the types of the parameters to this, and store
 * those deduced types in dedtypes[].
 * Input:
 *      flag    1: don't do semantic() because of dummy types
 *              2: don't change types in matchArg()
 * Output:
 *      dedtypes        deduced arguments
 * Return match level.
 */

MATCH TemplateDeclaration::matchWithInstance(Scope *sc, TemplateInstance *ti,
        Objects *dedtypes, Expressions *fargs, int flag)
{   MATCH m;
    size_t dedtypes_dim = dedtypes->dim;

#define LOGM 0
#if LOGM
    printf("\n+TemplateDeclaration::matchWithInstance(this = %s, ti = %s, flag = %d)\n", toChars(), ti->toChars(), flag);
#endif

#if 0
    printf("dedtypes->dim = %d, parameters->dim = %d\n", dedtypes_dim, parameters->dim);
    if (ti->tiargs->dim)
        printf("ti->tiargs->dim = %d, [0] = %p\n",
            ti->tiargs->dim,
            (*ti->tiargs)[0]);
#endif
    dedtypes->zero();

    if (errors)
        return MATCHnomatch;

    size_t parameters_dim = parameters->dim;
    int variadic = isVariadic() != NULL;

    // If more arguments than parameters, no match
    if (ti->tiargs->dim > parameters_dim && !variadic)
    {
#if LOGM
        printf(" no match: more arguments than parameters\n");
#endif
        return MATCHnomatch;
    }

    assert(dedtypes_dim == parameters_dim);
    assert(dedtypes_dim >= ti->tiargs->dim || variadic);

    // Set up scope for parameters
    assert(scope);
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = scope->parent;
    Scope *paramscope = scope->push(paramsym);
    Module *mi = ti->instantiatingModule ? ti->instantiatingModule : sc->instantiatingModule;
    paramscope->instantiatingModule = mi;
    paramscope->callsc = sc;
    paramscope->stc = 0;

    // Attempt type deduction
    m = MATCHexact;
    for (size_t i = 0; i < dedtypes_dim; i++)
    {
        MATCH m2;
        TemplateParameter *tp = (*parameters)[i];
        Declaration *sparam;

        //printf("\targument [%d]\n", i);
#if LOGM
        //printf("\targument [%d] is %s\n", i, oarg ? oarg->toChars() : "null");
        TemplateTypeParameter *ttp = tp->isTemplateTypeParameter();
        if (ttp)
            printf("\tparameter[%d] is %s : %s\n", i, tp->ident->toChars(), ttp->specType ? ttp->specType->toChars() : "");
#endif

        m2 = tp->matchArg(ti->loc, paramscope, ti->tiargs, i, parameters, dedtypes, &sparam);
        //printf("\tm2 = %d\n", m2);

        if (m2 == MATCHnomatch)
        {
#if 0
            printf("\tmatchArg() for parameter %i failed\n", i);
#endif
            goto Lnomatch;
        }

        if (m2 < m)
            m = m2;

        if (!flag)
            sparam->semantic(paramscope);
        if (!paramscope->insert(sparam))    // TODO: This check can make more early
            goto Lnomatch;                  // in TemplateDeclaration::semantic, and
                                            // then we don't need to make sparam if flags == 0
    }

    if (!flag)
    {
        /* Any parameter left without a type gets the type of
         * its corresponding arg
         */
        for (size_t i = 0; i < dedtypes_dim; i++)
        {
            if (!(*dedtypes)[i])
            {   assert(i < ti->tiargs->dim);
                (*dedtypes)[i] = (Type *)(*ti->tiargs)[i];
            }
        }
    }

    if (m > MATCHnomatch && constraint && !flag)
    {
        /* Check to see if constraint is satisfied.
         */
        makeParamNamesVisibleInConstraint(paramscope, fargs);
        Expression *e = constraint->syntaxCopy();

        /* There's a chicken-and-egg problem here. We don't know yet if this template
         * instantiation will be a local one (enclosing is set), and we won't know until
         * after selecting the correct template. Thus, function we're nesting inside
         * is not on the sc scope chain, and this can cause errors in FuncDeclaration::getLevel().
         * Workaround the problem by setting a flag to relax the checking on frame errors.
         */

        int nmatches = 0;
        for (Previous *p = previous; p; p = p->prev)
        {
            if (arrayObjectMatch(p->dedargs, dedtypes))
            {
                //printf("recursive, no match p->sc=%p %p %s\n", p->sc, this, this->toChars());
                /* It must be a subscope of p->sc, other scope chains are not recursive
                 * instantiations.
                 */
                for (Scope *scx = sc; scx; scx = scx->enclosing)
                {
                    if (scx == p->sc)
                        goto Lnomatch;
                }
            }
            /* BUG: should also check for ref param differences
             */
        }

        Previous pr;
        pr.prev = previous;
        pr.sc = paramscope;
        pr.dedargs = dedtypes;
        previous = &pr;                 // add this to threaded list

        int nerrors = global.errors;

        FuncDeclaration *fd = onemember && onemember->toAlias() ?
            onemember->toAlias()->isFuncDeclaration() : NULL;
        Dsymbol *s = parent;
        while (s->isTemplateInstance() || s->isTemplateMixin())
            s = s->parent;
        AggregateDeclaration *ad = s->isAggregateDeclaration();
        VarDeclaration *vthissave;
        if (fd && ad)
        {
            vthissave = fd->vthis;
            fd->vthis = fd->declareThis(paramscope, ad);
        }

        Scope *scx = paramscope->startCTFE();
        scx->flags |= SCOPEstaticif;
        e = e->semantic(scx);
        e = resolveProperties(scx, e);
        scx = scx->endCTFE();

        if (fd && fd->vthis)
            fd->vthis = vthissave;

        previous = pr.prev;             // unlink from threaded list

        if (nerrors != global.errors)   // if any errors from evaluating the constraint, no match
            goto Lnomatch;
        if (e->op == TOKerror)
            goto Lnomatch;

        e = e->ctfeInterpret();
        if (e->isBool(true))
            ;
        else if (e->isBool(false))
            goto Lnomatch;
        else
        {
            e->error("constraint %s is not constant or does not evaluate to a bool", e->toChars());
        }
    }

#if LOGM
    // Print out the results
    printf("--------------------------\n");
    printf("template %s\n", toChars());
    printf("instance %s\n", ti->toChars());
    if (m > MATCHnomatch)
    {
        for (size_t i = 0; i < dedtypes_dim; i++)
        {
            TemplateParameter *tp = (*parameters)[i];
            RootObject *oarg;

            printf(" [%d]", i);

            if (i < ti->tiargs->dim)
                oarg = (*ti->tiargs)[i];
            else
                oarg = NULL;
            tp->print(oarg, (*dedtypes)[i]);
        }
    }
    else
        goto Lnomatch;
#endif

#if LOGM
    printf(" match = %d\n", m);
#endif
    goto Lret;

Lnomatch:
#if LOGM
    printf(" no match\n");
#endif
    m = MATCHnomatch;

Lret:
    paramscope->pop();
#if LOGM
    printf("-TemplateDeclaration::matchWithInstance(this = %p, ti = %p) = %d\n", this, ti, m);
#endif
    return m;
}

/********************************************
 * Determine partial specialization order of 'this' vs td2.
 * Returns:
 *      match   this is at least as specialized as td2
 *      0       td2 is more specialized than this
 */

MATCH TemplateDeclaration::leastAsSpecialized(Scope *sc, TemplateDeclaration *td2, Expressions *fargs)
{
    /* This works by taking the template parameters to this template
     * declaration and feeding them to td2 as if it were a template
     * instance.
     * If it works, then this template is at least as specialized
     * as td2.
     */

    TemplateInstance ti(Loc(), ident);      // create dummy template instance
    Objects dedtypes;

#define LOG_LEASTAS     0

#if LOG_LEASTAS
    printf("%s.leastAsSpecialized(%s)\n", toChars(), td2->toChars());
#endif

    // Set type arguments to dummy template instance to be types
    // generated from the parameters to this template declaration
    ti.tiargs = new Objects();
    ti.tiargs->setDim(parameters->dim);
    for (size_t i = 0; i < ti.tiargs->dim; i++)
    {
        TemplateParameter *tp = (*parameters)[i];

        RootObject *p = (RootObject *)tp->dummyArg();
        if (p)
            (*ti.tiargs)[i] = p;
        else
            ti.tiargs->setDim(i);
    }

    // Temporary Array to hold deduced types
    //dedtypes.setDim(parameters->dim);
    dedtypes.setDim(td2->parameters->dim);

    // Attempt a type deduction
    MATCH m = td2->matchWithInstance(sc, &ti, &dedtypes, fargs, 1);
    if (m > MATCHnomatch)
    {
        /* A non-variadic template is more specialized than a
         * variadic one.
         */
        if (isVariadic() && !td2->isVariadic())
            goto L1;

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


/*************************************************
 * Match function arguments against a specific template function.
 * Input:
 *      loc             instantiation location
 *      sc              instantiation scope
 *      tiargs          Expression/Type initial list of template arguments
 *      tthis           'this' argument if !NULL
 *      fargs           arguments to function
 * Output:
 *      dedargs         Expression/Type deduced template arguments
 * Returns:
 *      match level
 *          bit 0-3     Match template parameters by inferred template arguments
 *          bit 4-7     Match template parameters by initial template arguments
 */

MATCH TemplateDeclaration::deduceFunctionTemplateMatch(FuncDeclaration *f, Loc loc, Scope *sc, Objects *tiargs,
        Type *tthis, Expressions *fargs,
        Objects *dedargs)
{
    size_t nfparams;
    size_t nfargs;
    size_t ntargs;              // array size of tiargs
    size_t fptupindex = IDX_NOTFOUND;
    size_t tuple_dim = 0;
    MATCH match = MATCHexact;
    MATCH matchTiargs = MATCHexact;
    FuncDeclaration *fd = f;
    Parameters *fparameters;            // function parameter list
    int fvarargs;                       // function varargs
    Objects dedtypes;   // for T:T*, the dedargs is the T*, dedtypes is the T
    unsigned wildmatch = 0;
    TemplateParameters *inferparams = parameters;

#if 0
    printf("\nTemplateDeclaration::deduceFunctionTemplateMatch() %s\n", toChars());
    for (size_t i = 0; i < (fargs ? fargs->dim : 0); i++)
    {   Expression *e = (*fargs)[i];
        printf("\tfarg[%d] is %s, type is %s\n", i, e->toChars(), e->type->toChars());
    }
    printf("fd = %s\n", fd->toChars());
    printf("fd->type = %s\n", fd->type->toChars());
    if (tthis)
        printf("tthis = %s\n", tthis->toChars());
#endif

    assert(scope);

    dedargs->setDim(parameters->dim);
    dedargs->zero();

    dedtypes.setDim(parameters->dim);
    dedtypes.zero();

    if (errors || f->errors)
        return MATCHnomatch;

    // Set up scope for parameters
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = scope->parent;
    Scope *paramscope = scope->push(paramsym);

    paramscope->instantiatingModule = sc->instantiatingModule;
    Module *mi = sc->instantiatingModule ? sc->instantiatingModule : sc->module;
    if (!sc->instantiatingModule || sc->instantiatingModule->isRoot())
        paramscope->instantiatingModule = mi;

    paramscope->callsc = sc;
    paramscope->stc = 0;

    TemplateTupleParameter *tp = isVariadic();
    bool tp_is_declared = false;

#if 0
    for (size_t i = 0; i < dedargs->dim; i++)
    {
        printf("\tdedarg[%d] = ", i);
        RootObject *oarg = (*dedargs)[i];
        if (oarg) printf("%s", oarg->toChars());
        printf("\n");
    }
#endif


    ntargs = 0;
    if (tiargs)
    {   // Set initial template arguments

        ntargs = tiargs->dim;
        size_t n = parameters->dim;
        if (tp)
            n--;
        if (ntargs > n)
        {   if (!tp)
                goto Lnomatch;

            /* The extra initial template arguments
             * now form the tuple argument.
             */
            Tuple *t = new Tuple();
            assert(parameters->dim);
            (*dedargs)[parameters->dim - 1] = t;

            tuple_dim = ntargs - n;
            t->objects.setDim(tuple_dim);
            for (size_t i = 0; i < tuple_dim; i++)
            {
                t->objects[i] = (*tiargs)[n + i];
            }
            declareParameter(paramscope, tp, t);
            tp_is_declared = true;
        }
        else
            n = ntargs;

        memcpy(dedargs->tdata(), tiargs->tdata(), n * sizeof(*dedargs->tdata()));

        for (size_t i = 0; i < n; i++)
        {   assert(i < parameters->dim);
            MATCH m;
            Declaration *sparam = NULL;

            m = (*parameters)[i]->matchArg(loc, paramscope, dedargs, i, parameters, &dedtypes, &sparam);
            //printf("\tdeduceType m = %d\n", m);
            if (m <= MATCHnomatch)
                goto Lnomatch;
            if (m < matchTiargs)
                matchTiargs = m;

            sparam->semantic(paramscope);
            if (!paramscope->insert(sparam))
                goto Lnomatch;
        }
        if (n < parameters->dim && !tp_is_declared)
        {
            inferparams = new TemplateParameters();
            inferparams->setDim(parameters->dim - n);
            memcpy(inferparams->tdata(),
                   parameters->tdata() + n,
                   inferparams->dim * sizeof(*inferparams->tdata()));
        }
        else
            inferparams = NULL;
        //printf("tiargs matchTiargs = %d\n", matchTiargs);
    }
#if 0
    for (size_t i = 0; i < dedargs->dim; i++)
    {
        printf("\tdedarg[%d] = ", i);
        RootObject *oarg = (*dedargs)[i];
        if (oarg) printf("%s", oarg->toChars());
        printf("\n");
    }
#endif

    fparameters = fd->getParameters(&fvarargs);
    nfparams = Parameter::dim(fparameters);     // number of function parameters
    nfargs = fargs ? fargs->dim : 0;            // number of function arguments

    /* Check for match of function arguments with variadic template
     * parameter, such as:
     *
     * void foo(T, A...)(T t, A a);
     * void main() { foo(1,2,3); }
     */
    if (tp)                             // if variadic
    {
        // TemplateTupleParameter always makes most lesser matching.
        matchTiargs = MATCHconvert;

        if (nfparams == 0 && nfargs != 0)               // if no function parameters
        {
            if (!tp_is_declared)
            {
                Tuple *t = new Tuple();
                //printf("t = %p\n", t);
                (*dedargs)[parameters->dim - 1] = t;
                declareParameter(paramscope, tp, t);
                tp_is_declared = true;
            }
        }
        else
        {
            /* Figure out which of the function parameters matches
             * the tuple template parameter. Do this by matching
             * type identifiers.
             * Set the index of this function parameter to fptupindex.
             */
            for (fptupindex = 0; fptupindex < nfparams; fptupindex++)
            {
                Parameter *fparam = (*fparameters)[fptupindex];
                if (fparam->type->ty != Tident)
                    continue;
                TypeIdentifier *tid = (TypeIdentifier *)fparam->type;
                if (!tp->ident->equals(tid->ident) || tid->idents.dim)
                    continue;

                if (fvarargs)           // variadic function doesn't
                    goto Lnomatch;      // go with variadic template

                goto L1;
            }
            fptupindex = IDX_NOTFOUND;
        L1:
            ;
        }
    }

    if (tthis)
    {
        bool hasttp = false;

        // Match 'tthis' to any TemplateThisParameter's
        for (size_t i = 0; i < parameters->dim; i++)
        {
            TemplateThisParameter *ttp = (*parameters)[i]->isTemplateThisParameter();
            if (ttp)
            {   hasttp = true;

                Type *t = new TypeIdentifier(Loc(), ttp->ident);
                MATCH m = tthis->deduceType(paramscope, t, parameters, &dedtypes);
                if (m <= MATCHnomatch)
                    goto Lnomatch;
                if (m < match)
                    match = m;          // pick worst match
            }
        }

        // Match attributes of tthis against attributes of fd
        if (fd->type && !fd->isCtorDeclaration())
        {
            StorageClass stc = scope->stc | fd->storage_class2;
            // Propagate parent storage class (see bug 5504)
            Dsymbol *p = parent;
            while (p->isTemplateDeclaration() || p->isTemplateInstance())
                p = p->parent;
            AggregateDeclaration *ad = p->isAggregateDeclaration();
            if (ad)
                stc |= ad->storage_class;

            unsigned char mod = fd->type->mod;
            if (stc & STCimmutable)
                mod = MODimmutable;
            else
            {
                if (stc & (STCshared | STCsynchronized))
                    mod |= MODshared;
                if (stc & STCconst)
                    mod |= MODconst;
                if (stc & STCwild)
                    mod |= MODwild;
            }

            unsigned char thismod = tthis->mod;
            if (hasttp)
                mod = MODmerge(thismod, mod);
            if (thismod != mod)
            {
                if (!MODmethodConv(thismod, mod))
                    goto Lnomatch;
                if (MATCHconst < match)
                    match = MATCHconst;
            }
        }
    }

    // Loop through the function parameters
    {
    //printf("%s nfargs=%d, nfparams=%d, tuple_dim = %d\n", toChars(), nfargs, nfparams, tuple_dim);
    //printf("\ttp = %p, fptupindex = %d, found = %d, tp_is_declared = %d\n", tp, fptupindex, fptupindex != IDX_NOTFOUND, tp_is_declared);
    size_t argi = 0;
    for (size_t parami = 0; parami < nfparams; parami++)
    {
        Parameter *fparam = Parameter::getNth(fparameters, parami);

        // Apply function parameter storage classes to parameter types
        Type *prmtype = fparam->type->addStorageClass(fparam->storageClass);

        /* See function parameters which wound up
         * as part of a template tuple parameter.
         */
        if (fptupindex != IDX_NOTFOUND && parami == fptupindex)
        {
            assert(prmtype->ty == Tident);
            TypeIdentifier *tid = (TypeIdentifier *)prmtype;
            if (!tp_is_declared)
            {
                /* The types of the function arguments
                 * now form the tuple argument.
                 */
                Tuple *t = new Tuple();
                (*dedargs)[parameters->dim - 1] = t;

                /* Count function parameters following a tuple parameter.
                 * void foo(U, T...)(int y, T, U, int) {}  // rem == 2 (U, int)
                 */
                size_t rem = 0;
                for (size_t j = parami + 1; j < nfparams; j++)
                {
                    Parameter *p = Parameter::getNth(fparameters, j);
                    if (!inferparams || !p->type->reliesOnTident(inferparams))
                    {
                        Type *pt = p->type->syntaxCopy()->semantic(fd->loc, paramscope);
                        rem += pt->ty == Ttuple ? ((TypeTuple *)pt)->arguments->dim : 1;
                    }
                    else
                    {
                        ++rem;
                    }
                }

                if (nfargs - argi < rem)
                    goto Lnomatch;
                tuple_dim = nfargs - argi - rem;
                t->objects.setDim(tuple_dim);
                for (size_t i = 0; i < tuple_dim; i++)
                {
                    Expression *farg = (*fargs)[argi + i];

                    // Check invalid arguments to detect errors early.
                    if (farg->op == TOKerror || farg->type->ty == Terror)
                        goto Lnomatch;

                    if (!(fparam->storageClass & STClazy) && farg->type->ty == Tvoid)
                        goto Lnomatch;

                    Type *tt;
                    MATCH m;

                    if (tid->mod & MODwild)
                    {
                        unsigned wm = farg->type->deduceWildHelper(&tt, tid);
                        if (wm)
                        {
                            wildmatch |= wm;
                            m = MATCHconst;
                            goto Lx;
                        }
                    }

                    m = farg->type->deduceTypeHelper(&tt, tid);
                    if (!m)
                        goto Lnomatch;

                Lx:
                    if (m <= MATCHnomatch)
                        goto Lnomatch;
                    if (m < match)
                        match = m;

                    /* Remove top const for dynamic array types and pointer types
                     */
                    if ((tt->ty == Tarray || tt->ty == Tpointer) &&
                        !tt->isMutable() &&
                        (!(fparam->storageClass & STCref) ||
                         (fparam->storageClass & STCauto) && !farg->isLvalue()))
                    {
                        tt = tt->mutableOf();
                    }
                    t->objects[i] = tt;
                }
                declareParameter(paramscope, tp, t);
            }
            argi += tuple_dim;
            continue;
        }

        // If parameter type doesn't depend on inferred template parameters,
        // semantic it to get actual type.
        if (!inferparams || !prmtype->reliesOnTident(inferparams))
        {
            // should copy prmtype to avoid affecting semantic result
            prmtype = prmtype->syntaxCopy()->semantic(fd->loc, paramscope);

            if (prmtype->ty == Ttuple)
            {
                TypeTuple *tt = (TypeTuple *)prmtype;
                size_t tt_dim = tt->arguments->dim;
                for (size_t j = 0; j < tt_dim; j++, ++argi)
                {
                    Parameter *p = (*tt->arguments)[j];
                    if (j == tt_dim - 1 && fvarargs == 2 && parami + 1 == nfparams && argi < nfargs)
                    {
                        prmtype = p->type;
                        goto Lvarargs;
                    }
                    if (argi >= nfargs)
                    {
                        if (p->defaultArg)
                            continue;
                        goto Lnomatch;
                    }
                    Expression *farg = (*fargs)[argi];
                    if (!farg->implicitConvTo(p->type))
                        goto Lnomatch;
                }
                continue;
            }
        }

        if (argi >= nfargs)                // if not enough arguments
        {
            if (fparam->defaultArg)
            {   /* Default arguments do not participate in template argument
                 * deduction.
                 */
                goto Lmatch;
            }
        }
        else
        {
            Expression *farg = (*fargs)[argi];

            // Check invalid arguments to detect errors early.
            if (farg->op == TOKerror || farg->type->ty == Terror)
                goto Lnomatch;

Lretry:
#if 0
            printf("\tfarg->type   = %s\n", farg->type->toChars());
            printf("\tfparam->type = %s\n", prmtype->toChars());
#endif
            Type *argtype = farg->type;

            /* Allow expressions that have CT-known boundaries and type [] to match with [dim]
             */
            Type *taai;
            if ( argtype->ty == Tarray &&
                (prmtype->ty == Tsarray ||
                 prmtype->ty == Taarray && (taai = ((TypeAArray *)prmtype)->index)->ty == Tident &&
                                           ((TypeIdentifier *)taai)->idents.dim == 0))
            {
                if (farg->op == TOKstring)
                {
                    StringExp *se = (StringExp *)farg;
                    argtype = argtype->nextOf()->sarrayOf(se->len);
                }
                else if (farg->op == TOKslice)
                {
                    SliceExp *se = (SliceExp *)farg;
                    Type *tsa = se->toStaticArrayType();
                    if (tsa)
                        argtype = tsa;
                }
                else if (farg->op == TOKarrayliteral)
                {
                    ArrayLiteralExp *ae = (ArrayLiteralExp *)farg;
                    argtype = argtype->nextOf()->sarrayOf(ae->elements->dim);
                }
            }

            /* Allow implicit function literals to delegate conversion
             */
            if (farg->op == TOKfunction)
            {   FuncExp *fe = (FuncExp *)farg;
                Expression *e = fe->inferType(prmtype, 1, paramscope, inferparams);
                if (!e)
                    goto Lvarargs;
                farg = e;
                argtype = farg->type;
            }

            if (!(fparam->storageClass & STClazy) && argtype->ty == Tvoid)
                goto Lnomatch;

            /* Remove top const for dynamic array types and pointer types
             */
            if ((argtype->ty == Tarray || argtype->ty == Tpointer) &&
                !argtype->isMutable() &&
                (!(fparam->storageClass & STCref) ||
                 (fparam->storageClass & STCauto) && !farg->isLvalue()))
            {
                argtype = argtype->mutableOf();
            }

            if (fvarargs == 2 && parami + 1 == nfparams && argi + 1 < nfargs)
                goto Lvarargs;

            unsigned wm = 0;
            MATCH m = argtype->deduceType(paramscope, prmtype, parameters, &dedtypes, &wm);
            //printf("\tdeduceType m = %d\n", m);
            //printf("\twildmatch = x%x m = %d\n", wildmatch, m);
            wildmatch |= wm;

            /* If no match, see if the argument can be matched by using
             * implicit conversions.
             */
            if (m == MATCHnomatch)
                m = farg->implicitConvTo(prmtype);

            /* If no match, see if there's a conversion to a delegate
             */
            if (m == MATCHnomatch)
            {   Type *tbp = prmtype->toBasetype();
                Type *tba = farg->type->toBasetype();
                if (tbp->ty == Tdelegate)
                {
                    TypeDelegate *td = (TypeDelegate *)prmtype->toBasetype();
                    TypeFunction *tf = (TypeFunction *)td->next;

                    if (!tf->varargs && Parameter::dim(tf->parameters) == 0)
                    {
                        m = farg->type->deduceType(paramscope, tf->next, parameters, &dedtypes);
                        if (m == MATCHnomatch && tf->next->toBasetype()->ty == Tvoid)
                            m = MATCHconvert;
                    }
                    //printf("\tm2 = %d\n", m);
                }
                else if (AggregateDeclaration *ad = isAggregate(tba))
                {
                    if (ad->aliasthis)
                    {
                        /* If a semantic error occurs while doing alias this,
                         * eg purity(bug 7295), just regard it as not a match.
                         */
                        unsigned olderrors = global.startGagging();
                        Expression *e = resolveAliasThis(sc, farg);
                        if (!global.endGagging(olderrors))
                        {
                            farg = e;
                            goto Lretry;
                        }
                    }
                }
            }

            if (m > MATCHnomatch && (fparam->storageClass & (STCref | STCauto)) == STCref)
            {
                if (!farg->isLvalue())
                {
                    if (farg->op == TOKstring && argtype->ty == Tsarray)
                    {
                    }
                    else if (farg->op == TOKslice && argtype->ty == Tsarray)
                    {   // Allow conversion from T[lwr .. upr] to ref T[upr-lwr]
                    }
                    else
                        goto Lnomatch;
                }
            }
            if (m > MATCHnomatch && (fparam->storageClass & STCout))
            {   if (!farg->isLvalue())
                    goto Lnomatch;
            }
            if (m == MATCHnomatch && (fparam->storageClass & STClazy) && prmtype->ty == Tvoid &&
                    farg->type->ty != Tvoid)
                m = MATCHconvert;

            if (m != MATCHnomatch)
            {   if (m < match)
                    match = m;          // pick worst match
                argi++;
                continue;
            }
        }

    Lvarargs:
        /* The following code for variadic arguments closely
         * matches TypeFunction::callMatch()
         */
        if (!(fvarargs == 2 && parami + 1 == nfparams))
            goto Lnomatch;

        /* Check for match with function parameter T...
         */
        Type *tb = prmtype->toBasetype();
        switch (tb->ty)
        {
            // 6764 fix - TypeAArray may be TypeSArray have not yet run semantic().
            case Tsarray:
            case Taarray:
            {   // Perhaps we can do better with this, see TypeFunction::callMatch()
                if (tb->ty == Tsarray)
                {   TypeSArray *tsa = (TypeSArray *)tb;
                    dinteger_t sz = tsa->dim->toInteger();
                    if (sz != nfargs - argi)
                        goto Lnomatch;
                }
                else if (tb->ty == Taarray)
                {   TypeAArray *taa = (TypeAArray *)tb;
                    Expression *dim = new IntegerExp(loc, nfargs - argi, Type::tsize_t);

                    size_t i = templateParameterLookup(taa->index, parameters);
                    if (i == IDX_NOTFOUND)
                    {   Expression *e;
                        Type *t;
                        Dsymbol *s;
                        taa->index->resolve(loc, sc, &e, &t, &s);
                        if (!e)
                            goto Lnomatch;
                        e = e->ctfeInterpret();
                        e = e->implicitCastTo(sc, Type::tsize_t);
                        e = e->optimize(WANTvalue);
                        if (!dim->equals(e))
                            goto Lnomatch;
                    }
                    else
                    {   // This code matches code in TypeInstance::deduceType()
                        TemplateParameter *tprm = (*parameters)[i];
                        TemplateValueParameter *tvp = tprm->isTemplateValueParameter();
                        if (!tvp)
                            goto Lnomatch;
                        Expression *e = (Expression *)dedtypes[i];
                        if (e)
                        {
                            if (!dim->equals(e))
                                goto Lnomatch;
                        }
                        else
                        {
                            Type *vt = tvp->valType->semantic(Loc(), sc);
                            MATCH m = (MATCH)dim->implicitConvTo(vt);
                            if (m <= MATCHnomatch)
                                goto Lnomatch;
                            dedtypes[i] = dim;
                        }
                    }
                }
                /* fall through */
            }
            case Tarray:
            {   TypeArray *ta = (TypeArray *)tb;
                for (; argi < nfargs; argi++)
                {
                    Expression *arg = (*fargs)[argi];
                    assert(arg);

                    if (arg->op == TOKfunction)
                    {   FuncExp *fe = (FuncExp *)arg;

                        Expression *e = fe->inferType(tb->nextOf(), 1, paramscope, inferparams);
                        if (!e)
                            goto Lnomatch;
                        arg = e;
                    }

                    MATCH m;
                    /* If lazy array of delegates,
                     * convert arg(s) to delegate(s)
                     */
                    Type *tret = fparam->isLazyArray();
                    if (tret)
                    {
                        if (ta->next->equals(arg->type))
                        {   m = MATCHexact;
                        }
                        else
                        {
                            m = arg->implicitConvTo(tret);
                            if (m == MATCHnomatch)
                            {
                                if (tret->toBasetype()->ty == Tvoid)
                                    m = MATCHconvert;
                            }
                        }
                    }
                    else
                    {
                        m = arg->type->deduceType(paramscope, ta->next, parameters, &dedtypes);
                        //m = arg->implicitConvTo(ta->next);
                    }
                    if (m == MATCHnomatch)
                        goto Lnomatch;
                    if (m < match)
                        match = m;
                }
                goto Lmatch;
            }
            case Tclass:
            case Tident:
                goto Lmatch;

            default:
                goto Lnomatch;
        }
        ++argi;
    }
    //printf("-> argi = %d, nfargs = %d\n", argi, nfargs);
    if (argi != nfargs && !fvarargs)
        goto Lnomatch;
    }

Lmatch:

    for (size_t i = ntargs; i < dedargs->dim; i++)
    {
        TemplateParameter *tparam = (*parameters)[i];
        //printf("tparam[%d] = %s\n", i, tparam->ident->toChars());
        /* For T:T*, the dedargs is the T*, dedtypes is the T
         * But for function templates, we really need them to match
         */
        RootObject *oarg = (*dedargs)[i];
        RootObject *oded = dedtypes[i];
        //printf("1dedargs[%d] = %p, dedtypes[%d] = %p\n", i, oarg, i, oded);
        //if (oarg) printf("oarg: %s\n", oarg->toChars());
        //if (oded) printf("oded: %s\n", oded->toChars());
        if (!oarg)
        {
            if (oded)
            {
                if (tparam->specialization() || !tparam->isTemplateTypeParameter())
                {   /* The specialization can work as long as afterwards
                     * the oded == oarg
                     */
                    (*dedargs)[i] = oded;
                    MATCH m2 = tparam->matchArg(loc, paramscope, dedargs, i, parameters, &dedtypes, NULL);
                    //printf("m2 = %d\n", m2);
                    if (m2 <= MATCHnomatch)
                        goto Lnomatch;
                    if (m2 < matchTiargs)
                        matchTiargs = m2;             // pick worst match
                    if (dedtypes[i] != oded)
                        error("specialization not allowed for deduced parameter %s", tparam->ident->toChars());
                }
                else
                {
                    if (MATCHconvert < matchTiargs)
                        matchTiargs = MATCHconvert;
                }
            }
            else
            {   oded = tparam->defaultArg(loc, paramscope);
                if (!oded)
                {
                    if (tp &&                           // if tuple parameter and
                        fptupindex == IDX_NOTFOUND &&   // tuple parameter was not in function parameter list and
                        ntargs == dedargs->dim - 1)     // we're one argument short (i.e. no tuple argument)
                    {   // make tuple argument an empty tuple
                        oded = (RootObject *)new Tuple();
                    }
                    else
                        goto Lnomatch;
                }
            }
            oded = declareParameter(paramscope, tparam, oded);
            (*dedargs)[i] = oded;
        }
    }

    if (constraint)
    {
        /* Check to see if constraint is satisfied.
         * Most of this code appears twice; this is a good candidate for refactoring.
         */
        makeParamNamesVisibleInConstraint(paramscope, fargs);
        Expression *e = constraint->syntaxCopy();

        /* Detect recursive attempts to instantiate this template declaration,
         * Bugzilla 4072
         *  void foo(T)(T x) if (is(typeof(foo(x)))) { }
         *  static assert(!is(typeof(foo(7))));
         * Recursive attempts are regarded as a constraint failure.
         */
        int nmatches = 0;
        for (Previous *p = previous; p; p = p->prev)
        {
            if (arrayObjectMatch(p->dedargs, dedargs))
            {
                //printf("recursive, no match p->sc=%p %p %s\n", p->sc, this, this->toChars());
                /* It must be a subscope of p->sc, other scope chains are not recursive
                 * instantiations.
                 */
                for (Scope *scx = sc; scx; scx = scx->enclosing)
                {
                    if (scx == p->sc)
                        goto Lnomatch;
                }
            }
            /* BUG: should also check for ref param differences
             */
        }

        Previous pr;
        pr.prev = previous;
        pr.sc = paramscope;
        pr.dedargs = dedargs;
        previous = &pr;                 // add this to threaded list

        int nerrors = global.errors;

        Dsymbol *s = parent;
        while (s->isTemplateInstance() || s->isTemplateMixin())
            s = s->parent;
        AggregateDeclaration *ad = s->isAggregateDeclaration();
        VarDeclaration *vthissave;
        if (fd && ad)
        {
            vthissave = fd->vthis;
            fd->vthis = fd->declareThis(paramscope, ad);
        }

        Scope *scx = paramscope->startCTFE();
        scx->flags |= SCOPEstaticif;
        e = e->semantic(scx);
        e = resolveProperties(scx, e);
        scx->endCTFE();

        if (fd && fd->vthis)
            fd->vthis = vthissave;

        previous = pr.prev;             // unlink from threaded list

        if (nerrors != global.errors)   // if any errors from evaluating the constraint, no match
            goto Lnomatch;
        if (e->op == TOKerror)
            goto Lnomatch;

        e = e->ctfeInterpret();
        if (e->isBool(true))
            ;
        else if (e->isBool(false))
            goto Lnomatch;
        else
        {
            e->error("constraint %s is not constant or does not evaluate to a bool", e->toChars());
        }
    }

#if 0
    for (i = 0; i < dedargs->dim; i++)
    {   Type *t = (*dedargs)[i];
        printf("\tdedargs[%d] = %d, %s\n", i, t->dyncast(), t->toChars());
    }
#endif

    paramscope->pop();
    //printf("\tmatch %d\n", match);
    return (MATCH)(match | (matchTiargs<<4));

Lnomatch:
    paramscope->pop();
    //printf("\tnomatch\n");
    return MATCHnomatch;
}

/**************************************************
 * Declare template parameter tp with value o, and install it in the scope sc.
 */

RootObject *TemplateDeclaration::declareParameter(Scope *sc, TemplateParameter *tp, RootObject *o)
{
    //printf("TemplateDeclaration::declareParameter('%s', o = %p)\n", tp->ident->toChars(), o);

    Type *targ = isType(o);
    Expression *ea = isExpression(o);
    Dsymbol *sa = isDsymbol(o);
    Tuple *va = isTuple(o);

    Dsymbol *s;
    VarDeclaration *v = NULL;

    if (ea && ea->op == TOKtype)
        targ = ea->type;
    else if (ea && ea->op == TOKimport)
        sa = ((ScopeExp *)ea)->sds;
    else if (ea && (ea->op == TOKthis || ea->op == TOKsuper))
        sa = ((ThisExp *)ea)->var;
    else if (ea && ea->op == TOKfunction)
    {
        if (((FuncExp *)ea)->td)
            sa = ((FuncExp *)ea)->td;
        else
            sa = ((FuncExp *)ea)->fd;
    }

    if (targ)
    {
        //printf("type %s\n", targ->toChars());
        s = new AliasDeclaration(Loc(), tp->ident, targ);
    }
    else if (sa)
    {
        //printf("Alias %s %s;\n", sa->ident->toChars(), tp->ident->toChars());
        s = new AliasDeclaration(Loc(), tp->ident, sa);
    }
    else if (ea)
    {
        // tdtypes.data[i] always matches ea here
        Initializer *init = new ExpInitializer(loc, ea);
        TemplateValueParameter *tvp = tp->isTemplateValueParameter();

        Type *t = tvp ? tvp->valType : NULL;

        v = new VarDeclaration(loc, t, tp->ident, init);
        v->storage_class = STCmanifest | STCtemplateparameter;
        s = v;
    }
    else if (va)
    {
        //printf("\ttuple\n");
        s = new TupleDeclaration(loc, tp->ident, &va->objects);
    }
    else
    {
#ifdef DEBUG
        o->print();
#endif
        assert(0);
    }
    if (!sc->insert(s))
        error("declaration %s is already defined", tp->ident->toChars());
    s->semantic(sc);
    /* So the caller's o gets updated with the result of semantic() being run on o
     */
    if (v)
        return (RootObject *)v->init->toExpression();
    return o;
}

/**************************************
 * Determine if TemplateDeclaration is variadic.
 */

TemplateTupleParameter *isVariadic(TemplateParameters *parameters)
{   size_t dim = parameters->dim;
    TemplateTupleParameter *tp = NULL;

    if (dim)
        tp = ((*parameters)[dim - 1])->isTemplateTupleParameter();
    return tp;
}

TemplateTupleParameter *TemplateDeclaration::isVariadic()
{
    return ::isVariadic(parameters);
}

/***********************************
 * We can overload templates.
 */

bool TemplateDeclaration::isOverloadable()
{
    return true;
}

/*************************************************
 * Given function arguments, figure out which template function
 * to expand, and return matching result.
 * Input:
 *      m               matching result
 *      dstart          the root of overloaded function templates
 *      loc             instantiation location
 *      sc              instantiation scope
 *      tiargs          initial list of template arguments
 *      tthis           if !NULL, the 'this' pointer argument
 *      fargs           arguments to function
 */

void functionResolve(Match *m, Dsymbol *dstart, Loc loc, Scope *sc,
        Objects *tiargs, Type *tthis, Expressions *fargs)
{
#if 0
    printf("functionResolve() dstart = %s\n", dstart->toChars());
    printf("    tiargs:\n");
    if (tiargs)
    {   for (size_t i = 0; i < tiargs->dim; i++)
        {   RootObject *arg = (*tiargs)[i];
            printf("\t%s\n", arg->toChars());
        }
    }
    printf("    fargs:\n");
    for (size_t i = 0; i < (fargs ? fargs->dim : 0); i++)
    {   Expression *arg = (*fargs)[i];
        printf("\t%s %s\n", arg->type->toChars(), arg->toChars());
        //printf("\tty = %d\n", arg->type->ty);
    }
    //printf("stc = %llx\n", dstart->scope->stc);
    //printf("match:t/f = %d/%d\n", ta_last, m->last);
#endif

  struct ParamDeduce
  {
    // context
    Loc loc;
    Scope *sc;
    Type *tthis;
    Objects *tiargs;
    Expressions *fargs;
    // result
    Match *m;
    int property;       // 0: unintialized
                        // 1: seen @property
                        // 2: not @property
    size_t ov_index;
    TemplateDeclaration *td_best;
    MATCH ta_last;
    Objects *tdargs;
    Type *tthis_best;

    static int fp(void *param, Dsymbol *s)
    {
        if (!s->errors)
        {
            if (FuncDeclaration *fd = s->isFuncDeclaration())
                return ((ParamDeduce *)param)->fp(fd);
            if (TemplateDeclaration *td = s->isTemplateDeclaration())
                return ((ParamDeduce *)param)->fp(td);
        }
        return 0;
    }
    int fp(FuncDeclaration *fd)
    {
        // skip duplicates
        if (fd == m->lastf)
            return 0;
        // explicitly specified tiargs never match to non template function
        if (tiargs && tiargs->dim > 0)
            return 0;

        //printf("fd = %s %s\n", fd->toChars(), fd->type->toChars());
        m->anyf = fd;
        TypeFunction *tf = (TypeFunction *)fd->type;

        int prop = (tf->isproperty) ? 1 : 2;
        if (property == 0)
            property = prop;
        else if (property != prop)
            error(fd->loc, "cannot overload both property and non-property functions");

        /* For constructors, qualifier check will be opposite direction.
         * Qualified constructor always makes qualified object, then will be checked
         * that it is implicitly convertible to tthis.
         */
        Type *tthis_fd = fd->needThis() ? tthis : NULL;
        if (tthis_fd && fd->isCtorDeclaration())
        {
            //printf("%s tf->mod = x%x tthis_fd->mod = x%x %d\n", tf->toChars(),
            //        tf->mod, tthis_fd->mod, fd->isolateReturn());
            if (MODimplicitConv(tf->mod, tthis_fd->mod) ||
                tf->isWild() && tf->isShared() == tthis_fd->isShared() ||
                fd->isolateReturn()/* && tf->isShared() == tthis_fd->isShared()*/)
            {   // Uniquely constructed object can ignore shared qualifier.
                // TODO: Is this appropriate?
                tthis_fd = NULL;
            }
            else
                return 0;   // MATCHnomatch
        }
        MATCH mfa = tf->callMatch(tthis_fd, fargs);
        //printf("test1: mfa = %d\n", mfa);
        if (mfa > MATCHnomatch)
        {
            if (mfa > m->last) goto LfIsBetter;
            if (mfa < m->last) goto LlastIsBetter;

            /* See if one of the matches overrides the other.
             */
            assert(m->lastf);
            if (m->lastf->overrides(fd)) goto LlastIsBetter;
            if (fd->overrides(m->lastf)) goto LfIsBetter;

            /* Try to disambiguate using template-style partial ordering rules.
             * In essence, if f() and g() are ambiguous, if f() can call g(),
             * but g() cannot call f(), then pick f().
             * This is because f() is "more specialized."
             */
            {
                MATCH c1 = fd->leastAsSpecialized(m->lastf);
                MATCH c2 = m->lastf->leastAsSpecialized(fd);
                //printf("c1 = %d, c2 = %d\n", c1, c2);
                if (c1 > c2) goto LfIsBetter;
                if (c1 < c2) goto LlastIsBetter;
            }

            /* If the two functions are the same function, like:
             *    int foo(int);
             *    int foo(int x) { ... }
             * then pick the one with the body.
             */
            if (tf->equals(m->lastf->type) &&
                fd->storage_class == m->lastf->storage_class &&
                fd->parent == m->lastf->parent &&
                fd->protection == m->lastf->protection &&
                fd->linkage == m->lastf->linkage)
            {
                if ( fd->fbody && !m->lastf->fbody) goto LfIsBetter;
                if (!fd->fbody &&  m->lastf->fbody) goto LlastIsBetter;
            }

        Lambiguous:
            m->nextf = fd;
            m->count++;
            return 0;

        LlastIsBetter:
            return 0;

        LfIsBetter:
            td_best = NULL;
            ta_last = MATCHexact;
            m->last = mfa;
            m->lastf = fd;
            tthis_best = tthis_fd;
            ov_index = 0;
            m->count = 1;
            tdargs->setDim(0);
            return 0;
        }
        return 0;
    }
    int fp(TemplateDeclaration *td)
    {
        // skip duplicates
        if (td == td_best)
            return 0;

        if (!sc)
            sc = td->scope; // workaround for Type::aliasthisOf

        if (td->semanticRun == PASSinit)
        {
            if (td->scope)
            {
                // Try to fix forward reference. Ungag errors while doing so.
                Ungag ungag = td->ungagSpeculative();
                td->semantic(td->scope);
            }
        }
        if (td->semanticRun == PASSinit)
        {
            ::error(loc, "forward reference to template %s", td->toChars());
        Lerror:
            m->lastf = NULL;
            m->count = 0;
            m->last = MATCHnomatch;
            return 1;
        }
        FuncDeclaration *f;
        f = td->onemember ? td->onemember/*->toAlias()*/->isFuncDeclaration() : NULL;
        if (!f)
        {
            if (!tiargs)
                tiargs = new Objects();
            TemplateInstance *ti = new TemplateInstance(loc, td, tiargs);

            Objects dedtypes;
            dedtypes.setDim(td->parameters->dim);
            assert(td->semanticRun != PASSinit);
            MATCH mta = td->matchWithInstance(sc, ti, &dedtypes, fargs, 0);
            //printf("matchWithInstance = %d\n", mta);
            if (mta <= MATCHnomatch || mta < ta_last)      // no match or less match
                return 0;

            ti->semantic(sc, fargs);
            if (!ti->inst)                  // if template failed to expand
                return 0;

            Dsymbol *s = ti->inst->toAlias();
            FuncDeclaration *fd;
            if (TemplateDeclaration *tdx = s->isTemplateDeclaration())
            {
                Objects dedtypesX;  // empty tiargs

                // Bugzilla 11553: Check for recursive instantiation of tdx.
                for (TemplateDeclaration::Previous *p = tdx->previous; p; p = p->prev)
                {
                    if (arrayObjectMatch(p->dedargs, &dedtypesX))
                    {
                        //printf("recursive, no match p->sc=%p %p %s\n", p->sc, this, this->toChars());
                        /* It must be a subscope of p->sc, other scope chains are not recursive
                         * instantiations.
                         */
                        for (Scope *scx = sc; scx; scx = scx->enclosing)
                        {
                            if (scx == p->sc)
                            {
                                error(loc, "recursive template expansion while looking for %s.%s", ti->toChars(), tdx->toChars());
                                goto Lerror;
                            }
                        }
                    }
                    /* BUG: should also check for ref param differences
                     */
                }

                TemplateDeclaration::Previous pr;
                pr.prev = tdx->previous;
                pr.sc = sc;
                pr.dedargs = &dedtypesX;
                tdx->previous = &pr;                 // add this to threaded list

                fd = resolveFuncCall(loc, sc, s, NULL, tthis, fargs, 1);

                tdx->previous = pr.prev;             // unlink from threaded list
            }
            else if (s->isFuncDeclaration())
            {
                fd = resolveFuncCall(loc, sc, s, NULL, tthis, fargs, 1);
            }
            else
                goto Lerror;

            if (!fd)
                return 0;

            Type *tthis_fd = fd->needThis() && !fd->isCtorDeclaration() ? tthis : NULL;

            TypeFunction *tf = (TypeFunction *)fd->type;
            MATCH mfa = tf->callMatch(tthis_fd, fargs);
            if (mfa < m->last)
                return 0;

            // td is the new best match
            assert(td->scope);
            td_best = td;
            property = 0;   // (backward compatibility)
            ta_last = mta;
            m->last = mfa;
            m->lastf = fd;
            tthis_best = tthis_fd;
            ov_index = 0;
            m->nextf = NULL;
            m->count = 1;
            tdargs->setDim(dedtypes.dim);
            memcpy(tdargs->tdata(), dedtypes.tdata(), tdargs->dim * sizeof(void *));
            return 0;
        }

        //printf("td = %s\n", td->toChars());
        for (size_t ovi = 0; f; f = f->overnext0, ovi++)
        {
            Objects dedtypes;
            FuncDeclaration *fd = NULL;
            int x = td->deduceFunctionTemplateMatch(f, loc, sc, tiargs, tthis, fargs, &dedtypes);
            MATCH mta = (MATCH)(x >> 4);
            MATCH mfa = (MATCH)(x & 0xF);
            //printf("match:t/f = %d/%d\n", mta, mfa);
            if (mfa <= MATCHnomatch)               // if no match
                continue;

            Type *tthis_fd = NULL;
            if (f->isCtorDeclaration())
            {
                // Constructor call requires additional check.
                // For that, do instantiate in early stage.
                fd = td->doHeaderInstantiation(sc, &dedtypes, tthis, fargs);
                if (!fd)
                    goto Lerror;

                TypeFunction *tf = (TypeFunction *)fd->type;
                tthis_fd = fd->needThis() ? tthis : NULL;
                if (tthis_fd)
                {
                    assert(tf->next);
                    if (MODimplicitConv(tf->mod, tthis_fd->mod) ||
                        tf->isWild() && tf->isShared() == tthis_fd->isShared() ||
                        fd->isolateReturn())
                    {
                        tthis_fd = NULL;
                    }
                    else
                        continue;   // MATCHnomatch
                }
            }

            if (mta < ta_last) goto Ltd_best;
            if (mta > ta_last) goto Ltd;

            if (mfa < m->last) goto Ltd_best;
            if (mfa > m->last) goto Ltd;

            if (td_best)
            {
                // Disambiguate by picking the most specialized TemplateDeclaration
                MATCH c1 = td->leastAsSpecialized(sc, td_best, fargs);
                MATCH c2 = td_best->leastAsSpecialized(sc, td, fargs);
                //printf("1: c1 = %d, c2 = %d\n", c1, c2);
                if (c1 > c2) goto Ltd;
                if (c1 < c2) goto Ltd_best;
            }

            if (!m->lastf)
            {
                assert(td_best);
                m->lastf = td_best->doHeaderInstantiation(sc, tdargs, tthis, fargs);
                if (!m->lastf) goto Lerror;
                tthis_best = m->lastf->needThis() ? tthis : NULL;
            }
            if (!fd)
            {
                fd = td->doHeaderInstantiation(sc, &dedtypes, tthis, fargs);
                if (!fd) goto Lerror;
                tthis_fd = fd->needThis() ? tthis : NULL;
            }
            assert(fd && m->lastf);

            {
                // Disambiguate by tf->callMatch
                TypeFunction *tf1 = (TypeFunction *)fd->type;
                assert(tf1->ty == Tfunction);
                TypeFunction *tf2 = (TypeFunction *)m->lastf->type;
                assert(tf2->ty == Tfunction);
                MATCH c1 = tf1->callMatch(tthis_fd,   fargs);
                MATCH c2 = tf2->callMatch(tthis_best, fargs);
                //printf("2: c1 = %d, c2 = %d\n", c1, c2);
                if (c1 > c2) goto Ltd;
                if (c1 < c2) goto Ltd_best;
            }
            {
                // Disambiguate by picking the most specialized FunctionDeclaration
                MATCH c1 = fd->leastAsSpecialized(m->lastf);
                MATCH c2 = m->lastf->leastAsSpecialized(fd);
                //printf("3: c1 = %d, c2 = %d\n", c1, c2);
                if (c1 > c2) goto Ltd;
                if (c1 < c2) goto Ltd_best;
            }

          Lambig:   // td_best and td are ambiguous
            //printf("Lambig\n");
            m->nextf = fd;  // Caution! m->nextf isn't complete instantiated fd, so must not call toPrettyChars()
            m->count++;
            continue;

          Ltd_best:         // td_best is the best match so far
            //printf("Ltd_best\n");
            continue;

          Ltd:              // td is the new best match
            //printf("Ltd\n");
            assert(td->scope);
            td_best = td;
            property = 0;   // (backward compatibility)
            ta_last = mta;
            m->last = mfa;
            m->lastf = fd;
            tthis_best = tthis_fd;
            ov_index = ovi;
            m->nextf = NULL;
            m->count = 1;
            tdargs->setDim(dedtypes.dim);
            memcpy(tdargs->tdata(), dedtypes.tdata(), tdargs->dim * sizeof(void *));
            continue;
        }
        return 0;
    }
  };
    ParamDeduce p;
    // context
    p.loc    = loc;
    p.sc     = sc;
    p.tthis  = tthis;
    p.tiargs = tiargs;
    p.fargs  = fargs;

    // result
    p.m          = m;
    p.property   = 0;
    p.ov_index   = 0;
    p.td_best    = NULL;
    p.ta_last    = m->last != MATCHnomatch ? MATCHexact : MATCHnomatch;
    p.tdargs     = new Objects();
    p.tthis_best = NULL;

    FuncDeclaration *fd = dstart->isFuncDeclaration();
    TemplateDeclaration *td = dstart->isTemplateDeclaration();
    if (td && td->funcroot)
        dstart = td->funcroot;
    overloadApply(dstart, &p, &ParamDeduce::fp);

    //printf("td_best = %p, m->lastf = %p\n", p.td_best, m->lastf);
    if (p.td_best)
    {
        // Matches to template function
        if (!p.td_best->onemember || !p.td_best->onemember->toAlias()->isFuncDeclaration())
            return; // goto Lerror?

        /* The best match is td_best with arguments tdargs.
         * Now instantiate the template.
         */
        assert(p.td_best->scope);
        if (!sc) sc = p.td_best->scope; // workaround for Type::aliasthisOf

        TemplateInstance *ti = new TemplateInstance(loc, p.td_best, p.tdargs);
        ti->semantic(sc, fargs);

        m->lastf = ti->toAlias()->isFuncDeclaration();
        if (ti->errors || !m->lastf)
            goto Lerror;

        // look forward instantiated overload function
        // Dsymbol::oneMembers is alredy called in TemplateInstance::semantic.
        // it has filled overnext0d
        while (p.ov_index--)
        {
            m->lastf = m->lastf->overnext0;
            assert(m->lastf);
        }

        p.tthis_best = m->lastf->needThis() && !m->lastf->isCtorDeclaration() ? tthis : NULL;

        TypeFunction *tf = (TypeFunction *)m->lastf->type;
        if (tf->ty == Terror)
            goto Lerror;
        assert(tf->ty == Tfunction);
        if (!tf->callMatch(p.tthis_best, fargs))
        {
            m->lastf = NULL;
            m->count = 0;
            goto Lerror;
        }

        if (FuncLiteralDeclaration *fld = m->lastf->isFuncLiteralDeclaration())
        {
            if ((sc->flags & SCOPEstaticif) || sc->intypeof)
            {
                // Inside template constraint, or inside typeof,
                // nested reference check doesn't work correctly.
            }
            else if (fld->tok == TOKreserved)
            {
                // change to non-nested
                fld->tok = TOKfunction;
                fld->vthis = NULL;
            }
        }

        /* As Bugzilla 3682 shows, a template instance can be matched while instantiating
         * that same template. Thus, the function type can be incomplete. Complete it.
         *
         * Bugzilla 9208: For auto function, completion should be deferred to the end of
         * its semantic3. Should not complete it in here.
         */
        if (tf->next && !m->lastf->inferRetType)
        {
            m->lastf->type = tf->semantic(loc, sc);
        }
    }
    else if (m->lastf)
    {
        // Matches to non template function
    }
    else
    {
    Lerror:
        // Keep m->lastf and m->count as-is.
        m->last = MATCHnomatch;
    }
}

/*************************************************
 * Limited function template instantiation for using fd->leastAsSpecialized()
 */
FuncDeclaration *TemplateDeclaration::doHeaderInstantiation(Scope *sc,
        Objects *tdargs, Type *tthis, Expressions *fargs)
{
    FuncDeclaration *fd = onemember->toAlias()->isFuncDeclaration();
    if (!fd)
        return NULL;

#if 0
    printf("doHeaderInstantiation this = %s\n", toChars());
    for (size_t i = 0; i < tdargs->dim; ++i)
        printf("\ttdargs[%d] = %s\n", i, ((RootObject *)tdargs->data[i])->toChars());
#endif

    assert(scope);
    TemplateInstance *ti = new TemplateInstance(loc, this, tdargs);
    ti->tinst = sc->tinst;
    {
        ti->tdtypes.setDim(parameters->dim);
        if (matchWithInstance(sc, ti, &ti->tdtypes, fargs, 2) <= MATCHnomatch)
            return NULL;
    }

    ti->parent = parent;

    // function body and contracts are not need
    //fd = fd->syntaxCopy(NULL)->isFuncDeclaration();
    if (fd->isCtorDeclaration())
        fd = new CtorDeclaration(fd->loc, fd->endloc, fd->storage_class, fd->type->syntaxCopy());
    else
        fd = new FuncDeclaration(fd->loc, fd->endloc, fd->ident, fd->storage_class, fd->type->syntaxCopy());
    fd->parent = ti;

    Module *mi = sc->instantiatingModule ? sc->instantiatingModule : sc->module;

    Scope *scope = this->scope;
    ti->argsym = new ScopeDsymbol();
    ti->argsym->parent = scope->parent;
    scope = scope->push(ti->argsym);
    scope->instantiatingModule = mi;

    bool hasttp = false;

    Scope *paramscope = scope->push();
    paramscope->stc = 0;
    ti->declareParameters(paramscope);
    paramscope->pop();

    if (tthis)
    {
        // Match 'tthis' to any TemplateThisParameter's
        for (size_t i = 0; i < parameters->dim; i++)
        {   TemplateParameter *tp = (*parameters)[i];
            TemplateThisParameter *ttp = tp->isTemplateThisParameter();
            if (ttp)
                hasttp = true;
        }
    }
    {
        TypeFunction *tf = (TypeFunction *)fd->type;
        if (tf && tf->ty == Tfunction)
            tf->fargs = fargs;
    }

    Scope *sc2;
    sc2 = scope->push(ti);
    sc2->parent = /*enclosing ? sc->parent :*/ ti;
    sc2->tinst = ti;

    {
        Scope *scx = sc2;
        scx = scx->push();

        if (hasttp)
            fd->type = fd->type->addMod(tthis->mod);
        //printf("tthis = %s, fdtype = %s\n", tthis->toChars(), fd->type->toChars());
        if (fd->isCtorDeclaration())
        {
            scx->flags |= SCOPEctor;

            Dsymbol *parent = toParent2();
            Type *tret;
            AggregateDeclaration *ad = parent->isAggregateDeclaration();
            if (!ad || parent->isUnionDeclaration())
            {
                tret = Type::tvoid;
            }
            else
            {   tret = ad->handle;
                assert(tret);
                tret = tret->addStorageClass(fd->storage_class | scx->stc);
                tret = tret->addMod(fd->type->mod);
            }
            ((TypeFunction *)fd->type)->next = tret;
            if (ad && ad->isStructDeclaration())
                ((TypeFunction *)fd->type)->isref = 1;
            //printf("fd->type = %s\n", fd->type->toChars());
        }
        fd->type = fd->type->addSTC(scx->stc);
        fd->type = fd->type->semantic(fd->loc, scx);
        scx = scx->pop();
    }
    //printf("\t[%s] fd->type = %s, mod = %x, ", loc.toChars(), fd->type->toChars(), fd->type->mod);
    //printf("fd->needThis() = %d\n", fd->needThis());

    sc2->pop();
    scope->pop();

    return fd->type->ty == Tfunction ? fd : NULL;
}

bool TemplateDeclaration::hasStaticCtorOrDtor()
{
    return false;               // don't scan uninstantiated templates
}

void TemplateDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
#if 0 // Should handle template functions for doc generation
    if (onemember && onemember->isFuncDeclaration())
        buf->writestring("foo ");
#endif
    if (hgs->hdrgen && members && members->dim == 1)
    {
        FuncDeclaration *fd = (*members)[0]->isFuncDeclaration();
        if (fd && fd->type && fd->type->ty == Tfunction && fd->ident == ident)
        {
            TypeFunction *tf = (TypeFunction *)fd->type;
            tf->toCBufferWithAttributes(buf, ident, hgs, tf, this);

            if (constraint)
            {
                buf->writestring(" if (");
                constraint->toCBuffer(buf, hgs);
                buf->writeByte(')');
            }

            hgs->tpltMember++;
            fd->bodyToCBuffer(buf, hgs);
            hgs->tpltMember--;
            return;
        }

        AggregateDeclaration *ad = (*members)[0]->isAggregateDeclaration();
        if (ad)
        {
            buf->writestring(ad->kind());
            buf->writeByte(' ');
            buf->writestring(ident->toChars());
            buf->writeByte('(');
            for (size_t i = 0; i < parameters->dim; i++)
            {
                TemplateParameter *tp = (*parameters)[i];
                if (hgs->ddoc)
                    tp = (*origParameters)[i];
                if (i)
                    buf->writestring(", ");
                tp->toCBuffer(buf, hgs);
            }
            buf->writeByte(')');

            if (constraint)
            {
                buf->writestring(" if (");
                constraint->toCBuffer(buf, hgs);
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
                    b->type->toCBuffer(buf, NULL, hgs);
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
                {
                    Dsymbol *s = (*ad->members)[i];
                    s->toCBuffer(buf, hgs);
                }
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
        buf->writestring(kind());
    else
        buf->writestring("template");
    buf->writeByte(' ');
    buf->writestring(ident->toChars());
    buf->writeByte('(');
    for (size_t i = 0; i < parameters->dim; i++)
    {
        TemplateParameter *tp = (*parameters)[i];
        if (hgs->ddoc)
            tp = (*origParameters)[i];
        if (i)
            buf->writestring(", ");
        tp->toCBuffer(buf, hgs);
    }
    buf->writeByte(')');
    if (constraint)
    {
        buf->writestring(" if (");
        constraint->toCBuffer(buf, hgs);
        buf->writeByte(')');
    }

    if (hgs->hdrgen)
    {
        hgs->tpltMember++;
        buf->writenl();
        buf->writebyte('{');
        buf->writenl();
        buf->level++;
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->toCBuffer(buf, hgs);
        }
        buf->level--;
        buf->writebyte('}');
        buf->writenl();
        hgs->tpltMember--;
    }
}


char *TemplateDeclaration::toChars()
{
    if (literal)
        return Dsymbol::toChars();

    OutBuffer buf;
    HdrGenState hgs;

    memset(&hgs, 0, sizeof(hgs));
    buf.writestring(ident->toChars());
    buf.writeByte('(');
    for (size_t i = 0; i < parameters->dim; i++)
    {
        TemplateParameter *tp = (*parameters)[i];
        if (i)
            buf.writestring(", ");
        tp->toCBuffer(&buf, &hgs);
    }
    buf.writeByte(')');

    if (onemember)
    {
        /* Bugzilla 9406:
         * onemember->toAlias() might run semantic, so should not call it in stringizing
         */
        FuncDeclaration *fd = onemember->isFuncDeclaration();
        if (fd && fd->type)
        {
            TypeFunction *tf = (TypeFunction *)fd->type;
            char const* args = Parameter::argsTypesToChars(tf->parameters, tf->varargs);
            buf.writestring(args);
        }
    }

    if (constraint)
    {
        buf.writestring(" if (");
        constraint->toCBuffer(&buf, &hgs);
        buf.writeByte(')');
    }
    buf.writeByte(0);
    return (char *)buf.extractData();
}

PROT TemplateDeclaration::prot()
{
    return protection;
}

/****************************************************
 * Given a new instance tithis of this TemplateDeclaration,
 * see if there already exists an instance.
 * If so, return that existing instance.
 */

TemplateInstance *TemplateDeclaration::findExistingInstance(TemplateInstance *tithis, Expressions *fargs)
{
    tithis->fargs = fargs;
    hash_t hash = tithis->hashCode();

    if (!buckets.dim)
    {
        buckets.setDim(7);
        buckets.zero();
    }
    size_t bi = hash % buckets.dim;
    TemplateInstances *instances = buckets[bi];
    if (instances)
    {
        for (size_t i = 0; i < instances->dim; i++)
        {
            TemplateInstance *ti = (*instances)[i];
#if LOG
            printf("\t%s: checking for match with instance %d (%p): '%s'\n", tithis->toChars(), i, ti, ti->toChars());
#endif
            if (hash == ti->hash &&
                tithis->compare(ti) == 0)
            {
                //printf("hash = %p yes %d n = %d\n", hash, instances->dim, numinstances);
                return ti;
            }
        }
    }
    //printf("hash = %p no\n", hash);
    return NULL;        // didn't find a match
}

/********************************************
 * Add instance ti to TemplateDeclaration's table of instances.
 * Return a handle we can use to later remove it if it fails instantiation.
 */

TemplateInstance *TemplateDeclaration::addInstance(TemplateInstance *ti)
{
    /* See if we need to rehash
     */
    if (numinstances > buckets.dim * 4)
    {   // rehash
        //printf("rehash\n");
        size_t newdim = buckets.dim * 2 + 1;
        TemplateInstances **newp = (TemplateInstances **)::calloc(newdim, sizeof(TemplateInstances *));
        assert(newp);
        for (size_t bi = 0; bi < buckets.dim; ++bi)
        {
            TemplateInstances *instances = buckets[bi];
            if (instances)
            {
                for (size_t i = 0; i < instances->dim; i++)
                {
                    TemplateInstance *ti1 = (*instances)[i];
                    size_t newbi = ti1->hash % newdim;
                    TemplateInstances *newinstances = newp[newbi];
                    if (!newinstances)
                        newp[newbi] = newinstances = new TemplateInstances();
                    newinstances->push(ti1);
                }
                delete instances;
            }
        }
        buckets.setDim(newdim);
        memcpy(buckets.tdata(), newp, newdim * sizeof(TemplateInstance *));
        ::free(newp);
    }

    // Insert ti into hash table
    size_t bi = ti->hash % buckets.dim;
    TemplateInstances *instances = buckets[bi];
    if (!instances)
        buckets[bi] = instances = new TemplateInstances();
    instances->push(ti);
    ++numinstances;
    return ti;
}

/*******************************************
 * Remove TemplateInstance from table of instances.
 * Input:
 *      handle returned by addInstance()
 */

void TemplateDeclaration::removeInstance(TemplateInstance *handle)
{
    size_t bi = handle->hash % buckets.dim;
    TemplateInstances *instances = buckets[bi];
    for (size_t i = 0; i < instances->dim; i++)
    {
        TemplateInstance *ti = (*instances)[i];
        if (handle == ti)
        {   instances->remove(i);
            break;
        }
    }
    --numinstances;
}

/* ======================== Type ============================================ */

/****
 * Given an identifier, figure out which TemplateParameter it is.
 * Return IDX_NOTFOUND if not found.
 */

size_t templateIdentifierLookup(Identifier *id, TemplateParameters *parameters)
{
    for (size_t i = 0; i < parameters->dim; i++)
    {   TemplateParameter *tp = (*parameters)[i];

        if (tp->ident->equals(id))
            return i;
    }
    return IDX_NOTFOUND;
}

size_t templateParameterLookup(Type *tparam, TemplateParameters *parameters)
{
    if (tparam->ty == Tident)
    {
        TypeIdentifier *tident = (TypeIdentifier *)tparam;
        //printf("\ttident = '%s'\n", tident->toChars());
        return templateIdentifierLookup(tident->ident, parameters);
    }
    return IDX_NOTFOUND;
}

unsigned Type::deduceWildHelper(Type **at, Type *tparam)
{
    assert(tparam->mod & MODwild);
    *at = NULL;

    #define X(U,T)  ((U) << 4) | (T)
    switch (X(tparam->mod, mod))
    {
        case X(MODwild,                     0):
        case X(MODwild,                     MODconst):
        case X(MODwild,                     MODshared):
        case X(MODwild,                     MODshared | MODconst):
        case X(MODwild,                     MODimmutable):
        case X(MODwildconst,                0):
        case X(MODwildconst,                MODconst):
        case X(MODwildconst,                MODshared):
        case X(MODwildconst,                MODshared | MODconst):
        case X(MODwildconst,                MODimmutable):
        case X(MODshared | MODwild,         MODshared):
        case X(MODshared | MODwild,         MODshared | MODconst):
        case X(MODshared | MODwild,         MODimmutable):
        case X(MODshared | MODwildconst,    MODshared):
        case X(MODshared | MODwildconst,    MODshared | MODconst):
        case X(MODshared | MODwildconst,    MODimmutable):
        {
            unsigned wm = (mod & ~MODshared);
            if (wm == 0)
                wm = MODmutable;
            unsigned m = (mod & (MODconst | MODimmutable)) | (tparam->mod & mod & MODshared);
            *at = unqualify(m);
            return wm;
        }

        case X(MODwild,                     MODwild):
        case X(MODwild,                     MODwildconst):
        case X(MODwild,                     MODshared | MODwild):
        case X(MODwild,                     MODshared | MODwildconst):
        case X(MODwildconst,                MODwild):
        case X(MODwildconst,                MODwildconst):
        case X(MODwildconst,                MODshared | MODwild):
        case X(MODwildconst,                MODshared | MODwildconst):
        case X(MODshared | MODwild,         MODshared | MODwild):
        case X(MODshared | MODwild,         MODshared | MODwildconst):
        case X(MODshared | MODwildconst,    MODshared | MODwild):
        case X(MODshared | MODwildconst,    MODshared | MODwildconst):
        {
            *at = unqualify(tparam->mod & mod);
            return MODwild;
        }

        default:
            return 0;
    }
    #undef X
}

MATCH Type::deduceTypeHelper(Type **at, Type *tparam)
{
    // 9*9 == 81 cases

    #define X(U,T)  ((U) << 4) | (T)
    switch (X(tparam->mod, mod))
    {
        case X(0, 0):
        case X(0, MODconst):
        case X(0, MODwild):
        case X(0, MODwildconst):
        case X(0, MODshared):
        case X(0, MODshared | MODconst):
        case X(0, MODshared | MODwild):
        case X(0, MODshared | MODwildconst):
        case X(0, MODimmutable):
            // foo(U)                       T                       => T
            // foo(U)                       const(T)                => const(T)
            // foo(U)                       inout(T)                => inout(T)
            // foo(U)                       inout(const(T))         => inout(const(T))
            // foo(U)                       shared(T)               => shared(T)
            // foo(U)                       shared(const(T))        => shared(const(T))
            // foo(U)                       shared(inout(T))        => shared(inout(T))
            // foo(U)                       shared(inout(const(T))) => shared(inout(const(T)))
            // foo(U)                       immutable(T)            => immutable(T)
        {
            *at = this;
            return MATCHexact;
        }

        case X(MODconst,                    MODconst):
        case X(MODwild,                     MODwild):
        case X(MODwildconst,                MODwildconst):
        case X(MODshared,                   MODshared):
        case X(MODshared | MODconst,        MODshared | MODconst):
        case X(MODshared | MODwild,         MODshared | MODwild):
        case X(MODshared | MODwildconst,    MODshared | MODwildconst):
        case X(MODimmutable,                MODimmutable):
            // foo(const(U))                const(T)                => T
            // foo(inout(U))                inout(T)                => T
            // foo(inout(const(U)))         inout(const(T))         => T
            // foo(shared(U))               shared(T)               => T
            // foo(shared(const(U)))        shared(const(T))        => T
            // foo(shared(inout(U)))        shared(inout(T))        => T
            // foo(shared(inout(const(U)))) shared(inout(const(T))) => T
            // foo(immutable(U))            immutable(T)            => T
        {
            *at = mutableOf()->unSharedOf();
            return MATCHexact;
        }

        case X(MODconst,                    0):
        case X(MODconst,                    MODwild):
        case X(MODconst,                    MODwildconst):
        case X(MODconst,                    MODshared | MODconst):
        case X(MODconst,                    MODshared | MODwild):
        case X(MODconst,                    MODshared | MODwildconst):
        case X(MODconst,                    MODimmutable):
        case X(MODwild,                     MODshared | MODwild):
        case X(MODwildconst,                MODshared | MODwildconst):
        case X(MODshared | MODconst,        MODimmutable):
            // foo(const(U))                T                       => T
            // foo(const(U))                inout(T)                => T
            // foo(const(U))                inout(const(T))         => T
            // foo(const(U))                shared(const(T))        => shared(T)
            // foo(const(U))                shared(inout(T))        => shared(T)
            // foo(const(U))                shared(inout(const(T))) => shared(T)
            // foo(const(U))                immutable(T)            => T
            // foo(inout(U))                shared(inout(T))        => shared(T)
            // foo(inout(const(U)))         shared(inout(const(T))) => shared(T)
            // foo(shared(const(U)))        immutable(T)            => T
        {
            *at = mutableOf();
            return MATCHconst;
        }

        case X(MODconst,                    MODshared):
            // foo(const(U))                shared(T)               => shared(T)
        {
            *at = this;
            return MATCHconst;
        }

        case X(MODshared,                   MODshared | MODconst):
        case X(MODshared,                   MODshared | MODwild):
        case X(MODshared,                   MODshared | MODwildconst):
        case X(MODshared | MODconst,        MODshared):
            // foo(shared(U))               shared(const(T))        => const(T)
            // foo(shared(U))               shared(inout(T))        => inout(T)
            // foo(shared(U))               shared(inout(const(T))) => inout(const(T))
            // foo(shared(const(U)))        shared(T)               => T
        {
            *at = unSharedOf();
            return MATCHconst;
        }

        case X(MODwildconst,                MODimmutable):
        case X(MODshared | MODconst,        MODshared | MODwildconst):
        case X(MODshared | MODwildconst,    MODimmutable):
        case X(MODshared | MODwildconst,    MODshared | MODwild):
            // foo(inout(const(U)))         immutable(T)            => T
            // foo(shared(const(U)))        shared(inout(const(T))) => T
            // foo(shared(inout(const(U)))) immutable(T)            => T
            // foo(shared(inout(const(U)))) shared(inout(T))        => T
        {
            *at = unSharedOf()->mutableOf();
            return MATCHconst;
        }

        case X(MODshared | MODconst,        MODshared | MODwild):
            // foo(shared(const(U)))        shared(inout(T))        => T
        {
            *at = unSharedOf()->mutableOf();
            return MATCHconst;
        }

        case X(MODwild,                     0):
        case X(MODwild,                     MODconst):
        case X(MODwild,                     MODwildconst):
        case X(MODwild,                     MODimmutable):
        case X(MODwild,                     MODshared):
        case X(MODwild,                     MODshared | MODconst):
        case X(MODwild,                     MODshared | MODwildconst):
        case X(MODwildconst,                0):
        case X(MODwildconst,                MODconst):
        case X(MODwildconst,                MODwild):
        case X(MODwildconst,                MODshared):
        case X(MODwildconst,                MODshared | MODconst):
        case X(MODwildconst,                MODshared | MODwild):
        case X(MODshared,                   0):
        case X(MODshared,                   MODconst):
        case X(MODshared,                   MODwild):
        case X(MODshared,                   MODwildconst):
        case X(MODshared,                   MODimmutable):
        case X(MODshared | MODconst,        0):
        case X(MODshared | MODconst,        MODconst):
        case X(MODshared | MODconst,        MODwild):
        case X(MODshared | MODconst,        MODwildconst):
        case X(MODshared | MODwild,         0):
        case X(MODshared | MODwild,         MODconst):
        case X(MODshared | MODwild,         MODwild):
        case X(MODshared | MODwild,         MODwildconst):
        case X(MODshared | MODwild,         MODimmutable):
        case X(MODshared | MODwild,         MODshared):
        case X(MODshared | MODwild,         MODshared | MODconst):
        case X(MODshared | MODwild,         MODshared | MODwildconst):
        case X(MODshared | MODwildconst,    0):
        case X(MODshared | MODwildconst,    MODconst):
        case X(MODshared | MODwildconst,    MODwild):
        case X(MODshared | MODwildconst,    MODwildconst):
        case X(MODshared | MODwildconst,    MODshared):
        case X(MODshared | MODwildconst,    MODshared | MODconst):
        case X(MODimmutable,                0):
        case X(MODimmutable,                MODconst):
        case X(MODimmutable,                MODwild):
        case X(MODimmutable,                MODwildconst):
        case X(MODimmutable,                MODshared):
        case X(MODimmutable,                MODshared | MODconst):
        case X(MODimmutable,                MODshared | MODwild):
        case X(MODimmutable,                MODshared | MODwildconst):
            // foo(inout(U))                T                       => nomatch
            // foo(inout(U))                const(T)                => nomatch
            // foo(inout(U))                inout(const(T))         => nomatch
            // foo(inout(U))                immutable(T)            => nomatch
            // foo(inout(U))                shared(T)               => nomatch
            // foo(inout(U))                shared(const(T))        => nomatch
            // foo(inout(U))                shared(inout(const(T))) => nomatch
            // foo(inout(const(U)))         T                       => nomatch
            // foo(inout(const(U)))         const(T)                => nomatch
            // foo(inout(const(U)))         inout(T)                => nomatch
            // foo(inout(const(U)))         shared(T)               => nomatch
            // foo(inout(const(U)))         shared(const(T))        => nomatch
            // foo(inout(const(U)))         shared(inout(T))        => nomatch
            // foo(shared(U))               T                       => nomatch
            // foo(shared(U))               const(T)                => nomatch
            // foo(shared(U))               inout(T)                => nomatch
            // foo(shared(U))               inout(const(T))         => nomatch
            // foo(shared(U))               immutable(T)            => nomatch
            // foo(shared(const(U)))        T                       => nomatch
            // foo(shared(const(U)))        const(T)                => nomatch
            // foo(shared(const(U)))        inout(T)                => nomatch
            // foo(shared(const(U)))        inout(const(T))         => nomatch
            // foo(shared(inout(U)))        T                       => nomatch
            // foo(shared(inout(U)))        const(T)                => nomatch
            // foo(shared(inout(U)))        inout(T)                => nomatch
            // foo(shared(inout(U)))        inout(const(T))         => nomatch
            // foo(shared(inout(U)))        immutable(T)            => nomatch
            // foo(shared(inout(U)))        shared(T)               => nomatch
            // foo(shared(inout(U)))        shared(const(T))        => nomatch
            // foo(shared(inout(U)))        shared(inout(const(T))) => nomatch
            // foo(shared(inout(const(U)))) T                       => nomatch
            // foo(shared(inout(const(U)))) const(T)                => nomatch
            // foo(shared(inout(const(U)))) inout(T)                => nomatch
            // foo(shared(inout(const(U)))) inout(const(T))         => nomatch
            // foo(shared(inout(const(U)))) shared(T)               => nomatch
            // foo(shared(inout(const(U)))) shared(const(T))        => nomatch
            // foo(immutable(U))            T                       => nomatch
            // foo(immutable(U))            const(T)                => nomatch
            // foo(immutable(U))            inout(T)                => nomatch
            // foo(immutable(U))            inout(const(T))         => nomatch
            // foo(immutable(U))            shared(T)               => nomatch
            // foo(immutable(U))            shared(const(T))        => nomatch
            // foo(immutable(U))            shared(inout(T))        => nomatch
            // foo(immutable(U))            shared(inout(const(T))) => nomatch
            return MATCHnomatch;

        default:
            assert(0);
    }
    #undef X
}

/* These form the heart of template argument deduction.
 * Given 'this' being the type argument to the template instance,
 * it is matched against the template declaration parameter specialization
 * 'tparam' to determine the type to be used for the parameter.
 * Example:
 *      template Foo(T:T*)      // template declaration
 *      Foo!(int*)              // template instantiation
 * Input:
 *      this = int*
 *      tparam = T*
 *      parameters = [ T:T* ]   // Array of TemplateParameter's
 * Output:
 *      dedtypes = [ int ]      // Array of Expression/Type's
 */

MATCH Type::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
        Objects *dedtypes, unsigned *wm)
{
#if 0
    printf("Type::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif
    if (!tparam)
        goto Lnomatch;

    if (this == tparam)
        goto Lexact;

    if (tparam->ty == Tident)
    {
        // Determine which parameter tparam is
        size_t i = templateParameterLookup(tparam, parameters);
        if (i == IDX_NOTFOUND)
        {
            if (!sc)
                goto Lnomatch;

            /* Need a loc to go with the semantic routine.
             */
            Loc loc;
            if (parameters->dim)
            {
                TemplateParameter *tp = (*parameters)[0];
                loc = tp->loc;
            }

            /* BUG: what if tparam is a template instance, that
             * has as an argument another Tident?
             */
            tparam = tparam->semantic(loc, sc);
            assert(tparam->ty != Tident);
            return deduceType(sc, tparam, parameters, dedtypes, wm);
        }

        TemplateParameter *tp = (*parameters)[i];

        TypeIdentifier *tident = (TypeIdentifier *)tparam;
        if (tident->idents.dim > 0)
        {
            //printf("matching %s to %s\n", tparam->toChars(), toChars());
            Dsymbol *s = this->toDsymbol(sc);
            for (size_t j = tident->idents.dim; j-- > 0; )
            {
                RootObject *id = tident->idents[j];
                if (id->dyncast() == DYNCAST_IDENTIFIER)
                {
                    if (!s || !s->parent)
                        goto Lnomatch;
                    Dsymbol *s2 = s->parent->searchX(Loc(), sc, id);
                    if (!s2)
                        goto Lnomatch;
                    s2 = s2->toAlias();
                    //printf("[%d] s = %s %s, s2 = %s %s\n", j, s->kind(), s->toChars(), s2->kind(), s2->toChars());
                    if (s != s2)
                    {
                        if (Type *t = s2->getType())
                        {
                            if (s != t->toDsymbol(sc))
                                goto Lnomatch;
                        }
                        else
                            goto Lnomatch;
                    }
                    s = s->parent;
                }
                else
                    goto Lnomatch;
            }
            //printf("[e] s = %s\n", s?s->toChars():"(null)");
            if (TemplateTypeParameter *ttp = tp->isTemplateTypeParameter())
            {
                Type *tt = s->getType();
                if (!tt)
                    goto Lnomatch;
                Type *at = (Type *)(*dedtypes)[i];
                if (!at || tt->equals(at))
                {
                    (*dedtypes)[i] = tt;
                    goto Lexact;
                }
            }
            if (TemplateAliasParameter *tap = tp->isTemplateAliasParameter())
            {
                Dsymbol *s2 = (Dsymbol *)(*dedtypes)[i];
                if (!s2 || s == s2)
                {
                    (*dedtypes)[i] = s;
                    goto Lexact;
                }
            }
            goto Lnomatch;
        }

        // Found the corresponding parameter tp
        if (!tp->isTemplateTypeParameter())
            goto Lnomatch;
        Type *tt;
        Type *at = (Type *)(*dedtypes)[i];

        if (wm && (tparam->mod & MODwild))
        {
            unsigned wx = deduceWildHelper(&tt, tparam);
            if (wx)
            {
                if (!at)
                {
                    (*dedtypes)[i] = tt;
                    *wm |= wx;
                    goto Lconst;
                }

                if (tt->equals(at))
                {
                    goto Lconst;
                }
                if (tt->implicitConvTo(at->constOf()))
                {
                    (*dedtypes)[i] = at->constOf()->mutableOf();
                    *wm |= MODconst;
                    goto Lconst;
                }
                if (at->implicitConvTo(tt->constOf()))
                {
                    (*dedtypes)[i] = tt->constOf()->mutableOf();
                    *wm |= MODconst;
                    goto Lconst;
                }
                goto Lnomatch;
            }
        }

        MATCH m = deduceTypeHelper(&tt, tparam);
        if (m)
        {
            if (!at)
            {
                (*dedtypes)[i] = tt;
                if (m == MATCHexact)
                    goto Lexact;
                else
                    goto Lconst;
            }

            if (tt->equals(at))
            {
                goto Lexact;
            }
            if (tt->ty == Tclass && at->ty == Tclass)
            {
                return tt->implicitConvTo(at);
            }
            if (tt->ty == Tsarray && at->ty == Tarray &&
                tt->nextOf()->implicitConvTo(at->nextOf()) >= MATCHconst)
            {
                goto Lexact;
            }
        }
        goto Lnomatch;
    }
    else if (tparam->ty == Ttypeof)
    {
        /* Need a loc to go with the semantic routine.
         */
        Loc loc;
        if (parameters->dim)
        {
            TemplateParameter *tp = (*parameters)[0];
            loc = tp->loc;
        }

        tparam = tparam->semantic(loc, sc);
    }

    if (ty != tparam->ty)
    {
        if (Dsymbol *sym = toDsymbol(sc))
        {
            if (sym->isforwardRef() && !tparam->deco)
                goto Lnomatch;
        }

        // Can't instantiate AssociativeArray!() without a scope
        if (tparam->ty == Taarray && !((TypeAArray*)tparam)->sc)
            ((TypeAArray*)tparam)->sc = sc;

        MATCH m = implicitConvTo(tparam);
        if (m == MATCHnomatch)
        {
            Type *at = aliasthisOf();
            if (at)
                m = at->deduceType(sc, tparam, parameters, dedtypes, wm);
        }
        return m;
    }

    if (nextOf())
    {
        if (tparam->deco && !tparam->hasWild())
            return implicitConvTo(tparam);

        return nextOf()->deduceType(sc, tparam->nextOf(), parameters, dedtypes, wm);
    }

Lexact:
    return MATCHexact;

Lnomatch:
    return MATCHnomatch;

Lconst:
    return MATCHconst;
}

MATCH TypeVector::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
        Objects *dedtypes, unsigned *wm)
{
#if 0
    printf("TypeVector::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif
    if (tparam->ty == Tvector)
    {
        TypeVector *tp = (TypeVector *)tparam;
        return basetype->deduceType(sc, tp->basetype, parameters, dedtypes, wm);
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);
}

MATCH TypeDArray::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
        Objects *dedtypes, unsigned *wm)
{
#if 0
    printf("TypeDArray::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);
}

MATCH TypeSArray::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
        Objects *dedtypes, unsigned *wm)
{
#if 0
    printf("TypeSArray::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif

    // Extra check that array dimensions must match
    if (tparam)
    {
        if (tparam->ty == Tarray)
        {
            MATCH m = next->deduceType(sc, tparam->nextOf(), parameters, dedtypes, wm);
            if (m == MATCHexact)
                m = MATCHconvert;
            return m;
        }

        Identifier *id = NULL;
        if (tparam->ty == Tsarray)
        {
            TypeSArray *tp = (TypeSArray *)tparam;
            if (tp->dim->op == TOKvar &&
                ((VarExp *)tp->dim)->var->storage_class & STCtemplateparameter)
            {
                id = ((VarExp *)tp->dim)->var->ident;
            }
            else if (dim->toInteger() != tp->dim->toInteger())
                return MATCHnomatch;
        }
        else if (tparam->ty == Taarray)
        {
            TypeAArray *tp = (TypeAArray *)tparam;
            if (tp->index->ty == Tident &&
                ((TypeIdentifier *)tp->index)->idents.dim == 0)
            {
                id = ((TypeIdentifier *)tp->index)->ident;
            }
        }
        if (id)
        {
            // This code matches code in TypeInstance::deduceType()
            size_t i = templateIdentifierLookup(id, parameters);
            if (i == IDX_NOTFOUND)
                goto Lnomatch;
            TemplateParameter *tp = (*parameters)[i];
            if (!tp->matchArg(sc, dim, i, parameters, dedtypes, NULL))
                goto Lnomatch;
            return next->deduceType(sc, tparam->nextOf(), parameters, dedtypes, wm);
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);

  Lnomatch:
    return MATCHnomatch;
}

MATCH TypeAArray::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wm)
{
#if 0
    printf("TypeAArray::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif

    // Extra check that index type must match
    if (tparam && tparam->ty == Taarray)
    {
        TypeAArray *tp = (TypeAArray *)tparam;
        if (!index->deduceType(sc, tp->index, parameters, dedtypes))
        {
            return MATCHnomatch;
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);
}

MATCH TypeFunction::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wm)
{
    //printf("TypeFunction::deduceType()\n");
    //printf("\tthis   = %d, ", ty); print();
    //printf("\ttparam = %d, ", tparam->ty); tparam->print();

    // Extra check that function characteristics must match
    if (tparam && tparam->ty == Tfunction)
    {
        TypeFunction *tp = (TypeFunction *)tparam;
        if (varargs != tp->varargs ||
            linkage != tp->linkage)
            return MATCHnomatch;

        size_t nfargs = Parameter::dim(this->parameters);
        size_t nfparams = Parameter::dim(tp->parameters);

        // bug 2579 fix: Apply function parameter storage classes to parameter types
        for (size_t i = 0; i < nfparams; i++)
        {
            Parameter *fparam = Parameter::getNth(tp->parameters, i);
            fparam->type = fparam->type->addStorageClass(fparam->storageClass);
            fparam->storageClass &= ~(STC_TYPECTOR | STCin);
        }
        //printf("\t-> this   = %d, ", ty); print();
        //printf("\t-> tparam = %d, ", tparam->ty); tparam->print();

        /* See if tuple match
         */
        if (nfparams > 0 && nfargs >= nfparams - 1)
        {
            /* See if 'A' of the template parameter matches 'A'
             * of the type of the last function parameter.
             */
            Parameter *fparam = Parameter::getNth(tp->parameters, nfparams - 1);
            assert(fparam);
            assert(fparam->type);
            if (fparam->type->ty != Tident)
                goto L1;
            TypeIdentifier *tid = (TypeIdentifier *)fparam->type;
            if (tid->idents.dim)
                goto L1;

            /* Look through parameters to find tuple matching tid->ident
             */
            size_t tupi = 0;
            for (; 1; tupi++)
            {   if (tupi == parameters->dim)
                    goto L1;
                TemplateParameter *t = (*parameters)[tupi];
                TemplateTupleParameter *tup = t->isTemplateTupleParameter();
                if (tup && tup->ident->equals(tid->ident))
                    break;
            }

            /* The types of the function arguments [nfparams - 1 .. nfargs]
             * now form the tuple argument.
             */
            size_t tuple_dim = nfargs - (nfparams - 1);

            /* See if existing tuple, and whether it matches or not
             */
            RootObject *o = (*dedtypes)[tupi];
            if (o)
            {   // Existing deduced argument must be a tuple, and must match
                Tuple *t = isTuple(o);
                if (!t || t->objects.dim != tuple_dim)
                    return MATCHnomatch;
                for (size_t i = 0; i < tuple_dim; i++)
                {   Parameter *arg = Parameter::getNth(this->parameters, nfparams - 1 + i);
                    if (!arg->type->equals(t->objects[i]))
                        return MATCHnomatch;
                }
            }
            else
            {   // Create new tuple
                Tuple *t = new Tuple();
                t->objects.setDim(tuple_dim);
                for (size_t i = 0; i < tuple_dim; i++)
                {   Parameter *arg = Parameter::getNth(this->parameters, nfparams - 1 + i);
                    t->objects[i] = arg->type;
                }
                (*dedtypes)[tupi] = t;
            }
            nfparams--; // don't consider the last parameter for type deduction
            goto L2;
        }

    L1:
        if (nfargs != nfparams)
            return MATCHnomatch;
    L2:
        for (size_t i = 0; i < nfparams; i++)
        {
            Parameter *a = Parameter::getNth(this->parameters, i);
            Parameter *ap = Parameter::getNth(tp->parameters, i);
            if (a->storageClass != ap->storageClass ||
                !a->type->deduceType(sc, ap->type, parameters, dedtypes))
                return MATCHnomatch;
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);
}

MATCH TypeIdentifier::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wm)
{
    // Extra check
    if (tparam && tparam->ty == Tident)
    {
        TypeIdentifier *tp = (TypeIdentifier *)tparam;

        for (size_t i = 0; i < idents.dim; i++)
        {
            RootObject *id1 = idents[i];
            RootObject *id2 = tp->idents[i];

            if (!id1->equals(id2))
                return MATCHnomatch;
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);
}

MATCH TypeInstance::deduceType(Scope *sc,
        Type *tparam, TemplateParameters *parameters,
        Objects *dedtypes, unsigned *wm)
{
#if 0
    printf("TypeInstance::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif
    // Extra check
    if (tparam && tparam->ty == Tinstance && tempinst->tempdecl)
    {
        TemplateDeclaration *tempdecl = tempinst->tempdecl->isTemplateDeclaration();
        assert(tempdecl);

        TypeInstance *tp = (TypeInstance *)tparam;

        //printf("tempinst->tempdecl = %p\n", tempdecl);
        //printf("tp->tempinst->tempdecl = %p\n", tp->tempinst->tempdecl);
        if (!tp->tempinst->tempdecl)
        {
            //printf("tp->tempinst->name = '%s'\n", tp->tempinst->name->toChars());
            if (!tp->tempinst->name->equals(tempinst->name))
            {
                /* Handle case of:
                 *  template Foo(T : sa!(T), alias sa)
                 */
                size_t i = templateIdentifierLookup(tp->tempinst->name, parameters);
                if (i == IDX_NOTFOUND)
                {
                    /* Didn't find it as a parameter identifier. Try looking
                     * it up and seeing if is an alias. See Bugzilla 1454
                     */
                    TypeIdentifier *tid = new TypeIdentifier(tp->loc, tp->tempinst->name);
                    Type *t;
                    Expression *e;
                    Dsymbol *s;
                    tid->resolve(tp->loc, sc, &e, &t, &s);
                    if (t)
                    {
                        s = t->toDsymbol(sc);
                        if (s)
                        {
                            TemplateInstance *ti = s->parent->isTemplateInstance();
                            s = ti ? ti->tempdecl : NULL;
                        }
                    }
                    if (s)
                    {
                        s = s->toAlias();
                        TemplateDeclaration *td = s->isTemplateDeclaration();
                        if (td && td == tempdecl)
                            goto L2;
                    }
                    goto Lnomatch;
                }
                TemplateParameter *tpx = (*parameters)[i];
                if (!tpx->matchArg(sc, tempdecl, i, parameters, dedtypes, NULL))
                    goto Lnomatch;
            }
        }
        else if (tempdecl != tp->tempinst->tempdecl)
            goto Lnomatch;

      L2:

        for (size_t i = 0; 1; i++)
        {
            //printf("\ttest: tempinst->tiargs[%d]\n", i);
            RootObject *o1 = NULL;
            if (i < tempinst->tiargs->dim)
                o1 = (*tempinst->tiargs)[i];
            else if (i < tempinst->tdtypes.dim && i < tp->tempinst->tiargs->dim)
                // Pick up default arg
                o1 = tempinst->tdtypes[i];
            else if (i >= tp->tempinst->tiargs->dim)
                break;

            if (i >= tp->tempinst->tiargs->dim)
                goto Lnomatch;

            RootObject *o2 = (*tp->tempinst->tiargs)[i];
            Type *t2 = isType(o2);

            size_t j;
            if (t2 &&
                t2->ty == Tident &&
                i == tp->tempinst->tiargs->dim - 1 &&
                (j = templateParameterLookup(t2, parameters), j != IDX_NOTFOUND) &&
                j == parameters->dim - 1 &&
                (*parameters)[j]->isTemplateTupleParameter())
            {
                /* Given:
                 *  struct A(B...) {}
                 *  alias A!(int, float) X;
                 *  static if (is(X Y == A!(Z), Z...)) {}
                 * deduce that Z is a tuple(int, float)
                 */

                /* Create tuple from remaining args
                 */
                Tuple *vt = new Tuple();
                size_t vtdim = (tempdecl->isVariadic()
                                ? tempinst->tiargs->dim : tempinst->tdtypes.dim) - i;
                vt->objects.setDim(vtdim);
                for (size_t k = 0; k < vtdim; k++)
                {
                    RootObject *o;
                    if (k < tempinst->tiargs->dim)
                        o = (*tempinst->tiargs)[i + k];
                    else    // Pick up default arg
                        o = tempinst->tdtypes[i + k];
                    vt->objects[k] = o;
                }

                Tuple *v = (Tuple *)(*dedtypes)[j];
                if (v)
                {
                    if (!match(v, vt))
                        goto Lnomatch;
                }
                else
                    (*dedtypes)[j] = vt;
                break; //return MATCHexact;
            }
            else if (!o1)
                break;

            Type *t1 = isType(o1);
            Dsymbol *s1 = isDsymbol(o1);
            Dsymbol *s2 = isDsymbol(o2);
            Expression *e1 = s1 ? getValue(s1) : getValue(isExpression(o1));
            Expression *e2 = isExpression(o2);
            Tuple *v1 = isTuple(o1);
            Tuple *v2 = isTuple(o2);
#if 0
            if (t1)     printf("t1 = %s\n", t1->toChars());
            if (t2)     printf("t2 = %s\n", t2->toChars());
            if (e1)     printf("e1 = %s\n", e1->toChars());
            if (e2)     printf("e2 = %s\n", e2->toChars());
            if (s1)     printf("s1 = %s\n", s1->toChars());
            if (s2)     printf("s2 = %s\n", s2->toChars());
            if (v1)     printf("v1 = %s\n", v1->toChars());
            if (v2)     printf("v2 = %s\n", v2->toChars());
#endif

            if (t1 && t2)
            {
                if (!t1->deduceType(sc, t2, parameters, dedtypes))
                    goto Lnomatch;
            }
            else if (e1 && e2)
            {
            Le:
                e1 = e1->ctfeInterpret();

                /* If it is one of the template parameters for this template,
                 * we should not attempt to interpret it. It already has a value.
                 */
                if (e2->op == TOKvar &&
                    (((VarExp *)e2)->var->storage_class & STCtemplateparameter))
                {
                    /*
                     * (T:Number!(e2), int e2)
                     */
                    j = templateIdentifierLookup(((VarExp *)e2)->var->ident, parameters);
                    if (j != IDX_NOTFOUND)
                        goto L1;
                    // The template parameter was not from this template
                    // (it may be from a parent template, for example)
                }

                e2 = e2->ctfeInterpret();

                //printf("e1 = %s, type = %s %d\n", e1->toChars(), e1->type->toChars(), e1->type->ty);
                //printf("e2 = %s, type = %s %d\n", e2->toChars(), e2->type->toChars(), e2->type->ty);
                if (!e1->equals(e2))
                {
                    if (!e2->implicitConvTo(e1->type))
                        goto Lnomatch;

                    e2 = e2->implicitCastTo(sc, e1->type);
                    e2 = e2->ctfeInterpret();
                    if (!e1->equals(e2))
                        goto Lnomatch;
                }
            }
            else if (e1 && t2 && t2->ty == Tident)
            {
                j = templateParameterLookup(t2, parameters);
            L1:
                if (j == IDX_NOTFOUND)
                {
                    t2->resolve(((TypeIdentifier *)t2)->loc, sc, &e2, &t2, &s2);
                    if (e2)
                        goto Le;
                    goto Lnomatch;
                }
                if (!(*parameters)[j]->matchArg(sc, e1, j, parameters, dedtypes, NULL))
                    goto Lnomatch;
            }
            else if (s1 && s2)
            {
            Ls:
                if (!s1->equals(s2))
                    goto Lnomatch;
            }
            else if (s1 && t2 && t2->ty == Tident)
            {
                j = templateParameterLookup(t2, parameters);
                if (j == IDX_NOTFOUND)
                {
                    t2->resolve(((TypeIdentifier *)t2)->loc, sc, &e2, &t2, &s2);
                    if (s2)
                        goto Ls;
                    goto Lnomatch;
                }
                if (!(*parameters)[j]->matchArg(sc, s1, j, parameters, dedtypes, NULL))
                    goto Lnomatch;
            }
            else
                goto Lnomatch;
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);

Lnomatch:
    //printf("no match\n");
    return MATCHnomatch;
}

MATCH TypeStruct::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wm)
{
    MATCH m;
    if (sym->aliasthis)
    {
        if (att & RECtracingDT)
            m = MATCHnomatch;
        else
        {
            att = (AliasThisRec)(att | RECtracingDT);
            m = deduceTypeNoRecursion(sc, tparam, parameters, dedtypes, wm);
            att = (AliasThisRec)(att & ~RECtracingDT);
        }
    }
    else
        m = deduceTypeNoRecursion(sc, tparam, parameters, dedtypes, wm);

    return m;
}

MATCH TypeStruct::deduceTypeNoRecursion(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wm)
{
    //printf("TypeStruct::deduceType()\n");
    //printf("\tthis->parent   = %s, ", sym->parent->toChars()); print();
    //printf("\ttparam = %d, ", tparam->ty); tparam->print();

    /* If this struct is a template struct, and we're matching
     * it against a template instance, convert the struct type
     * to a template instance, too, and try again.
     */
    TemplateInstance *ti = sym->parent->isTemplateInstance();

    if (tparam && tparam->ty == Tinstance)
    {
        if (ti && ti->toAlias() == sym)
        {
            TypeInstance *t = new TypeInstance(Loc(), ti);
            return t->deduceType(sc, tparam, parameters, dedtypes, wm);
        }

        /* Match things like:
         *  S!(T).foo
         */
        TypeInstance *tpi = (TypeInstance *)tparam;
        if (tpi->idents.dim)
        {
            RootObject *id = tpi->idents[tpi->idents.dim - 1];
            if (id->dyncast() == DYNCAST_IDENTIFIER && sym->ident->equals((Identifier *)id))
            {
                Type *tparent = sym->parent->getType();
                if (tparent)
                {
                    /* Slice off the .foo in S!(T).foo
                     */
                    tpi->idents.dim--;
                    MATCH m = tparent->deduceType(sc, tpi, parameters, dedtypes, wm);
                    tpi->idents.dim++;
                    return m;
                }
            }
        }
    }

    // Extra check
    if (tparam && tparam->ty == Tstruct)
    {
        TypeStruct *tp = (TypeStruct *)tparam;

        //printf("\t%d\n", (MATCH) implicitConvTo(tp));
        if (wm && deduceWild(tparam, false))
            return MATCHconst;
        return implicitConvTo(tp);
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);
}

MATCH TypeEnum::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wm)
{
    // Extra check
    if (tparam && tparam->ty == Tenum)
    {
        TypeEnum *tp = (TypeEnum *)tparam;

        if (sym != tp->sym)
            return MATCHnomatch;
    }
    Type *tb = toBasetype();
    if (tb->ty == tparam->ty ||
        tb->ty == Tsarray && tparam->ty == Taarray)
    {
        return tb->deduceType(sc, tparam, parameters, dedtypes, wm);
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);
}

MATCH TypeTypedef::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wm)
{
    // Extra check
    if (tparam && tparam->ty == Ttypedef)
    {
        TypeTypedef *tp = (TypeTypedef *)tparam;

        if (sym != tp->sym)
            return MATCHnomatch;
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);
}

/* Helper for TypeClass::deduceType().
 * Classes can match with implicit conversion to a base class or interface.
 * This is complicated, because there may be more than one base class which
 * matches. In such cases, one or more parameters remain ambiguous.
 * For example,
 *
 *   interface I(X, Y) {}
 *   class C : I(uint, double), I(char, double) {}
 *   C x;
 *   foo(T, U)( I!(T, U) x)
 *
 *   deduces that U is double, but T remains ambiguous (could be char or uint).
 *
 * Given a baseclass b, and initial deduced types 'dedtypes', this function
 * tries to match tparam with b, and also tries all base interfaces of b.
 * If a match occurs, numBaseClassMatches is incremented, and the new deduced
 * types are ANDed with the current 'best' estimate for dedtypes.
 */
void deduceBaseClassParameters(BaseClass *b,
    Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes,
    Objects *best, int &numBaseClassMatches)
{
    TemplateInstance *parti = b->base ? b->base->parent->isTemplateInstance() : NULL;
    if (parti)
    {
        // Make a temporary copy of dedtypes so we don't destroy it
        Objects *tmpdedtypes = new Objects();
        tmpdedtypes->setDim(dedtypes->dim);
        memcpy(tmpdedtypes->tdata(), dedtypes->tdata(), dedtypes->dim * sizeof(void *));

        TypeInstance *t = new TypeInstance(Loc(), parti);
        MATCH m = t->deduceType(sc, tparam, parameters, tmpdedtypes);
        if (m > MATCHnomatch)
        {
            // If this is the first ever match, it becomes our best estimate
            if (numBaseClassMatches==0)
                memcpy(best->tdata(), tmpdedtypes->tdata(), tmpdedtypes->dim * sizeof(void *));
            else for (size_t k = 0; k < tmpdedtypes->dim; ++k)
            {
                // If we've found more than one possible type for a parameter,
                // mark it as unknown.
                if ((*tmpdedtypes)[k] != (*best)[k])
                    (*best)[k] = (*dedtypes)[k];
            }
            ++numBaseClassMatches;
        }
    }
    // Now recursively test the inherited interfaces
    for (size_t j = 0; j < b->baseInterfaces_dim; ++j)
    {
        deduceBaseClassParameters( &(b->baseInterfaces)[j],
            sc, tparam, parameters, dedtypes,
            best, numBaseClassMatches);
    }

}

MATCH TypeClass::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wm)
{
    MATCH m;
    if (sym->aliasthis)
    {
        if (att & RECtracingDT)
            m = MATCHnomatch;
        else
        {
            att = (AliasThisRec)(att | RECtracingDT);
            m = deduceTypeNoRecursion(sc, tparam, parameters, dedtypes, wm);
            att = (AliasThisRec)(att & ~RECtracingDT);
        }
    }
    else
        m = deduceTypeNoRecursion(sc, tparam, parameters, dedtypes, wm);

    return m;
}

MATCH TypeClass::deduceTypeNoRecursion(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wm)
{
    //printf("TypeClass::deduceType(this = %s)\n", toChars());

    /* If this class is a template class, and we're matching
     * it against a template instance, convert the class type
     * to a template instance, too, and try again.
     */
    TemplateInstance *ti = sym->parent->isTemplateInstance();

    if (tparam && tparam->ty == Tinstance)
    {
        if (ti && ti->toAlias() == sym)
        {
            TypeInstance *t = new TypeInstance(Loc(), ti);
            MATCH m = t->deduceType(sc, tparam, parameters, dedtypes, wm);
            // Even if the match fails, there is still a chance it could match
            // a base class.
            if (m != MATCHnomatch)
                return m;
        }

        /* Match things like:
         *  S!(T).foo
         */
        TypeInstance *tpi = (TypeInstance *)tparam;
        if (tpi->idents.dim)
        {   RootObject *id = tpi->idents[tpi->idents.dim - 1];
            if (id->dyncast() == DYNCAST_IDENTIFIER && sym->ident->equals((Identifier *)id))
            {
                Type *tparent = sym->parent->getType();
                if (tparent)
                {
                    /* Slice off the .foo in S!(T).foo
                     */
                    tpi->idents.dim--;
                    MATCH m = tparent->deduceType(sc, tpi, parameters, dedtypes, wm);
                    tpi->idents.dim++;
                    return m;
                }
            }
        }

        // If it matches exactly or via implicit conversion, we're done
        MATCH m = Type::deduceType(sc, tparam, parameters, dedtypes, wm);
        if (m != MATCHnomatch)
            return m;

        /* There is still a chance to match via implicit conversion to
         * a base class or interface. Because there could be more than one such
         * match, we need to check them all.
         */

        int numBaseClassMatches = 0; // Have we found an interface match?

        // Our best guess at dedtypes
        Objects *best = new Objects();
        best->setDim(dedtypes->dim);

        ClassDeclaration *s = sym;
        while (s && s->baseclasses->dim > 0)
        {
            // Test the base class
            deduceBaseClassParameters((*s->baseclasses)[0],
                sc, tparam, parameters, dedtypes,
                best, numBaseClassMatches);

            // Test the interfaces inherited by the base class
            for (size_t i = 0; i < s->interfaces_dim; ++i)
            {
                BaseClass *b = s->interfaces[i];
                deduceBaseClassParameters(b, sc, tparam, parameters, dedtypes,
                    best, numBaseClassMatches);
            }
            s = (*s->baseclasses)[0]->base;
        }

        if (numBaseClassMatches == 0)
            return MATCHnomatch;

        // If we got at least one match, copy the known types into dedtypes
        memcpy(dedtypes->tdata(), best->tdata(), best->dim * sizeof(void *));
        return MATCHconvert;
    }

    // Extra check
    if (tparam && tparam->ty == Tclass)
    {
        TypeClass *tp = (TypeClass *)tparam;

        //printf("\t%d\n", (MATCH) implicitConvTo(tp));
        if (wm && deduceWild(tparam, false))
            return MATCHconst;
        return implicitConvTo(tp);
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wm);
}

/* ======================== TemplateParameter =============================== */

TemplateParameter::TemplateParameter(Loc loc, Identifier *ident)
{
    this->loc = loc;
    this->ident = ident;
    this->sparam = NULL;
}

TemplateTypeParameter  *TemplateParameter::isTemplateTypeParameter()
{
    return NULL;
}

TemplateValueParameter *TemplateParameter::isTemplateValueParameter()
{
    return NULL;
}

TemplateAliasParameter *TemplateParameter::isTemplateAliasParameter()
{
    return NULL;
}

TemplateTupleParameter *TemplateParameter::isTemplateTupleParameter()
{
    return NULL;
}

TemplateThisParameter  *TemplateParameter::isTemplateThisParameter()
{
    return NULL;
}

/*******************************************
 * Match to a particular TemplateParameter.
 * Input:
 *      i               i'th argument
 *      tiargs[]        actual arguments to template instance
 *      parameters[]    template parameters
 *      dedtypes[]      deduced arguments to template instance
 *      *psparam        set to symbol declared and initialized to dedtypes[i]
 */

MATCH TemplateParameter::matchArg(Loc loc, Scope *sc, Objects *tiargs,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    RootObject *oarg;

    if (i < tiargs->dim)
        oarg = (*tiargs)[i];
    else
    {
        // Get default argument instead
        oarg = defaultArg(loc, sc);
        if (!oarg)
        {
            assert(i < dedtypes->dim);
            // It might have already been deduced
            oarg = (*dedtypes)[i];
            if (!oarg)
                goto Lnomatch;
        }
    }
    return matchArg(sc, oarg, i, parameters, dedtypes, psparam);

Lnomatch:
    if (psparam)
        *psparam = NULL;
    return MATCHnomatch;
}

/* ======================== TemplateTypeParameter =========================== */

// type-parameter

Type *TemplateTypeParameter::tdummy = NULL;

TemplateTypeParameter::TemplateTypeParameter(Loc loc, Identifier *ident, Type *specType,
        Type *defaultType)
    : TemplateParameter(loc, ident)
{
    this->ident = ident;
    this->specType = specType;
    this->defaultType = defaultType;
}

TemplateTypeParameter  *TemplateTypeParameter::isTemplateTypeParameter()
{
    return this;
}

TemplateParameter *TemplateTypeParameter::syntaxCopy()
{
    TemplateTypeParameter *tp = new TemplateTypeParameter(loc, ident, specType, defaultType);
    if (tp->specType)
        tp->specType = specType->syntaxCopy();
    if (defaultType)
        tp->defaultType = defaultType->syntaxCopy();
    return tp;
}

void TemplateTypeParameter::declareParameter(Scope *sc)
{
    //printf("TemplateTypeParameter::declareParameter('%s')\n", ident->toChars());
    TypeIdentifier *ti = new TypeIdentifier(loc, ident);
    sparam = new AliasDeclaration(loc, ident, ti);
    if (!sc->insert(sparam))
        error(loc, "parameter '%s' multiply defined", ident->toChars());
}

void TemplateTypeParameter::semantic(Scope *sc, TemplateParameters *parameters)
{
    //printf("TemplateTypeParameter::semantic('%s')\n", ident->toChars());
    if (specType && !specType->reliesOnTident(parameters))
    {
        specType = specType->semantic(loc, sc);
    }
#if 0 // Don't do semantic() until instantiation
    if (defaultType)
    {
        defaultType = defaultType->semantic(loc, sc);
    }
#endif
}

/****************************************
 * Determine if two TemplateParameters are the same
 * as far as TemplateDeclaration overloading goes.
 * Returns:
 *      1       match
 *      0       no match
 */

int TemplateTypeParameter::overloadMatch(TemplateParameter *tp)
{
    TemplateTypeParameter *ttp = tp->isTemplateTypeParameter();

    if (ttp)
    {
        if (specType != ttp->specType)
            goto Lnomatch;

        if (specType && !specType->equals(ttp->specType))
            goto Lnomatch;

        return 1;                       // match
    }

Lnomatch:
    return 0;
}

MATCH TemplateTypeParameter::matchArg(Scope *sc, RootObject *oarg,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    //printf("TemplateTypeParameter::matchArg()\n");
    MATCH m = MATCHexact;
    Type *ta = isType(oarg);
    if (!ta)
    {
        //printf("%s %p %p %p\n", oarg->toChars(), isExpression(oarg), isDsymbol(oarg), isTuple(oarg));
        goto Lnomatch;
    }
    //printf("ta is %s\n", ta->toChars());

    if (specType)
    {
        if (!ta || ta == tdummy)
            goto Lnomatch;

        //printf("\tcalling deduceType(): ta is %s, specType is %s\n", ta->toChars(), specType->toChars());
        MATCH m2 = ta->deduceType(sc, specType, parameters, dedtypes);
        if (m2 <= MATCHnomatch)
        {   //printf("\tfailed deduceType\n");
            goto Lnomatch;
        }

        if (m2 < m)
            m = m2;
        if ((*dedtypes)[i])
            ta = (Type *)(*dedtypes)[i];
    }
    else
    {
        if ((*dedtypes)[i])
        {   // Must match already deduced type
            Type *t = (Type *)(*dedtypes)[i];

            if (!t->equals(ta))
            {   //printf("t = %s ta = %s\n", t->toChars(), ta->toChars());
                goto Lnomatch;
            }
        }
        else
        {
            // So that matches with specializations are better
            m = MATCHconvert;
        }
    }
    (*dedtypes)[i] = ta;

    if (psparam)
        *psparam = new AliasDeclaration(loc, ident, ta);
    //printf("\tm = %d\n", m);
    return m;

Lnomatch:
    if (psparam)
        *psparam = NULL;
    //printf("\tm = %d\n", MATCHnomatch);
    return MATCHnomatch;
}


void TemplateTypeParameter::print(RootObject *oarg, RootObject *oded)
{
    printf(" %s\n", ident->toChars());

    Type *t  = isType(oarg);
    Type *ta = isType(oded);

    assert(ta);

    if (specType)
        printf("\tSpecialization: %s\n", specType->toChars());
    if (defaultType)
        printf("\tDefault:        %s\n", defaultType->toChars());
    printf("\tParameter:       %s\n", t ? t->toChars() : "NULL");
    printf("\tDeduced Type:   %s\n", ta->toChars());
}


void TemplateTypeParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    if (specType)
    {
        buf->writestring(" : ");
        specType->toCBuffer(buf, NULL, hgs);
    }
    if (defaultType)
    {
        buf->writestring(" = ");
        defaultType->toCBuffer(buf, NULL, hgs);
    }
}


void *TemplateTypeParameter::dummyArg()
{
    Type *t;
    if (specType)
        t = specType;
    else
    {
        // Use this for alias-parameter's too (?)
        if (!tdummy)
            tdummy = new TypeIdentifier(loc, ident);
        t = tdummy;
    }
    return (void *)t;
}


RootObject *TemplateTypeParameter::specialization()
{
    return specType;
}


RootObject *TemplateTypeParameter::defaultArg(Loc loc, Scope *sc)
{
    Type *t;

    t = defaultType;
    if (t)
    {
        t = t->syntaxCopy();
        t = t->semantic(loc, sc);
    }
    return t;
}

/* ======================== TemplateThisParameter =========================== */

// this-parameter

TemplateThisParameter::TemplateThisParameter(Loc loc, Identifier *ident,
        Type *specType,
        Type *defaultType)
    : TemplateTypeParameter(loc, ident, specType, defaultType)
{
}

TemplateThisParameter  *TemplateThisParameter::isTemplateThisParameter()
{
    return this;
}

TemplateParameter *TemplateThisParameter::syntaxCopy()
{
    TemplateThisParameter *tp = new TemplateThisParameter(loc, ident, specType, defaultType);
    if (tp->specType)
        tp->specType = specType->syntaxCopy();
    if (defaultType)
        tp->defaultType = defaultType->syntaxCopy();
    return tp;
}

void TemplateThisParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("this ");
    TemplateTypeParameter::toCBuffer(buf, hgs);
}

/* ======================== TemplateAliasParameter ========================== */

// alias-parameter

Dsymbol *TemplateAliasParameter::sdummy = NULL;

TemplateAliasParameter::TemplateAliasParameter(Loc loc, Identifier *ident,
        Type *specType, RootObject *specAlias, RootObject *defaultAlias)
    : TemplateParameter(loc, ident)
{
    this->ident = ident;
    this->specType = specType;
    this->specAlias = specAlias;
    this->defaultAlias = defaultAlias;
}

TemplateAliasParameter *TemplateAliasParameter::isTemplateAliasParameter()
{
    return this;
}

TemplateParameter *TemplateAliasParameter::syntaxCopy()
{
    TemplateAliasParameter *tp = new TemplateAliasParameter(loc, ident, specType, specAlias, defaultAlias);
    if (tp->specType)
        tp->specType = specType->syntaxCopy();
    tp->specAlias = objectSyntaxCopy(specAlias);
    tp->defaultAlias = objectSyntaxCopy(defaultAlias);
    return tp;
}

void TemplateAliasParameter::declareParameter(Scope *sc)
{
    TypeIdentifier *ti = new TypeIdentifier(loc, ident);
    sparam = new AliasDeclaration(loc, ident, ti);
    if (!sc->insert(sparam))
        error(loc, "parameter '%s' multiply defined", ident->toChars());
}

RootObject *aliasParameterSemantic(Loc loc, Scope *sc, RootObject *o, TemplateParameters *parameters)
{
    if (o)
    {
        Expression *ea = isExpression(o);
        Type *ta = isType(o);
        if (ta && (!parameters || !ta->reliesOnTident(parameters)))
        {   Dsymbol *s = ta->toDsymbol(sc);
            if (s)
                o = s;
            else
                o = ta->semantic(loc, sc);
        }
        else if (ea)
        {
            sc = sc->startCTFE();
            ea = ea->semantic(sc);
            sc = sc->endCTFE();
            o = ea->ctfeInterpret();
        }
    }
    return o;
}

void TemplateAliasParameter::semantic(Scope *sc, TemplateParameters *parameters)
{
    if (specType && !specType->reliesOnTident(parameters))
    {
        specType = specType->semantic(loc, sc);
    }
    specAlias = aliasParameterSemantic(loc, sc, specAlias, parameters);
#if 0 // Don't do semantic() until instantiation
    if (defaultAlias)
        defaultAlias = defaultAlias->semantic(loc, sc);
#endif
}

int TemplateAliasParameter::overloadMatch(TemplateParameter *tp)
{
    TemplateAliasParameter *tap = tp->isTemplateAliasParameter();

    if (tap)
    {
        if (specAlias != tap->specAlias)
            goto Lnomatch;

        return 1;                       // match
    }

Lnomatch:
    return 0;
}

/* Bugzilla 6538: In template constraint, each function parameters, 'this',
 * and 'super' is *pseudo* symbol. If it is passed to other template through
 * alias/tuple parameter, it will cause an error. Because such symbol
 * does not have the actual entity yet.
 *
 * Example:
 *  template Sym(alias A) { enum Sym = true; }
 *  struct S {
 *    void foo() if (Sym!(this)) {} // Sym!(this) always make an error,
 *  }                               // because Sym template cannot
 *  void main() { S s; s.foo(); }   // access to the valid 'this' symbol.
 */
bool isPseudoDsymbol(RootObject *o)
{
    Dsymbol *s = isDsymbol(o);
    Expression *e = isExpression(o);
    if (e && e->op == TOKvar) s = ((VarExp *)e)->var->isVarDeclaration();
    if (e && e->op == TOKthis) s = ((ThisExp *)e)->var->isThisDeclaration();
    if (e && e->op == TOKsuper) s = ((SuperExp *)e)->var->isThisDeclaration();

    if (s && s->parent)
    {
        s = s->toAlias();
        VarDeclaration *v = s->isVarDeclaration();
        TupleDeclaration *t = s->isTupleDeclaration();
        if (v || t)
        {
            FuncDeclaration *fd = s->parent->isFuncDeclaration();
            if (fd && fd->parent && fd->parent->isTemplateDeclaration())
            {
                const char *str = (e && e->op == TOKsuper) ? "super" : s->toChars();
                ::error(s->loc, "cannot take a not yet instantiated symbol '%s' inside template constraint", str);
                return true;
            }
        }
    }
    return false;
}

MATCH TemplateAliasParameter::matchArg(Scope *sc, RootObject *oarg,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    //printf("TemplateAliasParameter::matchArg()\n");
    RootObject *sa = getDsymbol(oarg);
    Expression *ea = isExpression(oarg);
    if (ea && (ea->op == TOKthis || ea->op == TOKsuper))
        sa = ((ThisExp *)ea)->var;
    else if (ea && ea->op == TOKimport)
        sa = ((ScopeExp *)ea)->sds;
    if (sa)
    {
        /* specType means the alias must be a declaration with a type
         * that matches specType.
         */
        if (specType)
        {   Declaration *d = ((Dsymbol *)sa)->isDeclaration();
            if (!d)
                goto Lnomatch;
            if (!d->type->equals(specType))
                goto Lnomatch;
        }
    }
    else
    {
        sa = oarg;
        if (ea)
        {   if (specType)
            {
                if (!ea->type->equals(specType))
                    goto Lnomatch;
            }
        }
        else
            goto Lnomatch;
    }

    if (specAlias)
    {
        if (sa == sdummy)
            goto Lnomatch;
        if (sa != specAlias && isDsymbol(sa))
        {
            TemplateInstance *ti = isDsymbol(sa)->isTemplateInstance();
            Type *ta = isType(specAlias);
            if (!ti || !ta)
                goto Lnomatch;
            Type *t = new TypeInstance(Loc(), ti);
            MATCH m = t->deduceType(sc, ta, parameters, dedtypes);
            if (m <= MATCHnomatch)
                goto Lnomatch;
        }
    }
    else if ((*dedtypes)[i])
    {   // Must match already deduced symbol
        RootObject *si = (*dedtypes)[i];

        if (!sa || si != sa)
            goto Lnomatch;
    }
    (*dedtypes)[i] = sa;

    if (psparam)
    {
        if (Dsymbol *s = isDsymbol(sa))
        {
            *psparam = new AliasDeclaration(loc, ident, s);
        }
        else
        {
            assert(ea);

            // Declare manifest constant
            Initializer *init = new ExpInitializer(loc, ea);
            VarDeclaration *v = new VarDeclaration(loc, NULL, ident, init);
            v->storage_class = STCmanifest;
            v->semantic(sc);
            *psparam = v;
        }
    }
    return MATCHexact;

Lnomatch:
    if (psparam)
        *psparam = NULL;
    //printf("\tm = %d\n", MATCHnomatch);
    return MATCHnomatch;
}


void TemplateAliasParameter::print(RootObject *oarg, RootObject *oded)
{
    printf(" %s\n", ident->toChars());

    Dsymbol *sa = isDsymbol(oded);
    assert(sa);

    printf("\tParameter alias: %s\n", sa->toChars());
}

void TemplateAliasParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("alias ");
    if (specType)
    {   HdrGenState hgs1;
        specType->toCBuffer(buf, ident, &hgs1);
    }
    else
        buf->writestring(ident->toChars());
    if (specAlias)
    {
        buf->writestring(" : ");
        ObjectToCBuffer(buf, hgs, specAlias);
    }
    if (defaultAlias)
    {
        buf->writestring(" = ");
        ObjectToCBuffer(buf, hgs, defaultAlias);
    }
}


void *TemplateAliasParameter::dummyArg()
{   RootObject *s;

    s = specAlias;
    if (!s)
    {
        if (!sdummy)
            sdummy = new Dsymbol();
        s = sdummy;
    }
    return (void*)s;
}


RootObject *TemplateAliasParameter::specialization()
{
    return specAlias;
}


RootObject *TemplateAliasParameter::defaultArg(Loc loc, Scope *sc)
{
    RootObject *da = defaultAlias;
    Type *ta = isType(defaultAlias);
    if (ta)
    {
       if (ta->ty == Tinstance)
       {
           // If the default arg is a template, instantiate for each type
           da = ta->syntaxCopy();
       }
    }

    RootObject *o = aliasParameterSemantic(loc, sc, da, NULL);
    return o;
}

/* ======================== TemplateValueParameter ========================== */

// value-parameter

AA *TemplateValueParameter::edummies = NULL;

TemplateValueParameter::TemplateValueParameter(Loc loc, Identifier *ident, Type *valType,
        Expression *specValue, Expression *defaultValue)
    : TemplateParameter(loc, ident)
{
    this->ident = ident;
    this->valType = valType;
    this->specValue = specValue;
    this->defaultValue = defaultValue;
}

TemplateValueParameter *TemplateValueParameter::isTemplateValueParameter()
{
    return this;
}

TemplateParameter *TemplateValueParameter::syntaxCopy()
{
    TemplateValueParameter *tp =
        new TemplateValueParameter(loc, ident, valType, specValue, defaultValue);
    tp->valType = valType->syntaxCopy();
    if (specValue)
        tp->specValue = specValue->syntaxCopy();
    if (defaultValue)
        tp->defaultValue = defaultValue->syntaxCopy();
    return tp;
}

void TemplateValueParameter::declareParameter(Scope *sc)
{
    VarDeclaration *v = new VarDeclaration(loc, valType, ident, NULL);
    v->storage_class = STCtemplateparameter;
    if (!sc->insert(v))
        error(loc, "parameter '%s' multiply defined", ident->toChars());
    sparam = v;
}

void TemplateValueParameter::semantic(Scope *sc, TemplateParameters *parameters)
{
    bool wasSame = (sparam->type == valType);
    sparam->semantic(sc);
    if (sparam->type == Type::terror && wasSame)
    {   /* If sparam has a type error, avoid duplicate errors
         * The simple solution of leaving that function if sparam->type == Type::terror
         * doesn't quite work because it causes failures in xtest46 for bug 6295
         */
        valType = Type::terror;
        return;
    }
    valType = valType->semantic(loc, sc);
    if (!(valType->isintegral() || valType->isfloating() || valType->isString()) &&
        valType->ty != Tident)
    {
        if (valType != Type::terror)
            error(loc, "arithmetic/string type expected for value-parameter, not %s", valType->toChars());
    }

#if 0   // defer semantic analysis to arg match
    if (specValue)
    {
        Expression *e = specValue;
        sc = sc->startCTFE();
        e = e->semantic(sc);
        sc = sc->endCTFE();
        e = e->implicitCastTo(sc, valType);
        e = e->ctfeInterpret();
        if (e->op == TOKint64 || e->op == TOKfloat64 ||
            e->op == TOKcomplex80 || e->op == TOKnull || e->op == TOKstring)
            specValue = e;
        //e->toInteger();
    }

    if (defaultValue)
    {
        Expression *e = defaultValue;
        sc = sc->startCTFE();
        e = e->semantic(sc);
        sc = sc->endCTFE();
        e = e->implicitCastTo(sc, valType);
        e = e->ctfeInterpret();
        if (e->op == TOKint64)
            defaultValue = e;
        //e->toInteger();
    }
#endif
}

int TemplateValueParameter::overloadMatch(TemplateParameter *tp)
{
    TemplateValueParameter *tvp = tp->isTemplateValueParameter();

    if (tvp)
    {
        if (valType != tvp->valType)
            goto Lnomatch;

        if (valType && !valType->equals(tvp->valType))
            goto Lnomatch;

        if (specValue != tvp->specValue)
            goto Lnomatch;

        return 1;                       // match
    }

Lnomatch:
    return 0;
}

MATCH TemplateValueParameter::matchArg(Scope *sc, RootObject *oarg,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    //printf("TemplateValueParameter::matchArg()\n");

    MATCH m = MATCHexact;

    Expression *ei = isExpression(oarg);
    Type *vt;

    if (!ei && oarg)
    {
        Dsymbol *si = isDsymbol(oarg);
        FuncDeclaration *f;
        if (si && (f = si->isFuncDeclaration()) != NULL)
        {
            ei = new VarExp(loc, f);
            ei = ei->semantic(sc);
            if (!f->needThis())
                ei = resolveProperties(sc, ei);
            /* If it was really a property, it will become a CallExp.
             * If it stayed as a var, it cannot be interpreted.
             */
            if (ei->op == TOKvar)
                goto Lnomatch;
            ei = ei->ctfeInterpret();
        }
        else
            goto Lnomatch;
    }

    if (ei && ei->op == TOKvar)
    {   // Resolve const variables that we had skipped earlier
        ei = ei->ctfeInterpret();
    }

    //printf("\tvalType: %s, ty = %d\n", valType->toChars(), valType->ty);
    vt = valType->semantic(loc, sc);
    //printf("ei: %s, ei->type: %s\n", ei->toChars(), ei->type->toChars());
    //printf("vt = %s\n", vt->toChars());

    if (ei->type)
    {
        m = (MATCH)ei->implicitConvTo(vt);
        //printf("m: %d\n", m);
        if (m <= MATCHnomatch)
            goto Lnomatch;
        if (m != MATCHexact)
        {
            ei = ei->implicitCastTo(sc, vt);
            ei = ei->ctfeInterpret();
        }
    }

    if (specValue)
    {
        if (!ei || _aaGetRvalue(edummies, ei->type) == ei)
            goto Lnomatch;

        Expression *e = specValue;

        sc = sc->startCTFE();
        e = e->semantic(sc);
        e = resolveProperties(sc, e);
        sc = sc->endCTFE();
        e = e->implicitCastTo(sc, vt);
        e = e->ctfeInterpret();

        ei = ei->syntaxCopy();
        sc = sc->startCTFE();
        ei = ei->semantic(sc);
        sc = sc->endCTFE();
        ei = ei->implicitCastTo(sc, vt);
        ei = ei->ctfeInterpret();
        //printf("\tei: %s, %s\n", ei->toChars(), ei->type->toChars());
        //printf("\te : %s, %s\n", e->toChars(), e->type->toChars());
        if (!ei->equals(e))
            goto Lnomatch;
    }
    else
    {
        if ((*dedtypes)[i])
        {   // Must match already deduced value
            Expression *e = (Expression *)(*dedtypes)[i];

            if (!ei || !ei->equals(e))
                goto Lnomatch;
        }
    }
    (*dedtypes)[i] = ei;

    if (psparam)
    {
        Initializer *init = new ExpInitializer(loc, ei);
        Declaration *sparam = new VarDeclaration(loc, vt, ident, init);
        sparam->storage_class = STCmanifest;
        *psparam = sparam;
    }
    return m;

Lnomatch:
    //printf("\tno match\n");
    if (psparam)
        *psparam = NULL;
    return MATCHnomatch;
}


void TemplateValueParameter::print(RootObject *oarg, RootObject *oded)
{
    printf(" %s\n", ident->toChars());

    Expression *ea = isExpression(oded);

    if (specValue)
        printf("\tSpecialization: %s\n", specValue->toChars());
    printf("\tParameter Value: %s\n", ea ? ea->toChars() : "NULL");
}


void TemplateValueParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    valType->toCBuffer(buf, ident, hgs);
    if (specValue)
    {
        buf->writestring(" : ");
        specValue->toCBuffer(buf, hgs);
    }
    if (defaultValue)
    {
        buf->writestring(" = ");
        defaultValue->toCBuffer(buf, hgs);
    }
}


void *TemplateValueParameter::dummyArg()
{   Expression *e;

    e = specValue;
    if (!e)
    {
        // Create a dummy value
        Expression **pe = (Expression **)_aaGet(&edummies, valType);
        if (!*pe)
            *pe = valType->defaultInit();
        e = *pe;
    }
    return (void *)e;
}


RootObject *TemplateValueParameter::specialization()
{
    return specValue;
}


RootObject *TemplateValueParameter::defaultArg(Loc loc, Scope *sc)
{
    Expression *e = defaultValue;
    if (e)
    {
        e = e->syntaxCopy();
        e = e->semantic(sc);
        e = resolveProperties(sc, e);
        e = e->resolveLoc(loc, sc);
        e = e->optimize(WANTvalue);
    }
    return e;
}

/* ======================== TemplateTupleParameter ========================== */

// variadic-parameter

TemplateTupleParameter::TemplateTupleParameter(Loc loc, Identifier *ident)
    : TemplateParameter(loc, ident)
{
    this->ident = ident;
}

TemplateTupleParameter *TemplateTupleParameter::isTemplateTupleParameter()
{
    return this;
}

TemplateParameter *TemplateTupleParameter::syntaxCopy()
{
    TemplateTupleParameter *tp = new TemplateTupleParameter(loc, ident);
    return tp;
}

void TemplateTupleParameter::declareParameter(Scope *sc)
{
    TypeIdentifier *ti = new TypeIdentifier(loc, ident);
    sparam = new AliasDeclaration(loc, ident, ti);
    if (!sc->insert(sparam))
        error(loc, "parameter '%s' multiply defined", ident->toChars());
}

void TemplateTupleParameter::semantic(Scope *sc, TemplateParameters *parameters)
{
}

int TemplateTupleParameter::overloadMatch(TemplateParameter *tp)
{
    TemplateTupleParameter *tvp = tp->isTemplateTupleParameter();

    if (tvp)
    {
        return 1;                       // match
    }

    return 0;
}

MATCH TemplateTupleParameter::matchArg(Loc loc, Scope *sc, Objects *tiargs,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    /* The rest of the actual arguments (tiargs[]) form the match
     * for the variadic parameter.
     */
    assert(i + 1 == dedtypes->dim);     // must be the last one
    Tuple *ovar;

    if ((*dedtypes)[i] && isTuple((*dedtypes)[i]))
        // It was already been deduced
        ovar = isTuple((*dedtypes)[i]);
    else if (i + 1 == tiargs->dim && isTuple((*tiargs)[i]))
        ovar = isTuple((*tiargs)[i]);
    else
    {
        ovar = new Tuple();
        //printf("ovar = %p\n", ovar);
        if (i < tiargs->dim)
        {
            //printf("i = %d, tiargs->dim = %d\n", i, tiargs->dim);
            ovar->objects.setDim(tiargs->dim - i);
            for (size_t j = 0; j < ovar->objects.dim; j++)
                ovar->objects[j] = (*tiargs)[i + j];
        }
    }
    return matchArg(sc, ovar, i, parameters, dedtypes, psparam);
}

MATCH TemplateTupleParameter::matchArg(Scope *sc, RootObject *oarg,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    //printf("TemplateTupleParameter::matchArg()\n");
    Tuple *ovar = isTuple(oarg);
    if (!ovar)
        return MATCHnomatch;
    (*dedtypes)[i] = ovar;

    if (psparam)
        *psparam = new TupleDeclaration(loc, ident, &ovar->objects);
    return MATCHexact;
}


void TemplateTupleParameter::print(RootObject *oarg, RootObject *oded)
{
    printf(" %s... [", ident->toChars());
    Tuple *v = isTuple(oded);
    assert(v);

    //printf("|%d| ", v->objects.dim);
    for (size_t i = 0; i < v->objects.dim; i++)
    {
        if (i)
            printf(", ");

        RootObject *o = v->objects[i];

        Dsymbol *sa = isDsymbol(o);
        if (sa)
            printf("alias: %s", sa->toChars());

        Type *ta = isType(o);
        if (ta)
            printf("type: %s", ta->toChars());

        Expression *ea = isExpression(o);
        if (ea)
            printf("exp: %s", ea->toChars());

        assert(!isTuple(o));            // no nested Tuple arguments
    }

    printf("]\n");
}

void TemplateTupleParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    buf->writestring("...");
}


void *TemplateTupleParameter::dummyArg()
{
    return NULL;
}


RootObject *TemplateTupleParameter::specialization()
{
    return NULL;
}


RootObject *TemplateTupleParameter::defaultArg(Loc loc, Scope *sc)
{
    return NULL;
}

/* ======================== TemplateInstance ================================ */

TemplateInstance::TemplateInstance(Loc loc, Identifier *ident)
    : ScopeDsymbol(NULL)
{
#if LOG
    printf("TemplateInstance(this = %p, ident = '%s')\n", this, ident ? ident->toChars() : "null");
#endif
    this->loc = loc;
    this->name = ident;
    this->tiargs = NULL;
    this->tempdecl = NULL;
    this->instantiatingModule = NULL;
    this->inst = NULL;
    this->tinst = NULL;
    this->deferred = NULL;
    this->argsym = NULL;
    this->aliasdecl = NULL;
    this->semantictiargsdone = false;
    this->withsym = NULL;
    this->nest = 0;
    this->havetempdecl = false;
    this->enclosing = NULL;
    this->speculative = false;
    this->hash = 0;
    this->fargs = NULL;
}

/*****************
 * This constructor is only called when we figured out which function
 * template to instantiate.
 */

TemplateInstance::TemplateInstance(Loc loc, TemplateDeclaration *td, Objects *tiargs)
    : ScopeDsymbol(NULL)
{
#if LOG
    printf("TemplateInstance(this = %p, tempdecl = '%s')\n", this, td->toChars());
#endif
    this->loc = loc;
    this->name = td->ident;
    this->tiargs = tiargs;
    this->tempdecl = td;
    this->instantiatingModule = NULL;
    this->inst = NULL;
    this->tinst = NULL;
    this->deferred = NULL;
    this->argsym = NULL;
    this->aliasdecl = NULL;
    this->semantictiargsdone = true;
    this->withsym = NULL;
    this->nest = 0;
    this->havetempdecl = true;
    this->enclosing = NULL;
    this->speculative = false;
    this->hash = 0;
    this->fargs = NULL;

    assert(tempdecl->scope);
}


Objects *TemplateInstance::arraySyntaxCopy(Objects *objs)
{
    Objects *a = NULL;
    if (objs)
    {   a = new Objects();
        a->setDim(objs->dim);
        for (size_t i = 0; i < objs->dim; i++)
        {
            (*a)[i] = objectSyntaxCopy((*objs)[i]);
        }
    }
    return a;
}

Dsymbol *TemplateInstance::syntaxCopy(Dsymbol *s)
{
    TemplateInstance *ti;

    if (s)
        ti = (TemplateInstance *)s;
    else
        ti = new TemplateInstance(loc, name);

    ti->tiargs = arraySyntaxCopy(tiargs);

    TemplateDeclaration *td;
    if (inst && tempdecl && (td = tempdecl->isTemplateDeclaration()) != NULL)
        td->ScopeDsymbol::syntaxCopy(ti);
    else
        ScopeDsymbol::syntaxCopy(ti);
    return ti;
}


void TemplateInstance::semantic(Scope *sc)
{
    semantic(sc, NULL);
}

void TemplateInstance::expandMembers(Scope *sc2)
{
    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
        s->setScope(sc2);
    }

    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
        //printf("\t[%d] semantic on '%s' %p kind %s in '%s'\n", i, s->toChars(), s, s->kind(), this->toChars());
        //printf("test: enclosing = %d, sc2->parent = %s\n", enclosing, sc2->parent->toChars());
//      if (enclosing)
//          s->parent = sc->parent;
        //printf("test3: enclosing = %d, s->parent = %s\n", enclosing, s->parent->toChars());
        s->semantic(sc2);
        //printf("test4: enclosing = %d, s->parent = %s\n", enclosing, s->parent->toChars());
        sc2->module->runDeferredSemantic();
    }
}

void TemplateInstance::tryExpandMembers(Scope *sc2)
{
    static int nest;
    // extracted to a function to allow windows SEH to work without destructors in the same function
    //printf("%d\n", nest);
    if (++nest > 500)
    {
        global.gag = 0;                 // ensure error message gets printed
        error("recursive expansion");
        fatal();
    }

    expandMembers(sc2);
    nest--;
}

void TemplateInstance::trySemantic3(Scope *sc2)
{
    // extracted to a function to allow windows SEH to work without destructors in the same function
    static int nest;
    if (++nest > 300)
    {
        global.gag = 0;            // ensure error message gets printed
        error("recursive expansion");
        fatal();
    }
    semantic3(sc2);

    --nest;
}

void TemplateInstance::semantic(Scope *sc, Expressions *fargs)
{
    //printf("TemplateInstance::semantic('%s', this=%p, gag = %d, sc = %p)\n", toChars(), this, global.gag, sc);
#if 0
    for (Dsymbol *s = this; s; s = s->parent)
    {
        printf("\t%s\n", s->toChars());
    }
    printf("Scope\n");
    for (Scope *scx = sc; scx; scx = scx->enclosing)
    {
        printf("\t%s parent %s instantiatingModule %p\n", scx->module ? scx->module->toChars() : "null", scx->parent ? scx->parent->toChars() : "null", scx->instantiatingModule);
    }
#endif

    Module *mi = sc->instantiatingModule ? sc->instantiatingModule : sc->module;

    /* If a TemplateInstance is ever instantiated by non-root modules,
     * we do not have to generate code for it,
     * because it will be generated when the non-root module is compiled.
     */
    if (!instantiatingModule || instantiatingModule->isRoot())
        instantiatingModule = mi;
    //printf("mi = %s\n", mi->toChars());

#if LOG
    printf("\n+TemplateInstance::semantic('%s', this=%p)\n", toChars(), this);
#endif
    if (inst)           // if semantic() was already run
    {
#if LOG
        printf("-TemplateInstance::semantic('%s', this=%p) already run\n", inst->toChars(), inst);
#endif
        return;
    }

    // get the enclosing template instance from the scope tinst
    tinst = sc->tinst;

    if (semanticRun != PASSinit)
    {
#if LOG
        printf("Recursive template expansion\n");
#endif
        error(loc, "recursive template expansion");
//      inst = this;
        return;
    }
    semanticRun = PASSsemantic;

#if LOG
    printf("\tdo semantic\n");
#endif
    /* Find template declaration first,
     * then run semantic on each argument (place results in tiargs[]),
     * last find most specialized template from overload list/set.
     */
    if (!findTemplateDeclaration(sc) ||
        !semanticTiargs(sc) ||
        !findBestMatch(sc, fargs))
    {
        inst = this;
        inst->errors = true;
        return;             // error recovery
    }
    TemplateDeclaration *tempdecl = this->tempdecl->isTemplateDeclaration();
    assert(tempdecl);

    // If tempdecl is a mixin, disallow it
    if (tempdecl->ismixin)
        error("mixin templates are not regular templates");

    hasNestedArgs(tiargs, tempdecl->isstatic);

    /* See if there is an existing TemplateInstantiation that already
     * implements the typeargs. If so, just refer to that one instead.
     */
    {
        TemplateInstance *ti = tempdecl->findExistingInstance(this, fargs);
        if (ti)
        {
            // It's a match
            inst = ti;
            parent = ti->parent;

            // If both this and the previous instantiation were speculative,
            // use the number of errors that happened last time.
            if (inst->speculative && global.gag)
            {
                global.errors += inst->errors;
                global.gaggedErrors += inst->errors;
            }

            // If the first instantiation was speculative, but this is not:
            if (inst->speculative && !global.gag)
            {
                // If the first instantiation had failed, re-run semantic,
                // so that error messages are shown.
                if (inst->errors)
                    goto L1;
                // It had succeeded, mark it is a non-speculative instantiation,
                // and reuse it.
                inst->speculative = 0;
            }

#if LOG
            printf("\tit's a match with instance %p, %d\n", inst, inst->semanticRun);
#endif
            if (!inst->instantiatingModule || inst->instantiatingModule->isRoot())
                inst->instantiatingModule = mi;
            return;
        }
    L1: ;
    }

    /* So, we need to implement 'this' instance.
     */
#if LOG
    printf("\timplement template instance %s '%s'\n", tempdecl->parent->toChars(), toChars());
    printf("\ttempdecl %s\n", tempdecl->toChars());
#endif
    unsigned errorsave = global.errors;
    inst = this;
    // Mark as speculative if we are instantiated from inside is(typeof())
    if (global.gag && sc->speculative)
        speculative = 1;

    TemplateInstance *tempdecl_instance_idx = tempdecl->addInstance(this);

    parent = enclosing ? enclosing : tempdecl->parent;
    //printf("parent = '%s'\n", parent->kind());

    //getIdent();

    // Add 'this' to the enclosing scope's members[] so the semantic routines
    // will get called on the instance members. Store the place we added it to
    // in target_symbol_list(_idx) so we can remove it later if we encounter
    // an error.
#if 1
    Dsymbols *target_symbol_list = NULL;
    size_t target_symbol_list_idx;

    {   Dsymbols *a;

        Scope *scx = sc;
#if 0
        for (scx = sc; scx; scx = scx->enclosing)
            if (scx->scopesym)
                break;
#endif

        //if (scx && scx->scopesym) printf("3: scx is %s %s\n", scx->scopesym->kind(), scx->scopesym->toChars());
        /* The problem is if A imports B, and B imports A, and both A
         * and B instantiate the same template, does the compilation of A
         * or the compilation of B do the actual instantiation?
         *
         * see bugzilla 2500.
         *
         * && !scx->module->selfImports()
         */
        if (scx && scx->scopesym && scx->scopesym->members &&
            !scx->scopesym->isTemplateMixin())
        {
            /* A module can have explicit template instance and its alias
             * in module scope (e,g, `alias Base64Impl!('+', '/') Base64;`).
             * When the module is just imported, compiler can assume that
             * its instantiated code would be contained in the separately compiled
             * obj/lib file (e.g. phobos.lib). So we can omit their semantic3 running.
             */
            //if (scx->scopesym->isModule())
            //    printf("module level instance %s\n", toChars());

            //printf("\t1: adding to %s %s\n", scx->scopesym->kind(), scx->scopesym->toChars());
            a = scx->scopesym->members;
        }
        else
        {
            Dsymbol *s = enclosing ? enclosing : tempdecl->parent;
            for (; s; s = s->toParent2())
            {
                if (s->isModule())
                    break;
            }
            assert(s);
            Module *m = (Module *)s;
            if (!m->isRoot())
            {
                m = m->importedFrom;
            }
            //printf("\t2: adding to module %s instead of module %s\n", m->toChars(), sc->module->toChars());
            a = m->members;

            /* Defer semantic3 running in order to avoid mutual forward reference.
             * See test/runnable/test10736.d
             */
            if (m->semanticRun >= PASSsemantic3done)
                Module::addDeferredSemantic3(this);
        }
        for (size_t i = 0; 1; i++)
        {
            if (i == a->dim)
            {
                target_symbol_list = a;
                target_symbol_list_idx = i;
                a->push(this);
                break;
            }
            if (this == (*a)[i])  // if already in Array
                break;
        }
    }
#endif

    // Copy the syntax trees from the TemplateDeclaration
    if (members && speculative && !errors)
    {}  // Don't copy again so they were previously created.
    else
        members = Dsymbol::arraySyntaxCopy(tempdecl->members);

    // todo for TemplateThisParameter
    for (size_t i = 0; i < tempdecl->parameters->dim; i++)
    {
        if ((*tempdecl->parameters)[i]->isTemplateThisParameter() == NULL)
            continue;
        Type *t = isType((*tiargs)[i]);
        assert(t);

        StorageClass stc = 0;
        if (t->mod & MODimmutable)
            stc |= STCimmutable;
        else
        {
            if (t->mod & MODconst)
                stc |= STCconst;
            else if (t->mod & MODwild)
                stc |= STCwild;

            if (t->mod & MODshared)
                stc |= STCshared;
        }
        if (stc != 0)
        {
            //printf("t = %s, stc = x%llx\n", t->toChars(), stc);
            Dsymbols *s = new Dsymbols();
            s->push(new StorageClassDeclaration(stc, members));
            members = s;
        }
        break;
    }

    // Create our own scope for the template parameters
    Scope *scope = tempdecl->scope;
    if (tempdecl->semanticRun == PASSinit)
    {
        error("template instantiation %s forward references template declaration %s", toChars(), tempdecl->toChars());
        return;
    }

#if LOG
    printf("\tcreate scope for template parameters '%s'\n", toChars());
#endif
    argsym = new ScopeDsymbol();
    argsym->parent = scope->parent;
    scope = scope->push(argsym);
    scope->instantiatingModule = mi;
//    scope->stc = 0;

    // Declare each template parameter as an alias for the argument type
    Scope *paramscope = scope->push();
    paramscope->stc = 0;
    declareParameters(paramscope);
    paramscope->pop();

    // Add members of template instance to template instance symbol table
//    parent = scope->scopesym;
    symtab = new DsymbolTable();
    int memnum = 0;
    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
#if LOG
        printf("\t[%d] adding member '%s' %p kind %s to '%s', memnum = %d\n", i, s->toChars(), s, s->kind(), this->toChars(), memnum);
#endif
        memnum |= s->addMember(scope, this, memnum);
    }
#if LOG
    printf("adding members done\n");
#endif

    /* See if there is only one member of template instance, and that
     * member has the same name as the template instance.
     * If so, this template instance becomes an alias for that member.
     */
    //printf("members->dim = %d\n", members->dim);
    if (members->dim)
    {
        Dsymbol *s;
        if (Dsymbol::oneMembers(members, &s, tempdecl->ident) && s)
        {
            //printf("s->kind = '%s'\n", s->kind());
            //s->print();
            //printf("'%s', '%s'\n", s->ident->toChars(), tempdecl->ident->toChars());
            //printf("setting aliasdecl\n");
            aliasdecl = new AliasDeclaration(loc, s->ident, s);
        }
    }

    /* If function template declaration
     */
    if (fargs && aliasdecl)
    {
        FuncDeclaration *fd = aliasdecl->toAlias()->isFuncDeclaration();
        if (fd)
        {
            /* Transmit fargs to type so that TypeFunction::semantic() can
             * resolve any "auto ref" storage classes.
             */
            TypeFunction *tf = (TypeFunction *)fd->type;
            if (tf && tf->ty == Tfunction)
                tf->fargs = fargs;
        }
    }

    // Do semantic() analysis on template instance members
#if LOG
    printf("\tdo semantic() on template instance members '%s'\n", toChars());
#endif
    Scope *sc2;
    sc2 = scope->push(this);
    //printf("enclosing = %d, sc->parent = %s\n", enclosing, sc->parent->toChars());
    sc2->parent = /*enclosing ? sc->parent :*/ this;
    sc2->tinst = this;
    sc2->speculative = speculative;
    if (enclosing && tempdecl->isstatic)
        sc2->stc &= ~STCstatic;

    tryExpandMembers(sc2);

    semanticRun = PASSsemanticdone;

    /* If any of the instantiation members didn't get semantic() run
     * on them due to forward references, we cannot run semantic2()
     * or semantic3() yet.
     */
    bool found_deferred_ad = false;
    for (size_t i = 0; i < Module::deferred.dim; i++)
    {
        Dsymbol *sd = Module::deferred[i];
        AggregateDeclaration *ad = sd->isAggregateDeclaration();
        if (ad && ad->parent && ad->parent->isTemplateInstance())
        {
            //printf("deferred template aggregate: %s %s\n",
            //        sd->parent->toChars(), sd->toChars());
            found_deferred_ad = true;
            if (ad->parent == this)
            {
                ad->deferred = this;
                break;
            }
        }
    }
    if (found_deferred_ad || Module::deferred.dim)
        goto Laftersemantic;

    /* ConditionalDeclaration may introduce eponymous declaration,
     * so we should find it once again after semantic.
     */
    if (members->dim)
    {
        Dsymbol *s;
        if (Dsymbol::oneMembers(members, &s, tempdecl->ident) && s)
        {
            if (!aliasdecl || aliasdecl->toAlias() != s)
            {
                //printf("s->kind = '%s'\n", s->kind());
                //s->print();
                //printf("'%s', '%s'\n", s->ident->toChars(), tempdecl->ident->toChars());
                //printf("setting aliasdecl 2\n");
                aliasdecl = new AliasDeclaration(loc, s->ident, s);
            }
        }
        else if (aliasdecl)
            aliasdecl = NULL;
    }

    /* The problem is when to parse the initializer for a variable.
     * Perhaps VarDeclaration::semantic() should do it like it does
     * for initializers inside a function.
     */
//    if (sc->parent->isFuncDeclaration())
    {
        /* BUG 782: this has problems if the classes this depends on
         * are forward referenced. Find a way to defer semantic()
         * on this template.
         */
        semantic2(sc2);
    }

    if (sc->func && aliasdecl && aliasdecl->toAlias()->isFuncDeclaration())
    {
        /* Template function instantiation should run semantic3 immediately
         * for attribute inference.
         */
        //printf("function semantic3 %s inside %s\n", toChars(), sc->func->toChars());
        trySemantic3(sc2);
    }
    else if (sc->func && !tinst)
    {
        /* If a template is instantiated inside function, the whole instantiation
         * should be done at that position. But, immediate running semantic3 of
         * dependent templates may cause unresolved forward reference (Bugzilla 9050).
         * To avoid the issue, don't run semantic3 until semantic and semantic2 done.
         */
        TemplateInstances deferred;
        this->deferred = &deferred;

        //printf("Run semantic3 on %s\n", toChars());
        trySemantic3(sc2);

        for (size_t i = 0; i < deferred.dim; i++)
        {
            //printf("+ run deferred semantic3 on %s\n", deferred[i]->toChars());
            deferred[i]->semantic3(NULL);
        }

        this->deferred = NULL;
    }
    else if (tinst)
    {
        TemplateInstance *ti = tinst;
        int nest = 0;
        while (ti && !ti->deferred && ti->tinst)
        {
            ti = ti->tinst;
            if (++nest > 500)
            {
                global.gag = 0;            // ensure error message gets printed
                error("recursive expansion");
                fatal();
            }
        }
        if (ti && ti->deferred)
        {
            //printf("deferred semantic3 of %p %s, ti = %s, ti->deferred = %p\n", this, toChars(), ti->toChars());
            for (size_t i = 0; ; i++)
            {
                if (i == ti->deferred->dim)
                {
                    ti->deferred->push(this);
                    break;
                }
                if ((*ti->deferred)[i] == this)
                    break;
            }
        }
    }

  Laftersemantic:
    sc2->pop();

    scope->pop();

    // Give additional context info if error occurred during instantiation
    if (global.errors != errorsave)
    {
        if (!tempdecl->literal)
            error(loc, "error instantiating");
        if (tinst)
        {   tinst->printInstantiationTrace();
        }
        errors = true;
        if (global.gag)
        {
            // Errors are gagged, so remove the template instance from the
            // instance/symbol lists we added it to and reset our state to
            // finish clean and so we can try to instantiate it again later
            // (see bugzilla 4302 and 6602).
            tempdecl->removeInstance(tempdecl_instance_idx);
            if (target_symbol_list)
            {
                // Because we added 'this' in the last position above, we
                // should be able to remove it without messing other indices up.
                assert((*target_symbol_list)[target_symbol_list_idx] == this);
                target_symbol_list->remove(target_symbol_list_idx);
            }
            semanticRun = PASSinit;
            inst = NULL;
        }
    }

#if LOG
    printf("-TemplateInstance::semantic('%s', this=%p)\n", toChars(), this);
#endif
}


/**********************************************
 * Find template declaration corresponding to template instance.
 */

bool TemplateInstance::findTemplateDeclaration(Scope *sc)
{
    if (havetempdecl)
        return true;

    //printf("TemplateInstance::findTemplateDeclaration() %s\n", toChars());
    if (!tempdecl)
    {
        /* Given:
         *    foo!( ... )
         * figure out which TemplateDeclaration foo refers to.
         */
        Identifier *id = name;
        Dsymbol *scopesym;
        Dsymbol *s = sc->search(loc, id, &scopesym);
        if (!s)
        {
            s = sc->search_correct(id);
            if (s)
                error("template '%s' is not defined, did you mean %s?", id->toChars(), s->toChars());
            else
                error("template '%s' is not defined", id->toChars());
            return false;
        }

#if LOG
        printf("It's an instance of '%s' kind '%s'\n", s->toChars(), s->kind());
        if (s->parent)
            printf("s->parent = '%s'\n", s->parent->toChars());
#endif
        withsym = scopesym->isWithScopeSymbol();

        /* We might have found an alias within a template when
         * we really want the template.
         */
        TemplateInstance *ti;
        if (s->parent &&
            (ti = s->parent->isTemplateInstance()) != NULL)
        {
            if (ti->tempdecl && ti->tempdecl->ident == id)
            {
                /* This is so that one can refer to the enclosing
                 * template, even if it has the same name as a member
                 * of the template, if it has a !(arguments)
                 */
                TemplateDeclaration *td = ti->tempdecl->isTemplateDeclaration();
                assert(td);
                if (td->overroot)       // if not start of overloaded list of TemplateDeclaration's
                    td = td->overroot;  // then get the start
                s = td;
            }
        }

        if (!updateTemplateDeclaration(sc, s))
        {
            return false;
        }
    }
    assert(tempdecl);

  struct ParamFwdTi
  {
    static int fp(void *param, Dsymbol *s)
    {
        TemplateDeclaration *td = s->isTemplateDeclaration();
        if (!td)
            return 0;

        TemplateInstance *ti = (TemplateInstance *)param;
        if (td->semanticRun == PASSinit)
        {
            if (td->scope)
            {
                // Try to fix forward reference. Ungag errors while doing so.
                Ungag ungag = td->ungagSpeculative();
                td->semantic(td->scope);
            }
            if (td->semanticRun == PASSinit)
            {
                ti->error("%s forward references template declaration %s", ti->toChars(), td->toChars());
                return 1;
            }
        }
        return 0;
    }
  };
    // Look for forward references
    OverloadSet *tovers = tempdecl->isOverloadSet();
    size_t overs_dim = tovers ? tovers->a.dim : 1;
    for (size_t oi = 0; oi < overs_dim; oi++)
    {
        if (overloadApply(tovers ? tovers->a[oi] : tempdecl, (void *)this, &ParamFwdTi::fp))
            return false;
    }
    return true;
}

/**********************************************
 * Confirm s is a valid template, then store it.
 */

bool TemplateInstance::updateTemplateDeclaration(Scope *sc, Dsymbol *s)
{
    if (s)
    {
        Identifier *id = name;
        s = s->toAlias();

        /* If an OverloadSet, look for a unique member that is a template declaration
         */
        OverloadSet *os = s->isOverloadSet();
        if (os)
        {
            s = NULL;
            for (size_t i = 0; i < os->a.dim; i++)
            {
                Dsymbol *s2 = os->a[i];
                if (FuncDeclaration *f = s2->isFuncDeclaration())
                    s2 = f->findTemplateDeclRoot();
                else
                    s2 = s2->isTemplateDeclaration();
                if (s2)
                {
                    if (s)
                    {
                        tempdecl = os;
                        return true;
                    }
                    s = s2;
                }
            }
            if (!s)
            {
                error("template '%s' is not defined", id->toChars());
                return false;
            }
        }

        /* It should be a TemplateDeclaration, not some other symbol
         */
        if (FuncDeclaration *f = s->isFuncDeclaration())
            tempdecl = f->findTemplateDeclRoot();
        else
            tempdecl = s->isTemplateDeclaration();
        if (!tempdecl)
        {
            if (!s->parent && global.errors)
                return false;
            if (!s->parent && s->getType())
            {
                Dsymbol *s2 = s->getType()->toDsymbol(sc);
                if (!s2)
                {
                    error("%s is not a template declaration, it is a %s", id->toChars(), s->kind());
                    return false;
                }
                s = s2;
            }
#ifdef DEBUG
            //if (!s->parent) printf("s = %s %s\n", s->kind(), s->toChars());
#endif
            //assert(s->parent);
            TemplateInstance *ti = s->parent ? s->parent->isTemplateInstance() : NULL;
            if (ti &&
                (ti->name == s->ident ||
                 ti->toAlias()->ident == s->ident)
                &&
                ti->tempdecl)
            {
                /* This is so that one can refer to the enclosing
                 * template, even if it has the same name as a member
                 * of the template, if it has a !(arguments)
                 */
                TemplateDeclaration *td = ti->tempdecl->isTemplateDeclaration();
                assert(td);
                if (td->overroot)       // if not start of overloaded list of TemplateDeclaration's
                    td = td->overroot;  // then get the start
                tempdecl = td;
            }
            else
            {
                error("%s is not a template declaration, it is a %s", id->toChars(), s->kind());
                return false;
            }
        }
    }
    return (tempdecl != NULL);
}

bool TemplateInstance::semanticTiargs(Scope *sc)
{
    //printf("+TemplateInstance::semanticTiargs() %s\n", toChars());
    if (semantictiargsdone)
        return true;
    semantictiargsdone = 1;
    semanticTiargs(loc, sc, tiargs, 0);
    return arrayObjectIsError(tiargs) == 0;
}

/**********************************
 * Return true if e could be valid only as a template value parameter.
 * Return false if it might be an alias or tuple.
 * (Note that even in this case, it could still turn out to be a value).
 */
bool definitelyValueParameter(Expression *e)
{
    // None of these can be value parameters
    if (e->op == TOKtuple || e->op == TOKimport  ||
        e->op == TOKtype || e->op == TOKdottype ||
        e->op == TOKtemplate ||  e->op == TOKdottd ||
        e->op == TOKfunction || e->op == TOKerror ||
        e->op == TOKthis || e->op == TOKsuper)
        return false;

    if (e->op != TOKdotvar)
        return true;

 /* Template instantiations involving a DotVar expression are difficult.
  * In most cases, they should be treated as a value parameter, and interpreted.
  * But they might also just be a fully qualified name, which should be treated
  * as an alias.
  */

    // x.y.f cannot be a value
    FuncDeclaration *f = ((DotVarExp *)e)->var->isFuncDeclaration();
    if (f)
        return false;

    while (e->op == TOKdotvar)
    {
        e = ((DotVarExp *)e)->e1;
    }
    // this.x.y and super.x.y couldn't possibly be valid values.
    if (e->op == TOKthis || e->op == TOKsuper)
        return false;

    // e.type.x could be an alias
    if (e->op == TOKdottype)
        return false;

    // var.x.y is the only other possible form of alias
    if (e->op != TOKvar)
        return true;

    VarDeclaration *v = ((VarExp *)e)->var->isVarDeclaration();

    // func.x.y is not an alias
    if (!v)
        return true;

    // TODO: Should we force CTFE if it is a global constant?

    return false;
}

/**********************************
 * Input:
 *      flags   1: replace const variables with their initializers
 *              2: don't devolve Parameter to Type
 */

void TemplateInstance::semanticTiargs(Loc loc, Scope *sc, Objects *tiargs, int flags)
{
    // Run semantic on each argument, place results in tiargs[]
    //printf("+TemplateInstance::semanticTiargs()\n");
    if (!tiargs)
        return;
    for (size_t j = 0; j < tiargs->dim; j++)
    {
        RootObject *o = (*tiargs)[j];
        Type *ta = isType(o);
        Expression *ea = isExpression(o);
        Dsymbol *sa = isDsymbol(o);

        //printf("1: (*tiargs)[%d] = %p, s=%p, v=%p, ea=%p, ta=%p\n", j, o, isDsymbol(o), isTuple(o), ea, ta);
        if (ta)
        {
            //printf("type %s\n", ta->toChars());
            // It might really be an Expression or an Alias
            ta->resolve(loc, sc, &ea, &ta, &sa);
            if (ea) goto Lexpr;
            if (sa) goto Ldsym;
            if (ta == NULL)
            {
                assert(global.errors);
                ta = Type::terror;
            }

        Ltype:
            if (ta->ty == Ttuple)
            {   // Expand tuple
                TypeTuple *tt = (TypeTuple *)ta;
                size_t dim = tt->arguments->dim;
                tiargs->remove(j);
                if (dim)
                {   tiargs->reserve(dim);
                    for (size_t i = 0; i < dim; i++)
                    {   Parameter *arg = (*tt->arguments)[i];
                        if (flags & 2 && arg->ident)
                            tiargs->insert(j + i, arg);
                        else
                            tiargs->insert(j + i, arg->type);
                    }
                }
                j--;
                continue;
            }
            (*tiargs)[j] = ta->merge2();
        }
        else if (ea)
        {
        Lexpr:
            //printf("+[%d] ea = %s %s\n", j, Token::toChars(ea->op), ea->toChars());
            if (!(flags & 1)) sc = sc->startCTFE();
            ea = ea->semantic(sc);
            if (!(flags & 1)) sc = sc->endCTFE();
            if (flags & 1) // only used by __traits, must not interpret the args
            {
                VarDeclaration *v;
                if (ea->op == TOKvar && (v = ((VarExp *)ea)->var->isVarDeclaration()) != NULL &&
                    !(v->storage_class & STCtemplateparameter))
                {
                    if (v->sem < SemanticDone)
                        v->semantic(sc);
                    // skip optimization for variable symbols
                }
                else
                {
                    ea = ea->optimize(WANTvalue);
                }
            }
            else if (ea->op == TOKvar)
            {   /* This test is to skip substituting a const var with
                 * its initializer. The problem is the initializer won't
                 * match with an 'alias' parameter. Instead, do the
                 * const substitution in TemplateValueParameter::matchArg().
                 */
            }
            else if (definitelyValueParameter(ea))
            {
                int olderrs = global.errors;
                ea->rvalue();   // check void expression
                ea = ea->ctfeInterpret();
                if (global.errors != olderrs)
                    ea = new ErrorExp();
            }
            //printf("-[%d] ea = %s %s\n", j, Token::toChars(ea->op), ea->toChars());
            if (!flags && isPseudoDsymbol(ea))
            {   (*tiargs)[j] = new ErrorExp();
                continue;
            }
            if (ea->op == TOKtuple)
            {   // Expand tuple
                TupleExp *te = (TupleExp *)ea;
                size_t dim = te->exps->dim;
                tiargs->remove(j);
                if (dim)
                {   tiargs->reserve(dim);
                    for (size_t i = 0; i < dim; i++)
                        tiargs->insert(j + i, (*te->exps)[i]);
                }
                j--;
                continue;
            }
            (*tiargs)[j] = ea;

            if (ea->op == TOKtype)
            {   ta = ea->type;
                goto Ltype;
            }
            if (ea->op == TOKimport)
            {   sa = ((ScopeExp *)ea)->sds;
                goto Ldsym;
            }
            if (ea->op == TOKfunction)
            {   FuncExp *fe = (FuncExp *)ea;
                /* A function literal, that is passed to template and
                 * already semanticed as function pointer, never requires
                 * outer frame. So convert it to global function is valid.
                 */
                if (fe->fd->tok == TOKreserved && fe->type->ty == Tpointer)
                {   // change to non-nested
                    fe->fd->tok = TOKfunction;
                    fe->fd->vthis = NULL;
                }
                else if (fe->td)
                {   /* If template argument is a template lambda,
                     * get template declaration itself. */
                    //sa = fe->td;
                    //goto Ldsym;
                }
            }
            if (ea->op == TOKdotvar)
            {   // translate expression to dsymbol.
                sa = ((DotVarExp *)ea)->var;
                goto Ldsym;
            }
            if (ea->op == TOKtemplate)
            {   sa = ((TemplateExp *)ea)->td;
                goto Ldsym;
            }
            if (ea->op == TOKdottd)
            {   // translate expression to dsymbol.
                sa = ((DotTemplateExp *)ea)->td;
                goto Ldsym;
            }
        }
        else if (sa)
        {
        Ldsym:
            //printf("dsym %s %s\n", sa->kind(), sa->toChars());
            if (!flags && isPseudoDsymbol(sa))
            {   (*tiargs)[j] = new ErrorExp();
                continue;
            }
            TupleDeclaration *d = sa->toAlias()->isTupleDeclaration();
            if (d)
            {   // Expand tuple
                size_t dim = d->objects->dim;
                tiargs->remove(j);
                tiargs->insert(j, d->objects);
                j--;
                continue;
            }
            if (FuncAliasDeclaration *fa = sa->isFuncAliasDeclaration())
            {
                FuncDeclaration *f = fa->toAliasFunc();
                if (!fa->hasOverloads && f->isUnique())
                {
                    // Strip FuncAlias only when the aliased function
                    // does not have any overloads.
                    sa = f;
                }
            }
            (*tiargs)[j] = sa;

            TemplateDeclaration *td = sa->isTemplateDeclaration();
            if (td && td->semanticRun == PASSinit && td->literal)
            {
                td->semantic(sc);
            }
            FuncDeclaration *fd = sa->isFuncDeclaration();
            if (fd)
                fd->functionSemantic();
        }
        else if (isParameter(o))
        {
        }
        else
        {
            assert(0);
        }
        //printf("1: (*tiargs)[%d] = %p\n", j, (*tiargs)[j]);
    }
#if 0
    printf("-TemplateInstance::semanticTiargs()\n");
    for (size_t j = 0; j < tiargs->dim; j++)
    {
        RootObject *o = (*tiargs)[j];
        Type *ta = isType(o);
        Expression *ea = isExpression(o);
        Dsymbol *sa = isDsymbol(o);
        Tuple *va = isTuple(o);

        printf("\ttiargs[%d] = ta %p, ea %p, sa %p, va %p\n", j, ta, ea, sa, va);
    }
#endif
}

bool TemplateInstance::findBestMatch(Scope *sc, Expressions *fargs)
{
    if (havetempdecl)
    {
        TemplateDeclaration *tempdecl = this->tempdecl->isTemplateDeclaration();
        assert(tempdecl);
        assert(tempdecl->scope);
        // Deduce tdtypes
        tdtypes.setDim(tempdecl->parameters->dim);
        if (!tempdecl->matchWithInstance(sc, this, &tdtypes, fargs, 2))
        {
            error("incompatible arguments for template instantiation");
            return false;
        }
        return true;
    }

#if LOG
    printf("TemplateInstance::findBestMatch()\n");
#endif
    unsigned errs = global.errors;

  struct ParamBest
  {
    // context
    Scope *sc;
    TemplateInstance *ti;
    Objects dedtypes;
    // result
    TemplateDeclaration *td_best;
    TemplateDeclaration *td_ambig;
    MATCH m_best;

    static int fp(void *param, Dsymbol *s)
    {
        return ((ParamBest *)param)->fp(s);
    }
    int fp(Dsymbol *s)
    {
        TemplateDeclaration *td = s->isTemplateDeclaration();
        if (!td)
            return 0;

        if (td == td_best)          // skip duplicates
            return 0;

        //printf("td = %s\n", td->toPrettyChars());

        // If more arguments than parameters,
        // then this is no match.
        if (td->parameters->dim < ti->tiargs->dim)
        {
            if (!td->isVariadic())
                return 0;
        }

        dedtypes.setDim(td->parameters->dim);
        dedtypes.zero();
        assert(td->semanticRun != PASSinit);
        MATCH m = td->matchWithInstance(sc, ti, &dedtypes, ti->fargs, 0);
        //printf("matchWithInstance = %d\n", m);
        if (m <= MATCHnomatch)                 // no match at all
            return 0;

        if (m < m_best) goto Ltd_best;
        if (m > m_best) goto Ltd;

        {
        // Disambiguate by picking the most specialized TemplateDeclaration
        MATCH c1 = td->leastAsSpecialized(sc, td_best, ti->fargs);
        MATCH c2 = td_best->leastAsSpecialized(sc, td, ti->fargs);
        //printf("c1 = %d, c2 = %d\n", c1, c2);
        if (c1 > c2) goto Ltd;
        if (c1 < c2) goto Ltd_best;
        }

      Lambig:           // td_best and td are ambiguous
        td_ambig = td;
        return 0;

      Ltd_best:         // td_best is the best match so far
        td_ambig = NULL;
        return 0;

      Ltd:              // td is the new best match
        td_ambig = NULL;
        td_best = td;
        m_best = m;
        ti->tdtypes.setDim(dedtypes.dim);
        memcpy(ti->tdtypes.tdata(), dedtypes.tdata(), ti->tdtypes.dim * sizeof(void *));
        return 0;
    }
  };
    ParamBest p;
    // context
    p.ti = this;
    p.sc = sc;

    /* Since there can be multiple TemplateDeclaration's with the same
     * name, look for the best match.
     */
    TemplateDeclaration *td_last = NULL;

    OverloadSet *tovers = tempdecl->isOverloadSet();
    size_t overs_dim = tovers ? tovers->a.dim : 1;
    for (size_t oi = 0; oi < overs_dim; oi++)
    {
        // result
        p.td_best  = NULL;
        p.td_ambig = NULL;
        p.m_best   = MATCHnomatch;
        overloadApply(tovers ? tovers->a[oi] : tempdecl, &p, &ParamBest::fp);

        if (p.td_ambig)
        {
            ::error(loc, "%s %s.%s matches more than one template declaration:\n\t%s(%d):%s\nand\n\t%s(%d):%s",
                    p.td_best->kind(), p.td_best->parent->toPrettyChars(), p.td_best->ident->toChars(),
                    p.td_best->loc.filename,  p.td_best->loc.linnum,  p.td_best->toChars(),
                    p.td_ambig->loc.filename, p.td_ambig->loc.linnum, p.td_ambig->toChars());
            return false;
        }
        if (p.td_best)
        {
            if (!td_last)
                td_last = p.td_best;
            else if (td_last != p.td_best)
            {
                ScopeDsymbol::multiplyDefined(loc, td_last, p.td_best);
                return false;
            }
        }
    }

    if (!td_last)
    {
        TemplateDeclaration *tdecl = tempdecl->isTemplateDeclaration();

        if (errs != global.errors)
            errorSupplemental(loc, "while looking for match for %s", toChars());
        else if (tovers)
            error("does not match template overload set %s", tovers->toChars());
        else if (tdecl && !tdecl->overnext)
            // Only one template, so we can give better error message
            error("does not match template declaration %s", tdecl->toChars());
        else
            ::error(loc, "%s %s.%s does not match any template declaration",
                    tdecl->kind(), tdecl->parent->toPrettyChars(), tdecl->ident->toChars());
        return false;
    }

    /* The best match is td_last
     */
    tempdecl = td_last;

#if LOG
    printf("\tIt's a match with template declaration '%s'\n", tempdecl->toChars());
#endif
    return (errs == global.errors);
}

/*****************************************************
 * Determine if template instance is really a template function,
 * and that template function needs to infer types from the function
 * arguments.
 *
 * Like findBestMatch, iterate possible template candidates,
 * but just looks only the necessity of type inference.
 */

bool TemplateInstance::needsTypeInference(Scope *sc, int flag)
{
    //printf("TemplateInstance::needsTypeInference() %s\n", toChars());

  struct ParamNeedsInf
  {
    // context
    Scope *sc;
    TemplateInstance *ti;
    int flag;
    // result
    Objects dedtypes;
    size_t count;

    static int fp(void *param, Dsymbol *s)
    {
        return ((ParamNeedsInf *)param)->fp(s);
    }
    int fp(Dsymbol *s)
    {
        TemplateDeclaration *td = s->isTemplateDeclaration();
        if (!td)
        {
        Lcontinue:
            return 0;
        }

        /* If any of the overloaded template declarations need inference,
         * then return true
         */
        FuncDeclaration *fd;
        if (!td->onemember)
            return 0;
        if (TemplateDeclaration *td2 = td->onemember->isTemplateDeclaration())
        {
            if (!td2->onemember || !td2->onemember->isFuncDeclaration())
                return 0;
            if (ti->tiargs->dim > td->parameters->dim && !td->isVariadic())
                return 0;
            return 1;
        }
        if ((fd = td->onemember->isFuncDeclaration()) == NULL ||
            fd->type->ty != Tfunction)
        {
            return 0;
        }

        for (size_t i = 0; i < td->parameters->dim; i++)
        {
            if ((*td->parameters)[i]->isTemplateThisParameter())
                return 1;
        }

        /* Determine if the instance arguments, tiargs, are all that is necessary
         * to instantiate the template.
         */
        //printf("tp = %p, td->parameters->dim = %d, tiargs->dim = %d\n", tp, td->parameters->dim, ti->tiargs->dim);
        TypeFunction *tf = (TypeFunction *)fd->type;
        if (size_t dim = Parameter::dim(tf->parameters))
        {
            TemplateParameter *tp = td->isVariadic();
            if (tp && td->parameters->dim > 1)
                return 1;

            if (ti->tiargs->dim < td->parameters->dim)
            {
                // Can remain tiargs be filled by default arguments?
                for (size_t i = ti->tiargs->dim; i < td->parameters->dim; i++)
                {
                    tp = (*td->parameters)[i];
                    if (TemplateTypeParameter *ttp = tp->isTemplateTypeParameter())
                    {
                        if (!ttp->defaultType)
                            return 1;
                    }
                    else if (TemplateAliasParameter *tap = tp->isTemplateAliasParameter())
                    {
                        if (!tap->defaultAlias)
                            return 1;
                    }
                    else if (TemplateValueParameter *tvp = tp->isTemplateValueParameter())
                    {
                        if (!tvp->defaultValue)
                            return 1;
                    }
                }
            }

            for (size_t i = 0; i < dim; i++)
            {
                // 'auto ref' needs inference.
                if (Parameter::getNth(tf->parameters, i)->storageClass & STCauto)
                    return 1;
            }
        }

        if (!flag)
        {
            /* Calculate the need for overload resolution.
             * When only one template can match with tiargs, inference is not necessary.
             */
            dedtypes.setDim(td->parameters->dim);
            dedtypes.zero();
            assert(td->semanticRun != PASSinit);
            MATCH m = td->matchWithInstance(sc, ti, &dedtypes, NULL, 0);
            if (m <= MATCHnomatch)
                return 0;
        }

        /* If there is more than one function template which matches, we may
         * need type inference (see Bugzilla 4430)
         */
        if (++count > 1)
            return 1;

        return 0;
    }
  };
    ParamNeedsInf p;
    // context
    p.ti    = this;
    p.sc    = sc;
    p.flag  = flag;
    // result
    p.count = 0;

    OverloadSet *tovers = tempdecl->isOverloadSet();
    size_t overs_dim = tovers ? tovers->a.dim : 1;
    for (size_t oi = 0; oi < overs_dim; oi++)
    {
        if (int r = overloadApply(tovers ? tovers->a[oi] : tempdecl, &p, &ParamNeedsInf::fp))
            return true;
    }
    //printf("false\n");
    return false;
}


/*****************************************
 * Determines if a TemplateInstance will need a nested
 * generation of the TemplateDeclaration.
 * Sets enclosing property if so, and returns != 0;
 */

bool TemplateInstance::hasNestedArgs(Objects *args, bool isstatic)
{
    int nested = 0;
    //printf("TemplateInstance::hasNestedArgs('%s')\n", tempdecl->ident->toChars());

    /* A nested instance happens when an argument references a local
     * symbol that is on the stack.
     */
    for (size_t i = 0; i < args->dim; i++)
    {
        RootObject *o = (*args)[i];
        Expression *ea = isExpression(o);
        Dsymbol *sa = isDsymbol(o);
        Tuple *va = isTuple(o);
        if (ea)
        {
            if (ea->op == TOKvar)
            {
                sa = ((VarExp *)ea)->var;
                goto Lsa;
            }
            if (ea->op == TOKthis)
            {
                sa = ((ThisExp *)ea)->var;
                goto Lsa;
            }
            if (ea->op == TOKfunction)
            {
                if (((FuncExp *)ea)->td)
                    sa = ((FuncExp *)ea)->td;
                else
                    sa = ((FuncExp *)ea)->fd;
                goto Lsa;
            }
            // Emulate Expression::toMangleBuffer call that had exist in TemplateInstance::genIdent.
            if (ea->op != TOKint64 &&               // IntegerExp
                ea->op != TOKfloat64 &&             // RealExp
                ea->op != TOKcomplex80 &&           // CompexExp
                ea->op != TOKnull &&                // NullExp
                ea->op != TOKstring &&              // StringExp
                ea->op != TOKarrayliteral &&        // ArrayLiteralExp
                ea->op != TOKassocarrayliteral &&   // AssocArrayLiteralExp
                ea->op != TOKstructliteral)         // StructLiteralExp
            {
                ea->error("expression %s is not a valid template value argument", ea->toChars());
            }
        }
        else if (sa)
        {
          Lsa:
            sa = sa->toAlias();
            TemplateDeclaration *td = sa->isTemplateDeclaration();
            if (td)
            {
                TemplateInstance *ti = sa->toParent()->isTemplateInstance();
                if (ti && ti->enclosing)
                    sa = ti;
            }
            TemplateInstance *ti = sa->isTemplateInstance();
            AggregateDeclaration *ad = sa->isAggregateDeclaration();
            Declaration *d = sa->isDeclaration();
            if ((td && td->literal) ||
                (ti && ti->enclosing) ||
                (d && !d->isDataseg() &&
                 !(d->storage_class & STCmanifest) &&
                 (!d->isFuncDeclaration() || d->isFuncDeclaration()->isNested()) &&
                 !isTemplateMixin()
                ))
            {
                // if module level template
                if (isstatic)
                {
                    Dsymbol *dparent = sa->toParent2();
                    if (!enclosing)
                        enclosing = dparent;
                    else if (enclosing != dparent)
                    {
                        /* Select the more deeply nested of the two.
                         * Error if one is not nested inside the other.
                         */
                        for (Dsymbol *p = enclosing; p; p = p->parent)
                        {
                            if (p == dparent)
                                goto L1;        // enclosing is most nested
                        }
                        for (Dsymbol *p = dparent; p; p = p->parent)
                        {
                            if (p == enclosing)
                            {   enclosing = dparent;
                                goto L1;        // dparent is most nested
                            }
                        }
                        error("%s is nested in both %s and %s",
                                toChars(), enclosing->toChars(), dparent->toChars());
                    }
                  L1:
                    //printf("\tnested inside %s\n", enclosing->toChars());
                    nested |= 1;
                }
                else
                    error("cannot use local '%s' as parameter to non-global template %s", sa->toChars(), tempdecl->toChars());
            }
        }
        else if (va)
        {
            nested |= hasNestedArgs(&va->objects, isstatic);
        }
    }
    //printf("-TemplateInstance::hasNestedArgs('%s') = %d\n", tempdecl->ident->toChars(), nested);
    return nested != 0;
}

/****************************************
 * This instance needs an identifier for name mangling purposes.
 * Create one by taking the template declaration name and adding
 * the type signature for it.
 */

Identifier *TemplateInstance::genIdent(Objects *args)
{
    assert(tempdecl);

    //printf("TemplateInstance::genIdent('%s')\n", tempdecl->ident->toChars());
    OutBuffer buf;
    char *id = tempdecl->ident->toChars();
    buf.printf("__T%llu%s", (ulonglong)strlen(id), id);
    for (size_t i = 0; i < args->dim; i++)
    {
        RootObject *o = (*args)[i];
        Type *ta = isType(o);
        Expression *ea = isExpression(o);
        Dsymbol *sa = isDsymbol(o);
        Tuple *va = isTuple(o);
        //printf("\to [%d] %p ta %p ea %p sa %p va %p\n", i, o, ta, ea, sa, va);
        if (ta)
        {
            buf.writeByte('T');
            if (ta->deco)
                buf.writestring(ta->deco);
            else
            {
#ifdef DEBUG
                if (!global.errors)
                    printf("ta = %d, %s\n", ta->ty, ta->toChars());
#endif
                assert(global.errors);
            }
        }
        else if (ea)
        {
            // Don't interpret it yet, it might actually be an alias
            ea = ea->optimize(WANTvalue);
            if (ea->op == TOKvar)
            {
                sa = ((VarExp *)ea)->var;
                ea = NULL;
                goto Lsa;
            }
            if (ea->op == TOKthis)
            {
                sa = ((ThisExp *)ea)->var;
                ea = NULL;
                goto Lsa;
            }
            if (ea->op == TOKfunction)
            {
                if (((FuncExp *)ea)->td)
                    sa = ((FuncExp *)ea)->td;
                else
                    sa = ((FuncExp *)ea)->fd;
                ea = NULL;
                goto Lsa;
            }
            buf.writeByte('V');
            if (ea->op == TOKtuple)
            {   ea->error("tuple is not a valid template value argument");
                continue;
            }
            // Now that we know it is not an alias, we MUST obtain a value
            unsigned olderr = global.errors;
            ea = ea->ctfeInterpret();
            if (ea->op == TOKerror || olderr != global.errors)
                continue;
#if 1
            /* Use deco that matches what it would be for a function parameter
             */
            buf.writestring(ea->type->deco);
#else
            // Use type of parameter, not type of argument
            TemplateParameter *tp = (*tempdecl->parameters)[i];
            assert(tp);
            TemplateValueParameter *tvp = tp->isTemplateValueParameter();
            assert(tvp);
            buf.writestring(tvp->valType->deco);
#endif
            ea->toMangleBuffer(&buf);
        }
        else if (sa)
        {
          Lsa:
            buf.writeByte('S');
            sa = sa->toAlias();
            Declaration *d = sa->isDeclaration();
            if (d && (!d->type || !d->type->deco))
            {
                error("forward reference of %s %s", d->kind(), d->toChars());
                continue;
            }
#if 0
            VarDeclaration *v = sa->isVarDeclaration();
            if (v && v->storage_class & STCmanifest)
            {   ExpInitializer *ei = v->init->isExpInitializer();
                if (ei)
                {
                    ea = ei->exp;
                    goto Lea;
                }
            }
#endif
            const char *p = sa->mangle();

            /* Bugzilla 3043: if the first character of p is a digit this
             * causes ambiguity issues because the digits of the two numbers are adjacent.
             * Current demanglers resolve this by trying various places to separate the
             * numbers until one gets a successful demangle.
             * Unfortunately, fixing this ambiguity will break existing binary
             * compatibility and the demanglers, so we'll leave it as is.
             */
            buf.printf("%llu%s", (ulonglong)strlen(p), p);
        }
        else if (va)
        {
            assert(i + 1 == args->dim);         // must be last one
            args = &va->objects;
            i = -(size_t)1;
        }
        else
            assert(0);
    }
    buf.writeByte('Z');
    id = buf.toChars();
    //buf.data = NULL;                          // we can free the string after call to idPool()
    //printf("\tgenIdent = %s\n", id);
    return Lexer::idPool(id);
}

/*************************************
 * Lazily generate identifier for template instance.
 * This is because 75% of the ident's are never needed.
 */

Identifier *TemplateInstance::getIdent()
{
    if (!ident && inst)
        ident = genIdent(tiargs);         // need an identifier for name mangling purposes.
    return ident;
}

/****************************************************
 * Declare parameters of template instance, initialize them with the
 * template instance arguments.
 */

void TemplateInstance::declareParameters(Scope *sc)
{
    TemplateDeclaration *tempdecl = this->tempdecl->isTemplateDeclaration();
    assert(tempdecl);

    //printf("TemplateInstance::declareParameters()\n");
    for (size_t i = 0; i < tdtypes.dim; i++)
    {
        TemplateParameter *tp = (*tempdecl->parameters)[i];
        //RootObject *o = (*tiargs)[i];
        RootObject *o = tdtypes[i];          // initializer for tp

        //printf("\ttdtypes[%d] = %p\n", i, o);
        tempdecl->declareParameter(sc, tp, o);
    }
}

void TemplateInstance::semantic2(Scope *sc)
{
    if (semanticRun >= PASSsemantic2)
        return;
    semanticRun = PASSsemantic2;
#if LOG
    printf("+TemplateInstance::semantic2('%s')\n", toChars());
#endif
    if (!errors && members)
    {
        sc = tempdecl->scope;
        assert(sc);
        sc = sc->push(argsym);
        sc->instantiatingModule = instantiatingModule;
        sc = sc->push(this);
        sc->tinst = this;
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
#if LOG
printf("\tmember '%s', kind = '%s'\n", s->toChars(), s->kind());
#endif
            s->semantic2(sc);
        }
        sc = sc->pop();
        sc->pop();
    }
#if LOG
    printf("-TemplateInstance::semantic2('%s')\n", toChars());
#endif
}

void TemplateInstance::semantic3(Scope *sc)
{
#if LOG
    printf("TemplateInstance::semantic3('%s'), semanticRun = %d\n", toChars(), semanticRun);
#endif
//if (toChars()[0] == 'D') *(char*)0=0;
    if (semanticRun >= PASSsemantic3)
        return;
    semanticRun = PASSsemantic3;
    if (!errors && members)
    {
        sc = tempdecl->scope;
        sc = sc->push(argsym);
        sc->instantiatingModule = instantiatingModule;
        sc = sc->push(this);
        sc->tinst = this;
        int needGagging = (speculative && !global.gag);
        int olderrors = global.errors;
        int oldGaggedErrors;
        /* If this is a speculative instantiation, gag errors.
         * Future optimisation: If the results are actually needed, errors
         * would already be gagged, so we don't really need to run semantic
         * on the members.
         */
        if (needGagging)
            oldGaggedErrors = global.startGagging();
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->semantic3(sc);
            if (speculative && global.errors != olderrors)
                break;
        }
        if (needGagging)
        {   // If errors occurred, this instantiation failed
            if (global.endGagging(oldGaggedErrors))
                errors = true;
        }
        sc = sc->pop();
        sc->pop();
    }
}

/**************************************
 * Given an error instantiating the TemplateInstance,
 * give the nested TemplateInstance instantiations that got
 * us here. Those are a list threaded into the nested scopes.
 */
void TemplateInstance::printInstantiationTrace()
{
    if (global.gag)
        return;

    const unsigned max_shown = 6;
    const char format[] = "instantiated from here: %s";

    // determine instantiation depth and number of recursive instantiations
    int n_instantiations = 1;
    int n_totalrecursions = 0;
    for (TemplateInstance *cur = this; cur; cur = cur->tinst)
    {
        ++n_instantiations;
        // If two instantiations use the same declaration, they are recursive.
        // (this works even if they are instantiated from different places in the
        // same template).
        // In principle, we could also check for multiple-template recursion, but it's
        // probably not worthwhile.
        if (cur->tinst && cur->tempdecl && cur->tinst->tempdecl
            && cur->tempdecl->loc.equals(cur->tinst->tempdecl->loc))
            ++n_totalrecursions;
    }

    // show full trace only if it's short or verbose is on
    if (n_instantiations <= max_shown || global.params.verbose)
    {
        for (TemplateInstance *cur = this; cur; cur = cur->tinst)
        {
            errorSupplemental(cur->loc, format, cur->toChars());
        }
    }
    else if (n_instantiations - n_totalrecursions <= max_shown)
    {
        // By collapsing recursive instantiations into a single line,
        // we can stay under the limit.
        int recursionDepth=0;
        for (TemplateInstance *cur = this; cur; cur = cur->tinst)
        {
            if (cur->tinst && cur->tempdecl && cur->tinst->tempdecl
                    && cur->tempdecl->loc.equals(cur->tinst->tempdecl->loc))
            {
                ++recursionDepth;
            }
            else
            {
                if (recursionDepth)
                    errorSupplemental(cur->loc, "%d recursive instantiations from here: %s", recursionDepth+2, cur->toChars());
                else
                    errorSupplemental(cur->loc, format, cur->toChars());
                recursionDepth = 0;
            }
        }
    }
    else
    {
        // Even after collapsing the recursions, the depth is too deep.
        // Just display the first few and last few instantiations.
        unsigned i = 0;
        for (TemplateInstance *cur = this; cur; cur = cur->tinst)
        {
            if (i == max_shown / 2)
                errorSupplemental(cur->loc, "... (%d instantiations, -v to show) ...", n_instantiations - max_shown);

            if (i < max_shown / 2 ||
                i >= n_instantiations - max_shown + max_shown / 2)
                errorSupplemental(cur->loc, format, cur->toChars());
            ++i;
        }
    }
}

void TemplateInstance::inlineScan()
{
#if LOG
    printf("TemplateInstance::inlineScan('%s')\n", toChars());
#endif
    if (!errors && members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->inlineScan();
        }
    }
}

void TemplateInstance::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    Identifier *id = name;
    buf->writestring(id->toChars());
    toCBufferTiargs(buf, hgs);
}

void TemplateInstance::toCBufferTiargs(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writeByte('!');
    if (nest)
        buf->writestring("(...)");
    else if (!tiargs)
        buf->writestring("()");
    else
    {
        if (tiargs->dim == 1)
        {
            RootObject *oarg = (*tiargs)[0];
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
                if (e->op == TOKint64 ||    // IntegerExp(10, true, false, 'c')
                    e->op == TOKfloat64 ||  // RealExp(3.14, 1.4i)
                    e->op == TOKnull ||     // NullExp
                    e->op == TOKstring ||   // StringExp
                    e->op == TOKthis)
                {
                    buf->writestring(e->toChars());
                    return;
                }
            }
        }
        buf->writeByte('(');
        nest++;
        for (size_t i = 0; i < tiargs->dim; i++)
        {
            if (i)
                buf->writestring(", ");
            RootObject *oarg = (*tiargs)[i];
            ObjectToCBuffer(buf, hgs, oarg);
        }
        nest--;
        buf->writeByte(')');
    }
}


Dsymbol *TemplateInstance::toAlias()
{
#if LOG
    printf("TemplateInstance::toAlias()\n");
#endif
    if (!inst)
    {
        // Maybe we can resolve it
        if (scope)
        {
            /* Anything that affects scope->offset must be
             * done in lexical order. Fwd ref error if it is affected, otherwise allow.
             */
            unsigned offset = scope->offset;
            Scope *sc = scope;
            semantic(scope);
//            if (offset != sc->offset)
//                inst = NULL;            // trigger fwd ref error
        }
        if (!inst)
        {
            error("cannot resolve forward reference");
            errors = true;
            return this;
        }
    }

    if (inst != this)
        return inst->toAlias();

    if (aliasdecl)
    {
        return aliasdecl->toAlias();
    }

    return inst;
}

AliasDeclaration *TemplateInstance::isAliasDeclaration()
{
    return aliasdecl;
}

const char *TemplateInstance::kind()
{
    return "template instance";
}

bool TemplateInstance::oneMember(Dsymbol **ps, Identifier *ident)
{
    *ps = NULL;
    return true;
}

char *TemplateInstance::toChars()
{
    OutBuffer buf;
    HdrGenState hgs;
    char *s;

    toCBuffer(&buf, &hgs);
    s = buf.toChars();
    buf.data = NULL;
    return s;
}

int TemplateInstance::compare(RootObject *o)
{
    TemplateInstance *ti = (TemplateInstance *)o;

    //printf("this = %p, ti = %p\n", this, ti);
    assert(tdtypes.dim == ti->tdtypes.dim);

    // Nesting must match
    if (enclosing != ti->enclosing)
    {
        //printf("test2 enclosing %s ti->enclosing %s\n", enclosing ? enclosing->toChars() : "", ti->enclosing ? ti->enclosing->toChars() : "");
        goto Lnotequals;
    }
    //printf("parent = %s, ti->parent = %s\n", parent->toPrettyChars(), ti->parent->toPrettyChars());

    if (!arrayObjectMatch(&tdtypes, &ti->tdtypes))
        goto Lnotequals;

    /* Template functions may have different instantiations based on
     * "auto ref" parameters.
     */
    if (fargs)
    {
        FuncDeclaration *fd = ti->toAlias()->isFuncDeclaration();
        if (fd && !fd->errors)
        {
            Parameters *fparameters = fd->getParameters(NULL);
            size_t nfparams = Parameter::dim(fparameters); // Num function parameters
            for (size_t j = 0; j < nfparams && j < fargs->dim; j++)
            {
                Parameter *fparam = Parameter::getNth(fparameters, j);
                Expression *farg = (*fargs)[j];
                if (fparam->storageClass & STCauto)         // if "auto ref"
                {
                    if (farg->isLvalue())
                    {
                        if (!(fparam->storageClass & STCref))
                            goto Lnotequals;                // auto ref's don't match
                    }
                    else
                    {
                        if (fparam->storageClass & STCref)
                            goto Lnotequals;                // auto ref's don't match
                    }
                }
            }
        }
    }
    return 0;

  Lnotequals:
    return 1;
}

hash_t TemplateInstance::hashCode()
{
    if (!hash)
    {
        hash = (size_t)(void *)enclosing;
        hash += arrayObjectHash(&tdtypes);
    }
    return hash;
}



/* ======================== TemplateMixin ================================ */

TemplateMixin::TemplateMixin(Loc loc, Identifier *ident, TypeQualified *tqual, Objects *tiargs)
        : TemplateInstance(loc, tqual->idents.dim ? (Identifier *)tqual->idents[tqual->idents.dim - 1]
                                                  : ((TypeIdentifier *)tqual)->ident)
{
    //printf("TemplateMixin(ident = '%s')\n", ident ? ident->toChars() : "");
    this->ident = ident;
    this->tqual = tqual;
    this->tiargs = tiargs ? tiargs : new Objects();
}

Dsymbol *TemplateMixin::syntaxCopy(Dsymbol *s)
{
    TemplateMixin *tm = new TemplateMixin(loc, ident,
                (TypeQualified *)tqual->syntaxCopy(), tiargs);
    TemplateInstance::syntaxCopy(tm);
    return tm;
}

bool TemplateMixin::findTemplateDeclaration(Scope *sc)
{
    // Follow qualifications to find the TemplateDeclaration
    if (!tempdecl)
    {
        Expression *e;
        Type *t;
        Dsymbol *s;
        tqual->resolve(loc, sc, &e, &t, &s);
        if (!s)
        {
            error("is not defined");
            return false;
        }
        s = s->toAlias();
        tempdecl = s->isTemplateDeclaration();
        OverloadSet *os = s->isOverloadSet();

        /* If an OverloadSet, look for a unique member that is a template declaration
         */
        if (os)
        {
            Dsymbol *ds = NULL;
            for (size_t i = 0; i < os->a.dim; i++)
            {
                Dsymbol *s2 = os->a[i]->isTemplateDeclaration();
                if (s2)
                {
                    if (ds)
                    {
                        tempdecl = os;
                        break;
                    }
                    ds = s2;
                }
            }
        }
        if (!tempdecl)
        {
            error("%s isn't a template", s->toChars());
            return false;
        }
    }
    assert(tempdecl);

  struct ParamFwdResTm
  {
    static int fp(void *param, Dsymbol *s)
    {
        TemplateDeclaration *td = s->isTemplateDeclaration();
        if (!td)
            return 0;

        TemplateMixin *tm = (TemplateMixin *)param;
        if (td->semanticRun == PASSinit)
        {
            if (td->scope)
                td->semantic(td->scope);
            else
            {
                tm->semanticRun = PASSinit;
                return 1;
            }
        }
        return 0;
    }
  };
    // Look for forward references
    OverloadSet *tovers = tempdecl->isOverloadSet();
    size_t overs_dim = tovers ? tovers->a.dim : 1;
    for (size_t oi = 0; oi < overs_dim; oi++)
    {
        if (overloadApply(tovers ? tovers->a[oi] : tempdecl, (void *)this, &ParamFwdResTm::fp))
            return false;
    }
    return true;
}

void TemplateMixin::semantic(Scope *sc)
{
#if LOG
    printf("+TemplateMixin::semantic('%s', this=%p)\n", toChars(), this);
    fflush(stdout);
#endif
    if (semanticRun != PASSinit)
    {
        // This for when a class/struct contains mixin members, and
        // is done over because of forward references
        if (parent && toParent()->isAggregateDeclaration())
        {
            if (sc->parent != parent)
                return;
            semanticRun = PASSsemantic;            // do over
        }
        else
        {
#if LOG
            printf("\tsemantic done\n");
#endif
            return;
        }
    }
    if (semanticRun == PASSinit)
        semanticRun = PASSsemantic;
#if LOG
    printf("\tdo semantic\n");
#endif

    Scope *scx = NULL;
    if (scope)
    {
        sc = scope;
        scx = scope;            // save so we don't make redundant copies
        scope = NULL;
    }


    /* Run semantic on each argument, place results in tiargs[],
     * then find best match template with tiargs
     */
    if (!findTemplateDeclaration(sc) ||
        !semanticTiargs(sc) ||
        !findBestMatch(sc, NULL))
    {
        if (semanticRun == PASSinit)    // forward reference had occured
        {
            /* Cannot handle forward references if mixin is a struct member,
             * because addField must happen during struct's semantic, not
             * during the mixin semantic.
             * runDeferred will re-run mixin's semantic outside of the struct's
             * semantic.
             */
            AggregateDeclaration *ad = toParent()->isAggregateDeclaration();
            if (ad)
                ad->sizeok = SIZEOKfwd;
            else
            {
                // Forward reference
                //printf("forward reference - deferring\n");
                scope = scx ? scx : new Scope(*sc);
                scope->setNoFree();
                scope->module->addDeferredSemantic(this);
            }
            return;
        }

        inst = this;
        inst->errors = true;
        return;         // error recovery
    }
    TemplateDeclaration *tempdecl = this->tempdecl->isTemplateDeclaration();
    assert(tempdecl);

    if (!ident)
    {
        /* Assign scope local unique identifier, as same as lambdas.
         */
        const char *s = "__mixin";

        DsymbolTable *symtab;
        if (FuncDeclaration *func = sc->parent->isFuncDeclaration())
        {
            symtab = func->localsymtab;
            if (symtab)
            {
                // Inside template constraint, symtab is not set yet.
                goto L1;
            }
        }
        else
        {
            symtab = sc->parent->isScopeDsymbol()->symtab;
        L1:
            assert(symtab);
            int num = (int)_aaLen(symtab->tab) + 1;
            ident = Lexer::uniqueId(s, num);
            symtab->insert(this);
        }
    }

    inst = this;
    parent = sc->parent;

    /* Detect recursive mixin instantiations.
     */
    for (Dsymbol *s = parent; s; s = s->parent)
    {
        //printf("\ts = '%s'\n", s->toChars());
        TemplateMixin *tm = s->isTemplateMixin();
        if (!tm || tempdecl != tm->tempdecl)
            continue;

        /* Different argument list lengths happen with variadic args
         */
        if (tiargs->dim != tm->tiargs->dim)
            continue;

        for (size_t i = 0; i < tiargs->dim; i++)
        {
            RootObject *o = (*tiargs)[i];
            Type *ta = isType(o);
            Expression *ea = isExpression(o);
            Dsymbol *sa = isDsymbol(o);
            RootObject *tmo = (*tm->tiargs)[i];
            if (ta)
            {
                Type *tmta = isType(tmo);
                if (!tmta)
                    goto Lcontinue;
                if (!ta->equals(tmta))
                    goto Lcontinue;
            }
            else if (ea)
            {
                Expression *tme = isExpression(tmo);
                if (!tme || !ea->equals(tme))
                    goto Lcontinue;
            }
            else if (sa)
            {
                Dsymbol *tmsa = isDsymbol(tmo);
                if (sa != tmsa)
                    goto Lcontinue;
            }
            else
                assert(0);
        }
        error("recursive mixin instantiation");
        return;

    Lcontinue:
        continue;
    }

    // Copy the syntax trees from the TemplateDeclaration
    if (scx && members && !errors)
    {}  // Don't copy again so they were previously created.
    else
        members = Dsymbol::arraySyntaxCopy(tempdecl->members);
    if (!members)
        return;

    symtab = new DsymbolTable();

    for (Scope *sce = sc; 1; sce = sce->enclosing)
    {
        ScopeDsymbol *sds = (ScopeDsymbol *)sce->scopesym;
        if (sds)
        {
            sds->importScope(this, PROTpublic);
            break;
        }
    }

#if LOG
    printf("\tcreate scope for template parameters '%s'\n", toChars());
#endif
    Scope *scy = sc->push(this);
    scy->parent = this;

    argsym = new ScopeDsymbol();
    argsym->parent = scy->parent;
    Scope *argscope = scy->push(argsym);

    unsigned errorsave = global.errors;

    // Declare each template parameter as an alias for the argument type
    declareParameters(argscope);

    // Add members to enclosing scope, as well as this scope
    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
        s->addMember(argscope, this, i != 0);
        //printf("sc->parent = %p, sc->scopesym = %p\n", sc->parent, sc->scopesym);
        //printf("s->parent = %s\n", s->parent->toChars());
    }

    // Do semantic() analysis on template instance members
#if LOG
    printf("\tdo semantic() on template instance members '%s'\n", toChars());
#endif
    Scope *sc2;
    sc2 = argscope->push(this);
    sc2->offset = sc->offset;

    size_t deferred_dim = Module::deferred.dim;

    static int nest;
    //printf("%d\n", nest);
    if (++nest > 500)
    {
        global.gag = 0;                 // ensure error message gets printed
        error("recursive expansion");
        fatal();
    }

    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
        s->setScope(sc2);
    }

    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
        s->semantic(sc2);
    }

    nest--;

    sc->offset = sc2->offset;

    if (!sc->func && Module::deferred.dim > deferred_dim)
    {
        sc2->pop();
        argscope->pop();
        scy->pop();
        //printf("deferring mixin %s, deferred.dim += %d\n", toChars(), Module::deferred.dim - deferred_dim);
        //printf("\t[");
        //for (size_t u = 0; u < Module::deferred.dim; u++) printf("%s%s", Module::deferred[u]->toChars(), u == Module::deferred.dim-1?"":", ");
        //printf("]\n");

        semanticRun = PASSinit;
        AggregateDeclaration *ad = toParent()->isAggregateDeclaration();
        if (ad)
        {
            /* Forward reference of base class should not make derived class SIZEfwd.
             */
            //printf("\tad = %s, sizeok = %d\n", ad->toChars(), ad->sizeok);
            //ad->sizeok = SIZEOKfwd;
        }
        else
        {
            // Forward reference
            //printf("forward reference - deferring\n");
            scope = scx ? scx : new Scope(*sc);
            scope->setNoFree();
            scope->module->addDeferredSemantic(this);
        }
        return;
    }

    AggregateDeclaration *ad = toParent()->isAggregateDeclaration();
    if (sc->func && !ad)
    {
        semantic2(sc2);
        semantic3(sc2);
    }

    // Give additional context info if error occurred during instantiation
    if (global.errors != errorsave)
    {
        error("error instantiating");
        errors = true;
    }

    sc2->pop();
    argscope->pop();
    scy->pop();

#if LOG
    printf("-TemplateMixin::semantic('%s', this=%p)\n", toChars(), this);
#endif
}

void TemplateMixin::semantic2(Scope *sc)
{
    if (semanticRun >= PASSsemantic2)
        return;
    semanticRun = PASSsemantic2;
#if LOG
    printf("+TemplateMixin::semantic2('%s')\n", toChars());
#endif
    if (members)
    {
        assert(sc);
        sc = sc->push(argsym);
        sc = sc->push(this);
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
#if LOG
            printf("\tmember '%s', kind = '%s'\n", s->toChars(), s->kind());
#endif
            s->semantic2(sc);
        }
        sc = sc->pop();
        sc->pop();
    }
#if LOG
    printf("-TemplateMixin::semantic2('%s')\n", toChars());
#endif
}

void TemplateMixin::semantic3(Scope *sc)
{
    if (semanticRun >= PASSsemantic3)
        return;
    semanticRun = PASSsemantic3;
#if LOG
    printf("TemplateMixin::semantic3('%s')\n", toChars());
#endif
    if (members)
    {
        sc = sc->push(argsym);
        sc->instantiatingModule = instantiatingModule;
        sc = sc->push(this);
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->semantic3(sc);
        }
        sc = sc->pop();
        sc->pop();
    }
}

void TemplateMixin::inlineScan()
{
    TemplateInstance::inlineScan();
}

const char *TemplateMixin::kind()
{
    return "mixin";
}

bool TemplateMixin::oneMember(Dsymbol **ps, Identifier *ident)
{
    return Dsymbol::oneMember(ps, ident);
}

int TemplateMixin::apply(Dsymbol_apply_ft_t fp, void *param)
{
    if (members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            if (s)
            {
                if (s->apply(fp, param))
                    return 1;
            }
        }
    }
    return 0;
}

bool TemplateMixin::hasPointers()
{
    //printf("TemplateMixin::hasPointers() %s\n", toChars());

    if (members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            //printf(" s = %s %s\n", s->kind(), s->toChars());
            if (s->hasPointers())
            {
                return true;
            }
        }
    }
    return false;
}

void TemplateMixin::setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion)
{
    //printf("TemplateMixin::setFieldOffset() %s\n", toChars());
    if (scope)                  // if fwd reference
        semantic(NULL);         // try to resolve it
    if (members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            //printf("\t%s\n", s->toChars());
            s->setFieldOffset(ad, poffset, isunion);
        }
    }
}

char *TemplateMixin::toChars()
{
    OutBuffer buf;
    HdrGenState hgs;
    char *s;

    TemplateInstance::toCBuffer(&buf, &hgs);
    s = buf.toChars();
    buf.data = NULL;
    return s;
}

void TemplateMixin::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("mixin ");

    tqual->toCBuffer(buf, NULL, hgs);
    toCBufferTiargs(buf, hgs);

    if (ident && memcmp(ident->string, "__mixin", 7) != 0)
    {
        buf->writebyte(' ');
        buf->writestring(ident->toChars());
    }
    buf->writebyte(';');
    buf->writenl();
}


