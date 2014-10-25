
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/todt.c
 */

/* A dt_t is a simple structure representing data to be added
 * to the data segment of the output object file. As such,
 * it is a list of initialized bytes, 0 data, and offsets from
 * other symbols.
 * Each D symbol and type can be converted into a dt_t so it can
 * be written to the data segment.
 */

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        <assert.h>

#include        "lexer.h"
#include        "mtype.h"
#include        "expression.h"
#include        "init.h"
#include        "enum.h"
#include        "aggregate.h"
#include        "declaration.h"
#include        "target.h"
#include        "ctfe.h"
#include        "arraytypes.h"
#include        "visitor.h"
// Back end
#include        "dt.h"

typedef Array<struct dt_t *> Dts;

dt_t **Type_toDt(Type *t, dt_t **pdt);
dt_t **toDtElem(TypeSArray *tsa, dt_t **pdt, Expression *e);
void ClassDeclaration_toDt(ClassDeclaration *cd, dt_t **pdt);
void membersToDt(ClassDeclaration *cd, dt_t **pdt, ClassDeclaration *concreteType);
void StructDeclaration_toDt(StructDeclaration *sd, dt_t **pdt);
dt_t **ClassReferenceExp_toDt(ClassReferenceExp *e, dt_t **pdt, int off);
dt_t **ClassReferenceExp_toInstanceDt(ClassReferenceExp *ce, dt_t **pdt);
dt_t **membersToDt(ClassReferenceExp *ce, dt_t **pdt, ClassDeclaration *cd, Dts *dts);
dt_t **ClassReferenceExp_toDt(ClassReferenceExp *e, dt_t **pdt, int off);
Symbol *toSymbol(Dsymbol *s);
dt_t **Expression_toDt(Expression *e, dt_t **pdt);

/* ================================================================ */

dt_t *Initializer_toDt(Initializer *init)
{
    class InitToDt : public Visitor
    {
    public:
        dt_t *result;

        InitToDt()
            : result(NULL)
        {
        }

        void visit(Initializer *)
        {
            assert(0);
        }

        void visit(VoidInitializer *vi)
        {
            /* Void initializers are set to 0, just because we need something
             * to set them to in the static data segment.
             */
            dtnzeros(&result, vi->type->size());
        }

        void visit(StructInitializer *si)
        {
            //printf("StructInitializer::toDt('%s')\n", si->toChars());
            assert(0);
        }

        void visit(ArrayInitializer *ai)
        {
            //printf("ArrayInitializer::toDt('%s')\n", ai->toChars());
            Type *tb = ai->type->toBasetype();
            if (tb->ty == Tvector)
                tb = ((TypeVector *)tb)->basetype;

            Type *tn = tb->nextOf()->toBasetype();

            //printf("\tdim = %d\n", ai->dim);
            Dts dts;
            dts.setDim(ai->dim);
            dts.zero();

            unsigned size = tn->size();

            unsigned length = 0;
            for (size_t i = 0; i < ai->index.dim; i++)
            {
                Expression *idx = ai->index[i];
                if (idx)
                    length = idx->toInteger();
                //printf("\tindex[%d] = %p, length = %u, dim = %u\n", i, idx, length, ai->dim);

                assert(length < ai->dim);
                dt_t *dt = Initializer_toDt(ai->value[i]);
                if (dts[length])
                    error(ai->loc, "duplicate initializations for index %d", length);
                dts[length] = dt;
                length++;
            }

            Expression *edefault = tb->nextOf()->defaultInit();

            size_t n = 1;
            for (Type *tbn = tn; tbn->ty == Tsarray; tbn = tbn->nextOf()->toBasetype())
            {
                TypeSArray *tsa = (TypeSArray *)tbn;
                n *= tsa->dim->toInteger();
            }

            dt_t **pdtend = &result;
            for (size_t i = 0; i < ai->dim; i++)
            {
                dt_t *dt = dts[i];
                if (dt)
                    pdtend = dtcat(pdtend, dt);
                else
                {
                    for (size_t j = 0; j < n; j++)
                        pdtend = Expression_toDt(edefault, pdtend);
                }
            }
            switch (tb->ty)
            {
                case Tsarray:
                {
                    TypeSArray *ta = (TypeSArray *)tb;
                    size_t tadim = ta->dim->toInteger();
                    if (ai->dim < tadim)
                    {
                        if (edefault->isBool(false))
                        {
                            // pad out end of array
                            pdtend = dtnzeros(pdtend, size * (tadim - ai->dim));
                        }
                        else
                        {
                            for (size_t i = ai->dim; i < tadim; i++)
                            {
                                for (size_t j = 0; j < n; j++)
                                    pdtend = Expression_toDt(edefault, pdtend);
                            }
                        }
                    }
                    else if (ai->dim > tadim)
                    {
                        error(ai->loc, "too many initializers, %d, for array[%d]", ai->dim, tadim);
                    }
                    break;
                }

                case Tpointer:
                case Tarray:
                {
                    dt_t *dtarray = result;
                    result = NULL;
                    if (tb->ty == Tarray)
                        dtsize_t(&result, ai->dim);
                    dtdtoff(&result, dtarray, 0);
                    break;
                }

                default:
                    assert(0);
            }
        }

        void visit(ExpInitializer *ei)
        {
            //printf("ExpInitializer::toDt() %s\n", ei->exp->toChars());
            ei->exp = ei->exp->optimize(WANTvalue);
            Expression_toDt(ei->exp, &result);
        }
    };

    InitToDt v;
    init->accept(&v);
    return v.result;
}

