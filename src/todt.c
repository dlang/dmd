
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
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
#include        "errors.h"
// Back end
#include        "dt.h"

typedef Array<struct dt_t *> Dts;

void Type_toDt(Type *t, DtBuilder& dtb);
static void toDtElem(TypeSArray *tsa, DtBuilder& dtb, Expression *e);
void ClassDeclaration_toDt(ClassDeclaration *cd, DtBuilder& dtb);
void StructDeclaration_toDt(StructDeclaration *sd, DtBuilder& dtb);
static void membersToDt(AggregateDeclaration *ad, DtBuilder& dtb, Expressions *elements, size_t, ClassDeclaration *, BaseClass ***ppb = NULL);
static void ClassReferenceExp_toDt(ClassReferenceExp *e, DtBuilder& dtb, int off);
void ClassReferenceExp_toInstanceDt(ClassReferenceExp *ce, DtBuilder& dtb);
Symbol *toSymbol(Dsymbol *s);
void Expression_toDt(Expression *e, DtBuilder& dtb);
unsigned baseVtblOffset(ClassDeclaration *cd, BaseClass *bc);
void toObjFile(Dsymbol *ds, bool multiobj);
Symbol *toVtblSymbol(ClassDeclaration *cd);
Symbol* toSymbol(StructLiteralExp *sle);
Symbol* toSymbol(ClassReferenceExp *cre);
void genTypeInfo(Loc loc, Type *t, Scope *sc);
Symbol *toInitializer(AggregateDeclaration *ad);
Symbol *toInitializer(EnumDeclaration *ed);
FuncDeclaration *search_toString(StructDeclaration *sd);
Symbol *toSymbolCppTypeInfo(ClassDeclaration *cd);

/* ================================================================ */

void Initializer_toDt(Initializer *init, DtBuilder& dtb)
{
    class InitToDt : public Visitor
    {
    public:
        DtBuilder& dtb;

        InitToDt(DtBuilder& dtb)
            : dtb(dtb)
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
            dtb.nzeros(vi->type->size());
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
            for (size_t i = 0; i < ai->index.length; i++)
            {
                Expression *idx = ai->index[i];
                if (idx)
                    length = idx->toInteger();
                //printf("\tindex[%d] = %p, length = %u, dim = %u\n", i, idx, length, ai->dim);

                assert(length < ai->dim);
                DtBuilder dtb;
                Initializer_toDt(ai->value[i], dtb);
                if (dts[length])
                    error(ai->loc, "duplicate initializations for index %d", length);
                dts[length] = dtb.finish();
                length++;
            }

            Expression *edefault = tb->nextOf()->defaultInit();

            size_t n = tn->numberOfElems(ai->loc);

            dt_t *dtdefault = NULL;

            DtBuilder dtbarray;
            for (size_t i = 0; i < ai->dim; i++)
            {
                if (dts[i])
                    dtbarray.cat(dts[i]);
                else
                {
                    if (!dtdefault)
                    {
                        DtBuilder dtb;
                        Expression_toDt(edefault, dtb);
                        dtdefault = dtb.finish();
                    }
                    dtbarray.repeat(dtdefault, n);
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
                            dtbarray.nzeros(size * (tadim - ai->dim));
                        }
                        else
                        {
                            if (!dtdefault)
                            {
                                DtBuilder dtb;
                                Expression_toDt(edefault, dtb);
                                dtdefault = dtb.finish();
                            }

                            dtbarray.repeat(dtdefault, n * (tadim - ai->dim));
                        }
                    }
                    else if (ai->dim > tadim)
                    {
                        error(ai->loc, "too many initializers, %d, for array[%lu]", ai->dim, tadim);
                    }
                    dtb.cat(dtbarray);
                    break;
                }

                case Tpointer:
                case Tarray:
                {
                    if (tb->ty == Tarray)
                        dtb.size(ai->dim);
                    dtb.dtoff(dtbarray.finish(), 0);
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
            Expression_toDt(ei->exp, dtb);
        }
    };

    InitToDt v(dtb);
    init->accept(&v);
}

/* ================================================================ */

