// Compiler implementation of the D programming language
// Copyright (c) 1999-2016 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.init;

import core.stdc.stdio;
import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.dcast;
import ddmd.declaration;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.opover;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.statement;
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

    final Type checkMultiDimInit(Scope* sc, Type t)
    {
        Type tb = t.toBasetype();
        if (tb.ty == Tsarray)
        {
            Type tn = (cast(TypeNext)tb).next;
            if (isArrayInitializer() &&
                tn.ty != Tarray && tn.ty != Tsarray && tn.ty != Taarray)
            {
                // do not test matching
            }
            else
            {
                Type tx = checkMultiDimInit(sc, tn);
                if (tx)
                    return tx;
            }
        }
        return canMatch(sc, t) ? t : null;
    }

    bool canMatch(Scope* sc, Type t)
    {
        return false;
    }

    // needInterpret is INITinterpret if must be a manifest constant, 0 if not.
    final Initializer semantic(Scope* sc, Type t, NeedInterpret needInterpret)
    {
        if (needInterpret)
            sc = sc.startCTFE();

        // Prefer multidimensional initializing in local variable
        Type to = checkMultiDimInit(sc, t);
        if (!to)
            to = t;
        auto iz = semantic(sc, to, true);

        if (needInterpret)
            sc = sc.endCTFE();

        auto ez = iz.isExpInitializer();
        if (needInterpret && ez)
        {
            auto e = ez.exp;

            // If the result will be implicitly cast, move the cast into CTFE
            // to avoid premature truncation of polysemous types.
            // eg real [] x = [1.1, 2.2]; should use real precision.
            if (e.implicitConvTo(to))
                e = e.implicitCastTo(sc, to);
            e = e.ctfeInterpret();
            if (hasNonConstPointers(e))
            {
                e.error("cannot use non-constant CTFE pointer in an initializer '%s'", e.toChars());
                e = new ErrorExp();
            }
            e = e.implicitCastTo(sc, to);

            if (e.op == TOKerror)
                iz = new ErrorInitializer();
            else
                ez.exp = e;
        }
        return iz;
    }

    abstract Initializer semantic(Scope* sc, Type t, bool top = false);

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

    override Initializer semantic(Scope* sc, Type t, bool top = false)
    {
        //printf("VoidInitializer::semantic(t = %p)\n", t);
        type = t;
        return this;
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

    override Initializer semantic(Scope* sc, Type t, bool top = false)
    {
        //printf("ErrorInitializer::semantic(t = %p)\n", t);
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
    Initializers value;     // parallel array of Initializer's

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

    override bool canMatch(Scope* sc, Type t)
    {
        t = t.toBasetype();
        return (t.ty == Tstruct ||
                t.ty == Tdelegate ||
                t.ty == Tpointer && (cast(TypeNext)t).next.ty == Tfunction);
    }

    override Initializer semantic(Scope* sc, Type t, bool top = false)
    {
        //printf("StructInitializer::semantic(t = %s) %s\n", t.toChars(), toChars());
        t = t.toBasetype();
        if (t.ty == Tsarray && t.nextOf().toBasetype().ty == Tstruct)
            t = t.nextOf().toBasetype();
        if (t.ty == Tstruct)
        {
            StructDeclaration sd = (cast(TypeStruct)t).sym;
            if (sd.ctor)
            {
                error(loc, "%s %s has constructors, cannot use { initializers }, use %s( initializers ) instead", sd.kind(), sd.toChars(), sd.toChars());
                return new ErrorInitializer();
            }
            sd.size(loc);
            if (sd.sizeok != SIZEOKdone)
                return new ErrorInitializer();
            size_t nfields = sd.fields.dim - sd.isNested();
            //expandTuples for non-identity arguments?
            auto elements = new Expressions();
            elements.setDim(nfields);
            for (size_t i = 0; i < elements.dim; i++)
                (*elements)[i] = null;
            // Run semantic for explicitly given initializers
            // TODO: this part is slightly different from StructLiteralExp::semantic.
            bool errors = false;
            for (size_t fieldi = 0, i = 0; i < field.dim; i++)
            {
                if (Identifier id = field[i])
                {
                    Dsymbol s = sd.search(loc, id);
                    if (!s)
                    {
                        s = sd.search_correct(id);
                        if (s)
                            error(loc, "'%s' is not a member of '%s', did you mean %s '%s'?", id.toChars(), sd.toChars(), s.kind(), s.toChars());
                        else
                            error(loc, "'%s' is not a member of '%s'", id.toChars(), sd.toChars());
                        return new ErrorInitializer();
                    }
                    s = s.toAlias();
                    // Find out which field index it is
                    for (fieldi = 0; 1; fieldi++)
                    {
                        if (fieldi >= nfields)
                        {
                            error(loc, "%s.%s is not a per-instance initializable field", sd.toChars(), s.toChars());
                            return new ErrorInitializer();
                        }
                        if (s == sd.fields[fieldi])
                            break;
                    }
                }
                else if (fieldi >= nfields)
                {
                    error(loc, "too many initializers for %s", sd.toChars());
                    return new ErrorInitializer();
                }
                VarDeclaration vd = sd.fields[fieldi];
                if ((*elements)[fieldi])
                {
                    error(loc, "duplicate initializer for field '%s'", vd.toChars());
                    errors = true;
                    continue;
                }
                for (size_t j = 0; j < nfields; j++)
                {
                    VarDeclaration v2 = sd.fields[j];
                    if (vd.isOverlappedWith(v2) && (*elements)[j])
                    {
                        error(loc, "overlapping initialization for field %s and %s", v2.toChars(), vd.toChars());
                        errors = true;
                        continue;
                    }
                }
                assert(sc);
                Initializer iz = value[i];
                iz = iz.semantic(sc, vd.type.addMod(t.mod));
                Expression ex = iz.toExpression();
                if (ex.op == TOKerror)
                {
                    errors = true;
                    continue;
                }
                value[i] = iz;
                (*elements)[fieldi] = ex;
                ++fieldi;
            }
            if (errors)
                return new ErrorInitializer();
            auto sle = new StructLiteralExp(loc, sd, elements, t);
            if (!sd.fill(loc, elements, false))
                return new ErrorInitializer();
            sle.type = t;
            auto ie = new ExpInitializer(loc, sle);
            return ie.semantic(sc, t, top);
        }
        else if ((t.ty == Tdelegate || t.ty == Tpointer && t.nextOf().ty == Tfunction) && value.dim == 0)
        {
            TOK tok = (t.ty == Tdelegate) ? TOKdelegate : TOKfunction;
            /* Rewrite as empty delegate literal { }
             */
            auto parameters = new Parameters();
            Type tf = new TypeFunction(parameters, null, 0, LINKd);
            auto fd = new FuncLiteralDeclaration(loc, Loc(), tf, tok, null);
            fd.fbody = new CompoundStatement(loc, new Statements());
            fd.endloc = loc;
            Expression e = new FuncExp(loc, fd);
            auto ie = new ExpInitializer(loc, e);
            return ie.semantic(sc, t, top);
        }
        error(loc, "a struct is not a valid initializer for a %s", t.toChars());
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
    Initializers value;     // of Initializer's

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
                auto e = index[i];
                if (!e)
                    goto Lno;
                (*keys)[i] = e;

                auto iz = value[i];
                if (!iz)
                    goto Lno;
                iz = iz.inferType(sc);
                if (iz.isErrorInitializer())
                    return iz;
                assert(iz.isExpInitializer());
                (*values)[i] = (cast(ExpInitializer)iz).exp;
                assert((*values)[i].op != TOKerror);
            }

            auto e = new AssocArrayLiteralExp(loc, keys, values);
            auto ez = new ExpInitializer(loc, e);
            return ez.inferType(sc);
        }
        else
        {
            auto elements = new Expressions();
            elements.setDim(value.dim);
            elements.zero();

            for (size_t i = 0; i < value.dim; i++)
            {
                assert(!index[i]); // already asserted by isAssociativeArray()

                auto iz = value[i];
                if (!iz)
                    goto Lno;
                iz = iz.inferType(sc);
                if (iz.isErrorInitializer())
                    return iz;
                assert(iz.isExpInitializer());
                (*elements)[i] = (cast(ExpInitializer)iz).exp;
                assert((*elements)[i].op != TOKerror);
            }

            auto e = new ArrayLiteralExp(loc, elements);
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

    override bool canMatch(Scope* sc, Type t)
    {
        t = t.toBasetype();
        if (t.ty == Tvector)
            t = (cast(TypeVector)t).basetype;
        if (t.ty == Tarray || t.ty == Tsarray || t.ty == Taarray)
        {
            if (value.dim)
            {
                Type tn = (cast(TypeNext)t).next;
                for (size_t i = 0; i < value.dim; i++)
                {
                    // definitely not an AA literal
                    if (index[i] is null && t.ty == Taarray)
                        return false;

                    if (!value[i].canMatch(sc, tn))
                        return false;
                }
                return true;
            }
            else
            {
                if (t.ty == Tarray)
                    return true;
                else if (t.ty == Taarray)
                    return false;
                else
                    return (cast(TypeSArray)t).dim.toInteger() == 0;
            }
        }
        return false;
    }

    /********************************
     * Convert array initializer to array expression.
     */
    override Initializer semantic(Scope* sc, Type t, bool top = false)
    {
        //printf("ArrayInitializer::semantic(%s)\n", t.toChars());

        const(uint) amax = 0x80000000;
        bool errors = false;

        t = t.toBasetype();
        switch (t.ty)
        {
        case Tsarray:
        case Tarray:
            // void[$], void[]
            Type tn = (cast(TypeNext)t).next;
            if (tn.ty == Tvoid)
            {
                auto iz = inferType(sc);
                auto e = iz.toExpression();
                if (e.op == TOKarrayliteral)
                {
                    // cast to void[]
                    // TODO: check content size matching?
                    t = tn.arrayOf();
                }
                iz = new ExpInitializer(loc, e);
                return iz.semantic(sc, t, top);
            }
            break;

        case Tvector:
            t = (cast(TypeVector)t).basetype;
            break;

        case Taarray:
            return semanticAA(sc, t, top);

        case Tstruct: // consider implicit constructor call
            auto iz = inferType(sc);
            return iz.semantic(sc, t, top);

        default:
            error(loc, "cannot use array to initialize %s", t.toChars());
            return new ErrorInitializer();
        }

        size_t dim = 0;
        size_t length = 0;
        Type tn = (cast(TypeNext)t).next;
        for (size_t i = 0; i < index.dim; i++)
        {
            /* On sparse array initializing, indices should be
             * interpretd at compile time, even in function bodies.
             */
            Expression idx = index[i];
            if (idx)
            {
                sc = sc.startCTFE();
                idx = idx.semantic(sc);
                sc = sc.endCTFE();
                idx = idx.ctfeInterpret();
                index[i] = idx;
                length = cast(size_t)idx.toInteger();
                if (idx.op == TOKerror)
                    errors = true;
            }

            auto iz = value[i];
            auto ez = iz.isExpInitializer();
            if (ez && !idx)
                ez.expandTuples = true;
            iz = iz.semantic(sc, tn);
            if (iz.isErrorInitializer())
                errors = true;

            ez = iz.isExpInitializer();
            // found a tuple, expand it
            if (ez && ez.exp.op == TOKtuple)
            {
                auto te = cast(TupleExp)ez.exp;
                index.remove(i);
                value.remove(i);

                for (size_t j = 0; j < te.exps.dim; ++j)
                {
                    auto e = (*te.exps)[j];
                    index.insert(i + j, cast(Expression)null);
                    value.insert(i + j, new ExpInitializer(e.loc, e));
                }
                i--;
                continue;
            }
            else
            {
                value[i] = iz;
            }

            length++;
            if (length == 0)
            {
                error(loc, "array dimension overflow");
                return new ErrorInitializer();
            }
            if (length > dim)
                dim = length;
        }
        if (errors)
            return new ErrorInitializer();
        if (t.ty == Tsarray)
        {
            const needInterpret = (sc.flags & SCOPEctfe) != 0;
            const edim = (cast(TypeSArray)t).dim.toInteger();

            /* For local variables this is not accepted, but
             * loosely allowed for static variables.
             *  int[3] a = [1,2];
             */
            if (needInterpret ? dim > edim : dim != edim)
            {
                error(loc, "array initializer has %u elements, but array length is %lld", dim, edim);
                return new ErrorInitializer();
            }
        }

        if (cast(uinteger_t)dim * t.nextOf().size() >= amax)
        {
            error(loc, "array dimension %u exceeds max of %u", cast(uint)dim, cast(uint)(amax / t.nextOf().size()));
            return new ErrorInitializer();
        }

        /* Convert to ExpInitializer with ArrayLiteralExp
         */
        size_t edim;
        switch (t.ty)
        {
           case Tsarray:
               edim = cast(size_t)(cast(TypeSArray)t).dim.toInteger();
               break;

           case Tpointer:
           case Tarray:
               edim = dim;
               break;

           default:
               assert(0);
        }

        auto elements = new Expressions();
        elements.setDim(edim);
        elements.zero();
        for (size_t i = 0, j = 0; i < value.dim; i++, j++)
        {
            if (index[i])
                j = cast(size_t)(index[i]).toInteger();
            assert(j < edim);

            auto iz = value[i];
            auto ex = iz.toExpression();
            assert(ex);
            if (tn.ty == Tsarray && ex.implicitConvTo(tn.nextOf()))
            {
                size_t d = cast(size_t)(cast(TypeSArray)tn).dim.toInteger();
                auto a = new Expressions();
                a.setDim(d);
                for (size_t k = 0; k < d; k++)
                    (*a)[k] = ex;
                ex = new ArrayLiteralExp(ex.loc, a);
            }
            (*elements)[j] = ex;
        }

        /* Fill in any missing elements with the default initializer
         */
        Expression einit;
        for (size_t i = 0; i < edim; i++)
        {
            if ((*elements)[i])
                continue;
            if (!einit)
            {
                if (tn.ty == Tsarray)
                    einit = tn.defaultInitLiteral(loc);
                else
                    einit = tn.defaultInit();
            }
            (*elements)[i] = einit;
        }

        auto e = new ArrayLiteralExp(loc, elements);
        auto ez = new ExpInitializer(loc, e);
        return ez.semantic(sc, t, top);
    }

    /********************************
     * If possible, convert array initializer to associative array expression.
     */
    Initializer semanticAA(Scope* sc, Type t, bool top = false)
    {
        //printf("ArrayInitializer::semanticAA() %s, t = %s\n", toChars(), t.toChars());
        assert(t.ty == Taarray);
        auto taa = cast(TypeAArray)t;

        auto keys = new Expressions();
        keys.setDim(value.dim);
        auto values = new Expressions();
        values.setDim(value.dim);

        for (size_t i = 0; i < value.dim; i++)
        {
            auto e = index[i];
            if (!e)
            {
            Lno:
                delete keys;
                delete values;
                error(loc, "not an associative array initializer");
                return new ErrorInitializer();
            }
            (*keys)[i] = e;

            auto iz = value[i];
            if (!iz)
                goto Lno;
            iz = iz.semantic(sc, taa.next);
            if (iz.isErrorInitializer())
                return iz;
            (*values)[i] = iz.toExpression();
        }
        auto e = new AssocArrayLiteralExp(loc, keys, values);
        auto ez = new ExpInitializer(e.loc, e);
        return ez.semantic(sc, t, top);
    }

    override Expression toExpression(Type tx = null)
    {
        //printf("ArrayInitializer::toExpression(), dim = %d\n", dim);
        assert(0);
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
            auto se = cast(ScopeExp)exp;
            auto ti = se.sds.isTemplateInstance();
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
            auto ae = cast(AddrExp)exp;
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

    override bool canMatch(Scope* sc, Type t)
    {
        exp = .inferType(exp, t);
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);

        //printf("exp = %s, exp.type = %s, t = %s, m = %d\n", exp.toChars(), exp.type.toChars(), t.toChars(), exp.implicitConvTo(t));
        t = t.toBasetype();
        if (t.ty == Tarray && t.nextOf().ty == Tvoid)
            return false;   // do not match conversion to void[]
        return (exp.implicitConvTo(t) ||
                t.ty == Tsarray && exp.implicitConvTo((cast(TypeNext)t).next));
    }

    override Initializer semantic(Scope* sc, Type t, bool top = false)
    {
        //printf("ExpInitializer::semantic(%s), type = %s\n", exp.toChars(), t.toChars());
        exp = .inferType(exp, t);
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);
        if (exp.op == TOKerror)
            return new ErrorInitializer();

        uint olderrors = global.errors;
        exp = exp.optimize(WANTvalue);
        if (!global.gag && olderrors != global.errors)
            return this; // Failed, suppress duplicate error messages

        if (exp.type.ty == Ttuple && (cast(TypeTuple)exp.type).arguments.dim == 0)
        {
            Type et = exp.type;
            exp = new TupleExp(exp.loc, new Expressions());
            exp.type = et;
        }
        if (exp.op == TOKtype)
        {
            exp.error("initializer must be an expression, not a type '%s'", exp.toChars());
            return new ErrorInitializer();
        }

        Type tb = t.toBasetype();
        Type ti = exp.type.toBasetype();

        if (exp.op == TOKtuple && expandTuples && !exp.implicitConvTo(t))
            return new ExpInitializer(loc, exp);

        /* Look for case of initializing a static array with a too-short
         * string literal, such as:
         *  char[5] foo = "abc";
         * Allow this by doing an explicit cast, which will lengthen the string
         * literal.
         */
        if (exp.op == TOKstring && tb.ty == Tsarray)
        {
            auto se = cast(StringExp)exp;
            Type typeb = se.type.toBasetype();
            TY tynto = tb.nextOf().ty;
            if (!se.committed &&
                (typeb.ty == Tarray || typeb.ty == Tsarray) &&
                (tynto == Tchar || tynto == Twchar || tynto == Tdchar) &&
                se.numberOfCodeUnits(tynto) < (cast(TypeSArray)tb).dim.toInteger())
            {
                exp = se.castTo(sc, t);
                goto L1;
            }
        }

        if (tb.ty == Tstruct &&
            !(ti.ty == Tstruct && tb.toDsymbol(sc) == ti.toDsymbol(sc)) &&
            !exp.implicitConvTo(t))
        {
            const needInterpret = (sc.flags & SCOPEctfe) != 0;
            auto sd = (cast(TypeStruct)tb).sym;
            if (sd.ctor)
            {
                /* Look for implicit constructor call
                 * Rewrite as:
                 *      S().ctor(exp)
                 */
                Expression e;
                e = new StructLiteralExp(loc, sd, null, t);
                e = new DotIdExp(loc, e, Id.ctor);
                e = new CallExp(loc, e, exp);
                e = e.semantic(sc);
                exp = e.optimize(WANTvalue);
            }
            else if (!needInterpret && top && search_function(sd, Id.call))
            {
                /* Look for static opCall
                 * (See bugzilla 2702 for more discussion)
                 * Rewrite as:
                 *      S.opCall(exp)
                 */
                Expression e;
                e = typeDotIdExp(exp.loc, t, Id.call);
                e = new CallExp(loc, e, exp);
                e = e.semantic(sc);
                e = resolveProperties(sc, e);
                exp = e.optimize(WANTvalue);
            }
        }

        // Look for the case of statically initializing an array
        // with a single member.
        if (tb.ty == Tsarray &&
            !tb.nextOf().equals(ti.toBasetype().nextOf()) &&
            exp.implicitConvTo(tb.nextOf()))
        {
            /* If the variable is not actually used in compile time, array creation is
             * redundant. So delay it until invocation of toExpression() or toDt().
             */
            t = tb.nextOf();
        }

        if (exp.checkValue())
            return new ErrorInitializer();

        if (exp.implicitConvTo(t))
        {
            exp = exp.implicitCastTo(sc, t);
        }
        else
        {
            // Look for mismatch of compile-time known length to emit
            // better diagnostic message, as same as AssignExp::semantic.
            if (tb.ty == Tsarray &&
                exp.implicitConvTo(tb.nextOf().arrayOf()) > MATCHnomatch)
            {
                uinteger_t dim1 = (cast(TypeSArray)tb).dim.toInteger();
                uinteger_t dim2 = dim1;
                if (exp.op == TOKarrayliteral)
                {
                    auto ale = cast(ArrayLiteralExp)exp;
                    dim2 = ale.elements ? ale.elements.dim : 0;
                }
                else if (exp.op == TOKslice)
                {
                    Type tx = toStaticArrayType(cast(SliceExp)exp);
                    if (tx)
                        dim2 = (cast(TypeSArray)tx).dim.toInteger();
                }
                else if (ti.ty == Tsarray)
                {
                    dim2 = (cast(TypeSArray)ti).dim.toInteger();
                }
                if (dim1 != dim2)
                {
                    exp.error("mismatched array lengths, %d and %d", cast(int)dim1, cast(int)dim2);
                    return new ErrorInitializer();
                }

                /* Do not call implicitCastTo here to accept:
                 *  int[] fo();
                 *  int[3] a = foo();
                 */
            }
            else
            {
                // In here, exp should match to t here.
                // Therefore don't have to consider block initializing.
                exp = exp.implicitCastTo(sc, t);
            }
        }
    L1:
        if (exp.op == TOKerror)
            return new ErrorInitializer();
        exp = exp.optimize(WANTvalue);
        //printf("-ExpInitializer::semantic(): "); exp.print();
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
        if (e.type.ty == Terror)
            return false;

        if (e.op == TOKnull)
            return false;
        if (e.op == TOKstructliteral)
        {
            StructLiteralExp se = cast(StructLiteralExp)e;
            return arrayHasNonConstPointers(se.elements);
        }
        if (e.op == TOKarrayliteral)
        {
            if (!e.type.nextOf().hasPointers())
                return false;
            ArrayLiteralExp ae = cast(ArrayLiteralExp)e;
            return arrayHasNonConstPointers(ae.elements);
        }
        if (e.op == TOKassocarrayliteral)
        {
            AssocArrayLiteralExp ae = cast(AssocArrayLiteralExp)e;
            if (ae.type.nextOf().hasPointers() && arrayHasNonConstPointers(ae.values))
                return true;
            if ((cast(TypeAArray)ae.type).index.hasPointers())
                return arrayHasNonConstPointers(ae.keys);
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
                    bool ret = arrayHasNonConstPointers(se.elements);
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

    extern (C++) bool arrayHasNonConstPointers(Expressions* elems)
    {
        for (size_t i = 0; i < elems.dim; i++)
        {
            Expression e = (*elems)[i];
            if (e && hasNonConstPointers(e))
                return true;
        }
        return false;
    }
}