/* ================================================================ */

dt_t **Expression_toDt(Expression *e, dt_t **pdt)
{
    class ExpToDt : public Visitor
    {
    public:
        dt_t **pdt;

        ExpToDt(dt_t **pdt)
            : pdt(pdt)
        {
        }

        void visit(Expression *e)
        {
        #if 0
            printf("Expression::toDt() %d\n", e->op);
            print();
        #endif
            e->error("non-constant expression %s", e->toChars());
            pdt = dtnzeros(pdt, 1);
        }

        void visit(CastExp *e)
        {
        #if 0
            printf("CastExp::toDt() %d from %s to %s\n", e->op, e->e1->type->toChars(), e->type->toChars());
        #endif
            if (e->e1->type->ty == Tclass && e->type->ty == Tclass)
            {
                if (((TypeClass *)e->type)->sym->isInterfaceDeclaration()) // casting from class to interface
                {
                    assert(e->e1->op == TOKclassreference);
                    ClassDeclaration *from = ((ClassReferenceExp *)e->e1)->originalClass();
                    InterfaceDeclaration *to = ((TypeClass *)e->type)->sym->isInterfaceDeclaration();
                    int off = 0;
                    int isbase = to->isBaseOf(from, &off);
                    assert(isbase);
                    pdt = ClassReferenceExp_toDt((ClassReferenceExp*)e->e1, pdt, off);
                    return;
                }
                else //casting from class to class
                {
                    pdt = Expression_toDt(e->e1, pdt);
                    return;
                }
            }
            visit((UnaExp *)e);
        }

        void visit(AddrExp *e)
        {
        #if 0
            printf("AddrExp::toDt() %d\n", e->op);
        #endif
            if (e->e1->op == TOKstructliteral)
            {
                StructLiteralExp* sl = (StructLiteralExp *)e->e1;
                dtxoff(pdt, sl->toSymbol(), 0);
                return;
            }
            visit((UnaExp *)e);
        }

        void visit(IntegerExp *e)
        {
            //printf("IntegerExp::toDt() %d\n", e->op);
            unsigned sz = e->type->size();
            dinteger_t value = e->getInteger();
            if (value == 0)
                pdt = dtnzeros(pdt, sz);
            else
                pdt = dtnbytes(pdt, sz, (char *)&value);
        }

        void visit(RealExp *e)
        {
            //printf("RealExp::toDt(%Lg)\n", e->value);
            static char zeropad[6];
            switch (e->type->toBasetype()->ty)
            {
                case Tfloat32:
                case Timaginary32:
                {
                    d_float32 fvalue = e->value;
                    pdt = dtnbytes(pdt,4,(char *)&fvalue);
                    break;
                }

                case Tfloat64:
                case Timaginary64:
                {
                    d_float64 dvalue = e->value;
                    pdt = dtnbytes(pdt,8,(char *)&dvalue);
                    break;
                }

                case Tfloat80:
                case Timaginary80:
                {
                    d_float80 evalue = e->value;
                    pdt = dtnbytes(pdt,Target::realsize - Target::realpad,(char *)&evalue);
                    pdt = dtnbytes(pdt,Target::realpad,zeropad);
                    assert(Target::realpad <= sizeof(zeropad));
                    break;
                }

                default:
                    printf("%s\n", e->toChars());
                    e->type->print();
                    assert(0);
                    break;
            }
        }

        void visit(ComplexExp *e)
        {
            //printf("ComplexExp::toDt() '%s'\n", e->toChars());
            static char zeropad[6];
            switch (e->type->toBasetype()->ty)
            {
                case Tcomplex32:
                {
                    d_float32 fvalue = creall(e->value);
                    pdt = dtnbytes(pdt,4,(char *)&fvalue);
                    fvalue = cimagl(e->value);
                    pdt = dtnbytes(pdt,4,(char *)&fvalue);
                    break;
                }

                case Tcomplex64:
                {
                    d_float64 dvalue = creall(e->value);
                    pdt = dtnbytes(pdt,8,(char *)&dvalue);
                    dvalue = cimagl(e->value);
                    pdt = dtnbytes(pdt,8,(char *)&dvalue);
                    break;
                }

                case Tcomplex80:
                {
                    d_float80 evalue = creall(e->value);
                    pdt = dtnbytes(pdt,Target::realsize - Target::realpad,(char *)&evalue);
                    pdt = dtnbytes(pdt,Target::realpad,zeropad);
                    evalue = cimagl(e->value);
                    pdt = dtnbytes(pdt,Target::realsize - Target::realpad,(char *)&evalue);
                    pdt = dtnbytes(pdt,Target::realpad,zeropad);
                    break;
                }

                default:
                    assert(0);
                    break;
            }
        }

        void visit(NullExp *e)
        {
            assert(e->type);
            pdt = dtnzeros(pdt, e->type->size());
        }

        void visit(StringExp *e)
        {
            //printf("StringExp::toDt() '%s', type = %s\n", e->toChars(), e->type->toChars());
            Type *t = e->type->toBasetype();

            // BUG: should implement some form of static string pooling
            switch (t->ty)
            {
                case Tarray:
                    dtsize_t(pdt, e->len);
                    pdt = dtabytes(pdt, 0, (e->len + 1) * e->sz, (char *)e->string);
                    break;

                case Tsarray:
                {
                    TypeSArray *tsa = (TypeSArray *)t;

                    pdt = dtnbytes(pdt, e->len * e->sz, (const char *)e->string);
                    if (tsa->dim)
                    {
                        dinteger_t dim = tsa->dim->toInteger();
                        if (e->len < dim)
                        {
                            // Pad remainder with 0
                            pdt = dtnzeros(pdt, (dim - e->len) * tsa->next->size());
                        }
                    }
                    break;
                }
                case Tpointer:
                    pdt = dtabytes(pdt, 0, (e->len + 1) * e->sz, (char *)e->string);
                    break;

                default:
                    printf("StringExp::toDt(type = %s)\n", e->type->toChars());
                    assert(0);
            }
        }

        void visit(ArrayLiteralExp *e)
        {
            //printf("ArrayLiteralExp::toDt() '%s', type = %s\n", e->toChars(), e->type->toChars());

            dt_t *d = NULL;
            dt_t **pdtend = &d;
            for (size_t i = 0; i < e->elements->dim; i++)
            {
                pdtend = Expression_toDt((*e->elements)[i], pdtend);
            }
            Type *t = e->type->toBasetype();

            switch (t->ty)
            {
                case Tsarray:
                    pdt = dtcat(pdt, d);
                    break;

                case Tpointer:
                case Tarray:
                    if (t->ty == Tarray)
                        dtsize_t(pdt, e->elements->dim);
                    if (d)
                        dtdtoff(pdt, d, 0);
                    else
                        dtsize_t(pdt, 0);

                    break;

                default:
                    assert(0);
            }
        }

        void visit(StructLiteralExp *se)
        {
            //printf("StructLiteralExp::toDt() %s, ctfe = %d\n", se->toChars(), se->ownedByCtfe);
            assert(se->sd->fields.dim - se->sd->isNested() <= se->elements->dim);

            unsigned offset = 0;
            for (size_t i = 0; i < se->elements->dim; i++)
            {
                Expression *e = (*se->elements)[i];
                if (!e)
                    continue;

                VarDeclaration *vd = NULL;
                size_t k;
                for (size_t j = i; j < se->elements->dim; j++)
                {
                    VarDeclaration *v2 = se->sd->fields[j];
                    if (v2->offset < offset || (*se->elements)[j] == NULL)
                        continue;

                    // find the nearest field
                    if (!vd)
                    {
                        vd = v2;
                        k = j;
                    }
                    else if (v2->offset < vd->offset)
                    {
                        // Each elements should have no overlapping
                        assert(!(vd->offset < v2->offset + v2->type->size() &&
                                 v2->offset < vd->offset + vd->type->size()));
                        vd = v2;
                        k = j;
                    }
                }
                if (vd)
                {
                    if (offset < vd->offset)
                        pdt = dtnzeros(pdt, vd->offset - offset);
                    e = (*se->elements)[k];

                    Type *tb = vd->type->toBasetype();
                    if (tb->ty == Tsarray)
                        toDtElem(((TypeSArray *)tb), pdt, e);
                    else
                        Expression_toDt(e, pdt);           // convert e to an initializer dt

                    offset = vd->offset + vd->type->size();
                }
            }
            if (offset < se->sd->structsize)
                pdt = dtnzeros(pdt, se->sd->structsize - offset);
        }

        void visit(SymOffExp *e)
        {
            //printf("SymOffExp::toDt('%s')\n", e->var->toChars());
            assert(e->var);
            if (!(e->var->isDataseg() || e->var->isCodeseg()) ||
                e->var->needThis() ||
                e->var->isThreadlocal())
            {
        #if 0
                printf("SymOffExp::toDt()\n");
        #endif
                e->error("non-constant expression %s", e->toChars());
                return;
            }
            pdt =  dtxoff(pdt, toSymbol(e->var), e->offset);
        }

        void visit(VarExp *e)
        {
            //printf("VarExp::toDt() %d\n", e->op);
            pdt = dtend(pdt);

            VarDeclaration *v = e->var->isVarDeclaration();
            if (v && (v->isConst() || v->isImmutable()) &&
                e->type->toBasetype()->ty != Tsarray && v->init)
            {
                if (v->inuse)
                {
                    e->error("recursive reference %s", e->toChars());
                    return;
                }
                v->inuse++;
                *pdt = Initializer_toDt(v->init);
                v->inuse--;
                return;
            }
            SymbolDeclaration *sd = e->var->isSymbolDeclaration();
            if (sd && sd->dsym)
            {
                StructDeclaration_toDt(sd->dsym, pdt);
                return;
            }
        #if 0
            printf("VarExp::toDt(), kind = %s\n", e->var->kind());
        #endif
            e->error("non-constant expression %s", e->toChars());
            pdt = dtnzeros(pdt, 1);
        }

        void visit(FuncExp *e)
        {
            //printf("FuncExp::toDt() %d\n", e->op);
            if (e->fd->tok == TOKreserved && e->type->ty == Tpointer)
            {
                // change to non-nested
                e->fd->tok = TOKfunction;
                e->fd->vthis = NULL;
            }
            Symbol *s = toSymbol(e->fd);
            if (e->fd->isNested())
            {
                e->error("non-constant nested delegate literal expression %s", e->toChars());
                pdt = NULL;
                return;
            }
            e->fd->toObjFile(0);
            pdt = dtxoff(pdt, s, 0);
        }

        void visit(VectorExp *e)
        {
            //printf("VectorExp::toDt() %s\n", e->toChars());
            for (size_t i = 0; i < e->dim; i++)
            {
                Expression *elem;
                if (e->e1->op == TOKarrayliteral)
                {
                    ArrayLiteralExp *ea = (ArrayLiteralExp *)e->e1;
                    elem = (*ea->elements)[i];
                }
                else
                    elem = e->e1;
                pdt = Expression_toDt(elem, pdt);
            }
        }

        void visit(ClassReferenceExp *e)
        {
            InterfaceDeclaration* to = ((TypeClass *)e->type)->sym->isInterfaceDeclaration();

            if (to) //Static typeof this literal is an interface. We must add offset to symbol
            {
                ClassDeclaration *from = e->originalClass();
                int off = 0;
                int isbase = to->isBaseOf(from, &off);
                assert(isbase);
                pdt = ClassReferenceExp_toDt(e, pdt, off);
                return;
            }
            pdt = ClassReferenceExp_toDt(e, pdt, 0);
        }
    };

    ExpToDt v(pdt);
    e->accept(&v);
    return v.pdt;
}

