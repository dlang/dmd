
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
#include        "template.h"
// Back end
#include        "dt.h"

typedef Array<struct dt_t *> Dts;

dt_t **Type_toDt(Type *t, dt_t **pdt);
dt_t **toDtElem(TypeSArray *tsa, dt_t **pdt, Expression *e);
dt_t **ClassDeclaration_toDt(ClassDeclaration *cd, dt_t **pdt);
dt_t **StructDeclaration_toDt(StructDeclaration *sd, dt_t **pdt);
dt_t **membersToDt(AggregateDeclaration *cd, dt_t **pdt, ClassDeclaration * = NULL);
dt_t **membersToDt(AggregateDeclaration *ad, dt_t **pdt, Expressions *elements, size_t = 0, ClassDeclaration * = NULL);
dt_t **ClassReferenceExp_toDt(ClassReferenceExp *e, dt_t **pdt, int off);
dt_t **ClassReferenceExp_toInstanceDt(ClassReferenceExp *ce, dt_t **pdt);
Symbol *toSymbol(Dsymbol *s);
dt_t **Expression_toDt(Expression *e, dt_t **pdt);
unsigned baseVtblOffset(ClassDeclaration *cd, BaseClass *bc);
void toObjFile(Dsymbol *ds, bool multiobj);
Symbol *toVtblSymbol(ClassDeclaration *cd);
Symbol* toSymbol(StructLiteralExp *sle);
Symbol* toSymbol(ClassReferenceExp *cre);
void genTypeInfo(Type *t, Scope *sc);
Symbol *toInitializer(AggregateDeclaration *ad);
Symbol *toInitializer(EnumDeclaration *ed);
FuncDeclaration *search_toString(StructDeclaration *sd);

/* ================================================================ */

dt_t **Initializer_toDt(Initializer *init, dt_t **pdt)
{
    class InitToDt : public Visitor
    {
    public:
        dt_t **pdt;

        InitToDt(dt_t **pdt)
            : pdt(pdt)
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
            pdt = dtnzeros(pdt, vi->type->size());
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
                dt_t *dt = NULL;
                Initializer_toDt(ai->value[i], &dt);
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

            dt_t *dtdefault = NULL;

            dt_t *d = NULL;
            dt_t **pdtend = &d;
            for (size_t i = 0; i < ai->dim; i++)
            {
                dt_t *dt = dts[i];
                if (dt)
                    pdtend = dtcat(pdtend, dt);
                else
                {
                    if (!dtdefault)
                        Expression_toDt(edefault, &dtdefault);

                    pdtend = dtrepeat(pdtend, dtdefault, n);
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
                            if (!dtdefault)
                                Expression_toDt(edefault, &dtdefault);

                            pdtend = dtrepeat(pdtend, dtdefault, n * (tadim - ai->dim));
                        }
                    }
                    else if (ai->dim > tadim)
                    {
                        error(ai->loc, "too many initializers, %d, for array[%d]", ai->dim, tadim);
                    }
                    *pdt = d;
                    pdt = pdtend;
                    break;
                }

                case Tpointer:
                case Tarray:
                {
                    if (tb->ty == Tarray)
                        pdt = dtsize_t(pdt, ai->dim);
                    pdt = dtdtoff(pdt, d, 0);
                    break;
                }

                default:
                    assert(0);
            }
            dt_free(dtdefault);
        }

        void visit(ExpInitializer *ei)
        {
            //printf("ExpInitializer::toDt() %s\n", ei->exp->toChars());
            ei->exp = ei->exp->optimize(WANTvalue);
            pdt = Expression_toDt(ei->exp, pdt);
        }
    };

    InitToDt v(pdt);
    init->accept(&v);
    return v.pdt;
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
                pdt = dtxoff(pdt, toSymbol(sl), 0);
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
                    pdt = dtsize_t(pdt, e->len);
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
                        pdt = dtsize_t(pdt, e->elements->dim);
                    if (d)
                        pdt = dtdtoff(pdt, d, 0);
                    else
                        pdt = dtsize_t(pdt, 0);

                    break;

                default:
                    assert(0);
            }
        }

        void visit(StructLiteralExp *sle)
        {
            //printf("StructLiteralExp::toDt() %s, ctfe = %d\n", sle->toChars(), sle->ownedByCtfe);
            assert(sle->sd->fields.dim - sle->sd->isNested() <= sle->elements->dim);
            pdt = membersToDt(sle->sd, pdt, sle->elements);
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
            pdt = dtxoff(pdt, toSymbol(e->var), e->offset);
        }

        void visit(VarExp *e)
        {
            //printf("VarExp::toDt() %d\n", e->op);
            pdt = dtend(pdt);

            VarDeclaration *v = e->var->isVarDeclaration();
            if (v && (v->isConst() || v->isImmutable()) &&
                e->type->toBasetype()->ty != Tsarray && v->_init)
            {
                if (v->inuse)
                {
                    e->error("recursive reference %s", e->toChars());
                    return;
                }
                v->inuse++;
                pdt = Initializer_toDt(v->_init, pdt);
                v->inuse--;
                return;
            }
            SymbolDeclaration *sd = e->var->isSymbolDeclaration();
            if (sd && sd->dsym)
            {
                pdt = StructDeclaration_toDt(sd->dsym, pdt);
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
            toObjFile(e->fd, false);
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

        void visit(TypeidExp *e)
        {
            if (Type *t = isType(e->obj))
            {
                genTypeInfo(t, NULL);
                Symbol *s = toSymbol(t->vtinfo);
                pdt = dtxoff(pdt, s, 0);
                return;
            }
            assert(0);
        }
    };

    ExpToDt v(pdt);
    e->accept(&v);
    return v.pdt;
}

