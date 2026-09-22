/**
 * Semantic analysis of initializers.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/initsem.d, _initsem.d)
 * Documentation:  https://dlang.org/phobos/dmd_initsem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/initsem.d
 */

module dmd.initsem;

import core.stdc.stdio;
import core.checkedint;

import dmd.arraytypes;
import dmd.astcodegen : ASTCodegen;
import dmd.astenums;
import dmd.dcast;
import dmd.declaration;
import dmd.dinterpret;
import dmd.dscope;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dtemplate;
import dmd.errorsink;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.funcsem;
import dmd.globals;
import dmd.hdrgen;
import dmd.id;
import dmd.identifier;
import dmd.importc;
import dmd.init;
import dmd.location;
import dmd.mtype;
import dmd.opover;
import dmd.optimize;
import dmd.safe : setUnsafe;
import dmd.statement;
import dmd.target;
import dmd.tokens;
import dmd.typesem;


/********************************
 * int[3] a = [1: 2, 5];
 */
Expression indexedToArrayLiteral(AssocArrayLiteralExp e, Scope* sc, Type expectedType)
{
    auto eSink = global.errorSink;
    auto elements = new Expressions();
    size_t j = 0;
    foreach (i, k; *e.keys)
    {
        if (k)
        {
            k = k.expressionSemantic(sc);
            k = resolveProperties(sc, k);
            k = k.implicitCastTo(sc, Type.tsize_t);
            k = k.ctfeInterpret();
            if (k.isErrorExp())
                return k;
            auto ik = k.isIntegerExp();
            if (!ik)
            {
                eSink.error(k.loc, "array index `%s` is not a constant integer", k.toErrMsg());
                return ErrorExp.get();
            }
            const idx = ik.getInteger();
            if (idx >= 0x8000_0000)
            {
                eSink.error(k.loc, "array index %llu overflow", cast(ulong)idx);
                return ErrorExp.get();
            }
            j = cast(size_t)idx;
        }
        if (j >= elements.length)
            elements.insert(elements.length, j + 1 - elements.length, null);
        else if ((*elements)[j] && !sc.inCfile)
        {
            eSink.error((*e.values)[i].loc, "duplicate initializations for index `%d`", cast(int)j);
            return ErrorExp.get();
        }
        (*elements)[j] = (*e.values)[i];
        ++j;
    }
    auto ale = new ArrayLiteralExp(e.loc, null, elements);
    sc.expectedType = expectedType;
    return ale.expressionSemantic(sc);
}

/******************************************
 * Perform semantic analysis on the initializer `init` of a variable of type `tx`.
 * Params:
 *      init = initializer expression
 *      sc = context
 *      tx = type that the initializer needs to become. If tx is an incomplete
 *           type and the initializer completes it, it is updated to be the
 *           complete type. ImportC has incomplete types
 *      needInterpret = if CTFE needs to be run on this,
 *                      such as if it is the initializer for a const declaration
 * Returns:
 *      the initializer converted to type `tx`, `ErrorExp` if errors were encountered
 */
