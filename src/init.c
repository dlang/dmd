
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

#include "mars.h"
#include "init.h"
#include "expression.h"
#include "statement.h"
#include "identifier.h"
#include "declaration.h"
#include "aggregate.h"
#include "scope.h"
#include "mtype.h"
#include "hdrgen.h"
#include "template.h"

/********************************** Initializer *******************************/

Initializer::Initializer(Loc loc)
{
    this->loc = loc;
}

Initializer *Initializer::syntaxCopy()
{
    return this;
}

Initializer *Initializer::semantic(Scope *sc, Type *t, int needInterpret)
{
    return this;
}

Type *Initializer::inferType(Scope *sc)
{
    error(loc, "cannot infer type from initializer");
    return Type::terror;
}

Initializers *Initializer::arraySyntaxCopy(Initializers *ai)
{   Initializers *a = NULL;

    if (ai)
    {
        a = new Initializers();
        a->setDim(ai->dim);
        for (size_t i = 0; i < a->dim; i++)
        {   Initializer *e = (*ai)[i];

            e = e->syntaxCopy();
            (*a)[i] = e;
        }
    }
    return a;
}

char *Initializer::toChars()
{   OutBuffer *buf;
    HdrGenState hgs;

    memset(&hgs, 0, sizeof(hgs));
    buf = new OutBuffer();
    toCBuffer(buf, &hgs);
    return buf->toChars();
}

/********************************** VoidInitializer ***************************/

VoidInitializer::VoidInitializer(Loc loc)
    : Initializer(loc)
{
    type = NULL;
}


Initializer *VoidInitializer::syntaxCopy()
{
    return new VoidInitializer(loc);
}


Initializer *VoidInitializer::semantic(Scope *sc, Type *t, int needInterpret)
{
    //printf("VoidInitializer::semantic(t = %p)\n", t);
    type = t;
    return this;
}


Expression *VoidInitializer::toExpression()
{
    error(loc, "void initializer has no value");
    return new IntegerExp(0);
}


void VoidInitializer::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("void");
}


/********************************** StructInitializer *************************/

StructInitializer::StructInitializer(Loc loc)
    : Initializer(loc)
{
    ad = NULL;
}

Initializer *StructInitializer::syntaxCopy()
{
    StructInitializer *ai = new StructInitializer(loc);

    assert(field.dim == value.dim);
    ai->field.setDim(field.dim);
    ai->value.setDim(value.dim);
    for (size_t i = 0; i < field.dim; i++)
    {
        ai->field[i] = field[i];

        Initializer *init = value[i];
        init = init->syntaxCopy();
        ai->value[i] = init;
    }
    return ai;
}

void StructInitializer::addInit(Identifier *field, Initializer *value)
{
    //printf("StructInitializer::addInit(field = %p, value = %p)\n", field, value);
    this->field.push(field);
    this->value.push(value);
}