void Expression_toDt(Expression *e, DtBuilder& dtb)
{
    class ExpToDt : public Visitor
    {
    public:
        DtBuilder& dtb;

        ExpToDt(DtBuilder& dtb)
            : dtb(dtb)
        {
        }

        void visit(Expression *e)
        {
        #if 0
            printf("Expression::toDt() %d\n", e->op);
            print();
        #endif
            e->error("non-constant expression %s", e->toChars());
            dtb.nzeros(1);
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
                    ClassReferenceExp_toDt((ClassReferenceExp*)e->e1, dtb, off);
                }
                else //casting from class to class
                {
                    Expression_toDt(e->e1, dtb);
                }
                return;
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
                dtb.xoff(toSymbol(sl), 0);
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
                dtb.nzeros(sz);
            else
                dtb.nbytes(sz, (char *)&value);
        }

        void visit(RealExp *e)
        {
            //printf("RealExp::toDt(%Lg)\n", e->value);
            switch (e->type->toBasetype()->ty)
            {
                case Tfloat32:
                case Timaginary32:
                {
                    float fvalue = e->value;
                    dtb.nbytes(4,(char *)&fvalue);
                    break;
                }

                case Tfloat64:
                case Timaginary64:
                {
                    double dvalue = e->value;
                    dtb.nbytes(8,(char *)&dvalue);
                    break;
                }

                case Tfloat80:
                case Timaginary80:
                {
                    real_t evalue = e->value;
                    dtb.nbytes(target.realsize - target.realpad,(char *)&evalue);
                    dtb.nzeros(target.realpad);
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
            switch (e->type->toBasetype()->ty)
            {
                case Tcomplex32:
                {
                    float fvalue = creall(e->value);
                    dtb.nbytes(4,(char *)&fvalue);
                    fvalue = cimagl(e->value);
                    dtb.nbytes(4,(char *)&fvalue);
                    break;
                }

                case Tcomplex64:
                {
                    double dvalue = creall(e->value);
                    dtb.nbytes(8,(char *)&dvalue);
                    dvalue = cimagl(e->value);
                    dtb.nbytes(8,(char *)&dvalue);
                    break;
                }

                case Tcomplex80:
                {
                    real_t evalue = creall(e->value);
                    dtb.nbytes(target.realsize - target.realpad,(char *)&evalue);
                    dtb.nzeros(target.realpad);
                    evalue = cimagl(e->value);
                    dtb.nbytes(target.realsize - target.realpad,(char *)&evalue);
                    dtb.nzeros(target.realpad);
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
            dtb.nzeros(e->type->size());
        }

        void visit(StringExp *e)
        {
            //printf("StringExp::toDt() '%s', type = %s\n", e->toChars(), e->type->toChars());
            Type *t = e->type->toBasetype();

            // BUG: should implement some form of static string pooling
            int n = e->numberOfCodeUnits();
            char *p = e->toPtr();
            if (!p)
            {
                p = (char *)mem.xmalloc(n * e->sz);
                e->writeTo(p, false);
            }
            switch (t->ty)
            {
                case Tarray:
                    dtb.size(n);
                    dtb.abytes(0, n * e->sz, p, (unsigned)e->sz);
                    break;

                case Tpointer:
                    dtb.abytes(0, n * e->sz, p, (unsigned)e->sz);
                    break;

                case Tsarray:
                {
                    TypeSArray *tsa = (TypeSArray *)t;

                    dtb.nbytes(n * e->sz, p);
                    if (tsa->dim)
                    {
                        dinteger_t dim = tsa->dim->toInteger();
                        if (n < dim)
                        {
                            // Pad remainder with 0
                            dtb.nzeros((dim - n) * tsa->next->size());
                        }
                    }
                    break;
                }

                default:
                    printf("StringExp::toDt(type = %s)\n", e->type->toChars());
                    assert(0);
            }
            if (p != e->toPtr())
                mem.xfree(p);
        }

        void visit(ArrayLiteralExp *e)
        {
            //printf("ArrayLiteralExp::toDt() '%s', type = %s\n", e->toChars(), e->type->toChars());

            DtBuilder dtbarray;
            for (size_t i = 0; i < e->elements->length; i++)
            {
                Expression_toDt(e->getElement(i), dtbarray);
            }

            Type *t = e->type->toBasetype();
            switch (t->ty)
            {
                case Tsarray:
                    dtb.cat(dtbarray);
                    break;

                case Tpointer:
                case Tarray:
                {
                    if (t->ty == Tarray)
                        dtb.size(e->elements->length);
                    dt_t *d = dtbarray.finish();
                    if (d)
                        dtb.dtoff(d, 0);
                    else
                        dtb.size(0);

                    break;
                }

                default:
                    assert(0);
            }
        }

        void visit(StructLiteralExp *sle)
        {
            //printf("StructLiteralExp::toDt() %s, ctfe = %d\n", sle->toChars(), sle->ownedByCtfe);
            assert(sle->sd->fields.length - sle->sd->isNested() <= sle->elements->length);
            membersToDt(sle->sd, dtb, sle->elements, 0, NULL);
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
            dtb.xoff(toSymbol(e->var), e->offset);
        }

        void visit(VarExp *e)
        {
            //printf("VarExp::toDt() %d\n", e->op);

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
                Initializer_toDt(v->_init, dtb);
                v->inuse--;
                return;
            }
            SymbolDeclaration *sd = e->var->isSymbolDeclaration();
            if (sd && sd->dsym)
            {
                StructDeclaration_toDt(sd->dsym, dtb);
                return;
            }
        #if 0
            printf("VarExp::toDt(), kind = %s\n", e->var->kind());
        #endif
            e->error("non-constant expression %s", e->toChars());
            dtb.nzeros(1);
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
                return;
            }
            toObjFile(e->fd, false);
            dtb.xoff(s, 0);
        }

        void visit(VectorExp *e)
        {
            //printf("VectorExp::toDt() %s\n", e->toChars());
            for (size_t i = 0; i < e->dim; i++)
            {
                Expression *elem;
                if (e->e1->op == TOKarrayliteral)
                {
                    ArrayLiteralExp *ale = (ArrayLiteralExp *)e->e1;
                    elem = ale->getElement(i);
                }
                else
                    elem = e->e1;
                Expression_toDt(elem, dtb);
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
                ClassReferenceExp_toDt(e, dtb, off);
            }
            else
                ClassReferenceExp_toDt(e, dtb, 0);
        }

        void visit(TypeidExp *e)
        {
            if (Type *t = isType(e->obj))
            {
                genTypeInfo(e->loc, t, NULL);
                Symbol *s = toSymbol(t->vtinfo);
                dtb.xoff(s, 0);
                return;
            }
            assert(0);
        }
    };

    ExpToDt v(dtb);
    e->accept(&v);
}

/* ================================================================= */

// Generate the data for the static initializer.

void ClassDeclaration_toDt(ClassDeclaration *cd, DtBuilder& dtb)
{
    //printf("ClassDeclaration::toDt(this = '%s')\n", cd->toChars());

    membersToDt(cd, dtb, NULL, 0, cd);

    //printf("-ClassDeclaration::toDt(this = '%s')\n", cd->toChars());
}

void StructDeclaration_toDt(StructDeclaration *sd, DtBuilder& dtb)
{
    //printf("+StructDeclaration::toDt(), this='%s'\n", sd->toChars());
    membersToDt(sd, dtb, NULL, 0, NULL);

    //printf("-StructDeclaration::toDt(), this='%s'\n", sd->toChars());
}

/******************************
 * Generate data for instance of __cpp_type_info_ptr that refers
 * to the C++ RTTI symbol for cd.
 * Params:
 *      cd = C++ class
 */
void cpp_type_info_ptr_toDt(ClassDeclaration *cd, DtBuilder& dtb)
{
    //printf("cpp_type_info_ptr_toDt(this = '%s')\n", cd->toChars());
    assert(cd->isCPPclass());

    // Put in first two members, the vtbl[] and the monitor
    dtb.xoff(toVtblSymbol(ClassDeclaration::cpp_type_info_ptr), 0);
    if (ClassDeclaration::cpp_type_info_ptr->hasMonitor())
        dtb.size(0);             // monitor

    // Create symbol for C++ type info
    Symbol *s = toSymbolCppTypeInfo(cd);

    // Put in address of cd's C++ type info
    dtb.xoff(s, 0);

    //printf("-cpp_type_info_ptr_toDt(this = '%s')\n", cd.toChars());
}

/****************************************************
 * Put out initializers of ad->fields[].
 * Although this is consistent with the elements[] version, we
 * have to use this optimized version to reduce memory footprint.
 * Params:
 *      ad = aggregate with members
 *      pdt = tail of initializer list to start appending initialized data to
 *      elements = values to use as initializers, NULL means use default initializers
 *      firstFieldIndex = starting place is elements[firstFieldIndex]
 *      concreteType = structs: null, classes: most derived class
 *      ppb = pointer that moves through BaseClass[] from most derived class
 * Returns:
 *      updated tail of dt_t list
 */
static void membersToDt(AggregateDeclaration *ad, DtBuilder& dtb,
        Expressions *elements, size_t firstFieldIndex,
        ClassDeclaration *concreteType,
        BaseClass ***ppb)
{
    //printf("membersToDt(ad = '%s', concrete = '%s', ppb = %p)\n", ad->toChars(), concreteType ? concreteType->toChars() : "null", ppb);
    ClassDeclaration *cd = ad->isClassDeclaration();
#if 0
    printf(" interfaces.length = %d\n", (int)cd->interfaces.length);
    for (size_t i = 0; i < cd->vtblInterfaces->length; i++)
    {
        BaseClass *b = (*cd->vtblInterfaces)[i];
        printf("  vbtblInterfaces[%d] b = %p, b->sym = %s\n", (int)i, b, b->sym->toChars());
    }
#endif

    /* Order:
     *  { base class } or { __vptr, __monitor }
     *  interfaces
     *  fields
     */

    unsigned offset;
    if (cd)
    {
        if (ClassDeclaration *cdb = cd->baseClass)
        {
            size_t index = 0;
            for (ClassDeclaration *c = cdb->baseClass; c; c = c->baseClass)
                index += c->fields.length;
            membersToDt(cdb, dtb, elements, index, concreteType);
            offset = cdb->structsize;
        }
        else if (InterfaceDeclaration *id = cd->isInterfaceDeclaration())
        {
            offset = (**ppb)->offset;
            if (id->vtblInterfaces->length == 0)
            {
                BaseClass *b = **ppb;
                //printf("  Interface %s, b = %p\n", id->toChars(), b);
                ++(*ppb);
                for (ClassDeclaration *cd2 = concreteType; 1; cd2 = cd2->baseClass)
                {
                    assert(cd2);
                    unsigned csymoffset = baseVtblOffset(cd2, b);
                    //printf("    cd2 %s csymoffset = x%x\n", cd2 ? cd2->toChars() : "null", csymoffset);
                    if (csymoffset != ~0)
                    {
                        dtb.xoff(toSymbol(cd2), csymoffset);
                        offset += target.ptrsize;
                        break;
                    }
                }
            }
        }
        else
        {
            dtb.xoff(toVtblSymbol(concreteType), 0);  // __vptr
            offset = target.ptrsize;
            if (cd->hasMonitor())
            {
                dtb.size(0);              // __monitor
                offset += target.ptrsize;
            }
        }

        // Interface vptr initializations
        toSymbol(cd);                                         // define csym

        BaseClass **pb;
        if (!ppb)
        {
            pb = cd->vtblInterfaces->tdata();
            ppb = &pb;
        }

        for (size_t i = 0; i < cd->interfaces.length; ++i)
        {
            BaseClass *b = **ppb;
            if (offset < b->offset)
                dtb.nzeros(b->offset - offset);
            membersToDt(cd->interfaces.ptr[i]->sym, dtb, elements, firstFieldIndex, concreteType, ppb);
            //printf("b->offset = %d, b->sym->structsize = %d\n", (int)b->offset, (int)b->sym->structsize);
            offset = b->offset + b->sym->structsize;
        }
    }
    else
        offset = 0;

    assert(!elements ||
           firstFieldIndex <= elements->length &&
           firstFieldIndex + ad->fields.length <= elements->length);

    for (size_t i = 0; i < ad->fields.length; i++)
    {
        if (elements && !(*elements)[firstFieldIndex + i])
            continue;
        else if (ad->fields[i]->_init && ad->fields[i]->_init->isVoidInitializer())
            continue;

        VarDeclaration *vd = NULL;
        size_t k;
        for (size_t j = i; j < ad->fields.length; j++)
        {
            VarDeclaration *v2 = ad->fields[j];
            if (v2->offset < offset)
                continue;

            if (elements && !(*elements)[firstFieldIndex + j])
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
            dtb.nzeros(vd->offset - offset);

        DtBuilder dtbx;
        if (elements)
        {
            Expression *e = (*elements)[firstFieldIndex + k];
            Type *tb = vd->type->toBasetype();
            if (tb->ty == Tsarray)
                toDtElem(((TypeSArray *)tb), dtbx, e);
            else
                Expression_toDt(e, dtbx);    // convert e to an initializer dt
        }
        else
        {
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
                if (vd->semanticRun < PASSsemantic2done && vd->_scope)
                    semantic2(vd, vd->_scope);

                ExpInitializer *ei = init->isExpInitializer();
                Type *tb = vd->type->toBasetype();
                if (ei && tb->ty == Tsarray)
                    toDtElem(((TypeSArray *)tb), dtbx, ei->exp);
                else
                    Initializer_toDt(init, dtbx);
            }
            else if (offset <= vd->offset)
            {
                //printf("\t\tdefault initializer\n");
                Type_toDt(vd->type, dtbx);
            }
            if (dtbx.isZeroLength())
                continue;
        }

        dtb.cat(dtbx);
        offset = vd->offset + vd->type->size();
    }

    if (offset < ad->structsize)
        dtb.nzeros(ad->structsize - offset);
}


/* ================================================================= */

void Type_toDt(Type *t, DtBuilder& dtb)
{
    class TypeToDt : public Visitor
    {
    public:
        DtBuilder& dtb;

        TypeToDt(DtBuilder& dtb)
            : dtb(dtb)
        {
        }

        void visit(Type *t)
        {
            //printf("Type::toDt()\n");
            Expression *e = t->defaultInit();
            Expression_toDt(e, dtb);
        }

        void visit(TypeVector *t)
        {
            assert(t->basetype->ty == Tsarray);
            toDtElem((TypeSArray *)t->basetype, dtb, NULL);
        }

        void visit(TypeSArray *t)
        {
            toDtElem(t, dtb, NULL);
        }

        void visit(TypeStruct *t)
        {
            StructDeclaration_toDt(t->sym, dtb);
        }
    };

    TypeToDt v(dtb);
    t->accept(&v);
}

void toDtElem(TypeSArray *tsa, DtBuilder& dtb, Expression *e)
{
    //printf("TypeSArray::toDtElem() tsa = %s\n", tsa->toChars());
    if (tsa->size(Loc()) == 0)
    {
        dtb.nzeros(0);
    }
    else
    {
        size_t len = tsa->dim->toInteger();
        assert(len);
        Type *tnext = tsa->next;
        Type *tbn = tnext->toBasetype();
        while (tbn->ty == Tsarray && (!e || !tbn->equivalent(e->type->nextOf())))
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
                len /= ((StringExp *)e)->numberOfCodeUnits();
            else if (e->op == TOKarrayliteral)
                len /= ((ArrayLiteralExp *)e)->elements->length;
        }

        DtBuilder dtb2;
        Expression_toDt(e, dtb2);
        dt_t *dt2 = dtb2.finish();
        dtb.repeat(dt2, len);
    }
}

