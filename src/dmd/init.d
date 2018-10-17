/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
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
extern (C++) class Initializer : RootObject
{
    Loc loc;
    InitKind kind;


    extern (D) this(const ref Loc loc, InitKind kind)
    {
        this.loc = loc;
        this.kind = kind;
    }

    abstract Initializer syntaxCopy();

    override final const(char)* toChars()
    {
        OutBuffer buf;
        HdrGenState hgs;
        .toCBuffer(this, &buf, &hgs);
        return buf.extractString();
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

    void accept(Visitor v)
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

    override Initializer syntaxCopy()
    {
        return new VoidInitializer(loc);
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

    override Initializer syntaxCopy()
    {
        return this;
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

    override Initializer syntaxCopy()
    {
        auto ai = new StructInitializer(loc);
        assert(field.dim == value.dim);
        ai.field.setDim(field.dim);
        ai.value.setDim(value.dim);
        for (size_t i = 0; i < field.dim; i++)
        {
            ai.field[i] = field[i];
            ai.value[i] = value[i].syntaxCopy();
        }
        return ai;
    }

    void addInit(Identifier field, Initializer value)
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

    override Initializer syntaxCopy()
    {
        //printf("ArrayInitializer::syntaxCopy()\n");
        auto ai = new ArrayInitializer(loc);
        assert(index.dim == value.dim);
        ai.index.setDim(index.dim);
        ai.value.setDim(value.dim);
        for (size_t i = 0; i < ai.value.dim; i++)
        {
            ai.index[i] = index[i] ? index[i].syntaxCopy() : null;
            ai.value[i] = value[i].syntaxCopy();
        }
        return ai;
    }

    void addInit(Expression index, Initializer value)
    {
        this.index.push(index);
        this.value.push(value);
        dim = 0;
        type = null;
    }

    bool isAssociativeArray()
    {
        for (size_t i = 0; i < value.dim; i++)
        {
            if (index[i])
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
    Expression exp;
    bool expandTuples;

    extern (D) this(const ref Loc loc, Expression exp)
    {
        super(loc, InitKind.exp);
        this.exp = exp;
    }

    override Initializer syntaxCopy()
    {
        return new ExpInitializer(loc, exp.syntaxCopy());
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
        if (e.op == TOK.structLiteral)
        {
            StructLiteralExp se = cast(StructLiteralExp)e;
            return checkArray(se.elements);
        }
        if (e.op == TOK.arrayLiteral)
        {
            if (!e.type.nextOf().hasPointers())
                return false;
            ArrayLiteralExp ae = cast(ArrayLiteralExp)e;
            return checkArray(ae.elements);
        }
        if (e.op == TOK.assocArrayLiteral)
        {
            AssocArrayLiteralExp ae = cast(AssocArrayLiteralExp)e;
            if (ae.type.nextOf().hasPointers() && checkArray(ae.values))
                return true;
            if ((cast(TypeAArray)ae.type).index.hasPointers())
                return checkArray(ae.keys);
            return false;
        }
        if (e.op == TOK.address)
        {
            AddrExp ae = cast(AddrExp)e;
            if (ae.e1.op == TOK.structLiteral)
            {
                StructLiteralExp se = cast(StructLiteralExp)ae.e1;
                if (!(se.stageflags & stageSearchPointers))
                {
                    int old = se.stageflags;
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
