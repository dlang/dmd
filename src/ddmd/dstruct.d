/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _dstruct.d)
 */

module ddmd.dstruct;

import core.stdc.stdio;
import ddmd.aggregate;
import ddmd.argtypes;
import ddmd.arraytypes;
import ddmd.clone;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.opover;
import ddmd.tokens;
import ddmd.typinf;
import ddmd.visitor;

/***************************************
 * Search sd for a member function of the form:
 *   `extern (D) string toString();`
 * Params:
 *   sd = struct declaration to search
 * Returns:
 *   FuncDeclaration of `toString()` if found, `null` if not
 */
extern (C++) FuncDeclaration search_toString(StructDeclaration sd)
{
    Dsymbol s = search_function(sd, Id.tostring);
    FuncDeclaration fd = s ? s.isFuncDeclaration() : null;
    if (fd)
    {
        static __gshared TypeFunction tftostring;
        if (!tftostring)
        {
            tftostring = new TypeFunction(null, Type.tstring, 0, LINKd);
            tftostring = tftostring.merge().toTypeFunction();
        }
        fd = fd.overloadExactMatch(tftostring);
    }
    return fd;
}

/***************************************
 * Request additional semantic analysis for TypeInfo generation.
 * Params:
 *      sc = context
 *      t = type that TypeInfo is being generated for
 */
extern (C++) void semanticTypeInfo(Scope* sc, Type t)
{
    extern (C++) final class FullTypeInfoVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        Scope* sc;

        override void visit(Type t)
        {
            Type tb = t.toBasetype();
            if (tb != t)
                tb.accept(this);
        }

        override void visit(TypeNext t)
        {
            if (t.next)
                t.next.accept(this);
        }

        override void visit(TypeBasic t)
        {
        }

        override void visit(TypeVector t)
        {
            t.basetype.accept(this);
        }

        override void visit(TypeAArray t)
        {
            t.index.accept(this);
            visit(cast(TypeNext)t);
        }

        override void visit(TypeFunction t)
        {
            visit(cast(TypeNext)t);
            // Currently TypeInfo_Function doesn't store parameter types.
        }

        override void visit(TypeStruct t)
        {
            //printf("semanticTypeInfo.visit(TypeStruct = %s)\n", t.toChars());
            StructDeclaration sd = t.sym;

            /* Step 1: create TypeInfoDeclaration
             */
            if (!sc) // inline may request TypeInfo.
            {
                Scope scx;
                scx._module = sd.getModule();
                getTypeInfoType(t, &scx);
                sd.requestTypeInfo = true;
            }
            else if (!sc.minst)
            {
                // don't yet have to generate TypeInfo instance if
                // the typeid(T) expression exists in speculative scope.
            }
            else
            {
                getTypeInfoType(t, sc);
                sd.requestTypeInfo = true;

                // https://issues.dlang.org/show_bug.cgi?id=15149
                // if the typeid operand type comes from a
                // result of auto function, it may be yet speculative.
                unSpeculative(sc, sd);
            }

            /* Step 2: If the TypeInfo generation requires sd.semantic3, run it later.
             * This should be done even if typeid(T) exists in speculative scope.
             * Because it may appear later in non-speculative scope.
             */
            if (!sd.members)
                return; // opaque struct
            if (!sd.xeq && !sd.xcmp && !sd.postblit && !sd.dtor && !sd.xhash && !search_toString(sd))
                return; // none of TypeInfo-specific members

            // If the struct is in a non-root module, run semantic to get
            // correct symbols for the member function.
            if (sd.semanticState == SemState.Done)
            {
                // semantic is already done
            }
            else if (TemplateInstance ti = sd.isInstantiated())
            {
                if (ti.minst && !ti.minst.isRoot())
                    Module.addDeferredSemantic(sd); // FWDREF FIXME: full semantic shouldn't be necessary, we only want the mangling
            }
            else
            {
                if (sd.inNonRoot())
                {
                    //printf("deferred sem3 for TypeInfo - sd = %s, inNonRoot = %d\n", sd.toChars(), sd.inNonRoot());
                    Module.addDeferredSemantic(sd);
                }
            }
        }

        override void visit(TypeClass t)
        {
        }

        override void visit(TypeTuple t)
        {
            if (t.arguments)
            {
                for (size_t i = 0; i < t.arguments.dim; i++)
                {
                    Type tprm = (*t.arguments)[i].type;
                    if (tprm)
                        tprm.accept(this);
                }
            }
        }
    }

    if (sc)
    {
        if (!sc.func)
            return;
        if (sc.intypeof)
            return;
        if (sc.flags & (SCOPEctfe | SCOPEcompile))
            return;
    }

    scope FullTypeInfoVisitor v = new FullTypeInfoVisitor();
    v.sc = sc;
    t.accept(v);
}