/* ================================================================= */

// Generate the data for the static initializer.

void ClassDeclaration_toDt(ClassDeclaration *cd, dt_t **pdt)
{
    //printf("ClassDeclaration::toDt(this = '%s')\n", cd->toChars());

    // Put in first two members, the vtbl[] and the monitor
    dtxoff(pdt, cd->toVtblSymbol(), 0);
    if (!cd->cpp)
        dtsize_t(pdt, 0);                    // monitor

    // Put in the rest
    membersToDt(cd, pdt, cd);

    //printf("-ClassDeclaration::toDt(this = '%s')\n", cd->toChars());
}

void membersToDt(ClassDeclaration *cd, dt_t **pdt, ClassDeclaration *concreteType)
{
    unsigned offset;

    //printf("ClassDeclaration::toDt2(this = '%s', cd = '%s')\n", cd->toChars(), concreteType->toChars());
    if (cd->baseClass)
    {
        membersToDt(cd->baseClass, pdt, concreteType);
        offset = cd->baseClass->structsize;
    }
    else
    {
        if (cd->cpp)
            offset = Target::ptrsize;       // allow room for __vptr
        else
            offset = Target::ptrsize * 2;   // allow room for __vptr and __monitor
    }

    // Note equivalence of this loop to struct's
    for (size_t i = 0; i < cd->fields.dim; i++)
    {
        VarDeclaration *v = cd->fields[i];

        //printf("\t\tv = '%s' v->offset = %2d, offset = %2d\n", v->toChars(), v->offset, offset);
        dt_t *dt = NULL;
        Initializer *init = v->init;
        if (init)
        {
            //printf("\t\t%s has initializer %s\n", v->toChars(), init->toChars());
            ExpInitializer *ei = init->isExpInitializer();
            Type *tb = v->type->toBasetype();
            if (init->isVoidInitializer())
                ;
            else if (ei && tb->ty == Tsarray)
                toDtElem(((TypeSArray *)tb), &dt, ei->exp);
            else
                dt = Initializer_toDt(init);
        }
        else if (v->offset >= offset)
        {
            //printf("\t\tdefault initializer\n");
            Type_toDt(v->type, &dt);
        }
        if (dt)
        {
            if (v->offset < offset)
                cd->error("duplicated union initialization for %s", v->toChars());
            else
            {
                if (offset < v->offset)
                    dtnzeros(pdt, v->offset - offset);
                dtcat(pdt, dt);
                offset = v->offset + v->type->size();
            }
        }
    }

    // Interface vptr initializations
    toSymbol(cd);                                         // define csym

    for (size_t i = 0; i < cd->vtblInterfaces->dim; i++)
    {
        BaseClass *b = (*cd->vtblInterfaces)[i];

        for (ClassDeclaration *cd2 = concreteType; 1; cd2 = cd2->baseClass)
        {
            assert(cd2);
            unsigned csymoffset = cd2->baseVtblOffset(b);
            if (csymoffset != ~0)
            {
                if (offset < b->offset)
                    dtnzeros(pdt, b->offset - offset);
                dtxoff(pdt, toSymbol(cd2), csymoffset);
                break;
            }
        }
        offset = b->offset + Target::ptrsize;
    }

    if (offset < cd->structsize)
        dtnzeros(pdt, cd->structsize - offset);
}

