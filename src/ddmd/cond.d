/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _cond.d)
 */

module ddmd.cond;

import core.stdc.string;
import ddmd.arraytypes;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.expression;
import ddmd.expressionsem;
import ddmd.globals;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.tokens;
import ddmd.utils;
import ddmd.visitor;
import ddmd.id;
import ddmd.statement;
import ddmd.declaration;
import ddmd.dstruct;
import ddmd.func;

/***********************************************************
 */
extern (C++) abstract class Condition : RootObject
{
    Loc loc;
    // 0: not computed yet
    // 1: include
    // 2: do not include
    int inc;

    override final DYNCAST dyncast() const
    {
        return DYNCAST.condition;
    }

    final extern (D) this(Loc loc)
    {
        this.loc = loc;
    }

    abstract Condition syntaxCopy();

    abstract int include(Scope* sc, ScopeDsymbol sds);

    DebugCondition isDebugCondition()
    {
        return null;
    }

    void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * Implements common functionality for StaticForeachDeclaration and
 * StaticForeachStatement This performs the necessary lowerings before
 * ddmd.statementsem.makeTupleForeach can be used to expand the
 * corresponding `static foreach` declaration or statement.
 */

extern (C++) final class StaticForeach : RootObject
{
    extern(D) static immutable tupleFieldName = "tuple"; // used in lowering

    Loc loc;

    /***************
     * Not `null` iff the `static foreach` is over an aggregate. In
     * this case, it contains the corresponding ForeachStatement. For
     * StaticForeachDeclaration, the body is `null`.
    */
    ForeachStatement aggrfe;
    /***************
     * Not `null` iff the `static foreach` is over a range. Exactly
     * one of the `aggrefe` and `rangefe` fields is not null. See
     * `aggrfe` field for more details.
     */
    ForeachRangeStatement rangefe;

    /***************
     * true if it is necessary to expand a tuple into multiple
     * variables (see lowerNonArrayAggregate).
     */
    bool needExpansion = false;

    final extern (D) this(Loc loc,ForeachStatement aggrfe,ForeachRangeStatement rangefe)
    in
    {
        assert(!!aggrfe ^ !!rangefe);
    }
    body
    {
        this.loc = loc;
        this.aggrfe = aggrfe;
        this.rangefe = rangefe;
    }

    StaticForeach syntaxCopy()
    {
        return new StaticForeach(
            loc,
            aggrfe ? cast(ForeachStatement)aggrfe.syntaxCopy() : null,
            rangefe ? cast(ForeachRangeStatement)rangefe.syntaxCopy() : null
        );
    }

    /*****************************************
     * Turn an aggregate which is an array into an expression tuple
     * of its elements. I.e., lower
     *     static foreach (x; [1, 2, 3, 4]) { ... }
     * to
     *     static foreach (x; AliasSeq!(1, 2, 3, 4)) { ... }
     */
    private extern(D) void lowerArrayAggregate(Scope* sc)
    {
        auto aggr = aggrfe.aggr;
        Expression el = new ArrayLengthExp(aggr.loc, aggr);
        sc = sc.startCTFE();
        el = el.semantic(sc);
        sc = sc.endCTFE();
        el = el.optimize(WANTvalue);
        el = el.ctfeInterpret();
        if (el.op == TOKint64)
        {
            dinteger_t length = el.toInteger();
            auto es = new Expressions();
            foreach (i; 0 .. length)
            {
                auto index = new IntegerExp(loc, i, Type.tsize_t);
                auto value = new IndexExp(aggr.loc, aggr, index);
                es.push(value);
            }
            aggrfe.aggr = new TupleExp(aggr.loc, es);
            aggrfe.aggr = aggrfe.aggr.semantic(sc);
            aggrfe.aggr = aggrfe.aggr.optimize(WANTvalue);
        }
        else
        {
            aggrfe.aggr = new ErrorExp();
        }
    }

    /*****************************************
     * Wrap a statement into a function literal and call it.
     *
     * Params:
     *     loc = The source location.
     *     s  = The statement.
     * Returns:
     *     AST of the expression `(){ s; }()` with location loc.
     */
    private extern(D) Expression wrapAndCall(Loc loc, Statement s)
    {
        auto tf = new TypeFunction(new Parameters(), null, 0, LINK.def, 0);
        auto fd = new FuncLiteralDeclaration(loc, loc, tf, TOKreserved, null);
        fd.fbody = s;
        auto fe = new FuncExp(loc, fd);
        auto ce = new CallExp(loc, fe, new Expressions());
        return ce;
    }

    /*****************************************
     * Create a `foreach` statement from `aggrefe/rangefe` with given
     * `foreach` variables and body `s`.
     *
     * Params:
     *     loc = The source location.
     *     parameters = The foreach variables.
     *     s = The `foreach` body.
     * Returns:
     *     `foreach (parameters; aggregate) s;` or
     *     `foreach (parameters; lower .. upper) s;`
     *     Where aggregate/lower, upper are as for the current StaticForeach.
     */
    private extern(D) Statement createForeach(Loc loc, Parameters* parameters, Statement s)
    {
        if (aggrfe)
        {
            return new ForeachStatement(loc, aggrfe.op, parameters, aggrfe.aggr.syntaxCopy(), s, loc);
        }
        else
        {
            assert(rangefe && parameters.dim == 1);
            return new ForeachRangeStatement(loc, rangefe.op, (*parameters)[0], rangefe.lwr.syntaxCopy(), rangefe.upr.syntaxCopy(), s, loc);
        }
    }

    /*****************************************
     * For a `static foreach` with multiple loop variables, the
     * aggregate is lowered to an array of tuples. As D does not have
     * built-in tuples, we need a suitable tuple type. This generates
     * a `struct` that serves as the tuple type. This type is only
     * used during CTFE and hence its typeinfo will not go to the
     * object file.
     *
     * Params:
     *     loc = The source location.
     *     e = The expressions we wish to store in the tuple.
     *     sc  = The current scope.
     * Returns:
     *     A struct type of the form
     *         struct Tuple
     *         {
     *             typeof(AliasSeq!(e)) tuple;
     *         }
     */

    private extern(D) TypeStruct createTupleType(Loc loc, Expressions* e, Scope* sc)
    {   // TODO: move to druntime?
        auto sid = Identifier.generateId("Tuple");
        auto sdecl = new StructDeclaration(loc, sid);
        sdecl.storage_class |= STCstatic;
        sdecl.members = new Dsymbols();
        auto fid = Identifier.idPool(tupleFieldName.ptr, tupleFieldName.length);
        auto ty = new TypeTypeof(loc, new TupleExp(loc, e));
        sdecl.members.push(new VarDeclaration(loc, ty, fid, null, 0));
        auto r = cast(TypeStruct)sdecl.type;
        r.vtinfo = TypeInfoStructDeclaration.create(r); // prevent typeinfo from going to object file
        return r;
    }

    /*****************************************
     * Create the AST for an instantiation of a suitable tuple type.
     *
     * Params:
     *     loc = The source location.
     *     type = A Tuple type, created with createTupleType.
     *     e = The expressions we wish to store in the tuple.
     * Returns:
     *     An AST for the expression `Tuple(e)`.
     */

    private extern(D) Expression createTuple(Loc loc, TypeStruct type, Expressions* e)
    {   // TODO: move to druntime?
        return new CallExp(loc, new TypeExp(loc, type), e);
    }


    /*****************************************
     * Lower any aggregate that is not an array to an array using a
     * regular foreach loop within CTFE.  If there are multiple
     * `static foreach` loop variables, an array of tuples is
     * generated. In thise case, the field `needExpansion` is set to
     * true to indicate that the static foreach loop expansion will
     * need to expand the tuples into multiple variables.
     *
     * For example, `static foreach (x; range) { ... }` is lowered to:
     *
     *     static foreach (x; {
     *         typeof({
     *             foreach (x; range) return x;
     *         }())[] __res;
     *         foreach (x; range) __res ~= x;
     *         return __res;
     *     }()) { ... }
     *
     * Finally, call `lowerArrayAggregate` to turn the produced
     * array into an expression tuple.
     *
     * Params:
     *     sc = The current scope.
     */

    private void lowerNonArrayAggregate(Scope* sc)
    {
        auto nvars = aggrfe ? aggrfe.parameters.dim : 1;
        auto aloc = aggrfe ? aggrfe.aggr.loc : rangefe.lwr.loc;
        // We need three sets of foreach loop variables because the
        // lowering contains three foreach loops.
        Parameters*[3] pparams = [new Parameters(), new Parameters(), new Parameters()];
        foreach (i; 0 .. nvars)
        {
            foreach (params; pparams)
            {
                auto p = aggrfe ? (*aggrfe.parameters)[i] : rangefe.prm;
                params.push(new Parameter(p.storageClass, p.type, p.ident, null));
            }
        }
        Expression[2] res;
        TypeStruct tplty = null;
        if (nvars == 1) // only one `static foreach` variable, generate identifiers.
        {
            foreach (i; 0 .. 2)
            {
                res[i] = new IdentifierExp(aloc, (*pparams[i])[0].ident);
            }
        }
        else // multiple `static foreach` variables, generate tuples.
        {
            foreach (i; 0 .. 2)
            {
                auto e = new Expressions();
                foreach (j; 0 .. pparams[0].dim)
                {
                    auto p = (*pparams[i])[j];
                    e.push(new IdentifierExp(aloc, p.ident));
                }
                if (!tplty)
                {
                    tplty = createTupleType(aloc, e, sc);
                }
                res[i] = createTuple(aloc, tplty, e);
            }
            needExpansion = true; // need to expand the tuples later
        }
        // generate remaining code for the new aggregate which is an
        // array (see documentation comment).
        auto s1 = new Statements();
        auto sfe = new Statements();
        if (tplty) sfe.push(new ExpStatement(loc, tplty.sym));
        sfe.push(new ReturnStatement(aloc, res[0]));
        s1.push(createForeach(aloc, pparams[0], new CompoundStatement(aloc, sfe)));
        s1.push(new ExpStatement(aloc, new AssertExp(aloc, new IntegerExp(aloc, 0, Type.tint32))));
        auto ety = new TypeTypeof(aloc, wrapAndCall(aloc, new CompoundStatement(aloc, s1)));
        auto aty = ety.arrayOf();
        auto idres = Identifier.generateId("__res");
        auto vard = new VarDeclaration(aloc, aty, idres, null);
        auto s2 = new Statements();
        s2.push(new ExpStatement(aloc, vard));
        auto catass = new CatAssignExp(aloc, new IdentifierExp(aloc, idres), res[1]);
        s2.push(createForeach(aloc, pparams[1], new ExpStatement(aloc, catass)));
        s2.push(new ReturnStatement(aloc, new IdentifierExp(aloc, idres)));
        auto aggr = wrapAndCall(aloc, new CompoundStatement(aloc, s2));
        sc = sc.startCTFE();
        aggr = aggr.semantic(sc);
        aggr = resolveProperties(sc, aggr);
        sc = sc.endCTFE();
        aggr = aggr.optimize(WANTvalue);
        aggr = aggr.ctfeInterpret();

        assert(!!aggrfe ^ !!rangefe);
        aggrfe = new ForeachStatement(loc, TOKforeach, pparams[2], aggr,
                                      aggrfe ? aggrfe._body : rangefe._body,
                                      aggrfe ? aggrfe.endloc : rangefe.endloc);
        rangefe = null;
        lowerArrayAggregate(sc); // finally, turn generated array into expression tuple
    }

    /*****************************************
     * Perform `static foreach` lowerings that are necessary in order
     * to finally expand the `static foreach` using
     * `ddmd.statementsem.makeTupleForeach`.
     */
    final extern(D) void prepare(Scope* sc)
    in
    {
        assert(sc);
    }
    body
    {
        if (aggrfe)
        {
            sc = sc.startCTFE();
            aggrfe.aggr = aggrfe.aggr.semantic(sc);
            sc = sc.endCTFE();
            aggrfe.aggr = aggrfe.aggr.optimize(WANTvalue);
            auto tab = aggrfe.aggr.type.toBasetype();
            if (tab.ty != Ttuple)
            {
                aggrfe.aggr = aggrfe.aggr.ctfeInterpret();
            }
        }

        if (aggrfe && aggrfe.aggr.type.toBasetype().ty == Terror)
        {
            return;
        }

        if (!ready())
        {
            if (aggrfe && aggrfe.aggr.type.toBasetype().ty == Tarray)
            {
                lowerArrayAggregate(sc);
            }
            else
            {
                lowerNonArrayAggregate(sc);
            }
        }
    }

    /*****************************************
     * Returns:
     *     `true` iff ready to call `ddmd.statementsem.makeTupleForeach`.
     */
    final extern(D) bool ready()
    {
        return aggrfe && aggrfe.aggr && aggrfe.aggr.type.toBasetype().ty == Ttuple;
    }
}

/***********************************************************
 */
extern (C++) class DVCondition : Condition
{
    uint level;
    Identifier ident;
    Module mod;

    final extern (D) this(Module mod, uint level, Identifier ident)
    {
        super(Loc());
        this.mod = mod;
        this.level = level;
        this.ident = ident;
    }

    override final Condition syntaxCopy()
    {
        return this; // don't need to copy
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DebugCondition : DVCondition
{
    /**
     * Set the global debug level
     *
     * Only called from the driver
     *
     * Params:
     *   level = Integer literal to set the global version to
     */
    static void setGlobalLevel(uint level)
    {
        global.params.debuglevel = level;
    }


    /**
     * Add an user-supplied identifier to the list of global debug identifiers
     *
     * Can be called from either the driver or a `debug = Ident;` statement.
     * Unlike version identifier, there isn't any reserved debug identifier
     * so no validation takes place.
     *
     * Params:
     *   ident = identifier to add
     */
    deprecated("Kept for C++ compat - Use the string overload instead")
    static void addGlobalIdent(const(char)* ident)
    {
        addGlobalIdent(ident[0 .. ident.strlen]);
    }

    /// Ditto
    extern(D) static void addGlobalIdent(string ident)
    {
        // Overload necessary for string literals
        addGlobalIdent(cast(const(char)[])ident);
    }


    /// Ditto
    extern(D) static void addGlobalIdent(const(char)[] ident)
    {
        if (!global.params.debugids)
            global.params.debugids = new Strings();
        global.params.debugids.push(cast(char*)ident);
    }


    /**
     * Instantiate a new `DebugCondition`
     *
     * Params:
     *   mod = Module this node belongs to
     *   level = Minimum global level this condition needs to pass.
     *           Only used if `ident` is `null`.
     *   ident = Identifier required for this condition to pass.
     *           If `null`, this conditiion will use an integer level.
     */
    extern (D) this(Module mod, uint level, Identifier ident)
    {
        super(mod, level, ident);
    }

    override int include(Scope* sc, ScopeDsymbol sds)
    {
        //printf("DebugCondition::include() level = %d, debuglevel = %d\n", level, global.params.debuglevel);
        if (inc == 0)
        {
            inc = 2;
            bool definedInModule = false;
            if (ident)
            {
                if (findCondition(mod.debugids, ident))
                {
                    inc = 1;
                    definedInModule = true;
                }
                else if (findCondition(global.params.debugids, ident))
                    inc = 1;
                else
                {
                    if (!mod.debugidsNot)
                        mod.debugidsNot = new Strings();
                    mod.debugidsNot.push(ident.toChars());
                }
            }
            else if (level <= global.params.debuglevel || level <= mod.debuglevel)
                inc = 1;
            if (!definedInModule)
                printDepsConditional(sc, this, "depsDebug ");
        }
        return (inc == 1);
    }

    override DebugCondition isDebugCondition()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }

    override const(char)* toChars()
    {
        return ident ? ident.toChars() : "debug".ptr;
    }
}

/**
 * Node to represent a version condition
 *
 * A version condition is of the form:
 * ---
 * version (Identifier)
 * ---
 * In user code.
 * This class also provides means to add version identifier
 * to the list of global (cross module) identifiers.
 */
extern (C++) final class VersionCondition : DVCondition
{
    /**
     * Set the global version level
     *
     * Only called from the driver
     *
     * Params:
     *   level = Integer literal to set the global version to
     */
    static void setGlobalLevel(uint level)
    {
        global.params.versionlevel = level;
    }

    /**
     * Check if a given version identifier is reserved.
     *
     * Reserved identifier are the one documented below or
     * those starting with 'D_'.
     *
     * Params:
     *   ident = identifier being checked
     *
     * Returns:
     *   `true` if it is reserved, `false` otherwise
     */
    extern(D) private static bool isReserved(const(char)[] ident)
    {
        // This list doesn't include "D_*" versions, see the last return
        static immutable string[] reserved =
        [
            "DigitalMars",
            "GNU",
            "LDC",
            "SDC",
            "Windows",
            "Win32",
            "Win64",
            "linux",
            "OSX",
            "iOS",
            "TVOS",
            "WatchOS",
            "FreeBSD",
            "OpenBSD",
            "NetBSD",
            "DragonFlyBSD",
            "BSD",
            "Solaris",
            "Posix",
            "AIX",
            "Haiku",
            "SkyOS",
            "SysV3",
            "SysV4",
            "Hurd",
            "Android",
            "PlayStation",
            "PlayStation4",
            "Cygwin",
            "MinGW",
            "FreeStanding",
            "X86",
            "X86_64",
            "ARM",
            "ARM_Thumb",
            "ARM_SoftFloat",
            "ARM_SoftFP",
            "ARM_HardFloat",
            "AArch64",
            "Epiphany",
            "PPC",
            "PPC_SoftFloat",
            "PPC_HardFloat",
            "PPC64",
            "IA64",
            "MIPS32",
            "MIPS64",
            "MIPS_O32",
            "MIPS_N32",
            "MIPS_O64",
            "MIPS_N64",
            "MIPS_EABI",
            "MIPS_SoftFloat",
            "MIPS_HardFloat",
            "NVPTX",
            "NVPTX64",
            "RISCV32",
            "RISCV64",
            "SPARC",
            "SPARC_V8Plus",
            "SPARC_SoftFloat",
            "SPARC_HardFloat",
            "SPARC64",
            "S390",
            "S390X",
            "SystemZ",
            "HPPA",
            "HPPA64",
            "SH",
            "Alpha",
            "Alpha_SoftFloat",
            "Alpha_HardFloat",
            "LittleEndian",
            "BigEndian",
            "ELFv1",
            "ELFv2",
            "CRuntime_Bionic",
            "CRuntime_DigitalMars",
            "CRuntime_Glibc",
            "CRuntime_Microsoft",
            "CRuntime_Musl",
            "CRuntime_UClibc",
            "unittest",
            "assert",
            "all",
            "none"
        ];
        foreach (r; reserved)
        {
            if (ident == r)
                return true;
        }
        return (ident.length >= 2 && ident[0 .. 2] == "D_");
    }

    /**
     * Raises an error if a version identifier is reserved.
     *
     * Called when setting a version identifier, e.g. `-version=identifier`
     * parameter to the compiler or `version = Foo` in user code.
     *
     * Params:
     *   loc = Where the identifier is set
     *   ident = identifier being checked (ident[$] must be '\0')
     */
    extern(D) static void checkReserved(Loc loc, const(char)[] ident)
    {
        if (isReserved(ident))
            error(loc, "version identifier `%s` is reserved and cannot be set",
                  ident.ptr);
    }

    /**
     * Add an user-supplied global identifier to the list
     *
     * Only called from the driver for `-version=Ident` parameters.
     * Will raise an error if the identifier is reserved.
     *
     * Params:
     *   ident = identifier to add
     */
    deprecated("Kept for C++ compat - Use the string overload instead")
    static void addGlobalIdent(const(char)* ident)
    {
        addGlobalIdent(ident[0 .. ident.strlen]);
    }

    /// Ditto
    extern(D) static void addGlobalIdent(string ident)
    {
        // Overload necessary for string literals
        addGlobalIdent(cast(const(char)[])ident);
    }


    /// Ditto
    extern(D) static void addGlobalIdent(const(char)[] ident)
    {
        checkReserved(Loc(), ident);
        addPredefinedGlobalIdent(ident);
    }

    /**
     * Add any global identifier to the list, without checking
     * if it's predefined
     *
     * Only called from the driver after platform detection,
     * and internally.
     *
     * Params:
     *   ident = identifier to add (ident[$] must be '\0')
     */
    deprecated("Kept for C++ compat - Use the string overload instead")
    static void addPredefinedGlobalIdent(const(char)* ident)
    {
        addPredefinedGlobalIdent(ident[0 .. ident.strlen]);
    }

    /// Ditto
    extern(D) static void addPredefinedGlobalIdent(string ident)
    {
        // Forward: Overload necessary for string literal
        addPredefinedGlobalIdent(cast(const(char)[])ident);
    }


    /// Ditto
    extern(D) static void addPredefinedGlobalIdent(const(char)[] ident)
    {
        if (!global.params.versionids)
            global.params.versionids = new Strings();
        global.params.versionids.push(cast(char*)ident);
    }

    /**
     * Instantiate a new `VersionCondition`
     *
     * Params:
     *   mod = Module this node belongs to
     *   level = Minimum global level this condition needs to pass.
     *           Only used if `ident` is `null`.
     *   ident = Identifier required for this condition to pass.
     *           If `null`, this conditiion will use an integer level.
     */
    extern (D) this(Module mod, uint level, Identifier ident)
    {
        super(mod, level, ident);
    }

    override int include(Scope* sc, ScopeDsymbol sds)
    {
        //printf("VersionCondition::include() level = %d, versionlevel = %d\n", level, global.params.versionlevel);
        //if (ident) printf("\tident = '%s'\n", ident.toChars());
        if (inc == 0)
        {
            inc = 2;
            bool definedInModule = false;
            if (ident)
            {
                if (findCondition(mod.versionids, ident))
                {
                    inc = 1;
                    definedInModule = true;
                }
                else if (findCondition(global.params.versionids, ident))
                    inc = 1;
                else
                {
                    if (!mod.versionidsNot)
                        mod.versionidsNot = new Strings();
                    mod.versionidsNot.push(ident.toChars());
                }
            }
            else if (level <= global.params.versionlevel || level <= mod.versionlevel)
                inc = 1;
            if (!definedInModule &&
                (!ident || (!isReserved(ident.toString()) && ident != Id._unittest && ident != Id._assert)))
            {
                printDepsConditional(sc, this, "depsVersion ");
            }
        }
        return (inc == 1);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }

    override const(char)* toChars()
    {
        return ident ? ident.toChars() : "version".ptr;
    }
}

/***********************************************************
 */
extern (C++) final class StaticIfCondition : Condition
{
    Expression exp;
    int nest;           // limit circular dependencies

    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Condition syntaxCopy()
    {
        return new StaticIfCondition(loc, exp.syntaxCopy());
    }

    override int include(Scope* sc, ScopeDsymbol sds)
    {
        version (none)
        {
            printf("StaticIfCondition::include(sc = %p, sds = %p) this=%p inc = %d\n", sc, sds, this, inc);
            if (sds)
            {
                printf("\ts = '%s', kind = %s\n", sds.toChars(), sds.kind());
            }
        }

        int errorReturn()
        {
            if (!global.gag)
                inc = 2; // so we don't see the error message again
            return 0;
        }

        if (inc == 0)
        {
            if (exp.op == TOKerror || nest > 100)
            {
                error(loc, (nest > 1000) ? "unresolvable circular static if expression" : "error evaluating static if expression");
                return errorReturn();
            }
            if (!sc)
            {
                error(loc, "static if conditional cannot be at global scope");
                inc = 2;
                return 0;
            }

            ++nest;
            sc = sc.push(sc.scopesym);
            sc.sds = sds; // sds gets any addMember()

            import ddmd.staticcond;
            bool errors;
            bool result = evalStaticCondition(sc, exp, exp, errors);
            sc.pop();
            --nest;
            // Prevent repeated condition evaluation.
            // See: fail_compilation/fail7815.d
            if (inc != 0)
                return (inc == 1);
            if (errors)
                return errorReturn();
            if (result)
                inc = 1;
            else
                inc = 2;
        }
        return (inc == 1);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }

    override const(char)* toChars()
    {
        return exp ? exp.toChars() : "static if".ptr;
    }
}

extern (C++) int findCondition(Strings* ids, Identifier ident)
{
    if (ids)
    {
        for (size_t i = 0; i < ids.dim; i++)
        {
            const(char)* id = (*ids)[i];
            if (strcmp(id, ident.toChars()) == 0)
                return true;
        }
    }
    return false;
}

// Helper for printing dependency information
private void printDepsConditional(Scope* sc, DVCondition condition, const(char)[] depType)
{
    if (!global.params.moduleDeps || global.params.moduleDepsFile)
        return;
    OutBuffer* ob = global.params.moduleDeps;
    Module imod = sc ? sc.instantiatingModule() : condition.mod;
    if (!imod)
        return;
    ob.writestring(depType);
    ob.writestring(imod.toPrettyChars());
    ob.writestring(" (");
    escapePath(ob, imod.srcfile.toChars());
    ob.writestring(") : ");
    if (condition.ident)
        ob.printf("%s\n", condition.ident.toChars());
    else
        ob.printf("%d\n", condition.level);
}