Expression initializerSemantic(Expression init, Scope* sc, ref Type tx, NeedInterpret needInterpret)
{
    //printf("initializerSemantic() tx: %p %s\n", tx, tx.toChars());
    auto eSink = global.errorSink;
    Type t = tx;
    if (init.isVoidInitializer() || init.isErrorExp())
        return init;

    //printf("initializerSemantic(%s), type = %s\n", init.toChars(), t.toChars());
    if (needInterpret)
        sc = sc.startCTFE();
    sc.expectedType = t;
    Expression exp = init.expressionSemantic(sc);
    exp = resolveProperties(sc, exp);
    if (needInterpret)
        sc = sc.endCTFE();
    if (exp.op == EXP.error)
        return exp;
    if (exp.type && exp.type.ty == Terror)
        return ErrorExp.get();
    const olderrors = global.errors;

    /* ImportC: convert arrays to pointers, functions to pointers to functions
     */
    Type tb = t.toBasetype();
    if (tb.isTypePointer())
        exp = exp.arrayFuncConv(sc);

    /* enum int4 v = [1, 2, 3, 4];   // typeof(v) is int[4]
     */
    if (auto tv = tb.isTypeVector())
    {
        if (exp.isArrayLiteralExp() && exp.type.equals(tv.basetype))
        {
            t = tv.basetype;
            tb = t;
        }
    }

    /* Save the expression before ctfe
     * Otherwise the error message would contain for example "&[0][0]" instead of "new int"
     * Regression: https://issues.dlang.org/show_bug.cgi?id=21687
     */
    Expression currExp = exp;
    if (needInterpret)
    {
        // If the result will be implicitly cast, move the cast into CTFE
        // to avoid premature truncation of polysemous types.
        // eg real [] x = [1.1, 2.2]; should use real precision.
        if (exp.implicitConvTo(t) && !sc.inCfile)
        {
            exp = exp.implicitCastTo(sc, t);
        }
        if (!global.gag && olderrors != global.errors)
        {
            return exp;
        }
        if (sc.inCfile)
        {
            /* the interpreter turns (char*)"string" into &"string"[0] which then
             * it cannot interpret. Resolve that case by doing optimize() first
             */
            exp = cInterpretElements(exp);
            needInterpret = NeedInterpret.INITnointerpret;
        }
        if (needInterpret)
            exp = exp.ctfeInterpret();
        if (exp.op == EXP.voidExpression)
        {
            eSink.error(init.loc, "variables cannot be initialized with an expression of type `void`");
            eSink.errorSupplemental(init.loc, "only `= void;` is allowed, which prevents default initialization");
        }
    }
    else
    {
        exp = exp.optimize(WANTvalue);
    }

    if (!global.gag && olderrors != global.errors)
    {
        return exp; // Failed, suppress duplicate error messages
    }
    if (exp.type.isTypeTuple() && exp.type.isTypeTuple().arguments.length == 0)
    {
        Type et = exp.type;
        exp = new TupleExp(exp.loc, new Expressions());
        exp.type = et;
    }
    if (exp.op == EXP.type)
        return typeAsInitializerError(exp, init.loc);
    // Make sure all pointers are constants
    if (needInterpret && hasNonConstPointers(exp))
    {
        eSink.error(exp.loc, "cannot use non-constant CTFE pointer in an initializer `%s`", currExp.toErrMsg());
        return ErrorExp.get();
    }
    Type ti = exp.type.toBasetype();
    /* Look for case of initializing a static array with a too-short
     * string literal, such as:
     *  char[5] foo = "abc";
     * Allow this by doing an explicit cast, which will lengthen the string
     * literal.
     */
    if (exp.op == EXP.string_ && tb.ty == Tsarray)
    {
        StringExp se = exp.isStringExp();
        Type typeb = se.type.toBasetype();
        TY tynto = tb.nextOf().ty;
        if (!se.committed &&
            typeb.isStaticOrDynamicArray() && tynto.isSomeChar)
        {
            string str;
            size_t len = se.numberOfCodeUnits(tynto, str);
            if (str)
                eSink.error(se.loc, "%.*s", cast(int)str.length, str.ptr);
            if (len < tb.isTypeSArray().dim.toInteger())
            {
                exp = se.castTo(sc, t);
                goto L1;
            }
        }

        /* Lop off terminating 0 of initializer for:
         *  static char s[5] = "hello";
         */
        if (sc.inCfile &&
            typeb.ty == Tsarray &&
            tynto.isSomeChar &&
            tb.isTypeSArray().dim.toInteger() + 1 == typeb.isTypeSArray().dim.toInteger())
        {
            exp = se.castTo(sc, t);
            goto L1;
        }
    }
    /* C11 6.7.9-14..15
     * Initialize an array of unknown size with a string.
     * Change to static array of known size
     */
    if (sc.inCfile && exp.isStringExp() &&
        tb.isTypeSArray() && tb.isTypeSArray().isIncomplete())
    {
        StringExp se = exp.isStringExp();
        auto ts = new TypeSArray(tb.nextOf(), new IntegerExp(Loc.initial, se.len + 1, Type.tsize_t));
        t = typeSemantic(ts, Loc.initial, sc);
        exp.type = t;
        tx = t;
        tb = t;
    }
    /* C11 6.7.9-22
     *  int a[] = { 1, 2, 3 };
     */
    if (sc.inCfile && exp.isArrayLiteralExp() &&
        tb.isTypeSArray() && tb.isTypeSArray().isIncomplete())
    {
        auto ts = new TypeSArray(tb.nextOf(), new IntegerExp(Loc.initial, exp.isArrayLiteralExp().elements.length, Type.tsize_t));
        t = typeSemantic(ts, Loc.initial, sc);
        tx = t;
        tb = t;
    }

    // Look for implicit constructor call
    if (tb.ty == Tstruct && !(ti.ty == Tstruct && tb.toDsymbol(sc) == ti.toDsymbol(sc)) && !exp.implicitConvTo(t))
    {
        StructDeclaration sd = tb.isTypeStruct().sym;
        if (sd.ctor)
        {
            // Rewrite as S().ctor(exp)
            Expression e;
            e = new StructLiteralExp(init.loc, sd, null);
            e = new DotIdExp(init.loc, e, Id.ctor);
            e = new CallExp(init.loc, e, exp);
            e = e.expressionSemantic(sc);
            if (needInterpret)
                exp = e.ctfeInterpret();
            else
                exp = e.optimize(WANTvalue);
        }
        else if (search_function(sd, Id.opCall))
        {
            /* https://issues.dlang.org/show_bug.cgi?id=1547
             *
             * Look for static opCall
             *
             * Rewrite as:
             *  exp = typeof(sd).opCall(arguments)
             */

            Expression e = typeDotIdExp(init.loc, sd.type, Id.opCall);
            e = new CallExp(init.loc, e, exp);
            e = e.expressionSemantic(sc);
            e = resolveProperties(sc, e);
            if (needInterpret)
                exp = e.ctfeInterpret();
            else
                exp = e.optimize(WANTvalue);
        }
    }

    exp = broadcastArrayInit(exp, t, sc);

    /* T* p = [1, 2];
     */
    if (auto ale = exp.isArrayLiteralExp())
    {
        if (tb.isTypePointer() && !tb.nextOf().isTypeFunction() && !exp.implicitConvTo(t) &&
            ale.type.nextOf().implicitConvTo(tb.nextOf()))
        {
            exp = ale.copy();
            exp.type = t;
        }
    }

    {
    auto tta = t.isTypeSArray();
    if (exp.implicitConvTo(t))
    {
        exp = exp.implicitCastTo(sc, t);
    }
    else if (sc.inCfile && exp.isStringExp() &&
        tta && (tta.next.ty == Tint8 || tta.next.ty == Tuns8) &&
        ti.ty == Tsarray && ti.nextOf().ty == Tchar)
    {
        /* unsigned char bbb[1] = "";
         *   signed char ccc[1] = "";
         */
        exp = exp.castTo(sc, t);
    }
    else
    {
        auto tba = tb.isTypeSArray();
        // Look for mismatch of compile-time known length to emit
        // better diagnostic message, as same as AssignExp::semantic.
        if (tba && exp.implicitConvTo(tba.next.arrayOf()) > MATCH.nomatch)
        {
            uinteger_t dim1 = tba.dim.toInteger();
            uinteger_t dim2 = dim1;
            if (auto ale = exp.isArrayLiteralExp())
            {
                dim2 = ale.length;
            }
            else if (auto se = exp.isSliceExp())
            {
                if (Type tx2 = toStaticArrayType(se))
                    dim2 = tx2.isTypeSArray().dim.toInteger();
            }
            if (dim1 != dim2)
            {
                eSink.error(exp.loc, "mismatched array lengths, %d and %d", cast(int)dim1, cast(int)dim2);
                exp = ErrorExp.get();
            }
        }
        Type et = exp.type;
        const errors = global.startGagging();
        exp = exp.implicitCastTo(sc, t);
        if (global.endGagging(errors))
            eSink.error(currExp.loc, "cannot implicitly convert expression `%s` of type `%s` to `%s`", currExp.toErrMsg(), et.toErrMsg(), t.toErrMsg());
    }
    }
L1:
    if (exp.op == EXP.error)
    {
        return exp;
    }
    if (needInterpret)
        exp = exp.ctfeInterpret();
    else
        exp = exp.optimize(WANTvalue);
    //printf("-initializerSemantic(): "); exp.print();
    return exp;
}

