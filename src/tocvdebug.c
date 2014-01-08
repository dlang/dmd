
// Copyright (c) 2004-2012 by Digital Mars
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
#include "target.h"
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

unsigned PROTtoATTR(PROT prot)
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
{
    //printf("cv4_memfunctypidx(fd = '%s')\n", fd->toChars());

    type *t = fd->type->toCtype();
    AggregateDeclaration *ad = fd->isMember2();
    if (ad)
    {
        // It's a member function, which gets a special type record

        idx_t thisidx;
        if (fd->isStatic())
            thisidx = dttab4[TYvoid];
        else
        {
            assert(ad->handle);
            thisidx = cv4_typidx(ad->handle->toCtype());
        }

        unsigned nparam;
        idx_t paramidx = cv4_arglist(t,&nparam);

        unsigned char call = cv4_callconv(t);

        debtyp_t *d;
        switch (config.fulltypes)
        {
            case CV4:
            {
                d = debtyp_alloc(18);
                unsigned char *p = d->data;
                TOWORD(p,LF_MFUNCTION);
                TOWORD(p + 2,cv4_typidx(t->Tnext));
                TOWORD(p + 4,cv4_typidx(ad->type->toCtype()));
                TOWORD(p + 6,thisidx);
                p[8] = call;
                p[9] = 0;                               // reserved
                TOWORD(p + 10,nparam);
                TOWORD(p + 12,paramidx);
                TOLONG(p + 14,0);                       // thisadjust
                break;
            }
            case CV8:
            {
                d = debtyp_alloc(26);
                unsigned char *p = d->data;
                TOWORD(p,0x1009);
                TOLONG(p + 2,cv4_typidx(t->Tnext));
                TOLONG(p + 6,cv4_typidx(ad->type->toCtype()));
                TOLONG(p + 10,thisidx);
                p[14] = call;
                p[15] = 0;                               // reserved
                TOWORD(p + 16,nparam);
                TOLONG(p + 18,paramidx);
                TOLONG(p + 22,0);                       // thisadjust
                break;
            }
            default:
                assert(0);
        }
        return cv_debtyp(d);
    }
    return cv4_typidx(t);
}

#define CV4_NAMELENMAX 0x3b9f                   // found by trial and error

