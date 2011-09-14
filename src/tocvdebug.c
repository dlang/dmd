
// Copyright (c) 2004-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com

#include <stdio.h>
#include <stddef.h>
#include <time.h>
#include <assert.h>

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "declaration.h"
#include "statement.h"
#include "enum.h"
#include "aggregate.h"
#include "init.h"
#include "attrib.h"
#include "id.h"
#include "import.h"
#include "template.h"

#include "rmem.h"
#include "cc.h"
#include "global.h"
#include "oper.h"
#include "code.h"
#include "type.h"
#include "dt.h"
#include "cv4.h"
#include "cgcv.h"
#include "outbuf.h"
#include "irstate.h"

/* The CV4 debug format is defined in:
 *      "CV4 Symbolic Debug Information Specification"
 *      rev 3.1 March 5, 1993
 *      Languages Business Unit
 *      Microsoft
 */

/******************************
 * CV4 pg. 25
 * Convert D protection attribute to cv attribute.
 */

unsigned PROTtoATTR(enum PROT prot)
{
    unsigned attribute;

    switch (prot)
    {
        case PROTprivate:       attribute = 1;  break;
        case PROTpackage:       attribute = 2;  break;
        case PROTprotected:     attribute = 2;  break;
        case PROTpublic:        attribute = 3;  break;
        case PROTexport:        attribute = 3;  break;

        case PROTundefined:
        case PROTnone:
        default:
            //printf("prot = %d\n", prot);
            assert(0);
    }
    return attribute;
}

unsigned cv4_memfunctypidx(FuncDeclaration *fd)
{   type *t;
    debtyp_t *d;
    unsigned char *p;
    AggregateDeclaration *ad;

    //printf("cv4_memfunctypidx(fd = '%s')\n", fd->toChars());
    t = fd->type->toCtype();
    ad = fd->isMember2();
    if (ad)
    {
        unsigned nparam;
        idx_t paramidx;
        idx_t thisidx;
        unsigned char call;

        // It's a member function, which gets a special type record

        if (fd->isStatic())
            thisidx = dttab4[TYvoid];
        else
        {
            assert(ad->handle);
            thisidx = cv4_typidx(ad->handle->toCtype());
        }

        paramidx = cv4_arglist(t,&nparam);
        call = cv4_callconv(t);

        d = debtyp_alloc(18);
        p = d->data;
        TOWORD(p,LF_MFUNCTION);
        TOWORD(p + 2,cv4_typidx(t->Tnext));
        TOWORD(p + 4,cv4_typidx(ad->type->toCtype()));
        TOWORD(p + 6,thisidx);
        p[8] = call;
        p[9] = 0;                               // reserved
        TOWORD(p + 10,nparam);
        TOWORD(p + 12,paramidx);
        TOLONG(p + 14,0);                       // thisadjust

        return cv_debtyp(d);
    }
    return cv4_typidx(t);
}

unsigned cv4_Denum(EnumDeclaration *e)
{
    debtyp_t *d,*dt;
    unsigned nfields,fnamelen;
    unsigned len;
    unsigned property;
    unsigned attribute;
    const char *id;
    idx_t typidx;

    //dbg_printf("cv4_Denum(%s)\n", e->toChars());
    property = 0;
    if (!e->members || !e->memtype)
        property |= 0x80;               // enum is forward referenced

    id = e->toPrettyChars();
    len = 10;
    d = debtyp_alloc(len + cv_stringbytes(id));
    TOWORD(d->data,LF_ENUM);
    TOWORD(d->data + 4,e->memtype ? cv4_typidx(e->memtype->toCtype()) : 0);
    TOWORD(d->data + 8,property);
    len += cv_namestring(d->data + len,id);

    d->length = 0;                      // so cv_debtyp() will allocate new
    typidx = cv_debtyp(d);
    d->length = len;                    // restore length

    // Compute the number of fields, and the length of the fieldlist record
    nfields = 0;
    fnamelen = 2;
    if (!property)
    {
        for (size_t i = 0; i < e->members->dim; i++)
        {   EnumMember *sf = (e->members->tdata()[i])->isEnumMember();
            dinteger_t value;

            if (sf)
            {
                value = sf->value->toInteger();
                unsigned fnamelen1 = fnamelen;
                // store only member's simple name
                fnamelen += 4 + cv4_numericbytes(value) + cv_stringbytes(sf->toChars());

                /* Optlink dies on longer ones, so just truncate
                 */
                if (fnamelen > 0xB000)          // 0xB000 found by trial and error
                {   fnamelen = fnamelen1;       // back up
                    break;                      // and skip the rest
                }

                nfields++;
            }
        }
    }

    TOWORD(d->data + 2,nfields);

    // If forward reference, then field list is 0
    if (property)
    {
        TOWORD(d->data + 6,0);
        return typidx;
    }

    // Generate fieldlist type record
    dt = debtyp_alloc(fnamelen);
    TOWORD(dt->data,LF_FIELDLIST);

    // And fill it in
    unsigned j = 2;
    unsigned fieldi = 0;
    for (size_t i = 0; i < e->members->dim; i++)
    {   EnumMember *sf = (e->members->tdata()[i])->isEnumMember();
        dinteger_t value;

        if (sf)
        {
            fieldi++;
            if (fieldi > nfields)
                break;                  // chop off the rest

            value = sf->value->toInteger();
            TOWORD(dt->data + j,LF_ENUMERATE);
            attribute = 0;
            TOWORD(dt->data + j + 2,attribute);
            cv4_storenumeric(dt->data + j + 4,value);
            j += 4 + cv4_numericbytes(value);
            // store only member's simple name
            j += cv_namestring(dt->data + j, sf->toChars());

            // If enum is not a member of a class, output enum members as constants
//          if (!isclassmember(s))
//          {
//              cv4_outsym(sf);
//          }
        }
    }
    assert(j == fnamelen);
    TOWORD(d->data + 6,cv_debtyp(dt));

//    cv4_outsym(s);
    return typidx;
}