/* ================================================================= */

// Generate the data for the static initializer.

dt_t **ClassDeclaration_toDt(ClassDeclaration *cd, dt_t **pdt)
{
    //printf("ClassDeclaration::toDt(this = '%s')\n", cd->toChars());

    // Put in first two members, the vtbl[] and the monitor
    pdt = dtxoff(pdt, toVtblSymbol(cd), 0);
    if (!cd->cpp)
        pdt = dtsize_t(pdt, 0);             // monitor

    // Put in the rest
    pdt = membersToDt(cd, pdt, cd);

    //printf("-ClassDeclaration::toDt(this = '%s')\n", cd->toChars());
    return pdt;
}

dt_t **StructDeclaration_toDt(StructDeclaration *sd, dt_t **pdt)
{
    //printf("+StructDeclaration::toDt(), this='%s'\n", sd->toChars());
    pdt = membersToDt(sd, pdt);

    //printf("-StructDeclaration::toDt(), this='%s'\n", sd->toChars());
    return pdt;
}

/****************************************************
 * Put out initializers of ad->fields[].
 * Although this is consistent with the elements[] version, we
 * have to use this optimized version to reduce memory footprint.
 */
dt_t **membersToDt(AggregateDeclaration *ad, dt_t **pdt,
        ClassDeclaration *concreteType)
{
    //printf("membersToDt(ad = '%s')\n", ad->toChars());
    ClassDeclaration *cd = ad->isClassDeclaration();

    unsigned offset;
    if (cd)
    {
        if (ClassDeclaration *cdb = cd->baseClass)
        {
            pdt = membersToDt(cdb, pdt, concreteType);
            offset = cdb->structsize;
        }
        else
        {
            if (cd->cpp)
                offset = Target::ptrsize;       // allow room for __vptr
            else
                offset = Target::ptrsize * 2;   // allow room for __vptr and __monitor
        }
    }
    else
        offset = 0;

    for (size_t i = 0; i < ad->fields.dim; i++)
    {
        if (ad->fields[i]->_init && ad->fields[i]->_init->isVoidInitializer())
            continue;

        VarDeclaration *vd = NULL;
        size_t k;
        for (size_t j = i; j < ad->fields.dim; j++)
        {
            VarDeclaration *v2 = ad->fields[j];
            if (v2->offset < offset)
                continue;
            if (v2->_init && v2->_init->isVoidInitializer())
                continue;
            // find the nearest field
            if (!vd || v2->offset < vd->offset)
            {
                vd = v2;
                k = j;
                assert(vd == v2 || !vd->isOverlappedWith(v2));
            }
        }
        if (!vd)
            continue;

        assert(offset <= vd->offset);
        if (offset < vd->offset)
            pdt = dtnzeros(pdt, vd->offset - offset);

        dt_t *dt = NULL;
        if (Initializer *init = vd->_init)
        {
            //printf("\t\t%s has initializer %s\n", vd->toChars(), init->toChars());
            if (init->isVoidInitializer())
                continue;

            /* Because of issue 14666, function local import does not invoke
             * semantic2 pass for the imported module, and surprisingly there's
             * no opportunity to do it today.
             * As a workaround for the issue 9057, have to resolve forward reference
             * in `init` before its use.
             */
            if (vd->sem < Semantic2Done && vd->_scope)
                vd->semantic2(vd->_scope);

            ExpInitializer *ei = init->isExpInitializer();
            Type *tb = vd->type->toBasetype();
            if (ei && tb->ty == Tsarray)
                toDtElem(((TypeSArray *)tb), &dt, ei->exp);
            else
                Initializer_toDt(init, &dt);
        }
        else if (offset <= vd->offset)
        {
            //printf("\t\tdefault initializer\n");
            Type_toDt(vd->type, &dt);
        }
        if (!dt)
            continue;

        pdt = dtcat(pdt, dt);
        offset = vd->offset + vd->type->size();
    }

    if (cd)
    {
        // Interface vptr initializations
        toSymbol(cd);                                         // define csym

        for (size_t i = 0; i < cd->vtblInterfaces->dim; i++)
        {
            BaseClass *b = (*cd->vtblInterfaces)[i];
            for (ClassDeclaration *cd2 = concreteType; 1; cd2 = cd2->baseClass)
            {
                assert(cd2);
                unsigned csymoffset = baseVtblOffset(cd2, b);
                if (csymoffset != ~0)
                {
                    if (offset < b->offset)
                        pdt = dtnzeros(pdt, b->offset - offset);
                    pdt = dtxoff(pdt, toSymbol(cd2), csymoffset);
                    break;
                }
            }
            offset = b->offset + Target::ptrsize;
        }
    }

    if (offset < ad->structsize)
        pdt = dtnzeros(pdt, ad->structsize - offset);

    return pdt;
}