/******************************************
 * struct S { int a; int b[2]; } s = { 1, { 2, 3 } };   // { a: 1, b: [2, 3] }
 * int a[2][2] = { 1, 2, 3, 4 };                        // [[1, 2], [3, 4]]
 * int b[4] = { [3] = 1 };                              // [3: 1]
 */
Expression cInitializerSemantic(CInitExp ci, Scope* sc, Type tx)
{
    //printf("cInitializerSemantic() tx: %s ci: %s\n", tx.toChars(), ci.toChars());
    auto eSink = global.errorSink;
    Type t = tx.toBasetype();

    bool isComplexInitilaizer()
    {
        switch (t.ty)
        {
            case Tcomplex32:
            case Tcomplex64:
            case Tcomplex80:
                return true;
            default:
                return false;
        }
    }

    if (auto tv = t.isTypeVector())
        t = tv.basetype;

    if (ci.initializerList.length == 0)
        return t.defaultInit(ci.loc, true);

    /* If `{ expression }` return the expression
     */
    Expression isBraceExpression()
    {
        auto dil = ci.initializerList[];
        return (dil.length == 1 && !dil[0].designatorList && !dil[0].initializer.isCInitExp())
                ? dil[0].initializer
                : null;
    }

    /********************************
     */
    bool overlaps(VarDeclaration field, VarDeclaration[] fields, StructInitExp si)
    {
        foreach (fld; fields)
        {
            if (field.isOverlappedWith(fld))
            {
                // look for initializer corresponding with fld
                foreach (i, ident; si.field[])
                {
                    if (ident == fld.ident && si.value[i])
                        return true;   // already an initializer for `field`
                }
            }
        }
        return false;
    }

    /* Run semantic on expression, see if it represents entire struct ts
     */
    bool representsStruct(ref Expression e, TypeStruct ts)
    {
        e = e.expressionSemantic(sc);
        e = resolveProperties(sc, e);
        return e.implicitConvTo(ts) != MATCH.nomatch; // initializer represents the entire struct
    }

    /* If { } are omitted from substructs, use recursion to reconstruct where
     * brackets go
     * Params:
     *  ts = substruct to initialize
     *  index = index into ci.initializer, updated
     * Returns: struct initializer for this substruct
     */
    Expression subStruct()(TypeStruct ts, ref size_t index)
    {
        //printf("subStruct(ts: %s, index %d)\n", ts.toChars(), cast(int)index);

        auto si = new StructInitExp(ci.loc);
        StructDeclaration sd = ts.sym;
        sd.size(ci.loc);
        if (sd.sizeok != Sizeok.done)
        {
            index = ci.initializerList.length;
            return ErrorExp.get();
        }
        const nfields = sd.fields.length;

        foreach (fieldi; 0 .. nfields)
        {
            if (index >= ci.initializerList.length)
                break;          // ran out of initializers
            auto di = ci.initializerList[index];
            if (di.designatorList && fieldi != 0)
                break;          // back to top level

            VarDeclaration field;
            while (1)   // skip field if it overlaps with previously seen fields
            {
                field = sd.fields[fieldi];
                ++fieldi;
                if (!overlaps(field, sd.fields[], si))
                    break;
                if (fieldi == nfields)
                    break;
            }
            auto tn = field.type.toBasetype();
            auto tnsa = tn.isTypeSArray();
            auto tns = tn.isTypeStruct();
            auto ix = di.initializer;
            if (tnsa && !ix.isCInitExp())
            {
                if (ix.isStringExp() && tnsa.nextOf().isIntegral())
                {
                    si.addInit(field.ident, ix);
                    ++index;
                }
                else
                    si.addInit(field.ident, subArray(tnsa, index)); // fwd ref of subArray is why subStruct is a template
            }
            else if (tns && !ix.isCInitExp())
            {
                /* Disambiguate between an exp representing the entire
                 * struct, and an exp representing the first field of the struct
                 */
                if (representsStruct(ix, tns)) // initializer represents the entire struct
                {
                    si.addInit(field.ident, ix);
                    ++index;
                }
                else                                // field initializers for struct
                    si.addInit(field.ident, subStruct(tns, index)); // the first field
            }
            else
            {
                si.addInit(field.ident, ix);
                ++index;
            }
        }
        //printf("subStruct() returns ai: %s, index: %d\n", si.toChars(), cast(int)index);
        return si;
    }

    /* If { } are omitted from subarrays, use recursion to reconstruct where
     * brackets go
     * Params:
     *  tsa = subarray to initialize
     *  index = index into ci.initializer, updated
     * Returns: array initializer for this subarray
     */
    Expression subArray(TypeSArray tsa, ref size_t index)
    {
        //printf("array(tsa: %s, index %d)\n", tsa.toChars(), cast(int)index);
        if (tsa.isIncomplete())
        {
            // C11 6.2.5-20 "element type shall be complete whenever the array type is specified"
            assert(0); // should have been detected by parser
        }
        auto bt = tsa.nextOf().toBasetype();

        if (auto tnss = bt.isTypeStruct())
        {
            return subStruct(tnss, index);
        }
        auto tnsa = bt.isTypeSArray();
        ArrayBuilder!ASTCodegen ai;

        foreach (n; 0 .. cast(size_t)tsa.dim.toInteger())
        {
            if (index >= ci.initializerList.length)
                break;          // ran out of initializers
            auto di = ci.initializerList[index];
            if (di.designatorList)
                break;          // back to top level
            else if (tnsa && !di.initializer.isCInitExp())
            {
                if (di.initializer.isStringExp() && tnsa.nextOf().isIntegral())
                {
                    ai.addValue(di.initializer);
                    ++index;
                }
                else
                    ai.addValue(subArray(tnsa, index));
            }
            else
            {
                ai.addValue(di.initializer);
                ++index;
            }
        }
        //printf("array() returns ai: %s, index: %d\n", ai.toChars(), cast(int)index);
        return ai.finish(ci.loc);
    }

    if (auto ts = t.isTypeStruct())
    {
        auto si = new StructInitExp(ci.loc);
        StructDeclaration sd = ts.sym;
        sd.size(ci.loc);            // run semantic() on sd to get fields
        if (sd.sizeok != Sizeok.done)
        {
            return ErrorExp.get();
        }
        const nfields = sd.fields.length;
        size_t fieldi = 0;

    Loop1:
        for (size_t index = 0; index < ci.initializerList.length; )
        {
            DesigInit di = ci.initializerList[index];
            Designators* dlist = di.designatorList;
            VarDeclaration field;
            if (dlist)
            {
                const length = (*dlist).length;
                auto id = (*dlist)[0].ident;
                if (length == 0 || !(*dlist)[0].ident)
                {
                    eSink.error(ci.loc, "`.identifier` expected for C struct field initializer `%s`", ci.toErrMsg());
                    return ErrorExp.get();
                }

                if (length > 1)
                {
                    StructDeclaration nstsd = sd; // use this for member structs we wish to traverse
                    auto subsi = si;
                    /*
                     * run this for each designator in the chain until you hit the last
                     * then perform semantic analysis on the last field in the chain using the previous struct initializer
                     */
                    for (size_t i = 0; i < length; i++)
                    {
                        int found;
                        id = (*dlist)[i].ident;
                        foreach (f; nstsd.fields[])
                        {
                            if (f.ident == id)
                            {
                                field = f;
                                ++found;
                                break;
                            }
                        }
                        if (!found)
                        {
                            eSink.error(ci.loc, "`.%s` is not a field of `%s`\n", id.toErrMsg(), nstsd.toErrMsg());
                            return ErrorExp.get();
                        }

                        auto base = field.type.toBasetype();

                        if (i >= length -1)
                        {
                            subsi.addInit(id, di.initializer);
                            ++index;
                            continue Loop1;
                        }

                        auto tstr = base.isTypeStruct();
                        auto tarr = base.isTypeSArray();

                        if (tstr)
                        {
                            if (!overlaps(field, nstsd.fields[], subsi))
                            {
                                auto innersi = new StructInitExp(ci.loc);
                                subsi.addInit(id, innersi);
                                subsi = innersi;
                            }
                            else {
                                foreach(k, ident; subsi.field[])
                                {
                                    if (ident == id && subsi.value[k])
                                        subsi = subsi.value[k].isStructInitExp();
                                }
                            }
                            nstsd = tstr.sym;
                        }
                        /*
                         * once we hit an array, check & attach the array initializer to the struct initializer
                         * move to the next initializer id and run initializer semantics on it
                         */
                        else if (tarr)
                        {
                            AssocArrayLiteralExp ai;
                            foreach (k, ident; subsi.field[])
                            {
                                if (ident == id && subsi.value[k])
                                    ai = subsi.value[k].isAssocArrayLiteralExp();
                            }

                            if (ai is null)
                            {
                                ai = new AssocArrayLiteralExp(ci.loc, new Expressions(), new Expressions());
                                subsi.addInit(id, ai);
                            }

                            auto ndx = (*dlist)[i+1].exp;
                            ai.keys.push(ndx);
                            ai.values.push(di.initializer);
                            ++index;
                            continue Loop1;
                        }
                        else
                        {
                            eSink.error(ci.loc, "only 1 designated initializer allowed for C struct field of type `%s`", base.toErrMsg());
                            return ErrorExp.get();
                        }
                    }
                }
                foreach (k, f; sd.fields[])         // linear search for now
                {
                    if (f.ident == id)
                    {
                        fieldi = k;
                        si.addInit(id, di.initializer);
                        ++fieldi;
                        ++index;
                        continue Loop1;
                    }
                }
                eSink.error(ci.loc, "`.%s` is not a field of `%s`\n", id.toErrMsg(), sd.toErrMsg());
                return ErrorExp.get();
            }

            if (fieldi == nfields)
                break;

            auto ix = di.initializer;

            /* If a C initializer is wrapped in a C initializer, with no designators,
             * peel off the outer one
             */
            if (auto cix0 = ix.isCInitExp())
            {
                if (cix0.initializerList.length == 1)
                {
                    DesigInit dix = cix0.initializerList[0];
                    if (!dix.designatorList)
                    {
                        Expression inix = dix.initializer;
                        if (inix.isCInitExp())
                            ix = inix;
                    }
                }
            }

            if (auto cix = ix.isCInitExp())
            {
                /* ImportC loses the structure from anonymous structs, but this is retained
                 * by the initializer syntax. if a CInitializer has a Designator, it is probably
                 * a nested anonymous struct
                 */
                int found;
                foreach (dix; cix.initializerList)
                {
                    Designators* dlistx = dix.designatorList;
                    if (!dlistx)
                        continue;
                    if ((*dlistx).length == 1 && (*dlistx)[0].ident)
                    {
                        auto id = (*dlistx)[0].ident;
                        foreach (k, f; sd.fields[])         // linear search for now
                        {
                            if (f.ident == id)
                            {
                                fieldi = k;
                                si.addInit(id, dix.initializer);
                                ++fieldi;
                                ++index;
                                ++found;
                                break;
                            }
                        }
                    }
                    else {
                        eSink.error(ci.loc, "only 1 designator currently allowed for C struct field initializer `%s`", ci.toErrMsg());
                    }
                }

                if (found && found == cix.initializerList.length)
                    continue Loop1;
            }

            while (1)   // skip field if it overlaps with previously seen fields
            {
                field = sd.fields[fieldi];
                ++fieldi;
                if (!overlaps(field, sd.fields[], si))
                    break;
                if (fieldi == nfields)
                    break;
            }

            auto tn = field.type.toBasetype();
            auto tnsa = tn.isTypeSArray();
            auto tns = tn.isTypeStruct();

            if (tnsa && !ix.isCInitExp())
            {
                if (ix.isStringExp() && tnsa.nextOf().isIntegral())
                {
                    si.addInit(field.ident, ix);
                    ++index;
                }
                else
                    si.addInit(field.ident, subArray(tnsa, index));
            }
            else if (tns && !ix.isCInitExp())
            {
                /* Disambiguate between an exp representing the entire
                 * struct, and an exp representing the first field of the struct
                 */
                if (representsStruct(ix, tns)) // initializer represents the entire struct
                {
                    si.addInit(field.ident, ix);
                    ++index;
                }
                else                                // field initializers for struct
                    si.addInit(field.ident, subStruct(tns, index)); // the first field
            }
            else
            {
                si.addInit(field.ident, di.initializer);
                ++index;
            }
        }
        return si;
    }
    else if (auto ta = t.isTypeSArray())
    {
        auto tn = t.nextOf().toBasetype();  // element type of array

        /* If it's an array of integral being initialized by `{ string }`
         * replace with `string`
         */
        if (tn.isIntegral())
        {
            if (Expression ei = isBraceExpression())
            {
                if (ei.isStringExp())
                    return ei;
            }
        }

        auto tnsa = tn.isTypeSArray();      // array of array
        auto tns = tn.isTypeStruct();       // array of struct

        ArrayBuilder!ASTCodegen ai;
        for (size_t index = 0; index < ci.initializerList.length; )
        {
            auto di = ci.initializerList[index];
            if (auto dlist = di.designatorList)
            {
                const length = (*dlist).length;
                if (length == 0 || !(*dlist)[0].exp)
                {
                    eSink.error(ci.loc, "`[ constant-expression ]` expected for C array element initializer `%s`", ci.toErrMsg());
                    return ErrorExp.get();
                }
                if (length > 1)
                {
                    eSink.error(ci.loc, "only 1 designator currently allowed for C array element initializer `%s`", ci.toErrMsg());
                    return ErrorExp.get();
                }
                //printf("tn: %s, di.initializer: %s\n", tn.toChars(), di.initializer.toChars());
                auto ix = di.initializer;
                if (tnsa && !ix.isCInitExp())
                {
                    // Wrap initializer in [ ]
                    ai.addInit((*dlist)[0].exp, new ArrayLiteralExp(ci.loc, null, new Expressions(ix)));
                    ++index;
                }
                else if (tns && !ix.isCInitExp())
                {
                    /* Disambiguate between an exp representing the entire
                     * struct, and an exp representing the first field of the struct
                     */
                    if (representsStruct(ix, tns)) // initializer represents the entire struct
                    {
                        ai.addInit((*dlist)[0].exp, ix);
                        ++index;
                    }
                    else                                // field initializers for struct
                        ai.addInit((*dlist)[0].exp, subStruct(tns, index)); // the first field
                }
                else
                {
                    ai.addInit((*dlist)[0].exp, ix);
                    ++index;
                }
            }
            else if (tnsa && !di.initializer.isCInitExp())
            {
                if (di.initializer.isStringExp() && tnsa.nextOf().isIntegral())
                {
                    ai.addValue(di.initializer);
                    ++index;
                }
                else
                    ai.addValue(subArray(tnsa, index));
            }
            else if (tns && !di.initializer.isCInitExp())
            {
                /* Disambiguate between an exp representing the entire
                 * struct, and an exp representing the first field of the struct
                 */
                if (representsStruct(di.initializer, tns)) // initializer represents the entire struct
                {
                    ai.addValue(di.initializer);
                    ++index;
                }
                else                                // field initializers for struct
                    ai.addValue(subStruct(tns, index)); // the first field
            }
            else
            {
                ai.addValue(di.initializer);
                ++index;
            }
        }
        return ai.finish(ci.loc);
    }
    else if (Expression ei = isBraceExpression())
    {
        return ei;
    }
    else if (isComplexInitilaizer())
    {
        /* just convert _Complex = { a, b} to _Complex =. a + b*i */
        if (ci.initializerList[].length != 2)
        {
            eSink.error(ci.loc, "only two initializers required for complex type `%s`", t.toErrMsg());
            return ErrorExp.get();
        }
        auto rexp = ci.initializerList[0].initializer;
        auto imexp = ci.initializerList[1].initializer;

        import dmd.root.ctfloat;
        return new AddExp(ci.loc, rexp,
            new MulExp(ci.loc, imexp, new RealExp(ci.loc, CTFloat.one, Type.timaginary64)));
    }
    else
    {
        eSink.error(ci.loc, "unrecognized C initializer `%s` for type `%s`", ci.toErrMsg(), t.toErrMsg());
        return ErrorExp.get();
    }
}

