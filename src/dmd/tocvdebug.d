/**
 * Generate debug info in the CV4 debug format.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/tocsym.d, _tocvdebug.d)
 * Documentation:  https://dlang.org/phobos/dmd_tocvdebug.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/tocvdebug.d
 */

module dmd.tocvdebug;

version (Windows)
{

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stddef;
import core.stdc.stdlib;
import core.stdc.time;

import dmd.root.array;
import dmd.root.rmem;

import dmd.aggregate;
import dmd.apply;
import dmd.astenums;
import dmd.dclass;
import dmd.declaration;
import dmd.denum;
import dmd.dmodule;
import dmd.dsymbol;
import dmd.dstruct;
import dmd.dtemplate;
import dmd.func;
import dmd.globals;
import dmd.id;
import dmd.mtype;
import dmd.target;
import dmd.toctype;
import dmd.visitor;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.cv4;
import dmd.backend.dlist;
import dmd.backend.dt;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.type;

extern (C++):

/* The CV4 debug format is defined in:
 *      "CV4 Symbolic Debug Information Specification"
 *      rev 3.1 March 5, 1993
 *      Languages Business Unit
 *      Microsoft
 */

/******************************
 * CV4 pg. 25
 * Convert D visibility attribute to cv attribute.
 */

uint visibilityToCVAttr(Visibility.Kind vis) pure nothrow @safe @nogc
{
    uint attribute;

    final switch (vis)
    {
        case Visibility.Kind.private_:       attribute = 1;  break;
        case Visibility.Kind.package_:       attribute = 2;  break;
        case Visibility.Kind.protected_:     attribute = 2;  break;
        case Visibility.Kind.public_:        attribute = 3;  break;
        case Visibility.Kind.export_:        attribute = 3;  break;

        case Visibility.Kind.undefined:
        case Visibility.Kind.none:
            //printf("vis = %d\n", vis);
            assert(0);
    }
    return attribute;
}

uint cv4_memfunctypidx(FuncDeclaration fd)
{
    //printf("cv4_memfunctypidx(fd = '%s')\n", fd.toChars());

    type *t = Type_toCtype(fd.type);
    if (AggregateDeclaration ad = fd.isMemberLocal())
    {
        // It's a member function, which gets a special type record

        const idx_t thisidx = fd.isStatic()
                    ? dttab4[TYvoid]
                    : (ad.handleType() ? cv4_typidx(Type_toCtype(ad.handleType())) : 0);
        assert(thisidx);

        uint nparam;
        const idx_t paramidx = cv4_arglist(t,&nparam);

        const ubyte call = cv4_callconv(t);

        switch (config.fulltypes)
        {
            case CV4:
            {
                debtyp_t* d = debtyp_alloc(18);
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
                return cv_debtyp(d);
            }
            case CV8:
            {
                debtyp_t* d = debtyp_alloc(26);
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
                return cv_debtyp(d);
            }
            default:
                assert(0);
        }
    }
    return cv4_typidx(t);
}

enum CV4_NAMELENMAX = 0x3b9f;                   // found by trial and error
enum CV8_NAMELENMAX = 0xffff;                   // length record is 16-bit only

uint cv4_Denum(EnumDeclaration e)
{
    //dbg_printf("cv4_Denum(%s)\n", e.toChars());
    const uint property = (!e.members || !e.memtype || !e.memtype.isintegral())
        ? 0x80               // enum is forward referenced or non-integer
        : 0;

    // Compute the number of fields, and the length of the fieldlist record
    CvFieldList mc = CvFieldList(0, 0);
    if (!property)
    {
        for (size_t i = 0; i < e.members.dim; i++)
        {
            if (EnumMember sf = (*e.members)[i].isEnumMember())
            {
                const value = sf.value().toInteger();

                // store only member's simple name
                uint len = 4 + cv4_numericbytes(cast(uint)value) + cv_stringbytes(sf.toChars());

                len = cv_align(null, len);
                mc.count(len);
            }
        }
    }

    const id = e.toPrettyChars();
    uint len;
    debtyp_t *d;
    const uint memtype = e.memtype ? cv4_typidx(Type_toCtype(e.memtype)) : 0;
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
    const idx_t typidx = cv_debtyp(d);
    d.length = length_save;            // restore length

    TOWORD(d.data.ptr + 2, mc.nfields);

    uint fieldlist = 0;
    if (!property)                      // if forward reference, then fieldlist is 0
    {
        // Generate fieldlist type record
        mc.alloc();

        // And fill it in
        for (size_t i = 0; i < e.members.dim; i++)
        {
            if (EnumMember sf = (*e.members)[i].isEnumMember())
            {
                ubyte* p = mc.writePtr();
                dinteger_t value = sf.value().toInteger();
                TOWORD(p, (config.fulltypes == CV8) ? LF_ENUMERATE_V3 : LF_ENUMERATE);
                uint attribute = 0;
                TOWORD(p + 2, attribute);
                cv4_storenumeric(p + 4,cast(uint)value);
                uint j = 4 + cv4_numericbytes(cast(uint)value);
                // store only member's simple name
                j += cv_namestring(p + j, sf.toChars());
                j = cv_align(p + j, j);
                mc.written(j);
                // If enum is not a member of a class, output enum members as constants
    //          if (!isclassmember(s))
    //          {
    //              cv4_outsym(sf);
    //          }
            }
        }
        fieldlist = mc.debtyp();
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

/*************************************
 * write a UDT record to the object file
 * Params:
 *      id = name of user defined type
 *      typidx = type index
 */
void cv_udt(const char* id, uint typidx)
{
    if (config.fulltypes == CV8)
        cv8_udt(id, typidx);
    else
    {
        const len = strlen(id);
        ubyte *debsym = cast(ubyte *) alloca(39 + IDOHD + len);

        // Output a 'user-defined type' for the tag name
        TOWORD(debsym + 2,S_UDT);
        TOIDX(debsym + 4,typidx);
        uint length = 2 + 2 + cgcv.sz_idx;
        length += cv_namestring(debsym + length,id);
        TOWORD(debsym,length - 2);

        assert(length <= 40 + len);
        objmod.write_bytes(SegData[DEBSYM],length,debsym);
    }
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
        const id = ed.toPrettyChars(true);
        const idx_t typidx = cv4_Denum(ed);
        cv_udt(id, typidx);
    }
}

/****************************
 * Helper struct for field list records LF_FIELDLIST/LF_FIELDLIST_V2
 *
 * if the size exceeds the maximum length of a record, the last entry
 * is an LF_INDEX entry with the type index pointing to the next field list record
 *
 * Processing is done in two phases:
 *
 * Phase 1: computing the size of the field list and distributing it over multiple records
 *  - construct CvFieldList with some precalculated field count/length
 *  - for each field, call count(length of field)
 *
 * Phase 2: write the actual data
 *  - call alloc() to allocate debtyp's
 *  - for each field,
 *    - call writePtr() to get a pointer into the current debtyp
 *    - fill memory with field data
 *    - call written(length of field)
 *  - call debtyp() to create type records and return the index of the first one
 */
struct CvFieldList
{
    // one LF_FIELDLIST record
    static struct FLChunk
    {
        uint length;    // accumulated during "count" phase

        debtyp_t *dt;
        uint writepos;  // write position in dt
    }

    uint nfields;
    uint writeIndex;
    Array!FLChunk fieldLists;

    const uint fieldLenMax;
    const uint fieldIndexLen;

    const bool canSplitList;

    this(uint fields, uint len)
    {
        canSplitList = config.fulltypes == CV8; // optlink bails out with LF_INDEX
        fieldIndexLen = canSplitList ? (config.fulltypes == CV8 ? 2 + 2 + 4 : 2 + 2) : 0;
        fieldLenMax = (config.fulltypes == CV8 ? CV8_NAMELENMAX : CV4_NAMELENMAX) - fieldIndexLen;

        assert(len < fieldLenMax);
        nfields = fields;
        fieldLists.push(FLChunk(2 + len));
    }

    void count(uint n)
    {
        if (n)
        {
            nfields++;
            assert(n < fieldLenMax);
            if (fieldLists[$-1].length + n > fieldLenMax)
                fieldLists.push(FLChunk(2 + n));
            else
                fieldLists[$-1].length += n;
        }
    }

    void alloc()
    {
        foreach (i, ref fld; fieldLists)
        {
            fld.dt = debtyp_alloc(fld.length + (i < fieldLists.length - 1 ? fieldIndexLen : 0));
            TOWORD(fld.dt.data.ptr, config.fulltypes == CV8 ? LF_FIELDLIST_V2 : LF_FIELDLIST);
            fld.writepos = 2;
        }
    }

    ubyte* writePtr()
    {
        assert(writeIndex < fieldLists.length);
        auto fld = &fieldLists[writeIndex];
        if (fld.writepos >= fld.length)
        {
            assert(fld.writepos == fld.length);
            if (writeIndex < fieldLists.length - 1) // if false, all further attempts must not actually write any data
            {
                writeIndex++;
                fld++;
            }
        }
        return fld.dt.data.ptr + fld.writepos;
    }

    void written(uint n)
    {
        assert(fieldLists[writeIndex].writepos + n <= fieldLists[writeIndex].length);
        fieldLists[writeIndex].writepos += n;
    }

    idx_t debtyp()
    {
        idx_t typidx;
        auto numCreate = canSplitList ? fieldLists.length : 1;
        for(auto i = numCreate; i > 0; --i)
        {
            auto fld = &fieldLists[i - 1];
            if (typidx)
            {
                ubyte* p = fld.dt.data.ptr + fld.writepos;
                if (config.fulltypes == CV8)
                {
                    TOWORD (p, LF_INDEX_V2);
                    TOWORD (p + 2, 0); // padding
                    TOLONG (p + 4, typidx);
                }
                else
                {
                    TOWORD (p, LF_INDEX);
                    TOWORD (p + 2, typidx);
                }
            }
            typidx = cv_debtyp(fld.dt);
        }
        return typidx;
    }
}

// Lambda function
int cv_mem_count(Dsymbol s, CvFieldList *pmc)
{
    int nwritten = cvMember(s, null);
    pmc.count(nwritten);
    return 0;
}

// Lambda function
int cv_mem_p(Dsymbol s, CvFieldList *pmc)
{
    ubyte *p = pmc.writePtr();
    uint len = cvMember(s, p);
    pmc.written(len);
    return 0;
}


void toDebug(StructDeclaration sd)
{
    idx_t typidx1 = 0;

    //printf("StructDeclaration::toDebug('%s')\n", sd.toChars());

    assert(config.fulltypes >= CV4);
    if (sd.isAnonymous())
        return /*0*/;

    if (typidx1)                 // if reference already generated
        return /*typidx1*/;      // use already existing reference

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

    const len1 = numidx + cv4_numericbytes(cast(uint)size);
    debtyp_t *d = debtyp_alloc(len1 + cv_stringbytes(id));
    cv4_storenumeric(d.data.ptr + numidx, cast(uint)size);
    cv_namestring(d.data.ptr + len1, id);

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
    const idx_t typidx = cv_debtyp(d);
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

    // Compute the number of fields and the length of the fieldlist record
    CvFieldList mc = CvFieldList(0, 0);
    for (size_t i = 0; i < sd.members.dim; i++)
    {
        Dsymbol s = (*sd.members)[i];
        s.apply(&cv_mem_count, &mc);
    }
    const uint nfields = mc.nfields;

    // Generate fieldlist type record
    mc.alloc();
    if (nfields)
    {
        for (size_t i = 0; i < sd.members.dim; i++)
        {
            Dsymbol s = (*sd.members)[i];
            s.apply(&cv_mem_p, &mc);
        }
    }

    //dbg_printf("fnamelen = %d, p-dt.data.ptr = %d\n",fnamelen,p-dt.data.ptr);
    const idx_t fieldlist = mc.debtyp();

    TOWORD(d.data.ptr + 2, nfields);
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

    cv_udt(id, typidx);

//    return typidx;
}


void toDebug(ClassDeclaration cd)
{
    idx_t typidx1 = 0;

    //printf("ClassDeclaration::toDebug('%s')\n", cd.toChars());

    assert(config.fulltypes >= CV4);
    if (cd.isAnonymous())
        return /*0*/;

    if (typidx1)                 // if reference already generated
        return /*typidx1*/;      // use already existing reference

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

    const id = cd.isCPPinterface() ? cd.ident.toChars() : cd.toPrettyChars(true);
    const uint leaf = config.fulltypes == CV8 ? LF_CLASS_V3 : LF_CLASS;

    const uint numidx = (leaf == LF_CLASS_V3) ? 18 : 12;
    const uint len1 = numidx + cv4_numericbytes(cast(uint)size);
    debtyp_t *d = debtyp_alloc(len1 + cv_stringbytes(id));
    cv4_storenumeric(d.data.ptr + numidx, cast(uint)size);
    cv_namestring(d.data.ptr + len1, id);

    idx_t vshapeidx = 0;
    if (1)
    {
        const size_t dim = cd.vtbl.dim;              // number of virtual functions
        if (dim)
        {   // 4 bits per descriptor
            debtyp_t *vshape = debtyp_alloc(cast(uint)(4 + (dim + 1) / 2));
            TOWORD(vshape.data.ptr,LF_VTSHAPE);
            TOWORD(vshape.data.ptr + 2, cast(uint)dim);

            size_t n = 0;
            ubyte descriptor = 0;
            for (size_t i = 0; i < cd.vtbl.dim; i++)
            {
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
    const idx_t typidx = cv_debtyp(d);
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

    // Compute the number of fields and the length of the fieldlist record
    CvFieldList mc = CvFieldList(0, 0);

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
            const bc = (*cd.baseclasses)[i];
            const uint elementlen = 4 + cgcv.sz_idx + cv4_numericbytes(bc.offset);
            mc.count(cv_align(null, elementlen));
        }
    }

    for (size_t i = 0; i < cd.members.dim; i++)
    {
        Dsymbol s = (*cd.members)[i];
        s.apply(&cv_mem_count, &mc);
    }
    const uint nfields = mc.nfields;

    TOWORD(d.data.ptr + 2, nfields);

    // Generate fieldlist type record
    mc.alloc();

    if (nfields)        // if we didn't overflow
    {
        if (addInBaseClasses)
        {
            ubyte* base = mc.writePtr();
            ubyte* p = base;

            // Add in base classes
            for (size_t i = 0; i < cd.baseclasses.dim; i++)
            {
                BaseClass *bc = (*cd.baseclasses)[i];
                const idx_t typidx2 = cv4_typidx(Type_toCtype(bc.sym.type).Tnext);
                const uint attribute = visibilityToCVAttr(Visibility.Kind.public_);

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
                p += cv_align(p + elementlen, elementlen);
            }
            mc.written(cast(uint)(p - base));
        }

        for (size_t i = 0; i < cd.members.dim; i++)
        {
            Dsymbol s = (*cd.members)[i];
            s.apply(&cv_mem_p, &mc);
        }
    }

    const idx_t fieldlist = mc.debtyp();

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

    cv_udt(id, typidx);

//    return typidx;
}

private uint writeField(ubyte* p, const char* id, uint attr, uint typidx, uint offset)
{
    if (config.fulltypes == CV8)
    {
        TOWORD(p,LF_MEMBER_V3);
        TOWORD(p + 2,attr);
        TOLONG(p + 4,typidx);
        cv4_storesignednumeric(p + 8, offset);
        uint len = 8 + cv4_signednumericbytes(offset);
        len += cv_namestring(p + len, id);
        return cv_align(p + len, len);
    }
    else
    {
        TOWORD(p,LF_MEMBER);
        TOWORD(p + 2,typidx);
        TOWORD(p + 4,attr);
        cv4_storesignednumeric(p + 6, offset);
        uint len = 6 + cv4_signednumericbytes(offset);
        return len + cv_namestring(p + len, id);
    }
}

void toDebugClosure(Symbol* closstru)
{
    //printf("toDebugClosure('%s')\n", fd.toChars());

    assert(config.fulltypes >= CV4);

    uint leaf = config.fulltypes == CV8 ? LF_STRUCTURE_V3 : LF_STRUCTURE;
    uint numidx = leaf == LF_STRUCTURE ? 12 : 18;
    uint structsize = cast(uint)(closstru.Sstruct.Sstructsize);
    const char* closname = closstru.Sident.ptr;

    const len1 = numidx + cv4_numericbytes(structsize);
    debtyp_t *d = debtyp_alloc(len1 + cv_stringbytes(closname));
    cv4_storenumeric(d.data.ptr + numidx, structsize);
    cv_namestring(d.data.ptr + len1, closname);

    if (leaf == LF_STRUCTURE)
    {
        TOWORD(d.data.ptr + 8,0);          // dList
        TOWORD(d.data.ptr + 10,0);         // vshape is 0 (no virtual functions)
    }
    else // LF_STRUCTURE_V3
    {
        TOLONG(d.data.ptr + 10,0);         // dList
        TOLONG(d.data.ptr + 14,0);         // vshape is 0 (no virtual functions)
    }
    TOWORD(d.data.ptr,leaf);

    // Assign a number to prevent infinite recursion if a struct member
    // references the same struct.
    const length_save = d.length;
    d.length = 0;                      // so cv_debtyp() will allocate new
    const idx_t typidx = cv_debtyp(d);
    d.length = length_save;            // restore length

    // Compute the number of fields (nfields), and the length of the fieldlist record (flistlen)
    uint nfields = 0;
    uint flistlen = 2;
    for (auto sl = closstru.Sstruct.Sfldlst; sl; sl = list_next(sl))
    {
        Symbol *sf = list_symbol(sl);
        uint thislen = (config.fulltypes == CV8 ? 8 : 6);
        thislen += cv4_signednumericbytes(cast(uint)sf.Smemoff);
        thislen += cv_stringbytes(sf.Sident.ptr);
        thislen = cv_align(null, thislen);

        if (config.fulltypes != CV8 && flistlen + thislen > CV4_NAMELENMAX)
            break; // Too long, fail gracefully

        flistlen += thislen;
        nfields++;
    }

    // Generate fieldlist type record
    debtyp_t *dt = debtyp_alloc(flistlen);
    ubyte *p = dt.data.ptr;

    // And fill it in
    TOWORD(p, config.fulltypes == CV8 ? LF_FIELDLIST_V2 : LF_FIELDLIST);
    uint flistoff = 2;
    for (auto sl = closstru.Sstruct.Sfldlst; sl && flistoff < flistlen; sl = list_next(sl))
    {
        Symbol *sf = list_symbol(sl);
        idx_t vtypidx = cv_typidx(sf.Stype);
        flistoff += writeField(p + flistoff, sf.Sident.ptr, 3 /*public*/, vtypidx, cast(uint)sf.Smemoff);
    }

    //dbg_printf("fnamelen = %d, p-dt.data.ptr = %d\n",fnamelen,p-dt.data.ptr);
    assert(flistoff == flistlen);
    const idx_t fieldlist = cv_debtyp(dt);

    uint property = 0;
    TOWORD(d.data.ptr + 2, nfields);
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

    cv_udt(closname, typidx);
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

        alias visit = Visitor.visit;

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

            if (!fd.type)               // if not compiled in,
                return;                 // skip it
            if (!fd.type.nextOf())      // if not fully analyzed (e.g. auto return type)
                return;                 // skip it

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
                    uint attribute = visibilityToCVAttr(fd.visible().kind);

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
                        TOLONG(q, fd.vtblIndex * target.ptrsize);
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
                uint attribute = visibilityToCVAttr(vd.visible().kind);
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

}
else
{
    import dmd.denum;
    import dmd.dstruct;
    import dmd.dclass;
    import dmd.backend.cc;

    /****************************
     * Stub them out.
     */

    extern (C++) void toDebug(EnumDeclaration ed)
    {
        //printf("EnumDeclaration::toDebug('%s')\n", ed.toChars());
    }

    extern (C++) void toDebug(StructDeclaration sd)
    {
    }

    extern (C++) void toDebug(ClassDeclaration cd)
    {
    }

    extern (C++) void toDebugClosure(Symbol* closstru)
    {
    }
}
