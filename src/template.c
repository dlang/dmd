
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
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

#if WINDOWS_SEH
#include <windows.h>
long __cdecl __ehfilter(LPEXCEPTION_POINTERS ep);
#endif

#define LOG     0

#define IDX_NOTFOUND (0x12345678)               // index is not found

size_t templateParameterLookup(Type *tparam, TemplateParameters *parameters);

/********************************************
 * These functions substitute for dynamic_cast. dynamic_cast does not work
 * on earlier versions of gcc.
 */

Expression *isExpression(Object *o)
{
    //return dynamic_cast<Expression *>(o);
    if (!o || o->dyncast() != DYNCAST_EXPRESSION)
        return NULL;
    return (Expression *)o;
}

Dsymbol *isDsymbol(Object *o)
{
    //return dynamic_cast<Dsymbol *>(o);
    if (!o || o->dyncast() != DYNCAST_DSYMBOL)
        return NULL;
    return (Dsymbol *)o;
}

Type *isType(Object *o)
{
    //return dynamic_cast<Type *>(o);
    if (!o || o->dyncast() != DYNCAST_TYPE)
        return NULL;
    return (Type *)o;
}

Tuple *isTuple(Object *o)
{
    //return dynamic_cast<Tuple *>(o);
    if (!o || o->dyncast() != DYNCAST_TUPLE)
        return NULL;
    return (Tuple *)o;
}

Parameter *isParameter(Object *o)
{
    //return dynamic_cast<Parameter *>(o);
    if (!o || o->dyncast() != DYNCAST_PARAMETER)
        return NULL;
    return (Parameter *)o;
}

/**************************************
 * Is this Object an error?
 */
int isError(Object *o)
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
        Object *o = (*args)[i];
        if (isError(o))
            return 1;
    }
    return 0;
}

/***********************
 * Try to get arg as a type.
 */

Type *getType(Object *o)
{
    Type *t = isType(o);
    if (!t)
    {   Expression *e = isExpression(o);
        if (e)
            t = e->type;
    }
    return t;
}

Dsymbol *getDsymbol(Object *oarg)
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

int match(Object *o1, Object *o2, TemplateDeclaration *tempdecl, Scope *sc)
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
        /* if t1 is an instance of ti, then give error
         * about recursive expansions.
         */
        Dsymbol *s = t1->toDsymbol(sc);
        if (s && s->parent)
        {   TemplateInstance *ti1 = s->parent->isTemplateInstance();
            if (ti1 && ti1->tempdecl == tempdecl)
            {
                for (Scope *sc1 = sc; sc1; sc1 = sc1->enclosing)
                {
                    if (sc1->scopesym == ti1)
                    {
                        tempdecl->error("recursive template expansion for template argument %s", t1->toChars());
                        return 1;       // fake a match
                    }
                }
            }
        }

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
            FuncAliasDeclaration *fa1 = s1->isFuncAliasDeclaration();
            if (fa1)
                s1 = fa1->toAliasFunc();
            FuncAliasDeclaration *fa2 = s2->isFuncAliasDeclaration();
            if (fa2)
                s2 = fa2->toAliasFunc();
            if (!s1->equals(s2) || s1->parent != s2->parent)
                goto Lnomatch;
        }
        else
            goto Lnomatch;
    }
    else if (u1)
    {
        if (!u2)
            goto Lnomatch;
        if (u1->objects.dim != u2->objects.dim)
            goto Lnomatch;
        for (size_t i = 0; i < u1->objects.dim; i++)
        {
            if (!match(u1->objects[i],
                       u2->objects[i],
                       tempdecl, sc))
                goto Lnomatch;
        }
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
int arrayObjectMatch(Objects *oa1, Objects *oa2, TemplateDeclaration *tempdecl, Scope *sc)
{
    if (oa1 == oa2)
        return 1;
    if (oa1->dim != oa2->dim)
        return 0;
    for (size_t j = 0; j < oa1->dim; j++)
    {   Object *o1 = (*oa1)[j];
        Object *o2 = (*oa2)[j];
        if (!match(o1, o2, tempdecl, sc))
        {
            return 0;
        }
    }
    return 1;
}

/****************************************
 * This makes a 'pretty' version of the template arguments.
 * It's analogous to genIdent() which makes a mangled version.
 */

void ObjectToCBuffer(OutBuffer *buf, HdrGenState *hgs, Object *oarg)
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
            Object *o = (*args)[i];
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

#if DMDV2
Object *objectSyntaxCopy(Object *o)
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
#endif


/* ======================== TemplateDeclaration ============================= */

TemplateDeclaration::TemplateDeclaration(Loc loc, Identifier *id,
        TemplateParameters *parameters, Expression *constraint, Dsymbols *decldefs, int ismixin)
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
    this->semanticRun = PASSinit;
    this->onemember = NULL;
    this->literal = 0;
    this->ismixin = ismixin;
    this->previous = NULL;
    this->protection = PROTundefined;

    // Compute in advance for Ddoc's use
    if (members)
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
    td = new TemplateDeclaration(loc, ident, p, e, d, ismixin);
    td->literal = literal;
    return td;
}