/****************************************************
 * Put out elements[].
 */
dt_t **membersToDt(AggregateDeclaration *ad, dt_t **pdt,
        Expressions *elements, size_t firstFieldIndex,
        ClassDeclaration *concreteType)
{
    //printf("membersToDt(ad = '%s', elements = %s)\n", ad->toChars(), elements->toChars());
    ClassDeclaration *cd = ad->isClassDeclaration();

    unsigned offset;
    if (cd)
    {
        if (ClassDeclaration *cdb = cd->baseClass)
        {
            size_t index = 0;
            for (ClassDeclaration *c = cdb->baseClass; c; c = c->baseClass)
                index += c->fields.dim;
            pdt = membersToDt(cdb, pdt, elements, index, concreteType);
            offset = cdb->structsize;
        }
        else
        {
            if (cd->cpp)
                offset = Target::ptrsize;       // allow room for __vptr
            else
                offset = Target::ptrsize * 2;   // allow room for __vptr and __monitor
        }
    }
    else
        offset = 0;

    assert(firstFieldIndex <= elements->dim &&
           firstFieldIndex + ad->fields.dim <= elements->dim);
    for (size_t i = 0; i < ad->fields.dim; i++)
    {
        if (!(*elements)[firstFieldIndex + i])
            continue;

        VarDeclaration *vd = NULL;
        size_t k;
        for (size_t j = i; j < ad->fields.dim; j++)
        {
            VarDeclaration *v2 = ad->fields[j];
            if (v2->offset < offset)
                continue;
            if (!(*elements)[firstFieldIndex + j])
                continue;
            // find the nearest field
            if (!vd || v2->offset < vd->offset)
            {
                vd = v2;
                k = j;
                assert(vd == v2 || !vd->isOverlappedWith(v2));
            }
        }
        if (!vd)
            continue;

        assert(offset <= vd->offset);
        if (offset < vd->offset)
            pdt = dtnzeros(pdt, vd->offset - offset);

        dt_t *dt = NULL;
        Expression *e = (*elements)[firstFieldIndex + k];
        Type *tb = vd->type->toBasetype();
        if (tb->ty == Tsarray)
            toDtElem(((TypeSArray *)tb), &dt, e);
        else
            Expression_toDt(e, &dt);    // convert e to an initializer dt

        pdt = dtcat(pdt, dt);
        offset = vd->offset + vd->type->size();
    }

    if (cd)
    {
        // Interface vptr initializations
        toSymbol(cd);                                         // define csym

        for (size_t i = 0; i < cd->vtblInterfaces->dim; i++)
        {
            BaseClass *b = (*cd->vtblInterfaces)[i];
            for (ClassDeclaration *cd2 = concreteType; 1; cd2 = cd2->baseClass)
            {
                assert(cd2);
                unsigned csymoffset = baseVtblOffset(cd2, b);
                if (csymoffset != ~0)
                {
                    if (offset < b->offset)
                        pdt = dtnzeros(pdt, b->offset - offset);
                    pdt = dtxoff(pdt, toSymbol(cd2), csymoffset);
                    break;
                }
            }
            offset = b->offset + Target::ptrsize;
        }
    }

    if (offset < ad->structsize)
        pdt = dtnzeros(pdt, ad->structsize - offset);

    return pdt;
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
            pdt = StructDeclaration_toDt(t->sym, pdt);
        }
    };

    TypeToDt v(pdt);
    t->accept(&v);
    return v.pdt;
}

