
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
// Back end
#include        "dt.h"
/* ================================================================ */

dt_t *Initializer::toDt()
{
    assert(0);
    return NULL;
}


dt_t *VoidInitializer::toDt()
{   /* Void initializers are set to 0, just because we need something
     * to set them to in the static data segment.
     */
    dt_t *dt = NULL;

    dtnzeros(&dt, type->size());
    return dt;
}


dt_t *StructInitializer::toDt()
{
    //printf("StructInitializer::toDt('%s')\n", toChars());
    assert(0);
    return NULL;
}


dt_t *ArrayInitializer::toDt()
{
    //printf("ArrayInitializer::toDt('%s')\n", toChars());
    Type *tb = type->toBasetype();
    if (tb->ty == Tvector)
        tb = ((TypeVector *)tb)->basetype;

    Type *tn = tb->nextOf()->toBasetype();

    //printf("\tdim = %d\n", dim);
    Dts dts;
    dts.setDim(dim);
    dts.zero();

    unsigned size = tn->size();

    unsigned length = 0;
    for (size_t i = 0; i < index.dim; i++)
    {
        Expression *idx = index[i];
        if (idx)
            length = idx->toInteger();
        //printf("\tindex[%d] = %p, length = %u, dim = %u\n", i, idx, length, dim);

        assert(length < dim);
        Initializer *val = value[i];
        dt_t *dt = val->toDt();
        if (dts[length])
            error(loc, "duplicate initializations for index %d", length);
        dts[length] = dt;
        length++;
    }

    Expression *edefault = tb->nextOf()->defaultInit();

    size_t n = 1;
    for (Type *tbn = tn; tbn->ty == Tsarray; tbn = tbn->nextOf()->toBasetype())
    {   TypeSArray *tsa = (TypeSArray *)tbn;

        n *= tsa->dim->toInteger();
    }

    dt_t *d = NULL;
    dt_t **pdtend = &d;
    for (size_t i = 0; i < dim; i++)
    {
        dt_t *dt = dts[i];
        if (dt)
            pdtend = dtcat(pdtend, dt);
        else
        {
            for (size_t j = 0; j < n; j++)
                pdtend = edefault->toDt(pdtend);
        }
    }
    switch (tb->ty)
    {
        case Tsarray:
        {   size_t tadim;
            TypeSArray *ta = (TypeSArray *)tb;

            tadim = ta->dim->toInteger();
            if (dim < tadim)
            {
                if (edefault->isBool(false))
                    // pad out end of array
                    pdtend = dtnzeros(pdtend, size * (tadim - dim));
                else
                {
                    for (size_t i = dim; i < tadim; i++)
                    {   for (size_t j = 0; j < n; j++)
                            pdtend = edefault->toDt(pdtend);
                    }
                }
            }
            else if (dim > tadim)
            {
                error(loc, "too many initializers, %d, for array[%d]", dim, tadim);
            }
            break;
        }

        case Tpointer:
        case Tarray:
        {
            dt_t *dtarray = d;
            d = NULL;
            if (tb->ty == Tarray)
                dtsize_t(&d, dim);
            dtdtoff(&d, dtarray, 0);
            break;
        }

        default:
            assert(0);
    }
    return d;
}



dt_t *ExpInitializer::toDt()
{
    //printf("ExpInitializer::toDt() %s\n", exp->toChars());
    dt_t *dt = NULL;

    exp = exp->optimize(WANTvalue);
    exp->toDt(&dt);
    return dt;
}

/* ================================================================ */

dt_t **Expression::toDt(dt_t **pdt)
{
#if 0
    printf("Expression::toDt() %d\n", op);
    dump(0);
#endif
    error("non-constant expression %s", toChars());
    pdt = dtnzeros(pdt, 1);
    return pdt;
}

