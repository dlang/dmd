
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/init.c
 */

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
#include "id.h"
#include "tokens.h"

/********************************** Initializer *******************************/

Initializer::Initializer(Loc loc)
{
    this->loc = loc;
}

Initializers *Initializer::arraySyntaxCopy(Initializers *ai)
{
    Initializers *a = NULL;
    if (ai)
    {
        a = new Initializers();
        a->setDim(ai->dim);
        for (size_t i = 0; i < a->dim; i++)
            (*a)[i] = (*ai)[i]->syntaxCopy();
    }
    return a;
}

char *Initializer::toChars()
{
    OutBuffer buf;
    HdrGenState hgs;
    ::toCBuffer(this, &buf, &hgs);
    return buf.extractString();
}

/********************************** ErrorInitializer ***************************/

ErrorInitializer::ErrorInitializer()
    : Initializer(Loc())
{
}

Initializer *ErrorInitializer::syntaxCopy()
{
    return this;
}

Initializer *ErrorInitializer::inferType(Scope *sc)
{
    return this;
}

Initializer *ErrorInitializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
{
    //printf("ErrorInitializer::semantic(t = %p)\n", t);
    return this;
}

Expression *ErrorInitializer::toExpression(Type *t)
{
    return new ErrorExp();
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

Initializer *VoidInitializer::inferType(Scope *sc)
{
    error(loc, "cannot infer type from void initializer");
    return new ErrorInitializer();
}

Initializer *VoidInitializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
{
    //printf("VoidInitializer::semantic(t = %p)\n", t);
    type = t;
    return this;
}

Expression *VoidInitializer::toExpression(Type *t)
{
    return NULL;
}

/********************************** StructInitializer *************************/

StructInitializer::StructInitializer(Loc loc)
    : Initializer(loc)
{
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
        ai->value[i] = value[i]->syntaxCopy();
    }
    return ai;
}

void StructInitializer::addInit(Identifier *field, Initializer *value)
{
    //printf("StructInitializer::addInit(field = %p, value = %p)\n", field, value);
    this->field.push(field);
    this->value.push(value);
}

Initializer *StructInitializer::inferType(Scope *sc)
{
    error(loc, "cannot infer type from struct initializer");
    return new ErrorInitializer();
}