void StructDeclaration_toDt(StructDeclaration *sd, dt_t **pdt)
{
    //printf("StructDeclaration::toDt(), this='%s'\n", sd->toChars());
    StructLiteralExp *sle = StructLiteralExp::create(sd->loc, sd, NULL);
    if (!sd->fill(sd->loc, sle->elements, true))
        assert(0);

    //printf("sd->toDt sle = %s\n", sle->toChars());
    sle->type = sd->type;
    Expression_toDt(sle, pdt);
}

/* ================================================================= */

dt_t **Type_toDt(Type *t, dt_t **pdt)
{
    class TypeToDt : public Visitor
    {
    public:
        dt_t **pdt;

        TypeToDt(dt_t **pdt)
            : pdt(pdt)
        {
        }

        void visit(Type *t)
        {
            //printf("Type::toDt()\n");
            Expression *e = t->defaultInit();
            pdt = Expression_toDt(e, pdt);
        }

        void visit(TypeVector *t)
        {
            assert(t->basetype->ty == Tsarray);
            pdt = toDtElem((TypeSArray *)t->basetype, pdt, NULL);
        }

        void visit(TypeSArray *t)
        {
            pdt = toDtElem(t, pdt, NULL);
        }

        void visit(TypeStruct *t)
        {
            StructDeclaration_toDt(t->sym, pdt);
        }
    };

    TypeToDt v(pdt);
    t->accept(&v);
    return v.pdt;
}

