/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     Martin Kinkelin
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/argtypes_sysv_x64.d, _argtypes_sysv_x64.d)
 * Documentation:  https://dlang.org/phobos/dmd_argtypes_sysv_x64.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/argtypes_sysv_x64.d
 */

module dmd.argtypes_sysv_x64;

import dmd.declaration;
import dmd.globals;
import dmd.mtype;
import dmd.visitor;

/****************************************************
 * This breaks a type down into 'simpler' types that can be passed to a function
 * in registers, and returned in registers.
 * This is the implementation for the x86_64 System V ABI (not used for Win64),
 * based on https://www.uclibc.org/docs/psABI-x86_64.pdf.
 * Params:
 *      t = type to break down
 * Returns:
 *      tuple of types, each element can be passed in a register.
 *      A tuple of zero length means the type cannot be passed/returned in registers.
 *      null indicates a `void`.
 */
extern (C++) TypeTuple toArgTypes_sysv_x64(Type t)
{
    if (t == Type.terror)
        return new TypeTuple(t);

    const size = cast(size_t) t.size();
    if (size == 0)
        return null;
    if (size > 32)
        return new TypeTuple();

    const classification = classify(t, size);
    const classes = classification.slice();
    const c0 = classes[0];

    if (c0 == Class.Memory)
         return new TypeTuple();
    if (c0 == Class.X87)
        return new TypeTuple(Type.tfloat80);
    if (c0 == Class.ComplexX87)
        return new TypeTuple(Type.tfloat80, Type.tfloat80);

    if (classes.length > 2 ||
        (classes.length == 2 && classes[1] == Class.SSEUp))
    {
        assert(c0 == Class.SSE);
        foreach (c; classes[1 .. $])
            assert(c == Class.SSEUp);

        assert(size % 8 == 0);
        return new TypeTuple(new TypeVector(Type.tfloat64.sarrayOf(classes.length)));
    }

    assert(classes.length >= 1 && classes.length <= 2);
    Type[2] argtypes;
    foreach (i, c; classes)
    {
        // the last eightbyte may be filled partially only
        auto sizeInEightbyte = (i < classes.length - 1) ? 8 : size % 8;
        if (sizeInEightbyte == 0)
            sizeInEightbyte = 8;

        if (c == Class.Integer)
        {
            argtypes[i] =
                sizeInEightbyte > 4 ? Type.tint64 :
                sizeInEightbyte > 2 ? Type.tint32 :
                sizeInEightbyte > 1 ? Type.tint16 :
                                      Type.tint8;
        }
        else if (c == Class.SSE)
        {
            argtypes[i] =
                sizeInEightbyte > 4 ? Type.tfloat64 :
                                      Type.tfloat32;
        }
        else
            assert(0, "Unexpected class");
    }

    return classes.length == 1
        ? new TypeTuple(argtypes[0])
        : new TypeTuple(argtypes[0], argtypes[1]);
}


private:

// classification per eightbyte (64-bit chunk)
enum Class : ubyte
{
    Integer,
    SSE,
    SSEUp,
    X87,
    X87Up,
    ComplexX87,
    NoClass,
    Memory
}

Class merge(Class a, Class b)
{
    if (a == b)
        return a;
    if (a == Class.NoClass)
        return b;
    if (b == Class.NoClass)
        return a;
    if (a == Class.Memory || b == Class.Memory)
        return Class.Memory;
    if (a == Class.Integer || b == Class.Integer)
        return Class.Integer;
    if (a == Class.X87 || b == Class.X87 ||
        a == Class.X87Up || b == Class.X87Up ||
        a == Class.ComplexX87 || b == Class.ComplexX87)
        return Class.Memory;
    return Class.SSE;
}

struct Classification
{
    Class[4] classes;
    int numEightbytes;

    const(Class[]) slice() const { return classes[0 .. numEightbytes]; }
}

Classification classify(Type t, size_t size)
{
    scope v = new ToClassesVisitor(size);
    t.accept(v);
    return Classification(v.result, v.numEightbytes);
}

