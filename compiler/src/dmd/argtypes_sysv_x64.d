/**
 * Break down a D type into basic (register) types for the x86_64 System V ABI.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     Martin Kinkelin
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/argtypes_sysv_x64.d, _argtypes_sysv_x64.d)
 * Documentation:  https://dlang.org/phobos/dmd_argtypes_sysv_x64.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/argtypes_sysv_x64.d
 */

module dmd.argtypes_sysv_x64;

import dmd.astenums;
import dmd.declaration;
import dmd.globals;
import dmd.mtype;
import dmd.target;
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
TypeTuple toArgTypes_sysv_x64(Type t)
{
    if (t == Type.terror)
        return new TypeTuple(t);

    const size = cast(size_t) t.size();
    if (size == 0)
        return null;
    if (size > 32)
        return TypeTuple.empty;

    const classification = classify(t, size);
    const classes = classification.slice();
    const N = classes.length;
    const c0 = classes[0];

    switch (c0)
    {
    case Class.memory:
         return TypeTuple.empty;
    case Class.x87:
        return new TypeTuple(Type.tfloat80);
    case Class.complexX87:
        return new TypeTuple(Type.tfloat80, Type.tfloat80);
    default:
        break;
    }

    if (N > 2 || (N == 2 && classes[1] == Class.sseUp))
    {
        assert(c0 == Class.sse);
        foreach (c; classes[1 .. $])
            assert(c == Class.sseUp);

        assert(size % 8 == 0);
        import dmd.typesem : sarrayOf;
        return new TypeTuple(new TypeVector(Type.tfloat64.sarrayOf(N)));
    }

    assert(N >= 1 && N <= 2);
    Type[2] argtypes;
    foreach (i, c; classes)
    {
        // the last eightbyte may be filled partially only
        auto sizeInEightbyte = (i < N - 1) ? 8 : size % 8;
        if (sizeInEightbyte == 0)
            sizeInEightbyte = 8;

        if (c == Class.integer)
        {
            argtypes[i] =
                sizeInEightbyte > 4 ? Type.tint64 :
                sizeInEightbyte > 2 ? Type.tint32 :
                sizeInEightbyte > 1 ? Type.tint16 :
                                      Type.tint8;
        }
        else if (c == Class.sse)
        {
            argtypes[i] =
                sizeInEightbyte > 4 ? Type.tfloat64 :
                                      Type.tfloat32;
        }
        else
            assert(0, "Unexpected class");
    }

    return N == 1
        ? new TypeTuple(argtypes[0])
        : new TypeTuple(argtypes[0], argtypes[1]);
}


private:

// classification per eightbyte (64-bit chunk)
enum Class : ubyte
{
    integer,
    sse,
    sseUp,
    x87,
    x87Up,
    complexX87,
    noClass,
    memory
}

Class merge(Class a, Class b) @safe
{
    bool any(Class value) { return a == value || b == value; }

    if (a == b)
        return a;
    if (a == Class.noClass)
        return b;
    if (b == Class.noClass)
        return a;
    if (any(Class.memory))
        return Class.memory;
    if (any(Class.integer))
        return Class.integer;
    if (any(Class.x87) || any(Class.x87Up) || any(Class.complexX87))
        return Class.memory;
    return Class.sse;
}

struct Classification
{
    Class[4] classes;
    int numEightbytes;

    const(Class[]) slice() const return @safe { return classes[0 .. numEightbytes]; }
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
    Class[4] result = Class.noClass;

    this(size_t size) scope @safe
    {
        assert(size > 0);
        this.size = size;
        this.numEightbytes = cast(int) ((size + 7) / 8);
    }

    void memory()
    {
        result[0 .. numEightbytes] = Class.memory;
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

    override void visit(TypeNoreturn t)
    {
        // Treat as void
        return visit(Type.tvoid);
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
            return one(Class.integer);

        case Tint128:
        case Tuns128:
            return two(Class.integer, Class.integer);

        case Tfloat80:
        case Timaginary80:
            return two(Class.x87, Class.x87Up);

        case Tfloat32:
        case Tfloat64:
        case Timaginary32:
        case Timaginary64:
        case Tcomplex32: // struct { float a, b; }
            return one(Class.sse);

        case Tcomplex64: // struct { double a, b; }
            return two(Class.sse, Class.sse);

        case Tcomplex80: // struct { real a, b; }
            result[0 .. 4] = Class.complexX87;
            return;

        default:
            assert(0, "Unexpected basic type");
        }
    }

    override void visit(TypeVector t)
    {
        result[0] = Class.sse;
        result[1 .. numEightbytes] = Class.sseUp;
    }

    override void visit(TypeAArray)
    {
        return one(Class.integer);
    }

    override void visit(TypePointer)
    {
        return one(Class.integer);
    }

    override void visit(TypeNull)
    {
        return one(Class.integer);
    }

    override void visit(TypeClass)
    {
        return one(Class.integer);
    }

    override void visit(TypeDArray)
    {
        if (!target.isLP64)
            return one(Class.integer);
        return two(Class.integer, Class.integer);
    }

    override void visit(TypeDelegate)
    {
        if (!target.isLP64)
            return one(Class.integer);
        return two(Class.integer, Class.integer);
    }

    override void visit(TypeSArray t)
    {
        // treat as struct with N fields

        auto baseElemType = t.next.toBasetype().isTypeStruct();
        if (baseElemType && !baseElemType.sym.isPOD())
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

        classifyFields(baseOffset, t.sym.fields.length, &getNthField);
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

            if (auto ts = ftype.isTypeStruct())
                classifyStructFields(foffset, ts);
            else if (auto tsa = ftype.isTypeSArray())
                classifyStaticArrayElements(foffset, tsa);
            else if (ftype.toBasetype().isTypeNoreturn())
            {
                // Ignore noreturn members with sizeof = 0
                // Potential custom alignment changes are factored in above
                nfields--;
                continue;
            }
            else
            {
                const fEightbyteStart = foffset / 8;
                const fEightbyteEnd = (foffset + fsize + 7) / 8;
                if (ftype.ty == Tcomplex32) // may lie in 2 eightbytes
                {
                    assert(foffset % 4 == 0);
                    foreach (ref existingClass; result[fEightbyteStart .. fEightbyteEnd])
                        existingClass = merge(existingClass, Class.sse);
                }
                else
                {
                    assert(foffset % 8 == 0 ||
                        fEightbyteEnd - fEightbyteStart <= 1 ||
                        !target.isLP64,
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

        if (nfields == 0)
            return memory();
    }

    void finalizeAggregate()
    {
        foreach (i, ref c; result)
        {
            if (c == Class.memory ||
                (c == Class.x87Up && !(i > 0 && result[i - 1] == Class.x87)))
                return memory();

            if (c == Class.sseUp && !(i > 0 &&
                (result[i - 1] == Class.sse || result[i - 1] == Class.sseUp)))
                c = Class.sse;
        }

        if (numEightbytes > 2)
        {
            if (result[0] != Class.sse)
                return memory();

            foreach (c; result[1 .. numEightbytes])
                if (c != Class.sseUp)
                    return memory();
        }

        // Undocumented special case for aggregates with the 2nd eightbyte
        // consisting of padding only (`struct S { align(16) int a; }`).
        // clang only passes the first eightbyte in that case, so let's do the
        // same.
        if (numEightbytes == 2 && result[1] == Class.noClass)
            numEightbytes = 1;
    }
}
