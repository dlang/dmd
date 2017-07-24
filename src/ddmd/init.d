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
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.identifier;
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

    /* Translates to an expression to infer type.
     * Returns ExpInitializer or ErrorInitializer.
     */
    abstract Initializer inferType(Scope* sc);

    abstract Expression toExpression(Type t = null);

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

    override Initializer inferType(Scope* sc)
    {
        error(loc, "cannot infer type from void initializer");
        return new ErrorInitializer();
    }

    override Expression toExpression(Type t = null)
    {
        return null;
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

    override Initializer inferType(Scope* sc)
    {
        return this;
    }

    override Expression toExpression(Type t = null)
    {
        return new ErrorExp();
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

    override Initializer inferType(Scope* sc)
    {
        error(loc, "cannot infer type from struct initializer");
        return new ErrorInitializer();
    }

    /***************************************
     * This works by transforming a struct initializer into
     * a struct literal. In the future, the two should be the
     * same thing.
     */
    override Expression toExpression(Type t = null)
    {
        // cannot convert to an expression without target 'ad'
        return null;
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

    override Initializer inferType(Scope* sc)
    {
        //printf("ArrayInitializer::inferType() %s\n", toChars());
        Expressions* keys = null;
        Expressions* values;
        if (isAssociativeArray())
        {
            keys = new Expressions();
            keys.setDim(value.dim);
            values = new Expressions();
            values.setDim(value.dim);
            for (size_t i = 0; i < value.dim; i++)
            {
                Expression e = index[i];
                if (!e)
                    goto Lno;
                (*keys)[i] = e;
                Initializer iz = value[i];
                if (!iz)
                    goto Lno;
                iz = iz.inferType(sc);
                if (iz.isErrorInitializer())
                    return iz;
                assert(iz.isExpInitializer());
                (*values)[i] = (cast(ExpInitializer)iz).exp;
                assert((*values)[i].op != TOKerror);
            }
            Expression e = new AssocArrayLiteralExp(loc, keys, values);
            auto ei = new ExpInitializer(loc, e);
            return ei.inferType(sc);
        }
        else
        {
            auto elements = new Expressions();
            elements.setDim(value.dim);
            elements.zero();
            for (size_t i = 0; i < value.dim; i++)
            {
                assert(!index[i]); // already asserted by isAssociativeArray()
                Initializer iz = value[i];
                if (!iz)
                    goto Lno;
                iz = iz.inferType(sc);
                if (iz.isErrorInitializer())
                    return iz;
                assert(iz.isExpInitializer());
                (*elements)[i] = (cast(ExpInitializer)iz).exp;
                assert((*elements)[i].op != TOKerror);
            }
            Expression e = new ArrayLiteralExp(loc, elements);
            auto ei = new ExpInitializer(loc, e);
            return ei.inferType(sc);
        }
    Lno:
        if (keys)
        {
            error(loc, "not an associative array initializer");
        }
        else
        {
            error(loc, "cannot infer type from array initializer");
        }
        return new ErrorInitializer();
    }

    /********************************
     * If possible, convert array initializer to array literal.
     * Otherwise return NULL.
     */
    override Expression toExpression(Type tx = null)
    {
        //printf("ArrayInitializer::toExpression(), dim = %d\n", dim);
        //static int i; if (++i == 2) assert(0);
        Expressions* elements;
        uint edim;
        const(uint) amax = 0x80000000;
        Type t = null;
        if (type)
        {
            if (type == Type.terror)
                return new ErrorExp();
            t = type.toBasetype();
            switch (t.ty)
            {
            case Tvector:
                t = (cast(TypeVector)t).basetype;
                goto case Tsarray;

            case Tsarray:
                uinteger_t adim = (cast(TypeSArray)t).dim.toInteger();
                if (adim >= amax)
                    goto Lno;
                edim = cast(uint)adim;
                break;

            case Tpointer:
            case Tarray:
                edim = dim;
                break;

            default:
                assert(0);
            }
        }
        else
        {
            edim = cast(uint)value.dim;
            for (size_t i = 0, j = 0; i < value.dim; i++, j++)
            {
                if (index[i])
                {
                    if (index[i].op == TOKint64)
                    {
                        const uinteger_t idxval = index[i].toInteger();
                        if (idxval >= amax)
                            goto Lno;
                        j = cast(size_t)idxval;
                    }
                    else
                        goto Lno;
                }
                if (j >= edim)
                    edim = cast(uint)(j + 1);
            }
        }
        elements = new Expressions();
        elements.setDim(edim);
        elements.zero();
        for (size_t i = 0, j = 0; i < value.dim; i++, j++)
        {
            if (index[i])
                j = cast(size_t)index[i].toInteger();
            assert(j < edim);
            Initializer iz = value[i];
            if (!iz)
                goto Lno;
            Expression ex = iz.toExpression();
            if (!ex)
            {
                goto Lno;
            }
            (*elements)[j] = ex;
        }
        {
            /* Fill in any missing elements with the default initializer
             */
            Expression _init = null;
            for (size_t i = 0; i < edim; i++)
            {
                if (!(*elements)[i])
                {
                    if (!type)
                        goto Lno;
                    if (!_init)
                        _init = (cast(TypeNext)t).next.defaultInit();
                    (*elements)[i] = _init;
                }
            }

            /* Expand any static array initializers that are a single expression
             * into an array of them
             */
            if (t)
            {
                Type tn = t.nextOf().toBasetype();
                if (tn.ty == Tsarray)
                {
                    const dim = cast(size_t)(cast(TypeSArray)tn).dim.toInteger();
                    Type te = tn.nextOf().toBasetype();
                    foreach (ref e; *elements)
                    {
                        if (te.equals(e.type))
                        {
                            auto elements2 = new Expressions();
                            elements2.setDim(dim);
                            foreach (ref e2; *elements2)
                                e2 = e;
                            e = new ArrayLiteralExp(e.loc, elements2);
                            e.type = tn;
                        }
                    }
                }
            }

            /* If any elements are errors, then the whole thing is an error
             */
            for (size_t i = 0; i < edim; i++)
            {
                Expression e = (*elements)[i];
                if (e.op == TOKerror)
                    return e;
            }

            Expression e = new ArrayLiteralExp(loc, elements);
            e.type = type;
            return e;
        }
    Lno:
        return null;
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
            e = iz.toExpression();
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

    override Initializer inferType(Scope* sc)
    {
        //printf("ExpInitializer::inferType() %s\n", toChars());
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);
        if (exp.op == TOKscope)
        {
            ScopeExp se = cast(ScopeExp)exp;
            TemplateInstance ti = se.sds.isTemplateInstance();
            if (ti && ti.semanticRun == PASSsemantic && !ti.aliasdecl)
                se.error("cannot infer type from %s %s, possible circular dependency", se.sds.kind(), se.toChars());
            else
                se.error("cannot infer type from %s %s", se.sds.kind(), se.toChars());
            return new ErrorInitializer();
        }

        // Give error for overloaded function addresses
        bool hasOverloads;
        if (auto f = isFuncAddress(exp, &hasOverloads))
        {
            if (f.checkForwardRef(loc))
                return new ErrorInitializer();
            if (hasOverloads && !f.isUnique())
            {
                exp.error("cannot infer type from overloaded function symbol %s", exp.toChars());
                return new ErrorInitializer();
            }
        }
        if (exp.op == TOKaddress)
        {
            AddrExp ae = cast(AddrExp)exp;
            if (ae.e1.op == TOKoverloadset)
            {
                exp.error("cannot infer type from overloaded function symbol %s", exp.toChars());
                return new ErrorInitializer();
            }
        }
        if (exp.op == TOKerror)
            return new ErrorInitializer();
        if (!exp.type)
            return new ErrorInitializer();
        return this;
    }

    override Expression toExpression(Type t = null)
    {
        if (t)
        {
            //printf("ExpInitializer::toExpression(t = %s) exp = %s\n", t.toChars(), exp.toChars());
            Type tb = t.toBasetype();
            Expression e = (exp.op == TOKconstruct || exp.op == TOKblit) ? (cast(AssignExp)exp).e2 : exp;
            if (tb.ty == Tsarray && e.implicitConvTo(tb.nextOf()))
            {
                TypeSArray tsa = cast(TypeSArray)tb;
                size_t d = cast(size_t)tsa.dim.toInteger();
                auto elements = new Expressions();
                elements.setDim(d);
                for (size_t i = 0; i < d; i++)
                    (*elements)[i] = e;
                auto ae = new ArrayLiteralExp(e.loc, elements);
                ae.type = t;
                return ae;
            }
        }
        return exp;
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