unsigned cv4_Denum(EnumDeclaration *e)
{
    //dbg_printf("cv4_Denum(%s)\n", e->toChars());
    unsigned property = 0;
        if (!e->members || !e->memtype || !e->memtype->isintegral())
        property |= 0x80;               // enum is forward referenced or non-integer

    // Compute the number of fields, and the length of the fieldlist record
    unsigned nfields = 0;
    unsigned fnamelen = 2;
    if (!property)
    {
        for (size_t i = 0; i < e->members->dim; i++)
        {   EnumMember *sf = (*e->members)[i]->isEnumMember();
            if (sf)
            {
                dinteger_t value = sf->value->toInteger();
                unsigned fnamelen1 = fnamelen;

                // store only member's simple name
                fnamelen += 4 + cv4_numericbytes(value) + cv_stringbytes(sf->toChars());

                if (config.fulltypes != CV8)
                {
                    /* Optlink dies on longer ones, so just truncate
                     */
                    if (fnamelen > CV4_NAMELENMAX)
                    {   fnamelen = fnamelen1;       // back up
                        break;                      // and skip the rest
                    }
                }

                nfields++;
            }
        }
    }

    const char *id = e->toPrettyChars();
    unsigned len;
    debtyp_t *d;
    unsigned memtype = e->memtype ? cv4_typidx(e->memtype->toCtype()) : 0;
    switch (config.fulltypes)
    {
        case CV8:
            len = 14;
            d = debtyp_alloc(len + cv_stringbytes(id));
            TOWORD(d->data,LF_ENUM_V3);
            TOLONG(d->data + 6,memtype);
            TOWORD(d->data + 4,property);
            len += cv_namestring(d->data + len,id);
            break;

        case CV4:
            len = 10;
            d = debtyp_alloc(len + cv_stringbytes(id));
            TOWORD(d->data,LF_ENUM);
            TOWORD(d->data + 4,memtype);
            TOWORD(d->data + 8,property);
            len += cv_namestring(d->data + len,id);
            break;

        default:
            assert(0);
    }
    unsigned length_save = d->length;
    d->length = 0;                      // so cv_debtyp() will allocate new
    idx_t typidx = cv_debtyp(d);
    d->length = length_save;            // restore length

    TOWORD(d->data + 2,nfields);

    unsigned fieldlist = 0;
    if (!property)                      // if forward reference, then fieldlist is 0
    {
        // Generate fieldlist type record
        debtyp_t *dt = debtyp_alloc(fnamelen);
        TOWORD(dt->data,(config.fulltypes == CV8) ? LF_FIELDLIST_V2 : LF_FIELDLIST);

        // And fill it in
        unsigned j = 2;
        unsigned fieldi = 0;
        for (size_t i = 0; i < e->members->dim; i++)
        {   EnumMember *sf = (*e->members)[i]->isEnumMember();

            if (sf)
            {
                fieldi++;
                if (fieldi > nfields)
                    break;                  // chop off the rest

                dinteger_t value = sf->value->toInteger();
                TOWORD(dt->data + j,(config.fulltypes == CV8) ? LF_ENUMERATE_V3 : LF_ENUMERATE);
                unsigned attribute = 0;
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
        fieldlist = cv_debtyp(dt);
    }

    if (config.fulltypes == CV8)
        TOLONG(d->data + 10,fieldlist);
    else
        TOWORD(d->data + 6,fieldlist);

//    cv4_outsym(s);
    return typidx;
}

/*************************************
 * Align and pad.
 * Returns:
 *      aligned count
 */
unsigned cv_align(unsigned char *p, unsigned n)
{
    if (config.fulltypes == CV8)
    {
        if (p)
        {
            unsigned npad = -n & 3;
            while (npad)
            {
                *p = 0xF0 + npad;
                ++p;
                --npad;
            }
        }
        n = (n + 3) & ~3;
    }
    return n;
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

        const char *id = toPrettyChars();
        idx_t typidx = cv4_typidx(basetype->toCtype());
        if (config.fulltypes == CV8)
            cv8_udt(id, typidx);
        else
        {
            unsigned len = strlen(id);
            unsigned char *debsym = (unsigned char *) alloca(39 + IDOHD + len);

            // Output a 'user-defined type' for the tag name
            TOWORD(debsym + 2,S_UDT);
            TOIDX(debsym + 4,typidx);
            unsigned length = 2 + 2 + cgcv.sz_idx;
            length += cv_namestring(debsym + length,id);
            TOWORD(debsym,length - 2);

            assert(length <= 40 + len);
            objmod->write_bytes(SegData[DEBSYM],length,debsym);
        }
    }
}


void EnumDeclaration::toDebug()
{
    //printf("EnumDeclaration::toDebug('%s')\n", toChars());

    assert(config.fulltypes >= CV4);

    // If it is a member, it is handled by cvMember()
    if (!isMember())
    {
        const char *id = toPrettyChars();
        idx_t typidx = cv4_Denum(this);
        if (config.fulltypes == CV8)
            cv8_udt(id, typidx);
        else
        {
            unsigned len = strlen(id);
            unsigned char *debsym = (unsigned char *) alloca(39 + IDOHD + len);

            // Output a 'user-defined type' for the tag name
            TOWORD(debsym + 2,S_UDT);
            TOIDX(debsym + 4,typidx);
            unsigned length = 2 + 2 + cgcv.sz_idx;
            length += cv_namestring(debsym + length,id);
            TOWORD(debsym,length - 2);

            assert(length <= 40 + len);
            objmod->write_bytes(SegData[DEBSYM],length,debsym);
        }
    }
}

// Closure variables for Lambda cv_mem_count
struct CvMemberCount
{
    unsigned nfields;
    unsigned fnamelen;
};

// Lambda function
int cv_mem_count(Dsymbol *s, void *param)
{   CvMemberCount *pmc = (CvMemberCount *)param;

    int nwritten = s->cvMember(NULL);
    if (nwritten)
    {
        pmc->fnamelen += nwritten;
        pmc->nfields++;
    }
    return 0;
}

// Lambda function
int cv_mem_p(Dsymbol *s, void *param)
{
    unsigned char **pp = (unsigned char **)param;
    *pp += s->cvMember(*pp);
    return 0;
}


void StructDeclaration::toDebug()
{
    idx_t typidx = 0;

    //printf("StructDeclaration::toDebug('%s')\n", toChars());

    assert(config.fulltypes >= CV4);
    if (isAnonymous())
        return /*0*/;

    if (typidx)                 // if reference already generated
        return /*typidx*/;      // use already existing reference

    targ_size_t size;
    unsigned property = 0;
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

    const char *id = toPrettyChars();

    unsigned leaf = isUnionDeclaration() ? LF_UNION : LF_STRUCTURE;
    if (config.fulltypes == CV8)
        leaf = leaf == LF_UNION ? LF_UNION_V3 : LF_STRUCTURE_V3;

    unsigned numidx;
    switch (leaf)
    {
        case LF_UNION:        numidx = 8;       break;
        case LF_UNION_V3:     numidx = 10;      break;
        case LF_STRUCTURE:    numidx = 12;      break;
        case LF_STRUCTURE_V3: numidx = 18;      break;
    }

    unsigned len = numidx + cv4_numericbytes(size);
    debtyp_t *d = debtyp_alloc(len + cv_stringbytes(id));
    cv4_storenumeric(d->data + numidx,size);
    len += cv_namestring(d->data + len,id);

    if (leaf == LF_STRUCTURE)
    {
        TOWORD(d->data + 8,0);          // dList
        TOWORD(d->data + 10,0);         // vshape is 0 (no virtual functions)
    }
    else if (leaf == LF_STRUCTURE_V3)
    {
        TOLONG(d->data + 10,0);         // dList
        TOLONG(d->data + 14,0);         // vshape is 0 (no virtual functions)
    }
    TOWORD(d->data,leaf);

    // Assign a number to prevent infinite recursion if a struct member
    // references the same struct.
    unsigned length_save = d->length;
    d->length = 0;                      // so cv_debtyp() will allocate new
    typidx = cv_debtyp(d);
    d->length = length_save;            // restore length

    if (!members)                       // if reference only
    {
        if (config.fulltypes == CV8)
        {
            TOWORD(d->data + 2,0);          // count: number of fields is 0
            TOLONG(d->data + 6,0);          // field list is 0
            TOWORD(d->data + 4,property);
        }
        else
        {
            TOWORD(d->data + 2,0);          // count: number of fields is 0
            TOWORD(d->data + 4,0);          // field list is 0
            TOWORD(d->data + 6,property);
        }
        return /*typidx*/;
    }

    // Compute the number of fields (nfields), and the length of the fieldlist record (fnamelen)
    CvMemberCount mc;
    mc.nfields = 0;
    mc.fnamelen = 2;
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        s->apply(&cv_mem_count, &mc);
    }
    if (config.fulltypes != CV8 && mc.fnamelen > CV4_NAMELENMAX)
    {   // Too long, fail gracefully
        mc.nfields = 0;
        mc.fnamelen = 2;
    }
    unsigned nfields = mc.nfields;
    unsigned fnamelen = mc.fnamelen;

    int count = nfields;                  // COUNT field in LF_CLASS

    // Generate fieldlist type record
    debtyp_t *dt = debtyp_alloc(fnamelen);
    unsigned char *p = dt->data;

    // And fill it in
    TOWORD(p,config.fulltypes == CV8 ? LF_FIELDLIST_V2 : LF_FIELDLIST);
    p += 2;
    if (nfields)
    {
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            s->apply(&cv_mem_p, &p);
        }
    }

    //dbg_printf("fnamelen = %d, p-dt->data = %d\n",fnamelen,p-dt->data);
    assert(p - dt->data == fnamelen);
    idx_t fieldlist = cv_debtyp(dt);

    TOWORD(d->data + 2,count);
    if (config.fulltypes == CV8)
    {
        TOWORD(d->data + 4,property);
        TOLONG(d->data + 6,fieldlist);
    }
    else
    {
        TOWORD(d->data + 4,fieldlist);
        TOWORD(d->data + 6,property);
    }