dt_t **CastExp::toDt(dt_t **pdt)
{
#if 0
    printf("CastExp::toDt() %d from %s to %s\n", op, e1->type->toChars(), type->toChars());
#endif
    if (e1->type->ty == Tclass && type->ty == Tclass)
    {
        if (((TypeClass*)type)->sym->isInterfaceDeclaration())//casting from class to interface
        {
            assert(e1->op == TOKclassreference);
            ClassDeclaration *from = ((ClassReferenceExp*)e1)->originalClass();
            InterfaceDeclaration* to = ((TypeClass*)type)->sym->isInterfaceDeclaration();
            int off = 0;
            int isbase = to->isBaseOf(from, &off);
            assert(isbase);
            return ((ClassReferenceExp*)e1)->toDtI(pdt, off);
        }
        else //casting from class to class
        {
            return e1->toDt(pdt);
        }
    }
    return UnaExp::toDt(pdt);
}

dt_t **AddrExp::toDt(dt_t **pdt)
{
#if 0
    printf("AddrExp::toDt() %d\n", op);
#endif
    if (e1->op == TOKstructliteral)
    {
        StructLiteralExp* sl = (StructLiteralExp*)e1;
        dtxoff(pdt, sl->toSymbol(), 0);
        return pdt;
    }
    return UnaExp::toDt(pdt);
}


dt_t **IntegerExp::toDt(dt_t **pdt)
{
    //printf("IntegerExp::toDt() %d\n", op);
    unsigned sz = type->size();
    if (value == 0)
        pdt = dtnzeros(pdt, sz);
    else
        pdt = dtnbytes(pdt, sz, (char *)&value);
    return pdt;
}

static char zeropad[6];

dt_t **RealExp::toDt(dt_t **pdt)
{
    //printf("RealExp::toDt(%Lg)\n", value);
    switch (type->toBasetype()->ty)
    {
        case Tfloat32:
        case Timaginary32:
        {   d_float32 fvalue = value;
            pdt = dtnbytes(pdt,4,(char *)&fvalue);
            break;
        }

        case Tfloat64:
        case Timaginary64:
        {   d_float64 dvalue = value;
            pdt = dtnbytes(pdt,8,(char *)&dvalue);
            break;
        }

        case Tfloat80:
        case Timaginary80:
        {   d_float80 evalue = value;
            pdt = dtnbytes(pdt,Target::realsize - Target::realpad,(char *)&evalue);
            pdt = dtnbytes(pdt,Target::realpad,zeropad);
            assert(Target::realpad <= sizeof(zeropad));
            break;
        }

        default:
            printf("%s\n", toChars());
            type->print();
            assert(0);
            break;
    }
    return pdt;
}

dt_t **ComplexExp::toDt(dt_t **pdt)
{
    //printf("ComplexExp::toDt() '%s'\n", toChars());

    switch (type->toBasetype()->ty)
    {
        case Tcomplex32:
        {   d_float32 fvalue = creall(value);
            pdt = dtnbytes(pdt,4,(char *)&fvalue);
            fvalue = cimagl(value);
            pdt = dtnbytes(pdt,4,(char *)&fvalue);
            break;
        }

        case Tcomplex64:
        {   d_float64 dvalue = creall(value);
            pdt = dtnbytes(pdt,8,(char *)&dvalue);
            dvalue = cimagl(value);
            pdt = dtnbytes(pdt,8,(char *)&dvalue);
            break;
        }

        case Tcomplex80:
        {   d_float80 evalue = creall(value);
            pdt = dtnbytes(pdt,Target::realsize - Target::realpad,(char *)&evalue);
            pdt = dtnbytes(pdt,Target::realpad,zeropad);
            evalue = cimagl(value);
            pdt = dtnbytes(pdt,Target::realsize - Target::realpad,(char *)&evalue);
            pdt = dtnbytes(pdt,Target::realpad,zeropad);
            break;
        }

        default:
            assert(0);
            break;
    }
    return pdt;
}

dt_t **NullExp::toDt(dt_t **pdt)
{
    assert(type);
    return dtnzeros(pdt, type->size());
}

