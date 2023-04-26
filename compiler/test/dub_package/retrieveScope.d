#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../../.."
versions "CallbackAPI"
+/
/*
 * This file contains an example of how to retrieve the scope of a statement.
 * First, the callback system is used. This, however, will not work for fields
 * of structs or classes, which is why the visitor will cover this corner case
 */

import core.stdc.stdarg;
import core.stdc.string;

import std.conv;
import std.string;
import std.algorithm.sorting;
import std.algorithm.mutation : SwapStrategy;
import std.path : dirName;

import dmd.errors;
import dmd.frontend;
import dmd.console;
import dmd.arraytypes;
import dmd.compiler;
import dmd.dmodule;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.location;
import dmd.semantic2;
import dmd.semantic3;
import dmd.statement;
import dmd.visitor;
import dmd.dscope;
import dmd.denum;
import dmd.nspace;
import dmd.dstruct;
import dmd.dclass;
import dmd.globals;

import std.stdio : writeln;

private bool isBefore(Loc loc1, Loc loc2)
{
    return loc1.linnum != loc2.linnum? loc1.linnum < loc2.linnum
                                    : loc1.charnum < loc2.charnum;
}

private struct CallbackHelper {
    static Loc cursorLoc;
    static Scope *scp;

    static extern (C++) void statementSem(Statement s, Scope *sc) {
        if (s.loc.linnum == cursorLoc.linnum
                && strcmp(s.loc.filename, cursorLoc.filename) == 0) {
            sc.setNoFree();
            scp = sc;
        }
    }
};

int main()
{
    auto dmdParentDir = dirName(dirName(dirName(dirName(__FILE_FULL_PATH__))));
    global.path = new Strings();
    global.path.push((dmdParentDir ~ "/phobos").ptr);
    global.path.push((dmdParentDir ~ "/dmd/druntime/import").ptr);

    /* comment for error output in parsing & semantic */
    diagnosticHandler = (const ref Loc location,
                            Color headerColor,
                            const(char)* header,
                            const(char)* messageFormat,
                            va_list args,
                            const(char)* prefix1,
                            const(char)* prefix2) => true;
    global.gag = 1;
    initDMD(diagnosticHandler);

    Module m = parseModule(__FILE_FULL_PATH__ ~ "/testfiles/correct.d").module_;
    m.importedFrom = m; // m.isRoot() == true

    CallbackHelper.cursorLoc = Loc(to!string(m.srcfile).ptr, 22, 10);

    Compiler.onStatementSemanticStart = &CallbackHelper.statementSem;

    m.importAll(null);

    // semantic
    m.dsymbolSemantic(null);
    Module.runDeferredSemantic();

    m.semantic2(null);
    Module.runDeferredSemantic2();

    m.semantic3(null);
    Module.runDeferredSemantic3();


    Dsymbol[] symbols;

    // if scope could not be retrieved through the callback, then traverse AST
    if (!CallbackHelper.scp) {
        auto visitor = new DsymbolsScopeRetrievingVisitor(CallbackHelper.cursorLoc);
        m.accept(visitor);

        symbols = visitor.symbols;
    }

    while (CallbackHelper.scp) {
        if (CallbackHelper.scp.scopesym && CallbackHelper.scp.scopesym.symtab)
            foreach (x; CallbackHelper.scp.scopesym.symtab.tab.asRange()) {
                symbols ~= x.value;
            }
        CallbackHelper.scp = CallbackHelper.scp.enclosing;
    }

    sort!("to!string(a.ident) < to!string(b.ident)", SwapStrategy.stable)(symbols);

    foreach (sym; symbols) {
        writeln(sym.ident);
    }

    deinitializeDMD();

    return 0;
}

private extern (C++) final class DsymbolsScopeRetrievingVisitor : Visitor
{
    Loc loc;
    Dsymbol[] symbols;
    alias visit = Visitor.visit;

public:
    extern (D) this(Loc loc)
    {
        this.loc = loc;
    }

    override void visit(Dsymbol s)
    {
    }

    override void visit(ScopeDsymbol s)
    {
        visitScopeDsymbol(s);
    }

    override void visit(EnumDeclaration d)
    {
        visitScopeDsymbol(d);
    }

    override void visit(Nspace d)
    {
        visitScopeDsymbol(d);
    }

    override void visit(StructDeclaration d)
    {
        visitScopeDsymbol(d);
    }

    override void visit(ClassDeclaration d)
    {
        visitScopeDsymbol(d);
    }

    void visitBaseClasses(ClassDeclaration d)
    {
        visitScopeDsymbol(d);
    }

    override void visit(Module m)
    {
        visitScopeDsymbol(m);
    }

    private void visitScopeDsymbol(ScopeDsymbol scopeDsym)
    {
        if (!scopeDsym.members)
            return;

        Dsymbol dsym;
        foreach (i, s; *scopeDsym.members)
        {
            if (s is null || s.ident is null)
                continue;

            // if the current symbol is from another module
            if (auto m = scopeDsym.isModule())
                if (!(to!string(s.loc.filename).endsWith(m.ident.toString() ~ ".d")))
                    continue;

            if (!s.isImport())
                symbols ~= s;

            if (!i || dsym is null) {
                dsym = s;
                continue;
            }

            // only visit a symbol which contains the cursor
            // choose the symbol which is before and the closest to the cursor
            if (isBefore(dsym.loc, loc)
                && isBefore(dsym.loc, s.loc)
                && isBefore(s.loc, loc)) {
                dsym = s;
            }
        }

        dsym.accept(this);
    }
}