Initializer *StructInitializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
{
    //printf("StructInitializer::semantic(t = %s) %s\n", t->toChars(), toChars());
    t = t->toBasetype();
    if (t->ty == Tsarray && t->nextOf()->toBasetype()->ty == Tstruct)
        t = t->nextOf()->toBasetype();
    if (t->ty == Tstruct)
    {
        StructDeclaration *sd = ((TypeStruct *)t)->sym;
        if (sd->ctor)
        {
            error(loc, "%s %s has constructors, cannot use { initializers }, use %s( initializers ) instead",
                sd->kind(), sd->toChars(), sd->toChars());
            return new ErrorInitializer();
        }
        sd->size(loc);
        if (sd->sizeok != SIZEOKdone)
            return new ErrorInitializer();
        size_t nfields = sd->fields.dim - sd->isNested();

        //expandTuples for non-identity arguments?

        Expressions *elements = new Expressions();
        elements->setDim(nfields);
        for (size_t i = 0; i < elements->dim; i++)
            (*elements)[i] = NULL;

        // Run semantic for explicitly given initializers
        // TODO: this part is slightly different from StructLiteralExp::semantic.
        bool errors = false;
        for (size_t fieldi = 0, i = 0; i < field.dim; i++)
        {
            if (Identifier *id = field[i])
            {
                Dsymbol *s = sd->search(loc, id);
                if (!s)
                {
                    s = sd->search_correct(id);
                    if (s)
                        error(loc, "'%s' is not a member of '%s', did you mean '%s %s'?",
                              id->toChars(), sd->toChars(), s->kind(), s->toChars());
                    else
                        error(loc, "'%s' is not a member of '%s'", id->toChars(), sd->toChars());
                    return new ErrorInitializer();
                }
                s = s->toAlias();

                // Find out which field index it is
                for (fieldi = 0; 1; fieldi++)
                {
                    if (fieldi >= nfields)
                    {
                        error(loc, "%s.%s is not a per-instance initializable field",
                            sd->toChars(), s->toChars());
                        return new ErrorInitializer();
                    }
                    if (s == sd->fields[fieldi])
                        break;
                }
            }
            else if (fieldi >= nfields)
            {
                error(loc, "too many initializers for %s", sd->toChars());
                return new ErrorInitializer();
            }

            VarDeclaration *vd = sd->fields[fieldi];
            if ((*elements)[fieldi])
            {
                error(loc, "duplicate initializer for field '%s'", vd->toChars());
                errors = true;
                continue;
            }
            for (size_t j = 0; j < nfields; j++)
            {
                VarDeclaration *v2 = sd->fields[j];
                bool overlap = (vd->offset < v2->offset + v2->type->size() &&
                                v2->offset < vd->offset + vd->type->size());
                if (overlap && (*elements)[j])
                {
                    error(loc, "overlapping initialization for field %s and %s",
                        v2->toChars(), vd->toChars());
                    errors = true;
                    continue;
                }
            }

            assert(sc);
            Initializer *iz = value[i];
            iz = iz->semantic(sc, vd->type->addMod(t->mod), needInterpret);
            Expression *ex = iz->toExpression();
            if (ex->op == TOKerror)
            {
                errors = true;
                continue;
            }
            value[i] = iz;
            (*elements)[fieldi] = ex;
            ++fieldi;
        }
        if (errors)
            return new ErrorInitializer();

        StructLiteralExp *sle = new StructLiteralExp(loc, sd, elements, t);
        if (!sd->fill(loc, elements, false))
            return new ErrorInitializer();
        sle->type = t;

        ExpInitializer *ie = new ExpInitializer(loc, sle);
        return ie->semantic(sc, t, needInterpret);
    }
    else if ((t->ty == Tdelegate || t->ty == Tpointer && t->nextOf()->ty == Tfunction) && value.dim == 0)
    {
        TOK tok = (t->ty == Tdelegate) ? TOKdelegate : TOKfunction;
        /* Rewrite as empty delegate literal { }
         */
        Parameters *parameters = new Parameters;
        Type *tf = new TypeFunction(parameters, NULL, 0, LINKd);
        FuncLiteralDeclaration *fd = new FuncLiteralDeclaration(loc, Loc(), tf, tok, NULL);
        fd->fbody = new CompoundStatement(loc, new Statements());
        fd->endloc = loc;
        Expression *e = new FuncExp(loc, fd);
        ExpInitializer *ie = new ExpInitializer(loc, e);
        return ie->semantic(sc, t, needInterpret);
    }

    error(loc, "a struct is not a valid initializer for a %s", t->toChars());
    return new ErrorInitializer();
}

/***************************************
 * This works by transforming a struct initializer into
 * a struct literal. In the future, the two should be the
 * same thing.
 */
Expression *StructInitializer::toExpression(Type *t)
{
    // cannot convert to an expression without target 'ad'
    return NULL;
}

/********************************** ArrayInitializer ************************************/

ArrayInitializer::ArrayInitializer(Loc loc)
    : Initializer(loc)
{
    dim = 0;
    type = NULL;
    sem = false;
}

