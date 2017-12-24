/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _mtype.d)
 */

module ddmd.typesem;

import core.checkedint;
import core.stdc.string;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.dcast;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dmangle;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.expression;
import ddmd.expressionsem;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.init;
import ddmd.initsem;
import ddmd.visitor;
import ddmd.mtype;
import ddmd.opover;
import ddmd.root.rmem;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.root.stringtable;
import ddmd.semantic;
import ddmd.target;
import ddmd.tokens;
import ddmd.typesem;

/******************************************
 * Perform semantic analysis on a type.
 * Params:
 *      t = Type AST node
 *      loc = the location of the type
 *      sc = context
 * Returns:
 *      `Type` with completed semantic analysis, `Terror` if errors
 *      were encountered
 */
extern(C++) Type typeSemantic(Type t, Loc loc, Scope* sc)
{
    scope v = new TypeSemanticVisitor(loc, sc);
    t.accept(v);
    return  v.result;
}

private extern (C++) final class TypeToExpressionVisitor : Visitor
{
    alias visit = super.visit;

    Expression result;
    Type itype;

    this() {}

    this(Type itype)
    {
        this.itype = itype;
    }

    override void visit(Type t)
    {
        result = null;
    }

    override void visit(TypeSArray t)
    {
        Expression e = t.next.typeToExpression();
        if (e)
            e = new ArrayExp(t.dim.loc, e, t.dim);
        result = e;
    }

    override void visit(TypeAArray t)
    {
        Expression e = t.next.typeToExpression();
        if (e)
        {
            Expression ei = t.index.typeToExpression();
            if (ei)
            {
                result = new ArrayExp(t.loc, e, ei);
                return;
            }
        }
        result = null;
    }

    override void visit(TypeIdentifier t)
    {
        result = typeToExpressionHelper(t, new IdentifierExp(t.loc, t.ident));
    }

    override void visit(TypeInstance t)
    {
        result = typeToExpressionHelper(t, new ScopeExp(t.loc, t.tempinst));
    }
}

/* We've mistakenly parsed this as a type.
 * Redo it as an Expression.
 * NULL if cannot.
 */
extern (C++) Expression typeToExpression(Type t)
{
    scope v = new TypeToExpressionVisitor();
    t.accept(v);
    return v.result;
}

/* Helper function for `typeToExpression`. Contains common code
 * for TypeQualified derived classes.
 */
extern (C++) Expression typeToExpressionHelper(TypeQualified t, Expression e, size_t i = 0)
{
    //printf("toExpressionHelper(e = %s %s)\n", Token.toChars(e.op), e.toChars());
    for (; i < t.idents.dim; i++)
    {
        RootObject id = t.idents[i];
        //printf("\t[%d] e: '%s', id: '%s'\n", i, e.toChars(), id.toChars());

        switch (id.dyncast())
        {
            // ... '. ident'
            case DYNCAST.identifier:
                e = new DotIdExp(e.loc, e, cast(Identifier)id);
                break;

            // ... '. name!(tiargs)'
            case DYNCAST.dsymbol:
                auto ti = (cast(Dsymbol)id).isTemplateInstance();
                assert(ti);
                e = new DotTemplateInstanceExp(e.loc, e, ti.name, ti.tiargs);
                break;

            // ... '[type]'
            case DYNCAST.type:          // https://issues.dlang.org/show_bug.cgi?id=1215
                e = new ArrayExp(t.loc, e, new TypeExp(t.loc, cast(Type)id));
                break;

            // ... '[expr]'
            case DYNCAST.expression:    // https://issues.dlang.org/show_bug.cgi?id=1215
                e = new ArrayExp(t.loc, e, cast(Expression)id);
                break;

            default:
                assert(0);
        }
    }
    return e;
}