//    cv4_outsym(s);

    if (config.fulltypes == CV8)
        cv8_udt(id, typidx);
    else
    {
        size_t idlen = strlen(id);
        unsigned char *debsym = (unsigned char *) alloca(39 + IDOHD + idlen);

        // Output a 'user-defined type' for the tag name
        TOWORD(debsym + 2,S_UDT);
        TOIDX(debsym + 4,typidx);
        unsigned length = 2 + 2 + cgcv.sz_idx;
        length += cv_namestring(debsym + length,id);
        TOWORD(debsym,length - 2);

        assert(length <= 40 + idlen);
        objmod->write_bytes(SegData[DEBSYM],length,debsym);
    }

//    return typidx;
}


void ClassDeclaration::toDebug()
{
    idx_t typidx = 0;

    //printf("ClassDeclaration::toDebug('%s')\n", toChars());

    assert(config.fulltypes >= CV4);
    if (isAnonymous())
        return /*0*/;

    if (typidx)                 // if reference already generated
        return /*typidx*/;      // use already existing reference

    targ_size_t size;
    unsigned property = 0;
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

    const char *id = isCPPinterface() ? ident->toChars() : toPrettyChars();
    unsigned leaf = config.fulltypes == CV8 ? LF_CLASS_V3 : LF_CLASS;

    unsigned numidx = (leaf == LF_CLASS_V3) ? 18 : 12;
    unsigned len = numidx + cv4_numericbytes(size);
    debtyp_t *d = debtyp_alloc(len + cv_stringbytes(id));
    cv4_storenumeric(d->data + numidx,size);
    len += cv_namestring(d->data + len,id);

    idx_t vshapeidx = 0;
    if (1)
    {
        size_t n = vtbl.dim;                   // number of virtual functions
        if (n)
        {   // 4 bits per descriptor
            debtyp_t *vshape = debtyp_alloc(4 + (n + 1) / 2);
            TOWORD(vshape->data,LF_VTSHAPE);
            TOWORD(vshape->data + 2,n);

            n = 0;
            unsigned char descriptor = 0;
            for (size_t i = 0; i < vtbl.dim; i++)
            {   FuncDeclaration *fd = (FuncDeclaration *)vtbl[i];

                //if (intsize == 4)
                    descriptor |= 5;
                vshape->data[4 + n / 2] = descriptor;
                descriptor <<= 4;
                n++;
            }
            vshapeidx = cv_debtyp(vshape);
        }
    }
    if (leaf == LF_CLASS)
    {
        TOWORD(d->data + 8,0);          // dList
        TOWORD(d->data + 10,vshapeidx);
    }
    else if (leaf == LF_CLASS_V3)
    {
        TOLONG(d->data + 10,0);         // dList
        TOLONG(d->data + 14,vshapeidx);
    }
    TOWORD(d->data,leaf);

    // Assign a number to prevent infinite recursion if a struct member
    // references the same struct.
    unsigned length_save = d->length;
    d->length = 0;                      // so cv_debtyp() will allocate new
    typidx = cv_debtyp(d);
    d->length = length_save;            // restore length

    if (!members)                       // if reference only
    {
        if (leaf == LF_CLASS_V3)
        {
            TOWORD(d->data + 2,0);          // count: number of fields is 0
            TOLONG(d->data + 6,0);          // field list is 0
            TOWORD(d->data + 4,property);
        }
        else
        {
            TOWORD(d->data + 2,0);          // count: number of fields is 0
            TOWORD(d->data + 4,0);          // field list is 0
            TOWORD(d->data + 6,property);
        }
        return /*typidx*/;
    }

    // Compute the number of fields (nfields), and the length of the fieldlist record (fnamelen)
    CvMemberCount mc;
    mc.nfields = 0;
    mc.fnamelen = 2;

    /* Adding in the base classes causes VS 2010 debugger to refuse to display any
     * of the fields. I have not been able to determine why.
     * (Could it be because the base class is "forward referenced"?)
     * It does work with VS 2012.
     */
    bool addInBaseClasses = true;
    if (addInBaseClasses)
    {
        // Add in base classes
        for (size_t i = 0; i < baseclasses->dim; i++)
        {   BaseClass *bc = (*baseclasses)[i];

            mc.nfields++;
            unsigned elementlen = 4 + cgcv.sz_idx + cv4_numericbytes(bc->offset);
            elementlen = cv_align(NULL, elementlen);
            mc.fnamelen += elementlen;
        }
    }

    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        s->apply(&cv_mem_count, &mc);
    }
    if (config.fulltypes != CV8 && mc.fnamelen > CV4_NAMELENMAX)
    {   // Too long, fail gracefully
        mc.nfields = 0;
        mc.fnamelen = 2;
    }
    unsigned nfields = mc.nfields;
    unsigned fnamelen = mc.fnamelen;

    int count = nfields;
    TOWORD(d->data + 2,count);

    // Generate fieldlist type record
    debtyp_t *dt = debtyp_alloc(fnamelen);
    unsigned char *p = dt->data;

    // And fill it in
    TOWORD(p,config.fulltypes == CV8 ? LF_FIELDLIST_V2 : LF_FIELDLIST);
    p += 2;

    if (nfields)        // if we didn't overflow
    {
        if (addInBaseClasses)
        {
            // Add in base classes
            for (size_t i = 0; i < baseclasses->dim; i++)
            {   BaseClass *bc = (*baseclasses)[i];

                idx_t typidx = cv4_typidx(bc->base->type->toCtype()->Tnext);
                unsigned attribute = PROTtoATTR(bc->protection);

                unsigned elementlen;
                switch (config.fulltypes)
                {
                    case CV8:
                        TOWORD(p, LF_BCLASS_V2);
                        TOWORD(p + 2,attribute);
                        TOLONG(p + 4,typidx);
                        elementlen = 8;
                        break;

                    case CV4:
                        TOWORD(p, LF_BCLASS);
                        TOWORD(p + 2,typidx);
                        TOWORD(p + 4,attribute);
                        elementlen = 6;
                        break;
                }

                cv4_storenumeric(p + elementlen, bc->offset);
                elementlen += cv4_numericbytes(bc->offset);
                elementlen = cv_align(p + elementlen, elementlen);
                p += elementlen;
            }
        }

        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            s->apply(&cv_mem_p, &p);
        }
    }

    //dbg_printf("fnamelen = %d, p-dt->data = %d\n",fnamelen,p-dt->data);
    assert(p - dt->data == fnamelen);
    idx_t fieldlist = cv_debtyp(dt);

    TOWORD(d->data + 2,count);
    if (config.fulltypes == CV8)
    {
        TOWORD(d->data + 4,property);
        TOLONG(d->data + 6,fieldlist);
    }
    else
    {
        TOWORD(d->data + 4,fieldlist);
        TOWORD(d->data + 6,property);
    }

