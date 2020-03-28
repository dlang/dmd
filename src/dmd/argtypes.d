/**
 * Break down a D type into basic (register) types for the Itanium C++ ABI.
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/argtypes.d, _argtypes.d)
 * Documentation:  https://dlang.org/phobos/dmd_argtypes.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/argtypes.d
 */

module dmd.argtypes;

import core.stdc.stdio;
import core.checkedint;

import dmd.declaration;
import dmd.globals;
import dmd.mtype;
import dmd.visitor;

private bool isDMDx64Target()
{
    version (MARS)
        return global.params.is64bit;
    else
        return false;
}

/****************************************************
 * This breaks a type down into 'simpler' types that can be passed to a function
 * in registers, and returned in registers.
 * It's highly platform dependent.
 * Params:
 *      t = type to break down
 * Returns:
 *      tuple of types, each element can be passed in a register.
 *      A tuple of zero length means the type cannot be passed/returned in registers.
 *      null indicates a `void`.
 * References:
 *  For 64 bit code, follows Itanium C++ ABI 1.86 Chapter 3
 *  http://refspecs.linux-foundation.org/cxxabi-1.86.html#calls
 */
extern (C++) TypeTuple toArgTypes(Type t)
{
    extern (C++) final class ToArgTypes : Visitor
    {
        alias visit = Visitor.visit;
    public:
        TypeTuple result;

        /*****
         * Pass type in memory (i.e. on the stack), a tuple of one type, or a tuple of 2 types
         */
        void memory()
        {
            //printf("\ttoArgTypes() %s => [ ]\n", t.toChars());
            result = new TypeTuple(); // pass on the stack
        }

        ///
        void oneType(Type t)
        {
            result = new TypeTuple(t);
        }

        ///
        void twoTypes(Type t1, Type t2)
        {
            result = new TypeTuple(t1, t2);
        }


        override void visit(Type)
        {
            // not valid for a parameter
        }

        override void visit(TypeError)
        {
            result = new TypeTuple(Type.terror);
        }

        override void visit(TypeBasic t)
        {
            Type t1 = null;
            Type t2 = null;
            switch (t.ty)
            {
            case Tvoid:
                return;
            case Tbool:
            case Tint8:
            case Tuns8:
            case Tint16:
            case Tuns16:
            case Tint32:
            case Tuns32:
            case Tfloat32:
            case Tint64:
            case Tuns64:
            case Tint128:
            case Tuns128:
            case Tfloat64:
            case Tfloat80:
                t1 = t;
                break;
            case Timaginary32:
                t1 = Type.tfloat32;
                break;
            case Timaginary64:
                t1 = Type.tfloat64;
                break;
            case Timaginary80:
                t1 = Type.tfloat80;
                break;
            case Tcomplex32:
                if (isDMDx64Target())
                    t1 = Type.tfloat64;
                else
                {
                    t1 = Type.tfloat64;
                    t2 = Type.tfloat64;
                }
                break;
            case Tcomplex64:
                t1 = Type.tfloat64;
                t2 = Type.tfloat64;
                break;
            case Tcomplex80:
                t1 = Type.tfloat80;
                t2 = Type.tfloat80;
                break;
            case Tchar:
                t1 = Type.tuns8;
                break;
            case Twchar:
                t1 = Type.tuns16;
                break;
            case Tdchar:
                t1 = Type.tuns32;
                break;
            default:
                assert(0);
            }
            if (t1)
            {
                if (t2)
                    return twoTypes(t1, t2);
                else
                    return oneType(t1);
            }
            else
                return memory();
        }

        override void visit(TypeVector t)
        {
            return oneType(t);
        }

        override void visit(TypeAArray)
        {
            return oneType(Type.tvoidptr);
        }

        override void visit(TypePointer)
        {
            return oneType(Type.tvoidptr);
        }

        /*************************************
         * Convert a floating point type into the equivalent integral type.
         */
        static Type mergeFloatToInt(Type t)
        {
            switch (t.ty)
            {
            case Tfloat32:
            case Timaginary32:
                t = Type.tint32;
                break;
            case Tfloat64:
            case Timaginary64:
            case Tcomplex32:
                t = Type.tint64;
                break;
            default:
                debug
                {
                    printf("mergeFloatToInt() %s\n", t.toChars());
                }
                assert(0);
            }
            return t;
        }

        /*************************************
         * This merges two types into an 8byte type.
         * Params:
         *      t1 = first type (can be null)
         *      t2 = second type (can be null)
         *      offset2 = offset of t2 from start of t1
         * Returns:
         *      type that encompasses both t1 and t2, null if cannot be done
         */
        static Type argtypemerge(Type t1, Type t2, uint offset2)
        {
            //printf("argtypemerge(%s, %s, %d)\n", t1 ? t1.toChars() : "", t2 ? t2.toChars() : "", offset2);
            if (!t1)
            {
                assert(!t2 || offset2 == 0);
                return t2;
            }
            if (!t2)
                return t1;
            const sz1 = t1.size(Loc.initial);
            const sz2 = t2.size(Loc.initial);
            assert(sz1 != SIZE_INVALID && sz2 != SIZE_INVALID);
            if (t1.ty != t2.ty && (t1.ty == Tfloat80 || t2.ty == Tfloat80))
                return null;
            // [float,float] => [cfloat]
            if (t1.ty == Tfloat32 && t2.ty == Tfloat32 && offset2 == 4)
                return Type.tfloat64;
            // Merging floating and non-floating types produces the non-floating type
            if (t1.isfloating())
            {
                if (!t2.isfloating())
                    t1 = mergeFloatToInt(t1);
            }
            else if (t2.isfloating())
                t2 = mergeFloatToInt(t2);
            Type t;
            // Pick type with larger size
            if (sz1 < sz2)
                t = t2;
            else
                t = t1;
            // If t2 does not lie within t1, need to increase the size of t to enclose both
            bool overflow;
            const offset3 = addu(offset2, sz2, overflow);
            assert(!overflow);
            if (offset2 && sz1 < offset3)
            {
                switch (offset3)
                {
                case 2:
                    t = Type.tint16;
                    break;
                case 3:
                case 4:
                    t = Type.tint32;
                    break;
                default:
                    t = Type.tint64;
                    break;
                }
            }
            return t;
        }

        override void visit(TypeDArray)
        {
            /* Should be done as if it were:
             * struct S { size_t length; void* ptr; }
             */
            if (isDMDx64Target() && !global.params.isLP64)
            {
                // For AMD64 ILP32 ABI, D arrays fit into a single integer register.
                const offset = cast(uint)Type.tsize_t.size(Loc.initial);
                Type t = argtypemerge(Type.tsize_t, Type.tvoidptr, offset);
                if (t)
                {
                    return oneType(t);
                }
            }
            return twoTypes(Type.tsize_t, Type.tvoidptr);
        }

        override void visit(TypeDelegate)
        {
            /* Should be done as if it were:
             * struct S { void* funcptr; void* ptr; }
             */
            if (isDMDx64Target() && !global.params.isLP64)
            {
                // For AMD64 ILP32 ABI, delegates fit into a single integer register.
                const offset = cast(uint)Type.tsize_t.size(Loc.initial);
                Type t = argtypemerge(Type.tvoidptr, Type.tvoidptr, offset);
                if (t)
                {
                    return oneType(t);
                }
            }
            return twoTypes(Type.tvoidptr, Type.tvoidptr);
        }

        override void visit(TypeSArray t)
        {
            const sz = t.size(Loc.initial);
            if (sz > 16)
                return memory();

            const dim = t.dim.toInteger();
            Type tn = t.next;
            const tnsize = tn.size();
            const tnalignsize = tn.alignsize();

            /*****
             * Get the nth element of this array.
             * Params:
             *   n = element number, from 0..dim
             *   offset = set to offset of the element from the start of the array
             *   alignsize = set to the aligned size of the element
             * Returns:
             *   type of the element
             */
            extern (D) Type getNthElement(size_t n, out uint offset, out uint alignsize)
            {
                offset = cast(uint)(n * tnsize);
                alignsize = tnalignsize;
                return tn;
            }

            aggregate(sz, cast(size_t)dim, &getNthElement);
        }

        override void visit(TypeStruct t)
        {
            //printf("TypeStruct.toArgTypes() %s\n", t.toChars());

            if (!t.sym.isPOD())
                return memory();

            /*****
             * Get the nth field of this struct.
             * Params:
             *   n = field number, from 0..nfields
             *   offset = set to offset of the field from the start of the type
             *   alignsize = set to the aligned size of the field
             * Returns:
             *   type of the field
             */
            extern (D) Type getNthField(size_t n, out uint offset, out uint alignsize)
            {
                auto field = t.sym.fields[n];
                offset = field.offset;
                alignsize = field.type.alignsize();
                return field.type;
            }

            aggregate(t.size(Loc.initial), t.sym.fields.dim, &getNthField);
        }

        /*******************
         * Handle aggregates (struct, union, and static array) and set `result`
         * Params:
         *      sz = total size of aggregate
         *      nfields = number of fields in the aggregate (dimension for static arrays)
         *      getFieldInfo = get information about the nth field in the aggregate
         */
        extern (D) void aggregate(d_uns64 sz, size_t nfields, Type delegate(size_t, out uint, out uint) getFieldInfo)
        {
            if (nfields == 0)
                return memory();

            if (isDMDx64Target())
            {
                if (sz == 0 || sz > 16)
                    return memory();

                Type t1 = null;
                Type t2 = null;

                foreach (n; 0 .. nfields)
                {
                    uint foffset;
                    uint falignsize;
                    Type ftype = getFieldInfo(n, foffset, falignsize);

                    //printf("  [%u] ftype = %s\n", n, ftype.toChars());
                    TypeTuple tup = toArgTypes(ftype);
                    if (!tup)
                        return memory();
                    const dim = tup.arguments.dim;
                    Type ft1 = null;
                    Type ft2 = null;
                    switch (dim)
                    {
                    case 2:
                        ft1 = (*tup.arguments)[0].type;
                        ft2 = (*tup.arguments)[1].type;
                        break;
                    case 1:
                        if (foffset < 8)
                            ft1 = (*tup.arguments)[0].type;
                        else
                            ft2 = (*tup.arguments)[0].type;
                        break;
                    default:
                        return memory();
                    }
                    if (foffset & 7)
                    {
                        // Misaligned fields goto Lmemory
                        if (foffset & (falignsize - 1))
                            return memory();

                        // Fields that overlap the 8byte boundary goto memory
                        const fieldsz = ftype.size(Loc.initial);
                        bool overflow;
                        const nextOffset = addu(foffset, fieldsz, overflow);
                        assert(!overflow);
                        if (foffset < 8 && nextOffset > 8)
                            return memory();
                    }
                    // First field in 8byte must be at start of 8byte
                    assert(t1 || foffset == 0);
                    //printf("ft1 = %s\n", ft1 ? ft1.toChars() : "null");
                    //printf("ft2 = %s\n", ft2 ? ft2.toChars() : "null");
                    if (ft1)
                    {
                        t1 = argtypemerge(t1, ft1, foffset);
                        if (!t1)
                            return memory();
                    }
                    if (ft2)
                    {
                        const off2 = ft1 ? 8 : foffset;
                        if (!t2 && off2 != 8)
                            return memory();
                        assert(t2 || off2 == 8);
                        t2 = argtypemerge(t2, ft2, off2 - 8);
                        if (!t2)
                            return memory();
                    }
                }
                if (t2)
                {
                    if (t1.isfloating() && t2.isfloating())
                    {
                        if ((t1.ty == Tfloat32 || t1.ty == Tfloat64) && (t2.ty == Tfloat32 || t2.ty == Tfloat64))
                        {
                        }
                        else
                            return memory();
                    }
                    else if (t1.isfloating() || t2.isfloating())
                        return memory();
                    return twoTypes(t1, t2);
                }

                //printf("\ttoArgTypes() %s => [%s,%s]\n", t.toChars(), t1 ? t1.toChars() : "", t2 ? t2.toChars() : "");
                if (t1)
                    return oneType(t1);
                else
                    return memory();
            }
            else
            {
                Type t1 = null;
                switch (cast(uint)sz)
                {
                case 1:
                    t1 = Type.tint8;
                    break;
                case 2:
                    t1 = Type.tint16;
                    break;
                case 4:
                    t1 = Type.tint32;
                    break;
                case 8:
                    t1 = Type.tint64;
                    break;
                case 16:
                    t1 = null; // could be a TypeVector
                    break;
                default:
                    return memory();
                }
                if (global.params.isFreeBSD && nfields == 1 &&
                    (sz == 4 || sz == 8))
                {
                    /* FreeBSD changed their 32 bit ABI at some point before 10.3 for the following:
                     *  struct { float f;  } => arg1type is float
                     *  struct { double d; } => arg1type is double
                     * Cannot find any documentation on it.
                     */

                    uint foffset;
                    uint falignsize;
                    Type ftype = getFieldInfo(0, foffset, falignsize);
                    TypeTuple tup = toArgTypes(ftype);
                    if (tup && tup.arguments.dim == 1)
                    {
                        Type ft1 = (*tup.arguments)[0].type;
                        if (ft1.ty == Tfloat32 || ft1.ty == Tfloat64)
                            return oneType(ft1);
                    }
                }

                if (t1)
                    return oneType(t1);
                else
                    return memory();
            }
        }

        override void visit(TypeEnum t)
        {
            t.toBasetype().accept(this);
        }

        override void visit(TypeClass)
        {
            result = new TypeTuple(Type.tvoidptr);
        }
    }

    scope ToArgTypes v = new ToArgTypes();
    t.accept(v);
    return v.result;
}