dt_t **toDtElem(TypeSArray *tsa, dt_t **pdt, Expression *e)
{
    //printf("TypeSArray::toDtElem() tsa = %s\n", tsa->toChars());
    if (tsa->size(Loc()) == 0)
    {
        pdt = dtnzeros(pdt, 0);
    }
    else
    {
        size_t len = tsa->dim->toInteger();
        assert(len);
        pdt = dtend(pdt);
        Type *tnext = tsa->next;
        Type *tbn = tnext->toBasetype();
        while (tbn->ty == Tsarray && (!e || tbn != e->type->nextOf()))
        {
            len *= ((TypeSArray *)tbn)->dim->toInteger();
            tnext = tbn->nextOf();
            tbn = tnext->toBasetype();
        }
        if (!e)                             // if not already supplied
            e = tsa->defaultInit(Loc());    // use default initializer

        if (!e->type->implicitConvTo(tnext))    // Bugzilla 14996
        {
            // Bugzilla 1914, 3198
            if (e->op == TOKstring)
                len /= ((StringExp *)e)->len;
            else if (e->op == TOKarrayliteral)
                len /= ((ArrayLiteralExp *)e)->elements->dim;
        }

        Expression_toDt(e, pdt);
        dt_optimize(*pdt);
        pdt = dtrepeat(pdt, *pdt, len - 1);
    }
    return pdt;
}

/*****************************************************/
/*                   CTFE stuff                      */
/*****************************************************/

dt_t **ClassReferenceExp_toDt(ClassReferenceExp *e, dt_t **pdt, int off)
{
    //printf("ClassReferenceExp::toDt() %d\n", e->op);
    pdt = dtxoff(pdt, toSymbol(e), off);
    return pdt;
}

dt_t **ClassReferenceExp_toInstanceDt(ClassReferenceExp *ce, dt_t **pdt)
{
    //printf("ClassReferenceExp::toInstanceDt() %d\n", ce->op);
    ClassDeclaration *cd = ce->originalClass();

    pdt = dtxoff(pdt, toVtblSymbol(cd), 0);
    pdt = dtsize_t(pdt, 0);                 // monitor

    // Put in the rest
    size_t firstFieldIndex = 0;
    for (ClassDeclaration *c = cd->baseClass; c; c = c->baseClass)
        firstFieldIndex += c->fields.dim;
    pdt = membersToDt(cd, pdt, ce->value->elements, firstFieldIndex, cd);

    return pdt;
}

/****************************************************
 */
class TypeInfoDtVisitor : public Visitor
{
public:
    dt_t **pdt;

    /*
     * Used in TypeInfo*::toDt to verify the runtime TypeInfo sizes
     */
    static void verifyStructSize(ClassDeclaration *typeclass, size_t expected)
    {
        if (typeclass->structsize != expected)
        {
#ifdef DEBUG
            printf("expected = x%x, %s.structsize = x%x\n", (unsigned)expected,
                typeclass->toChars(), (unsigned)typeclass->structsize);
#endif
            error(typeclass->loc, "mismatch between compiler and object.d or object.di found. Check installation and import paths with -v compiler switch.");
            fatal();
        }
    }

    TypeInfoDtVisitor(dt_t **pdt)
        : pdt(pdt)
    {
    }