dt_t **toDtElem(TypeSArray *tsa, dt_t **pdt, Expression *e)
{
    //printf("TypeSArray::toDtElem()\n");
    size_t len = tsa->dim->toInteger();
    if (len)
    {
        pdt = dtend(pdt);
        Type *tnext = tsa->next;
        Type *tbn = tnext->toBasetype();
        while (tbn->ty == Tsarray && (!e || tbn != e->type->nextOf()))
        {
            TypeSArray *tsa = (TypeSArray *)tbn;
            len *= tsa->dim->toInteger();
            tnext = tbn->nextOf();
            tbn = tnext->toBasetype();
        }
        if (!e)                             // if not already supplied
            e = tsa->defaultInit(Loc());    // use default initializer
        Expression_toDt(e, pdt);
        dt_optimize(*pdt);
        if (e->op == TOKstring)
            len /= ((StringExp *)e)->len;
        if (e->op == TOKarrayliteral)
            len /= ((ArrayLiteralExp *)e)->elements->dim;
        if (dtallzeros(*pdt))
            pdt = dtnzeros(pdt, dt_size(*pdt) * (len - 1));
        else
        {
            for (size_t i = 1; i < len; i++)
            {
                pdt = Expression_toDt(e, pdt);
            }
        }
    }
    return pdt;
}

