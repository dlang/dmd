/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/initsem.d, _initsem.d)
 * Documentation:  https://dlang.org/phobos/dmd_initsem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/initsem.d
 */

module dmd.initsem;

import core.stdc.stdio;
import core.checkedint;

import dmd.aggregate;
import dmd.aliasthis;
import dmd.arraytypes;
import dmd.dcast;
import dmd.declaration;
import dmd.dscope;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.errors;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.mtype;
import dmd.statement;
import dmd.target;
import dmd.tokens;
import dmd.typesem;

/********************************
 * If possible, convert array initializer to associative array initializer.
 *
 *  Params:
 *     ai = array initializer to be converted
 *
 *  Returns:
 *     The converted associative array initializer or ErrorExp if `ai`
 *     is not an associative array initializer.
 */
Expression toAssocArrayLiteral(ArrayInitializer ai)
{
    Expression e;
    //printf("ArrayInitializer::toAssocArrayInitializer()\n");
    //static int i; if (++i == 2) assert(0);
    const dim = ai.value.dim;
    auto keys = new Expressions(dim);
    auto values = new Expressions(dim);
    for (size_t i = 0; i < dim; i++)
    {
        e = ai.index[i];
        if (!e)
            goto Lno;
        (*keys)[i] = e;
        Initializer iz = ai.value[i];
        if (!iz)
            goto Lno;
        e = iz.initializerToExpression();
        if (!e)
            goto Lno;
        (*values)[i] = e;
    }
    e = new AssocArrayLiteralExp(ai.loc, keys, values);
    return e;
Lno:
    error(ai.loc, "not an associative array initializer");
    return new ErrorExp();
}

/******************************************
 * Perform semantic analysis on init.
 * Params:
 *      init = Initializer AST node
 *      sc = context
 *      t = type that the initializer needs to become
 *      needInterpret = if CTFE needs to be run on this,
 *                      such as if it is the initializer for a const declaration
 * Returns:
 *      `Initializer` with completed semantic analysis, `ErrorInitializer` if errors
 *      were encountered
 */
