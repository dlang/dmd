/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _init.d)
 */

module ddmd.initsem;

import core.checkedint;

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
import ddmd.expressionsem;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.init;
import ddmd.mtype;
import ddmd.statement;
import ddmd.tokens;
import ddmd.visitor;

alias semantic = ddmd.expressionsem.semantic;
alias semanticY = ddmd.expressionsem.semanticY;

private extern(C++) final class InitializerSemanticVisitor : Visitor
{
    alias visit = super.visit;

    Initializer result;
    Scope* sc;
    Type t;
    NeedInterpret needInterpret;

    this(Scope* sc, Type t, NeedInterpret needInterpret)
    {
        this.sc = sc;
        this.t = t;
        this.needInterpret = needInterpret;
    }

    override void visit(VoidInitializer i)
    {
        i.type = t;
        result = i;
    }

    override void visit(ErrorInitializer i)
    {
        result = i;
    }

    override void visit(StructInitializer i)
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
                error(i.loc, "%s %s has constructors, cannot use { initializers }, use %s( initializers ) instead", sd.kind(), sd.toChars(), sd.toChars());
                result = new ErrorInitializer();
                return;
            }
            sd.size(i.loc);
            if (sd.sizeok != SIZEOKdone)
            {
                result = new ErrorInitializer();
                return;
            }
            size_t nfields = sd.fields.dim - sd.isNested();
            //expandTuples for non-identity arguments?
            auto elements = new Expressions();
            elements.setDim(nfields);
            for (size_t j = 0; j < elements.dim; j++)
                (*elements)[j] = null;
            // Run semantic for explicitly given initializers
            // TODO: this part is slightly different from StructLiteralExp::semantic.
            bool errors = false;
            for (size_t fieldi = 0, j = 0; j < i.field.dim; j++)
            {
                if (Identifier id = i.field[j])
                {
                    Dsymbol s = sd.search(i.loc, id);
                    if (!s)
                    {
                        s = sd.search_correct(id);
                        if (s)
                            error(i.loc, "'%s' is not a member of '%s', did you mean %s '%s'?", id.toChars(), sd.toChars(), s.kind(), s.toChars());
                        else
                            error(i.loc, "'%s' is not a member of '%s'", id.toChars(), sd.toChars());
                        result = new ErrorInitializer();
                        return;
                    }
                    s = s.toAlias();
                    // Find out which field index it is
                    for (fieldi = 0; 1; fieldi++)
                    {
                        if (fieldi >= nfields)
                        {
                            error(i.loc, "%s.%s is not a per-instance initializable field", sd.toChars(), s.toChars());
                            result = new ErrorInitializer();
                            return;
                        }
                        if (s == sd.fields[fieldi])
                            break;
                    }
                }
                else if (fieldi >= nfields)
                {
                    error(i.loc, "too many initializers for %s", sd.toChars());
                    result = new ErrorInitializer();
                    return;
                }
                VarDeclaration vd = sd.fields[fieldi];
                if ((*elements)[fieldi])
                {
                    error(i.loc, "duplicate initializer for field '%s'", vd.toChars());
                    errors = true;
                    continue;
                }
                for (size_t k = 0; k < nfields; k++)
                {
                    VarDeclaration v2 = sd.fields[k];
                    if (vd.isOverlappedWith(v2) && (*elements)[k])
                    {
                        error(i.loc, "overlapping initialization for field %s and %s", v2.toChars(), vd.toChars());
                        errors = true;
                        continue;
                    }
                }
                assert(sc);
                Initializer iz = i.value[j];
                iz = iz.semantic(sc, vd.type.addMod(t.mod), needInterpret);
                Expression ex = iz.initializerToExpression();
                if (ex.op == TOKerror)
                {
                    errors = true;
                    continue;
                }
                i.value[j] = iz;
                (*elements)[fieldi] = doCopyOrMove(sc, ex);
                ++fieldi;
            }
            if (errors)
            {
                result = new ErrorInitializer();
                return;
            }
            auto sle = new StructLiteralExp(i.loc, sd, elements, t);
            if (!sd.fill(i.loc, elements, false))
            {
                result = new ErrorInitializer();
                return;
            }
            sle.type = t;
            auto ie = new ExpInitializer(i.loc, sle);
            result = ie.semantic(sc, t, needInterpret);
            return;
        }
        else if ((t.ty == Tdelegate || t.ty == Tpointer && t.nextOf().ty == Tfunction) && i.value.dim == 0)
        {
            TOK tok = (t.ty == Tdelegate) ? TOKdelegate : TOKfunction;
            /* Rewrite as empty delegate literal { }
             */
            auto parameters = new Parameters();
            Type tf = new TypeFunction(parameters, null, 0, LINKd);
            auto fd = new FuncLiteralDeclaration(i.loc, Loc(), tf, tok, null);
            fd.fbody = new CompoundStatement(i.loc, new Statements());
            fd.endloc = i.loc;
            Expression e = new FuncExp(i.loc, fd);
            auto ie = new ExpInitializer(i.loc, e);
            result = ie.semantic(sc, t, needInterpret);
            return;
        }
        error(i.loc, "a struct is not a valid initializer for a %s", t.toChars());
        result = new ErrorInitializer();
        return;
    }

    override void visit(ArrayInitializer i)
    {
        uint length;
        const(uint) amax = 0x80000000;
        bool errors = false;
        //printf("ArrayInitializer::semantic(%s)\n", t.toChars());
        if (i.sem) // if semantic() already run
        {
            result = i;
            return;
        }
        i.sem = true;
        t = t.toBasetype();
        switch (t.ty)
        {
        case Tsarray:
        case Tarray:
            break;
        case Tvector:
            t = (cast(TypeVector)t).basetype;
            break;
        case Taarray:
        case Tstruct: // consider implicit constructor call
            {
                Expression e;
                // note: MyStruct foo = [1:2, 3:4] is correct code if MyStruct has a this(int[int])
                if (t.ty == Taarray || i.isAssociativeArray())
                    e = i.toAssocArrayLiteral();
                else
                    e = i.initializerToExpression();
                // Bugzilla 13987
                if (!e)
                {
                    error(i.loc, "cannot use array to initialize %s", t.toChars());
                    goto Lerr;
                }
                auto ei = new ExpInitializer(e.loc, e);
                result = ei.semantic(sc, t, needInterpret);
                return;
            }
        case Tpointer:
            if (t.nextOf().ty != Tfunction)
                break;
            goto default;
        default:
            error(i.loc, "cannot use array to initialize %s", t.toChars());
            goto Lerr;
        }
        i.type = t;
        length = 0;
        for (size_t j = 0; j < i.index.dim; j++)
        {
            Expression idx = i.index[j];
            if (idx)
            {
                sc = sc.startCTFE();
                idx = idx.semantic(sc);
                sc = sc.endCTFE();
                idx = idx.ctfeInterpret();
                i.index[j] = idx;
                const uinteger_t idxvalue = idx.toInteger();
                if (idxvalue >= amax)
                {
                    error(i.loc, "array index %llu overflow", ulong(idxvalue));
                    errors = true;
                }
                length = cast(uint)idxvalue;
                if (idx.op == TOKerror)
                    errors = true;
            }
            Initializer val = i.value[j];
            ExpInitializer ei = val.isExpInitializer();
            if (ei && !idx)
                ei.expandTuples = true;
            val = val.semantic(sc, t.nextOf(), needInterpret);
            if (val.isErrorInitializer())
                errors = true;
            ei = val.isExpInitializer();
            // found a tuple, expand it
            if (ei && ei.exp.op == TOKtuple)
            {
                TupleExp te = cast(TupleExp)ei.exp;
                i.index.remove(j);
                i.value.remove(j);
                for (size_t k = 0; k < te.exps.dim; ++k)
                {
                    Expression e = (*te.exps)[k];
                    i.index.insert(j + k, cast(Expression)null);
                    i.value.insert(j + k, new ExpInitializer(e.loc, e));
                }
                j--;
                continue;
            }
            else
            {
                i.value[j] = val;
            }
            length++;
            if (length == 0)
            {
                error(i.loc, "array dimension overflow");
                goto Lerr;
            }
            if (length > i.dim)
                i.dim = length;
        }
        if (t.ty == Tsarray)
        {
            uinteger_t edim = (cast(TypeSArray)t).dim.toInteger();
            if (i.dim > edim)
            {
                error(i.loc, "array initializer has %u elements, but array length is %llu", i.dim, edim);
                goto Lerr;
            }
        }
        if (errors)
            goto Lerr;
        {
            const sz = t.nextOf().size();
            bool overflow;
            const max = mulu(i.dim, sz, overflow);
            if (overflow || max >= amax)
            {
                error(i.loc, "array dimension %llu exceeds max of %llu", ulong(i.dim), ulong(amax / sz));
                goto Lerr;
            }
            result = i;
            return;
        }
    Lerr:
        result = new ErrorInitializer();
    }

    override void visit(ExpInitializer i)
    {
        //printf("ExpInitializer::semantic(%s), type = %s\n", exp.toChars(), t.toChars());
        if (needInterpret)
            sc = sc.startCTFE();
        i.exp = i.exp.semantic(sc);
        i.exp = resolveProperties(sc, i.exp);
        if (needInterpret)
            sc = sc.endCTFE();
        if (i.exp.op == TOKerror)
        {
            result = new ErrorInitializer();
            return;
        }
        uint olderrors = global.errors;
        if (needInterpret)
        {
            // If the result will be implicitly cast, move the cast into CTFE
            // to avoid premature truncation of polysemous types.
            // eg real [] x = [1.1, 2.2]; should use real precision.
            if (i.exp.implicitConvTo(t))
            {
                i.exp = i.exp.implicitCastTo(sc, t);
            }
            if (!global.gag && olderrors != global.errors)
            {
                result = i;
                return;
            }
            i.exp = i.exp.ctfeInterpret();
        }
        else
        {
            i.exp = i.exp.optimize(WANTvalue);
        }
        if (!global.gag && olderrors != global.errors)
        {
            result = i; // Failed, suppress duplicate error messages
            return;
        }
        if (i.exp.type.ty == Ttuple && (cast(TypeTuple)i.exp.type).arguments.dim == 0)
        {
            Type et = i.exp.type;
            i.exp = new TupleExp(i.exp.loc, new Expressions());
            i.exp.type = et;
        }
        if (i.exp.op == TOKtype)
        {
            i.exp.error("initializer must be an expression, not '%s'", i.exp.toChars());
            result = new ErrorInitializer();
            return;
        }
        // Make sure all pointers are constants
        if (needInterpret && hasNonConstPointers(i.exp))
        {
            i.exp.error("cannot use non-constant CTFE pointer in an initializer '%s'", i.exp.toChars());
            result = new ErrorInitializer();
            return;
        }
        Type tb = t.toBasetype();
        Type ti = i.exp.type.toBasetype();
        if (i.exp.op == TOKtuple && i.expandTuples && !i.exp.implicitConvTo(t))
        {
            result = new ExpInitializer(i.loc, i.exp);
            return;
        }
        /* Look for case of initializing a static array with a too-short
         * string literal, such as:
         *  char[5] foo = "abc";
         * Allow this by doing an explicit cast, which will lengthen the string
         * literal.
         */
        if (i.exp.op == TOKstring && tb.ty == Tsarray)
        {
            StringExp se = cast(StringExp)i.exp;
            Type typeb = se.type.toBasetype();
            TY tynto = tb.nextOf().ty;
            if (!se.committed &&
                (typeb.ty == Tarray || typeb.ty == Tsarray) &&
                (tynto == Tchar || tynto == Twchar || tynto == Tdchar) &&
                se.numberOfCodeUnits(tynto) < (cast(TypeSArray)tb).dim.toInteger())
            {
                i.exp = se.castTo(sc, t);
                goto L1;
            }
        }
        // Look for implicit constructor call
        if (tb.ty == Tstruct && !(ti.ty == Tstruct && tb.toDsymbol(sc) == ti.toDsymbol(sc)) && !i.exp.implicitConvTo(t))
        {
            StructDeclaration sd = (cast(TypeStruct)tb).sym;
            if (sd.ctor)
            {
                // Rewrite as S().ctor(exp)
                Expression e;
                e = new StructLiteralExp(i.loc, sd, null);
                e = new DotIdExp(i.loc, e, Id.ctor);
                e = new CallExp(i.loc, e, i.exp);
                e = e.semantic(sc);
                if (needInterpret)
                    i.exp = e.ctfeInterpret();
                else
                    i.exp = e.optimize(WANTvalue);
            }
        }
        // Look for the case of statically initializing an array
        // with a single member.
        if (tb.ty == Tsarray && !tb.nextOf().equals(ti.toBasetype().nextOf()) && i.exp.implicitConvTo(tb.nextOf()))
        {
            /* If the variable is not actually used in compile time, array creation is
             * redundant. So delay it until invocation of toExpression() or toDt().
             */
            t = tb.nextOf();
        }
        if (i.exp.implicitConvTo(t))
        {
            i.exp = i.exp.implicitCastTo(sc, t);
        }
        else
        {
            // Look for mismatch of compile-time known length to emit
            // better diagnostic message, as same as AssignExp::semantic.
            if (tb.ty == Tsarray && i.exp.implicitConvTo(tb.nextOf().arrayOf()) > MATCHnomatch)
            {
                uinteger_t dim1 = (cast(TypeSArray)tb).dim.toInteger();
                uinteger_t dim2 = dim1;
                if (i.exp.op == TOKarrayliteral)
                {
                    ArrayLiteralExp ale = cast(ArrayLiteralExp)i.exp;
                    dim2 = ale.elements ? ale.elements.dim : 0;
                }
                else if (i.exp.op == TOKslice)
                {
                    Type tx = toStaticArrayType(cast(SliceExp)i.exp);
                    if (tx)
                        dim2 = (cast(TypeSArray)tx).dim.toInteger();
                }
                if (dim1 != dim2)
                {
                    i.exp.error("mismatched array lengths, %d and %d", cast(int)dim1, cast(int)dim2);
                    i.exp = new ErrorExp();
                }
            }
            i.exp = i.exp.implicitCastTo(sc, t);
        }
    L1:
        if (i.exp.op == TOKerror)
        {
            result = i;
            return;
        }
        if (needInterpret)
            i.exp = i.exp.ctfeInterpret();
        else
            i.exp = i.exp.optimize(WANTvalue);
        //printf("-ExpInitializer::semantic(): "); exp.print();
        result = i;
    }
}