dt_t **StringExp::toDt(dt_t **pdt)
{
    //printf("StringExp::toDt() '%s', type = %s\n", toChars(), type->toChars());
    Type *t = type->toBasetype();

    // BUG: should implement some form of static string pooling
    switch (t->ty)
    {
        case Tarray:
            dtsize_t(pdt, len);
            pdt = dtabytes(pdt, 0, (len + 1) * sz, (char *)string);
            break;

        case Tsarray:
        {
            TypeSArray *tsa = (TypeSArray *)t;

            pdt = dtnbytes(pdt, len * sz, (const char *)string);
            if (tsa->dim)
            {
                dinteger_t dim = tsa->dim->toInteger();
                if (len < dim)
                {
                    // Pad remainder with 0
                    pdt = dtnzeros(pdt, (dim - len) * tsa->next->size());
                }
            }
            break;
        }
        case Tpointer:
            pdt = dtabytes(pdt, 0, (len + 1) * sz, (char *)string);
            break;

        default:
            printf("StringExp::toDt(type = %s)\n", type->toChars());
            assert(0);
    }
    return pdt;
}

dt_t **ArrayLiteralExp::toDt(dt_t **pdt)
{
    //printf("ArrayLiteralExp::toDt() '%s', type = %s\n", toChars(), type->toChars());

    dt_t *d = NULL;
    dt_t **pdtend = &d;
    for (size_t i = 0; i < elements->dim; i++)
    {   Expression *e = (*elements)[i];

        pdtend = e->toDt(pdtend);
    }
    Type *t = type->toBasetype();

    switch (t->ty)
    {
        case Tsarray:
            pdt = dtcat(pdt, d);
            break;

        case Tpointer:
        case Tarray:
            if (t->ty == Tarray)
                dtsize_t(pdt, elements->dim);
            if (d)
                dtdtoff(pdt, d, 0);
            else
                dtsize_t(pdt, 0);

            break;

        default:
            assert(0);
    }
    return pdt;
}

dt_t **StructLiteralExp::toDt(dt_t **pdt)
{
    //printf("StructLiteralExp::toDt() %s, ctfe = %d\n", toChars(), ownedByCtfe);
    assert(sd->fields.dim - sd->isNested() <= elements->dim);

    unsigned offset = 0;
    for (size_t i = 0; i < elements->dim; i++)
    {
        Expression *e = (*elements)[i];
        if (!e)
            continue;

        VarDeclaration *vd = NULL;
        size_t k;
        for (size_t j = i; j < elements->dim; j++)
        {
            VarDeclaration *v2 = sd->fields[j];
            if (v2->offset < offset || (*elements)[j] == NULL)
                continue;

            // find the nearest field
            if (!vd)
                vd = v2, k = j;
            else if (v2->offset < vd->offset)
            {
                // Each elements should have no overlapping
                assert(!(vd->offset < v2->offset + v2->type->size() &&
                         v2->offset < vd->offset + vd->type->size()));
                vd = v2, k = j;
            }
        }
        if (vd)
        {
            if (offset < vd->offset)
                pdt = dtnzeros(pdt, vd->offset - offset);
            e = (*elements)[k];

            Type *tb = vd->type->toBasetype();
            if (tb->ty == Tsarray)
                ((TypeSArray *)tb)->toDtElem(pdt, e);
            else
                e->toDt(pdt);           // convert e to an initializer dt

            offset = vd->offset + vd->type->size();
        }
    }
    if (offset < sd->structsize)
        pdt = dtnzeros(pdt, sd->structsize - offset);

    return pdt;
}


dt_t **SymOffExp::toDt(dt_t **pdt)
{
    //printf("SymOffExp::toDt('%s')\n", var->toChars());
    assert(var);
    if (!(var->isDataseg() || var->isCodeseg()) ||
        var->needThis() ||
        var->isThreadlocal())
    {
#if 0
        printf("SymOffExp::toDt()\n");
#endif
        error("non-constant expression %s", toChars());
        return pdt;
    }
    return dtxoff(pdt, var->toSymbol(), offset);
}