Initializer *StructInitializer::semantic(Scope *sc, Type *t, int needInterpret)
{
    int errors = 0;

    //printf("StructInitializer::semantic(t = %s) %s\n", t->toChars(), toChars());
    vars.setDim(field.dim);
    t = t->toBasetype();
    if (t->ty == Tstruct)
    {
        unsigned fieldi = 0;

        TypeStruct *ts = (TypeStruct *)t;
        ad = ts->sym;
        if (ad->ctor)
            error(loc, "%s %s has constructors, cannot use { initializers }, use %s( initializers ) instead",
                ad->kind(), ad->toChars(), ad->toChars());
        StructDeclaration *sd = ad->isStructDeclaration();
        assert(sd);
        sd->size(loc);
        if (sd->sizeok != SIZEOKdone)
        {
            error(loc, "struct %s is forward referenced", sd->toChars());
            errors = 1;
            goto Lerror;
        }
        size_t nfields = sd->fields.dim;
        if (sd->isnested)
            nfields--;
        for (size_t i = 0; i < field.dim; i++)
        {
            Identifier *id = field[i];
            Initializer *val = value[i];
            Dsymbol *s;
            VarDeclaration *v;

            if (id == NULL)
            {
                if (fieldi >= nfields)
                {   error(loc, "too many initializers for %s", ad->toChars());
                    errors = 1;
                    field.remove(i);
                    i--;
                    continue;
                }
                else
                {
                    s = ad->fields[fieldi];
                }
            }
            else
            {
                //s = ad->symtab->lookup(id);
                s = ad->search(loc, id, 0);
                if (!s)
                {
                    s = ad->search_correct(id);
                    if (s)
                        error(loc, "'%s' is not a member of '%s', did you mean '%s %s'?",
                              id->toChars(), t->toChars(), s->kind(), s->toChars());
                    else
                        error(loc, "'%s' is not a member of '%s'", id->toChars(), t->toChars());
                    errors = 1;
                    continue;
                }
                s = s->toAlias();

                // Find out which field index it is
                for (fieldi = 0; 1; fieldi++)
                {
                    if (fieldi >= nfields)
                    {
                        error(loc, "%s.%s is not a per-instance initializable field",
                            t->toChars(), s->toChars());
                        errors = 1;
                        break;
                    }
                    if (s == ad->fields[fieldi])
                        break;
                }
            }
            if (s && (v = s->isVarDeclaration()) != NULL)
            {
                val = val->semantic(sc, v->type, needInterpret);
                value[i] = val;
                vars[i] = v;
            }
            else
            {   error(loc, "%s is not a field of %s", id ? id->toChars() : s->toChars(), ad->toChars());
                errors = 1;
            }
            fieldi++;
        }
    }
    else if (t->ty == Tdelegate && value.dim == 0)
    {   /* Rewrite as empty delegate literal { }
         */
        Parameters *arguments = new Parameters;
        Type *tf = new TypeFunction(arguments, NULL, 0, LINKd);
        FuncLiteralDeclaration *fd = new FuncLiteralDeclaration(loc, 0, tf, TOKdelegate, NULL);
        fd->fbody = new CompoundStatement(loc, new Statements());
        fd->endloc = loc;
        Expression *e = new FuncExp(loc, fd);
        ExpInitializer *ie = new ExpInitializer(loc, e);
        return ie->semantic(sc, t, needInterpret);
    }
    else
    {
        error(loc, "a struct is not a valid initializer for a %s", t->toChars());
        errors = 1;
    }
Lerror:
    if (errors)
    {
        field.setDim(0);
        value.setDim(0);
        vars.setDim(0);
    }
    return this;
}

/***************************************
 * This works by transforming a struct initializer into
 * a struct literal. In the future, the two should be the
 * same thing.
 */
