/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _cond.d)
 */

module dmd.cond;

import core.stdc.string;
import dmd.arraytypes;
import dmd.dmodule;
import dmd.dscope;
import dmd.dsymbol;
import dmd.errors;
import dmd.expression;
import dmd.globals;
import dmd.identifier;
import dmd.mtype;
import dmd.root.outbuffer;
import dmd.root.rootobject;
import dmd.tokens;
import dmd.utils;
import dmd.visitor;
import dmd.id;


/***********************************************************
 */
extern (C++) abstract class Condition : RootObject
{
    Loc loc;
    // 0: not computed yet
    // 1: include
    // 2: do not include
    int inc;

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
            "SH64",
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
            error(loc, "version identifier '%s' is reserved and cannot be set",
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
        if (inc == 0)
        {
            if (exp.op == TOKerror || nest > 100)
            {
                error(loc, (nest > 1000) ? "unresolvable circular static if expression" : "error evaluating static if expression");
                goto Lerror;
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
            //sc.speculative = true;       // TODO: static if (is(T U)) { /* U is available */ }
            sc.flags |= SCOPEcondition;
            sc = sc.startCTFE();
            Expression e = exp.semantic(sc);
            e = resolveProperties(sc, e);
            sc = sc.endCTFE();
            sc.pop();
            --nest;
            // Prevent repeated condition evaluation.
            // See: fail_compilation/fail7815.d
            if (inc != 0)
                return (inc == 1);
            if (!e.type.isBoolean())
            {
                if (e.type.toBasetype() != Type.terror)
                    exp.error("expression %s of type %s does not have a boolean value", exp.toChars(), e.type.toChars());
                goto Lerror;
            }
            e = e.ctfeInterpret();
            if (e.op == TOKerror)
            {
                goto Lerror;
            }
            else if (e.isBool(true))
                inc = 1;
            else if (e.isBool(false))
                inc = 2;
            else
            {
                e.error("expression %s is not constant or does not evaluate to a bool", e.toChars());
                goto Lerror;
            }
        }
        return (inc == 1);
    Lerror:
        if (!global.gag)
            inc = 2; // so we don't see the error message again
        return 0;
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