extern(C++) Initializer initializerSemantic(Initializer init, Scope* sc, Type t, NeedInterpret needInterpret)
{
    Initializer visitVoid(VoidInitializer i)
    {
        i.type = t;
        return i;
    }

    Initializer visitError(ErrorInitializer i)
    {
        return i;
    }

    Initializer visitStruct(StructInitializer i)
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
                error(i.loc, "%s `%s` has constructors, cannot use `{ initializers }`, use `%s( initializers )` instead", sd.kind(), sd.toChars(), sd.toChars());
                return new ErrorInitializer();
            }
            sd.size(i.loc);
            if (sd.sizeok != Sizeok.done)
            {
                return new ErrorInitializer();
            }
            size_t nfields = sd.fields.dim - sd.isNested();
            //expandTuples for non-identity arguments?
            auto elements = new Expressions(nfields);
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
                        Loc initLoc = i.value[j].loc;
                        if (s)
                            error(initLoc, "`%s` is not a member of `%s`, did you mean %s `%s`?", id.toChars(), sd.toChars(), s.kind(), s.toChars());
                        else
                            error(initLoc, "`%s` is not a member of `%s`", id.toChars(), sd.toChars());
                        return new ErrorInitializer();
                    }
                    s = s.toAlias();
                    // Find out which field index it is
                    for (fieldi = 0; 1; fieldi++)
                    {
                        if (fieldi >= nfields)
                        {
                            error(i.loc, "`%s.%s` is not a per-instance initializable field", sd.toChars(), s.toChars());
                            return new ErrorInitializer();
                        }
                        if (s == sd.fields[fieldi])
                            break;
                    }
                }
                else if (fieldi >= nfields)
                {
                    error(i.loc, "too many initializers for `%s`", sd.toChars());
                    return new ErrorInitializer();
                }
                VarDeclaration vd = sd.fields[fieldi];
                if ((*elements)[fieldi])
                {
                    error(i.loc, "duplicate initializer for field `%s`", vd.toChars());
                    errors = true;
                    continue;
                }
                if (vd.type.hasPointers)
                {
                    if ((t.alignment() < target.ptrsize ||
                         (vd.offset & (target.ptrsize - 1))) &&
                        sc.func && sc.func.setUnsafe())
                    {
                        error(i.loc, "field `%s.%s` cannot assign to misaligned pointers in `@safe` code",
                            sd.toChars(), vd.toChars());
                        errors = true;
                    }
                }
                for (size_t k = 0; k < nfields; k++)
                {
                    VarDeclaration v2 = sd.fields[k];
                    if (vd.isOverlappedWith(v2) && (*elements)[k])
                    {
                        error(i.loc, "overlapping initialization for field `%s` and `%s`", v2.toChars(), vd.toChars());
                        errors = true;
                        continue;
                    }
                }
                assert(sc);
                Initializer iz = i.value[j];
                iz = iz.initializerSemantic(sc, vd.type.addMod(t.mod), needInterpret);
                Expression ex = iz.initializerToExpression();
                if (ex.op == TOK.error)
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
                return new ErrorInitializer();
            }
            auto sle = new StructLiteralExp(i.loc, sd, elements, t);
            if (!sd.fill(i.loc, elements, false))
            {
                return new ErrorInitializer();
            }
            sle.type = t;
            auto ie = new ExpInitializer(i.loc, sle);
            return ie.initializerSemantic(sc, t, needInterpret);
        }
        else if ((t.ty == Tdelegate || t.ty == Tpointer && t.nextOf().ty == Tfunction) && i.value.dim == 0)
        {
            TOK tok = (t.ty == Tdelegate) ? TOK.delegate_ : TOK.function_;
            /* Rewrite as empty delegate literal { }
             */
            Type tf = new TypeFunction(ParameterList(), null, LINK.d);
            auto fd = new FuncLiteralDeclaration(i.loc, Loc.initial, tf, tok, null);
            fd.fbody = new CompoundStatement(i.loc, new Statements());
            fd.endloc = i.loc;
            Expression e = new FuncExp(i.loc, fd);
            auto ie = new ExpInitializer(i.loc, e);
            return ie.initializerSemantic(sc, t, needInterpret);
        }
        error(i.loc, "a struct is not a valid initializer for a `%s`", t.toChars());
        return new ErrorInitializer();
    }

    Initializer visitArray(ArrayInitializer i)
    {
        uint length;
        const(uint) amax = 0x80000000;
        bool errors = false;
        //printf("ArrayInitializer::semantic(%s)\n", t.toChars());
        if (i.sem) // if semantic() already run
        {
            return i;
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
                    error(i.loc, "cannot use array to initialize `%s`", t.toChars());
                    goto Lerr;
                }
                auto ei = new ExpInitializer(e.loc, e);
                return ei.initializerSemantic(sc, t, needInterpret);
            }
        case Tpointer:
            if (t.nextOf().ty != Tfunction)
                break;
            goto default;
        default:
            error(i.loc, "cannot use array to initialize `%s`", t.toChars());
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
                idx = idx.expressionSemantic(sc);
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
                if (idx.op == TOK.error)
                    errors = true;
            }
            Initializer val = i.value[j];
            ExpInitializer ei = val.isExpInitializer();
            if (ei && !idx)
                ei.expandTuples = true;
            val = val.initializerSemantic(sc, t.nextOf(), needInterpret);
            if (val.isErrorInitializer())
                errors = true;
            ei = val.isExpInitializer();
            // found a tuple, expand it
            if (ei && ei.exp.op == TOK.tuple)
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
            return i;
        }
    Lerr:
        return new ErrorInitializer();
    }

    Initializer visitExp(ExpInitializer i)
    {
        //printf("ExpInitializer::semantic(%s), type = %s\n", i.exp.toChars(), t.toChars());
        if (needInterpret)
            sc = sc.startCTFE();
        i.exp = i.exp.expressionSemantic(sc);
        i.exp = resolveProperties(sc, i.exp);
        if (needInterpret)
            sc = sc.endCTFE();
        if (i.exp.op == TOK.error)
        {
            return new ErrorInitializer();
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
                return i;
            }
            i.exp = i.exp.ctfeInterpret();
            if (i.exp.op == TOK.voidExpression)
                error(i.loc, "variables cannot be initialized with an expression of type `void`. Use `void` initialization instead.");
        }
        else
        {
            i.exp = i.exp.optimize(WANTvalue);
        }
        if (!global.gag && olderrors != global.errors)
        {
            return i; // Failed, suppress duplicate error messages
        }
        if (i.exp.type.ty == Ttuple && (cast(TypeTuple)i.exp.type).arguments.dim == 0)
        {
            Type et = i.exp.type;
            i.exp = new TupleExp(i.exp.loc, new Expressions());
            i.exp.type = et;
        }
        if (i.exp.op == TOK.type)
        {
            i.exp.error("initializer must be an expression, not `%s`", i.exp.toChars());
            return new ErrorInitializer();
        }
        // Make sure all pointers are constants
        if (needInterpret && hasNonConstPointers(i.exp))
        {
            i.exp.error("cannot use non-constant CTFE pointer in an initializer `%s`", i.exp.toChars());
            return new ErrorInitializer();
        }
        Type tb = t.toBasetype();
        Type ti = i.exp.type.toBasetype();
        if (i.exp.op == TOK.tuple && i.expandTuples && !i.exp.implicitConvTo(t))
        {
            return new ExpInitializer(i.loc, i.exp);
        }
        /* Look for case of initializing a static array with a too-short
         * string literal, such as:
         *  char[5] foo = "abc";
         * Allow this by doing an explicit cast, which will lengthen the string
         * literal.
         */
        if (i.exp.op == TOK.string_ && tb.ty == Tsarray)
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
                e = e.expressionSemantic(sc);
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
            if (tb.ty == Tsarray && i.exp.implicitConvTo(tb.nextOf().arrayOf()) > MATCH.nomatch)
            {
                uinteger_t dim1 = (cast(TypeSArray)tb).dim.toInteger();
                uinteger_t dim2 = dim1;
                if (i.exp.op == TOK.arrayLiteral)
                {
                    ArrayLiteralExp ale = cast(ArrayLiteralExp)i.exp;
                    dim2 = ale.elements ? ale.elements.dim : 0;
                }
                else if (i.exp.op == TOK.slice)
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
        if (i.exp.op == TOK.error)
        {
            return i;
        }
        if (needInterpret)
            i.exp = i.exp.ctfeInterpret();
        else
            i.exp = i.exp.optimize(WANTvalue);
        //printf("-ExpInitializer::semantic(): "); i.exp.print();
        return i;
    }

    final switch (init.kind)
    {
        case InitKind.void_:   return visitVoid  (cast(  VoidInitializer)init);
        case InitKind.error:   return visitError (cast( ErrorInitializer)init);
        case InitKind.struct_: return visitStruct(cast(StructInitializer)init);
        case InitKind.array:   return visitArray (cast( ArrayInitializer)init);
        case InitKind.exp:     return visitExp   (cast(   ExpInitializer)init);
    }
}