extern (C++) final class ToClassesVisitor : Visitor
{
    const size_t size;
    int numEightbytes;
    Class[4] result = Class.NoClass;

    this(size_t size)
    {
        assert(size > 0);
        this.size = size;
        this.numEightbytes = cast(int) ((size + 7) / 8);
    }

    void memory()
    {
        result[0 .. numEightbytes] = Class.Memory;
    }

    void one(Class a)
    {
        result[0] = a;
    }

    void two(Class a, Class b)
    {
        result[0] = a;
        result[1] = b;
    }

    alias visit = Visitor.visit;

    override void visit(Type)
    {
        assert(0, "Unexpected type");
    }

    override void visit(TypeEnum t)
    {
        t.toBasetype().accept(this);
    }

    override void visit(TypeBasic t)
    {
        switch (t.ty)
        {
        case Tvoid:
        case Tbool:
        case Tint8:
        case Tuns8:
        case Tint16:
        case Tuns16:
        case Tint32:
        case Tuns32:
        case Tint64:
        case Tuns64:
        case Tchar:
        case Twchar:
        case Tdchar:
            return one(Class.Integer);

        case Tint128:
        case Tuns128:
            return two(Class.Integer, Class.Integer);

        case Tfloat80:
        case Timaginary80:
            return two(Class.X87, Class.X87Up);

        case Tfloat32:
        case Tfloat64:
        case Timaginary32:
        case Timaginary64:
        case Tcomplex32: // struct { float a, b; }
            return one(Class.SSE);

        case Tcomplex64: // struct { double a, b; }
            return two(Class.SSE, Class.SSE);

        case Tcomplex80: // struct { real a, b; }
            result[0 .. 4] = Class.ComplexX87;
            return;

        default:
            assert(0, "Unexpected basic type");
        }
    }

    override void visit(TypeVector t)
    {
        result[0] = Class.SSE;
        result[1 .. numEightbytes] = Class.SSEUp;
    }

    override void visit(TypeAArray)
    {
        return one(Class.Integer);
    }

    override void visit(TypePointer)
    {
        return one(Class.Integer);
    }

    override void visit(TypeNull)
    {
        return one(Class.Integer);
    }

    override void visit(TypeClass)
    {
        return one(Class.Integer);
    }

    override void visit(TypeDArray)
    {
        if (!global.params.isLP64)
            return one(Class.Integer);
        return two(Class.Integer, Class.Integer);
    }

    override void visit(TypeDelegate)
    {
        if (!global.params.isLP64)
            return one(Class.Integer);
        return two(Class.Integer, Class.Integer);
    }

    override void visit(TypeSArray t)
    {
        // treat as struct with N fields

        Type baseElemType = t.next.toBasetype();
        if (baseElemType.ty == Tstruct && !(cast(TypeStruct) baseElemType).sym.isPOD())
            return memory();

        classifyStaticArrayElements(0, t);
        finalizeAggregate();
    }

    override void visit(TypeStruct t)
    {
        if (!t.sym.isPOD())
            return memory();

        classifyStructFields(0, t);
        finalizeAggregate();
    }

    void classifyStructFields(uint baseOffset, TypeStruct t)
    {
        extern(D) Type getNthField(size_t n, out uint offset, out uint typeAlignment)
        {
            auto field = t.sym.fields[n];
            offset = field.offset;
            typeAlignment = field.type.alignsize();
            return field.type;
        }

        classifyFields(baseOffset, t.sym.fields.dim, &getNthField);
    }

    void classifyStaticArrayElements(uint baseOffset, TypeSArray t)
    {
        Type elemType = t.next;
        const elemSize = elemType.size();
        const elemTypeAlignment = elemType.alignsize();

        extern(D) Type getNthElement(size_t n, out uint offset, out uint typeAlignment)
        {
            offset = cast(uint)(n * elemSize);
            typeAlignment = elemTypeAlignment;
            return elemType;
        }

        classifyFields(baseOffset, cast(size_t) t.dim.toInteger(), &getNthElement);
    }

    extern(D) void classifyFields(uint baseOffset, size_t nfields, Type delegate(size_t, out uint, out uint) getFieldInfo)
    {
        if (nfields == 0)
            return memory();

        // classify each field (recursively for aggregates) and merge all classes per eightbyte
        foreach (n; 0 .. nfields)
        {
            uint foffset_relative;
            uint ftypeAlignment;
            Type ftype = getFieldInfo(n, foffset_relative, ftypeAlignment);
            const fsize = cast(size_t) ftype.size();

            const foffset = baseOffset + foffset_relative;
            if (foffset & (ftypeAlignment - 1)) // not aligned
                return memory();

            if (ftype.ty == Tstruct)
                classifyStructFields(foffset, cast(TypeStruct) ftype);
            else if (ftype.ty == Tsarray)
                classifyStaticArrayElements(foffset, cast(TypeSArray) ftype);
            else
            {
                const fEightbyteStart = foffset / 8;
                const fEightbyteEnd = (foffset + fsize + 7) / 8;
                if (ftype.ty == Tcomplex32) // may lie in 2 eightbytes
                {
                    assert(foffset % 4 == 0);
                    foreach (ref existingClass; result[fEightbyteStart .. fEightbyteEnd])
                        existingClass = merge(existingClass, Class.SSE);
                }
                else
                {
                    assert(foffset % 8 == 0 ||
                        fEightbyteEnd - fEightbyteStart <= 1,
                        "Field not aligned at eightbyte boundary but contributing to multiple eightbytes?"
                    );
                    foreach (i, fclass; classify(ftype, fsize).slice())
                    {
                        Class* existingClass = &result[fEightbyteStart + i];
                        *existingClass = merge(*existingClass, fclass);
                    }
                }
            }
        }
    }

    void finalizeAggregate()
    {
        foreach (i, ref c; result)
        {
            if (c == Class.Memory ||
                (c == Class.X87Up && !(i > 0 && result[i - 1] == Class.X87)))
                return memory();

            if (c == Class.SSEUp && !(i > 0 &&
                (result[i - 1] == Class.SSE || result[i - 1] == Class.SSEUp)))
                c = Class.SSE;
        }

        if (numEightbytes > 2)
        {
            if (result[0] != Class.SSE)
                return memory();

            foreach (c; result[1 .. numEightbytes])
                if (c != Class.SSEUp)
                    return memory();
        }

        // Undocumented special case for aggregates with the 2nd eightbyte
        // consisting of padding only (`struct S { align(16) int a; }`).
        // clang only passes the first eightbyte in that case, so let's do the
        // same.
        if (numEightbytes == 2 && result[1] == Class.NoClass)
            numEightbytes = 1;
    }
}