//    cv4_outsym(s);

    if (config.fulltypes == CV8)
        cv8_udt(id, typidx);
    else
    {
        size_t idlen = strlen(id);
        unsigned char *debsym = (unsigned char *) alloca(39 + IDOHD + idlen);

        // Output a 'user-defined type' for the tag name
        TOWORD(debsym + 2,S_UDT);
        TOIDX(debsym + 4,typidx);
        unsigned length = 2 + 2 + cgcv.sz_idx;
        length += cv_namestring(debsym + length,id);
        TOWORD(debsym,length - 2);

        assert(length <= 40 + idlen);
        objmod->write_bytes(SegData[DEBSYM],length,debsym);
    }

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

int cvMember(unsigned char *p, char *id, idx_t typidx)
{
    int nwritten = 0;
    if (!p)
        nwritten = cv_stringbytes(id);

    switch (config.fulltypes)
    {
        case CV8:
            if (!p)
            {
                nwritten += 8;
                nwritten = cv_align(NULL, nwritten);
            }
            else
            {
                TOWORD(p,LF_NESTTYPE_V3);
                TOWORD(p + 2,0);
                TOLONG(p + 4,typidx);
                nwritten = 8 + cv_namestring(p + 8, id);
                nwritten = cv_align(p + nwritten, nwritten);
            }
            break;

        case CV4:
            if (!p)
            {
                nwritten += 4;
            }
            else
            {
                TOWORD(p,LF_NESTTYPE);
                TOWORD(p + 2,typidx);
                nwritten = 4 + cv_namestring(p + 4, id);
            }
            break;

        default:
            assert(0);
    }
#ifdef DEBUG
    if (p)
        assert(nwritten == cvMember(NULL, id, typidx));
#endif
    return nwritten;
}

