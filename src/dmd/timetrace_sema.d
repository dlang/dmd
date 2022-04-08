/**
Visitors for adding timetracing code to DMD's semantic analysis visitors.

This file is originally from LDC (the LLVM D compiler).

Copyright: Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
Authors:   Johan Engelen, Max Haughton
License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/timetrace_sema.d, _timetrace.d)
Documentation: https://dlang.org/phobos/dmd_timetrace.html
Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/timetrace.d
 */
module dmd.timetrace_sema;

import dmd.aggregate;
import dmd.aliasthis;
import dmd.arraytypes;
import dmd.astcodegen;
import dmd.attrib;
import dmd.blockexit;
import dmd.clone;
import dmd.compiler;
import dmd.dcast;
import dmd.dclass;
import dmd.declaration;
import dmd.denum;
import dmd.dimport;
import dmd.dinterpret;
import dmd.dmangle;
import dmd.dmodule;
import dmd.dscope;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.dversion;
import dmd.errors;
import dmd.escape;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.initsem;
import dmd.hdrgen;
import dmd.mtype;
import dmd.nogc;
import dmd.nspace;
import dmd.objc;
import dmd.opover;
import dmd.parse;
import dmd.root.filename;
import dmd.common.outbuffer;
import dmd.root.rmem;
import dmd.root.rootobject;
import dmd.semantic2;
import dmd.semantic3;
import dmd.sideeffect;
import dmd.statementsem;
import dmd.staticassert;
import dmd.tokens;
import dmd.root.utf;
import dmd.utils;
import dmd.statement;
import dmd.target;
import dmd.templateparamsem;
import dmd.typesem;
import dmd.visitor;
import dmd.common.timetrace;