void initializerSemantic(VarDeclaration vd, Scope* sc, NeedInterpret needInterpret)
{
    if (vd.initSemanticDone)
        return;
    vd._init = initializerSemantic(vd._init, sc, vd.type, needInterpret);
    vd.initSemanticDone = true;
}

/***********************
 * auto x = init;
 */
Expression inferInitializerType(ref Expression init, Scope* sc)
{
    auto eSink = global.errorSink;
    if (init.isVoidInitializer())
    {
        eSink.error(init.loc, "cannot infer type from void initializer");
        return ErrorExp.get();
    }
    //printf("inferInitializerType() %s\n", init.toChars());
    init = init.expressionSemantic(sc);

    // for static alias this: https://issues.dlang.org/show_bug.cgi?id=17684
    if (init.op == EXP.type)
        init = resolveAliasThis(sc, init);

    init = resolveProperties(sc, init);
    if (auto se = init.isScopeExp())
    {
        TemplateInstance ti = se.sds.isTemplateInstance();
        if (ti && ti.semanticRun == PASS.semantic && !ti.aliasdecl)
            eSink.error(se.loc, "cannot infer type from %s `%s`, possible circular dependency", se.sds.kind(), se.toErrMsg());
        else
            eSink.error(se.loc, "cannot infer type from %s `%s`", se.sds.kind(), se.toErrMsg());
        return ErrorExp.get();
    }

    // Give error for overloaded function addresses
    bool hasOverloads;
    if (auto f = isFuncAddress(init, &hasOverloads))
    {
        if (checkForwardRef(f, init.loc))
        {
            return ErrorExp.get();
        }
        if (hasOverloads && !f.isUnique())
        {
            eSink.error(init.loc, "cannot infer type from overloaded function symbol `%s`", init.toErrMsg());
            return ErrorExp.get();
        }
    }
    if (auto ae = init.isAddrExp())
    {
        if (ae.e1.op == EXP.overloadSet)
        {
            eSink.error(init.loc, "cannot infer type from overloaded function symbol `%s`", init.toErrMsg());
            return ErrorExp.get();
        }
    }
    if (init.isErrorExp())
    {
        return init;
    }
    if (!init.type)
    {
        return ErrorExp.get();
    }
    return init;
}