/*****************************************************/
/*                   CTFE stuff                      */
/*****************************************************/

static void ClassReferenceExp_toDt(ClassReferenceExp *e, DtBuilder& dtb, int off)
{
    //printf("ClassReferenceExp::toDt() %d\n", e->op);
    dtb.xoff(toSymbol(e), off);
}

void ClassReferenceExp_toInstanceDt(ClassReferenceExp *ce, DtBuilder& dtb)
{
    //printf("ClassReferenceExp::toInstanceDt() %d\n", ce->op);
    ClassDeclaration *cd = ce->originalClass();

    // Put in the rest
    size_t firstFieldIndex = 0;
    for (ClassDeclaration *c = cd->baseClass; c; c = c->baseClass)
        firstFieldIndex += c->fields.length;
    membersToDt(cd, dtb, ce->value->elements, firstFieldIndex, cd);
}

/****************************************************
 */
class TypeInfoDtVisitor : public Visitor
{
public:
    DtBuilder& dtb;

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

    TypeInfoDtVisitor(DtBuilder& dtb)
        : dtb(dtb)
    {
    }

    void visit(TypeInfoDeclaration *d)
    {
        //printf("TypeInfoDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::dtypeinfo, 2 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::dtypeinfo), 0);        // vtbl for TypeInfo
        if (Type::dtypeinfo->hasMonitor())
            dtb.size(0);                                   // monitor
    }