int TypedefDeclaration::cvMember(unsigned char *p)
{
    //printf("TypedefDeclaration::cvMember() '%s'\n", toChars());

    return ::cvMember(p, toChars(), cv4_typidx(basetype->toCtype()));
}


int EnumDeclaration::cvMember(unsigned char *p)
{
    //printf("EnumDeclaration::cvMember() '%s'\n", toChars());

    return ::cvMember(p, toChars(), cv4_Denum(this));
}


int FuncDeclaration::cvMember(unsigned char *p)
{
    int nwritten = 0;

    //printf("FuncDeclaration::cvMember() '%s'\n", toChars());

    if (!type)                  // if not compiled in,
        return 0;               // skip it

    char *id = toChars();

    if (!p)
    {
        nwritten = 2 + 2 + cgcv.sz_idx + cv_stringbytes(id);
        nwritten = cv_align(NULL, nwritten);
        return nwritten;
    }
    else
    {
        int count = 0;
        int mlen = 2;
        {
            if (introducing)
                mlen += 4;
            mlen += cgcv.sz_idx * 2;
            count++;
        }

        // Allocate and fill it in
        debtyp_t *d = debtyp_alloc(mlen);
        unsigned char *q = d->data;
        TOWORD(q,config.fulltypes == CV8 ? LF_METHODLIST_V2 : LF_METHODLIST);
        q += 2;
//      for (s = sf; s; s = s->Sfunc->Foversym)
        {
            unsigned attribute = PROTtoATTR(prot());

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
            {   TOLONG(q, vtblIndex * Target::ptrsize);
                q += 4;
            }
        }
        assert(q - d->data == mlen);

        idx_t typidx = cv_debtyp(d);
        if (typidx)
        {
            switch (config.fulltypes)
            {
                case CV8:
                    TOWORD(p,LF_METHOD_V3);
                    goto Lmethod;
                case CV4:
                    TOWORD(p,LF_METHOD);
                Lmethod:
                    TOWORD(p + 2,count);
                    nwritten = 4;
                    TOIDX(p + nwritten, typidx);
                    nwritten += cgcv.sz_idx;
                    nwritten += cv_namestring(p + nwritten, id);
                    break;

                default:
                    assert(0);
            }
        }
        nwritten = cv_align(p + nwritten, nwritten);
#ifdef DEBUG
        assert(nwritten == cvMember(NULL));
#endif
    }
    return nwritten;
}