struct StructFlags
{
    alias Type = uint;

    enum Enum : int
    {
        hasPointers = 0x1, // NB: should use noPointers as in ClassFlags
    }

    alias hasPointers = Enum.hasPointers;
}

enum StructPOD : int
{
    ISPODno,    // struct is not POD
    ISPODyes,   // struct is POD
    ISPODfwd,   // POD not yet computed
}

alias ISPODno = StructPOD.ISPODno;
alias ISPODyes = StructPOD.ISPODyes;
alias ISPODfwd = StructPOD.ISPODfwd;

/***********************************************************
 * All `struct` declarations are an instance of this.
 */
extern (C++) class StructDeclaration : AggregateDeclaration
{
    int zeroInit;               // !=0 if initialize with 0 fill
    bool hasIdentityAssign;     // true if has identity opAssign
    bool hasIdentityEquals;     // true if has identity opEquals
    FuncDeclarations postblits; // Array of postblit functions
    FuncDeclaration postblit;   // aggregate postblit

    FuncDeclaration xeq;        // TypeInfo_Struct.xopEquals
    FuncDeclaration xcmp;       // TypeInfo_Struct.xopCmp
    FuncDeclaration xhash;      // TypeInfo_Struct.xtoHash
    extern (C++) static __gshared FuncDeclaration xerreq;   // object.xopEquals
    extern (C++) static __gshared FuncDeclaration xerrcmp;  // object.xopCmp

    structalign_t alignment;    // alignment applied outside of the struct
    StructPOD ispod;            // if struct is POD

    // For 64 bit Efl function call/return ABI
    Type arg1type;
    Type arg2type;

    // Even if struct is defined as non-root symbol, some built-in operations
    // (e.g. TypeidExp, NewExp, ArrayLiteralExp, etc) request its TypeInfo.
    // For those, today TypeInfo_Struct is generated in COMDAT.
    bool requestTypeInfo;

    final extern (D) this(Loc loc, Identifier id)
    {
        super(loc, id);
        zeroInit = 0; // assume false until we do semantic processing
        ispod = ISPODfwd;
        // For forward references
        type = new TypeStruct(this);
        if (id == Id.ModuleInfo && !Module.moduleinfo)
            Module.moduleinfo = this;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        StructDeclaration sd =
            s ? cast(StructDeclaration)s
              : new StructDeclaration(loc, ident);
        return ScopeDsymbol.syntaxCopy(sd);
    }

    override void setScope(Scope* sc)
    {
        super.setScope(sc);

        if (!parent)
        {
            assert(sc.parent && sc.func);
            parent = sc.parent;
        }
        assert(parent && !isAnonymous());

        protection = sc.protection;

        alignment = sc.alignment();

        storage_class |= sc.stc;
        if (storage_class & STCdeprecated)
            isdeprecated = true;
        if (storage_class & STCabstract)
            error("structs, unions cannot be abstract");
    }

    override void semanticType()
    {
        if (this.errors)
            type = Type.terror;

        type = type.addSTC(_scope.stc | storage_class);
        type = type.semantic(loc, _scope);

        if (type.ty == Tstruct && (cast(TypeStruct)type).sym != this)
        {
            auto ti = (cast(TypeStruct)type).sym.isInstantiated();
            if (ti && isError(ti)) // FWDREF FIXME hmm, how could we possibly have an invalid struct that becomes valid? This was possible before with forward referencing errors when the order of declarations and calls mattered, but not anymore
                (cast(TypeStruct)type).sym = this;
        }

        version (none)
        {
            if (type.ty == Tstruct && (cast(TypeStruct)type).sym != this)
            {
                printf("this = %p %s\n", this, this.toChars());
                printf("type = %d sym = %p\n", type.ty, (cast(TypeStruct)type).sym);
            }
        }
        assert(type.ty != Tstruct || (cast(TypeStruct)type).sym == this);
    }

    override void determineMembers()
    {
        if (membersState == SemState.Done)
            return;

        super.determineMembers();
        if (membersState != SemState.Done)
            return;

        membersState = SemState.In;
        // we still have to generate the special methods (which depend upon the field types) and push them to .members

        determineFields();
        if (type.ty == Terror)
            return;
        if (fieldsState != SemState.Done)
        {
            membersState = SemState.Defer;
            return;
        }

        /* Following special member functions creation needs semantic analysis
         * completion of sub-structs in each field types. For example, buildDtor
         * needs to check existence of elaborate dtor in type of each fields.
         * See the case in compilable/test14838.d
         */
        foreach (v; fields)
        {
            Type tb = v.type.baseElemOf();
            if (tb.ty != Tstruct)
                continue;
            auto sd = (cast(TypeStruct)tb).sym;
            sd.determineMembers();
            if (sd.membersState == SemState.Done)
                continue;

            membersState = SemState.Defer;
            //printf("\tdeferring %s\n", toChars());
            return;
        }

        auto sc2 = newScope();
        scope(exit) sc2.pop();

        /* Look for special member functions.
         */
        aggNew = cast(NewDeclaration)search(Loc(), Id.classNew);
        aggDelete = cast(DeleteDeclaration)search(Loc(), Id.classDelete);

        // Look for the constructor
        ctor = searchCtor();

        dtor = buildDtor(this, sc2);
        postblit = buildPostBlit(this, sc2);

        buildOpAssign(this, sc2);
        buildOpEquals(this, sc2);

        xeq = buildXopEquals(this, sc2);
        xcmp = buildXopCmp(this, sc2);
        xhash = buildXtoHash(this, sc2);

        inv = buildInv(this, sc2);

        membersState = SemState.Done;
    }

    override final void semantic()
    {
        //printf("StructDeclaration::semantic(this=%p, '%s', sizeok = %d)\n", this, toPrettyChars(), sizeok);

        if (semanticState == SemState.Done)
            return;

        int errors = global.errors;
        bool checkErrors()
        {
            if (global.errors != errors || this.errors)
            {
                type = Type.terror;
                this.errors = true;
                semanticState = SemState.Done;
                return true;
            }
            return false;
        }

        super.semantic();

        if (checkErrors() || semanticState != SemState.Done)
            return;

        if (ctor)
        {
            Dsymbol scall = search(Loc(), Id.call);
            if (scall)
            {
                uint xerrors = global.startGagging();
                auto sc = _scope.push();
                sc.tinst = null;
                sc.minst = null;
                auto fcall = resolveFuncCall(loc, sc, scall, null, null, null, 1);
                sc = sc.pop();
                global.endGagging(xerrors);

                if (fcall && fcall.isStatic())
                {
                    error(fcall.loc, "static opCall is hidden by constructors and can never be called");
                    errorSupplemental(fcall.loc, "Please use a factory method instead, or replace all constructors with static opCall.");
                }
            }
        }

        checkErrors();

        void defer() { semanticState = SemState.Defer; }
        semanticState = SemState.In;

        determineSize(loc);
        if (sizeState == SemState.Defer)
            return defer();

        semanticTypeInfoMembers();
        genRTInfo();

        semanticState = SemState.Done;
    }

    final void semanticTypeInfoMembers()
    {
        if (xeq &&
            xeq.bodyState != SemState.Done)
        {
            uint errors = global.startGagging();
            xeq.semanticBody();
            if (global.endGagging(errors))
                xeq = xerreq;
        }

        if (xcmp &&
            xcmp.bodyState != SemState.Done)
        {
            uint errors = global.startGagging();
            xcmp.semanticBody();
            if (global.endGagging(errors))
                xcmp = xerrcmp;
        }

        FuncDeclaration ftostr = search_toString(this);
        if (ftostr &&
            ftostr.bodyState != SemState.Done)
        {
            ftostr.semanticBody();
        }

        if (xhash &&
            xhash.bodyState != SemState.Done)
        {
            xhash.semanticBody();
        }

        if (postblit &&
            postblit.bodyState != SemState.Done)
        {
            postblit.semanticBody();
        }

        if (dtor &&
            dtor.bodyState != SemState.Done)
        {
            dtor.semanticBody();
        }
    }

    override const(char)* kind() const
    {
        return "struct";
    }

    override final void finalizeSize()
    {
        //printf("StructDeclaration::finalizeSize() %s, sizeok = %d\n", toChars(), sizeok);
        assert(sizeState != SemState.Done);
        assert(fieldsState == SemState.Done);

        // Set the offsets of the fields and determine the size of the struct
        uint offset = 0;
        bool isunion = isUnionDeclaration() !is null;
        foreach (s; fields)
            s.setFieldOffset(this, &offset, isunion);
        if (type.ty == Terror)
            return;

        // 0 sized struct's are set to 1 byte
        if (structsize == 0)
        {
            structsize = 1;
            alignsize = 1;
        }

        // Round struct size up to next alignsize boundary.
        // This will ensure that arrays of structs will get their internals
        // aligned properly.
        if (alignment == STRUCTALIGN_DEFAULT)
            structsize = (structsize + alignsize - 1) & ~(alignsize - 1);
        else
            structsize = (structsize + alignment - 1) & ~(alignment - 1);

        //printf("-StructDeclaration::finalizeSize() %s, fields.dim = %d, structsize = %d\n", toChars(), fields.dim, structsize);

        if (errors)
            return;

        // Calculate fields[i].overlapped
        if (checkOverlappedFields())
        {
            errors = true;
            return;
        }

        // Determine if struct is all zeros or not
        zeroInit = 1;
        foreach (vd; fields)
        {
            if (vd._init)
            {
                // Should examine init to see if it is really all 0's
                zeroInit = 0;
                break;
            }
            else if (!vd.type.isZeroInit(loc))
            {
                zeroInit = 0;
                break;
            }
        }

        auto tt = toArgTypes(type);
        size_t dim = tt.arguments.dim;
        if (dim >= 1)
        {
            assert(dim <= 2);
            arg1type = (*tt.arguments)[0].type;
            if (dim == 2)
                arg2type = (*tt.arguments)[1].type;
        }
    }

    /***************************************
     * Fit elements[] to the corresponding types of the struct's fields.
     *
     * Params:
     *      loc = location to use for error messages
     *      sc = context
     *      elements = explicit arguments used to construct object
     *      stype = the constructed object type.
     * Returns:
     *      false if any errors occur,
     *      otherwise true and elements[] are rewritten for the output.
     */
    final bool fit(Loc loc, Scope* sc, Expressions* elements, Type stype)
    {
        if (!elements)
            return true;

        size_t nfields = fields.dim - isNested();
        size_t offset = 0;
        for (size_t i = 0; i < elements.dim; i++)
        {
            Expression e = (*elements)[i];
            if (!e)
                continue;

            e = resolveProperties(sc, e);
            if (i >= nfields)
            {
                if (i == fields.dim - 1 && isNested() && e.op == TOKnull)
                {
                    // CTFE sometimes creates null as hidden pointer; we'll allow this.
                    continue;
                }
                .error(loc, "more initializers than fields (%d) of %s", nfields, toChars());
                return false;
            }
            VarDeclaration v = fields[i];
            if (v.offset < offset)
            {
                .error(loc, "overlapping initialization for %s", v.toChars());
                return false;
            }
            offset = cast(uint)(v.offset + v.type.size());

            Type t = v.type;
            if (stype)
                t = t.addMod(stype.mod);
            Type origType = t;
            Type tb = t.toBasetype();

            /* Look for case of initializing a static array with a too-short
             * string literal, such as:
             *  char[5] foo = "abc";
             * Allow this by doing an explicit cast, which will lengthen the string
             * literal.
             */
            if (e.op == TOKstring && tb.ty == Tsarray)
            {
                StringExp se = cast(StringExp)e;
                Type typeb = se.type.toBasetype();
                TY tynto = tb.nextOf().ty;
                if (!se.committed &&
                    (typeb.ty == Tarray || typeb.ty == Tsarray) &&
                    (tynto == Tchar || tynto == Twchar || tynto == Tdchar) &&
                    se.numberOfCodeUnits(tynto) < (cast(TypeSArray)tb).dim.toInteger())
                {
                    e = se.castTo(sc, t);
                    goto L1;
                }
            }

            while (!e.implicitConvTo(t) && tb.ty == Tsarray)
            {
                /* Static array initialization, as in:
                 *  T[3][5] = e;
                 */
                t = tb.nextOf();
                tb = t.toBasetype();
            }
            if (!e.implicitConvTo(t))
                t = origType; // restore type for better diagnostic

            e = e.implicitCastTo(sc, t);
        L1:
            if (e.op == TOKerror)
                return false;

            (*elements)[i] = doCopyOrMove(sc, e);
        }
        return true;
    }

    /***************************************
     * Determine if struct is POD (Plain Old Data).
     *
     * POD is defined as:
     *      $(OL
     *      $(LI not nested)
     *      $(LI no postblits, destructors, or assignment operators)
     *      $(LI no `ref` fields or fields that are themselves non-POD)
     *      )
     * The idea being these are compatible with C structs.
     *
     * Returns:
     *     true if struct is POD
     */
    final bool isPOD()
    {
        // If we've already determined whether this struct is POD.
        if (ispod != ISPODfwd)
            return (ispod == ISPODyes);

        ispod = ISPODyes;

        if (enclosing || postblit || dtor)
            ispod = ISPODno;

        // Recursively check all fields are POD.
        for (size_t i = 0; i < fields.dim; i++)
        {
            VarDeclaration v = fields[i];
            if (v.storage_class & STCref)
            {
                ispod = ISPODno;
                break;
            }

            Type tv = v.type.baseElemOf();
            if (tv.ty == Tstruct)
            {
                TypeStruct ts = cast(TypeStruct)tv;
                StructDeclaration sd = ts.sym;
                if (!sd.isPOD())
                {
                    ispod = ISPODno;
                    break;
                }
            }
        }

        return (ispod == ISPODyes);
    }

    override final inout(StructDeclaration) isStructDeclaration() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * Unions are a variation on structs.
 */
extern (C++) final class UnionDeclaration : StructDeclaration
{
    extern (D) this(Loc loc, Identifier id)
    {
        super(loc, id);
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        auto ud = new UnionDeclaration(loc, ident);
        return StructDeclaration.syntaxCopy(ud);
    }

    override const(char)* kind() const
    {
        return "union";
    }

    override inout(UnionDeclaration) isUnionDeclaration() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