template pretext(string i)
{
    static if (i == "DsymbolSemanticVisitor")
        private enum pretext = "Sema1: ";
    else static if (i == "Semantic2Visitor")
        private enum pretext = "Sema2: ";
    else static if (i == "Semantic3Visitor")
        private enum pretext = "Sema3: ";
    else
        static assert (false, "did not recognize SemaVisitor ==" ~ SemaVisitor);
}
/// Time tracing visitor for semantic analysis. Only valid to instantiate and use this visitor if time tracing is enabled.
extern(C++) final class SemanticTimeTraceVisitor(SemaVisitor) : Visitor
{
    static assert(checkFirstOverridesAllSecondOverrides!(typeof(this), SemaVisitor));

    //import std.format, std.conv;

    SemaVisitor semavisitor;

    @disable this();


    this(SemaVisitor semavisitor)
    {
        this.semavisitor = semavisitor;
    }

    alias visit = Visitor.visit;

    override void visit(Dsymbol dsym) { semavisitor.visit(dsym); }
    override void visit(ScopeDsymbol dsym) { semavisitor.visit(dsym); }
    override void visit(Declaration dsym) { semavisitor.visit(dsym); }

    override void visit(AliasThis dsym) { semavisitor.visit(dsym); }

    override void visit(AliasDeclaration dsym) { semavisitor.visit(dsym); }

    override void visit(VarDeclaration dsym) { semavisitor.visit(dsym); }

    override void visit(TypeInfoDeclaration dsym) { semavisitor.visit(dsym); }

    override void visit(Import imp)
    {
        import dmd.root.string;
        auto timeScope = TimeTraceScope(cast(string)(pretext!(SemaVisitor.stringof) ~ "Import " ~ imp.id.toChars().toDString()), cast(string) imp.toPrettyChars().toDString(), imp.loc);
        semavisitor.visit(imp);
    }

    override void visit(AttribDeclaration atd) { semavisitor.visit(atd); }

    override void visit(DeprecatedDeclaration dd) { semavisitor.visit(dd); }

    override void visit(AlignDeclaration ad) { semavisitor.visit(ad); }

    override void visit(AggregateDeclaration ad)  { semavisitor.visit(ad); }

    override void visit(AnonDeclaration scd) { semavisitor.visit(scd); }

    override void visit(PragmaDeclaration pd) { semavisitor.visit(pd); }

    override void visit(StaticIfDeclaration sid) { semavisitor.visit(sid); }

    override void visit(StaticForeachDeclaration sfd) { semavisitor.visit(sfd); }

    override void visit(CompileDeclaration cd) { semavisitor.visit(cd); }

    override void visit(CPPNamespaceDeclaration ns) { semavisitor.visit(ns); }

    override void visit(UserAttributeDeclaration uad) { semavisitor.visit(uad); }

    override void visit(StaticAssert sa) { semavisitor.visit(sa); }

    override void visit(DebugSymbol ds) { semavisitor.visit(ds); }

    override void visit(VersionSymbol vs) { semavisitor.visit(vs); }

    override void visit(AliasAssign aa) { semavisitor.visit(aa); }

    override void visit(Package pkg) { semavisitor.visit(pkg); }

    override void visit(Module m) {
        import dmd.root.string;
        auto timeScope = TimeTraceScope(cast(string)(pretext!(SemaVisitor.stringof) ~ "Module " ~ m.toPrettyChars().toDString()), m.loc);
        semavisitor.visit(m);
    }

    override void visit(EnumDeclaration ed) { semavisitor.visit(ed); }

    override void visit(EnumMember em) { semavisitor.visit(em); }

    override void visit(TemplateDeclaration tempdecl) { semavisitor.visit(tempdecl); }

    override void visit(TemplateInstance ti) { semavisitor.visit(ti); }

    override void visit(TemplateMixin tm) { semavisitor.visit(tm); }

    override void visit(Nspace ns) { semavisitor.visit(ns); }

    override void visit(FuncDeclaration funcdecl) {
        import dmd.root.string;
        auto timeScope = TimeTraceScope(cast(string)(pretext!(SemaVisitor.stringof) ~ "Func " ~ funcdecl.toChars().toDString()), cast(string) funcdecl.toPrettyChars().toDString(), funcdecl.loc);
        semavisitor.visit(funcdecl);
    }

    override void visit(CtorDeclaration ctd) { semavisitor.visit(ctd); }

    override void visit(PostBlitDeclaration pbd) { semavisitor.visit(pbd); }

    override void visit(DtorDeclaration dd) { semavisitor.visit(dd); }

    override void visit(StaticCtorDeclaration scd) { semavisitor.visit(scd); }

    override void visit(StaticDtorDeclaration sdd) { semavisitor.visit(sdd); }

    override void visit(InvariantDeclaration invd) { semavisitor.visit(invd); }

    override void visit(UnitTestDeclaration utd) { semavisitor.visit(utd); }

    override void visit(NewDeclaration nd) { semavisitor.visit(nd); }

    override void visit(StructDeclaration sd) { semavisitor.visit(sd); }

    override void visit(ClassDeclaration cldec) { semavisitor.visit(cldec); }

    override void visit(InterfaceDeclaration idec) { semavisitor.visit(idec); }

    override void visit(BitFieldDeclaration bfd) { semavisitor.visit(bfd); }
}

// Note: this is not a very careful check, but is hopefully good enough to trigger upon relevant changes to the DMD frontend.
// If the parent of First and Second already contains an override
// function and Second overrides it, this function always returns true even if First does not override it.
private bool checkFirstOverridesAllSecondOverrides(First, Second)() {
    // Due to access rights limits of __traits(derivedMembers,...) we require a newer dlang version to do the check
    static if (__VERSION__ >= 2086)
    {
        foreach (der2;  __traits(derivedMembers, Second))
        {
            foreach (mem2; __traits(getOverloads, Second, der2))
            {
                if (!__traits(isOverrideFunction, mem2))
                    continue;
                else
                {
                    bool found = false;
                    foreach (der1;  __traits(derivedMembers, First))
                    {
                        foreach (mem1; __traits(getOverloads, First, der1))
                        {
                            if (!__traits(isOverrideFunction, mem1))
                                continue;
                            else if (__traits(getVirtualIndex, mem1) == __traits(getVirtualIndex, mem2))
                            {
                                found = true;
                                break;
                            }
                        }
                        if (found) break;
                    }
                    assert (found, mem2.mangleof ~ " needs override");
                    if (!found) return false;
                }
            }
        }
    }
    return true;
}