/***********************
 * Translate init to an `Expression` in order to infer the type.
 * Params:
 *      init = `Initializer` AST node
 *      sc = context
 * Returns:
 *      an equivalent `ExpInitializer` if successful, or `ErrorInitializer` if it cannot be translated
 */
Initializer inferType(Initializer init, Scope* sc)
{
    Initializer visitVoid(VoidInitializer i)
    {
        error(i.loc, "cannot infer type from void initializer");
        return new ErrorInitializer();
    }

    Initializer visitError(ErrorInitializer i)
    {
        return i;
    }

    Initializer visitStruct(StructInitializer i)
    {
        error(i.loc, "cannot infer type from struct initializer");
        return new ErrorInitializer();
    }

    Initializer visitArray(ArrayInitializer init)
    {
        //printf("ArrayInitializer::inferType() %s\n", toChars());
        Expressions* keys = null;
        Expressions* values;
        if (init.isAssociativeArray())
        {
            keys = new Expressions(init.value.dim);
            values = new Expressions(init.value.dim);
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
                    return iz;
                }
                assert(iz.isExpInitializer());
                (*values)[i] = (cast(ExpInitializer)iz).exp;
                assert((*values)[i].op != TOK.error);
            }
            Expression e = new AssocArrayLiteralExp(init.loc, keys, values);
            auto ei = new ExpInitializer(init.loc, e);
            return ei.inferType(sc);
        }
        else
        {
            auto elements = new Expressions(init.value.dim);
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
                    return iz;
                }
                assert(iz.isExpInitializer());
                (*elements)[i] = (cast(ExpInitializer)iz).exp;
                assert((*elements)[i].op != TOK.error);
            }
            Expression e = new ArrayLiteralExp(init.loc, null, elements);
            auto ei = new ExpInitializer(init.loc, e);
            return ei.inferType(sc);
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
        return new ErrorInitializer();
    }

    Initializer visitExp(ExpInitializer init)
    {
        //printf("ExpInitializer::inferType() %s\n", toChars());
        init.exp = init.exp.expressionSemantic(sc);

        // for static alias this: https://issues.dlang.org/show_bug.cgi?id=17684
        if (init.exp.op == TOK.type)
            init.exp = resolveAliasThis(sc, init.exp);

        init.exp = resolveProperties(sc, init.exp);
        if (init.exp.op == TOK.scope_)
        {
            ScopeExp se = cast(ScopeExp)init.exp;
            TemplateInstance ti = se.sds.isTemplateInstance();
            if (ti && ti.semanticRun == PASS.semantic && !ti.aliasdecl)
                se.error("cannot infer type from %s `%s`, possible circular dependency", se.sds.kind(), se.toChars());
            else
                se.error("cannot infer type from %s `%s`", se.sds.kind(), se.toChars());
            return new ErrorInitializer();
        }

        // Give error for overloaded function addresses
        bool hasOverloads;
        if (auto f = isFuncAddress(init.exp, &hasOverloads))
        {
            if (f.checkForwardRef(init.loc))
            {
                return new ErrorInitializer();
            }
            if (hasOverloads && !f.isUnique())
            {
                init.exp.error("cannot infer type from overloaded function symbol `%s`", init.exp.toChars());
                return new ErrorInitializer();
            }
        }
        if (init.exp.op == TOK.address)
        {
            AddrExp ae = cast(AddrExp)init.exp;
            if (ae.e1.op == TOK.overloadSet)
            {
                init.exp.error("cannot infer type from overloaded function symbol `%s`", init.exp.toChars());
                return new ErrorInitializer();
            }
        }
        if (init.exp.op == TOK.error)
        {
            return new ErrorInitializer();
        }
        if (!init.exp.type)
        {
            return new ErrorInitializer();
        }
        return init;
    }

    final switch (init.kind)
    {
        case InitKind.void_:   return visitVoid  (cast(  VoidInitializer)init);
        case InitKind.error:   return visitError (cast( ErrorInitializer)init);
        case InitKind.struct_: return visitStruct(cast(StructInitializer)init);
        case InitKind.array:   return visitArray (cast( ArrayInitializer)init);
        case InitKind.exp:     return visitExp   (cast(   ExpInitializer)init);
    }
}