/* ==================================================================== */

/****************************
 * Emit symbolic debug info in CV format.
 */

void TypedefDeclaration::toDebug()
{
    //printf("TypedefDeclaration::toDebug('%s')\n", toChars());

    assert(config.fulltypes >= CV4);

    // If it is a member, it is handled by cvMember()
    if (!isMember())
    {
        if (basetype->ty == Ttuple)
            return;

        unsigned length;
        const char *id = toPrettyChars();
        idx_t typidx = cv4_typidx(basetype->toCtype());
        unsigned len = strlen(id);
        unsigned char *debsym = (unsigned char *) alloca(39 + IDOHD + len);

        // Output a 'user-defined type' for the tag name
        TOWORD(debsym + 2,S_UDT);
        TOIDX(debsym + 4,typidx);
        length = 2 + 2 + cgcv.sz_idx;
        length += cv_namestring(debsym + length,id);
        TOWORD(debsym,length - 2);

        assert(length <= 40 + len);
        obj_write_bytes(SegData[DEBSYM],length,debsym);
    }
}


void EnumDeclaration::toDebug()
{
    //printf("EnumDeclaration::toDebug('%s')\n", toChars());

    assert(config.fulltypes >= CV4);

    // If it is a member, it is handled by cvMember()
    if (!isMember())
    {
        unsigned length;
        const char *id = toPrettyChars();
        idx_t typidx = cv4_Denum(this);
        unsigned len = strlen(id);
        unsigned char *debsym = (unsigned char *) alloca(39 + IDOHD + len);

        // Output a 'user-defined type' for the tag name
        TOWORD(debsym + 2,S_UDT);
        TOIDX(debsym + 4,typidx);
        length = 2 + 2 + cgcv.sz_idx;
        length += cv_namestring(debsym + length,id);
        TOWORD(debsym,length - 2);

        assert(length <= 40 + len);
        obj_write_bytes(SegData[DEBSYM],length,debsym);
    }
}