Expression *StructInitializer::toExpression()
{   Expression *e;
    size_t offset;

    //printf("StructInitializer::toExpression() %s\n", toChars());
    if (!ad)                            // if fwd referenced
        return NULL;
    StructDeclaration *sd = ad->isStructDeclaration();
    if (!sd)
        return NULL;

    Expressions *elements = new Expressions();
    size_t nfields = ad->fields.dim;
#if DMDV2
    if (sd->isnested)
       nfields--;
#endif
    elements->setDim(nfields);
    for (size_t i = 0; i < elements->dim; i++)
    {
        (*elements)[i] = NULL;
    }
    unsigned fieldi = 0;
    for (size_t i = 0; i < value.dim; i++)
    {
        Identifier *id = field[i];
        if (id)
        {
            Dsymbol * s = ad->search(loc, id, 0);
            if (!s)
            {
                error(loc, "'%s' is not a member of '%s'", id->toChars(), sd->toChars());
                goto Lno;
            }
            s = s->toAlias();

            // Find out which field index it is
            for (fieldi = 0; 1; fieldi++)
            {
                if (fieldi >= nfields)
                {
                    s->error("is not a per-instance initializable field");
                    goto Lno;
                }
                if (s == ad->fields[fieldi])
                    break;
            }
        }
        else if (fieldi >= nfields)
        {   error(loc, "too many initializers for '%s'", ad->toChars());
            goto Lno;
        }
        Initializer *iz = value[i];
        if (!iz)
            goto Lno;
        Expression *ex = iz->toExpression();
        if (!ex)
            goto Lno;
        if ((*elements)[fieldi])
        {   error(loc, "duplicate initializer for field '%s'",
                ad->fields[fieldi]->toChars());
            goto Lno;
        }
        (*elements)[fieldi] = ex;
        ++fieldi;
    }
    // Now, fill in any missing elements with default initializers.
    // We also need to validate any anonymous unions
    offset = 0;
    for (size_t i = 0; i < elements->dim; )
    {
        VarDeclaration * vd = ad->fields[i]->isVarDeclaration();

        //printf("test2 [%d] : %s %d %d\n", i, vd->toChars(), (int)offset, (int)vd->offset);
        if (vd->offset < offset)
        {
            // Only the first field of a union can have an initializer
            if ((*elements)[i])
                goto Lno;
        }
        else
        {
            if (!(*elements)[i])
                // Default initialize
                (*elements)[i] = vd->type->defaultInit();
        }
        offset = vd->offset + vd->type->size();
        i++;
#if 0
        int unionSize = ad->numFieldsInUnion(i);
        if (unionSize == 1)
        {   // Not a union -- default initialize if missing
            if (!(*elements)[i])
                (*elements)[i] = vd->type->defaultInit();
        }
        else
        {   // anonymous union -- check for errors
            int found = -1; // index of the first field with an initializer
            for (size_t j = i; j < i + unionSize; ++j)
            {
                if (!(*elements)[j])
                    continue;
                if (found >= 0)
                {
                    VarDeclaration * v1 = ((Dsymbol *)ad->fields.data[found])->isVarDeclaration();
                    VarDeclaration * v = ((Dsymbol *)ad->fields.data[j])->isVarDeclaration();
                    error(loc, "%s cannot have initializers for fields %s and %s in same union",
                        ad->toChars(),
                        v1->toChars(), v->toChars());
                    goto Lno;
                }
                found = j;
            }
            if (found == -1)
            {
                error(loc, "no initializer for union that contains field %s",
                    vd->toChars());
                goto Lno;
            }
        }
        i += unionSize;
#endif
    }
    e = new StructLiteralExp(loc, sd, elements);
    e->type = sd->type;
    return e;

Lno:
    delete elements;
    return NULL;
}


void StructInitializer::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    //printf("StructInitializer::toCBuffer()\n");
    buf->writebyte('{');
    for (size_t i = 0; i < field.dim; i++)
    {
        if (i > 0)
            buf->writebyte(',');
        Identifier *id = field[i];
        if (id)
        {
            buf->writestring(id->toChars());
            buf->writebyte(':');
        }
        Initializer *iz = value[i];
        if (iz)
            iz->toCBuffer(buf, hgs);
    }
    buf->writebyte('}');
}

/********************************** ArrayInitializer ************************************/

ArrayInitializer::ArrayInitializer(Loc loc)
    : Initializer(loc)
{
    dim = 0;
    type = NULL;
    sem = 0;
}

Initializer *ArrayInitializer::syntaxCopy()
{
    //printf("ArrayInitializer::syntaxCopy()\n");

    ArrayInitializer *ai = new ArrayInitializer(loc);

    assert(index.dim == value.dim);
    ai->index.setDim(index.dim);
    ai->value.setDim(value.dim);
    for (size_t i = 0; i < ai->value.dim; i++)
    {   Expression *e = index[i];
        if (e)
            e = e->syntaxCopy();
        ai->index[i] = e;

        Initializer *init = value[i];
        init = init->syntaxCopy();
        ai->value[i] = init;
    }
    return ai;
}

void ArrayInitializer::addInit(Expression *index, Initializer *value)
{
    this->index.push(index);
    this->value.push(value);
    dim = 0;
    type = NULL;
}