private extern (C++) final class TypeSemanticVisitor : Visitor
{
    alias visit = super.visit;
    Loc loc;
    Scope* sc;
    Type result;

    this(Loc loc, Scope* sc)
    {
        this.loc = loc;
        this.sc = sc;
    }

    override void visit(Type t)
    {
        if (t.ty == Tint128 || t.ty == Tuns128)
        {
            t.error(loc, "cent and ucent types not implemented");
            result = Type.terror;
            return;
        }

        result = t.merge();
    }

    override void visit(TypeVector mtype)
    {
        uint errors = global.errors;
        mtype.basetype = mtype.basetype.typeSemantic(loc, sc);
        if (errors != global.errors)
        {
            result = Type.terror;
            return;
        }
        mtype.basetype = mtype.basetype.toBasetype().mutableOf();
        if (mtype.basetype.ty != Tsarray)
        {
            mtype.error(loc, "T in __vector(T) must be a static array, not %s", mtype.basetype.toChars());
            result = Type.terror;
            return;
        }
        TypeSArray t = cast(TypeSArray)mtype.basetype;
        int sz = cast(int)t.size(loc);
        switch (Target.isVectorTypeSupported(sz, t.nextOf()))
        {
        case 0:
            // valid
            break;
        case 1:
            // no support at all
            mtype.error(loc, "SIMD vector types not supported on this platform");
            result = Type.terror;
            return;
        case 2:
            // invalid base type
            mtype.error(loc, "vector type %s is not supported on this platform", mtype.toChars());
            result = Type.terror;
            return;
        case 3:
            // invalid size
            if (sz == 32)
            {
                deprecation(loc, "%d byte vector types are only supported with -mcpu=avx", sz, mtype.toChars());
                result = merge(mtype);
                return;
            }
            else
                mtype.error(loc, "%d byte vector type %s is not supported on this platform", sz, mtype.toChars());
            result = Type.terror;
            return;
        default:
            assert(0);
        }
        result = merge(mtype);
    }

    override void visit(TypeSArray mtype)
    {
        //printf("TypeSArray::semantic() %s\n", toChars());

        static Type errorReturn()
        {
            return Type.terror;
        }

        Type t;
        Expression e;
        Dsymbol s;
        mtype.next.resolve(loc, sc, &e, &t, &s);

        if (auto tup = s ? s.isTupleDeclaration() : null)
        {
            mtype.dim = semanticLength(sc, tup, mtype.dim);
            mtype.dim = mtype.dim.ctfeInterpret();
            if (mtype.dim.op == TOKerror)
            {
                result = errorReturn();
                return;
            }
            uinteger_t d = mtype.dim.toUInteger();
            if (d >= tup.objects.dim)
            {
                mtype.error(loc, "tuple index %llu exceeds %u", d, tup.objects.dim);
                result = errorReturn();
                return;
            }

            RootObject o = (*tup.objects)[cast(size_t)d];
            if (o.dyncast() != DYNCAST.type)
            {
                mtype.error(loc, "%s is not a type", mtype.toChars());
                result = errorReturn();
                return;
            }
            t = (cast(Type)o).addMod(mtype.mod);
            result = t;
            return;
        }

        Type tn = mtype.next.typeSemantic(loc, sc);
        if (tn.ty == Terror)
        {
            result = errorReturn();
            return;
        }

        Type tbn = tn.toBasetype();
        if (mtype.dim)
        {
            uint errors = global.errors;
            mtype.dim = semanticLength(sc, tbn, mtype.dim);
            if (errors != global.errors)
            {
                result = errorReturn();
                return;
            }

            mtype.dim = mtype.dim.optimize(WANTvalue);
            mtype.dim = mtype.dim.ctfeInterpret();
            if (mtype.dim.op == TOKerror)
            {
                result = errorReturn();
                return;
            }
            errors = global.errors;
            dinteger_t d1 = mtype.dim.toInteger();
            if (errors != global.errors)
            {
                result = errorReturn();
                return;
            }

            mtype.dim = mtype.dim.implicitCastTo(sc, Type.tsize_t);
            mtype.dim = mtype.dim.optimize(WANTvalue);
            if (mtype.dim.op == TOKerror)
            {
                result = errorReturn();
                return;
            }
            errors = global.errors;
            dinteger_t d2 = mtype.dim.toInteger();
            if (errors != global.errors)
            {
                result = errorReturn();
                return;
            }

            if (mtype.dim.op == TOKerror)
            {
                result = errorReturn();
                return;
            }

            if (d1 != d2)
            {
            Loverflow:
                mtype.error(loc, "%s size %llu * %llu exceeds 0x%llx size limit for static array",
                        mtype.toChars(), cast(ulong)tbn.size(loc), cast(ulong)d1, Target.maxStaticDataSize);
                result = errorReturn();
                return;
            }
            Type tbx = tbn.baseElemOf();
            if (tbx.ty == Tstruct && !(cast(TypeStruct)tbx).sym.members || tbx.ty == Tenum && !(cast(TypeEnum)tbx).sym.members)
            {
                /* To avoid meaningless error message, skip the total size limit check
                 * when the bottom of element type is opaque.
                 */
            }
            else if (tbn.isintegral() || tbn.isfloating() || tbn.ty == Tpointer || tbn.ty == Tarray || tbn.ty == Tsarray || tbn.ty == Taarray || (tbn.ty == Tstruct && ((cast(TypeStruct)tbn).sym.sizeok == SIZEOKdone)) || tbn.ty == Tclass)
            {
                /* Only do this for types that don't need to have semantic()
                 * run on them for the size, since they may be forward referenced.
                 */
                bool overflow = false;
                if (mulu(tbn.size(loc), d2, overflow) >= Target.maxStaticDataSize || overflow)
                    goto Loverflow;
            }
        }
        switch (tbn.ty)
        {
        case Ttuple:
            {
                // Index the tuple to get the type
                assert(mtype.dim);
                TypeTuple tt = cast(TypeTuple)tbn;
                uinteger_t d = mtype.dim.toUInteger();
                if (d >= tt.arguments.dim)
                {
                    mtype.error(loc, "tuple index %llu exceeds %u", d, tt.arguments.dim);
                    result = errorReturn();
                    return;
                }
                Type telem = (*tt.arguments)[cast(size_t)d].type;
                result = telem.addMod(mtype.mod);
                return;
            }
        case Tfunction:
        case Tnone:
            mtype.error(loc, "can't have array of %s", tbn.toChars());
            result = errorReturn();
            return;
        default:
            break;
        }
        if (tbn.isscope())
        {
            mtype.error(loc, "cannot have array of scope %s", tbn.toChars());
            result = errorReturn();
            return;
        }

        /* Ensure things like const(immutable(T)[3]) become immutable(T[3])
         * and const(T)[3] become const(T[3])
         */
        mtype.next = tn;
        mtype.transitive();
        t = mtype.addMod(tn.mod);

        result = t.merge();
    }

    override void visit(TypeDArray mtype)
    {
        Type tn = mtype.next.typeSemantic(loc, sc);
        Type tbn = tn.toBasetype();
        switch (tbn.ty)
        {
        case Ttuple:
            result = tbn;
            return;
        case Tfunction:
        case Tnone:
            mtype.error(loc, "can't have array of %s", tbn.toChars());
            result = Type.terror;
            return;
        case Terror:
            result = Type.terror;
            return;
        default:
            break;
        }
        if (tn.isscope())
        {
            mtype.error(loc, "cannot have array of scope %s", tn.toChars());
            result = Type.terror;
            return;
        }
        mtype.next = tn;
        mtype.transitive();
        result = merge(mtype);
    }

    override void visit(TypeAArray mtype)
    {
        //printf("TypeAArray::semantic() %s index.ty = %d\n", toChars(), index.ty);
        if (mtype.deco)
        {
            result = mtype;
            return;
        }

        mtype.loc = loc;
        mtype.sc = sc;
        if (sc)
            sc.setNoFree();

        // Deal with the case where we thought the index was a type, but
        // in reality it was an expression.
        if (mtype.index.ty == Tident || mtype.index.ty == Tinstance || mtype.index.ty == Tsarray || mtype.index.ty == Ttypeof || mtype.index.ty == Treturn)
        {
            Expression e;
            Type t;
            Dsymbol s;
            mtype.index.resolve(loc, sc, &e, &t, &s);
            if (e)
            {
                // It was an expression -
                // Rewrite as a static array
                auto tsa = new TypeSArray(mtype.next, e);
                result = tsa.typeSemantic(loc, sc);
                return;
            }
            else if (t)
                mtype.index = t.typeSemantic(loc, sc);
            else
            {
                mtype.index.error(loc, "index is not a type or an expression");
                result = Type.terror;
                return;
            }
        }
        else
            mtype.index = mtype.index.typeSemantic(loc, sc);
        mtype.index = mtype.index.merge2();

        if (mtype.index.nextOf() && !mtype.index.nextOf().isImmutable())
        {
            mtype.index = mtype.index.constOf().mutableOf();
            version (none)
            {
                printf("index is %p %s\n", mtype.index, mtype.index.toChars());
                mtype.index.check();
                printf("index.mod = x%x\n", mtype.index.mod);
                printf("index.ito = x%x\n", mtype.index.ito);
                if (mtype.index.ito)
                {
                    printf("index.ito.mod = x%x\n", mtype.index.ito.mod);
                    printf("index.ito.ito = x%x\n", mtype.index.ito.ito);
                }
            }
        }

        switch (mtype.index.toBasetype().ty)
        {
        case Tfunction:
        case Tvoid:
        case Tnone:
        case Ttuple:
            mtype.error(loc, "can't have associative array key of %s", mtype.index.toBasetype().toChars());
            goto case Terror;
        case Terror:
            result = Type.terror;
            return;
        default:
            break;
        }
        Type tbase = mtype.index.baseElemOf();
        while (tbase.ty == Tarray)
            tbase = tbase.nextOf().baseElemOf();
        if (tbase.ty == Tstruct)
        {
            /* AA's need typeid(index).equals() and getHash(). Issue error if not correctly set up.
             */
            StructDeclaration sd = (cast(TypeStruct)tbase).sym;
            if (sd.semanticRun < PASSsemanticdone)
                sd.semantic(null);

            // duplicate a part of StructDeclaration::semanticTypeInfoMembers
            //printf("AA = %s, key: xeq = %p, xerreq = %p xhash = %p\n", toChars(), sd.xeq, sd.xerreq, sd.xhash);
            if (sd.xeq && sd.xeq._scope && sd.xeq.semanticRun < PASSsemantic3done)
            {
                uint errors = global.startGagging();
                sd.xeq.semantic3(sd.xeq._scope);
                if (global.endGagging(errors))
                    sd.xeq = sd.xerreq;
            }

            //printf("AA = %s, key: xeq = %p, xhash = %p\n", toChars(), sd.xeq, sd.xhash);
            const(char)* s = (mtype.index.toBasetype().ty != Tstruct) ? "bottom of " : "";
            if (!sd.xeq)
            {
                // If sd.xhash != NULL:
                //   sd or its fields have user-defined toHash.
                //   AA assumes that its result is consistent with bitwise equality.
                // else:
                //   bitwise equality & hashing
            }
            else if (sd.xeq == sd.xerreq)
            {
                if (search_function(sd, Id.eq))
                {
                    mtype.error(loc, "%sAA key type %s does not have 'bool opEquals(ref const %s) const'", s, sd.toChars(), sd.toChars());
                }
                else
                {
                    mtype.error(loc, "%sAA key type %s does not support const equality", s, sd.toChars());
                }
                result = Type.terror;
                return;
            }
            else if (!sd.xhash)
            {
                if (search_function(sd, Id.eq))
                {
                    mtype.error(loc, "%sAA key type %s should have 'size_t toHash() const nothrow @safe' if opEquals defined", s, sd.toChars());
                }
                else
                {
                    mtype.error(loc, "%sAA key type %s supports const equality but doesn't support const hashing", s, sd.toChars());
                }
                result = Type.terror;
                return;
            }
            else
            {
                // defined equality & hashing
                assert(sd.xeq && sd.xhash);

                /* xeq and xhash may be implicitly defined by compiler. For example:
                 *   struct S { int[] arr; }
                 * With 'arr' field equality and hashing, compiler will implicitly
                 * generate functions for xopEquals and xtoHash in TypeInfo_Struct.
                 */
            }
        }
        else if (tbase.ty == Tclass && !(cast(TypeClass)tbase).sym.isInterfaceDeclaration())
        {
            ClassDeclaration cd = (cast(TypeClass)tbase).sym;
            if (cd.semanticRun < PASSsemanticdone)
                cd.semantic(null);

            if (!ClassDeclaration.object)
            {
                mtype.error(Loc(), "missing or corrupt object.d");
                fatal();
            }

            static __gshared FuncDeclaration feq = null;
            static __gshared FuncDeclaration fcmp = null;
            static __gshared FuncDeclaration fhash = null;
            if (!feq)
                feq = search_function(ClassDeclaration.object, Id.eq).isFuncDeclaration();
            if (!fcmp)
                fcmp = search_function(ClassDeclaration.object, Id.cmp).isFuncDeclaration();
            if (!fhash)
                fhash = search_function(ClassDeclaration.object, Id.tohash).isFuncDeclaration();
            assert(fcmp && feq && fhash);

            if (feq.vtblIndex < cd.vtbl.dim && cd.vtbl[feq.vtblIndex] == feq)
            {
                version (all)
                {
                    if (fcmp.vtblIndex < cd.vtbl.dim && cd.vtbl[fcmp.vtblIndex] != fcmp)
                    {
                        const(char)* s = (mtype.index.toBasetype().ty != Tclass) ? "bottom of " : "";
                        mtype.error(loc, "%sAA key type %s now requires equality rather than comparison", s, cd.toChars());
                        errorSupplemental(loc, "Please override Object.opEquals and toHash.");
                    }
                }
            }
        }
        mtype.next = mtype.next.typeSemantic(loc, sc).merge2();
        mtype.transitive();

        switch (mtype.next.toBasetype().ty)
        {
        case Tfunction:
        case Tvoid:
        case Tnone:
        case Ttuple:
            mtype.error(loc, "can't have associative array of %s", mtype.next.toChars());
            goto case Terror;
        case Terror:
            result = Type.terror;
            return;
        default:
            break;
        }
        if (mtype.next.isscope())
        {
            mtype.error(loc, "cannot have array of scope %s", mtype.next.toChars());
            result = Type.terror;
            return;
        }
        result = merge(mtype);
    }

    override void visit(TypePointer mtype)
    {
        //printf("TypePointer::semantic() %s\n", toChars());
        if (mtype.deco)
        {
            result = mtype;
            return;
        }
        Type n = mtype.next.typeSemantic(loc, sc);
        switch (n.toBasetype().ty)
        {
        case Ttuple:
            mtype.error(loc, "can't have pointer to %s", n.toChars());
            goto case Terror;
        case Terror:
            result = Type.terror;
            return;
        default:
            break;
        }
        if (n != mtype.next)
        {
            mtype.deco = null;
        }
        mtype.next = n;
        if (mtype.next.ty != Tfunction)
        {
            mtype.transitive();
            result = merge(mtype);
            return;
        }
        version (none)
        {
            result = merge(mtype);
            return;
        }
        else
        {
            mtype.deco = merge(mtype).deco;
            /* Don't return merge(), because arg identifiers and default args
             * can be different
             * even though the types match
             */
            result = mtype;
            return;
        }
    }

    override void visit(TypeReference mtype)
    {
        //printf("TypeReference::semantic()\n");
        Type n = mtype.next.typeSemantic(loc, sc);
        if (n !=mtype. next)
           mtype. deco = null;
        mtype.next = n;
        mtype.transitive();
        result = merge(mtype);
    }

    override void visit(TypeFunction mtype)
    {
        if (mtype.deco) // if semantic() already run
        {
            //printf("already done\n");
            result = mtype;
            return;
        }
        //printf("TypeFunction::semantic() this = %p\n", this);
        //printf("TypeFunction::semantic() %s, sc.stc = %llx, fargs = %p\n", toChars(), sc.stc, fargs);

        bool errors = false;

        /* Copy in order to not mess up original.
         * This can produce redundant copies if inferring return type,
         * as semantic() will get called again on this.
         */
        TypeFunction tf = mtype.copy().toTypeFunction();
        if (mtype.parameters)
        {
            tf.parameters = mtype.parameters.copy();
            for (size_t i = 0; i < mtype.parameters.dim; i++)
            {
                Parameter p = cast(Parameter)mem.xmalloc(__traits(classInstanceSize, Parameter));
                memcpy(cast(void*)p, cast(void*)(*mtype.parameters)[i], __traits(classInstanceSize, Parameter));
                (*tf.parameters)[i] = p;
            }
        }

        if (sc.stc & STCpure)
            tf.purity = PUREfwdref;
        if (sc.stc & STCnothrow)
            tf.isnothrow = true;
        if (sc.stc & STCnogc)
            tf.isnogc = true;
        if (sc.stc & STCref)
            tf.isref = true;
        if (sc.stc & STCreturn)
            tf.isreturn = true;
        if (sc.stc & STCscope)
            tf.isscope = true;
        if (sc.stc & STCscopeinferred)
            tf.isscopeinferred = true;

//        if (tf.isreturn && !tf.isref)
//            tf.isscope = true;                                  // return by itself means 'return scope'

        if (tf.trust == TRUSTdefault)
        {
            if (sc.stc & STCsafe)
                tf.trust = TRUSTsafe;
            else if (sc.stc & STCsystem)
                tf.trust = TRUSTsystem;
            else if (sc.stc & STCtrusted)
                tf.trust = TRUSTtrusted;
        }

        if (sc.stc & STCproperty)
            tf.isproperty = true;

        tf.linkage = sc.linkage;
        version (none)
        {
            /* If the parent is @safe, then this function defaults to safe
             * too.
             * If the parent's @safe-ty is inferred, then this function's @safe-ty needs
             * to be inferred first.
             */
            if (tf.trust == TRUSTdefault)
                for (Dsymbol p = sc.func; p; p = p.toParent2())
                {
                    FuncDeclaration fd = p.isFuncDeclaration();
                    if (fd)
                    {
                        if (fd.isSafeBypassingInference())
                            tf.trust = TRUSTsafe; // default to @safe
                        break;
                    }
                }
        }

        bool wildreturn = false;
        if (tf.next)
        {
            sc = sc.push();
            sc.stc &= ~(STC_TYPECTOR | STC_FUNCATTR);
            tf.next = tf.next.typeSemantic(loc, sc);
            sc = sc.pop();
            errors |= tf.checkRetType(loc);
            if (tf.next.isscope() && !(sc.flags & SCOPEctor))
            {
                mtype.error(loc, "functions cannot return scope %s", tf.next.toChars());
                errors = true;
            }
            if (tf.next.hasWild())
                wildreturn = true;

            if (tf.isreturn && !tf.isref && !tf.next.hasPointers())
            {
                mtype.error(loc, "function type '%s' has 'return' but does not return any indirections", tf.toChars());
            }
        }

        ubyte wildparams = 0;
        if (tf.parameters)
        {
            /* Create a scope for evaluating the default arguments for the parameters
             */
            Scope* argsc = sc.push();
            argsc.stc = 0; // don't inherit storage class
            argsc.protection = Prot(PROTpublic);
            argsc.func = null;

            size_t dim = Parameter.dim(tf.parameters);
            for (size_t i = 0; i < dim; i++)
            {
                Parameter fparam = Parameter.getNth(tf.parameters, i);
                tf.inuse++;
                fparam.type = fparam.type.typeSemantic(loc, argsc);
                if (tf.inuse == 1)
                    tf.inuse--;
                if (fparam.type.ty == Terror)
                {
                    errors = true;
                    continue;
                }

                fparam.type = fparam.type.addStorageClass(fparam.storageClass);

                if (fparam.storageClass & (STCauto | STCalias | STCstatic))
                {
                    if (!fparam.type)
                        continue;
                }

                Type t = fparam.type.toBasetype();

                if (t.ty == Tfunction)
                {
                    mtype.error(loc, "cannot have parameter of function type %s", fparam.type.toChars());
                    errors = true;
                }
                else if (!(fparam.storageClass & (STCref | STCout)) &&
                         (t.ty == Tstruct || t.ty == Tsarray || t.ty == Tenum))
                {
                    Type tb2 = t.baseElemOf();
                    if (tb2.ty == Tstruct && !(cast(TypeStruct)tb2).sym.members ||
                        tb2.ty == Tenum && !(cast(TypeEnum)tb2).sym.memtype)
                    {
                        mtype.error(loc, "cannot have parameter of opaque type %s by value", fparam.type.toChars());
                        errors = true;
                    }
                }
                else if (!(fparam.storageClass & STClazy) && t.ty == Tvoid)
                {
                    mtype.error(loc, "cannot have parameter of type %s", fparam.type.toChars());
                    errors = true;
                }

                if ((fparam.storageClass & (STCref | STCwild)) == (STCref | STCwild))
                {
                    // 'ref inout' implies 'return'
                    fparam.storageClass |= STCreturn;
                }

                if (fparam.storageClass & STCreturn)
                {
                    if (fparam.storageClass & (STCref | STCout))
                    {
                        // Disabled for the moment awaiting improvement to allow return by ref
                        // to be transformed into return by scope.
                        if (0 && !tf.isref)
                        {
                            auto stc = fparam.storageClass & (STCref | STCout);
                            mtype.error(loc, "parameter %s is 'return %s' but function does not return by ref",
                                fparam.ident ? fparam.ident.toChars() : "",
                                stcToChars(stc));
                            errors = true;
                        }
                    }
                    else
                    {
                        fparam.storageClass |= STCscope;        // 'return' implies 'scope'
                        if (tf.isref)
                        {
                        }
                        else if (tf.next && !tf.next.hasPointers())
                        {
                            mtype.error(loc, "parameter %s is 'return' but function does not return any indirections",
                                fparam.ident ? fparam.ident.toChars() : "");
                            errors = true;
                        }
                    }
                }

                if (fparam.storageClass & (STCref | STClazy))
                {
                }
                else if (fparam.storageClass & STCout)
                {
                    if (ubyte m = fparam.type.mod & (MODimmutable | MODconst | MODwild))
                    {
                        mtype.error(loc, "cannot have %s out parameter of type %s", MODtoChars(m), t.toChars());
                        errors = true;
                    }
                    else
                    {
                        Type tv = t;
                        while (tv.ty == Tsarray)
                            tv = tv.nextOf().toBasetype();
                        if (tv.ty == Tstruct && (cast(TypeStruct)tv).sym.noDefaultCtor)
                        {
                            mtype.error(loc, "cannot have out parameter of type %s because the default construction is disabled", fparam.type.toChars());
                            errors = true;
                        }
                    }
                }

                if (fparam.storageClass & STCscope && !fparam.type.hasPointers() && fparam.type.ty != Ttuple)
                {
                    fparam.storageClass &= ~STCscope;
                    if (!(fparam.storageClass & STCref))
                        fparam.storageClass &= ~STCreturn;
                }

                if (t.hasWild())
                {
                    wildparams |= 1;
                    //if (tf.next && !wildreturn)
                    //    error(loc, "inout on parameter means inout must be on return type as well (if from D1 code, replace with 'ref')");
                }

                if (fparam.defaultArg)
                {
                    Expression e = fparam.defaultArg;
                    if (fparam.storageClass & (STCref | STCout))
                    {
                        e = e.expressionSemantic(argsc);
                        e = resolveProperties(argsc, e);
                    }
                    else
                    {
                        e = inferType(e, fparam.type);
                        Initializer iz = new ExpInitializer(e.loc, e);
                        iz = iz.semantic(argsc, fparam.type, INITnointerpret);
                        e = iz.initializerToExpression();
                    }
                    if (e.op == TOKfunction) // https://issues.dlang.org/show_bug.cgi?id=4820
                    {
                        FuncExp fe = cast(FuncExp)e;
                        // Replace function literal with a function symbol,
                        // since default arg expression must be copied when used
                        // and copying the literal itself is wrong.
                        e = new VarExp(e.loc, fe.fd, false);
                        e = new AddrExp(e.loc, e);
                        e = e.expressionSemantic(argsc);
                    }
                    e = e.implicitCastTo(argsc, fparam.type);

                    // default arg must be an lvalue
                    if (fparam.storageClass & (STCout | STCref))
                        e = e.toLvalue(argsc, e);

                    fparam.defaultArg = e;
                    if (e.op == TOKerror)
                        errors = true;
                }

                /* If fparam after semantic() turns out to be a tuple, the number of parameters may
                 * change.
                 */
                if (t.ty == Ttuple)
                {
                    /* TypeFunction::parameter also is used as the storage of
                     * Parameter objects for FuncDeclaration. So we should copy
                     * the elements of TypeTuple::arguments to avoid unintended
                     * sharing of Parameter object among other functions.
                     */
                    TypeTuple tt = cast(TypeTuple)t;
                    if (tt.arguments && tt.arguments.dim)
                    {
                        /* Propagate additional storage class from tuple parameters to their
                         * element-parameters.
                         * Make a copy, as original may be referenced elsewhere.
                         */
                        size_t tdim = tt.arguments.dim;
                        auto newparams = new Parameters();
                        newparams.setDim(tdim);
                        for (size_t j = 0; j < tdim; j++)
                        {
                            Parameter narg = (*tt.arguments)[j];

                            // https://issues.dlang.org/show_bug.cgi?id=12744
                            // If the storage classes of narg
                            // conflict with the ones in fparam, it's ignored.
                            StorageClass stc  = fparam.storageClass | narg.storageClass;
                            StorageClass stc1 = fparam.storageClass & (STCref | STCout | STClazy);
                            StorageClass stc2 =   narg.storageClass & (STCref | STCout | STClazy);
                            if (stc1 && stc2 && stc1 != stc2)
                            {
                                OutBuffer buf1;  stcToBuffer(&buf1, stc1 | ((stc1 & STCref) ? (fparam.storageClass & STCauto) : 0));
                                OutBuffer buf2;  stcToBuffer(&buf2, stc2);

                                mtype.error(loc, "incompatible parameter storage classes '%s' and '%s'",
                                    buf1.peekString(), buf2.peekString());
                                errors = true;
                                stc = stc1 | (stc & ~(STCref | STCout | STClazy));
                            }

                            (*newparams)[j] = new Parameter(
                                stc, narg.type, narg.ident, narg.defaultArg);
                        }
                        fparam.type = new TypeTuple(newparams);
                    }
                    fparam.storageClass = 0;

                    /* Reset number of parameters, and back up one to do this fparam again,
                     * now that it is a tuple
                     */
                    dim = Parameter.dim(tf.parameters);
                    i--;
                    continue;
                }

                /* Resolve "auto ref" storage class to be either ref or value,
                 * based on the argument matching the parameter
                 */
                if (fparam.storageClass & STCauto)
                {
                    if (mtype.fargs && i < mtype.fargs.dim && (fparam.storageClass & STCref))
                    {
                        Expression farg = (*mtype.fargs)[i];
                        if (farg.isLvalue())
                        {
                            // ref parameter
                        }
                        else
                            fparam.storageClass &= ~STCref; // value parameter
                        fparam.storageClass &= ~STCauto;    // https://issues.dlang.org/show_bug.cgi?id=14656
                        fparam.storageClass |= STCautoref;
                    }
                    else
                    {
                        mtype.error(loc, "'auto' can only be used as part of 'auto ref' for template function parameters");
                        errors = true;
                    }
                }

                // Remove redundant storage classes for type, they are already applied
                fparam.storageClass &= ~(STC_TYPECTOR | STCin);
            }
            argsc.pop();
        }
        if (tf.isWild())
            wildparams |= 2;

        if (wildreturn && !wildparams)
        {
            mtype.error(loc, "inout on return means inout must be on a parameter as well for %s", mtype.toChars());
            errors = true;
        }
        tf.iswild = wildparams;

        if (tf.inuse)
        {
            mtype.error(loc, "recursive type");
            tf.inuse = 0;
            errors = true;
        }

        if (tf.isproperty && (tf.varargs || Parameter.dim(tf.parameters) > 2))
        {
            mtype.error(loc, "properties can only have zero, one, or two parameter");
            errors = true;
        }

        if (tf.varargs == 1 && tf.linkage != LINKd && Parameter.dim(tf.parameters) == 0)
        {
            mtype.error(loc, "variadic functions with non-D linkage must have at least one parameter");
            errors = true;
        }

        if (errors)
        {
            result = Type.terror;
            return;
        }

        if (tf.next)
            tf.deco = tf.merge().deco;

        /* Don't return merge(), because arg identifiers and default args
         * can be different
         * even though the types match
         */
        result = tf;
    }

    override void visit(TypeDelegate mtype)
    {
        //printf("TypeDelegate::semantic() %s\n", toChars());
        if (mtype.deco) // if semantic() already run
        {
            //printf("already done\n");
            result = mtype;
            return;
        }
        mtype.next = mtype.next.typeSemantic(loc, sc);
        if (mtype.next.ty != Tfunction)
        {
            result = Type.terror;
            return;
        }

        /* In order to deal with https://issues.dlang.org/show_bug.cgi?id=4028
         * perhaps default arguments should
         * be removed from next before the merge.
         */
        version (none)
        {
            result = mtype.merge();
            return;
        }
        else
        {
            /* Don't return merge(), because arg identifiers and default args
             * can be different
             * even though the types match
             */
            mtype.deco = mtype.merge().deco;
            result = mtype;
        }
    }

    override void visit(TypeIdentifier mtype)
    {
        Type t;
        Expression e;
        Dsymbol s;
        //printf("TypeIdentifier::semantic(%s)\n", toChars());
        mtype.resolve(loc, sc, &e, &t, &s);
        if (t)
        {
            //printf("\tit's a type %d, %s, %s\n", t.ty, t.toChars(), t.deco);
            t = t.addMod(mtype.mod);
        }
        else
        {
            if (s)
            {
                s.error(loc, "is used as a type");
                //assert(0);
            }
            else
                mtype.error(loc, "%s is used as a type", mtype.toChars());
            t = Type.terror;
        }
        //t.print();
        result = t;
    }

    override void visit(TypeInstance mtype)
    {
        Type t;
        Expression e;
        Dsymbol s;

        //printf("TypeInstance::semantic(%p, %s)\n", this, toChars());
        {
            uint errors = global.errors;
            mtype.resolve(loc, sc, &e, &t, &s);
            // if we had an error evaluating the symbol, suppress further errors
            if (!t && errors != global.errors)
            {
                result = Type.terror;
                return;
            }
        }

        if (!t)
        {
            if (!e && s && s.errors)
            {
                // if there was an error evaluating the symbol, it might actually
                // be a type. Avoid misleading error messages.
               mtype.error(loc, "%s had previous errors", mtype.toChars());
            }
            else
               mtype.error(loc, "%s is used as a type", mtype.toChars());
            t = Type.terror;
        }
        result = t;
    }

    override void visit(TypeTypeof mtype)
    {
        //printf("TypeTypeof::semantic() %s\n", toChars());
        Expression e;
        Type t;
        Dsymbol s;
        mtype.resolve(loc, sc, &e, &t, &s);
        if (s && (t = s.getType()) !is null)
            t = t.addMod(mtype.mod);
        if (!t)
        {
            mtype.error(loc, "%s is used as a type", mtype.toChars());
            t = Type.terror;
        }
        result = t;
    }

    override void visit(TypeReturn mtype)
    {
        //printf("TypeReturn::semantic() %s\n", toChars());
        Expression e;
        Type t;
        Dsymbol s;
        mtype.resolve(loc, sc, &e, &t, &s);
        if (s && (t = s.getType()) !is null)
            t = t.addMod(mtype.mod);
        if (!t)
        {
            mtype.error(loc, "%s is used as a type", mtype.toChars());
            t = Type.terror;
        }
        result = t;
    }

    override void visit(TypeStruct mtype)
    {
        //printf("TypeStruct::semantic('%s')\n", sym.toChars());
        if (mtype.deco)
        {
            if (sc && sc.cppmangle != CPPMANGLE.def)
            {
                if (mtype.cppmangle == CPPMANGLE.def)
                    mtype.cppmangle = sc.cppmangle;
                else
                    assert(mtype.cppmangle == sc.cppmangle);
            }
            result = mtype;
            return;
        }

        /* Don't semantic for sym because it should be deferred until
         * sizeof needed or its members accessed.
         */
        // instead, parent should be set correctly
        assert(mtype.sym.parent);

        if (mtype.sym.type.ty == Terror)
        {
            result = Type.terror;
            return;
        }
        if (sc)
            mtype.cppmangle = sc.cppmangle;
        result = merge(mtype);
    }

    override void visit(TypeEnum mtype)
    {
        //printf("TypeEnum::semantic() %s\n", toChars());
        if (mtype.deco)
        {
            result = mtype;
            return;
        }
        result = merge(mtype);
    }

    override void visit(TypeClass mtype)
    {
        //printf("TypeClass::semantic(%s)\n", sym.toChars());
        if (mtype.deco)
        {
            if (sc && sc.cppmangle != CPPMANGLE.def)
            {
                if (mtype.cppmangle == CPPMANGLE.def)
                    mtype.cppmangle = sc.cppmangle;
                else
                    assert(mtype.cppmangle == sc.cppmangle);
            }
            result = mtype;
            return;
        }

        /* Don't semantic for sym because it should be deferred until
         * sizeof needed or its members accessed.
         */
        // instead, parent should be set correctly
        assert(mtype.sym.parent);

        if (mtype.sym.type.ty == Terror)
        {
            result = Type.terror;
            return;
        }
        if (sc)
            mtype.cppmangle = sc.cppmangle;
        result = merge(mtype);
    }

    override void visit(TypeTuple mtype)
    {
        //printf("TypeTuple::semantic(this = %p)\n", this);
        //printf("TypeTuple::semantic() %p, %s\n", this, toChars());
        if (!mtype.deco)
            mtype.deco = merge(mtype).deco;

        /* Don't return merge(), because a tuple with one type has the
         * same deco as that type.
         */
        result = mtype;
    }

    override void visit(TypeSlice mtype)
    {
        //printf("TypeSlice::semantic() %s\n", toChars());
        Type tn = mtype.next.typeSemantic(loc, sc);
        //printf("next: %s\n", tn.toChars());

        Type tbn = tn.toBasetype();
        if (tbn.ty != Ttuple)
        {
            mtype.error(loc, "can only slice tuple types, not %s", tbn.toChars());
            result = Type.terror;
            return;
        }
        TypeTuple tt = cast(TypeTuple)tbn;

        mtype.lwr = semanticLength(sc, tbn, mtype.lwr);
        mtype.upr = semanticLength(sc, tbn, mtype.upr);
        mtype.lwr = mtype.lwr.ctfeInterpret();
        mtype.upr = mtype.upr.ctfeInterpret();
        if (mtype.lwr.op == TOKerror || mtype.upr.op == TOKerror)
        {
            result = Type.terror;
            return;
        }

        uinteger_t i1 = mtype.lwr.toUInteger();
        uinteger_t i2 = mtype.upr.toUInteger();
        if (!(i1 <= i2 && i2 <= tt.arguments.dim))
        {
            mtype.error(loc, "slice [%llu..%llu] is out of range of [0..%u]", i1, i2, tt.arguments.dim);
            result = Type.terror;
            return;
        }

        mtype.next = tn;
        mtype.transitive();

        auto args = new Parameters();
        args.reserve(cast(size_t)(i2 - i1));
        for (size_t i = cast(size_t)i1; i < cast(size_t)i2; i++)
        {
            Parameter arg = (*tt.arguments)[i];
            args.push(arg);
        }
        Type t = new TypeTuple(args);
        result = t.typeSemantic(loc, sc);
    }

}