void StructDeclaration::toDebug()
{
    unsigned leaf;
    unsigned property;
    unsigned nfields;
    unsigned fnamelen;
    const char *id;
    targ_size_t size;
    unsigned numidx;
    debtyp_t *d,*dt;
    unsigned len;
    int count;                  // COUNT field in LF_CLASS
    unsigned char *p;
    idx_t typidx = 0;

    //printf("StructDeclaration::toDebug('%s')\n", toChars());

    assert(config.fulltypes >= CV4);
    if (isAnonymous())
        return /*0*/;

    if (typidx)                 // if reference already generated
        return /*typidx*/;      // use already existing reference

    property = 0;
    if (!members)
    {   size = 0;
        property |= 0x80;               // forward reference
    }
    else
        size = structsize;

    if (parent->isAggregateDeclaration()) // if class is nested
        property |= 8;
//    if (st->Sctor || st->Sdtor)
//      property |= 2;          // class has ctors and/or dtors
//    if (st->Sopoverload)
//      property |= 4;          // class has overloaded operators
//    if (st->Scastoverload)
//      property |= 0x40;               // class has casting methods
//    if (st->Sopeq && !(st->Sopeq->Sfunc->Fflags & Fnodebug))
//      property |= 0x20;               // class has overloaded assignment

    id = toPrettyChars();
    numidx = isUnionDeclaration() ? 8 : 12;
    len = numidx + cv4_numericbytes(size);
    d = debtyp_alloc(len + cv_stringbytes(id));
    cv4_storenumeric(d->data + numidx,size);
    len += cv_namestring(d->data + len,id);

    leaf = isUnionDeclaration() ? LF_UNION : LF_STRUCTURE;
    if (!isUnionDeclaration())
    {
        TOWORD(d->data + 8,0);          // dList
        TOWORD(d->data + 10,0);         // vshape is 0 (no virtual functions)
    }
    TOWORD(d->data,leaf);

    // Assign a number to prevent infinite recursion if a struct member
    // references the same struct.
    d->length = 0;                      // so cv_debtyp() will allocate new
    typidx = cv_debtyp(d);
    d->length = len;            // restore length

    if (!members)                       // if reference only
    {
        TOWORD(d->data + 2,0);          // count: number of fields is 0
        TOWORD(d->data + 4,0);          // field list is 0
        TOWORD(d->data + 6,property);
        return /*typidx*/;
    }

    // Compute the number of fields, and the length of the fieldlist record
    nfields = 0;
    fnamelen = 2;

    count = nfields;
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = members->tdata()[i];
        int nwritten;

        nwritten = s->cvMember(NULL);
        if (nwritten)
        {
            fnamelen += nwritten;
            nfields++;
            count++;
        }
    }

    TOWORD(d->data + 2,count);
    TOWORD(d->data + 6,property);

    // Generate fieldlist type record
    dt = debtyp_alloc(fnamelen);
    p = dt->data;

    // And fill it in
    TOWORD(p,LF_FIELDLIST);
    p += 2;
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = members->tdata()[i];

        p += s->cvMember(p);
    }

    //dbg_printf("fnamelen = %d, p-dt->data = %d\n",fnamelen,p-dt->data);
    assert(p - dt->data == fnamelen);
    TOWORD(d->data + 4,cv_debtyp(dt));

//    cv4_outsym(s);

    unsigned char *debsym;
    unsigned length;

    len = strlen(id);
    debsym = (unsigned char *) alloca(39 + IDOHD + len);

    // Output a 'user-defined type' for the tag name
    TOWORD(debsym + 2,S_UDT);
    TOIDX(debsym + 4,typidx);
    length = 2 + 2 + cgcv.sz_idx;
    length += cv_namestring(debsym + length,id);
    TOWORD(debsym,length - 2);

    assert(length <= 40 + len);
    obj_write_bytes(SegData[DEBSYM],length,debsym);

//    return typidx;
}


