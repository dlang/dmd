
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

/********************************** Initializer *******************************/

Initializer::Initializer(Loc loc)
{
    this->loc = loc;
}

Initializer *Initializer::syntaxCopy()
{
    return this;
}

Initializer *Initializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
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


Initializer *VoidInitializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
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

Initializer *StructInitializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
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
        size_t nfields = ad->fields.dim;
#if DMDV2
        if (((StructDeclaration *)ad)->isnested)
            nfields--;          // don't count pointer to outer
#endif
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

    //printf("StructInitializer::toExpression() %s\n", toChars());
    if (!ad)                            // if fwd referenced
    {
        return NULL;
    }
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
    for (size_t i = 0; i < elements->dim; )
    {
        VarDeclaration * vd = ad->fields[i]->isVarDeclaration();
        int unionSize = ad->numFieldsInUnion(i);
        if (unionSize == 1)
        {   // Not a union -- default initialize if missing
            if (!(*elements)[i])
            {   // Default initialize
                if (vd->init)
                    (*elements)[i] = vd->init->toExpression();
                else
                    (*elements)[i] = vd->type->defaultInit();
            }
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

Initializer *ArrayInitializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
{   unsigned i;
    unsigned length;
    const unsigned amax = 0x80000000;

    //printf("ArrayInitializer::semantic(%s)\n", t->toChars());
    if (sem)                            // if semantic() already run
        return this;
    sem = 1;
    type = t;
    Initializer *aa = NULL;
    t = t->toBasetype();
    switch (t->ty)
    {
        case Tpointer:
        case Tsarray:
        case Tarray:
            break;

        case Taarray:
            // was actually an associative array literal
            aa = toAssocArrayInitializer();
            return aa->semantic(sc, t, needInterpret);

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
            idx = idx->ctfeInterpret();
            index[i] = idx;
            length = idx->toInteger();
        }

        Initializer *val = value[i];
        ExpInitializer *ei = val->isExpInitializer();
        if (ei && !idx)
            ei->expandTuples = 1;
        val = val->semantic(sc, t->nextOf(), needInterpret);

        ei = val->isExpInitializer();
        // found a tuple, expand it
        if (ei && ei->exp->op == TOKtuple)
        {
            TupleExp *te = (TupleExp *)ei->exp;
            index.remove(i);
            value.remove(i);

            for (size_t j = 0; j < te->exps->dim; ++j)
            {
                Expression *e = (*te->exps)[j];
                index.insert(i + j, (Expression *)NULL);
                value.insert(i + j, new ExpInitializer(e->loc, e));
            }
            i--;
            continue;
        }
        else
        {
            value[i] = val;
        }

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
            error(loc, "array initializer has %u elements, but array length is %jd", dim, edim);
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
            {
                if (index[i]->op == TOKint64)
                    j = index[i]->toInteger();
                else
                    goto Lno;
            }
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
                init = t->next->defaultInit();
            (*elements)[i] = init;
        }
    }

    Expression *e = new ArrayLiteralExp(loc, elements);
    e->type = type;
    return e;
    }

Lno:
    delete elements;
    error(loc, "array initializers as expressions are not allowed");
    return new ErrorExp();
}


/********************************
 * If possible, convert array initializer to associative array initializer.
 */

Initializer *ArrayInitializer::toAssocArrayInitializer()
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
    return new ExpInitializer(loc, e);

Lno:
    delete keys;
    delete values;
    error(loc, "not an associative array initializer");
    return this;
}


Type *ArrayInitializer::inferType(Scope *sc)
{
    for (size_t i = 0; i < value.dim; i++)
    {
        if (index.data[i])
            goto Laa;
    }
    if (value.dim)
    {
        Initializer *iz = (Initializer *)value.data[0];
        if (iz)
        {   Type *t = iz->inferType(sc);
            t = new TypeSArray(t, new IntegerExp(value.dim));
            t = t->semantic(loc, sc);
            return t;
        }
    }

Laa:
    /* It's possibly an associative array initializer
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
    this->expandTuples = 0;
}

Initializer *ExpInitializer::syntaxCopy()
{
    return new ExpInitializer(loc, exp->syntaxCopy());
}

Initializer *ExpInitializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
{
    //printf("ExpInitializer::semantic(%s), type = %s\n", exp->toChars(), t->toChars());
    exp = exp->semantic(sc);
    if (exp->op == TOKerror)
        return this;

    int olderrors = global.errors;
    if (needInterpret)
        exp = exp->ctfeInterpret();
    else
        exp = exp->optimize(WANTvalue);
    if (!global.gag && olderrors != global.errors)
        return this; // Failed, suppress duplicate error messages

    if (exp->op == TOKtype)
        exp->error("initializer must be an expression, not '%s'", exp->toChars());
    Type *tb = t->toBasetype();

    if (exp->op == TOKtuple &&
        expandTuples &&
        !exp->implicitConvTo(t))
        return new ExpInitializer(loc, exp);

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
    if (exp->op == TOKerror)
        return this;
L1:
    if (needInterpret)
        exp = exp->ctfeInterpret();
    else
        exp = exp->optimize(WANTvalue);
    //printf("-ExpInitializer::semantic(): "); exp->print();
    return this;
}

Type *ExpInitializer::inferType(Scope *sc)
{
    //printf("ExpInitializer::inferType() %s\n", toChars());
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);

    // Give error for overloaded function addresses
    if (exp->op == TOKsymoff)
    {   SymOffExp *se = (SymOffExp *)exp;
        if (
#if DMDV2
            se->hasOverloads &&
#else
            se->var->isFuncDeclaration() &&
#endif
            !se->var->isFuncDeclaration()->isUnique())
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