/************************************
 */
// LLVM: added `extern(C++)`
extern(C++) Type merge(Type type)
{
    if (type.ty == Terror)
        return type;
    if (type.ty == Ttypeof)
        return type;
    if (type.ty == Tident)
        return type;
    if (type.ty == Tinstance)
        return type;
    if (type.ty == Taarray && !(cast(TypeAArray)type).index.merge().deco)
        return type;
    if (type.ty != Tenum && type.nextOf() && !type.nextOf().deco)
        return type;

    //printf("merge(%s)\n", toChars());
    Type t = type;
    assert(t);
    if (!type.deco)
    {
        OutBuffer buf;
        buf.reserve(32);

        mangleToBuffer(type, &buf);

        StringValue* sv = type.stringtable.update(cast(char*)buf.data, buf.offset);
        if (sv.ptrvalue)
        {
            t = cast(Type)sv.ptrvalue;
            debug
            {
                import core.stdc.stdio;
                if (!t.deco)
                    printf("t = %s\n", t.toChars());
            }
            assert(t.deco);
            //printf("old value, deco = '%s' %p\n", t.deco, t.deco);
        }
        else
        {
            sv.ptrvalue = cast(char*)(t = stripDefaultArgs(t));
            type.deco = t.deco = cast(char*)sv.toDchars();
            //printf("new value, deco = '%s' %p\n", t.deco, t.deco);
        }
    }
    return t;
}
