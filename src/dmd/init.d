/**
 * Defines initializers of variables, e.g. the array literal in `int[3] x = [0, 1, 2]`.
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/init.d, _init.d)
 * Documentation:  https://dlang.org/phobos/dmd_init.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/init.d
 */

module dmd.init;

import core.stdc.stdio;
import core.checkedint;

import dmd.arraytypes;
import dmd.ast_node;
import dmd.dsymbol;
import dmd.expression;
import dmd.globals;
import dmd.hdrgen;
import dmd.identifier;
import dmd.mtype;
import dmd.root.outbuffer;
import dmd.root.rootobject;
import dmd.tokens;
import dmd.visitor;
// import core.checkedint : ;

// import dmd.root.rootobject : ;
enum NeedInterpret : int
{
    INITnointerpret,
    INITinterpret,
}

alias INITnointerpret = NeedInterpret.INITnointerpret;
alias INITinterpret = NeedInterpret.INITinterpret;

/*************
 * Discriminant for which kind of initializer
 */
enum InitKind : ubyte
{
    void_,
    error,
    struct_,
    array,
    exp,
}

/***********************************************************
 */
extern (C++) class Initializer : ASTNode
{
    Loc loc;
    InitKind kind;


    extern (D) this(const ref Loc loc, InitKind kind)
    {
        this.loc = loc;
        this.kind = kind;
    }

    override final const(char)* toChars() const
    {
        OutBuffer buf;
        HdrGenState hgs;
        .toCBuffer(this, &buf, &hgs);
        return buf.extractChars();
    }

    final inout(ErrorInitializer) isErrorInitializer() inout pure
    {
        // Use void* cast to skip dynamic casting call
        return kind == InitKind.error ? cast(inout ErrorInitializer)cast(void*)this : null;
    }

    final inout(VoidInitializer) isVoidInitializer() inout pure
    {
        return kind == InitKind.void_ ? cast(inout VoidInitializer)cast(void*)this : null;
    }

    final inout(StructInitializer) isStructInitializer() inout pure
    {
        return kind == InitKind.struct_ ? cast(inout StructInitializer)cast(void*)this : null;
    }

    final inout(ArrayInitializer) isArrayInitializer() inout pure
    {
        return kind == InitKind.array ? cast(inout ArrayInitializer)cast(void*)this : null;
    }

    final inout(ExpInitializer) isExpInitializer() inout pure
    {
        return kind == InitKind.exp ? cast(inout ExpInitializer)cast(void*)this : null;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class VoidInitializer : Initializer
{
    Type type;      // type that this will initialize to

    extern (D) this(const ref Loc loc)
    {
        super(loc, InitKind.void_);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ErrorInitializer : Initializer
{
    extern (D) this()
    {
        super(Loc.initial, InitKind.error);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class StructInitializer : Initializer
{
    Identifiers field;      // of Identifier *'s
    Initializers value;     // parallel array of Initializer *'s

    extern (D) this(const ref Loc loc)
    {
        super(loc, InitKind.struct_);
    }

    extern (D) void addInit(Identifier field, Initializer value)
    {
        //printf("StructInitializer::addInit(field = %p, value = %p)\n", field, value);
        this.field.push(field);
        this.value.push(value);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ArrayInitializer : Initializer
{
    Expressions index;      // indices
    Initializers value;     // of Initializer *'s
    uint dim;               // length of array being initialized
    Type type;              // type that array will be used to initialize
    bool sem;               // true if semantic() is run

    extern (D) this(const ref Loc loc)
    {
        super(loc, InitKind.array);
    }

    extern (D) void addInit(Expression index, Initializer value)
    {
        this.index.push(index);
        this.value.push(value);
        dim = 0;
        type = null;
    }

    bool isAssociativeArray() const pure
    {
        foreach (idx; index)
        {
            if (idx)
                return true;
        }
        return false;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ExpInitializer : Initializer
{
    bool expandTuples;
    Expression exp;

    extern (D) this(const ref Loc loc, Expression exp)
    {
        super(loc, InitKind.exp);
        this.exp = exp;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

version (all)
{
    extern (C++) bool hasNonConstPointers(Expression e)
    {
        static bool checkArray(Expressions* elems)
        {
            foreach (e; *elems)
            {
                if (e && hasNonConstPointers(e))
                    return true;
            }
            return false;
        }

        if (e.type.ty == Terror)
            return false;
        if (e.op == TOK.null_)
            return false;
        if (auto se = e.isStructLiteralExp())
        {
            return checkArray(se.elements);
        }
        if (auto ae = e.isArrayLiteralExp())
        {
            if (!ae.type.nextOf().hasPointers())
                return false;
            return checkArray(ae.elements);
        }
        if (auto ae = e.isAssocArrayLiteralExp())
        {
            if (ae.type.nextOf().hasPointers() && checkArray(ae.values))
                return true;
            if ((cast(TypeAArray)ae.type).index.hasPointers())
                return checkArray(ae.keys);
            return false;
        }
        if (auto ae = e.isAddrExp())
        {
            if (auto se = ae.e1.isStructLiteralExp())
            {
                if (!(se.stageflags & stageSearchPointers))
                {
                    const old = se.stageflags;
                    se.stageflags |= stageSearchPointers;
                    bool ret = checkArray(se.elements);
                    se.stageflags = old;
                    return ret;
                }
                else
                {
                    return false;
                }
            }
            return true;
        }
        if (e.type.ty == Tpointer && e.type.nextOf().ty != Tfunction)
        {
            if (e.op == TOK.symbolOffset) // address of a global is OK
                return false;
            if (e.op == TOK.int64) // cast(void *)int is OK
                return false;
            if (e.op == TOK.string_) // "abc".ptr is OK
                return false;
            return true;
        }
        return false;
    }
}


/****************************************
 * Copy the AST for Initializer.
 * Params:
 *      inx = Initializer AST to copy
 * Returns:
 *      the copy
 */
Initializer syntaxCopy(Initializer inx)
{
    static Initializer copyStruct(StructInitializer vi)
    {
        auto si = new StructInitializer(vi.loc);
        assert(vi.field.dim == vi.value.dim);
        si.field.setDim(vi.field.dim);
        si.value.setDim(vi.value.dim);
        foreach (const i; 0 .. vi.field.dim)
        {
            si.field[i] = vi.field[i];
            si.value[i] = vi.value[i].syntaxCopy();
        }
        return si;
    }

    static Initializer copyArray(ArrayInitializer vi)
    {
        auto ai = new ArrayInitializer(vi.loc);
        assert(vi.index.dim == vi.value.dim);
        ai.index.setDim(vi.index.dim);
        ai.value.setDim(vi.value.dim);
        foreach (const i; 0 .. vi.value.dim)
        {
            ai.index[i] = vi.index[i] ? vi.index[i].syntaxCopy() : null;
            ai.value[i] = vi.value[i].syntaxCopy();
        }
        return ai;
    }

    final switch (inx.kind)
    {
        case InitKind.void_:   return new VoidInitializer(inx.loc);
        case InitKind.error:   return inx;
        case InitKind.struct_: return copyStruct(cast(StructInitializer)inx);
        case InitKind.array:   return copyArray(cast(ArrayInitializer)inx);
        case InitKind.exp:     return new ExpInitializer(inx.loc, (cast(ExpInitializer)inx).exp.syntaxCopy());
    }
}