void ClassDeclaration::toDebug()
{
    unsigned leaf;
    unsigned property;
    unsigned nfields;
    unsigned fnamelen;
    const char *id;
    targ_size_t size;
    unsigned numidx;
    debtyp_t *d,*dt;
    unsigned len;
    int i;
    int count;                  // COUNT field in LF_CLASS
    unsigned char *p;
    idx_t typidx = 0;

    //printf("ClassDeclaration::toDebug('%s')\n", toChars());

    assert(config.fulltypes >= CV4);
    if (isAnonymous())
        return /*0*/;

    if (typidx)                 // if reference already generated
        return /*typidx*/;      // use already existing reference

    property = 0;
    if (!members)
    {   size = 0;
        property |= 0x80;               // forward reference
    }
    else
        size = structsize;

    if (parent->isAggregateDeclaration()) // if class is nested
        property |= 8;
    if (ctor || dtors.dim)
        property |= 2;          // class has ctors and/or dtors
//    if (st->Sopoverload)
//      property |= 4;          // class has overloaded operators
//    if (st->Scastoverload)
//      property |= 0x40;               // class has casting methods
//    if (st->Sopeq && !(st->Sopeq->Sfunc->Fflags & Fnodebug))
//      property |= 0x20;               // class has overloaded assignment

    id = isCPPinterface() ? ident->toChars() : toPrettyChars();
    numidx = isUnionDeclaration() ? 8 : 12;
    len = numidx + cv4_numericbytes(size);
    d = debtyp_alloc(len + cv_stringbytes(id));
    cv4_storenumeric(d->data + numidx,size);
    len += cv_namestring(d->data + len,id);

    leaf = LF_CLASS;
    TOWORD(d->data + 8,0);              // dList

    if (1)
    {   debtyp_t *vshape;
        unsigned char descriptor;

        size_t n = vtbl.dim;                   // number of virtual functions
        if (n == 0)
        {
            TOWORD(d->data + 10,0);             // vshape is 0
        }
        else
        {
            vshape = debtyp_alloc(4 + (n + 1) / 2);
            TOWORD(vshape->data,LF_VTSHAPE);
            TOWORD(vshape->data + 2,1);

            n = 0;
            descriptor = 0;
            for (size_t i = 0; i < vtbl.dim; i++)
            {   FuncDeclaration *fd = (FuncDeclaration *)vtbl.tdata()[i];

                //if (intsize == 4)
                    descriptor |= 5;
                vshape->data[4 + n / 2] = descriptor;
                descriptor <<= 4;
                n++;
            }
            TOWORD(d->data + 10,cv_debtyp(vshape));     // vshape
        }
    }
    else
        TOWORD(d->data + 10,0);         // vshape is 0 (no virtual functions)

    TOWORD(d->data,leaf);

    // Assign a number to prevent infinite recursion if a struct member
    // references the same struct.
    d->length = 0;                      // so cv_debtyp() will allocate new
    typidx = cv_debtyp(d);
    d->length = len;            // restore length

    if (!members)                       // if reference only
    {
        TOWORD(d->data + 2,0);          // count: number of fields is 0
        TOWORD(d->data + 4,0);          // field list is 0
        TOWORD(d->data + 6,property);
        return /*typidx*/;
    }

    // Compute the number of fields, and the length of the fieldlist record
    nfields = 0;
    fnamelen = 2;

    // Add in base classes
    for (size_t i = 0; i < baseclasses->dim; i++)
    {   BaseClass *bc = baseclasses->tdata()[i];

        nfields++;
        fnamelen += 6 + cv4_numericbytes(bc->offset);
    }

    count = nfields;
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = members->tdata()[i];
        int nwritten;

        nwritten = s->cvMember(NULL);
        if (nwritten)
        {
            fnamelen += nwritten;
            nfields++;
            count++;
        }
    }

    TOWORD(d->data + 2,count);
    TOWORD(d->data + 6,property);

    // Generate fieldlist type record
    dt = debtyp_alloc(fnamelen);
    p = dt->data;

    // And fill it in
    TOWORD(p,LF_FIELDLIST);
    p += 2;

    // Add in base classes
    for (size_t i = 0; i < baseclasses->dim; i++)
    {   BaseClass *bc = baseclasses->tdata()[i];
        idx_t typidx;
        unsigned attribute;

        typidx = cv4_typidx(bc->base->type->toCtype()->Tnext);

        attribute = PROTtoATTR(bc->protection);

        TOWORD(p,LF_BCLASS);
        TOWORD(p + 2,typidx);
        TOWORD(p + 4,attribute);
        p += 6;

        cv4_storenumeric(p, bc->offset);
        p += cv4_numericbytes(bc->offset);
    }



    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = members->tdata()[i];

        p += s->cvMember(p);
    }

    //dbg_printf("fnamelen = %d, p-dt->data = %d\n",fnamelen,p-dt->data);
    assert(p - dt->data == fnamelen);
    TOWORD(d->data + 4,cv_debtyp(dt));

//    cv4_outsym(s);

    unsigned char *debsym;
    unsigned length;

    len = strlen(id);
    debsym = (unsigned char *) alloca(39 + IDOHD + len);

    // Output a 'user-defined type' for the tag name
    TOWORD(debsym + 2,S_UDT);
    TOIDX(debsym + 4,typidx);
    length = 2 + 2 + cgcv.sz_idx;
    length += cv_namestring(debsym + length,id);
    TOWORD(debsym,length - 2);

    assert(length <= 40 + len);
    obj_write_bytes(SegData[DEBSYM],length,debsym);

//    return typidx;
}


/* ===================================================================== */

/*****************************************
 * Insert CV info into *p.
 * Returns:
 *      number of bytes written, or that would be written if p==NULL
 */

int Dsymbol::cvMember(unsigned char *p)
{
    return 0;
}


int TypedefDeclaration::cvMember(unsigned char *p)
{
    char *id;
    idx_t typidx;
    int nwritten = 0;

    //printf("TypedefDeclaration::cvMember() '%s'\n", toChars());
    id = toChars();

    if (!p)
    {
        nwritten = 4 + cv_stringbytes(id);
    }
    else
    {
        TOWORD(p,LF_NESTTYPE);
        typidx = cv4_typidx(basetype->toCtype());
        TOWORD(p + 2,typidx);
        nwritten = 4 + cv_namestring(p + 4, id);
    }
    return nwritten;
}