dt_t **VarExp::toDt(dt_t **pdt)
{
    //printf("VarExp::toDt() %d\n", op);
    pdt = dtend(pdt);

    VarDeclaration *v = var->isVarDeclaration();
    if (v && (v->isConst() || v->isImmutable()) &&
        type->toBasetype()->ty != Tsarray && v->init)
    {
        if (v->inuse)
        {
            error("recursive reference %s", toChars());
            return pdt;
        }
        v->inuse++;
        *pdt = v->init->toDt();
        v->inuse--;
        return pdt;
    }
    SymbolDeclaration *sd = var->isSymbolDeclaration();
    if (sd && sd->dsym)
    {
        sd->dsym->toDt(pdt);
        return pdt;
    }
#if 0
    printf("VarExp::toDt(), kind = %s\n", var->kind());
#endif
    error("non-constant expression %s", toChars());
    pdt = dtnzeros(pdt, 1);
    return pdt;
}

dt_t **FuncExp::toDt(dt_t **pdt)
{
    //printf("FuncExp::toDt() %d\n", op);
    if (fd->tok == TOKreserved && type->ty == Tpointer)
    {   // change to non-nested
        fd->tok = TOKfunction;
        fd->vthis = NULL;
    }
    Symbol *s = fd->toSymbol();
    if (fd->isNested())
    {   error("non-constant nested delegate literal expression %s", toChars());
        return NULL;
    }
    fd->toObjFile(0);
    return dtxoff(pdt, s, 0);
}

dt_t **VectorExp::toDt(dt_t **pdt)
{
    //printf("VectorExp::toDt() %s\n", toChars());
    for (size_t i = 0; i < dim; i++)
    {   Expression *elem;

        if (e1->op == TOKarrayliteral)
        {
            ArrayLiteralExp *ea = (ArrayLiteralExp *)e1;
            elem = (*ea->elements)[i];
        }
        else
            elem = e1;
        pdt = elem->toDt(pdt);
    }
    return pdt;
}

/* ================================================================= */

// Generate the data for the static initializer.

void ClassDeclaration::toDt(dt_t **pdt)
{
    //printf("ClassDeclaration::toDt(this = '%s')\n", toChars());

    // Put in first two members, the vtbl[] and the monitor
    dtxoff(pdt, toVtblSymbol(), 0);
    if (!cpp)
        dtsize_t(pdt, 0);                    // monitor

    // Put in the rest
    toDt2(pdt, this);

    //printf("-ClassDeclaration::toDt(this = '%s')\n", toChars());
}