Initializer *ArrayInitializer::semantic(Scope *sc, Type *t, int needInterpret)
{   unsigned i;
    unsigned length;
    const unsigned amax = 0x80000000;

    //printf("ArrayInitializer::semantic(%s)\n", t->toChars());
    if (sem)                            // if semantic() already run
        return this;
    sem = 1;
    type = t;
    t = t->toBasetype();
    switch (t->ty)
    {
        case Tpointer:
        case Tsarray:
        case Tarray:
            break;

        default:
            error(loc, "cannot use array to initialize %s", type->toChars());
            goto Lerr;
    }

    length = 0;
    for (i = 0; i < index.dim; i++)
    {
        Expression *idx = index[i];
        if (idx)
        {   idx = idx->semantic(sc);
            idx = idx->optimize(WANTvalue | WANTinterpret);
            index[i] = idx;
            length = idx->toInteger();
        }

        Initializer *val = value[i];
        val = val->semantic(sc, t->nextOf(), needInterpret);
        value[i] = val;
        length++;
        if (length == 0)
        {   error(loc, "array dimension overflow");
            goto Lerr;
        }
        if (length > dim)
            dim = length;
    }
    if (t->ty == Tsarray)
    {
        dinteger_t edim = ((TypeSArray *)t)->dim->toInteger();
        if (dim > edim)
        {
            error(loc, "array initializer has %u elements, but array length is %lld", dim, edim);
            goto Lerr;
        }
    }

    if ((unsigned long) dim * t->nextOf()->size() >= amax)
    {   error(loc, "array dimension %u exceeds max of %u", dim, amax / t->nextOf()->size());
        goto Lerr;
    }
    return this;

Lerr:
    return new ExpInitializer(loc, new ErrorExp());
}

/********************************
 * If possible, convert array initializer to array literal.
 * Otherwise return NULL.
 */

Expression *ArrayInitializer::toExpression()
{   Expressions *elements;

    //printf("ArrayInitializer::toExpression(), dim = %d\n", dim);
    //static int i; if (++i == 2) halt();

    size_t edim;
    Type *t = NULL;
    if (type)
    {
        if (type == Type::terror)
            return new ErrorExp();

        t = type->toBasetype();
        switch (t->ty)
        {
           case Tsarray:
               edim = ((TypeSArray *)t)->dim->toInteger();
               break;

           case Tpointer:
           case Tarray:
               edim = dim;
               break;

           default:
               assert(0);
        }
    }
    else
    {
        edim = value.dim;
        for (size_t i = 0, j = 0; i < value.dim; i++, j++)
        {
            if (index[i])
                j = index[i]->toInteger();
            if (j >= edim)
                edim = j + 1;
        }
    }

    elements = new Expressions();
    elements->setDim(edim);
    elements->zero();
    for (size_t i = 0, j = 0; i < value.dim; i++, j++)
    {
        if (index[i])
            j = (index[i])->toInteger();
        assert(j < edim);
        Initializer *iz = value[i];
        if (!iz)
            goto Lno;
        Expression *ex = iz->toExpression();
        if (!ex)
        {
            goto Lno;
        }
        (*elements)[j] = ex;
    }

    /* Fill in any missing elements with the default initializer
     */
    {
    Expression *init = NULL;
    for (size_t i = 0; i < edim; i++)
    {
        if (!(*elements)[i])
        {
            if (!type)
                goto Lno;
            if (!init)
                init = ((TypeNext *)t)->next->defaultInit();
            (*elements)[i] = init;
        }
    }

    Expression *e = new ArrayLiteralExp(loc, elements);
    e->type = type;
    return e;
    }

Lno:
    return NULL;
}


/********************************
 * If possible, convert array initializer to associative array initializer.
 */