/*****************************************************/
/*                   CTFE stuff                      */
/*****************************************************/

dt_t **ClassReferenceExp_toDt(ClassReferenceExp *e, dt_t **pdt, int off)
{
#if 0
    printf("ClassReferenceExp::toDtI() %d\n", e->op);
#endif

    dtxoff(pdt, e->toSymbol(), off);
    return pdt;
}

dt_t **ClassReferenceExp_toInstanceDt(ClassReferenceExp *ce, dt_t **pdt)
{
#if 0
    printf("ClassReferenceExp::toInstanceDt() %d\n", ce->op);
#endif
    dt_t *d = NULL;
    dt_t **pdtend = &d;

    Dts dts;
    dts.setDim(ce->value->elements->dim);
    dts.zero();
    //assert(ce->value->elements->dim <= ce->value->sd->fields.dim);
    for (size_t i = 0; i < ce->value->elements->dim; i++)
    {
        Expression *e = (*ce->value->elements)[i];
        if (!e)
            continue;
        dt_t *dt = NULL;
        Expression_toDt(e, &dt);           // convert e to an initializer dt
        dts[i] = dt;
    }
    dtxoff(pdtend, ce->originalClass()->toVtblSymbol(), 0);
    dtsize_t(pdtend, 0);                    // monitor
    // Put in the rest
    membersToDt(ce, &d, ce->originalClass(), &dts);
    *pdt = d;
    return pdt;
}