Initializer *ArrayInitializer::syntaxCopy()
{
    //printf("ArrayInitializer::syntaxCopy()\n");
    ArrayInitializer *ai = new ArrayInitializer(loc);
    assert(index.dim == value.dim);
    ai->index.setDim(index.dim);
    ai->value.setDim(value.dim);
    for (size_t i = 0; i < ai->value.dim; i++)
    {
        ai->index[i] = index[i] ? index[i]->syntaxCopy() : NULL;
        ai->value[i] = value[i]->syntaxCopy();
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

bool ArrayInitializer::isAssociativeArray()
{
    for (size_t i = 0; i < value.dim; i++)
    {
        if (index[i])
            return true;
    }
    return false;
}

Initializer *ArrayInitializer::inferType(Scope *sc)
{
    //printf("ArrayInitializer::inferType() %s\n", toChars());
    Expressions *keys = NULL;
    Expressions *values;
    if (isAssociativeArray())
    {
        keys = new Expressions();
        keys->setDim(value.dim);
        values = new Expressions();
        values->setDim(value.dim);

        for (size_t i = 0; i < value.dim; i++)
        {
            Expression *e = index[i];
            if (!e)
                goto Lno;
            (*keys)[i] = e;

            Initializer *iz = value[i];
            if (!iz)
                goto Lno;
            iz = iz->inferType(sc);
            if (iz->isErrorInitializer())
                return iz;
            assert(iz->isExpInitializer());
            (*values)[i] = ((ExpInitializer *)iz)->exp;
            assert((*values)[i]->op != TOKerror);
        }

        Expression *e = new AssocArrayLiteralExp(loc, keys, values);
        ExpInitializer *ei = new ExpInitializer(loc, e);
        return ei->inferType(sc);
    }
    else
    {
        Expressions *elements = new Expressions();
        elements->setDim(value.dim);
        elements->zero();

        for (size_t i = 0; i < value.dim; i++)
        {
            assert(!index[i]);  // already asserted by isAssociativeArray()

            Initializer *iz = value[i];
            if (!iz)
                goto Lno;
            iz = iz->inferType(sc);
            if (iz->isErrorInitializer())
                return iz;
            assert(iz->isExpInitializer());
            (*elements)[i] = ((ExpInitializer *)iz)->exp;
            assert((*elements)[i]->op != TOKerror);
        }

        Expression *e = new ArrayLiteralExp(loc, elements);
        ExpInitializer *ei = new ExpInitializer(loc, e);
        return ei->inferType(sc);
    }
Lno:
    if (keys)
    {
        delete keys;
        delete values;
        error(loc, "not an associative array initializer");
    }
    else
    {
        error(loc, "cannot infer type from array initializer");
    }
    return new ErrorInitializer();
}

Initializer *ArrayInitializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
{
    size_t length;
    const unsigned amax = 0x80000000;
    bool errors = false;

    //printf("ArrayInitializer::semantic(%s)\n", t->toChars());
    if (sem)                            // if semantic() already run
        return this;
    sem = true;
    t = t->toBasetype();
    switch (t->ty)
    {
        case Tsarray:
        case Tarray:
            break;

        case Tvector:
            t = ((TypeVector *)t)->basetype;
            break;

        case Taarray:
        case Tstruct:   // consider implicit constructor call
        {
            Expression *e;
            // note: MyStruct foo = [1:2, 3:4] is correct code if MyStruct has a this(int[int])
            if (t->ty == Taarray || isAssociativeArray())
                e = toAssocArrayLiteral();
            else
                e = toExpression();
            ExpInitializer *ei = new ExpInitializer(e->loc, e);
            return ei->semantic(sc, t, needInterpret);
        }
        case Tpointer:
            if (t->nextOf()->ty != Tfunction)
                break;

        default:
            error(loc, "cannot use array to initialize %s", t->toChars());
            goto Lerr;
    }

    type = t;

    length = 0;
    for (size_t i = 0; i < index.dim; i++)
    {
        Expression *idx = index[i];
        if (idx)
        {
            sc = sc->startCTFE();
            idx = idx->semantic(sc);
            sc = sc->endCTFE();
            idx = idx->ctfeInterpret();
            index[i] = idx;
            length = (size_t)idx->toInteger();
            if (idx->op == TOKerror)
                errors = true;
        }

        Initializer *val = value[i];
        ExpInitializer *ei = val->isExpInitializer();
        if (ei && !idx)
            ei->expandTuples = true;
        val = val->semantic(sc, t->nextOf(), needInterpret);
        if (val->isErrorInitializer())
            errors = true;

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
        {
            error(loc, "array dimension overflow");
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
    if (errors)
        goto Lerr;

    if ((uinteger_t) dim * t->nextOf()->size() >= amax)
    {
        error(loc, "array dimension %u exceeds max of %u", (unsigned) dim, (unsigned)(amax / t->nextOf()->size()));
        goto Lerr;
    }
    return this;

Lerr:
    return new ErrorInitializer();
}

/********************************
 * If possible, convert array initializer to array literal.
 * Otherwise return NULL.
 */

Expression *ArrayInitializer::toExpression(Type *tx)
{
    //printf("ArrayInitializer::toExpression(), dim = %d\n", dim);
    //static int i; if (++i == 2) halt();

    Expressions *elements;
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
               edim = (size_t)((TypeSArray *)t)->dim->toInteger();
               break;

           case Tvector:
               t = ((TypeVector *)t)->basetype;
               edim = (size_t)((TypeSArray *)t)->dim->toInteger();
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
                    j = (size_t)index[i]->toInteger();
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
            j = (size_t)(index[i])->toInteger();
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

    for (size_t i = 0; i < edim; i++)
    {
        Expression *e = (*elements)[i];
        if (e->op == TOKerror)
            return e;
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

/********************************** ExpInitializer ************************************/

ExpInitializer::ExpInitializer(Loc loc, Expression *exp)
    : Initializer(loc)
{
    this->exp = exp;
    this->expandTuples = false;
}

Initializer *ExpInitializer::syntaxCopy()
{
    return new ExpInitializer(loc, exp->syntaxCopy());
}

#if 1   // should be removed and rely on ctfeInterpreter()
bool arrayHasNonConstPointers(Expressions *elems);

bool hasNonConstPointers(Expression *e)
{
    if (e->type->ty == Terror)
        return false;

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
    if(e->op == TOKaddress)
    {
        AddrExp *ae = (AddrExp *)e;
        if (ae->e1->op == TOKstructliteral)
        {
            StructLiteralExp *se = (StructLiteralExp *)ae->e1;
            if (!(se->stageflags & stageSearchPointers))
            {
                int old = se->stageflags;
                se->stageflags |= stageSearchPointers;
                bool ret = arrayHasNonConstPointers(se->elements);
                se->stageflags = old;
                return ret;
            }
            else
            {
                return false;
            }
        }
        return true;
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
    {
        Expression *e = (*elems)[i];
        if (e && hasNonConstPointers(e))
            return true;
    }
    return false;
}
#endif

Initializer *ExpInitializer::inferType(Scope *sc)
{
    //printf("ExpInitializer::inferType() %s\n", toChars());
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);

    if (exp->op == TOKimport)
    {
        ScopeExp *se = (ScopeExp *)exp;
        TemplateInstance *ti = se->sds->isTemplateInstance();
        if (ti && ti->semanticRun == PASSsemantic && !ti->aliasdecl)
            se->error("cannot infer type from %s %s, possible circular dependency", se->sds->kind(), se->toChars());
        else
            se->error("cannot infer type from %s %s", se->sds->kind(), se->toChars());
        return new ErrorInitializer();
    }

    // Give error for overloaded function addresses
    if (exp->op == TOKsymoff)
    {
        SymOffExp *se = (SymOffExp *)exp;
        if (se->hasOverloads && !se->var->isFuncDeclaration()->isUnique())
        {
            exp->error("cannot infer type from overloaded function symbol %s", exp->toChars());
            return new ErrorInitializer();
        }
    }
    if (exp->op == TOKdelegate)
    {
        DelegateExp *se = (DelegateExp *)exp;
        if (se->hasOverloads &&
            se->func->isFuncDeclaration() &&
            !se->func->isFuncDeclaration()->isUnique())
        {
            exp->error("cannot infer type from overloaded function symbol %s", exp->toChars());
            return new ErrorInitializer();
        }
    }
    if (exp->op == TOKaddress)
    {
        AddrExp *ae = (AddrExp *)exp;
        if (ae->e1->op == TOKoverloadset)
        {
            exp->error("cannot infer type from overloaded function symbol %s", exp->toChars());
            return new ErrorInitializer();
        }
    }

    if (exp->op == TOKerror)
        return new ErrorInitializer();
    if (!exp->type)
        return new ErrorInitializer();
    return this;
}

Initializer *ExpInitializer::semantic(Scope *sc, Type *t, NeedInterpret needInterpret)
{
    //printf("ExpInitializer::semantic(%s), type = %s\n", exp->toChars(), t->toChars());
    if (needInterpret) sc = sc->startCTFE();
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    if (needInterpret) sc = sc->endCTFE();
    if (exp->op == TOKerror)
        return new ErrorInitializer();

    unsigned int olderrors = global.errors;
    if (needInterpret)
    {
        // If the result will be implicitly cast, move the cast into CTFE
        // to avoid premature truncation of polysemous types.
        // eg real [] x = [1.1, 2.2]; should use real precision.
        if (exp->implicitConvTo(t))
        {
            exp = exp->implicitCastTo(sc, t);
        }
        exp = exp->ctfeInterpret();
    }
    else
    {
        exp = exp->optimize(WANTvalue);
    }
    if (!global.gag && olderrors != global.errors)
        return this; // Failed, suppress duplicate error messages

    if (exp->type->ty == Ttuple && ((TypeTuple *)exp->type)->arguments->dim == 0)
    {
        Type *et = exp->type;
        exp = new TupleExp(exp->loc, new Expressions());
        exp->type = et;
    }
    if (exp->op == TOKtype)
    {
        exp->error("initializer must be an expression, not '%s'", exp->toChars());
        return new ErrorInitializer();
    }

    // Make sure all pointers are constants
    if (needInterpret && hasNonConstPointers(exp))
    {
        exp->error("cannot use non-constant CTFE pointer in an initializer '%s'", exp->toChars());
        return new ErrorInitializer();
    }

    Type *tb = t->toBasetype();
    Type *ti = exp->type->toBasetype();

    if (exp->op == TOKtuple && expandTuples && !exp->implicitConvTo(t))
        return new ExpInitializer(loc, exp);

    /* Look for case of initializing a static array with a too-short
     * string literal, such as:
     *  char[5] foo = "abc";
     * Allow this by doing an explicit cast, which will lengthen the string
     * literal.
     */
    if (exp->op == TOKstring && tb->ty == Tsarray)
    {
        StringExp *se = (StringExp *)exp;
        Type *typeb = se->type->toBasetype();
        TY tynto = tb->nextOf()->ty;
        if (!se->committed &&
            (typeb->ty == Tarray || typeb->ty == Tsarray) &&
            (tynto == Tchar || tynto == Twchar || tynto == Tdchar) &&
            se->length((int)tb->nextOf()->size()) < ((TypeSArray *)tb)->dim->toInteger())
        {
            exp = se->castTo(sc, t);
            goto L1;
        }
    }

    // Look for implicit constructor call
    if (tb->ty == Tstruct &&
        !(ti->ty == Tstruct && tb->toDsymbol(sc) == ti->toDsymbol(sc)) &&
        !exp->implicitConvTo(t))
    {
        StructDeclaration *sd = ((TypeStruct *)tb)->sym;
        if (sd->ctor)
        {
            // Rewrite as S().ctor(exp)
            Expression *e;
            e = new StructLiteralExp(loc, sd, NULL);
            e = new DotIdExp(loc, e, Id::ctor);
            e = new CallExp(loc, e, exp);
            e = e->semantic(sc);
            if (needInterpret)
                exp = e->ctfeInterpret();
            else
                exp = e->optimize(WANTvalue);
        }
    }

    // Look for the case of statically initializing an array
    // with a single member.
    if (tb->ty == Tsarray &&
        !tb->nextOf()->equals(ti->toBasetype()->nextOf()) &&
        exp->implicitConvTo(tb->nextOf())
       )
    {
        /* If the variable is not actually used in compile time, array creation is
         * redundant. So delay it until invocation of toExpression() or toDt().
         */
        t = tb->nextOf();
    }

    if (exp->implicitConvTo(t))
    {
        exp = exp->implicitCastTo(sc, t);
    }
    else
    {
        // Look for mismatch of compile-time known length to emit
        // better diagnostic message, as same as AssignExp::semantic.
        if (tb->ty == Tsarray &&
            exp->implicitConvTo(tb->nextOf()->arrayOf()) > MATCHnomatch)
        {
            uinteger_t dim1 = ((TypeSArray *)tb)->dim->toInteger();
            uinteger_t dim2 = dim1;
            if (exp->op == TOKarrayliteral)
            {
                ArrayLiteralExp *ale = (ArrayLiteralExp *)exp;
                dim2 = ale->elements ? ale->elements->dim : 0;
            }
            else if (exp->op == TOKslice)
            {
                Type *tx = toStaticArrayType((SliceExp *)exp);
                if (tx)
                    dim2 = ((TypeSArray *)tx)->dim->toInteger();
            }
            if (dim1 != dim2)
            {
                exp->error("mismatched array lengths, %d and %d", (int)dim1, (int)dim2);
                exp = new ErrorExp();
            }
        }
        exp = exp->implicitCastTo(sc, t);
    }
L1:
    if (exp->op == TOKerror)
        return this;
    if (needInterpret)
        exp = exp->ctfeInterpret();
    else
        exp = exp->optimize(WANTvalue);
    //printf("-ExpInitializer::semantic(): "); exp->print();
    return this;
}

Expression *ExpInitializer::toExpression(Type *t)
{
    if (t)
    {
        //printf("ExpInitializer::toExpression(t = %s) exp = %s\n", t->toChars(), exp->toChars());
        Type *tb = t->toBasetype();
        Expression *e = (exp->op == TOKconstruct || exp->op == TOKblit) ? ((AssignExp *)exp)->e2 : exp;
        if (tb->ty == Tsarray && e->implicitConvTo(tb->nextOf()))
        {
            TypeSArray *tsa = (TypeSArray *)tb;
            size_t d = (size_t)tsa->dim->toInteger();
            Expressions *elements = new Expressions();
            elements->setDim(d);
            for (size_t i = 0; i < d; i++)
                (*elements)[i] = e;
            ArrayLiteralExp *ae = new ArrayLiteralExp(e->loc, elements);
            ae->type = t;
            return ae;
        }
    }
    return exp;
}