Expression *ArrayInitializer::toAssocArrayLiteral()
{
    Expression *e;

    //printf("ArrayInitializer::toAssocArrayInitializer()\n");
    //static int i; if (++i == 2) halt();
    Expressions *keys = new Expressions();
    keys->setDim(value.dim);
    Expressions *values = new Expressions();
    values->setDim(value.dim);

    for (size_t i = 0; i < value.dim; i++)
    {
        e = index[i];
        if (!e)
            goto Lno;
        (*keys)[i] = e;

        Initializer *iz = value[i];
        if (!iz)
            goto Lno;
        e = iz->toExpression();
        if (!e)
            goto Lno;
        (*values)[i] = e;
    }
    e = new AssocArrayLiteralExp(loc, keys, values);
    return e;

Lno:
    delete keys;
    delete values;
    error(loc, "not an associative array initializer");
    return new ErrorExp();
}

int ArrayInitializer::isAssociativeArray()
{
    for (size_t i = 0; i < value.dim; i++)
    {
        if (index[i])
            return 1;
    }
    return 0;
}

Type *ArrayInitializer::inferType(Scope *sc)
{
    //printf("ArrayInitializer::inferType() %s\n", toChars());
    assert(0);
    return NULL;
#if 0
    type = Type::terror;
    for (size_t i = 0; i < value.dim; i++)
    {
        if (index.data[i])
            goto Laa;
    }
    for (size_t i = 0; i < value.dim; i++)
    {
        Initializer *iz = (Initializer *)value.data[i];
        if (iz)
        {   Type *t = iz->inferType(sc);
            if (i == 0)
            {   /* BUG: This gets the type from the first element.
                 * Fix to use all the elements to figure out the type.
                 */
                t = new TypeSArray(t, new IntegerExp(value.dim));
                t = t->semantic(loc, sc);
                type = t;
            }
        }
    }
    return type;

Laa:
    /* It's possibly an associative array initializer.
     * BUG: inferring type from first member.
     */
    Initializer *iz = (Initializer *)value.data[0];
    Expression *indexinit = (Expression *)index.data[0];
    if (iz && indexinit)
    {   Type *t = iz->inferType(sc);
        indexinit = indexinit->semantic(sc);
        Type *indext = indexinit->type;
        t = new TypeAArray(t, indext);
        type = t->semantic(loc, sc);
    }
    else
        error(loc, "cannot infer type from this array initializer");
    return type;
#endif
}


void ArrayInitializer::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writebyte('[');
    for (size_t i = 0; i < index.dim; i++)
    {
        if (i > 0)
            buf->writebyte(',');
        Expression *ex = index[i];
        if (ex)
        {
            ex->toCBuffer(buf, hgs);
            buf->writebyte(':');
        }
        Initializer *iz = value[i];
        if (iz)
            iz->toCBuffer(buf, hgs);
    }
    buf->writebyte(']');
}


/********************************** ExpInitializer ************************************/

ExpInitializer::ExpInitializer(Loc loc, Expression *exp)
    : Initializer(loc)
{
    this->exp = exp;
}

Initializer *ExpInitializer::syntaxCopy()
{
    return new ExpInitializer(loc, exp->syntaxCopy());
}

bool arrayHasNonConstPointers(Expressions *elems);

bool hasNonConstPointers(Expression *e)
{
    if (e->op == TOKnull)
        return false;
    if (e->op == TOKstructliteral)
    {
        StructLiteralExp *se = (StructLiteralExp *)e;
        return arrayHasNonConstPointers(se->elements);
    }
    if (e->op == TOKarrayliteral)
    {
        if (!e->type->nextOf()->hasPointers())
            return false;
        ArrayLiteralExp *ae = (ArrayLiteralExp *)e;
        return arrayHasNonConstPointers(ae->elements);
    }
    if (e->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *ae = (AssocArrayLiteralExp *)e;
        if (ae->type->nextOf()->hasPointers() &&
            arrayHasNonConstPointers(ae->values))
                return true;
        if (((TypeAArray *)ae->type)->index->hasPointers())
            return arrayHasNonConstPointers(ae->keys);
        return false;
    }
    if (e->type->ty== Tpointer && e->type->nextOf()->ty != Tfunction)
    {
        if (e->op == TOKsymoff) // address of a global is OK
            return false;
        if (e->op == TOKint64)  // cast(void *)int is OK
            return false;
        if (e->op == TOKstring) // "abc".ptr is OK
            return false;
        return true;
    }
    return false;
}