int VarDeclaration::cvMember(unsigned char *p)
{
    int nwritten = 0;

    //printf("VarDeclaration::cvMember(p = %p) '%s'\n", p, toChars());

    if (type->toBasetype()->ty == Ttuple)
        return 0;

    char *id = toChars();

    if (!p)
    {
        if (isField())
        {
            if (config.fulltypes == CV8)
                nwritten += 2;
            nwritten += 6 + cv_stringbytes(id);
            nwritten += cv4_numericbytes(offset);
        }
        else if (isStatic())
        {
            if (config.fulltypes == CV8)
                nwritten += 2;
            nwritten += 6 + cv_stringbytes(id);
        }
        nwritten = cv_align(NULL, nwritten);
    }
    else
    {
        idx_t typidx = cv_typidx(type->toCtype());
        unsigned attribute = PROTtoATTR(prot());
        assert((attribute & ~3) == 0);
        switch (config.fulltypes)
        {
            case CV8:
                if (isField())
                {
                    TOWORD(p,LF_MEMBER_V3);
                    TOWORD(p + 2,attribute);
                    TOLONG(p + 4,typidx);
                    cv4_storenumeric(p + 8, offset);
                    nwritten = 8 + cv4_numericbytes( offset);
                    nwritten += cv_namestring(p + nwritten, id);
                }
                else if (isStatic())
                {
                    TOWORD(p,LF_STMEMBER_V3);
                    TOWORD(p + 2,attribute);
                    TOLONG(p + 4,typidx);
                    nwritten = 8;
                    nwritten += cv_namestring(p + nwritten, id);
                }
                break;

            case CV4:
                if (isField())
                {
                    TOWORD(p,LF_MEMBER);
                    TOWORD(p + 2,typidx);
                    TOWORD(p + 4,attribute);
                    cv4_storenumeric(p + 6, offset);
                    nwritten = 6 + cv4_numericbytes( offset);
                    nwritten += cv_namestring(p + nwritten, id);
                }
                else if (isStatic())
                {
                    TOWORD(p,LF_STMEMBER);
                    TOWORD(p + 2,typidx);
                    TOWORD(p + 4,attribute);
                    nwritten = 6;
                    nwritten += cv_namestring(p + nwritten, id);
                }
                break;

             default:
                assert(0);
        }

        nwritten = cv_align(p + nwritten, nwritten);
#ifdef DEBUG
        assert(nwritten == cvMember(NULL));
#endif
    }
    return nwritten;
}