/***********************
 * Translate init to an `Expression`.
 * Params:
 *      init = `Initializer` AST node
 *      itype = if not `null`, type to coerce expression to
 * Returns:
 *      `Expression` created, `null` if cannot, `ErrorExp` for other errors
 */
extern (C++) Expression initializerToExpression(Initializer init, Type itype = null)
{
    Expression visitVoid(VoidInitializer)
    {
        return null;
    }

    Expression visitError(ErrorInitializer)
    {
        return new ErrorExp();
    }

    /***************************************
     * This works by transforming a struct initializer into
     * a struct literal. In the future, the two should be the
     * same thing.
     */
    Expression visitStruct(StructInitializer)
    {
        // cannot convert to an expression without target 'ad'
        return null;
    }

    /********************************
     * If possible, convert array initializer to array literal.
     * Otherwise return NULL.
     */
    Expression visitArray(ArrayInitializer init)
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
                return new ErrorExp();
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
                    if (init.index[i].op == TOK.int64)
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
        elements = new Expressions(edim);
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
                        _init = (cast(TypeNext)t).next.defaultInit(Loc.initial);
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
                            auto elements2 = new Expressions(dim);
                            foreach (ref e2; *elements2)
                                e2 = e;
                            e = new ArrayLiteralExp(e.loc, tn, elements2);
                        }
                    }
                }
            }

            /* If any elements are errors, then the whole thing is an error
             */
            for (size_t i = 0; i < edim; i++)
            {
                Expression e = (*elements)[i];
                if (e.op == TOK.error)
                {
                    return e;
                }
            }

            Expression e = new ArrayLiteralExp(init.loc, init.type, elements);
            return e;
        }
    Lno:
        return null;
    }

    Expression visitExp(ExpInitializer i)
    {
        if (itype)
        {
            //printf("ExpInitializer::toExpression(t = %s) exp = %s\n", itype.toChars(), i.exp.toChars());
            Type tb = itype.toBasetype();
            Expression e = (i.exp.op == TOK.construct || i.exp.op == TOK.blit) ? (cast(AssignExp)i.exp).e2 : i.exp;
            if (tb.ty == Tsarray && e.implicitConvTo(tb.nextOf()))
            {
                TypeSArray tsa = cast(TypeSArray)tb;
                size_t d = cast(size_t)tsa.dim.toInteger();
                auto elements = new Expressions(d);
                for (size_t j = 0; j < d; j++)
                    (*elements)[j] = e;
                auto ae = new ArrayLiteralExp(e.loc, itype, elements);
                return ae;
            }
        }
        return i.exp;
    }


    final switch (init.kind)
    {
        case InitKind.void_:   return visitVoid  (cast(  VoidInitializer)init);
        case InitKind.error:   return visitError (cast( ErrorInitializer)init);
        case InitKind.struct_: return visitStruct(cast(StructInitializer)init);
        case InitKind.array:   return visitArray (cast( ArrayInitializer)init);
        case InitKind.exp:     return visitExp   (cast(   ExpInitializer)init);
    }
}