    void visit(TypeInfoDeclaration *d)
    {
        //printf("TypeInfoDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::dtypeinfo, 2 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::dtypeinfo), 0);        // vtbl for TypeInfo
        pdt = dtsize_t(pdt, 0);                                     // monitor
    }

    void visit(TypeInfoConstDeclaration *d)
    {
        //printf("TypeInfoConstDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::typeinfoconst, 3 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfoconst), 0);    // vtbl for TypeInfo_Const
        pdt = dtsize_t(pdt, 0);                                     // monitor
        Type *tm = d->tinfo->mutableOf();
        tm = tm->merge();
        genTypeInfo(tm, NULL);
        pdt = dtxoff(pdt, toSymbol(tm->vtinfo), 0);
    }

    void visit(TypeInfoInvariantDeclaration *d)
    {
        //printf("TypeInfoInvariantDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::typeinfoinvariant, 3 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfoinvariant), 0);    // vtbl for TypeInfo_Invariant
        pdt = dtsize_t(pdt, 0);                                         // monitor
        Type *tm = d->tinfo->mutableOf();
        tm = tm->merge();
        genTypeInfo(tm, NULL);
        pdt = dtxoff(pdt, toSymbol(tm->vtinfo), 0);
    }

    void visit(TypeInfoSharedDeclaration *d)
    {
        //printf("TypeInfoSharedDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::typeinfoshared, 3 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfoshared), 0);   // vtbl for TypeInfo_Shared
        pdt = dtsize_t(pdt, 0);                                     // monitor
        Type *tm = d->tinfo->unSharedOf();
        tm = tm->merge();
        genTypeInfo(tm, NULL);
        pdt = dtxoff(pdt, toSymbol(tm->vtinfo), 0);
    }

    void visit(TypeInfoWildDeclaration *d)
    {
        //printf("TypeInfoWildDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::typeinfowild, 3 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfowild), 0); // vtbl for TypeInfo_Wild
        pdt = dtsize_t(pdt, 0);                                 // monitor
        Type *tm = d->tinfo->mutableOf();
        tm = tm->merge();
        genTypeInfo(tm, NULL);
        pdt = dtxoff(pdt, toSymbol(tm->vtinfo), 0);
    }

    void visit(TypeInfoEnumDeclaration *d)
    {
        //printf("TypeInfoEnumDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfoenum, 7 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfoenum), 0); // vtbl for TypeInfo_Enum
        pdt = dtsize_t(pdt, 0);                        // monitor

        assert(d->tinfo->ty == Tenum);

        TypeEnum *tc = (TypeEnum *)d->tinfo;
        EnumDeclaration *sd = tc->sym;

        /* Put out:
         *  TypeInfo base;
         *  string name;
         *  void[] m_init;
         */

        // TypeInfo for enum members
        if (sd->memtype)
        {
            genTypeInfo(sd->memtype, NULL);
            pdt = dtxoff(pdt, toSymbol(sd->memtype->vtinfo), 0);
        }
        else
            pdt = dtsize_t(pdt, 0);

        // string name;
        const char *name = sd->toPrettyChars();
        size_t namelen = strlen(name);
        pdt = dtsize_t(pdt, namelen);
        pdt = dtxoff(pdt, d->csym, Type::typeinfoenum->structsize);

        // void[] init;
        if (!sd->members || d->tinfo->isZeroInit())
        {
            // 0 initializer, or the same as the base type
            pdt = dtsize_t(pdt, 0);                     // init.length
            pdt = dtsize_t(pdt, 0);                     // init.ptr
        }
        else
        {
            pdt = dtsize_t(pdt, sd->type->size());      // init.length
            pdt = dtxoff(pdt, toInitializer(sd), 0);    // init.ptr
        }

        // Put out name[] immediately following TypeInfo_Enum
        pdt = dtnbytes(pdt, namelen + 1, name);
    }

    void visit(TypeInfoPointerDeclaration *d)
    {
        //printf("TypeInfoPointerDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfopointer, 3 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfopointer), 0);  // vtbl for TypeInfo_Pointer
        pdt = dtsize_t(pdt, 0);                                     // monitor

        assert(d->tinfo->ty == Tpointer);

        TypePointer *tc = (TypePointer *)d->tinfo;

        genTypeInfo(tc->next, NULL);
        pdt = dtxoff(pdt, toSymbol(tc->next->vtinfo), 0); // TypeInfo for type being pointed to
    }

