/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/_tocsym.d, _tocvdebug.d)
 */

module ddmd.tocvdebug;

version (Windows):

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stddef;
import core.stdc.stdlib;
import core.stdc.time;

import ddmd.root.array;
import ddmd.root.rmem;

import ddmd.aggregate;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dmodule;
import ddmd.dsymbol;
import ddmd.dstruct;
import ddmd.dtemplate;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.mtype;
import ddmd.target;
import ddmd.visitor;

import ddmd.backend.cc;
import ddmd.backend.cdef;
import ddmd.backend.cgcv;
import ddmd.backend.code;
import ddmd.backend.cv4;
import ddmd.backend.dt;
import ddmd.backend.global;
import ddmd.backend.obj;
import ddmd.backend.oper;
import ddmd.backend.ty;
import ddmd.backend.type;

extern (C++):


type *Type_toCtype(Type t);
int cvMember(Dsymbol s, ubyte *p);

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

uint PROTtoATTR(PROTKIND prot)
{
    uint attribute;

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

uint cv4_memfunctypidx(FuncDeclaration fd)
{
    //printf("cv4_memfunctypidx(fd = '%s')\n", fd.toChars());

    type *t = Type_toCtype(fd.type);
    AggregateDeclaration ad = fd.isMember2();
    if (ad)
    {
        // It's a member function, which gets a special type record

        idx_t thisidx;
        if (fd.isStatic())
            thisidx = dttab4[TYvoid];
        else
        {
            assert(ad.handleType());
            thisidx = cv4_typidx(Type_toCtype(ad.handleType()));
        }

        uint nparam;
        idx_t paramidx = cv4_arglist(t,&nparam);

        ubyte call = cv4_callconv(t);

        debtyp_t *d;
        switch (config.fulltypes)
        {
            case CV4:
            {
                d = debtyp_alloc(18);
                ubyte *p = &d.data[0];
                TOWORD(p,LF_MFUNCTION);
                TOWORD(p + 2,cv4_typidx(t.Tnext));
                TOWORD(p + 4,cv4_typidx(Type_toCtype(ad.type)));
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
                ubyte *p = &d.data[0];
                TOWORD(p,0x1009);
                TOLONG(p + 2,cv4_typidx(t.Tnext));
                TOLONG(p + 6,cv4_typidx(Type_toCtype(ad.type)));
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

enum CV4_NAMELENMAX = 0x3b9f;                   // found by trial and error

uint cv4_Denum(EnumDeclaration e)
{
    //dbg_printf("cv4_Denum(%s)\n", e.toChars());
    uint property = 0;
    if (!e.members || !e.memtype || !e.memtype.isintegral())
        property |= 0x80;               // enum is forward referenced or non-integer

    // Compute the number of fields, and the length of the fieldlist record
    uint nfields = 0;
    uint fnamelen = 2;
    if (!property)
    {
        for (size_t i = 0; i < e.members.dim; i++)
        {   EnumMember sf = (*e.members)[i].isEnumMember();
            if (sf)
            {
                dinteger_t value = sf.value().toInteger();
                uint fnamelen1 = fnamelen;

                // store only member's simple name
                fnamelen += 4 + cv4_numericbytes(cast(uint)value) + cv_stringbytes(sf.toChars());

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

    auto id = e.toPrettyChars();
    uint len;
    debtyp_t *d;
    uint memtype = e.memtype ? cv4_typidx(Type_toCtype(e.memtype)) : 0;
    switch (config.fulltypes)
    {
        case CV8:
            len = 14;
            d = debtyp_alloc(len + cv_stringbytes(id));
            TOWORD(d.data.ptr,LF_ENUM_V3);
            TOLONG(d.data.ptr + 6,memtype);
            TOWORD(d.data.ptr + 4,property);
            len += cv_namestring(d.data.ptr + len,id);
            break;

        case CV4:
            len = 10;
            d = debtyp_alloc(len + cv_stringbytes(id));
            TOWORD(d.data.ptr,LF_ENUM);
            TOWORD(d.data.ptr + 4,memtype);
            TOWORD(d.data.ptr + 8,property);
            len += cv_namestring(d.data.ptr + len,id);
            break;

        default:
            assert(0);
    }
    const length_save = d.length;
    d.length = 0;                      // so cv_debtyp() will allocate new
    idx_t typidx = cv_debtyp(d);
    d.length = length_save;            // restore length

    TOWORD(d.data.ptr + 2,nfields);

    uint fieldlist = 0;
    if (!property)                      // if forward reference, then fieldlist is 0
    {
        // Generate fieldlist type record
        debtyp_t *dt = debtyp_alloc(fnamelen);
        TOWORD(dt.data.ptr,(config.fulltypes == CV8) ? LF_FIELDLIST_V2 : LF_FIELDLIST);

        // And fill it in
        uint j = 2;
        uint fieldi = 0;
        for (size_t i = 0; i < e.members.dim; i++)
        {   EnumMember sf = (*e.members)[i].isEnumMember();

            if (sf)
            {
                fieldi++;
                if (fieldi > nfields)
                    break;                  // chop off the rest

                dinteger_t value = sf.value().toInteger();
                TOWORD(dt.data.ptr + j,(config.fulltypes == CV8) ? LF_ENUMERATE_V3 : LF_ENUMERATE);
                uint attribute = 0;
                TOWORD(dt.data.ptr + j + 2,attribute);
                cv4_storenumeric(dt.data.ptr + j + 4,cast(uint)value);
                j += 4 + cv4_numericbytes(cast(uint)value);
                // store only member's simple name
                j += cv_namestring(dt.data.ptr + j, sf.toChars());

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
        TOLONG(d.data.ptr + 10,fieldlist);
    else
        TOWORD(d.data.ptr + 6,fieldlist);

//    cv4_outsym(s);
    return typidx;
}

/*************************************
 * Align and pad.
 * Returns:
 *      aligned count
 */
uint cv_align(ubyte *p, uint n)
{
    if (config.fulltypes == CV8)
    {
        if (p)
        {
            uint npad = -n & 3;
            while (npad)
            {
                *p = cast(ubyte)(0xF0 + npad);
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

void toDebug(EnumDeclaration ed)
{
    //printf("EnumDeclaration::toDebug('%s')\n", ed.toChars());

    assert(config.fulltypes >= CV4);

    // If it is a member, it is handled by cvMember()
    if (!ed.isMember())
    {
        auto id = ed.toPrettyChars(true);
        idx_t typidx = cv4_Denum(ed);
        if (config.fulltypes == CV8)
            cv8_udt(id, typidx);
        else
        {
            uint len = strlen(id);
            ubyte *debsym = cast(ubyte *) alloca(39 + IDOHD + len);

            // Output a 'user-defined type' for the tag name
            TOWORD(debsym + 2,S_UDT);
            TOIDX(debsym + 4,typidx);
            uint length = 2 + 2 + cgcv.sz_idx;
            length += cv_namestring(debsym + length,id);
            TOWORD(debsym,length - 2);

            assert(length <= 40 + len);
            objmod.write_bytes(SegData[DEBSYM],length,cast(void*)debsym);
        }
    }
}

// Closure variables for Lambda cv_mem_count
struct CvMemberCount
{
    uint nfields;
    uint fnamelen;
}

// Lambda function
int cv_mem_count(Dsymbol s, void *param)
{   CvMemberCount *pmc = cast(CvMemberCount *)param;

    int nwritten = cvMember(s, null);
    if (nwritten)
    {
        pmc.fnamelen += nwritten;
        pmc.nfields++;
    }
    return 0;
}

// Lambda function
int cv_mem_p(Dsymbol s, void *param)
{
    ubyte **pp = cast(ubyte **)param;
    *pp += cvMember(s, *pp);
    return 0;
}


void toDebug(StructDeclaration sd)
{
    idx_t typidx = 0;

    //printf("StructDeclaration::toDebug('%s')\n", sd.toChars());

    assert(config.fulltypes >= CV4);
    if (sd.isAnonymous())
        return /*0*/;

    if (typidx)                 // if reference already generated
        return /*typidx*/;      // use already existing reference

    targ_size_t size;
    uint property = 0;
    if (!sd.members)
    {
        size = 0;
        property |= 0x80;               // forward reference
    }
    else
        size = sd.structsize;

    if (sd.parent.isAggregateDeclaration()) // if class is nested
        property |= 8;
//    if (st.Sctor || st.Sdtor)
//      property |= 2;          // class has ctors and/or dtors
//    if (st.Sopoverload)
//      property |= 4;          // class has overloaded operators
//    if (st.Scastoverload)
//      property |= 0x40;               // class has casting methods
//    if (st.Sopeq && !(st.Sopeq.Sfunc.Fflags & Fnodebug))
//      property |= 0x20;               // class has overloaded assignment

    const char *id = sd.toPrettyChars(true);

    uint leaf = sd.isUnionDeclaration() ? LF_UNION : LF_STRUCTURE;
    if (config.fulltypes == CV8)
        leaf = leaf == LF_UNION ? LF_UNION_V3 : LF_STRUCTURE_V3;

    uint numidx;
    final switch (leaf)
    {
        case LF_UNION:        numidx = 8;       break;
        case LF_UNION_V3:     numidx = 10;      break;
        case LF_STRUCTURE:    numidx = 12;      break;
        case LF_STRUCTURE_V3: numidx = 18;      break;
    }

    uint len = numidx + cv4_numericbytes(cast(uint)size);
    debtyp_t *d = debtyp_alloc(len + cv_stringbytes(id));
    cv4_storenumeric(d.data.ptr + numidx, cast(uint)size);
    len += cv_namestring(d.data.ptr + len,id);

    if (leaf == LF_STRUCTURE)
    {
        TOWORD(d.data.ptr + 8,0);          // dList
        TOWORD(d.data.ptr + 10,0);         // vshape is 0 (no virtual functions)
    }
    else if (leaf == LF_STRUCTURE_V3)
    {
        TOLONG(d.data.ptr + 10,0);         // dList
        TOLONG(d.data.ptr + 14,0);         // vshape is 0 (no virtual functions)
    }
    TOWORD(d.data.ptr,leaf);

    // Assign a number to prevent infinite recursion if a struct member
    // references the same struct.
    const length_save = d.length;
    d.length = 0;                      // so cv_debtyp() will allocate new
    typidx = cv_debtyp(d);
    d.length = length_save;            // restore length

    if (!sd.members)                       // if reference only
    {
        if (config.fulltypes == CV8)
        {
            TOWORD(d.data.ptr + 2,0);          // count: number of fields is 0
            TOLONG(d.data.ptr + 6,0);          // field list is 0
            TOWORD(d.data.ptr + 4,property);
        }
        else
        {
            TOWORD(d.data.ptr + 2,0);          // count: number of fields is 0
            TOWORD(d.data.ptr + 4,0);          // field list is 0
            TOWORD(d.data.ptr + 6,property);
        }
        return /*typidx*/;
    }

    // Compute the number of fields (nfields), and the length of the fieldlist record (fnamelen)
    CvMemberCount mc;
    mc.nfields = 0;
    mc.fnamelen = 2;
    for (size_t i = 0; i < sd.members.dim; i++)
    {
        Dsymbol s = (*sd.members)[i];
        s.apply(&cv_mem_count, &mc);
    }
    if (config.fulltypes != CV8 && mc.fnamelen > CV4_NAMELENMAX)
    {   // Too long, fail gracefully
        mc.nfields = 0;
        mc.fnamelen = 2;
    }
    uint nfields = mc.nfields;
    uint fnamelen = mc.fnamelen;

    int count = nfields;                  // COUNT field in LF_CLASS

    // Generate fieldlist type record
    debtyp_t *dt = debtyp_alloc(fnamelen);
    ubyte *p = dt.data.ptr;

    // And fill it in
    TOWORD(p,config.fulltypes == CV8 ? LF_FIELDLIST_V2 : LF_FIELDLIST);
    p += 2;
    if (nfields)
    {
        for (size_t i = 0; i < sd.members.dim; i++)
        {
            Dsymbol s = (*sd.members)[i];
            s.apply(&cv_mem_p, &p);
        }
    }

    //dbg_printf("fnamelen = %d, p-dt.data.ptr = %d\n",fnamelen,p-dt.data.ptr);
    assert(p - dt.data.ptr == fnamelen);
    idx_t fieldlist = cv_debtyp(dt);

    TOWORD(d.data.ptr + 2,count);
    if (config.fulltypes == CV8)
    {
        TOWORD(d.data.ptr + 4,property);
        TOLONG(d.data.ptr + 6,fieldlist);
    }
    else
    {
        TOWORD(d.data.ptr + 4,fieldlist);
        TOWORD(d.data.ptr + 6,property);
    }

//    cv4_outsym(s);

    if (config.fulltypes == CV8)
        cv8_udt(id, typidx);
    else
    {
        size_t idlen = strlen(id);
        ubyte *debsym = cast(ubyte *) alloca(39 + IDOHD + idlen);

        // Output a 'user-defined type' for the tag name
        TOWORD(debsym + 2,S_UDT);
        TOIDX(debsym + 4,typidx);
        uint length = 2 + 2 + cgcv.sz_idx;
        length += cv_namestring(debsym + length,id);
        TOWORD(debsym,length - 2);

        assert(length <= 40 + idlen);
        objmod.write_bytes(SegData[DEBSYM],length,debsym);
    }

//    return typidx;
}


void toDebug(ClassDeclaration cd)
{
    idx_t typidx = 0;

    //printf("ClassDeclaration::toDebug('%s')\n", cd.toChars());

    assert(config.fulltypes >= CV4);
    if (cd.isAnonymous())
        return /*0*/;

    if (typidx)                 // if reference already generated
        return /*typidx*/;      // use already existing reference

    targ_size_t size;
    uint property = 0;
    if (!cd.members)
    {
        size = 0;
        property |= 0x80;               // forward reference
    }
    else
        size = cd.structsize;

    if (cd.parent.isAggregateDeclaration()) // if class is nested
        property |= 8;
    if (cd.ctor || cd.dtors.dim)
        property |= 2;          // class has ctors and/or dtors
//    if (st.Sopoverload)
//      property |= 4;          // class has overloaded operators
//    if (st.Scastoverload)
//      property |= 0x40;               // class has casting methods
//    if (st.Sopeq && !(st.Sopeq.Sfunc.Fflags & Fnodebug))
//      property |= 0x20;               // class has overloaded assignment

    auto id = cd.isCPPinterface() ? cd.ident.toChars() : cd.toPrettyChars(true);
    uint leaf = config.fulltypes == CV8 ? LF_CLASS_V3 : LF_CLASS;

    uint numidx = (leaf == LF_CLASS_V3) ? 18 : 12;
    uint len = numidx + cv4_numericbytes(cast(uint)size);
    debtyp_t *d = debtyp_alloc(len + cv_stringbytes(id));
    cv4_storenumeric(d.data.ptr + numidx, cast(uint)size);
    len += cv_namestring(d.data.ptr + len,id);

    idx_t vshapeidx = 0;
    if (1)
    {
        size_t n = cd.vtbl.dim;                   // number of virtual functions
        if (n)
        {   // 4 bits per descriptor
            debtyp_t *vshape = debtyp_alloc(4 + (n + 1) / 2);
            TOWORD(vshape.data.ptr,LF_VTSHAPE);
            TOWORD(vshape.data.ptr + 2,n);

            n = 0;
            ubyte descriptor = 0;
            for (size_t i = 0; i < cd.vtbl.dim; i++)
            {
                FuncDeclaration fd = cast(FuncDeclaration)cd.vtbl[i];
                //if (intsize == 4)
                    descriptor |= 5;
                vshape.data.ptr[4 + n / 2] = descriptor;
                descriptor <<= 4;
                n++;
            }
            vshapeidx = cv_debtyp(vshape);
        }
    }
    if (leaf == LF_CLASS)
    {
        TOWORD(d.data.ptr + 8,0);          // dList
        TOWORD(d.data.ptr + 10,vshapeidx);
    }
    else if (leaf == LF_CLASS_V3)
    {
        TOLONG(d.data.ptr + 10,0);         // dList
        TOLONG(d.data.ptr + 14,vshapeidx);
    }
    TOWORD(d.data.ptr,leaf);

    // Assign a number to prevent infinite recursion if a struct member
    // references the same struct.
    const length_save = d.length;
    d.length = 0;                      // so cv_debtyp() will allocate new
    typidx = cv_debtyp(d);
    d.length = length_save;            // restore length

    if (!cd.members)                       // if reference only
    {
        if (leaf == LF_CLASS_V3)
        {
            TOWORD(d.data.ptr + 2,0);          // count: number of fields is 0
            TOLONG(d.data.ptr + 6,0);          // field list is 0
            TOWORD(d.data.ptr + 4,property);
        }
        else
        {
            TOWORD(d.data.ptr + 2,0);          // count: number of fields is 0
            TOWORD(d.data.ptr + 4,0);          // field list is 0
            TOWORD(d.data.ptr + 6,property);
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
        for (size_t i = 0; i < cd.baseclasses.dim; i++)
        {
            auto bc = (*cd.baseclasses)[i];
            mc.nfields++;
            uint elementlen = 4 + cgcv.sz_idx + cv4_numericbytes(bc.offset);
            elementlen = cv_align(null, elementlen);
            mc.fnamelen += elementlen;
        }
    }

    for (size_t i = 0; i < cd.members.dim; i++)
    {
        Dsymbol s = (*cd.members)[i];
        s.apply(&cv_mem_count, &mc);
    }
    if (config.fulltypes != CV8 && mc.fnamelen > CV4_NAMELENMAX)
    {   // Too long, fail gracefully
        mc.nfields = 0;
        mc.fnamelen = 2;
    }
    uint nfields = mc.nfields;
    uint fnamelen = mc.fnamelen;

    int count = nfields;
    TOWORD(d.data.ptr + 2,count);

    // Generate fieldlist type record
    debtyp_t *dt = debtyp_alloc(fnamelen);
    ubyte *p = dt.data.ptr;

    // And fill it in
    TOWORD(p,config.fulltypes == CV8 ? LF_FIELDLIST_V2 : LF_FIELDLIST);
    p += 2;

    if (nfields)        // if we didn't overflow
    {
        if (addInBaseClasses)
        {
            // Add in base classes
            for (size_t i = 0; i < cd.baseclasses.dim; i++)
            {
                BaseClass *bc = (*cd.baseclasses)[i];
                idx_t typidx2 = cv4_typidx(Type_toCtype(bc.sym.type).Tnext);
                uint attribute = PROTtoATTR(PROTpublic);

                uint elementlen;
                final switch (config.fulltypes)
                {
                    case CV8:
                        TOWORD(p, LF_BCLASS_V2);
                        TOWORD(p + 2,attribute);
                        TOLONG(p + 4,typidx2);
                        elementlen = 8;
                        break;

                    case CV4:
                        TOWORD(p, LF_BCLASS);
                        TOWORD(p + 2,typidx2);
                        TOWORD(p + 4,attribute);
                        elementlen = 6;
                        break;
                }

                cv4_storenumeric(p + elementlen, bc.offset);
                elementlen += cv4_numericbytes(bc.offset);
                elementlen = cv_align(p + elementlen, elementlen);
                p += elementlen;
            }
        }

        for (size_t i = 0; i < cd.members.dim; i++)
        {
            Dsymbol s = (*cd.members)[i];
            s.apply(&cv_mem_p, &p);
        }
    }

    //dbg_printf("fnamelen = %d, p-dt.data.ptr = %d\n",fnamelen,p-dt.data.ptr);
    assert(p - dt.data.ptr == fnamelen);
    idx_t fieldlist = cv_debtyp(dt);

    TOWORD(d.data.ptr + 2,count);
    if (config.fulltypes == CV8)
    {
        TOWORD(d.data.ptr + 4,property);
        TOLONG(d.data.ptr + 6,fieldlist);
    }
    else
    {
        TOWORD(d.data.ptr + 4,fieldlist);
        TOWORD(d.data.ptr + 6,property);
    }

//    cv4_outsym(s);

    if (config.fulltypes == CV8)
        cv8_udt(id, typidx);
    else
    {
        size_t idlen = strlen(id);
        ubyte *debsym = cast(ubyte *) alloca(39 + IDOHD + idlen);

        // Output a 'user-defined type' for the tag name
        TOWORD(debsym + 2,S_UDT);
        TOIDX(debsym + 4,typidx);
        uint length = 2 + 2 + cgcv.sz_idx;
        length += cv_namestring(debsym + length,id);
        TOWORD(debsym,length - 2);

        assert(length <= 40 + idlen);
        objmod.write_bytes(SegData[DEBSYM],length,debsym);
    }

//    return typidx;
}


/* ===================================================================== */

/*****************************************
 * Insert CV info into *p.
 * Returns:
 *      number of bytes written, or that would be written if p==null
 */

int cvMember(Dsymbol s, ubyte *p)
{
    extern (C++) class CVMember : Visitor
    {
        ubyte *p;
        int result;

        this(ubyte *p)
        {
            this.p = p;
            result = 0;
        }

        alias visit = super.visit;

        override void visit(Dsymbol s)
        {
        }

        void cvMemberCommon(Dsymbol s, const(char)* id, idx_t typidx)
        {
            if (!p)
                result = cv_stringbytes(id);

            switch (config.fulltypes)
            {
                case CV8:
                    if (!p)
                    {
                        result += 8;
                        result = cv_align(null, result);
                    }
                    else
                    {
                        TOWORD(p,LF_NESTTYPE_V3);
                        TOWORD(p + 2,0);
                        TOLONG(p + 4,typidx);
                        result = 8 + cv_namestring(p + 8, id);
                        result = cv_align(p + result, result);
                    }
                    break;

                case CV4:
                    if (!p)
                    {
                        result += 4;
                    }
                    else
                    {
                        TOWORD(p,LF_NESTTYPE);
                        TOWORD(p + 2,typidx);
                        result = 4 + cv_namestring(p + 4, id);
                    }
                    break;

                default:
                    assert(0);
            }
            debug
            {
                if (p)
                {
                    int save = result;
                    p = null;
                    cvMemberCommon(s, id, typidx);
                    assert(result == save);
                }
            }
        }

        override void visit(EnumDeclaration ed)
        {
            //printf("EnumDeclaration.cvMember() '%s'\n", d.toChars());

            cvMemberCommon(ed, ed.toChars(), cv4_Denum(ed));
        }

        override void visit(FuncDeclaration fd)
        {
            //printf("FuncDeclaration.cvMember() '%s'\n", fd.toChars());

            if (!fd.type)                  // if not compiled in,
                return;               // skip it

            const id = fd.toChars();

            if (!p)
            {
                result = 2 + 2 + cgcv.sz_idx + cv_stringbytes(id);
                result = cv_align(null, result);
                return;
            }
            else
            {
                int count = 0;
                int mlen = 2;
                {
                    if (fd.introducing)
                        mlen += 4;
                    mlen += cgcv.sz_idx * 2;
                    count++;
                }

                // Allocate and fill it in
                debtyp_t *d = debtyp_alloc(mlen);
                ubyte *q = d.data.ptr;
                TOWORD(q,config.fulltypes == CV8 ? LF_METHODLIST_V2 : LF_METHODLIST);
                q += 2;
        //      for (s = sf; s; s = s.Sfunc.Foversym)
                {
                    uint attribute = PROTtoATTR(fd.prot().kind);

                    /* 0*4 vanilla method
                     * 1*4 virtual method
                     * 2*4 static method
                     * 3*4 friend method
                     * 4*4 introducing virtual method
                     * 5*4 pure virtual method
                     * 6*4 pure introducing virtual method
                     * 7*4 reserved
                     */

                    if (fd.isStatic())
                        attribute |= 2*4;
                    else if (fd.isVirtual())
                    {
                        if (fd.introducing)
                        {
                            if (fd.isAbstract())
                                attribute |= 6*4;
                            else
                                attribute |= 4*4;
                        }
                        else
                        {
                            if (fd.isAbstract())
                                attribute |= 5*4;
                            else
                                attribute |= 1*4;
                        }
                    }
                    else
                        attribute |= 0*4;

                    TOIDX(q,attribute);
                    q += cgcv.sz_idx;
                    TOIDX(q, cv4_memfunctypidx(fd));
                    q += cgcv.sz_idx;
                    if (fd.introducing)
                    {
                        TOLONG(q, fd.vtblIndex * Target.ptrsize);
                        q += 4;
                    }
                }
                assert(q - d.data.ptr == mlen);

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
                            result = 4;
                            TOIDX(p + result, typidx);
                            result += cgcv.sz_idx;
                            result += cv_namestring(p + result, id);
                            break;

                        default:
                            assert(0);
                    }
                }
                result = cv_align(p + result, result);
                debug
                {
                    int save = result;
                    result = 0;
                    p = null;
                    visit(fd);
                    assert(result == save);
                }
            }
        }

        override void visit(VarDeclaration vd)
        {
            //printf("VarDeclaration.cvMember(p = %p) '%s'\n", p, vd.toChars());

            if (vd.type.toBasetype().ty == Ttuple)
                return;

            const id = vd.toChars();

            if (!p)
            {
                if (vd.isField())
                {
                    if (config.fulltypes == CV8)
                        result += 2;
                    result += 6 + cv_stringbytes(id);
                    result += cv4_numericbytes(vd.offset);
                }
                else if (vd.isStatic())
                {
                    if (config.fulltypes == CV8)
                        result += 2;
                    result += 6 + cv_stringbytes(id);
                }
                result = cv_align(null, result);
            }
            else
            {
                idx_t typidx = cv_typidx(Type_toCtype(vd.type));
                uint attribute = PROTtoATTR(vd.prot().kind);
                assert((attribute & ~3) == 0);
                switch (config.fulltypes)
                {
                    case CV8:
                        if (vd.isField())
                        {
                            TOWORD(p,LF_MEMBER_V3);
                            TOWORD(p + 2,attribute);
                            TOLONG(p + 4,typidx);
                            cv4_storenumeric(p + 8, vd.offset);
                            result = 8 + cv4_numericbytes(vd.offset);
                            result += cv_namestring(p + result, id);
                        }
                        else if (vd.isStatic())
                        {
                            TOWORD(p,LF_STMEMBER_V3);
                            TOWORD(p + 2,attribute);
                            TOLONG(p + 4,typidx);
                            result = 8;
                            result += cv_namestring(p + result, id);
                        }
                        break;

                    case CV4:
                        if (vd.isField())
                        {
                            TOWORD(p,LF_MEMBER);
                            TOWORD(p + 2,typidx);
                            TOWORD(p + 4,attribute);
                            cv4_storenumeric(p + 6, vd.offset);
                            result = 6 + cv4_numericbytes(vd.offset);
                            result += cv_namestring(p + result, id);
                        }
                        else if (vd.isStatic())
                        {
                            TOWORD(p,LF_STMEMBER);
                            TOWORD(p + 2,typidx);
                            TOWORD(p + 4,attribute);
                            result = 6;
                            result += cv_namestring(p + result, id);
                        }
                        break;

                     default:
                        assert(0);
                }

                result = cv_align(p + result, result);
                debug
                {
                    int save = result;
                    result = 0;
                    p = null;
                    visit(vd);
                    assert(result == save);
                }
            }
        }
    }

    scope v = new CVMember(p);
    s.accept(v);
    return v.result;
}
