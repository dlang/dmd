// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.cond;

import core.stdc.string;
import ddmd.arraytypes;
import ddmd.dmodule;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.expression;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.identifier;
import ddmd.mars;
import ddmd.mtype;
import ddmd.root.outbuffer;
import ddmd.tokens;
import ddmd.visitor;

extern (C++) class Condition
{
public:
    Loc loc;
    // 0: not computed yet
    // 1: include
    // 2: do not include
    int inc;

    /* ============================================================ */
    final extern (D) this(Loc loc)
    {
        this.loc = loc;
        inc = 0;
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

extern (C++) class DVCondition : Condition
{
public:
    uint level;
    Identifier ident;
    Module mod;

    /* ============================================================ */
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

extern (C++) final class DebugCondition : DVCondition
{
public:
    /* ============================================================ */
    static void setGlobalLevel(uint level)
    {
        global.params.debuglevel = level;
    }

    static void addGlobalIdent(const(char)* ident)
    {
        if (!global.params.debugids)
            global.params.debugids = new Strings();
        global.params.debugids.push(cast(char*)ident);
    }

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
}

extern (C++) final class VersionCondition : DVCondition
{
public:
    /* ============================================================ */
    static void setGlobalLevel(uint level)
    {
        global.params.versionlevel = level;
    }

    static bool isPredefined(const(char)* ident)
    {
        static __gshared const(char)** reserved =
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
            "SPARC",
            "SPARC_V8Plus",
            "SPARC_SoftFloat",
            "SPARC_HardFloat",
            "SPARC64",
            "S390",
            "S390X",
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
            "CRuntime_Digitalmars",
            "CRuntime_Glibc",
            "CRuntime_Microsoft",
            "D_Coverage",
            "D_Ddoc",
            "D_InlineAsm_X86",
            "D_InlineAsm_X86_64",
            "D_LP64",
            "D_X32",
            "D_HardFloat",
            "D_SoftFloat",
            "D_PIC",
            "D_SIMD",
            "D_Version2",
            "D_NoBoundsChecks",
            "unittest",
            "assert",
            "all",
            "none",
            null
        ];
        for (uint i = 0; reserved[i]; i++)
        {
            if (strcmp(ident, reserved[i]) == 0)
                return true;
        }
        if (ident[0] == 'D' && ident[1] == '_')
            return true;
        return false;
    }

    static void checkPredefined(Loc loc, const(char)* ident)
    {
        if (isPredefined(ident))
            error(loc, "version identifier '%s' is reserved and cannot be set", ident);
    }

    static void addGlobalIdent(const(char)* ident)
    {
        checkPredefined(Loc(), ident);
        addPredefinedGlobalIdent(ident);
    }

    static void addPredefinedGlobalIdent(const(char)* ident)
    {
        if (!global.params.versionids)
            global.params.versionids = new Strings();
        global.params.versionids.push(cast(char*)ident);
    }

    extern (D) this(Module mod, uint level, Identifier ident)
    {
        super(mod, level, ident);
    }

    override int include(Scope* sc, ScopeDsymbol sds)
    {
        //printf("VersionCondition::include() level = %d, versionlevel = %d\n", level, global.params.versionlevel);
        //if (ident) printf("\tident = '%s'\n", ident->toChars());
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
            if (!definedInModule && (!ident || (!isPredefined(ident.toChars()) && ident != Identifier.idPool(Token.toChars(TOKunittest)) && ident != Identifier.idPool(Token.toChars(TOKassert)))))
                printDepsConditional(sc, this, "depsVersion ");
        }
        return (inc == 1);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class StaticIfCondition : Condition
{
public:
    Expression exp;
    int nest; // limit circular dependencies

    /**************************** StaticIfCondition *******************************/
    extern (D) this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
        this.nest = 0;
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
            //sc->speculative = true;       // TODO: static if (is(T U)) { /* U is available */ }
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
extern (C++) void printDepsConditional(Scope* sc, DVCondition condition, const(char)* depType)
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
