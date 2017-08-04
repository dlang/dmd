/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _init.d)
 */

module ddmd.init;

import core.stdc.stdio;
import core.checkedint;

import ddmd.arraytypes;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.expressionsem;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.identifier;
import ddmd.initsem;
import ddmd.mtype;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.tokens;
import ddmd.visitor;

enum NeedInterpret : int
{
    INITnointerpret,
    INITinterpret,
}

alias INITnointerpret = NeedInterpret.INITnointerpret;
alias INITinterpret = NeedInterpret.INITinterpret;

/***********************************************************
 */
extern (C++) class Initializer : RootObject
{
    Loc loc;

    final extern (D) this(Loc loc)
    {
        this.loc = loc;
    }

    abstract Initializer syntaxCopy();

    static Initializers* arraySyntaxCopy(Initializers* ai)
    {
        Initializers* a = null;
        if (ai)
        {
            a = new Initializers();
            a.setDim(ai.dim);
            for (size_t i = 0; i < a.dim; i++)
                (*a)[i] = (*ai)[i].syntaxCopy();
        }
        return a;
    }

    override final const(char)* toChars()
    {
        OutBuffer buf;
        HdrGenState hgs;
        .toCBuffer(this, &buf, &hgs);
        return buf.extractString();
    }

    ErrorInitializer isErrorInitializer()
    {
        return null;
    }

    VoidInitializer isVoidInitializer()
    {
        return null;
    }

    StructInitializer isStructInitializer()
    {
        return null;
    }

    ArrayInitializer isArrayInitializer()
    {
        return null;
    }

    ExpInitializer isExpInitializer()
    {
        return null;
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

    extern (D) this(Loc loc)
    {
        super(loc);
    }

    override Initializer syntaxCopy()
    {
        return new VoidInitializer(loc);
    }

    override VoidInitializer isVoidInitializer()
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
extern (C++) final class ErrorInitializer : Initializer
{
    extern (D) this()
    {
        super(Loc());
    }

    override Initializer syntaxCopy()
    {
        return this;
    }

    override ErrorInitializer isErrorInitializer()
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

    extern (D) this(Loc loc)
    {
        super(loc);
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

    override StructInitializer isStructInitializer()
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
extern (C++) final class ArrayInitializer : Initializer
{
    Expressions index;      // indices
    Initializers value;     // of Initializer *'s
    uint dim;               // length of array being initialized
    Type type;              // type that array will be used to initialize
    bool sem;               // true if semantic() is run

    extern (D) this(Loc loc)
    {
        super(loc);
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

    /********************************
     * If possible, convert array initializer to associative array initializer.
     */
    Expression toAssocArrayLiteral()
    {
        Expression e;
        //printf("ArrayInitializer::toAssocArrayInitializer()\n");
        //static int i; if (++i == 2) assert(0);
        auto keys = new Expressions();
        keys.setDim(value.dim);
        auto values = new Expressions();
        values.setDim(value.dim);
        for (size_t i = 0; i < value.dim; i++)
        {
            e = index[i];
            if (!e)
                goto Lno;
            (*keys)[i] = e;
            Initializer iz = value[i];
            if (!iz)
                goto Lno;
            e = iz.initializerToExpression();
            if (!e)
                goto Lno;
            (*values)[i] = e;
        }
        e = new AssocArrayLiteralExp(loc, keys, values);
        return e;
    Lno:
        error(loc, "not an associative array initializer");
        return new ErrorExp();
    }

    override ArrayInitializer isArrayInitializer()
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
extern (C++) final class ExpInitializer : Initializer
{
    Expression exp;
    bool expandTuples;

    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Initializer syntaxCopy()
    {
        return new ExpInitializer(loc, exp.syntaxCopy());
    }

    override ExpInitializer isExpInitializer()
    {
        return this;
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
        if (e.op == TOKnull)
            return false;
        if (e.op == TOKstructliteral)
        {
            StructLiteralExp se = cast(StructLiteralExp)e;
            return checkArray(se.elements);
        }
        if (e.op == TOKarrayliteral)
        {
            if (!e.type.nextOf().hasPointers())
                return false;
            ArrayLiteralExp ae = cast(ArrayLiteralExp)e;
            return checkArray(ae.elements);
        }
        if (e.op == TOKassocarrayliteral)
        {
            AssocArrayLiteralExp ae = cast(AssocArrayLiteralExp)e;
            if (ae.type.nextOf().hasPointers() && checkArray(ae.values))
                return true;
            if ((cast(TypeAArray)ae.type).index.hasPointers())
                return checkArray(ae.keys);
            return false;
        }
        if (e.op == TOKaddress)
        {
            AddrExp ae = cast(AddrExp)e;
            if (ae.e1.op == TOKstructliteral)
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
            if (e.op == TOKsymoff) // address of a global is OK
                return false;
            if (e.op == TOKint64) // cast(void *)int is OK
                return false;
            if (e.op == TOKstring) // "abc".ptr is OK
                return false;
            return true;
        }
        return false;
    }
}