bool arrayHasNonConstPointers(Expressions *elems)
{
    for (size_t i = 0; i < elems->dim; i++)
    {   Expression *e = (*elems)[i];
        if (e && hasNonConstPointers(e))
            return true;
    }
    return false;
}



Initializer *ExpInitializer::semantic(Scope *sc, Type *t, int needInterpret)
{
    //printf("ExpInitializer::semantic(%s), type = %s\n", exp->toChars(), t->toChars());
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    int wantOptimize = needInterpret ? WANTinterpret|WANTvalue : WANTvalue;

    int olderrors = global.errors;
    exp = exp->optimize(wantOptimize);
    if (!global.gag && olderrors != global.errors)
        return this; // Failed, suppress duplicate error messages

    if (exp->op == TOKtype)
        exp->error("initializer must be an expression, not '%s'", exp->toChars());

    // Make sure all pointers are constants
    if (needInterpret && hasNonConstPointers(exp))
    {
        exp->error("cannot use non-constant CTFE pointer in an initializer '%s'", exp->toChars());
        return this;
    }

    Type *tb = t->toBasetype();

    /* Look for case of initializing a static array with a too-short
     * string literal, such as:
     *  char[5] foo = "abc";
     * Allow this by doing an explicit cast, which will lengthen the string
     * literal.
     */
    if (exp->op == TOKstring && tb->ty == Tsarray && exp->type->ty == Tsarray)
    {   StringExp *se = (StringExp *)exp;

        if (!se->committed && se->type->ty == Tsarray &&
            ((TypeSArray *)se->type)->dim->toInteger() <
            ((TypeSArray *)t)->dim->toInteger())
        {
            exp = se->castTo(sc, t);
            goto L1;
        }
    }

    // Look for the case of statically initializing an array
    // with a single member.
    if (tb->ty == Tsarray &&
        !tb->nextOf()->equals(exp->type->toBasetype()->nextOf()) &&
        exp->implicitConvTo(tb->nextOf())
       )
    {
        t = tb->nextOf();
    }

    exp = exp->implicitCastTo(sc, t);
L1:
    exp = exp->optimize(wantOptimize);
    //printf("-ExpInitializer::semantic(): "); exp->print();
    return this;
}

Type *ExpInitializer::inferType(Scope *sc)
{
    //printf("ExpInitializer::inferType() %s\n", toChars());
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    if (exp->op == TOKimport)
    {   ScopeExp *se = (ScopeExp *)exp;
        TemplateInstance *ti = se->sds->isTemplateInstance();
        if (ti && ti->semanticRun == PASSsemantic && !ti->aliasdecl)
            se->error("cannot infer type from %s %s, possible circular dependency", se->sds->kind(), se->toChars());
        else
            se->error("cannot infer type from %s %s", se->sds->kind(), se->toChars());
        return Type::terror;
    }

    // Give error for overloaded function addresses
    if (exp->op == TOKsymoff)
    {   SymOffExp *se = (SymOffExp *)exp;
        if (se->hasOverloads && !se->var->isFuncDeclaration()->isUnique())
            exp->error("cannot infer type from overloaded function symbol %s", exp->toChars());
    }

    // Give error for overloaded function addresses
    if (exp->op == TOKdelegate)
    {   DelegateExp *se = (DelegateExp *)exp;
        if (se->hasOverloads &&
            se->func->isFuncDeclaration() &&
            !se->func->isFuncDeclaration()->isUnique())
            exp->error("cannot infer type from overloaded function symbol %s", exp->toChars());
    }

    Type *t = exp->type;
    if (!t)
        t = Initializer::inferType(sc);
    return t;
}

Expression *ExpInitializer::toExpression()
{
    return exp;
}


void ExpInitializer::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    exp->toCBuffer(buf, hgs);
}