// Performs semantic analisys on Initializer AST nodes
extern (C++) Initializer semantic(Initializer init, Scope* sc, Type t, NeedInterpret needInterpret)
{
    scope v = new InitializerSemanticVisitor(sc, t, needInterpret);
    init.accept(v);
    return v.result;
}

private extern(C++) final class InferTypeVisitor : Visitor
{
    alias visit = super.visit;

    Initializer result;
    Scope* sc;

    this(Scope* sc)
    {
        this.sc = sc;
    }

    override void visit(VoidInitializer i)
    {
        error(i.loc, "cannot infer type from void initializer");
        result = new ErrorInitializer();
    }

    override void visit(ErrorInitializer i)
    {
        result = i;
    }

    override void visit(StructInitializer i)
    {
        error(i.loc, "cannot infer type from struct initializer");
        result = new ErrorInitializer();
    }

    override void visit(ArrayInitializer init)
    {
        //printf("ArrayInitializer::inferType() %s\n", toChars());
        Expressions* keys = null;
        Expressions* values;
        if (init.isAssociativeArray())
        {
            keys = new Expressions();
            keys.setDim(init.value.dim);
            values = new Expressions();
            values.setDim(init.value.dim);
            for (size_t i = 0; i < init.value.dim; i++)
            {
                Expression e = init.index[i];
                if (!e)
                    goto Lno;
                (*keys)[i] = e;
                Initializer iz = init.value[i];
                if (!iz)
                    goto Lno;
                iz = iz.inferType(sc);
                if (iz.isErrorInitializer())
                {
                    result = iz;
                    return;
                }
                assert(iz.isExpInitializer());
                (*values)[i] = (cast(ExpInitializer)iz).exp;
                assert((*values)[i].op != TOKerror);
            }
            Expression e = new AssocArrayLiteralExp(init.loc, keys, values);
            auto ei = new ExpInitializer(init.loc, e);
            result = ei.inferType(sc);
            return;
        }
        else
        {
            auto elements = new Expressions();
            elements.setDim(init.value.dim);
            elements.zero();
            for (size_t i = 0; i < init.value.dim; i++)
            {
                assert(!init.index[i]); // already asserted by isAssociativeArray()
                Initializer iz = init.value[i];
                if (!iz)
                    goto Lno;
                iz = iz.inferType(sc);
                if (iz.isErrorInitializer())
                {
                    result = iz;
                    return;
                }
                assert(iz.isExpInitializer());
                (*elements)[i] = (cast(ExpInitializer)iz).exp;
                assert((*elements)[i].op != TOKerror);
            }
            Expression e = new ArrayLiteralExp(init.loc, elements);
            auto ei = new ExpInitializer(init.loc, e);
            result = ei.inferType(sc);
            return;
        }
    Lno:
        if (keys)
        {
            error(init.loc, "not an associative array initializer");
        }
        else
        {
            error(init.loc, "cannot infer type from array initializer");
        }
        result = new ErrorInitializer();
    }

    override void visit(ExpInitializer init)
    {
        //printf("ExpInitializer::inferType() %s\n", toChars());
        init.exp = init.exp.semantic(sc);
        init.exp = resolveProperties(sc, init.exp);
        if (init.exp.op == TOKscope)
        {
            ScopeExp se = cast(ScopeExp)init.exp;
            TemplateInstance ti = se.sds.isTemplateInstance();
            if (ti && ti.semanticRun == PASSsemantic && !ti.aliasdecl)
                se.error("cannot infer type from %s %s, possible circular dependency", se.sds.kind(), se.toChars());
            else
                se.error("cannot infer type from %s %s", se.sds.kind(), se.toChars());
            result = new ErrorInitializer();
            return;
        }

        // Give error for overloaded function addresses
        bool hasOverloads;
        if (auto f = isFuncAddress(init.exp, &hasOverloads))
        {
            if (f.checkForwardRef(init.loc))
            {
                result = new ErrorInitializer();
                return;
            }
            if (hasOverloads && !f.isUnique())
            {
                init.exp.error("cannot infer type from overloaded function symbol %s", init.exp.toChars());
                result = new ErrorInitializer();
                return;
            }
        }
        if (init.exp.op == TOKaddress)
        {
            AddrExp ae = cast(AddrExp)init.exp;
            if (ae.e1.op == TOKoverloadset)
            {
                init.exp.error("cannot infer type from overloaded function symbol %s", init.exp.toChars());
                result = new ErrorInitializer();
                return;
            }
        }
        if (init.exp.op == TOKerror)
        {
            result = new ErrorInitializer();
            return;
        }
        if (!init.exp.type)
        {
            result = new ErrorInitializer();
            return;
        }
        result = init;
    }
}