void ClassDeclaration::toDt2(dt_t **pdt, ClassDeclaration *cd)
{
    unsigned offset;
    dt_t *dt;
    unsigned csymoffset;

#define LOG 0

#if LOG
    printf("ClassDeclaration::toDt2(this = '%s', cd = '%s')\n", toChars(), cd->toChars());
#endif
    if (baseClass)
    {
        baseClass->toDt2(pdt, cd);
        offset = baseClass->structsize;
    }
    else
    {
        offset = Target::ptrsize * 2;
    }

    // Note equivalence of this loop to struct's
    for (size_t i = 0; i < fields.dim; i++)
    {
        VarDeclaration *v = fields[i];
        Initializer *init;

        //printf("\t\tv = '%s' v->offset = %2d, offset = %2d\n", v->toChars(), v->offset, offset);
        dt = NULL;
        init = v->init;
        if (init)
        {   //printf("\t\t%s has initializer %s\n", v->toChars(), init->toChars());
            ExpInitializer *ei = init->isExpInitializer();
            Type *tb = v->type->toBasetype();
            if (init->isVoidInitializer())
                ;
            else if (ei && tb->ty == Tsarray)
                ((TypeSArray *)tb)->toDtElem(&dt, ei->exp);
            else
                dt = init->toDt();
        }
        else if (v->offset >= offset)
        {   //printf("\t\tdefault initializer\n");
            v->type->toDt(&dt);
        }
        if (dt)
        {
            if (v->offset < offset)
                error("duplicated union initialization for %s", v->toChars());
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
    toSymbol();                                         // define csym

    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {   BaseClass *b = (*vtblInterfaces)[i];

        for (ClassDeclaration *cd2 = cd; 1; cd2 = cd2->baseClass)
        {
            assert(cd2);
            csymoffset = cd2->baseVtblOffset(b);
            if (csymoffset != ~0)
            {
                if (offset < b->offset)
                    dtnzeros(pdt, b->offset - offset);
                dtxoff(pdt, cd2->toSymbol(), csymoffset);
                break;
            }
        }
        offset = b->offset + Target::ptrsize;
    }

    if (offset < structsize)
        dtnzeros(pdt, structsize - offset);

#undef LOG
}

void StructDeclaration::toDt(dt_t **pdt)
{
    //printf("StructDeclaration::toDt(), this='%s'\n", toChars());
    StructLiteralExp *sle = StructLiteralExp::create(loc, this, NULL);
    if (!fill(loc, sle->elements, true))
        assert(0);

    //printf("sd->toDt sle = %s\n", sle->toChars());
    sle->type = type;
    sle->toDt(pdt);
}

/* ================================================================= */

dt_t **Type::toDt(dt_t **pdt)
{
    //printf("Type::toDt()\n");
    Expression *e = defaultInit();
    return e->toDt(pdt);
}

dt_t **TypeVector::toDt(dt_t **pdt)
{
    assert(basetype->ty == Tsarray);
    return ((TypeSArray *)basetype)->toDtElem(pdt, NULL);
}

dt_t **TypeSArray::toDt(dt_t **pdt)
{
    return toDtElem(pdt, NULL);
}

dt_t **TypeSArray::toDtElem(dt_t **pdt, Expression *e)
{
    //printf("TypeSArray::toDtElem()\n");
    size_t len = dim->toInteger();
    if (len)
    {
        pdt = dtend(pdt);
        Type *tnext = next;
        Type *tbn = tnext->toBasetype();
        while (tbn->ty == Tsarray && (!e || tbn != e->type->nextOf()))
        {
            TypeSArray *tsa = (TypeSArray *)tbn;
            len *= tsa->dim->toInteger();
            tnext = tbn->nextOf();
            tbn = tnext->toBasetype();
        }
        if (!e)                         // if not already supplied
            e = tnext->defaultInit();   // use default initializer
        e->toDt(pdt);
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
                if (tbn->ty == Tstruct)
                {   pdt = tnext->toDt(pdt);
                    pdt = dtend(pdt);
                }
                else
                    pdt = e->toDt(pdt);
            }
        }
    }
    return pdt;
}

dt_t **TypeStruct::toDt(dt_t **pdt)
{
    sym->toDt(pdt);
    return pdt;
}

dt_t **TypeTypedef::toDt(dt_t **pdt)
{
    if (sym->init)
    {
        dt_t *dt = sym->init->toDt();

        pdt = dtend(pdt);
        *pdt = dt;
        return pdt;
    }
    sym->basetype->toDt(pdt);
    return pdt;
}

/*****************************************************/
/*                   CTFE stuff                      */
/*****************************************************/

dt_t **ClassReferenceExp::toDt(dt_t **pdt)
{
    InterfaceDeclaration* to = ((TypeClass *)type)->sym->isInterfaceDeclaration();

    if (to) //Static typeof this literal is an interface. We must add offset to symbol
    {
        ClassDeclaration *from = originalClass();
        int off = 0;
        int isbase = to->isBaseOf(from, &off);
        assert(isbase);
        return toDtI(pdt, off);
    }
    return toDtI(pdt, 0);
}