int EnumDeclaration::cvMember(unsigned char *p)
{
    char *id;
    idx_t typidx;
    int nwritten = 0;

    //printf("EnumDeclaration::cvMember() '%s'\n", toChars());
    id = toChars();

    if (!p)
    {
        nwritten = 4 + cv_stringbytes(id);
    }
    else
    {
        TOWORD(p,LF_NESTTYPE);
        typidx = cv4_Denum(this);
        TOWORD(p + 2,typidx);
        nwritten = 4 + cv_namestring(p + 4, id);
    }
    return nwritten;
}


int FuncDeclaration::cvMember(unsigned char *p)
{
    char *id;
    idx_t typidx;
    unsigned attribute;
    int nwritten = 0;
    debtyp_t *d;

    //printf("FuncDeclaration::cvMember() '%s'\n", toChars());

    if (!type)                  // if not compiled in,
        return 0;               // skip it

    id = toChars();

    if (!p)
    {
        nwritten = 6 + cv_stringbytes(id);
    }
    else
    {
        int count;
        int mlen;
        unsigned char *q;

        count = 0;
        mlen = 2;
        {
            if (introducing)
                mlen += 4;
            mlen += cgcv.sz_idx * 2;
            count++;
        }

        // Allocate and fill it in
        d = debtyp_alloc(mlen);
        q = d->data;
        TOWORD(q,LF_METHODLIST);
        q += 2;
//      for (s = sf; s; s = s->Sfunc->Foversym)
        {
            attribute = PROTtoATTR(prot());

            /* 0*4 vanilla method
             * 1*4 virtual method
             * 2*4 static method
             * 3*4 friend method
             * 4*4 introducing virtual method
             * 5*4 pure virtual method
             * 6*4 pure introducing virtual method
             * 7*4 reserved
             */

            if (isStatic())
                attribute |= 2*4;
            else if (isVirtual())
            {
                if (introducing)
                {
                    if (isAbstract())
                        attribute |= 6*4;
                    else
                        attribute |= 4*4;
                }
                else
                {
                    if (isAbstract())
                        attribute |= 5*4;
                    else
                        attribute |= 1*4;
                }
            }
            else
                attribute |= 0*4;

            TOIDX(q,attribute);
            q += cgcv.sz_idx;
            TOIDX(q, cv4_memfunctypidx(this));
            q += cgcv.sz_idx;
            if (introducing)
            {   TOLONG(q, vtblIndex * PTRSIZE);
                q += 4;
            }
        }
        assert(q - d->data == mlen);

        typidx = cv_debtyp(d);
        if (typidx)
        {
            TOWORD(p,LF_METHOD);
            TOWORD(p + 2,count);
            nwritten = 4;
            TOIDX(p + nwritten, typidx);
            nwritten += cgcv.sz_idx;
            nwritten += cv_namestring(p + nwritten, id);
        }
    }
    return nwritten;
}

int VarDeclaration::cvMember(unsigned char *p)
{
    char *id;
    idx_t typidx;
    unsigned attribute;
    int nwritten = 0;

    //printf("VarDeclaration::cvMember(p = %p) '%s'\n", p, toChars());

    if (type->toBasetype()->ty == Ttuple)
        return 0;

    id = toChars();

    if (!p)
    {
        if (storage_class & STCfield)
        {
            nwritten += 6 +
                    cv4_numericbytes(offset) + cv_stringbytes(id);
        }
        else if (isStatic())
        {
            nwritten += 6 + cv_stringbytes(id);
        }
    }
    else if (storage_class & STCfield)
    {
        TOWORD(p,LF_MEMBER);
        typidx = cv_typidx(type->toCtype());
        attribute = PROTtoATTR(prot());
        assert((attribute & ~3) == 0);
        TOWORD(p + 2,typidx);
        TOWORD(p + 4,attribute);
        cv4_storenumeric(p + 6, offset);
        nwritten = 6 + cv4_numericbytes( offset);
        nwritten += cv_namestring(p + nwritten, id);
    }
    else if (isStatic())
    {
        TOWORD(p,LF_STMEMBER);
        typidx = cv_typidx(type->toCtype());
        attribute = PROTtoATTR(prot());
        assert((attribute & ~3) == 0);
        TOWORD(p + 2,typidx);
        TOWORD(p + 4,attribute);
        nwritten = 6 + cv_namestring(p + 6, id);
    }
    return nwritten;
}