    void visit(TypeInfoConstDeclaration *d)
    {
        //printf("TypeInfoConstDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::typeinfoconst, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfoconst), 0);    // vtbl for TypeInfo_Const
        if (Type::typeinfoconst->hasMonitor())
            dtb.size(0);                                   // monitor
        Type *tm = d->tinfo->mutableOf();
        tm = tm->merge();
        genTypeInfo(d->loc, tm, NULL);
        dtb.xoff(toSymbol(tm->vtinfo), 0);
    }

    void visit(TypeInfoInvariantDeclaration *d)
    {
        //printf("TypeInfoInvariantDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::typeinfoinvariant, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfoinvariant), 0);    // vtbl for TypeInfo_Invariant
        if (Type::typeinfoinvariant->hasMonitor())
            dtb.size(0);                                   // monitor
        Type *tm = d->tinfo->mutableOf();
        tm = tm->merge();
        genTypeInfo(d->loc, tm, NULL);
        dtb.xoff(toSymbol(tm->vtinfo), 0);
    }

    void visit(TypeInfoSharedDeclaration *d)
    {
        //printf("TypeInfoSharedDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::typeinfoshared, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfoshared), 0);   // vtbl for TypeInfo_Shared
        if (Type::typeinfoshared->hasMonitor())
            dtb.size(0);                                   // monitor
        Type *tm = d->tinfo->unSharedOf();
        tm = tm->merge();
        genTypeInfo(d->loc, tm, NULL);
        dtb.xoff(toSymbol(tm->vtinfo), 0);
    }