dt_t **ClassReferenceExp::toDtI(dt_t **pdt, int off)
{
#if 0
    printf("ClassReferenceExp::toDtI() %d\n", op);
#endif

    dtxoff(pdt, toSymbol(), off);
    return pdt;
}

dt_t **ClassReferenceExp::toInstanceDt(dt_t **pdt)
{
#if 0
    printf("ClassReferenceExp::toInstanceDt() %d\n", op);
#endif
    dt_t *d = NULL;
    dt_t **pdtend = &d;

    Dts dts;
    dts.setDim(value->elements->dim);
    dts.zero();
    //assert(value->elements->dim <= value->sd->fields.dim);
    for (size_t i = 0; i < value->elements->dim; i++)
    {
        Expression *e = (*value->elements)[i];
        if (!e)
            continue;
        dt_t *dt = NULL;
        e->toDt(&dt);           // convert e to an initializer dt
        dts[i] = dt;
    }
    dtxoff(pdtend, originalClass()->toVtblSymbol(), 0);
    dtsize_t(pdtend, 0);                    // monitor
    // Put in the rest
    toDt2(&d, originalClass(), &dts);
    *pdt = d;
    return pdt;
}

// Generates the data for the static initializer of class variable.
// dts is an array of dt fields, which values have been evaluated in compile time.
// cd - is a ClassDeclaration, for which initializing data is being built
// this function, being alike to ClassDeclaration::toDt2, recursively builds the dt for all base classes.
dt_t **ClassReferenceExp::toDt2(dt_t **pdt, ClassDeclaration *cd, Dts *dts)
{
    unsigned offset;
    unsigned csymoffset;
#define LOG 0

#if LOG
    printf("ClassReferenceExp::toDt2(this = '%s', cd = '%s')\n", toChars(), cd->toChars());
#endif
    if (cd->baseClass)
    {
        toDt2(pdt, cd->baseClass, dts);
        offset = cd->baseClass->structsize;
    }
    else
    {
        offset = Target::ptrsize * 2;
    }
    for (size_t i = 0; i < cd->fields.dim; i++)
    {
        VarDeclaration *v = cd->fields[i];
        int idx = findFieldIndexByName(v);
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
                    ((TypeSArray *)tb)->toDtElem(&dt, ei->exp);
                else
                    dt = init->toDt();
            }
            else if (v->offset >= offset)
            {   //printf("\t\tdefault initializer\n");
                v->type->toDt(&dt);
            }
            if (dt)
            {
                if (v->offset < offset)
                    error("duplicated union initialization for %s", v->toChars());
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
              error("duplicate union initialization for %s", v->toChars());
          else
          {
              unsigned sz = dt_size(d);
              unsigned vsz = v->type->size();
              unsigned voffset = v->offset;

              if (sz > vsz)
              {   assert(v->type->ty == Tsarray && vsz == 0);
                  error("zero length array %s has non-zero length initializer", v->toChars());
              }

              size_t dim = 1;
              Type *vt;
              for (vt = v->type->toBasetype();
                   vt->ty == Tsarray;
                   vt = vt->nextOf()->toBasetype())
              {   TypeSArray *tsa = (TypeSArray *)vt;
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
                          d = v->init->toDt();
                      else
                          vt->toDt(&d);
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
    cd->toSymbol();                                         // define csym

    for (size_t i = 0; i < cd->vtblInterfaces->dim; i++)
    {   BaseClass *b = (*cd->vtblInterfaces)[i];

        for (ClassDeclaration *cd2 = originalClass(); 1; cd2 = cd2->baseClass)
        {
            assert(cd2);
            csymoffset = cd2->baseVtblOffset(b);
            if (csymoffset != ~0)
            {
                if (offset < b->offset)
                    dtnzeros(pdt, b->offset - offset);
                dtxoff(pdt, cd2->toSymbol(), csymoffset);
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