void TemplateDeclaration::semantic(Scope *sc)
{
#if LOG
    printf("TemplateDeclaration::semantic(this = %p, id = '%s')\n", this, ident->toChars());
    printf("sc->stc = %llx\n", sc->stc);
    printf("sc->module = %s\n", sc->module->toChars());
#endif
    if (semanticRun)
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

    if (sc->func)
    {
#if DMDV1
        error("cannot declare template at function scope %s", sc->func->toChars());
#endif
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

#if DMDV2
    if (sc->module)
    {
        // Generate this function as it may be used
        // when template is instantiated in other modules
        sc->module->toModuleUnittest();
    }
#endif

    /* Remember Scope for later instantiations, but make
     * a copy since attributes can change.
     */
    if (!this->scope)
    {   this->scope = new Scope(*sc);
        this->scope->setNoFree();
    }

    // Set up scope for parameters
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = sc->parent;
    Scope *paramscope = sc->push(paramsym);
    paramscope->stc = 0;

    if (!parent)
        parent = sc->parent;

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
        {   error("template tuple parameter must be last one");
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
 * Return !=0 if successful; i.e. no conflict.
 */

int TemplateDeclaration::overloadInsert(Dsymbol *s)
{
#if LOG
    printf("TemplateDeclaration::overloadInsert('%s')\n", s->toChars());
#endif
    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (!td)
        return FALSE;

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
        return FALSE;

     Lcontinue:
        ;
#endif
    }

    td->overroot = this;
    *ptd = td;
#if LOG
    printf("\ttrue: no conflict\n");
#endif
    return TRUE;
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

MATCH TemplateDeclaration::matchWithInstance(TemplateInstance *ti,
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
    paramscope->stc = 0;

    // Attempt type deduction
    m = MATCHexact;
    for (size_t i = 0; i < dedtypes_dim; i++)
    {   MATCH m2;
        TemplateParameter *tp = (*parameters)[i];
        Declaration *sparam;

        //printf("\targument [%d]\n", i);
#if LOGM
        //printf("\targument [%d] is %s\n", i, oarg ? oarg->toChars() : "null");
        TemplateTypeParameter *ttp = tp->isTemplateTypeParameter();
        if (ttp)
            printf("\tparameter[%d] is %s : %s\n", i, tp->ident->toChars(), ttp->specType ? ttp->specType->toChars() : "");
#endif

        m2 = tp->matchArg(paramscope, ti->tiargs, i, parameters, dedtypes, &sparam);
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

#if DMDV2
    if (m && constraint && !flag)
    {   /* Check to see if constraint is satisfied.
         */
        makeParamNamesVisibleInConstraint(paramscope, fargs);
        Expression *e = constraint->syntaxCopy();
        Scope *sc = paramscope->push();

        /* There's a chicken-and-egg problem here. We don't know yet if this template
         * instantiation will be a local one (enclosing is set), and we won't know until
         * after selecting the correct template. Thus, function we're nesting inside
         * is not on the sc scope chain, and this can cause errors in FuncDeclaration::getLevel().
         * Workaround the problem by setting a flag to relax the checking on frame errors.
         */
        sc->flags |= SCOPEstaticif;

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

        e = e->ctfeSemantic(sc);
        e = resolveProperties(sc, e);
        if (e->op == TOKerror)
            goto Lnomatch;

        if (fd && fd->vthis)
            fd->vthis = vthissave;

        sc->pop();
        e = e->ctfeInterpret();
        if (e->isBool(TRUE))
            ;
        else if (e->isBool(FALSE))
            goto Lnomatch;
        else
        {
            e->error("constraint %s is not constant or does not evaluate to a bool", e->toChars());
        }
    }
#endif

#if LOGM
    // Print out the results
    printf("--------------------------\n");
    printf("template %s\n", toChars());
    printf("instance %s\n", ti->toChars());
    if (m)
    {
        for (size_t i = 0; i < dedtypes_dim; i++)
        {
            TemplateParameter *tp = (*parameters)[i];
            Object *oarg;

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

MATCH TemplateDeclaration::leastAsSpecialized(TemplateDeclaration *td2, Expressions *fargs)
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

        Object *p = (Object *)tp->dummyArg();
        if (p)
            (*ti.tiargs)[i] = p;
        else
            ti.tiargs->setDim(i);
    }

    // Temporary Array to hold deduced types
    //dedtypes.setDim(parameters->dim);
    dedtypes.setDim(td2->parameters->dim);

    // Attempt a type deduction
    MATCH m = td2->matchWithInstance(&ti, &dedtypes, fargs, 1);
    if (m)
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

MATCH TemplateDeclaration::deduceFunctionTemplateMatch(Loc loc, Scope *sc, Objects *tiargs,
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
    FuncDeclaration *fd = onemember->toAlias()->isFuncDeclaration();
    Parameters *fparameters;            // function parameter list
    int fvarargs;                       // function varargs
    Objects dedtypes;   // for T:T*, the dedargs is the T*, dedtypes is the T
    unsigned wildmatch = 0;
    TemplateParameters *inferparams = parameters;

    TypeFunction *tf = (TypeFunction *)fd->type;

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

    if (errors)
        return MATCHnomatch;

    // Set up scope for parameters
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = scope->parent;
    Scope *paramscope = scope->push(paramsym);
    paramscope->callsc = sc;
    paramscope->stc = 0;

    TemplateTupleParameter *tp = isVariadic();
    bool tp_is_declared = false;

#if 0
    for (size_t i = 0; i < dedargs->dim; i++)
    {
        printf("\tdedarg[%d] = ", i);
        Object *oarg = (*dedargs)[i];
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
            TemplateParameter *tp = (*parameters)[i];
            MATCH m;
            Declaration *sparam = NULL;

            m = tp->matchArg(paramscope, dedargs, i, parameters, &dedtypes, &sparam);
            //printf("\tdeduceType m = %d\n", m);
            if (m == MATCHnomatch)
                goto Lnomatch;
            if (m < matchTiargs)
                matchTiargs = m;

            sparam->semantic(paramscope);
            if (!paramscope->insert(sparam))
                goto Lnomatch;
        }
        if (n < parameters->dim)
        {
            inferparams = new TemplateParameters();
            inferparams->setDim(parameters->dim - n);
            memcpy(inferparams->tdata(),
                   parameters->tdata() + n,
                   inferparams->dim * sizeof(*inferparams->tdata()));
        }
        else
            inferparams = NULL;
    }
#if 0
    for (size_t i = 0; i < dedargs->dim; i++)
    {
        printf("\tdedarg[%d] = ", i);
        Object *oarg = (*dedargs)[i];
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

#if DMDV2
    if (tthis)
    {
        bool hasttp = false;

        // Match 'tthis' to any TemplateThisParameter's
        for (size_t i = 0; i < parameters->dim; i++)
        {   TemplateParameter *tp = (*parameters)[i];
            TemplateThisParameter *ttp = tp->isTemplateThisParameter();
            if (ttp)
            {   hasttp = true;

                Type *t = new TypeIdentifier(Loc(), ttp->ident);
                MATCH m = tthis->deduceType(paramscope, t, parameters, &dedtypes);
                if (!m)
                    goto Lnomatch;
                if (m < match)
                    match = m;          // pick worst match
            }
        }

        // Match attributes of tthis against attributes of fd
        if (fd->type && !fd->isCtorDeclaration())
        {
            unsigned mod = fd->type->mod;
            StorageClass stc = scope->stc | fd->storage_class2;
            // Propagate parent storage class (see bug 5504)
            Dsymbol *p = parent;
            while (p->isTemplateDeclaration() || p->isTemplateInstance())
                p = p->parent;
            AggregateDeclaration *ad = p->isAggregateDeclaration();
            if (ad)
                stc |= ad->storage_class;

            if (stc & (STCshared | STCsynchronized))
                mod |= MODshared;
            if (stc & STCimmutable)
                mod |= MODimmutable;
            if (stc & STCconst)
                mod |= MODconst;
            if (stc & STCwild)
                mod |= MODwild;
            // Fix mod
            if (mod & MODimmutable)
                mod = MODimmutable;
            if (mod & MODconst)
                mod &= ~STCwild;

            unsigned thismod = tthis->mod;
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
#endif

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

                tuple_dim = nfargs - argi - rem;
                t->objects.setDim(tuple_dim);
                for (size_t i = 0; i < tuple_dim; i++)
                {   Expression *farg = (*fargs)[argi + i];

                    // Check invalid arguments to detect errors early.
                    if (farg->op == TOKerror || farg->type->ty == Terror)
                        goto Lnomatch;

                    if (!(fparam->storageClass & STClazy) && farg->type->ty == Tvoid)
                        goto Lnomatch;

                    unsigned mod = farg->type->mod;
                    Type *tt;
                    MATCH m;

                    #define X(U,T)  ((U) << 4) | (T)
                    if (tid->mod & MODwild)
                    {
                        switch (X(tid->mod, mod))
                        {
                            case X(MODwild,              MODwild):
                            case X(MODwild | MODshared,  MODwild | MODshared):
                            case X(MODwild,              0):
                            case X(MODwild,              MODconst):
                            case X(MODwild,              MODimmutable):
                            case X(MODwild | MODshared,  MODshared):
                            case X(MODwild | MODshared,  MODconst | MODshared):
                                if (mod & MODwild)
                                    wildmatch |= MODwild;
                                else if (mod == 0)
                                    wildmatch |= MODmutable;
                                else
                                    wildmatch |= (mod & ~MODshared);
                                tt = farg->type->mutableOf();
                                m = MATCHconst;
                                goto Lx;

                            default:
                                break;
                        }
                    }

                    switch (X(tid->mod, mod))
                    {
                        case X(0, 0):
                        case X(0, MODconst):
                        case X(0, MODimmutable):
                        case X(0, MODshared):
                        case X(0, MODconst | MODshared):
                        case X(0, MODwild):
                        case X(0, MODwild | MODshared):
                            // foo(U:U)                T                => T
                            // foo(U:U)                const(T)         => const(T)
                            // foo(U:U)                immutable(T)     => immutable(T)
                            // foo(U:U)                shared(T)        => shared(T)
                            // foo(U:U)                const(shared(T)) => const(shared(T))
                            // foo(U:U)                wild(T)          => wild(T)
                            // foo(U:U)                wild(shared(T))  => wild(shared(T))
                            tt = farg->type;
                            m = MATCHexact;
                            break;

                        case X(MODconst, MODconst):
                        case X(MODimmutable, MODimmutable):
                        case X(MODshared, MODshared):
                        case X(MODconst | MODshared, MODconst | MODshared):
                        case X(MODwild, MODwild):
                        case X(MODwild | MODshared, MODwild | MODshared):
                            // foo(U:const(U))         const(T)         => T
                            // foo(U:immutable(U))     immutable(T)     => T
                            // foo(U:shared(U))        shared(T)        => T
                            // foo(U:const(shared(U))) const(shared(T)) => T
                            // foo(U:wild(U))          wild(T)          => T
                            // foo(U:wild(shared(U)))  wild(shared(T))  => T
                            tt = farg->type->mutableOf()->unSharedOf();
                            m = MATCHexact;
                            break;

                        case X(MODconst, 0):
                        case X(MODconst, MODimmutable):
                        case X(MODconst, MODconst | MODshared):
                        case X(MODconst | MODshared, MODimmutable):
                        case X(MODconst, MODwild):
                        case X(MODconst, MODwild | MODshared):
                            // foo(U:const(U))         T                => T
                            // foo(U:const(U))         immutable(T)     => T
                            // foo(U:const(U))         const(shared(T)) => shared(T)
                            // foo(U:const(shared(U))) immutable(T)     => T
                            // foo(U:const(U))         wild(shared(T))  => shared(T)
                            tt = farg->type->mutableOf();
                            m = MATCHconst;
                            break;

                        case X(MODshared, MODconst | MODshared):
                        case X(MODconst | MODshared, MODshared):
                        case X(MODshared, MODwild | MODshared):
                            // foo(U:shared(U))        const(shared(T)) => const(T)
                            // foo(U:const(shared(U))) shared(T)        => T
                            // foo(U:shared(U))        wild(shared(T))  => wild(T)
                            tt = farg->type->unSharedOf();
                            m = MATCHconst;
                            break;

                        case X(MODimmutable,         0):
                        case X(MODimmutable,         MODconst):
                        case X(MODimmutable,         MODshared):
                        case X(MODimmutable,         MODconst | MODshared):
                        case X(MODconst,             MODshared):
                        case X(MODshared,            0):
                        case X(MODshared,            MODconst):
                        case X(MODshared,            MODimmutable):
                        case X(MODconst | MODshared, 0):
                        case X(MODconst | MODshared, MODconst):
                        case X(MODimmutable,         MODwild):
                        case X(MODshared,            MODwild):
                        case X(MODconst | MODshared, MODwild):
                        case X(MODwild,              0):
                        case X(MODwild,              MODconst):
                        case X(MODwild,              MODimmutable):
                        case X(MODwild,              MODshared):
                        case X(MODwild,              MODconst | MODshared):
                        case X(MODwild | MODshared,  0):
                        case X(MODwild | MODshared,  MODconst):
                        case X(MODwild | MODshared,  MODimmutable):
                        case X(MODwild | MODshared,  MODshared):
                        case X(MODwild | MODshared,  MODconst | MODshared):
                        case X(MODwild | MODshared,  MODwild):
                        case X(MODimmutable,         MODwild | MODshared):
                        case X(MODconst | MODshared, MODwild | MODshared):
                        case X(MODwild,              MODwild | MODshared):
                            // foo(U:immutable(U))     T                => nomatch
                            // foo(U:immutable(U))     const(T)         => nomatch
                            // foo(U:immutable(U))     shared(T)        => nomatch
                            // foo(U:immutable(U))     const(shared(T)) => nomatch
                            // foo(U:const(U))         shared(T)        => nomatch
                            // foo(U:shared(U))        T                => nomatch
                            // foo(U:shared(U))        const(T)         => nomatch
                            // foo(U:shared(U))        immutable(T)     => nomatch
                            // foo(U:const(shared(U))) T                => nomatch
                            // foo(U:const(shared(U))) const(T)         => nomatch
                            // foo(U:immutable(U))     wild(T)          => nomatch
                            // foo(U:shared(U))        wild(T)          => nomatch
                            // foo(U:const(shared(U))) wild(T)          => nomatch
                            // foo(U:wild(U))          T                => nomatch
                            // foo(U:wild(U))          const(T)         => nomatch
                            // foo(U:wild(U))          immutable(T)     => nomatch
                            // foo(U:wild(U))          shared(T)        => nomatch
                            // foo(U:wild(U))          const(shared(T)) => nomatch
                            // foo(U:wild(shared(U)))  T                => nomatch
                            // foo(U:wild(shared(U)))  const(T)         => nomatch
                            // foo(U:wild(shared(U)))  immutable(T)     => nomatch
                            // foo(U:wild(shared(U)))  shared(T)        => nomatch
                            // foo(U:wild(shared(U)))  const(shared(T)) => nomatch
                            // foo(U:wild(shared(U)))  wild(T)          => nomatch
                            // foo(U:immutable(U))     wild(shared(T))  => nomatch
                            // foo(U:const(shared(U))) wild(shared(T))  => nomatch
                            // foo(U:wild(U))          wild(shared(T))  => nomatch
                            m = MATCHnomatch;
                            break;

                        default:
                            assert(0);
                    }
                    #undef X

                Lx:
                    if (m == MATCHnomatch)
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

#if DMDV2
            /* Allow expressions that have CT-known boundaries and type [] to match with [dim]
             */
            Type *taai;
            if ( argtype->ty == Tarray &&
                (prmtype->ty == Tsarray ||
                 prmtype->ty == Taarray && (taai = ((TypeAArray *)prmtype)->index)->ty == Tident &&
                                           ((TypeIdentifier *)taai)->idents.dim == 0))
            {
                if (farg->op == TOKstring)
                {   StringExp *se = (StringExp *)farg;
                    argtype = new TypeSArray(argtype->nextOf(), new IntegerExp(se->loc, se->len, Type::tindex));
                    argtype = argtype->semantic(se->loc, NULL);
                }
                else if (farg->op == TOKslice)
                {   SliceExp *se = (SliceExp *)farg;
                    Type *tsa = se->toStaticArrayType();
                    if (tsa)
                        argtype = tsa;
                }
                else if (farg->op == TOKarrayliteral)
                {   ArrayLiteralExp *ae = (ArrayLiteralExp *)farg;
                    argtype = new TypeSArray(argtype->nextOf(), new IntegerExp(ae->loc, ae->elements->dim, Type::tindex));
                    argtype = argtype->semantic(ae->loc, NULL);
                }
            }

            /* Allow implicit function literals to delegate conversion
             */
            if (farg->op == TOKfunction)
            {   FuncExp *fe = (FuncExp *)farg;
                Type *tp = prmtype;
                Expression *e = fe->inferType(tp, 1, paramscope, inferparams);
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
#endif

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
            if (!m)
                m = farg->implicitConvTo(prmtype);

            /* If no match, see if there's a conversion to a delegate
             */
            if (!m)
            {   Type *tbp = prmtype->toBasetype();
                Type *tba = farg->type->toBasetype();
                AggregateDeclaration *ad;
                if (tbp->ty == Tdelegate)
                {
                    TypeDelegate *td = (TypeDelegate *)prmtype->toBasetype();
                    TypeFunction *tf = (TypeFunction *)td->next;

                    if (!tf->varargs && Parameter::dim(tf->parameters) == 0)
                    {
                        m = farg->type->deduceType(paramscope, tf->next, parameters, &dedtypes);
                        if (!m && tf->next->toBasetype()->ty == Tvoid)
                            m = MATCHconvert;
                    }
                    //printf("\tm2 = %d\n", m);
                }
                else if (tba->ty == Tclass)
                {
                    ad = ((TypeClass *)tba)->sym;
                    goto Lad;
                }
                else if (tba->ty == Tstruct)
                {
                    ad = ((TypeStruct *)tba)->sym;
            Lad:
                    if (ad->aliasthis)
                    {   /* If a semantic error occurs while doing alias this,
                         * eg purity(bug 7295), just regard it as not a match.
                         */
                        unsigned olderrors = global.startGagging();
                        Expression *e = resolveAliasThis(sc, farg);
                        if (!global.endGagging(olderrors))
                        {   farg = e;
                            goto Lretry;
                        }
                    }
                }
            }

            if (m && (fparam->storageClass & (STCref | STCauto)) == STCref)
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
            if (m && (fparam->storageClass & STCout))
            {   if (!farg->isLvalue())
                    goto Lnomatch;
            }
            if (!m && (fparam->storageClass & STClazy) && prmtype->ty == Tvoid &&
                    farg->type->ty != Tvoid)
                m = MATCHconvert;

            if (m)
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
                            if (!m)
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
                        Type *tp = tb->nextOf();

                        Expression *e = fe->inferType(tp, 1, paramscope, inferparams);
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
        Object *oarg = (*dedargs)[i];
        Object *oded = dedtypes[i];
        //printf("1dedargs[%d] = %p, dedtypes[%d] = %p\n", i, oarg, i, oded);
        //if (oarg) printf("oarg: %s\n", oarg->toChars());
        //if (oded) printf("oded: %s\n", oded->toChars());
        if (!oarg)
        {
            if (oded)
            {
                if (tparam->specialization())
                {   /* The specialization can work as long as afterwards
                     * the oded == oarg
                     */
                    (*dedargs)[i] = oded;
                    MATCH m2 = tparam->matchArg(paramscope, dedargs, i, parameters, &dedtypes, NULL);
                    //printf("m2 = %d\n", m2);
                    if (!m2)
                        goto Lnomatch;
                    if (m2 < match)
                        match = m2;             // pick worst match
                    if (dedtypes[i] != oded)
                        error("specialization not allowed for deduced parameter %s", tparam->ident->toChars());
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
                        oded = (Object *)new Tuple();
                    }
                    else
                        goto Lnomatch;
                }
            }
            oded = declareParameter(paramscope, tparam, oded);
            (*dedargs)[i] = oded;
        }
    }

#if DMDV2
    if (constraint)
    {   /* Check to see if constraint is satisfied.
         * Most of this code appears twice; this is a good candidate for refactoring.
         */
        makeParamNamesVisibleInConstraint(paramscope, fargs);
        Expression *e = constraint->syntaxCopy();
        paramscope->flags |= SCOPEstaticif;

        /* Detect recursive attempts to instantiate this template declaration,
         * Bugzilla 4072
         *  void foo(T)(T x) if (is(typeof(foo(x)))) { }
         *  static assert(!is(typeof(foo(7))));
         * Recursive attempts are regarded as a constraint failure.
         */
        int nmatches = 0;
        for (Previous *p = previous; p; p = p->prev)
        {
            if (arrayObjectMatch(p->dedargs, dedargs, this, sc))
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

        e = e->ctfeSemantic(paramscope);
        e = resolveProperties(sc, e);

        if (fd && fd->vthis)
            fd->vthis = vthissave;

        previous = pr.prev;             // unlink from threaded list

        if (nerrors != global.errors)   // if any errors from evaluating the constraint, no match
            goto Lnomatch;
        if (e->op == TOKerror)
            goto Lnomatch;

        e = e->ctfeInterpret();
        if (e->isBool(TRUE))
            ;
        else if (e->isBool(FALSE))
            goto Lnomatch;
        else
        {
            e->error("constraint %s is not constant or does not evaluate to a bool", e->toChars());
        }
    }
#endif

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

Object *TemplateDeclaration::declareParameter(Scope *sc, TemplateParameter *tp, Object *o)
{
    //printf("TemplateDeclaration::declareParameter('%s', o = %p)\n", tp->ident->toChars(), o);

    Type *targ = isType(o);
    Expression *ea = isExpression(o);
    Dsymbol *sa = isDsymbol(o);
    Tuple *va = isTuple(o);

    Dsymbol *s;
    VarDeclaration *v = NULL;

    // See if tp->ident already exists with a matching definition
    Dsymbol *scopesym;
    s = sc->search(loc, tp->ident, &scopesym);
    if (s && scopesym == sc->scopesym)
    {
        TupleDeclaration *td = s->isTupleDeclaration();
        if (va && td)
        {   Tuple tup;
            tup.objects = *td->objects;
            if (match(va, &tup, this, sc))
            {
                return o;
            }
        }
    }
    if (ea && ea->op == TOKtype)
        targ = ea->type;
    else if (ea && ea->op == TOKimport)
        sa = ((ScopeExp *)ea)->sds;
    else if (ea && (ea->op == TOKthis || ea->op == TOKsuper))
        sa = ((ThisExp *)ea)->var;

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
    else if (ea && ea->op == TOKfunction)
    {
        if (((FuncExp *)ea)->td)
            sa = ((FuncExp *)ea)->td;
        else
            sa = ((FuncExp *)ea)->fd;
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
        return (Object *)v->init->toExpression();
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

int TemplateDeclaration::isOverloadable()
{
    return 1;
}

/*************************************************
 * Given function arguments, figure out which template function
 * to expand, and return that function.
 * If no match, give error message and return NULL.
 * Input:
 *      loc             instantiation location
 *      sc              instantiation scope
 *      tiargs          initial list of template arguments
 *      tthis           if !NULL, the 'this' pointer argument
 *      fargs           arguments to function
 *      flags           1: do not issue error message on no match, just return NULL
 */

FuncDeclaration *TemplateDeclaration::deduceFunctionTemplate(Loc loc, Scope *sc,
        Objects *tiargs, Type *tthis, Expressions *fargs, int flags)
{
    MATCH m_best = MATCHnomatch;
    MATCH m_best2 = MATCHnomatch;
    TemplateDeclaration *td_ambig = NULL;
    TemplateDeclaration *td_best = NULL;
    Objects *tdargs = new Objects();
    TemplateInstance *ti;
    FuncDeclaration *fd_best;
    Type *tthis_best = NULL;

#if 0
    printf("TemplateDeclaration::deduceFunctionTemplate() %s\n", toChars());
    printf("    tiargs:\n");
    if (tiargs)
    {   for (size_t i = 0; i < tiargs->dim; i++)
        {   Object *arg = (*tiargs)[i];
            printf("\t%s\n", arg->toChars());
        }
    }
    printf("    fargs:\n");
    for (size_t i = 0; i < (fargs ? fargs->dim : 0); i++)
    {   Expression *arg = (*fargs)[i];
        printf("\t%s %s\n", arg->type->toChars(), arg->toChars());
        //printf("\tty = %d\n", arg->type->ty);
    }
    printf("stc = %llx\n", scope->stc);
#endif

    for (TemplateDeclaration *td = this; td; td = td->overnext)
    {
        if (!td->semanticRun)
        {
            error("forward reference to template %s", td->toChars());
            goto Lerror;
        }
        if (!td->onemember || !td->onemember->toAlias()->isFuncDeclaration())
        {
            if (!tiargs)
                tiargs = new Objects();
            TemplateInstance *ti = new TemplateInstance(loc, td, tiargs);

            Objects dedtypes;
            dedtypes.setDim(td->parameters->dim);
            assert(td->semanticRun);
            MATCH m2 = td->matchWithInstance(ti, &dedtypes, fargs, 0);
            //printf("matchWithInstance = %d\n", m2);
            if (!m2 || m2 < m_best2)        // no match or less match
                continue;

            ti->semantic(sc, fargs);
            if (!ti->inst)                  // if template failed to expand
                continue;

            Dsymbol *s = ti->inst->toAlias();
            FuncDeclaration *fd = s->isFuncDeclaration();
            if (!fd)
            {
                if (!(flags & 1))
                    td->error("is not a function template");
                goto Lerror;
            }
            fd = resolveFuncCall(loc, sc, fd, NULL, tthis, fargs, flags);
            if (!fd)
                continue;

            TypeFunction *tf = (TypeFunction *)fd->type;
            MATCH m = (MATCH) tf->callMatch(fd->needThis() && !fd->isCtorDeclaration() ? tthis : NULL, fargs);
            if (m < m_best)
                continue;

            // td is the new best match
            td_ambig = NULL;
            assert(td->scope);
            td_best = td;
            fd_best = fd;
            m_best = m;
            m_best2 = m2;
            tdargs->setDim(dedtypes.dim);
            memcpy(tdargs->tdata(), dedtypes.tdata(), tdargs->dim * sizeof(void *));
            continue;
        }

        MATCH m, m2;
        Objects dedargs;
        FuncDeclaration *fd = NULL;

        m = td->deduceFunctionTemplateMatch(loc, sc, tiargs, tthis, fargs, &dedargs);
        m2 = (MATCH)(m >> 4);
        m = (MATCH)(m & 0xF);
        //printf("deduceFunctionTemplateMatch = %d, m2 = %d\n", m, m2);
        if (!m)                 // if no match
            continue;

        Type *tthis_fd = NULL;
        if (td->onemember->toAlias()->isFuncDeclaration()->isCtorDeclaration())
        {
            // Constructor call requires additional check.
            // For that, do instantiate in early stage.
            fd = td->doHeaderInstantiation(sc, &dedargs, tthis, fargs);
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

        if (m2 < m_best2)
            goto Ltd_best;
        if (m2 > m_best2)
            goto Ltd;

        if (m < m_best)
            goto Ltd_best;
        if (m > m_best)
            goto Ltd;

        {
        // Disambiguate by picking the most specialized TemplateDeclaration
        MATCH c1 = td->leastAsSpecialized(td_best, fargs);
        MATCH c2 = td_best->leastAsSpecialized(td, fargs);
        //printf("1: c1 = %d, c2 = %d\n", c1, c2);

        if (c1 > c2)
            goto Ltd;
        else if (c1 < c2)
            goto Ltd_best;
        }

        if (!fd_best)
        {
            fd_best = td_best->doHeaderInstantiation(sc, tdargs, tthis, fargs);
            if (!fd_best)
                goto Lerror;
            tthis_best = fd_best->needThis() ? tthis : NULL;
        }
        if (!fd)
        {
            fd = td->doHeaderInstantiation(sc, &dedargs, tthis, fargs);
            if (!fd)
                goto Lerror;
            tthis_fd = fd->needThis() ? tthis : NULL;
        }
        assert(fd && fd_best);

        {
        // Disambiguate by tf->callMatch
        TypeFunction *tf1 = (TypeFunction *)fd->type;
        TypeFunction *tf2 = (TypeFunction *)fd_best->type;
        MATCH c1 = tf1->callMatch(tthis_fd, fargs);
        MATCH c2 = tf2->callMatch(tthis_best, fargs);
        //printf("2: c1 = %d, c2 = %d\n", c1, c2);

        if (c1 > c2)
            goto Ltd;
        if (c1 < c2)
            goto Ltd_best;
        }

        {
        // Disambiguate by picking the most specialized FunctionDeclaration
        MATCH c1 = fd->leastAsSpecialized(fd_best);
        MATCH c2 = fd_best->leastAsSpecialized(fd);
        //printf("3: c1 = %d, c2 = %d\n", c1, c2);

        if (c1 > c2)
            goto Ltd;
        if (c1 < c2)
            goto Ltd_best;
        }

      Lambig:           // td_best and td are ambiguous
        td_ambig = td;
        continue;

      Ltd_best:         // td_best is the best match so far
        td_ambig = NULL;
        continue;

      Ltd:              // td is the new best match
        td_ambig = NULL;
        assert(td->scope);
        td_best = td;
        fd_best = fd;
        tthis_best = tthis_fd;
        m_best = m;
        m_best2 = m2;
        tdargs->setDim(dedargs.dim);
        memcpy(tdargs->tdata(), dedargs.tdata(), tdargs->dim * sizeof(void *));
        continue;
    }
    if (!td_best)
    {
        if (!(flags & 1))
        {
            ::error(loc, "%s %s.%s does not match any function template declaration. Candidates are:",
                    kind(), parent->toPrettyChars(), ident->toChars());

            // Display candidate template functions
            int numToDisplay = 5; // sensible number to display
            for (TemplateDeclaration *td = this; td; td = td->overnext)
            {
                ::errorSupplemental(td->loc, "%s", td->toPrettyChars());
                if (!global.params.verbose && --numToDisplay == 0)
                {
                    // Too many overloads to sensibly display.
                    // Just show count of remaining overloads.
                    int remaining = 0;
                    for (; td; td = td->overnext)
                        ++remaining;
                    if (remaining > 0)
                        ::errorSupplemental(loc, "... (%d more, -v to show) ...", remaining);
                    break;
                }
            }
        }
        goto Lerror;
    }
    if (td_ambig)
    {
        ::error(loc, "%s %s.%s matches more than one template declaration, %s(%d):%s and %s(%d):%s",
                kind(), parent->toPrettyChars(), ident->toChars(),
                td_best->loc.filename,  td_best->loc.linnum,  td_best->toChars(),
                td_ambig->loc.filename, td_ambig->loc.linnum, td_ambig->toChars());
    }

    if (!td_best->onemember || !td_best->onemember->toAlias()->isFuncDeclaration())
        return fd_best;

    /* The best match is td_best with arguments tdargs.
     * Now instantiate the template.
     */
    assert(td_best->scope);
    ti = new TemplateInstance(loc, td_best, tdargs);
    ti->semantic(sc, fargs);
    fd_best = ti->toAlias()->isFuncDeclaration();
    if (!fd_best)
        goto Lerror;
    if (!((TypeFunction*)fd_best->type)->callMatch(fd_best->needThis() && !fd_best->isCtorDeclaration() ? tthis : NULL, fargs))
        goto Lerror;

    if (FuncLiteralDeclaration *fld = fd_best->isFuncLiteralDeclaration())
    {
        // Inside template constraint, nested reference check doesn't work correctly.
        if (!(sc->flags & SCOPEstaticif) && fld->tok == TOKreserved)
        {   // change to non-nested
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
    {   TypeFunction *tf = (TypeFunction *)fd_best->type;
        assert(tf->ty == Tfunction);
        if (tf->next && !fd_best->inferRetType)
        {
            fd_best->type = tf->semantic(loc, sc);
        }
    }

    if (!(flags & 1))
        fd_best->functionSemantic();

    return fd_best;

  Lerror:
#if DMDV2
    if (!(flags & 1))
#endif
    {
        HdrGenState hgs;

        OutBuffer bufa;
        Objects *args = tiargs;
        if (args)
        {   for (size_t i = 0; i < args->dim; i++)
            {
                if (i)
                    bufa.writestring(", ");
                Object *oarg = (*args)[i];
                ObjectToCBuffer(&bufa, &hgs, oarg);
            }
        }

        OutBuffer buf;
        argExpTypesToCBuffer(&buf, fargs, &hgs);
        if (this->overnext)
            ::error(this->loc, "%s %s.%s cannot deduce template function from argument types !(%s)(%s)",
                    kind(), parent->toPrettyChars(), ident->toChars(),
                    bufa.toChars(), buf.toChars());
        else
            error(loc, "cannot deduce template function from argument types !(%s)(%s)",
                  bufa.toChars(), buf.toChars());
    }
    return NULL;
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
        printf("\ttdargs[%d] = %s\n", i, ((Object *)tdargs->data[i])->toChars());
#endif

    assert(scope);
    TemplateInstance *ti = new TemplateInstance(loc, this, tdargs);
    ti->tinst = sc->tinst;
    {
        ti->tdtypes.setDim(ti->tempdecl->parameters->dim);
        if (!ti->tempdecl->matchWithInstance(ti, &ti->tdtypes, fargs, 2))
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

    Scope *scope = this->scope;

    ti->argsym = new ScopeDsymbol();
    ti->argsym->parent = scope->parent;
    scope = scope->push(ti->argsym);

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
        Scope *sc = sc2;
        sc = sc->push();

        if (hasttp)
            fd->type = fd->type->addMod(tthis->mod);
        //printf("tthis = %s, fdtype = %s\n", tthis->toChars(), fd->type->toChars());
        if (fd->isCtorDeclaration())
        {
            sc->flags |= SCOPEctor;

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
                tret = tret->addStorageClass(fd->storage_class | sc->stc);
                tret = tret->addMod(fd->type->mod);
            }
            ((TypeFunction *)fd->type)->next = tret;
            if (ad && ad->isStructDeclaration())
                ((TypeFunction *)fd->type)->isref = 1;
            //printf("fd->type = %s\n", fd->type->toChars());
        }
        fd->type = fd->type->addSTC(sc->stc);
        fd->type = fd->type->semantic(fd->loc, sc);
        sc = sc->pop();
    }
    //printf("\t[%s] fd->type = %s, mod = %x, ", loc.toChars(), fd->type->toChars(), fd->type->mod);
    //printf("fd->needThis() = %d\n", fd->needThis());

    sc2->pop();
    scope->pop();

    return fd;
}

bool TemplateDeclaration::hasStaticCtorOrDtor()
{
    return FALSE;               // don't scan uninstantiated templates
}

void TemplateDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
#if 0 // Should handle template functions for doc generation
    if (onemember && onemember->isFuncDeclaration())
        buf->writestring("foo ");
#endif
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
#if DMDV2
    if (constraint)
    {   buf->writestring(" if (");
        constraint->toCBuffer(buf, hgs);
        buf->writeByte(')');
    }
#endif

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
{   OutBuffer buf;
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
    {   /* Bugzilla 9406:
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

#if DMDV2
    if (constraint)
    {   buf.writestring(" if (");
        constraint->toCBuffer(&buf, &hgs);
        buf.writeByte(')');
    }
#endif
    buf.writeByte(0);
    return (char *)buf.extractData();
}

PROT TemplateDeclaration::prot()
{
    return protection;
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
        if (tident->idents.dim == 0)
        {
            return templateIdentifierLookup(tident->ident, parameters);
        }
    }
    return IDX_NOTFOUND;
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
        Objects *dedtypes, unsigned *wildmatch)
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
            return deduceType(sc, tparam, parameters, dedtypes, wildmatch);
        }

        TemplateParameter *tp = (*parameters)[i];

        // Found the corresponding parameter tp
        if (!tp->isTemplateTypeParameter())
            goto Lnomatch;
        Type *tt = this;
        Type *at = (Type *)(*dedtypes)[i];

        // 7*7 == 49 cases

        #define X(U,T)  ((U) << 4) | (T)

        if (wildmatch && (tparam->mod & MODwild))
        {
            switch (X(tparam->mod, mod))
            {
                case X(MODwild,              0):
                case X(MODwild,              MODshared):
                case X(MODwild,              MODconst):
                case X(MODwild,              MODconst | MODshared):
                case X(MODwild,              MODimmutable):
                case X(MODwild,              MODwild):
                case X(MODwild,              MODwild | MODshared):
                case X(MODwild | MODshared,  MODshared):
                case X(MODwild | MODshared,  MODconst | MODshared):
                case X(MODwild | MODshared,  MODimmutable):
                case X(MODwild | MODshared,  MODwild | MODshared):

                    if (!at)
                    {
                        if (mod & MODwild)
                            *wildmatch |= MODwild;
                        else if (mod == 0)
                            *wildmatch |= MODmutable;
                        else
                            *wildmatch |= (mod & ~MODshared);
                        tt = mutableOf()->substWildTo(MODmutable);
                        (*dedtypes)[i] = tt;
                        goto Lconst;
                    }

                    //printf("\t> tt = %s, at = %s\n", tt->toChars(), at->toChars());
                    //printf("\t> tt->implicitConvTo(at->constOf()) = %d\n", tt->implicitConvTo(at->constOf()));
                    //printf("\t> at->implicitConvTo(tt->constOf()) = %d\n", at->implicitConvTo(tt->constOf()));

                    if (tt->equals(at))
                    {
                        goto Lconst;
                    }
                    else if (tt->implicitConvTo(at->constOf()))
                    {
                        (*dedtypes)[i] = at->constOf()->mutableOf();
                        *wildmatch |= MODconst;
                        goto Lconst;
                    }
                    else if (at->implicitConvTo(tt->constOf()))
                    {
                        (*dedtypes)[i] = tt->constOf()->mutableOf();
                        *wildmatch |= MODconst;
                        goto Lconst;
                    }
                    goto Lnomatch;

                default:
                    break;
            }
        }

        switch (X(tparam->mod, mod))
        {
            case X(0, 0):
            case X(0, MODconst):
            case X(0, MODimmutable):
            case X(0, MODshared):
            case X(0, MODconst | MODshared):
            case X(0, MODwild):
            case X(0, MODwild | MODshared):
                // foo(U:U)                T                => T
                // foo(U:U)                const(T)         => const(T)
                // foo(U:U)                immutable(T)     => immutable(T)
                // foo(U:U)                shared(T)        => shared(T)
                // foo(U:U)                const(shared(T)) => const(shared(T))
                // foo(U:U)                wild(T)          => wild(T)
                // foo(U:U)                wild(shared(T))  => wild(shared(T))
                if (!at)
                {   (*dedtypes)[i] = tt;
                    goto Lexact;
                }
                break;

            case X(MODconst,             MODconst):
            case X(MODimmutable,         MODimmutable):
            case X(MODshared,            MODshared):
            case X(MODconst | MODshared, MODconst | MODshared):
            case X(MODwild,              MODwild):
            case X(MODwild | MODshared,  MODwild | MODshared):
                // foo(U:const(U))         const(T)         => T
                // foo(U:immutable(U))     immutable(T)     => T
                // foo(U:shared(U))        shared(T)        => T
                // foo(U:const(shared(U))) const(shared(T)) => T
                // foo(U:wild(U))          wild(T)          => T
                // foo(U:wild(shared(U)))  wild(shared(T))  => T
                tt = mutableOf()->unSharedOf();
                if (!at)
                {   (*dedtypes)[i] = tt;
                    goto Lexact;
                }
                break;

            case X(MODconst,             0):
            case X(MODconst,             MODimmutable):
            case X(MODconst,             MODconst | MODshared):
            case X(MODconst | MODshared, MODimmutable):
            case X(MODconst,             MODwild):
            case X(MODconst,             MODwild | MODshared):
                // foo(U:const(U))         T                => T
                // foo(U:const(U))         immutable(T)     => T
                // foo(U:const(U))         const(shared(T)) => shared(T)
                // foo(U:const(shared(U))) immutable(T)     => T
                // foo(U:const(U))         wild(shared(T))  => shared(T)
                tt = mutableOf();
                if (!at)
                {   (*dedtypes)[i] = tt;
                    goto Lconst;
                }
                break;

            case X(MODshared,            MODconst | MODshared):
            case X(MODconst | MODshared, MODshared):
            case X(MODshared,            MODwild | MODshared):
                // foo(U:shared(U))        const(shared(T)) => const(T)
                // foo(U:const(shared(U))) shared(T)        => T
                // foo(U:shared(U))        wild(shared(T))  => wild(T)
                tt = unSharedOf();
                if (!at)
                {   (*dedtypes)[i] = tt;
                    goto Lconst;
                }
                break;

            case X(MODconst,             MODshared):
                // foo(U:const(U))         shared(T)        => shared(T)
                if (!at)
                {   (*dedtypes)[i] = tt;
                    goto Lconst;
                }
                break;

            case X(MODimmutable,         0):
            case X(MODimmutable,         MODconst):
            case X(MODimmutable,         MODshared):
            case X(MODimmutable,         MODconst | MODshared):
            case X(MODshared,            0):
            case X(MODshared,            MODconst):
            case X(MODshared,            MODimmutable):
            case X(MODconst | MODshared, 0):
            case X(MODconst | MODshared, MODconst):
            case X(MODimmutable,         MODwild):
            case X(MODshared,            MODwild):
            case X(MODconst | MODshared, MODwild):
            case X(MODwild,              0):
            case X(MODwild,              MODconst):
            case X(MODwild,              MODimmutable):
            case X(MODwild,              MODshared):
            case X(MODwild,              MODconst | MODshared):
            case X(MODwild | MODshared,  0):
            case X(MODwild | MODshared,  MODconst):
            case X(MODwild | MODshared,  MODimmutable):
            case X(MODwild | MODshared,  MODshared):
            case X(MODwild | MODshared,  MODconst | MODshared):
            case X(MODwild | MODshared,  MODwild):
            case X(MODimmutable,         MODwild | MODshared):
            case X(MODconst | MODshared, MODwild | MODshared):
            case X(MODwild,              MODwild | MODshared):
                // foo(U:immutable(U))     T                => nomatch
                // foo(U:immutable(U))     const(T)         => nomatch
                // foo(U:immutable(U))     shared(T)        => nomatch
                // foo(U:immutable(U))     const(shared(T)) => nomatch
                // foo(U:const(U))         shared(T)        => nomatch
                // foo(U:shared(U))        T                => nomatch
                // foo(U:shared(U))        const(T)         => nomatch
                // foo(U:shared(U))        immutable(T)     => nomatch
                // foo(U:const(shared(U))) T                => nomatch
                // foo(U:const(shared(U))) const(T)         => nomatch
                // foo(U:immutable(U))     wild(T)          => nomatch
                // foo(U:shared(U))        wild(T)          => nomatch
                // foo(U:const(shared(U))) wild(T)          => nomatch
                // foo(U:wild(U))          T                => nomatch
                // foo(U:wild(U))          const(T)         => nomatch
                // foo(U:wild(U))          immutable(T)     => nomatch
                // foo(U:wild(U))          shared(T)        => nomatch
                // foo(U:wild(U))          const(shared(T)) => nomatch
                // foo(U:wild(shared(U)))  T                => nomatch
                // foo(U:wild(shared(U)))  const(T)         => nomatch
                // foo(U:wild(shared(U)))  immutable(T)     => nomatch
                // foo(U:wild(shared(U)))  shared(T)        => nomatch
                // foo(U:wild(shared(U)))  const(shared(T)) => nomatch
                // foo(U:wild(shared(U)))  wild(T)          => nomatch
                // foo(U:immutable(U))     wild(shared(T))  => nomatch
                // foo(U:const(shared(U))) wild(shared(T))  => nomatch
                // foo(U:wild(U))          wild(shared(T))  => nomatch
                //if (!at)
                    goto Lnomatch;
                break;

            default:
                assert(0);
        }
        #undef X

        if (tt->equals(at))
            goto Lexact;
        else if (tt->ty == Tclass && at->ty == Tclass)
        {
            return tt->implicitConvTo(at);
        }
        else if (tt->ty == Tsarray && at->ty == Tarray &&
            tt->nextOf()->implicitConvTo(at->nextOf()) >= MATCHconst)
        {
            goto Lexact;
        }
        else
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
#if DMDV2
        // Can't instantiate AssociativeArray!() without a scope
        if (tparam->ty == Taarray && !((TypeAArray*)tparam)->sc)
            ((TypeAArray*)tparam)->sc = sc;

        MATCH m = implicitConvTo(tparam);
        if (m == MATCHnomatch)
        {
            Type *at = aliasthisOf();
            if (at)
                m = at->deduceType(sc, tparam, parameters, dedtypes, wildmatch);
        }
        return m;
#else
        return implicitConvTo(tparam);
#endif
    }

    if (nextOf())
        return nextOf()->deduceType(sc, tparam->nextOf(), parameters, dedtypes, wildmatch);

Lexact:
    return MATCHexact;

Lnomatch:
    return MATCHnomatch;

#if DMDV2
Lconst:
    return MATCHconst;
#endif
}

#if DMDV2
MATCH TypeVector::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
        Objects *dedtypes, unsigned *wildmatch)
{
#if 0
    printf("TypeVector::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif
    if (tparam->ty == Tvector)
    {   TypeVector *tp = (TypeVector *)tparam;
        return basetype->deduceType(sc, tp->basetype, parameters, dedtypes, wildmatch);
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
}
#endif

#if DMDV2
MATCH TypeDArray::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
        Objects *dedtypes, unsigned *wildmatch)
{
#if 0
    printf("TypeDArray::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
}
#endif

MATCH TypeSArray::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
        Objects *dedtypes, unsigned *wildmatch)
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
        {   MATCH m;

            m = next->deduceType(sc, tparam->nextOf(), parameters, dedtypes, wildmatch);
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
            return next->deduceType(sc, tparam->nextOf(), parameters, dedtypes, wildmatch);
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);

  Lnomatch:
    return MATCHnomatch;
}

MATCH TypeAArray::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch)
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
        if (!index->deduceType(sc, tp->index, parameters, dedtypes, wildmatch))
        {
            return MATCHnomatch;
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
}

MATCH TypeFunction::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch)
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
            Object *o = (*dedtypes)[tupi];
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
                !a->type->deduceType(sc, ap->type, parameters, dedtypes, wildmatch))
                return MATCHnomatch;
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
}

MATCH TypeIdentifier::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch)
{
    // Extra check
    if (tparam && tparam->ty == Tident)
    {
        TypeIdentifier *tp = (TypeIdentifier *)tparam;

        for (size_t i = 0; i < idents.dim; i++)
        {
            Object *id1 = idents[i];
            Object *id2 = tp->idents[i];

            if (!id1->equals(id2))
                return MATCHnomatch;
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
}

MATCH TypeInstance::deduceType(Scope *sc,
        Type *tparam, TemplateParameters *parameters,
        Objects *dedtypes, unsigned *wildmatch)
{
#if 0
    printf("TypeInstance::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif

    // Extra check
    if (tparam && tparam->ty == Tinstance)
    {
        TypeInstance *tp = (TypeInstance *)tparam;

        //printf("tempinst->tempdecl = %p\n", tempinst->tempdecl);
        //printf("tp->tempinst->tempdecl = %p\n", tp->tempinst->tempdecl);
        if (!tp->tempinst->tempdecl)
        {   //printf("tp->tempinst->name = '%s'\n", tp->tempinst->name->toChars());
            if (!tp->tempinst->name->equals(tempinst->name))
            {
                /* Handle case of:
                 *  template Foo(T : sa!(T), alias sa)
                 */
                size_t i = templateIdentifierLookup(tp->tempinst->name, parameters);
                if (i == IDX_NOTFOUND)
                {   /* Didn't find it as a parameter identifier. Try looking
                     * it up and seeing if is an alias. See Bugzilla 1454
                     */
                    TypeIdentifier *tid = new TypeIdentifier(Loc(), tp->tempinst->name);
                    Type *t;
                    Expression *e;
                    Dsymbol *s;
                    tid->resolve(Loc(), sc, &e, &t, &s);
                    if (t)
                    {
                        s = t->toDsymbol(sc);
                        if (s)
                        {   TemplateInstance *ti = s->parent->isTemplateInstance();
                            s = ti ? ti->tempdecl : NULL;
                        }
                    }
                    if (s)
                    {
                        s = s->toAlias();
                        TemplateDeclaration *td = s->isTemplateDeclaration();
                        if (td && td == tempinst->tempdecl)
                            goto L2;
                    }
                    goto Lnomatch;
                }
                TemplateParameter *tpx = (*parameters)[i];
                if (!tpx->matchArg(sc, tempinst->tempdecl, i, parameters, dedtypes, NULL))
                    goto Lnomatch;
            }
        }
        else if (tempinst->tempdecl != tp->tempinst->tempdecl)
            goto Lnomatch;

      L2:

        for (size_t i = 0; 1; i++)
        {
            //printf("\ttest: tempinst->tiargs[%d]\n", i);
            Object *o1 = NULL;
            if (i < tempinst->tiargs->dim)
                o1 = (*tempinst->tiargs)[i];
            else if (i < tempinst->tdtypes.dim && i < tp->tempinst->tiargs->dim)
                // Pick up default arg
                o1 = tempinst->tdtypes[i];
            else if (i >= tp->tempinst->tiargs->dim)
                break;

            if (i >= tp->tempinst->tiargs->dim)
                goto Lnomatch;

            Object *o2 = (*tp->tempinst->tiargs)[i];
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
                size_t vtdim = (tempinst->tempdecl->isVariadic()
                                ? tempinst->tiargs->dim : tempinst->tdtypes.dim) - i;
                vt->objects.setDim(vtdim);
                for (size_t k = 0; k < vtdim; k++)
                {
                    Object *o;
                    if (k < tempinst->tiargs->dim)
                        o = (*tempinst->tiargs)[i + k];
                    else    // Pick up default arg
                        o = tempinst->tdtypes[i + k];
                    vt->objects[k] = o;
                }

                Tuple *v = (Tuple *)(*dedtypes)[j];
                if (v)
                {
                    if (!match(v, vt, tempinst->tempdecl, sc))
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
                if (!t1->deduceType(sc, t2, parameters, dedtypes, wildmatch))
                    goto Lnomatch;
            }
            else if (e1 && e2)
            {
            Le:
                e1 = e1->ctfeInterpret();
                e2 = e2->ctfeInterpret();

                //printf("e1 = %s, type = %s %d\n", e1->toChars(), e1->type->toChars(), e1->type->ty);
                //printf("e2 = %s, type = %s %d\n", e2->toChars(), e2->type->toChars(), e2->type->ty);
                if (!e1->equals(e2))
                {   if (e2->op == TOKvar)
                    {
                        /*
                         * (T:Number!(e2), int e2)
                         */
                        j = templateIdentifierLookup(((VarExp *)e2)->var->ident, parameters);
                        goto L1;
                    }
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
                    t2->resolve(loc, sc, &e2, &t2, &s2);
                    if (e2)
                        goto Le;
                    goto Lnomatch;
                }
                TemplateParameter *tp = (*parameters)[j];
                if (!tp->matchArg(sc, e1, j, parameters, dedtypes, NULL))
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
                    t2->resolve(loc, sc, &e2, &t2, &s2);
                    if (s2)
                        goto Ls;
                    goto Lnomatch;
                }
                TemplateParameter *tp = (*parameters)[j];
                if (!tp->matchArg(sc, s1, j, parameters, dedtypes, NULL))
                    goto Lnomatch;
            }
            else
                goto Lnomatch;
        }
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);

Lnomatch:
    //printf("no match\n");
    return MATCHnomatch;
}

MATCH TypeStruct::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch)
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
            return t->deduceType(sc, tparam, parameters, dedtypes, wildmatch);
        }

        /* Match things like:
         *  S!(T).foo
         */
        TypeInstance *tpi = (TypeInstance *)tparam;
        if (tpi->idents.dim)
        {   Object *id = tpi->idents[tpi->idents.dim - 1];
            if (id->dyncast() == DYNCAST_IDENTIFIER && sym->ident->equals((Identifier *)id))
            {
                Type *tparent = sym->parent->getType();
                if (tparent)
                {
                    /* Slice off the .foo in S!(T).foo
                     */
                    tpi->idents.dim--;
                    MATCH m = tparent->deduceType(sc, tpi, parameters, dedtypes, wildmatch);
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
        return implicitConvTo(tp);
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
}

MATCH TypeEnum::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch)
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
        return tb->deduceType(sc, tparam, parameters, dedtypes, wildmatch);
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
}

MATCH TypeTypedef::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch)
{
    // Extra check
    if (tparam && tparam->ty == Ttypedef)
    {
        TypeTypedef *tp = (TypeTypedef *)tparam;

        if (sym != tp->sym)
            return MATCHnomatch;
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
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
        if (m != MATCHnomatch)
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

MATCH TypeClass::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch)
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
            MATCH m = t->deduceType(sc, tparam, parameters, dedtypes, wildmatch);
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
        {   Object *id = tpi->idents[tpi->idents.dim - 1];
            if (id->dyncast() == DYNCAST_IDENTIFIER && sym->ident->equals((Identifier *)id))
            {
                Type *tparent = sym->parent->getType();
                if (tparent)
                {
                    /* Slice off the .foo in S!(T).foo
                     */
                    tpi->idents.dim--;
                    MATCH m = tparent->deduceType(sc, tpi, parameters, dedtypes, wildmatch);
                    tpi->idents.dim++;
                    return m;
                }
            }
        }

        // If it matches exactly or via implicit conversion, we're done
        MATCH m = Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
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
        while(s && s->baseclasses->dim > 0)
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
        return implicitConvTo(tp);
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes, wildmatch);
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

#if DMDV2
TemplateThisParameter  *TemplateParameter::isTemplateThisParameter()
{
    return NULL;
}
#endif

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

/*******************************************
 * Match to a particular TemplateParameter.
 * Input:
 *      i               i'th argument
 *      tiargs[]        actual arguments to template instance
 *      parameters[]    template parameters
 *      dedtypes[]      deduced arguments to template instance
 *      *psparam        set to symbol declared and initialized to dedtypes[i]
 */

MATCH TemplateTypeParameter::matchArg(Scope *sc, Objects *tiargs,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    Object *oarg;

    if (i < tiargs->dim)
        oarg = (*tiargs)[i];
    else
    {   // Get default argument instead
        oarg = defaultArg(loc, sc);
        if (!oarg)
        {   assert(i < dedtypes->dim);
            // It might have already been deduced
            oarg = (*dedtypes)[i];
            if (!oarg)
            {
                goto Lnomatch;
            }
        }
    }
    return matchArg(sc, oarg, i, parameters, dedtypes, psparam);

Lnomatch:
    if (psparam)
        *psparam = NULL;
    return MATCHnomatch;
}

MATCH TemplateTypeParameter::matchArg(Scope *sc, Object *oarg,
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
        if (m2 == MATCHnomatch)
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


void TemplateTypeParameter::print(Object *oarg, Object *oded)
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
{   Type *t;

    if (specType)
        t = specType;
    else
    {   // Use this for alias-parameter's too (?)
        if (!tdummy)
            tdummy = new TypeIdentifier(loc, ident);
        t = tdummy;
    }
    return (void *)t;
}


Object *TemplateTypeParameter::specialization()
{
    return specType;
}


Object *TemplateTypeParameter::defaultArg(Loc loc, Scope *sc)
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

#if DMDV2
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
#endif

/* ======================== TemplateAliasParameter ========================== */

// alias-parameter

Dsymbol *TemplateAliasParameter::sdummy = NULL;

TemplateAliasParameter::TemplateAliasParameter(Loc loc, Identifier *ident,
        Type *specType, Object *specAlias, Object *defaultAlias)
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

Object *aliasParameterSemantic(Loc loc, Scope *sc, Object *o, TemplateParameters *parameters)
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
            ea = ea->ctfeSemantic(sc);
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
bool isPseudoDsymbol(Object *o)
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

MATCH TemplateAliasParameter::matchArg(Scope *sc, Objects *tiargs,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    Object *oarg;

    if (i < tiargs->dim)
        oarg = (*tiargs)[i];
    else
    {   // Get default argument instead
        oarg = defaultArg(loc, sc);
        if (!oarg)
        {   assert(i < dedtypes->dim);
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

MATCH TemplateAliasParameter::matchArg(Scope *sc, Object *oarg,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    //printf("TemplateAliasParameter::matchArg()\n");
    Object *sa = getDsymbol(oarg);
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
            if (m == MATCHnomatch)
                goto Lnomatch;
        }
    }
    else if ((*dedtypes)[i])
    {   // Must match already deduced symbol
        Object *si = (*dedtypes)[i];

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


void TemplateAliasParameter::print(Object *oarg, Object *oded)
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
{   Object *s;

    s = specAlias;
    if (!s)
    {
        if (!sdummy)
            sdummy = new Dsymbol();
        s = sdummy;
    }
    return (void*)s;
}


Object *TemplateAliasParameter::specialization()
{
    return specAlias;
}


Object *TemplateAliasParameter::defaultArg(Loc loc, Scope *sc)
{
    Object *da = defaultAlias;
    Type *ta = isType(defaultAlias);
    if (ta)
    {
       if (ta->ty == Tinstance)
       {
           // If the default arg is a template, instantiate for each type
           da = ta->syntaxCopy();
       }
    }

    Object *o = aliasParameterSemantic(loc, sc, da, NULL);
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
    {   Expression *e = specValue;

        e = e->ctfeSemantic(sc);
        e = e->implicitCastTo(sc, valType);
        e = e->ctfeInterpret();
        if (e->op == TOKint64 || e->op == TOKfloat64 ||
            e->op == TOKcomplex80 || e->op == TOKnull || e->op == TOKstring)
            specValue = e;
        //e->toInteger();
    }

    if (defaultValue)
    {   Expression *e = defaultValue;

        e = e->ctfeSemantic(sc);
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


MATCH TemplateValueParameter::matchArg(Scope *sc, Objects *tiargs,
        size_t i, TemplateParameters *parameters, Objects *dedtypes,
        Declaration **psparam)
{
    Object *oarg;

    if (i < tiargs->dim)
        oarg = (*tiargs)[i];
    else
    {   // Get default argument instead
        oarg = defaultArg(loc, sc);
        if (!oarg)
        {   assert(i < dedtypes->dim);
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

MATCH TemplateValueParameter::matchArg(Scope *sc, Object *oarg,
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
    vt = valType->semantic(Loc(), sc);
    //printf("ei: %s, ei->type: %s\n", ei->toChars(), ei->type->toChars());
    //printf("vt = %s\n", vt->toChars());

    if (ei->type)
    {
        m = (MATCH)ei->implicitConvTo(vt);
        //printf("m: %d\n", m);
        if (!m)
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

        e = e->ctfeSemantic(sc);
        e = resolveProperties(sc, e);
        e = e->implicitCastTo(sc, vt);
        e = e->ctfeInterpret();

        ei = ei->syntaxCopy();
        ei = ei->ctfeSemantic(sc);
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


void TemplateValueParameter::print(Object *oarg, Object *oded)
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


Object *TemplateValueParameter::specialization()
{
    return specValue;
}


Object *TemplateValueParameter::defaultArg(Loc loc, Scope *sc)
{
    Expression *e = defaultValue;
    if (e)
    {
        e = e->syntaxCopy();
        e = e->semantic(sc);
        e = resolveProperties(sc, e);
#if DMDV2
        e = e->resolveLoc(loc, sc);
#endif
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

MATCH TemplateTupleParameter::matchArg(Scope *sc, Objects *tiargs,
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

MATCH TemplateTupleParameter::matchArg(Scope *sc, Object *oarg,
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


void TemplateTupleParameter::print(Object *oarg, Object *oded)
{
    printf(" %s... [", ident->toChars());
    Tuple *v = isTuple(oded);
    assert(v);

    //printf("|%d| ", v->objects.dim);
    for (size_t i = 0; i < v->objects.dim; i++)
    {
        if (i)
            printf(", ");

        Object *o = v->objects[i];

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


Object *TemplateTupleParameter::specialization()
{
    return NULL;
}


Object *TemplateTupleParameter::defaultArg(Loc loc, Scope *sc)
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
    this->inst = NULL;
    this->tinst = NULL;
    this->argsym = NULL;
    this->aliasdecl = NULL;
    this->semanticRun = PASSinit;
    this->semantictiargsdone = 0;
    this->withsym = NULL;
    this->nest = 0;
    this->havetempdecl = 0;
    this->enclosing = NULL;
    this->speculative = 0;
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
    this->inst = NULL;
    this->tinst = NULL;
    this->argsym = NULL;
    this->aliasdecl = NULL;
    this->semanticRun = PASSinit;
    this->semantictiargsdone = 1;
    this->withsym = NULL;
    this->nest = 0;
    this->havetempdecl = 1;
    this->enclosing = NULL;
    this->speculative = 0;

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

    if (inst)
        tempdecl->ScopeDsymbol::syntaxCopy(ti);
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
    {   Dsymbol *s = (*members)[i];
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

#if WINDOWS_SEH
    if(nest == 1)
    {
        // do not catch at every nesting level, because generating the output error might cause more stack
        //  errors in the __except block otherwise
        __try
        {
            expandMembers(sc2);
        }
        __except (__ehfilter(GetExceptionInformation()))
        {
            global.gag = 0;                     // ensure error message gets printed
            error("recursive expansion");
            fatal();
        }
    }
    else
#endif
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
#if WINDOWS_SEH
    if(nest == 1)
    {
        // do not catch at every nesting level, because generating the output error might cause more stack
        //  errors in the __except block otherwise
        __try
        {
            semantic3(sc2);
        }
        __except (__ehfilter(GetExceptionInformation()))
        {
            global.gag = 0;            // ensure error message gets printed
            error("recursive expansion");
            fatal();
        }
    }
    else
#endif
        semantic3(sc2);

    --nest;
}

void TemplateInstance::semantic(Scope *sc, Expressions *fargs)
{
    //printf("TemplateInstance::semantic('%s', this=%p, gag = %d, sc = %p)\n", toChars(), this, global.gag, sc);
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
    if (havetempdecl)
    {
        assert(tempdecl->scope);
        // Deduce tdtypes
        tdtypes.setDim(tempdecl->parameters->dim);
        if (!tempdecl->matchWithInstance(this, &tdtypes, fargs, 2))
        {
            error("incompatible arguments for template instantiation");
            inst = this;
            return;
        }
    }
    else
    {
        /* Find template declaration first,
         * then run semantic on each argument (place results in tiargs[]),
         * last find most specialized template from overload list/set.
         */
        if (!findTemplateDeclaration(sc) ||
            !semanticTiargs(sc) ||
            !findBestMatch(sc, fargs))
        {
            inst = this;
            //printf("error return %p, %d\n", tempdecl, global.errors);
            if (inst)
                inst->errors = true;
            return;             // error recovery
        }
    }

    // If tempdecl is a mixin, disallow it
    if (tempdecl->ismixin)
        error("mixin templates are not regular templates");

    hasNestedArgs(tiargs);

    /* See if there is an existing TemplateInstantiation that already
     * implements the typeargs. If so, just refer to that one instead.
     */

    for (size_t i = 0; i < tempdecl->instances.dim; i++)
    {
        TemplateInstance *ti = tempdecl->instances[i];
#if LOG
        printf("\t%s: checking for match with instance %d (%p): '%s'\n", toChars(), i, ti, ti->toChars());
#endif
        assert(tdtypes.dim == ti->tdtypes.dim);

        // Nesting must match
        if (enclosing != ti->enclosing)
        {
            //printf("test2 enclosing %s ti->enclosing %s\n", enclosing ? enclosing->toChars() : "", ti->enclosing ? ti->enclosing->toChars() : "");
            continue;
        }
        //printf("parent = %s, ti->parent = %s\n", tempdecl->parent->toPrettyChars(), ti->parent->toPrettyChars());

        if (!arrayObjectMatch(&tdtypes, &ti->tdtypes, tempdecl, sc))
            goto L1;

        /* Template functions may have different instantiations based on
         * "auto ref" parameters.
         */
        if (fargs)
        {
            FuncDeclaration *fd = ti->toAlias()->isFuncDeclaration();
            if (fd)
            {
                Parameters *fparameters = fd->getParameters(NULL);
                size_t nfparams = Parameter::dim(fparameters); // Num function parameters
                for (size_t j = 0; j < nfparams && j < fargs->dim; j++)
                {   Parameter *fparam = Parameter::getNth(fparameters, j);
                    Expression *farg = (*fargs)[j];
                    if (fparam->storageClass & STCauto)         // if "auto ref"
                    {
                        if (farg->isLvalue())
                        {   if (!(fparam->storageClass & STCref))
                                goto L1;                        // auto ref's don't match
                        }
                        else
                        {   if (fparam->storageClass & STCref)
                                goto L1;                        // auto ref's don't match
                        }
                    }
                }
            }
        }

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
        return;

     L1:
        ;
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

    size_t tempdecl_instance_idx = tempdecl->instances.dim;
    tempdecl->instances.push(this);
    parent = tempdecl->parent;
    //printf("parent = '%s'\n", parent->kind());

    ident = genIdent(tiargs);         // need an identifier for name mangling purposes.

#if 1
    if (enclosing)
        parent = enclosing;
#endif
    //printf("parent = '%s'\n", parent->kind());

    // Add 'this' to the enclosing scope's members[] so the semantic routines
    // will get called on the instance members. Store the place we added it to
    // in target_symbol_list(_idx) so we can remove it later if we encounter
    // an error.
#if 1
    int dosemantic3 = 0;
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
        if (scx && scx->scopesym &&
            scx->scopesym->members && !scx->scopesym->isTemplateMixin()
#if 0 // removed because it bloated compile times
            /* The problem is if A imports B, and B imports A, and both A
             * and B instantiate the same template, does the compilation of A
             * or the compilation of B do the actual instantiation?
             *
             * see bugzilla 2500.
             */
            && !scx->module->selfImports()
#endif
           )
        {
            //printf("\t1: adding to %s %s\n", scx->scopesym->kind(), scx->scopesym->toChars());
            a = scx->scopesym->members;
        }
        else
        {
            Module *m = (enclosing ? sc : tempdecl->scope)->module->importedFrom;
            //printf("\t2: adding to module %s instead of module %s\n", m->toChars(), sc->module->toChars());
            a = m->members;
            if (m->semanticRun >= 3)
            {
                dosemantic3 = 1;
            }
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
    if (members && speculative)
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
    if (!tempdecl->semanticRun)
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

    tryExpandMembers(sc2);

    semanticRun = PASSsemanticdone;

    /* If any of the instantiation members didn't get semantic() run
     * on them due to forward references, we cannot run semantic2()
     * or semantic3() yet.
     */
    bool found_deferred_ad = false;
    for (size_t i = 0; i < Module::deferred.dim; i++)
    {   Dsymbol *sd = Module::deferred[i];

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
    if (found_deferred_ad)
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

        /* BUG 782: this has problems if the classes this depends on
         * are forward referenced. Find a way to defer semantic()
         * on this template.
         */
        semantic2(sc2);

    if (sc->func || dosemantic3)
    {
        trySemantic3(sc2);
    }

  Laftersemantic:
    sc2->pop();

    scope->pop();

    // Give additional context info if error occurred during instantiation
    if (global.errors != errorsave)
    {
        error(loc, "error instantiating");
        if (tinst)
        {   tinst->printInstantiationTrace();
        }
        errors = 1;
        if (global.gag)
        {
            // Errors are gagged, so remove the template instance from the
            // instance/symbol lists we added it to and reset our state to
            // finish clean and so we can try to instantiate it again later
            // (see bugzilla 4302 and 6602).
            tempdecl->instances.remove(tempdecl_instance_idx);
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
        Object *o = (*tiargs)[j];
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
            (*tiargs)[j] = ta;
        }
        else if (ea)
        {
        Lexpr:
            //printf("+[%d] ea = %s %s\n", j, Token::toChars(ea->op), ea->toChars());
            if (flags & 1)
                ea = ea->semantic(sc);
            else
                ea = ea->ctfeSemantic(sc);
            if (flags & 1) // only used by __traits, must not interpret the args
            {
                VarDeclaration *v;
                if (ea->op == TOKvar && (v = ((VarExp *)ea)->var->isVarDeclaration()) != NULL &&
                    v->storage_class & STCmanifest && !(v->storage_class & STCtemplateparameter))
                {
                    if (v->sem < SemanticDone)
                        v->semantic(sc);
                    // skip optimization for manifest constant
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
            else if (ea->op != TOKtuple &&
                     ea->op != TOKimport && ea->op != TOKtype &&
                     ea->op != TOKfunction && ea->op != TOKerror &&
                     ea->op != TOKthis && ea->op != TOKsuper)
            {
                int olderrs = global.errors;
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
                    sa = fe->td;
                    goto Ldsym;
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
            (*tiargs)[j] = sa;

            TemplateDeclaration *td = sa->isTemplateDeclaration();
            if (td && !td->semanticRun && td->literal)
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
        Object *o = (*tiargs)[j];
        Type *ta = isType(o);
        Expression *ea = isExpression(o);
        Dsymbol *sa = isDsymbol(o);
        Tuple *va = isTuple(o);

        printf("\ttiargs[%d] = ta %p, ea %p, sa %p, va %p\n", j, ta, ea, sa, va);
    }
#endif
}

/**********************************************
 * Find template declaration corresponding to template instance.
 */

bool TemplateInstance::findTemplateDeclaration(Scope *sc)
{
    //printf("TemplateInstance::findTemplateDeclaration() %s\n", toChars());
    if (!tempdecl)
    {
        /* Given:
         *    foo!( ... )
         * figure out which TemplateDeclaration foo refers to.
         */
        Dsymbol *s;
        Dsymbol *scopesym;
        Identifier *id;

        id = name;
        s = sc->search(loc, id, &scopesym);
        if (!s)
        {
            s = sc->search_correct(id);
            if (s)
                error("template '%s' is not defined, did you mean %s?", id->toChars(), s->toChars());
            else
                error("template '%s' is not defined", id->toChars());
            return false;
        }

        /* If an OverloadSet, look for a unique member that is a template declaration
         */
        OverloadSet *os = s->isOverloadSet();
        if (os)
        {   s = NULL;
            for (size_t i = 0; i < os->a.dim; i++)
            {   Dsymbol *s2 = os->a[i];
                if (s2->isTemplateDeclaration())
                {
                    if (s)
                        error("ambiguous template declaration %s and %s", s->toPrettyChars(), s2->toPrettyChars());
                    s = s2;
                }
            }
            if (!s)
            {   error("template '%s' is not defined", id->toChars());
                return false;
            }
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
                tempdecl = ti->tempdecl;
                if (tempdecl->overroot)         // if not start of overloaded list of TemplateDeclaration's
                    tempdecl = tempdecl->overroot; // then get the start
                s = tempdecl;
            }
        }

        s = s->toAlias();

        /* It should be a TemplateDeclaration, not some other symbol
         */
        tempdecl = s->isTemplateDeclaration();
        if (!tempdecl)
        {
            if (!s->parent && global.errors)
                return false;
            if (!s->parent && s->getType())
            {   Dsymbol *s2 = s->getType()->toDsymbol(sc);
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
                (ti->name == id ||
                 ti->toAlias()->ident == id)
                &&
                ti->tempdecl)
            {
                /* This is so that one can refer to the enclosing
                 * template, even if it has the same name as a member
                 * of the template, if it has a !(arguments)
                 */
                tempdecl = ti->tempdecl;
                if (tempdecl->overroot)         // if not start of overloaded list of TemplateDeclaration's
                    tempdecl = tempdecl->overroot; // then get the start
            }
            else
            {
                error("%s is not a template declaration, it is a %s", id->toChars(), s->kind());
                return false;
            }
        }
    }
    else
        assert(tempdecl->isTemplateDeclaration());
    return (tempdecl != NULL);
}

bool TemplateInstance::findBestMatch(Scope *sc, Expressions *fargs)
{
    /* Since there can be multiple TemplateDeclaration's with the same
     * name, look for the best match.
     */
    TemplateDeclaration *td_ambig = NULL;
    TemplateDeclaration *td_best = NULL;
    MATCH m_best = MATCHnomatch;
    Objects dedtypes;
    unsigned errs = global.errors;

#if LOG
    printf("TemplateInstance::findBestMatch()\n");
#endif
    // First look for forward references
    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
        if (!td->semanticRun)
        {
            if (td->scope)
            {   // Try to fix forward reference. Ungag errors while doing so.
                int oldgag = global.gag;
                if (global.isSpeculativeGagging() && !td->isSpeculative())
                    global.gag = 0;

                td->semantic(td->scope);

                global.gag = oldgag;
            }
            if (!td->semanticRun)
            {
                error("%s forward references template declaration %s", toChars(), td->toChars());
                return false;
            }
        }
    }

    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
        MATCH m;

//if (tiargs->dim) printf("2: tiargs->dim = %d, data[0] = %p\n", tiargs->dim, (*tiargs)[0]);

        // If more arguments than parameters,
        // then this is no match.
        if (td->parameters->dim < tiargs->dim)
        {
            if (!td->isVariadic())
                continue;
        }

        dedtypes.setDim(td->parameters->dim);
        dedtypes.zero();
        assert(td->semanticRun);
        m = td->matchWithInstance(this, &dedtypes, fargs, 0);
        //printf("matchWithInstance = %d\n", m);
        if (!m)                 // no match at all
            continue;

        if (m < m_best)
            goto Ltd_best;
        if (m > m_best)
            goto Ltd;

        {
        // Disambiguate by picking the most specialized TemplateDeclaration
        MATCH c1 = td->leastAsSpecialized(td_best, fargs);
        MATCH c2 = td_best->leastAsSpecialized(td, fargs);
        //printf("c1 = %d, c2 = %d\n", c1, c2);

        if (c1 > c2)
            goto Ltd;
        else if (c1 < c2)
            goto Ltd_best;
        else
            goto Lambig;
        }

      Lambig:           // td_best and td are ambiguous
        td_ambig = td;
        continue;

      Ltd_best:         // td_best is the best match so far
        td_ambig = NULL;
        continue;

      Ltd:              // td is the new best match
        td_ambig = NULL;
        td_best = td;
        m_best = m;
        tdtypes.setDim(dedtypes.dim);
        memcpy(tdtypes.tdata(), dedtypes.tdata(), tdtypes.dim * sizeof(void *));
        continue;
    }

    if (!td_best)
    {
        if (errs != global.errors)
            errorSupplemental(loc, "while looking for match for %s", toChars());
        else if (tempdecl && !tempdecl->overnext)
            // Only one template, so we can give better error message
            error("does not match template declaration %s", tempdecl->toChars());
        else
            ::error(loc, "%s %s.%s does not match any template declaration",
                    tempdecl->kind(), tempdecl->parent->toPrettyChars(), tempdecl->ident->toChars());
        return false;
    }
    if (td_ambig)
    {
        ::error(loc, "%s %s.%s matches more than one template declaration, %s(%d):%s and %s(%d):%s",
                td_best->kind(), td_best->parent->toPrettyChars(), td_best->ident->toChars(),
                td_best->loc.filename,  td_best->loc.linnum,  td_best->toChars(),
                td_ambig->loc.filename, td_ambig->loc.linnum, td_ambig->toChars());
    }

    /* The best match is td_best
     */
    tempdecl = td_best;

#if 0
    /* Cast any value arguments to be same type as value parameter
     */
    for (size_t i = 0; i < tiargs->dim; i++)
    {   Object *o = (*tiargs)[i];
        Expression *ea = isExpression(o);       // value argument
        TemplateParameter *tp = (*tempdecl->parameters)[i];
        assert(tp);
        TemplateValueParameter *tvp = tp->isTemplateValueParameter();
        if (tvp)
        {
            assert(ea);
            ea = ea->castTo(tvp->valType);
            ea = ea->ctfeInterpret();
            (*tiargs)[i] = (Object *)ea;
        }
    }
#endif

#if LOG
    printf("\tIt's a match with template declaration '%s'\n", tempdecl->toChars());
#endif
    return (errs == global.errors) && tempdecl;
}


/*****************************************
 * Determines if a TemplateInstance will need a nested
 * generation of the TemplateDeclaration.
 * Sets enclosing property if so, and returns != 0;
 */

int TemplateInstance::hasNestedArgs(Objects *args)
{   int nested = 0;
    //printf("TemplateInstance::hasNestedArgs('%s')\n", tempdecl->ident->toChars());

    /* A nested instance happens when an argument references a local
     * symbol that is on the stack.
     */
    for (size_t i = 0; i < args->dim; i++)
    {   Object *o = (*args)[i];
        Expression *ea = isExpression(o);
        Dsymbol *sa = isDsymbol(o);
        Tuple *va = isTuple(o);
#define FIXBUG8863 0
#if FIXBUG8863
        /* This does fix 8863, but it causes other complex
         * failures in Phobos unittests and the test suite.
         * Not sure why.
         */
        Type *ta = isType(o);
        if (ta && !sa)
        {
            Dsymbol *s = ta->toDsymbol(NULL);
            if (s)
            {
                sa = s;
                goto Lsa;
            }
        }
        else
#endif
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
        }
        else if (sa)
        {
          Lsa:
            sa = sa->toAlias();
            TemplateDeclaration *td = sa->isTemplateDeclaration();
            AggregateDeclaration *ad = sa->isAggregateDeclaration();
            Declaration *d = sa->isDeclaration();
            if ((td && td->literal) ||
#if FIXBUG8863
                (ad && ad->isNested()) ||
#endif
                (d && !d->isDataseg() &&
#if DMDV2
                 !(d->storage_class & STCmanifest) &&
#endif
                 (!d->isFuncDeclaration() || d->isFuncDeclaration()->isNested()) &&
                 !isTemplateMixin()
                ))
            {
                // if module level template
                if (tempdecl->toParent()->isModule())
                {   Dsymbol *dparent = sa->toParent2();
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
            nested |= hasNestedArgs(&va->objects);
        }
    }
    //printf("-TemplateInstance::hasNestedArgs('%s') = %d\n", tempdecl->ident->toChars(), nested);
    return nested;
}

/****************************************
 * This instance needs an identifier for name mangling purposes.
 * Create one by taking the template declaration name and adding
 * the type signature for it.
 */

Identifier *TemplateInstance::genIdent(Objects *args)
{   OutBuffer buf;

    //printf("TemplateInstance::genIdent('%s')\n", tempdecl->ident->toChars());
    char *id = tempdecl->ident->toChars();
    buf.printf("__T%llu%s", (ulonglong)strlen(id), id);
    for (size_t i = 0; i < args->dim; i++)
    {   Object *o = (*args)[i];
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
          Lsa2:
            if (d && (!d->type || !d->type->deco))
            {
                FuncAliasDeclaration *fad = d->isFuncAliasDeclaration();
                if (fad)
                {   d = fad->toAliasFunc();
                    goto Lsa2;
                }
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


/****************************************************
 * Declare parameters of template instance, initialize them with the
 * template instance arguments.
 */

void TemplateInstance::declareParameters(Scope *sc)
{
    //printf("TemplateInstance::declareParameters()\n");
    for (size_t i = 0; i < tdtypes.dim; i++)
    {
        TemplateParameter *tp = (*tempdecl->parameters)[i];
        //Object *o = (*tiargs)[i];
        Object *o = tdtypes[i];          // initializer for tp

        //printf("\ttdtypes[%d] = %p\n", i, o);
        tempdecl->declareParameter(sc, tp, o);
    }
}

/*****************************************************
 * Determine if template instance is really a template function,
 * and that template function needs to infer types from the function
 * arguments.
 */

int TemplateInstance::needsTypeInference(Scope *sc)
{
    //printf("TemplateInstance::needsTypeInference() %s\n", toChars());
    if (!findTemplateDeclaration(sc))
        return FALSE;

    int multipleMatches = FALSE;
    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
        /* If any of the overloaded template declarations need inference,
         * then return TRUE
         */
        FuncDeclaration *fd;
        if (!td->onemember ||
            (fd = td->onemember/*->toAlias()*/->isFuncDeclaration()) == NULL ||
            fd->type->ty != Tfunction)
        {
            /* Not a template function, therefore type inference is not possible.
             */
            //printf("false\n");
            return FALSE;
        }

        for (size_t i = 0; i < td->parameters->dim; i++)
            if ((*td->parameters)[i]->isTemplateThisParameter())
                return TRUE;

        /* Determine if the instance arguments, tiargs, are all that is necessary
         * to instantiate the template.
         */
        //printf("tp = %p, td->parameters->dim = %d, tiargs->dim = %d\n", tp, td->parameters->dim, tiargs->dim);
        TypeFunction *fdtype = (TypeFunction *)fd->type;
        if (Parameter::dim(fdtype->parameters))
        {
            TemplateParameter *tp = td->isVariadic();
            if (tp && td->parameters->dim > 1)
                return TRUE;

            if (tiargs->dim < td->parameters->dim)
            {   // Can remain tiargs be filled by default arguments?
                for (size_t i = tiargs->dim; i < td->parameters->dim; i++)
                {   tp = (*td->parameters)[i];
                    if (TemplateTypeParameter *ttp = tp->isTemplateTypeParameter())
                    {   if (!ttp->defaultType)
                            return TRUE;
                    }
                    else if (TemplateAliasParameter *tap = tp->isTemplateAliasParameter())
                    {   if (!tap->defaultAlias)
                            return TRUE;
                    }
                    else if (TemplateValueParameter *tvp = tp->isTemplateValueParameter())
                    {   if (!tvp->defaultValue)
                            return TRUE;
                    }
                }
            }
        }
        /* If there is more than one function template which matches, we may
         * need type inference (see Bugzilla 4430)
         */
        if (td != tempdecl)
            multipleMatches = TRUE;
    }
    //printf("false\n");
    return multipleMatches;
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
        sc = sc->push(this);
        sc->tinst = this;
        int oldgag = global.gag;
        int olderrors = global.errors;
        /* If this is a speculative instantiation, gag errors.
         * Future optimisation: If the results are actually needed, errors
         * would already be gagged, so we don't really need to run semantic
         * on the members.
         */
        if (speculative && !oldgag)
            olderrors = global.startGagging();
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->semantic3(sc);
            if (speculative && global.errors != olderrors)
                break;
        }
        if (speculative && !oldgag)
        {   // If errors occurred, this instantiation failed
            errors += global.errors - olderrors;
            global.endGagging(olderrors);
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
    buf->writestring("!(");
    if (nest)
        buf->writestring("...");
    else
    {
        nest++;
        Objects *args = tiargs;
        for (size_t i = 0; i < args->dim; i++)
        {
            if (i)
                buf->writestring(", ");
            Object *oarg = (*args)[i];
            ObjectToCBuffer(buf, hgs, oarg);
        }
        nest--;
    }
    buf->writeByte(')');
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
        {   error("cannot resolve forward reference");
            errors = 1;
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

int TemplateInstance::oneMember(Dsymbol **ps, Identifier *ident)
{
    *ps = NULL;
    return TRUE;
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

void TemplateMixin::semantic(Scope *sc)
{
#if LOG
    printf("+TemplateMixin::semantic('%s', this=%p)\n", toChars(), this);
    fflush(stdout);
#endif
    if (semanticRun)
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
    if (!semanticRun)
        semanticRun = PASSsemantic;
#if LOG
    printf("\tdo semantic\n");
#endif
#ifndef IN_GCC
    util_progress();
#endif

    Scope *scx = NULL;
    if (scope)
    {   sc = scope;
        scx = scope;            // save so we don't make redundant copies
        scope = NULL;
    }

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
            inst = this;
            return;
        }
        tempdecl = s->toAlias()->isTemplateDeclaration();
        if (!tempdecl)
        {
            error("%s isn't a template", s->toChars());
            inst = this;
            return;
        }
    }

    // Look for forward reference
    assert(tempdecl);
    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
        if (!td->semanticRun)
        {
            if (td->scope)
                td->semantic(td->scope);
            else
            {
                /* Cannot handle forward references if mixin is a struct member,
                 * because addField must happen during struct's semantic, not
                 * during the mixin semantic.
                 * runDeferred will re-run mixin's semantic outside of the struct's
                 * semantic.
                 */
                semanticRun = PASSinit;
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
        }
    }

    /* Run semantic on each argument, place results in tiargs[],
     * then find best match template with tiargs
     */
    if (!semanticTiargs(sc) ||
        !findBestMatch(sc, NULL))
    {
        inst = this;
        inst->errors = true;
        return;         // error recovery
    }

    if (!ident)
        ident = genIdent(tiargs);

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
        {   Object *o = (*tiargs)[i];
            Type *ta = isType(o);
            Expression *ea = isExpression(o);
            Dsymbol *sa = isDsymbol(o);
            Object *tmo = (*tm->tiargs)[i];
            if (ta)
            {
                Type *tmta = isType(tmo);
                if (!tmta)
                    goto Lcontinue;
                if (!ta->equals(tmta))
                    goto Lcontinue;
            }
            else if (ea)
            {   Expression *tme = isExpression(tmo);
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
    if (scx && members)
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
    {   Dsymbol *s = (*members)[i];
        s->addMember(argscope, this, i);
        //sc->insert(s);
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
    }

    sc2->pop();

    argscope->pop();

//    if (!isAnonymous())
    {
        scy->pop();
    }
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

int TemplateMixin::oneMember(Dsymbol **ps, Identifier *ident)
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

int TemplateMixin::hasPointers()
{
    //printf("TemplateMixin::hasPointers() %s\n", toChars());

    if (members)
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            //printf(" s = %s %s\n", s->kind(), s->toChars());
            if (s->hasPointers())
            {
                return 1;
            }
        }
    return 0;
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
    buf->writestring("!(");
    if (tiargs)
    {
        for (size_t i = 0; i < tiargs->dim; i++)
        {   if (i)
                buf->writestring(", ");
            Object *oarg = (*tiargs)[i];
            Type *t = isType(oarg);
            Expression *e = isExpression(oarg);
            Dsymbol *s = isDsymbol(oarg);
            if (t)
                t->toCBuffer(buf, NULL, hgs);
            else if (e)
                e->toCBuffer(buf, hgs);
            else if (s)
            {
                char *p = s->ident ? s->ident->toChars() : s->toChars();
                buf->writestring(p);
            }
            else if (!oarg)
            {
                buf->writestring("NULL");
            }
            else
            {
                assert(0);
            }
        }
    }
    buf->writebyte(')');
    if (ident)
    {
        buf->writebyte(' ');
        buf->writestring(ident->toChars());
    }
    buf->writebyte(';');
    buf->writenl();
}