/* Translates to an expression to infer type.
 * Returns ExpInitializer or ErrorInitializer.
 */
extern (C++) Initializer inferType(Initializer init, Scope* sc)
{
    scope v = new InferTypeVisitor(sc);
    init.accept(v);
    return v.result;
}

private extern(C++) final class InitToExpressionVisitor : Visitor
{
    alias visit = super.visit;

    Expression result;
    Type itype;

    this(Type itype)
    {
        this.itype = itype;
    }

    override void visit(VoidInitializer)
    {
        result = null;
    }

    override void visit(ErrorInitializer)
    {
        result = new ErrorExp();
    }

    /***************************************
     * This works by transforming a struct initializer into
     * a struct literal. In the future, the two should be the
     * same thing.
     */
    override void visit(StructInitializer)
    {
        // cannot convert to an expression without target 'ad'
        result = null;
    }

    /********************************
     * If possible, convert array initializer to array literal.
     * Otherwise return NULL.
     */
    override void visit(ArrayInitializer init)
    {
        //printf("ArrayInitializer::toExpression(), dim = %d\n", dim);
        //static int i; if (++i == 2) assert(0);
        Expressions* elements;
        uint edim;
        const(uint) amax = 0x80000000;
        Type t = null;
        if (init.type)
        {
            if (init.type == Type.terror)
            {
                result = new ErrorExp();
                return;
            }
            t = init.type.toBasetype();
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
                edim = init.dim;
                break;

            default:
                assert(0);
            }
        }
        else
        {
            edim = cast(uint)init.value.dim;
            for (size_t i = 0, j = 0; i < init.value.dim; i++, j++)
            {
                if (init.index[i])
                {
                    if (init.index[i].op == TOKint64)
                    {
                        const uinteger_t idxval = init.index[i].toInteger();
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
        for (size_t i = 0, j = 0; i < init.value.dim; i++, j++)
        {
            if (init.index[i])
                j = cast(size_t)init.index[i].toInteger();
            assert(j < edim);
            Initializer iz = init.value[i];
            if (!iz)
                goto Lno;
            Expression ex = iz.initializerToExpression();
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
                    if (!init.type)
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
                {
                    result = e;
                    return;
                }
            }

            Expression e = new ArrayLiteralExp(init.loc, elements);
            e.type = init.type;
            result = e;
            return;
        }
    Lno:
        result = null;
    }

    override void visit(ExpInitializer i)
    {
        if (itype)
        {
            //printf("ExpInitializer::toExpression(t = %s) exp = %s\n", t.toChars(), exp.toChars());
            Type tb = itype.toBasetype();
            Expression e = (i.exp.op == TOKconstruct || i.exp.op == TOKblit) ? (cast(AssignExp)i.exp).e2 : i.exp;
            if (tb.ty == Tsarray && e.implicitConvTo(tb.nextOf()))
            {
                TypeSArray tsa = cast(TypeSArray)tb;
                size_t d = cast(size_t)tsa.dim.toInteger();
                auto elements = new Expressions();
                elements.setDim(d);
                for (size_t j = 0; j < d; j++)
                    (*elements)[j] = e;
                auto ae = new ArrayLiteralExp(e.loc, elements);
                ae.type = itype;
                result = ae;
                return;
            }
        }
        result = i.exp;
    }
}

// Converts an initializer to an expression.
public extern (C++) Expression initializerToExpression(Initializer i, Type t = null)
{
    scope v = new InitToExpressionVisitor(t);
    i.accept(v);
    return v.result;
}