    void visit(TypeInfoArrayDeclaration *d)
    {
        //printf("TypeInfoArrayDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfoarray, 3 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfoarray), 0);    // vtbl for TypeInfo_Array
        pdt = dtsize_t(pdt, 0);                                     // monitor

        assert(d->tinfo->ty == Tarray);

        TypeDArray *tc = (TypeDArray *)d->tinfo;

        genTypeInfo(tc->next, NULL);
        pdt = dtxoff(pdt, toSymbol(tc->next->vtinfo), 0); // TypeInfo for array of type
    }

    void visit(TypeInfoStaticArrayDeclaration *d)
    {
        //printf("TypeInfoStaticArrayDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfostaticarray, 4 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfostaticarray), 0);  // vtbl for TypeInfo_StaticArray
        pdt = dtsize_t(pdt, 0);                                         // monitor

        assert(d->tinfo->ty == Tsarray);

        TypeSArray *tc = (TypeSArray *)d->tinfo;

        genTypeInfo(tc->next, NULL);
        pdt = dtxoff(pdt, toSymbol(tc->next->vtinfo), 0);   // TypeInfo for array of type

        pdt = dtsize_t(pdt, tc->dim->toInteger());          // length
    }

    void visit(TypeInfoVectorDeclaration *d)
    {
        //printf("TypeInfoVectorDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfovector, 3 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfovector), 0);   // vtbl for TypeInfo_Vector
        pdt = dtsize_t(pdt, 0);                                     // monitor

        assert(d->tinfo->ty == Tvector);

        TypeVector *tc = (TypeVector *)d->tinfo;

        genTypeInfo(tc->basetype, NULL);
        pdt = dtxoff(pdt, toSymbol(tc->basetype->vtinfo), 0); // TypeInfo for equivalent static array
    }

    void visit(TypeInfoAssociativeArrayDeclaration *d)
    {
        //printf("TypeInfoAssociativeArrayDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfoassociativearray, 4 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfoassociativearray), 0); // vtbl for TypeInfo_AssociativeArray
        pdt = dtsize_t(pdt, 0);                        // monitor

        assert(d->tinfo->ty == Taarray);

        TypeAArray *tc = (TypeAArray *)d->tinfo;

        genTypeInfo(tc->next, NULL);
        pdt = dtxoff(pdt, toSymbol(tc->next->vtinfo), 0);   // TypeInfo for array of type

        genTypeInfo(tc->index, NULL);
        pdt = dtxoff(pdt, toSymbol(tc->index->vtinfo), 0);  // TypeInfo for array of type
    }

    void visit(TypeInfoFunctionDeclaration *d)
    {
        //printf("TypeInfoFunctionDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfofunction, 5 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfofunction), 0); // vtbl for TypeInfo_Function
        pdt = dtsize_t(pdt, 0);                                     // monitor

        assert(d->tinfo->ty == Tfunction);

        TypeFunction *tc = (TypeFunction *)d->tinfo;

        genTypeInfo(tc->next, NULL);
        pdt = dtxoff(pdt, toSymbol(tc->next->vtinfo), 0); // TypeInfo for function return value

        const char *name = d->tinfo->deco;
        assert(name);
        size_t namelen = strlen(name);
        pdt = dtsize_t(pdt, namelen);
        pdt = dtxoff(pdt, d->csym, Type::typeinfofunction->structsize);

        // Put out name[] immediately following TypeInfo_Function
        pdt = dtnbytes(pdt, namelen + 1, name);
    }

    void visit(TypeInfoDelegateDeclaration *d)
    {
        //printf("TypeInfoDelegateDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfodelegate, 5 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfodelegate), 0); // vtbl for TypeInfo_Delegate
        pdt = dtsize_t(pdt, 0);                                     // monitor

        assert(d->tinfo->ty == Tdelegate);

        TypeDelegate *tc = (TypeDelegate *)d->tinfo;

        genTypeInfo(tc->next->nextOf(), NULL);
        pdt = dtxoff(pdt, toSymbol(tc->next->nextOf()->vtinfo), 0); // TypeInfo for delegate return value

        const char *name = d->tinfo->deco;
        assert(name);
        size_t namelen = strlen(name);
        pdt = dtsize_t(pdt, namelen);
        pdt = dtxoff(pdt, d->csym, Type::typeinfodelegate->structsize);

        // Put out name[] immediately following TypeInfo_Delegate
        pdt = dtnbytes(pdt, namelen + 1, name);
    }