    void visit(TypeInfoWildDeclaration *d)
    {
        //printf("TypeInfoWildDeclaration::toDt() %s\n", toChars());
        verifyStructSize(Type::typeinfowild, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfowild), 0); // vtbl for TypeInfo_Wild
        if (Type::typeinfowild->hasMonitor())
            dtb.size(0);                                   // monitor
        Type *tm = d->tinfo->mutableOf();
        tm = tm->merge();
        genTypeInfo(d->loc, tm, NULL);
        dtb.xoff(toSymbol(tm->vtinfo), 0);
    }

    void visit(TypeInfoEnumDeclaration *d)
    {
        //printf("TypeInfoEnumDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfoenum, 7 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfoenum), 0); // vtbl for TypeInfo_Enum
        if (Type::typeinfoenum->hasMonitor())
            dtb.size(0);                                   // monitor

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
            genTypeInfo(d->loc, sd->memtype, NULL);
            dtb.xoff(toSymbol(sd->memtype->vtinfo), 0);
        }
        else
            dtb.size(0);

        // string name;
        const char *name = sd->toPrettyChars();
        size_t namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(d->csym, Type::typeinfoenum->structsize);

        // void[] init;
        if (!sd->members || d->tinfo->isZeroInit())
        {
            // 0 initializer, or the same as the base type
            dtb.size(0);                     // init.length
            dtb.size(0);                     // init.ptr
        }
        else
        {
            dtb.size(sd->type->size());      // init.length
            dtb.xoff(toInitializer(sd), 0);    // init.ptr
        }

        // Put out name[] immediately following TypeInfo_Enum
        dtb.nbytes(namelen + 1, name);
    }

    void visit(TypeInfoPointerDeclaration *d)
    {
        //printf("TypeInfoPointerDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfopointer, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfopointer), 0);  // vtbl for TypeInfo_Pointer
        if (Type::typeinfopointer->hasMonitor())
            dtb.size(0);                                   // monitor

        assert(d->tinfo->ty == Tpointer);

        TypePointer *tc = (TypePointer *)d->tinfo;

        genTypeInfo(d->loc, tc->next, NULL);
        dtb.xoff(toSymbol(tc->next->vtinfo), 0); // TypeInfo for type being pointed to
    }

    void visit(TypeInfoArrayDeclaration *d)
    {
        //printf("TypeInfoArrayDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfoarray, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfoarray), 0);    // vtbl for TypeInfo_Array
        if (Type::typeinfoarray->hasMonitor())
            dtb.size(0);                                   // monitor

        assert(d->tinfo->ty == Tarray);

        TypeDArray *tc = (TypeDArray *)d->tinfo;

        genTypeInfo(d->loc, tc->next, NULL);
        dtb.xoff(toSymbol(tc->next->vtinfo), 0); // TypeInfo for array of type
    }

    void visit(TypeInfoStaticArrayDeclaration *d)
    {
        //printf("TypeInfoStaticArrayDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfostaticarray, 4 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfostaticarray), 0);  // vtbl for TypeInfo_StaticArray
        if (Type::typeinfostaticarray->hasMonitor())
            dtb.size(0);                                       // monitor

        assert(d->tinfo->ty == Tsarray);

        TypeSArray *tc = (TypeSArray *)d->tinfo;

        genTypeInfo(d->loc, tc->next, NULL);
        dtb.xoff(toSymbol(tc->next->vtinfo), 0);   // TypeInfo for array of type

        dtb.size(tc->dim->toInteger());          // length
    }

    void visit(TypeInfoVectorDeclaration *d)
    {
        //printf("TypeInfoVectorDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfovector, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfovector), 0);   // vtbl for TypeInfo_Vector
        if (Type::typeinfovector->hasMonitor())
            dtb.size(0);                                   // monitor

        assert(d->tinfo->ty == Tvector);

        TypeVector *tc = (TypeVector *)d->tinfo;

        genTypeInfo(d->loc, tc->basetype, NULL);
        dtb.xoff(toSymbol(tc->basetype->vtinfo), 0); // TypeInfo for equivalent static array
    }

    void visit(TypeInfoAssociativeArrayDeclaration *d)
    {
        //printf("TypeInfoAssociativeArrayDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfoassociativearray, 4 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfoassociativearray), 0); // vtbl for TypeInfo_AssociativeArray
        if (Type::typeinfoassociativearray->hasMonitor())
            dtb.size(0);                    // monitor

        assert(d->tinfo->ty == Taarray);

        TypeAArray *tc = (TypeAArray *)d->tinfo;

        genTypeInfo(d->loc, tc->next, NULL);
        dtb.xoff(toSymbol(tc->next->vtinfo), 0);   // TypeInfo for array of type

        genTypeInfo(d->loc, tc->index, NULL);
        dtb.xoff(toSymbol(tc->index->vtinfo), 0);  // TypeInfo for array of type
    }

    void visit(TypeInfoFunctionDeclaration *d)
    {
        //printf("TypeInfoFunctionDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfofunction, 5 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfofunction), 0); // vtbl for TypeInfo_Function
        if (Type::typeinfofunction->hasMonitor())
            dtb.size(0);                                   // monitor

        assert(d->tinfo->ty == Tfunction);

        TypeFunction *tc = (TypeFunction *)d->tinfo;

        genTypeInfo(d->loc, tc->next, NULL);
        dtb.xoff(toSymbol(tc->next->vtinfo), 0); // TypeInfo for function return value

        const char *name = d->tinfo->deco;
        assert(name);
        size_t namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(d->csym, Type::typeinfofunction->structsize);

        // Put out name[] immediately following TypeInfo_Function
        dtb.nbytes(namelen + 1, name);
    }

    void visit(TypeInfoDelegateDeclaration *d)
    {
        //printf("TypeInfoDelegateDeclaration::toDt()\n");
        verifyStructSize(Type::typeinfodelegate, 5 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfodelegate), 0); // vtbl for TypeInfo_Delegate
        if (Type::typeinfodelegate->hasMonitor())
            dtb.size(0);                                   // monitor

        assert(d->tinfo->ty == Tdelegate);

        TypeDelegate *tc = (TypeDelegate *)d->tinfo;

        genTypeInfo(d->loc, tc->next->nextOf(), NULL);
        dtb.xoff(toSymbol(tc->next->nextOf()->vtinfo), 0); // TypeInfo for delegate return value

        const char *name = d->tinfo->deco;
        assert(name);
        size_t namelen = strlen(name);
        dtb.size(namelen);
        dtb.xoff(d->csym, Type::typeinfodelegate->structsize);

        // Put out name[] immediately following TypeInfo_Delegate
        dtb.nbytes(namelen + 1, name);
    }

    void visit(TypeInfoStructDeclaration *d)
    {
        //printf("TypeInfoStructDeclaration::toDt() '%s'\n", d->toChars());
        if (global.params.is64bit)
            verifyStructSize(Type::typeinfostruct, 17 * target.ptrsize);
        else
            verifyStructSize(Type::typeinfostruct, 15 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfostruct), 0); // vtbl for TypeInfo_Struct
        if (Type::typeinfostruct->hasMonitor())
            dtb.size(0);                                 // monitor

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
        dtb.size(namelen);
        dtb.xoff(d->csym, Type::typeinfostruct->structsize);

        // void[] init;
        dtb.size(sd->structsize);            // init.length
        if (sd->zeroInit)
            dtb.size(0);                     // NULL for 0 initialization
        else
            dtb.xoff(toInitializer(sd), 0);    // init.ptr

        if (FuncDeclaration *fd = sd->xhash)
        {
            dtb.xoff(toSymbol(fd), 0);
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
            dtb.size(0);

        if (sd->xeq)
            dtb.xoff(toSymbol(sd->xeq), 0);
        else
            dtb.size(0);

        if (sd->xcmp)
            dtb.xoff(toSymbol(sd->xcmp), 0);
        else
            dtb.size(0);

        if (FuncDeclaration *fd = search_toString(sd))
        {
            dtb.xoff(toSymbol(fd), 0);
        }
        else
            dtb.size(0);

        // StructFlags m_flags;
        StructFlags::Type m_flags = 0;
        if (tc->hasPointers()) m_flags |= StructFlags::hasPointers;
        dtb.size(m_flags);

    #if 0
        // xgetMembers
        FuncDeclaration *sgetmembers = sd->findGetMembers();
        if (sgetmembers)
            dtb.xoff(toSymbol(sgetmembers), 0);
        else
            dtb.size(0);                     // xgetMembers
    #endif

        // xdtor
        FuncDeclaration *sdtor = sd->dtor;
        if (sdtor)
            dtb.xoff(toSymbol(sdtor), 0);
        else
            dtb.size(0);                     // xdtor

        // xpostblit
        FuncDeclaration *spostblit = sd->postblit;
        if (spostblit && !(spostblit->storage_class & STCdisable))
            dtb.xoff(toSymbol(spostblit), 0);
        else
            dtb.size(0);                     // xpostblit

        // uint m_align;
        dtb.size(tc->alignsize());

        if (global.params.is64bit)
        {
            Type *t = sd->arg1type;
            for (int i = 0; i < 2; i++)
            {
                // m_argi
                if (t)
                {
                    genTypeInfo(d->loc, t, NULL);
                    dtb.xoff(toSymbol(t->vtinfo), 0);
                }
                else
                    dtb.size(0);

                t = sd->arg2type;
            }
        }

        // xgetRTInfo
        if (sd->getRTInfo)
        {
            Expression_toDt(sd->getRTInfo, dtb);
        }
        else if (m_flags & StructFlags::hasPointers)
            dtb.size(1);
        else
            dtb.size(0);

        // Put out name[] immediately following TypeInfo_Struct
        dtb.nbytes(namelen + 1, name);
    }

    void visit(TypeInfoClassDeclaration *d)
    {
        //printf("TypeInfoClassDeclaration::toDt() %s\n", tinfo->toChars());
        assert(0);
    }

    void visit(TypeInfoInterfaceDeclaration *d)
    {
        //printf("TypeInfoInterfaceDeclaration::toDt() %s\n", tinfo->toChars());
        verifyStructSize(Type::typeinfointerface, 3 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfointerface), 0);    // vtbl for TypeInfoInterface
        if (Type::typeinfointerface->hasMonitor())
            dtb.size(0);                                       // monitor

        assert(d->tinfo->ty == Tclass);

        TypeClass *tc = (TypeClass *)d->tinfo;
        Symbol *s;

        if (!tc->sym->vclassinfo)
            tc->sym->vclassinfo = TypeInfoClassDeclaration::create(tc);
        s = toSymbol(tc->sym->vclassinfo);
        dtb.xoff(s, 0);    // ClassInfo for tinfo
    }

    void visit(TypeInfoTupleDeclaration *d)
    {
        //printf("TypeInfoTupleDeclaration::toDt() %s\n", tinfo->toChars());
        verifyStructSize(Type::typeinfotypelist, 4 * target.ptrsize);

        dtb.xoff(toVtblSymbol(Type::typeinfotypelist), 0); // vtbl for TypeInfoInterface
        if (Type::typeinfotypelist->hasMonitor())
            dtb.size(0);                                   // monitor

        assert(d->tinfo->ty == Ttuple);

        TypeTuple *tu = (TypeTuple *)d->tinfo;

        size_t dim = tu->arguments->length;
        dtb.size(dim);                       // elements.length

        DtBuilder dtbargs;
        for (size_t i = 0; i < dim; i++)
        {
            Parameter *arg = (*tu->arguments)[i];

            genTypeInfo(d->loc, arg->type, NULL);
            Symbol *s = toSymbol(arg->type->vtinfo);
            dtbargs.xoff(s, 0);
        }

        dtb.dtoff(dtbargs.finish(), 0);                  // elements.ptr
    }
};

void TypeInfo_toDt(DtBuilder& dtb, TypeInfoDeclaration *d)
{
    TypeInfoDtVisitor v(dtb);
    d->accept(&v);
}