/**************************************
 * Determine if expression has non-constant pointers, or more precisely,
 * a pointer that CTFE cannot handle.
 * Params:
 *    e = expression to check
 * Returns:
 *    true if it has non-constant pointers
 */
private bool hasNonConstPointers(Expression e)
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
    if (e.op == EXP.null_)
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
        if (ae.type.isTypeAArray().index.hasPointers())
            return checkArray(ae.keys);
        return false;
    }
    if (auto ae = e.isAddrExp())
    {
        if (ae.type.nextOf().isImmutable() || ae.type.nextOf().isConst())
        {
            return false;
        }
        if (auto se = ae.e1.isStructLiteralExp())
        {
            if (!(se.stageflags & StructLiteralExp.StageFlags.searchPointers))
            {
                const old = se.stageflags;
                se.stageflags |= StructLiteralExp.StageFlags.searchPointers;
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
    if (e.type.ty == Tpointer && !e.type.isPtrToFunction())
    {
        if (e.op == EXP.symbolOffset) // address of a global is OK
            return false;
        if (e.op == EXP.int64) // cast(void *)int is OK
            return false;
        if (e.op == EXP.string_) // "abc".ptr is OK
            return false;
        return true;
    }
    return false;
}

/**
Given the names and values of a `StructInitExp` or `CallExp`,
resolve it to a list of expressions to construct a `StructLiteralExp`.

Params:
    sd = struct
    t = type of struct (potentially including qualifiers such as `const` or `immutable`)
    sc = scope of the expression initializing the struct
    iloc = location of expression initializing the struct
    argCount = count of argumnet present
    getExp = function that, given an index into `argNames` and destination type, returns the initializing expression
    getArgName = function that, given an index into `argNames`, returns the name of argument for error messages
    getArgLoc = function that, given an index into `argNames`, returns a location of argument for error messages
    getNameLoc = function that, given an index into `argNames`, returns a location of that `name` for error messages
    eSink = where error messages go

Returns: list of expressions ordered to the struct's fields, or `null` on error
*/
Expressions* resolveStructLiteralNamedArgs(StructDeclaration sd, Type t, Scope* sc,
    Loc iloc, size_t argCount, scope Identifier delegate(size_t i) getArgName, scope Expression delegate(size_t i, Type fieldType) getExp,
    scope Loc delegate(size_t i) getArgLoc,
    scope Loc delegate(size_t i) getNameLoc,
    ErrorSink eSink
)
{
    //expandTuples for non-identity arguments?
    const nfields = sd.nonHiddenFields();
    auto elements = new Expressions(nfields);
    auto elems = (*elements)[];
    foreach (ref elem; elems)
        elem = null;

    // Run semantic for explicitly given initializers
    // TODO: this part is slightly different from StructLiteralExp::semantic.
    bool errors = false;
    size_t fieldi = 0;
    foreach (j; 0 .. argCount)
    {
        const argLoc = getArgLoc(j);
        const nameLoc = getNameLoc(j);
        Identifier id = getArgName(j);
        if (id)
        {
            // Determine `fieldi` that `id` matches
            Dsymbol s = sd.search(iloc, id);
            if (!s)
            {
                s = sd.search_correct(id);
                if (s)
                    eSink.error(nameLoc, "`%s` is not a member of `%s`, did you mean %s `%s`?", id.toErrMsg(), sd.toErrMsg(), s.kind(), s.toErrMsg());
                else
                    eSink.error(nameLoc, "`%s` is not a member of `%s`", id.toErrMsg(), sd.toErrMsg());
                return null;
            }
            s.checkDeprecated(iloc, sc);
            s = s.toAlias();

            // Find out which field index `s` is
            for (fieldi = 0; 1; fieldi++)
            {
                if (fieldi >= nfields)
                {
                    eSink.error(iloc, "`%s.%s` is not a per-instance initializable field", sd.toErrMsg(), s.toErrMsg());
                    return null;
                }
                if (s == sd.fields[fieldi])
                    break;
            }
        }
        if (nfields == 0)
        {
            eSink.error(argLoc, "initializer provided for struct `%s` with no fields", sd.toErrMsg());
            return null;
        }
        if (j >= nfields)
        {
            eSink.error(argLoc, "too many initializers for `%s` with %d field%s", sd.toErrMsg(),
                cast(int) nfields, nfields != 1 ? "s".ptr : "".ptr);
            return null;
        }
        if (fieldi >= nfields)
        {
            eSink.error(argLoc, "trying to initialize past the last field `%s` of `%s`", sd.fields[nfields - 1].toErrMsg(), sd.toErrMsg());
            return null;
        }

        VarDeclaration vd = sd.fields[fieldi];
        if (elems[fieldi])
        {
            eSink.error(argLoc, "duplicate initializer for field `%s`", vd.toErrMsg());
            errors = true;
            elems[fieldi] = ErrorExp.get(); // for better diagnostics on multiple errors
            ++fieldi;
            continue;
        }

        // Check for @safe violations
        if (vd.type.hasPointers)
        {
            if ((!t.alignment.isDefault() && t.alignment.get() < target.ptrsize ||
                    (vd.offset & (target.ptrsize - 1))))
            {
                if (sc.setUnsafe(false, argLoc,
                    "field `%s.%s` assigning to misaligned pointers", sd, vd))
                {
                    errors = true;
                    elems[fieldi] = ErrorExp.get(); // for better diagnostics on multiple errors
                    ++fieldi;
                    continue;
                }
            }
        }

        // Check for overlapping initializations (can happen with unions)
        foreach (k, v2; sd.fields[0 .. nfields])
        {
            if (vd.isOverlappedWith(v2) && elems[k])
            {
                eSink.error(elems[k].loc, "overlapping initialization for field `%s` and `%s`", v2.toErrMsg(), vd.toErrMsg());
                enum errorMsg = "`struct` initializers that contain anonymous unions" ~
                    " must initialize only the first member of a `union`. All subsequent" ~
                    " non-overlapping fields are default initialized";
                if (!sd.isUnionDeclaration())
                    eSink.errorSupplemental(elems[k].loc, errorMsg);
                errors = true;
                continue;
            }
        }

        assert(sc);

        auto ex = getExp(j, vd.type);

        if (ex.op == EXP.error)
        {
            errors = true;
            elems[fieldi] = ErrorExp.get(); // for better diagnostics on multiple errors
            ++fieldi;
            continue;
        }

        elems[fieldi] = doCopyOrMove(sc, ex, null, false);
        ++fieldi;
    }
    if (errors)
        return null;

    return elements;
}




/****************************
 * char* args[] = { ops[1].text };
 */
private Expression cInterpretElements(Expression e)
{
    if (auto ale = e.isArrayLiteralExp())
    {
        foreach (ref el; *ale.elements)
            if (el)
                el = cInterpretElements(el);
        return e;
    }
    if (auto sle = e.isStructLiteralExp())
    {
        foreach (ref el; *sle.elements)
            if (el)
                el = cInterpretElements(el);
        return e;
    }
    e = e.optimize(WANTvalue);
    if (e.isSymOffExp())
        return e;
    return e.ctfeInterpret();
}

/********************************
 * S[] a = [{a: 1}, [1: {}], {}];
 * int[2] b = [1, 2];
 */
bool hasInitializerLiterals(Expression e)
{
    if (!e)
        return false;
    if (e.isStructInitExp() || e.isCInitExp() || e.isAssocArrayLiteralExp())
        return true;
    if (auto ale = e.isArrayLiteralExp())
    {
        foreach (el; *ale.elements)
            if (hasInitializerLiterals(el))
                return true;
    }
    return false;
}

/********************************
 * int[2][3] x = 7;  // [[7, 7], [7, 7], [7, 7]]
 * int[2] y = new Object;
 */
Expression broadcastArrayInit(Expression e, Type t, Scope* sc)
{
    Expression repeat(Type tb)
    {
        auto tsa = tb.isTypeSArray();
        if (!tsa || !tsa.dim.isIntegerExp())
            return null;
        Type tn = tsa.nextOf();
        Expression elem;
        if (e.implicitConvTo(tn))
            elem = e.implicitCastTo(sc, tn);
        else
            elem = repeat(tn.toBasetype());
        if (!elem)
            return null;
        auto elements = new Expressions(cast(size_t)tsa.dim.toInteger());
        foreach (ref el; *elements)
            el = elem;
        return new ArrayLiteralExp(e.loc, tb, elements);
    }

    Type tb = t.toBasetype();
    if (!tb.isTypeSArray() || !e.type || e.isErrorExp() || e.implicitConvTo(t))
        return e;
    if (auto r = repeat(tb))
        return r;
    return e;
}

/**********************
 * S s = S;
 */
Expression typeAsInitializerError(Expression exp, Loc initLoc)
{
    auto eSink = global.errorSink;
    eSink.error(exp.loc, "initializer must be an expression, not `%s`", exp.toErrMsg());
    if (exp.loc != initLoc)
        eSink.errorSupplemental(initLoc, "used in initialization here");
    if (auto ts = exp.type.isTypeStruct())
    {
        if (!ts.sym.hasCopyCtor && (!ts.sym.ctor || ts.sym.defaultCtor))
            eSink.errorSupplemental(exp.loc, "perhaps use `%s()` to construct a value of the type", exp.toChars());
        else if (ts.sym.ctor && !ts.sym.hasCopyCtor)
            eSink.errorSupplemental(exp.loc, "perhaps use `%s(...)` to construct a value of the type", exp.toChars());
    }
    else if (auto tc = exp.type.isTypeClass())
    {
        if (!tc.sym.noDefaultCtor && (!tc.sym.ctor || tc.sym.defaultCtor))
            eSink.errorSupplemental(exp.loc, "perhaps use `new %s()` to construct a value of the type", exp.toChars());
        else if (tc.sym.ctor)
            eSink.errorSupplemental(exp.loc, "perhaps use `new %s(...)` to construct a value of the type", exp.toChars());
    }
    return ErrorExp.get();
}