    void visit(TypeInfoStructDeclaration *d)
    {
        //printf("TypeInfoStructDeclaration::toDt() '%s'\n", d->toChars());
        if (global.params.is64bit)
            verifyStructSize(Type::typeinfostruct, 17 * Target::ptrsize);
        else
            verifyStructSize(Type::typeinfostruct, 15 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfostruct), 0); // vtbl for TypeInfo_Struct
        pdt = dtsize_t(pdt, 0);                        // monitor

        assert(d->tinfo->ty == Tstruct);

        TypeStruct *tc = (TypeStruct *)d->tinfo;
        StructDeclaration *sd = tc->sym;

        if (!sd->members)
            return;

        if (TemplateInstance *ti = sd->isInstantiated())
        {
            if (!ti->needsCodegen())
            {
                assert(ti->minst || sd->requestTypeInfo);

                /* ti->toObjFile() won't get called. So, store these
                 * member functions into object file in here.
                 */
                if (sd->xeq && sd->xeq != StructDeclaration::xerreq)
                    toObjFile(sd->xeq, global.params.multiobj);
                if (sd->xcmp && sd->xcmp != StructDeclaration::xerrcmp)
                    toObjFile(sd->xcmp, global.params.multiobj);
                if (FuncDeclaration *ftostr = search_toString(sd))
                    toObjFile(ftostr, global.params.multiobj);
                if (sd->xhash)
                    toObjFile(sd->xhash, global.params.multiobj);
                if (sd->postblit)
                    toObjFile(sd->postblit, global.params.multiobj);
                if (sd->dtor)
                    toObjFile(sd->dtor, global.params.multiobj);
            }
        }

        /* Put out:
         *  char[] name;
         *  void[] init;
         *  hash_t function(in void*) xtoHash;
         *  bool function(in void*, in void*) xopEquals;
         *  int function(in void*, in void*) xopCmp;
         *  string function(const(void)*) xtoString;
         *  StructFlags m_flags;
         *  //xgetMembers;
         *  xdtor;
         *  xpostblit;
         *  uint m_align;
         *  version (X86_64)
         *      TypeInfo m_arg1;
         *      TypeInfo m_arg2;
         *  xgetRTInfo
         */

        const char *name = sd->toPrettyChars();
        size_t namelen = strlen(name);
        pdt = dtsize_t(pdt, namelen);
        pdt = dtxoff(pdt, d->csym, Type::typeinfostruct->structsize);

        // void[] init;
        pdt = dtsize_t(pdt, sd->structsize);            // init.length
        if (sd->zeroInit)
            pdt = dtsize_t(pdt, 0);                     // NULL for 0 initialization
        else
            pdt = dtxoff(pdt, toInitializer(sd), 0);    // init.ptr

        if (FuncDeclaration *fd = sd->xhash)
        {
            pdt = dtxoff(pdt, toSymbol(fd), 0);
            TypeFunction *tf = (TypeFunction *)fd->type;
            assert(tf->ty == Tfunction);
            /* I'm a little unsure this is the right way to do it. Perhaps a better
             * way would to automatically add these attributes to any struct member
             * function with the name "toHash".
             * So I'm leaving this here as an experiment for the moment.
             */
            if (!tf->isnothrow || tf->trust == TRUSTsystem /*|| tf->purity == PUREimpure*/)
                warning(fd->loc, "toHash() must be declared as extern (D) size_t toHash() const nothrow @safe, not %s", tf->toChars());
        }
        else
            pdt = dtsize_t(pdt, 0);

        if (sd->xeq)
            pdt = dtxoff(pdt, toSymbol(sd->xeq), 0);
        else
            pdt = dtsize_t(pdt, 0);

        if (sd->xcmp)
            pdt = dtxoff(pdt, toSymbol(sd->xcmp), 0);
        else
            pdt = dtsize_t(pdt, 0);

        if (FuncDeclaration *fd = search_toString(sd))
        {
            pdt = dtxoff(pdt, toSymbol(fd), 0);
        }
        else
            pdt = dtsize_t(pdt, 0);

