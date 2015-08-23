// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.init;

import ddmd.aggregate, ddmd.arraytypes, ddmd.dcast, ddmd.declaration, ddmd.dscope, ddmd.dstruct, ddmd.dsymbol, ddmd.dtemplate, ddmd.errors, ddmd.expression, ddmd.func, ddmd.globals, ddmd.hdrgen, ddmd.id, ddmd.identifier, ddmd.mtype, ddmd.root.outbuffer, ddmd.root.rootobject, ddmd.statement, ddmd.tokens, ddmd.visitor;

enum NeedInterpret : int
{
    INITnointerpret,
    INITinterpret,
}

alias INITnointerpret = NeedInterpret.INITnointerpret;
alias INITinterpret = NeedInterpret.INITinterpret;

extern (C++) class Initializer : RootObject
{
public:
    Loc loc;

    /********************************** Initializer *******************************/
    final extern (D) this(Loc loc)
    {
        this.loc = loc;
    }

    abstract Initializer syntaxCopy();

    final static Initializers* arraySyntaxCopy(Initializers* ai)
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

    // needInterpret is INITinterpret if must be a manifest constant, 0 if not.
    abstract Initializer semantic(Scope* sc, Type t, NeedInterpret needInterpret);

    abstract Expression toExpression(Type t = null);

    final char* toChars()
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

extern (C++) final class VoidInitializer : Initializer
{
public:
    Type type; // type that this will initialize to

    /********************************** VoidInitializer ***************************/
    extern (D) this(Loc loc)
    {
        super(loc);
        type = null;
    }

    Initializer syntaxCopy()
    {
        return new VoidInitializer(loc);
    }

    Initializer inferType(Scope* sc)
    {
        error(loc, "cannot infer type from void initializer");
        return new ErrorInitializer();
    }

    Initializer semantic(Scope* sc, Type t, NeedInterpret needInterpret)
    {
        //printf("VoidInitializer::semantic(t = %p)\n", t);
        type = t;
        return this;
    }

    Expression toExpression(Type t = null)
    {
        return null;
    }

    VoidInitializer isVoidInitializer()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ErrorInitializer : Initializer
{
public:
    /********************************** ErrorInitializer ***************************/
    extern (D) this()
    {
        super(Loc());
    }

    Initializer syntaxCopy()
    {
        return this;
    }

    Initializer inferType(Scope* sc)
    {
        return this;
    }

    Initializer semantic(Scope* sc, Type t, NeedInterpret needInterpret)
    {
        //printf("ErrorInitializer::semantic(t = %p)\n", t);
        return this;
    }

    Expression toExpression(Type t = null)
    {
        return new ErrorExp();
    }

    ErrorInitializer isErrorInitializer()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class StructInitializer : Initializer
{
public:
    Identifiers field; // of Identifier *'s
    Initializers value; // parallel array of Initializer *'s

    /********************************** StructInitializer *************************/
    extern (D) this(Loc loc)
    {
        super(loc);
    }

    Initializer syntaxCopy()
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

    Initializer inferType(Scope* sc)
    {
        error(loc, "cannot infer type from struct initializer");
        return new ErrorInitializer();
    }

    Initializer semantic(Scope* sc, Type t, NeedInterpret needInterpret)
    {
        //printf("StructInitializer::semantic(t = %s) %s\n", t->toChars(), toChars());
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
                    bool overlap = (vd.offset < v2.offset + v2.type.size() && v2.offset < vd.offset + vd.type.size());
                    if (overlap && (*elements)[j])
                    {
                        error(loc, "overlapping initialization for field %s and %s", v2.toChars(), vd.toChars());
                        errors = true;
                        continue;
                    }
                }
                assert(sc);
                Initializer iz = value[i];
                iz = iz.semantic(sc, vd.type.addMod(t.mod), needInterpret);
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
            return ie.semantic(sc, t, needInterpret);
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
            return ie.semantic(sc, t, needInterpret);
        }
        error(loc, "a struct is not a valid initializer for a %s", t.toChars());
        return new ErrorInitializer();
    }

    /***************************************
     * This works by transforming a struct initializer into
     * a struct literal. In the future, the two should be the
     * same thing.
     */
    Expression toExpression(Type t = null)
    {
        // cannot convert to an expression without target 'ad'
        return null;
    }

    StructInitializer isStructInitializer()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ArrayInitializer : Initializer
{
public:
    Expressions index; // indices
    Initializers value; // of Initializer *'s
    size_t dim; // length of array being initialized
    Type type; // type that array will be used to initialize
    bool sem; // true if semantic() is run

    /********************************** ArrayInitializer ************************************/
    extern (D) this(Loc loc)
    {
        super(loc);
        dim = 0;
        type = null;
        sem = false;
    }

    Initializer syntaxCopy()
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

    Initializer inferType(Scope* sc)
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

    Initializer semantic(Scope* sc, Type t, NeedInterpret needInterpret)
    {
        size_t length;
        const(uint) amax = 0x80000000;
        bool errors = false;
        //printf("ArrayInitializer::semantic(%s)\n", t->toChars());
        if (sem) // if semantic() already run
            return this;
        sem = true;
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
        case Tstruct:
            // consider implicit constructor call
            {
                Expression e;
                // note: MyStruct foo = [1:2, 3:4] is correct code if MyStruct has a this(int[int])
                if (t.ty == Taarray || isAssociativeArray())
                    e = toAssocArrayLiteral();
                else
                    e = toExpression();
                if (!e) // Bugzilla 13987
                {
                    error(loc, "cannot use array to initialize %s", t.toChars());
                    goto Lerr;
                }
                auto ei = new ExpInitializer(e.loc, e);
                return ei.semantic(sc, t, needInterpret);
            }
        case Tpointer:
            if (t.nextOf().ty != Tfunction)
                break;
        default:
            error(loc, "cannot use array to initialize %s", t.toChars());
            goto Lerr;
        }
        type = t;
        length = 0;
        for (size_t i = 0; i < index.dim; i++)
        {
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
            Initializer val = value[i];
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
                index.remove(i);
                value.remove(i);
                for (size_t j = 0; j < te.exps.dim; ++j)
                {
                    Expression e = (*te.exps)[j];
                    index.insert(i + j, cast(Expression)null);
                    value.insert(i + j, new ExpInitializer(e.loc, e));
                }
                i--;
                continue;
            }
            else
            {
                value[i] = val;
            }
            length++;
            if (length == 0)
            {
                error(loc, "array dimension overflow");
                goto Lerr;
            }
            if (length > dim)
                dim = length;
        }
        if (t.ty == Tsarray)
        {
            dinteger_t edim = (cast(TypeSArray)t).dim.toInteger();
            if (dim > edim)
            {
                error(loc, "array initializer has %u elements, but array length is %lld", dim, edim);
                goto Lerr;
            }
        }
        if (errors)
            goto Lerr;
        if (cast(uinteger_t)dim * t.nextOf().size() >= amax)
        {
            error(loc, "array dimension %u exceeds max of %u", cast(uint)dim, cast(uint)(amax / t.nextOf().size()));
            goto Lerr;
        }
        return this;
    Lerr:
        return new ErrorInitializer();
    }

    /********************************
     * If possible, convert array initializer to array literal.
     * Otherwise return NULL.
     */
    Expression toExpression(Type tx = null)
    {
        //printf("ArrayInitializer::toExpression(), dim = %d\n", dim);
        //static int i; if (++i == 2) halt();
        Expressions* elements;
        size_t edim;
        Type t = null;
        if (type)
        {
            if (type == Type.terror)
                return new ErrorExp();
            t = type.toBasetype();
            switch (t.ty)
            {
            case Tsarray:
                edim = cast(size_t)(cast(TypeSArray)t).dim.toInteger();
                break;
            case Tvector:
                t = (cast(TypeVector)t).basetype;
                edim = cast(size_t)(cast(TypeSArray)t).dim.toInteger();
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
            edim = value.dim;
            for (size_t i = 0, j = 0; i < value.dim; i++, j++)
            {
                if (index[i])
                {
                    if (index[i].op == TOKint64)
                        j = cast(size_t)index[i].toInteger();
                    else
                        goto Lno;
                }
                if (j >= edim)
                    edim = j + 1;
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
        /* Fill in any missing elements with the default initializer
         */
        {
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
        //static int i; if (++i == 2) halt();
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

    ArrayInitializer isArrayInitializer()
    {
        return this;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class ExpInitializer : Initializer
{
public:
    Expression exp;
    bool expandTuples;

    /********************************** ExpInitializer ************************************/
    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
        this.expandTuples = false;
    }

    Initializer syntaxCopy()
    {
        return new ExpInitializer(loc, exp.syntaxCopy());
    }

    Initializer inferType(Scope* sc)
    {
        //printf("ExpInitializer::inferType() %s\n", toChars());
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);
        if (exp.op == TOKimport)
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
        if (exp.op == TOKsymoff)
        {
            SymOffExp se = cast(SymOffExp)exp;
            if (se.hasOverloads && !se.var.isFuncDeclaration().isUnique())
            {
                exp.error("cannot infer type from overloaded function symbol %s", exp.toChars());
                return new ErrorInitializer();
            }
        }
        if (exp.op == TOKdelegate)
        {
            DelegateExp se = cast(DelegateExp)exp;
            if (se.hasOverloads && se.func.isFuncDeclaration() && !se.func.isFuncDeclaration().isUnique())
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

    Initializer semantic(Scope* sc, Type t, NeedInterpret needInterpret)
    {
        //printf("ExpInitializer::semantic(%s), type = %s\n", exp->toChars(), t->toChars());
        if (needInterpret)
            sc = sc.startCTFE();
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);
        if (needInterpret)
            sc = sc.endCTFE();
        if (exp.op == TOKerror)
            return new ErrorInitializer();
        uint olderrors = global.errors;
        if (needInterpret)
        {
            // If the result will be implicitly cast, move the cast into CTFE
            // to avoid premature truncation of polysemous types.
            // eg real [] x = [1.1, 2.2]; should use real precision.
            if (exp.implicitConvTo(t))
            {
                exp = exp.implicitCastTo(sc, t);
            }
            exp = exp.ctfeInterpret();
        }
        else
        {
            exp = exp.optimize(WANTvalue);
        }
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
            exp.error("initializer must be an expression, not '%s'", exp.toChars());
            return new ErrorInitializer();
        }
        // Make sure all pointers are constants
        if (needInterpret && hasNonConstPointers(exp))
        {
            exp.error("cannot use non-constant CTFE pointer in an initializer '%s'", exp.toChars());
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
            StringExp se = cast(StringExp)exp;
            Type typeb = se.type.toBasetype();
            TY tynto = tb.nextOf().ty;
            if (!se.committed && (typeb.ty == Tarray || typeb.ty == Tsarray) && (tynto == Tchar || tynto == Twchar || tynto == Tdchar) && se.length(cast(int)tb.nextOf().size()) < (cast(TypeSArray)tb).dim.toInteger())
            {
                exp = se.castTo(sc, t);
                goto L1;
            }
        }
        // Look for implicit constructor call
        if (tb.ty == Tstruct && !(ti.ty == Tstruct && tb.toDsymbol(sc) == ti.toDsymbol(sc)) && !exp.implicitConvTo(t))
        {
            StructDeclaration sd = (cast(TypeStruct)tb).sym;
            if (sd.ctor)
            {
                // Rewrite as S().ctor(exp)
                Expression e;
                e = new StructLiteralExp(loc, sd, null);
                e = new DotIdExp(loc, e, Id.ctor);
                e = new CallExp(loc, e, exp);
                e = e.semantic(sc);
                if (needInterpret)
                    exp = e.ctfeInterpret();
                else
                    exp = e.optimize(WANTvalue);
            }
        }
        // Look for the case of statically initializing an array
        // with a single member.
        if (tb.ty == Tsarray && !tb.nextOf().equals(ti.toBasetype().nextOf()) && exp.implicitConvTo(tb.nextOf()))
        {
            /* If the variable is not actually used in compile time, array creation is
             * redundant. So delay it until invocation of toExpression() or toDt().
             */
            t = tb.nextOf();
        }
        if (exp.implicitConvTo(t))
        {
            exp = exp.implicitCastTo(sc, t);
        }
        else
        {
            // Look for mismatch of compile-time known length to emit
            // better diagnostic message, as same as AssignExp::semantic.
            if (tb.ty == Tsarray && exp.implicitConvTo(tb.nextOf().arrayOf()) > MATCHnomatch)
            {
                uinteger_t dim1 = (cast(TypeSArray)tb).dim.toInteger();
                uinteger_t dim2 = dim1;
                if (exp.op == TOKarrayliteral)
                {
                    ArrayLiteralExp ale = cast(ArrayLiteralExp)exp;
                    dim2 = ale.elements ? ale.elements.dim : 0;
                }
                else if (exp.op == TOKslice)
                {
                    Type tx = toStaticArrayType(cast(SliceExp)exp);
                    if (tx)
                        dim2 = (cast(TypeSArray)tx).dim.toInteger();
                }
                if (dim1 != dim2)
                {
                    exp.error("mismatched array lengths, %d and %d", cast(int)dim1, cast(int)dim2);
                    exp = new ErrorExp();
                }
            }
            exp = exp.implicitCastTo(sc, t);
        }
    L1:
        if (exp.op == TOKerror)
            return this;
        if (needInterpret)
            exp = exp.ctfeInterpret();
        else
            exp = exp.optimize(WANTvalue);
        //printf("-ExpInitializer::semantic(): "); exp->print();
        return this;
    }

    Expression toExpression(Type t = null)
    {
        if (t)
        {
            //printf("ExpInitializer::toExpression(t = %s) exp = %s\n", t->toChars(), exp->toChars());
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

    ExpInitializer isExpInitializer()
    {
        return this;
    }

    void accept(Visitor v)
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