// Generates the data for the static initializer of class variable.
// dts is an array of dt fields, which values have been evaluated in compile time.
// cd - is a ClassDeclaration, for which initializing data is being built
// this function, being alike to ClassDeclaration::toDt2, recursively builds the dt for all base classes.
dt_t **membersToDt(ClassReferenceExp *ce, dt_t **pdt, ClassDeclaration *cd, Dts *dts)
{
    unsigned offset;
#define LOG 0

#if LOG
    printf("ClassReferenceExp::toDt2(this = '%s', cd = '%s')\n", ce->toChars(), cd->toChars());
#endif
    if (cd->baseClass)
    {
        membersToDt(ce, pdt, cd->baseClass, dts);
        offset = cd->baseClass->structsize;
    }
    else
    {
        offset = Target::ptrsize * 2;
    }
    for (size_t i = 0; i < cd->fields.dim; i++)
    {
        VarDeclaration *v = cd->fields[i];
        int idx = ce->findFieldIndexByName(v);
        assert(idx != -1);
        dt_t *d = (*dts)[idx];

        if (!d)
        {
            dt_t *dt = NULL;
            Initializer *init = v->init;
            if (init)
            {   //printf("\t\t%s has initializer %s\n", v->toChars(), init->toChars());
                ExpInitializer *ei = init->isExpInitializer();
                Type *tb = v->type->toBasetype();
                if (init->isVoidInitializer())
                    ;
                else if (ei && tb->ty == Tsarray)
                    toDtElem((TypeSArray *)tb, &dt, ei->exp);
                else
                    dt = Initializer_toDt(init);
            }
            else if (v->offset >= offset)
            {
                //printf("\t\tdefault initializer\n");
                Type_toDt(v->type, &dt);
            }
            if (dt)
            {
                if (v->offset < offset)
                    ce->error("duplicated union initialization for %s", v->toChars());
                else
                {
                    if (offset < v->offset)
                        dtnzeros(pdt, v->offset - offset);
                    dtcat(pdt, dt);
                    offset = v->offset + v->type->size();
                }
            }
        }
        else
        {
            if (v->offset < offset)
                ce->error("duplicate union initialization for %s", v->toChars());
            else
            {
                unsigned sz = dt_size(d);
                unsigned vsz = v->type->size();
                unsigned voffset = v->offset;

                if (sz > vsz)
                {
                    assert(v->type->ty == Tsarray && vsz == 0);
                    ce->error("zero length array %s has non-zero length initializer", v->toChars());
                }

                size_t dim = 1;
                Type *vt;
                for (vt = v->type->toBasetype();
                     vt->ty == Tsarray;
                     vt = vt->nextOf()->toBasetype())
                {
                    TypeSArray *tsa = (TypeSArray *)vt;
                    dim *= tsa->dim->toInteger();
                }
                //printf("sz = %d, dim = %d, vsz = %d\n", sz, dim, vsz);
                assert(sz == vsz || sz * dim <= vsz);

                for (size_t i = 0; i < dim; i++)
                {
                    if (offset < voffset)
                        pdt = dtnzeros(pdt, voffset - offset);
                    if (!d)
                    {
                        if (v->init)
                            d = Initializer_toDt(v->init);
                        else
                            Type_toDt(vt, &d);
                    }
                    pdt = dtcat(pdt, d);
                    d = NULL;
                    offset = voffset + sz;
                    voffset += vsz / dim;
                    if (sz == vsz)
                        break;
                }
            }
        }
    }

    // Interface vptr initializations
    toSymbol(cd);                                         // define csym

    for (size_t i = 0; i < cd->vtblInterfaces->dim; i++)
    {
        BaseClass *b = (*cd->vtblInterfaces)[i];
        for (ClassDeclaration *cd2 = ce->originalClass(); 1; cd2 = cd2->baseClass)
        {
            assert(cd2);
            unsigned csymoffset = cd2->baseVtblOffset(b);
            if (csymoffset != ~0)
            {
                if (offset < b->offset)
                    dtnzeros(pdt, b->offset - offset);
                dtxoff(pdt, toSymbol(cd2), csymoffset);
                break;
            }
        }
        offset = b->offset + Target::ptrsize;
    }

    if (offset < cd->structsize)
        dtnzeros(pdt, cd->structsize - offset);

#undef LOG
    return pdt;
}