        // StructFlags m_flags;
        StructFlags::Type m_flags = 0;
        if (tc->hasPointers()) m_flags |= StructFlags::hasPointers;
        pdt = dtsize_t(pdt, m_flags);

    #if 0
        // xgetMembers
        FuncDeclaration *sgetmembers = sd->findGetMembers();
        if (sgetmembers)
            pdt = dtxoff(pdt, toSymbol(sgetmembers), 0);
        else
            pdt = dtsize_t(pdt, 0);                     // xgetMembers
    #endif

        // xdtor
        FuncDeclaration *sdtor = sd->dtor;
        if (sdtor)
            pdt = dtxoff(pdt, toSymbol(sdtor), 0);
        else
            pdt = dtsize_t(pdt, 0);                     // xdtor

        // xpostblit
        FuncDeclaration *spostblit = sd->postblit;
        if (spostblit && !(spostblit->storage_class & STCdisable))
            pdt = dtxoff(pdt, toSymbol(spostblit), 0);
        else
            pdt = dtsize_t(pdt, 0);                     // xpostblit

        // uint m_align;
        pdt = dtsize_t(pdt, tc->alignsize());

        if (global.params.is64bit)
        {
            Type *t = sd->arg1type;
            for (int i = 0; i < 2; i++)
            {
                // m_argi
                if (t)
                {
                    genTypeInfo(t, NULL);
                    pdt = dtxoff(pdt, toSymbol(t->vtinfo), 0);
                }
                else
                    pdt = dtsize_t(pdt, 0);

                t = sd->arg2type;
            }
        }

        // xgetRTInfo
        if (sd->getRTInfo)
            Expression_toDt(sd->getRTInfo, pdt);
        else if (m_flags & StructFlags::hasPointers)
            pdt = dtsize_t(pdt, 1);
        else
            pdt = dtsize_t(pdt, 0);

        // Put out name[] immediately following TypeInfo_Struct
        pdt = dtnbytes(pdt, namelen + 1, name);
    }

    void visit(TypeInfoClassDeclaration *d)
    {
        //printf("TypeInfoClassDeclaration::toDt() %s\n", tinfo->toChars());
        assert(0);
    }

    void visit(TypeInfoInterfaceDeclaration *d)
    {
        //printf("TypeInfoInterfaceDeclaration::toDt() %s\n", tinfo->toChars());
        verifyStructSize(Type::typeinfointerface, 3 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfointerface), 0);    // vtbl for TypeInfoInterface
        pdt = dtsize_t(pdt, 0);                                         // monitor

        assert(d->tinfo->ty == Tclass);

        TypeClass *tc = (TypeClass *)d->tinfo;
        Symbol *s;

        if (!tc->sym->vclassinfo)
            tc->sym->vclassinfo = TypeInfoClassDeclaration::create(tc);
        s = toSymbol(tc->sym->vclassinfo);
        pdt = dtxoff(pdt, s, 0);    // ClassInfo for tinfo
    }

    void visit(TypeInfoTupleDeclaration *d)
    {
        //printf("TypeInfoTupleDeclaration::toDt() %s\n", tinfo->toChars());
        verifyStructSize(Type::typeinfotypelist, 4 * Target::ptrsize);

        pdt = dtxoff(pdt, toVtblSymbol(Type::typeinfotypelist), 0); // vtbl for TypeInfoInterface
        pdt = dtsize_t(pdt, 0);                                     // monitor

        assert(d->tinfo->ty == Ttuple);

        TypeTuple *tu = (TypeTuple *)d->tinfo;

        size_t dim = tu->arguments->dim;
        pdt = dtsize_t(pdt, dim);                       // elements.length

        dt_t *dtargs = NULL;
        dt_t **pdtend = &dtargs;
        for (size_t i = 0; i < dim; i++)
        {
            Parameter *arg = (*tu->arguments)[i];

            genTypeInfo(arg->type, NULL);
            Symbol *s = toSymbol(arg->type->vtinfo);
            pdtend = dtxoff(pdtend, s, 0);
        }

        pdt = dtdtoff(pdt, dtargs, 0);                  // elements.ptr
    }
};

dt_t **TypeInfo_toDt(dt_t **pdt, TypeInfoDeclaration *d)
{
    TypeInfoDtVisitor v(pdt);
    d->accept(&v);
    return v.pdt;
}
