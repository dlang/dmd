/**
 * This module contains the implementation of the C++ header generation available through
 * the command line switch -Hc.
 *
 * Copyright:   Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/dtohd, _dtoh.d)
 * Documentation:  https://dlang.org/phobos/dmd_dtoh.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/dtoh.d
 */
module dmd.dtoh;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.ctype;

import dmd.astcodegen;
import dmd.arraytypes;
import dmd.globals;
import dmd.identifier;
import dmd.root.filename;
import dmd.visitor;
import dmd.tokens;

import dmd.root.outbuffer;
import dmd.utils;

//debug = Debug_DtoH;
enum isBuildingCompiler = false;

private struct DMDType
{
    __gshared Identifier c_long;
    __gshared Identifier c_ulong;
    __gshared Identifier c_longlong;
    __gshared Identifier c_ulonglong;
    __gshared Identifier c_long_double;
    __gshared Identifier c_wchar_t;
    __gshared Identifier AssocArray;
    __gshared Identifier Array;

    static void _init()
    {
        c_long          = Identifier.idPool("__c_long");
        c_ulong         = Identifier.idPool("__c_ulong");
        c_longlong      = Identifier.idPool("__c_longlong");
        c_ulonglong     = Identifier.idPool("__c_ulonglong");
        c_long_double   = Identifier.idPool("__c_long_double");
        c_wchar_t       = Identifier.idPool("__c_wchar_t");

        if (isBuildingCompiler)
        {
            AssocArray      = Identifier.idPool("AssocArray");
            Array           = Identifier.idPool("Array");
        }

    }
}

private struct DMDModule
{
    __gshared Identifier identifier;
    __gshared Identifier root;
    __gshared Identifier visitor;
    __gshared Identifier parsetimevisitor;
    __gshared Identifier permissivevisitor;
    __gshared Identifier strictvisitor;
    __gshared Identifier transitivevisitor;
    __gshared Identifier dmd;
    static void _init()
    {
        identifier          = Identifier.idPool("identifier");
        root                = Identifier.idPool("root");
        visitor             = Identifier.idPool("visitor");
        parsetimevisitor    = Identifier.idPool("parsetimevisitor");
        permissivevisitor   = Identifier.idPool("permissivevisitor");
        strictvisitor       = Identifier.idPool("strictvisitor");
        transitivevisitor   = Identifier.idPool("transitivevisitor");
        dmd                 = Identifier.idPool("dmd");
    }
}

private struct DMDClass
{
    __gshared Identifier ID; ////Identifier
    __gshared Identifier Visitor;
    __gshared Identifier ParseTimeVisitor;
    static void _init()
    {
        ID                  = Identifier.idPool("Identifier");
        Visitor             = Identifier.idPool("Visitor");
        ParseTimeVisitor    = Identifier.idPool("ParseTimeVisitor");
    }

}

private bool isIdentifierClass(ASTCodegen.ClassDeclaration cd)
{
    return (cd.ident == DMDClass.ID &&
            cd.parent !is null &&
            cd.parent.ident == DMDModule.identifier &&
            cd.parent.parent && cd.parent.parent.ident == DMDModule.dmd &&
            !cd.parent.parent.parent);
}

private bool isVisitorClass(ASTCodegen.ClassDeclaration cd)
{
    for (auto cdb = cd; cdb; cdb = cdb.baseClass)
    {
        if (cdb.ident == DMDClass.Visitor ||
            cdb.ident == DMDClass.ParseTimeVisitor)
        return true;
    }
    return false;
}

private bool isIgnoredModule(ASTCodegen.Module m)
{
    if (!m)
        return true;

    // Ignore dmd.root
    if (m.parent && m.parent.ident == DMDModule.root &&
        m.parent.parent && m.parent.parent.ident == DMDModule.dmd &&
        !m.parent.parent.parent)
    {
        return true;
    }

    // Ignore dmd.visitor and derivatives
    if ((m.ident == DMDModule.visitor ||
            m.ident == DMDModule.parsetimevisitor ||
            m.ident == DMDModule.permissivevisitor ||
            m.ident == DMDModule.strictvisitor ||
            m.ident == DMDModule.transitivevisitor) &&
            m.parent && m.parent.ident == DMDModule.dmd &&
            !m.parent.parent)
    {
        return true;
    }
    return false;
}

private bool isFrontendModule(ASTCodegen.Module m)
{
    if (!m || !m.parent)
        return false;

    // Ignore dmd.root
    if (m.parent.ident == DMDModule.root &&
        m.parent.parent && m.parent.parent.ident == DMDModule.dmd &&
        !m.parent.parent.parent)
    {
        return false;
    }

    // Ignore dmd.visitor and derivatives
    if ((m.ident == DMDModule.visitor ||
            m.ident == DMDModule.parsetimevisitor ||
            m.ident == DMDModule.permissivevisitor ||
            m.ident == DMDModule.strictvisitor ||
            m.ident == DMDModule.transitivevisitor) &&
            m.parent && m.parent.ident == DMDModule.dmd &&
            !m.parent.parent)
    {
        return false;
    }
    return ((m.parent.ident == DMDModule.dmd && !m.parent.parent) ||
            (m.parent.parent.ident == DMDModule.dmd && !m.parent.parent.parent));
}

private void initialize()
{
    __gshared bool initialized;

    if (!initialized)
    {
        initialized = true;

        DMDType._init();
        if (isBuildingCompiler)
        {
            DMDModule._init();
            DMDClass._init();
        }
    }
}

extern(C++) void genCppHdrFiles(ref Modules ms)
{
    initialize();

    OutBuffer fwd;
    OutBuffer check;
    OutBuffer done;
    OutBuffer decl;

    scope v = new ToCppBuffer!ASTCodegen(&check, &fwd, &done, &decl);

    foreach (m; ms)
        m.accept(v);

    OutBuffer buf;
    buf.printf("// Automatically generated by %s Compiler v%d\n\n", global.vendor.ptr, global.versionNumber());
    buf.writestring("#pragma once\n\n");
//    buf.writestring("#include <assert.h>\n");
    buf.writestring("#include <stddef.h>\n");
    buf.writestring("#include <stdint.h>\n");
//    buf.writestring("#include <stdio.h>\n");
//    buf.writestring("#include <string.h>\n");
    buf.writeByte('\n');
    if (v.hasReal)
    {
        buf.writestring("#if !defined(_d_real)\n");
        buf.writestring("# define _d_real long double\n");
        buf.writestring("#endif\n");
    }
    if (v.hasDefaultEnum)
    {
        buf.writestring("#if !defined(BEGIN_ENUM)\n");
        buf.writestring("# define BEGIN_ENUM(name, upper, lower) enum class name {\n");
        buf.writestring("# define ENUM_KEY(type, name, value, enumName, upper, lower, abbrev) name = value,\n");
        buf.writestring("# define END_ENUM(name, upper, lower) };\n");
        buf.writestring("#endif\n");
    }
    if (v.hasNumericEnum)
    {
        buf.writestring("#if !defined(BEGIN_ENUM_NUMERIC)\n");
        buf.writestring("# define BEGIN_ENUM_NUMERIC(type, name, upper, lower) enum class name : type {\n");
        buf.writestring("# define ENUM_KEY_NUMERIC(type, name, value, enumName, upper, lower, abbrev) name = value,\n");
        buf.writestring("# define END_ENUM_NUMERIC(type, name, upper, lower) };\n");
        buf.writestring("#endif\n");
    }
    if (v.hasTypedEnum)
    {
        buf.writestring("#if !defined(BEGIN_ENUM_TYPE)\n");
        buf.writestring("# define BEGIN_ENUM_TYPE(type, name, upper, lower) namespace name {\n");
        buf.writestring("# define ENUM_KEY_TYPE(type, name, value, enumName, upper, lower, abbrev) static type const name = value;\n");
        buf.writestring("# define END_ENUM_TYPE(type, name, upper, lower) };\n");
        buf.writestring("#endif\n");
    }
    if (v.hasAnonEnum)
    {
        buf.writestring("#if !defined(BEGIN_ANON_ENUM)\n");
        buf.writestring("# define BEGIN_ANON_ENUM() enum {\n");
        buf.writestring("# define ANON_ENUM_KEY(type, name, value) name = value,\n");
        buf.writestring("# define END_ANON_ENUM() };\n");
        buf.writestring("#endif\n");
    }
    if (v.hasAnonNumericEnum)
    {
        buf.writestring("#if !defined(BEGIN_ANON_ENUM_NUMERIC)\n");
        buf.writestring("# define BEGIN_ANON_ENUM_NUMERIC(type) enum : type {\n");
        buf.writestring("# define ANON_ENUM_KEY_NUMERIC(type, name, value) name = value,\n");
        buf.writestring("# define END_ANON_ENUM_NUMERIC(type) };\n");
        buf.writestring("#endif\n");
    }
    if (v.hasNumericConstant)
    {
        buf.writestring("#if !defined(ENUM_CONSTANT_NUMERIC)\n");
        buf.writestring("# define ENUM_CONSTANT_NUMERIC(type, name, value) enum : type { name = value };\n");
        buf.writestring("#endif\n");
    }
    if (v.hasTypedConstant)
    {
        buf.writestring("#if !defined(ENUM_CONSTANT)\n");
        buf.writestring("# define ENUM_CONSTANT(type, name, value) static type const name = value;\n");
        buf.writestring("#endif\n");
    }
    buf.writestring("\n");

    buf.write(&fwd);
    if (fwd.length > 0)
        buf.writestring("\n");

    buf.write(&done);
    buf.write(&decl);

    debug (Debug_DtoH)
    {
        buf.writestring(`
#if OFFSETS
    template <class T>
    size_t getSlotNumber(int dummy, ...)
    {
        T c;
        va_list ap;
        va_start(ap, dummy);
        void *f = va_arg(ap, void*);
        for (size_t i = 0; ; i++)
        {
            if ( (*(void***)&c)[i] == f)
            return i;
        }
        va_end(ap);
    }

    void testOffsets()
    {
`);
        buf.write(&check);
        buf.writestring(`
    }
#endif
`);
    }

    if (global.params.cxxhdrname is null)
    {
        // Write to stdout; assume it succeeds
        size_t n = fwrite(buf[].ptr, 1, buf.length, stdout);
        assert(n == buf.length); // keep gcc happy about return values
    }
    else
    {
        const(char)[] name = FileName.combine(global.params.cxxhdrdir, global.params.cxxhdrname);
        writeFile(Loc.initial, name, buf[]);
    }
}

/****************************************************
 */
extern(C++) final class ToCppBuffer(AST) : Visitor
{
    alias visit = Visitor.visit;
public:
    enum EnumKind
    {
        Int,
        Numeric,
        Other
    }

    bool[void*] visited;
    bool[void*] forwarded;
    OutBuffer* fwdbuf;
    OutBuffer* checkbuf;
    OutBuffer* donebuf;
    OutBuffer* buf;
    AST.AggregateDeclaration adparent;
    AST.ClassDeclaration cdparent;
    AST.TemplateDeclaration tdparent;
    Identifier ident;
    LINK linkage = LINK.d;
    bool forwardedAA;
    AST.Type* origType;

    bool hasReal;
    bool hasDefaultEnum;
    bool hasNumericEnum;
    bool hasTypedEnum;
    bool hasAnonEnum;
    bool hasAnonNumericEnum;
    bool hasNumericConstant;
    bool hasTypedConstant;

    this(OutBuffer* checkbuf, OutBuffer* fwdbuf, OutBuffer* donebuf, OutBuffer* buf)
    {
        this.checkbuf = checkbuf;
        this.fwdbuf = fwdbuf;
        this.donebuf = donebuf;
        this.buf = buf;
    }

    private EnumKind getEnumKind(AST.Type type)
    {
        if (type) switch (type.ty)
        {
            case AST.Tint32:
                return EnumKind.Int;
            case AST.Tbool,
                AST.Tchar, AST.Twchar, AST.Tdchar,
                AST.Tint8, AST.Tuns8,
                AST.Tint16, AST.Tuns16,
                AST.Tuns32,
                AST.Tint64, AST.Tuns64:
                return EnumKind.Numeric;
            default:
                break;
        }
        return EnumKind.Other;
    }

    private void writeEnumTypeName(AST.Type type)
    {
        if (auto arr = type.isTypeDArray())
        {
            switch (arr.next.ty)
            {
                case AST.Tchar:  buf.writestring("const char*"); return;
                case AST.Twchar: buf.writestring("const char16_t*"); return;
                case AST.Tdchar: buf.writestring("const char32_t*"); return;
                default: break;
            }
        }
        type.accept(this);
    }

    private void indent()
    {
        if (adparent)
            buf.writestring("    ");
    }

    override void visit(AST.Dsymbol s)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.Dsymbol enter] %s\n", s.toChars());
            scope(exit) printf("[AST.Dsymbol exit] %s\n", s.toChars());
        }

        if (isBuildingCompiler && s.getModule() && s.getModule().isFrontendModule())
        {
            indent();
            buf.printf("// ignored %s %s\n", s.kind(), s.toPrettyChars());
        }
    }

    override void visit(AST.Import i)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.Import enter] %s\n", i.toChars());
            scope(exit) printf("[AST.Import exit] %s\n", i.toChars());
        }
    }

    override void visit(AST.AttribDeclaration pd)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.AttribDeclaration enter] %s\n", pd.toChars());
            scope(exit) printf("[AST.AttribDeclaration exit] %s\n", pd.toChars());
        }
        Dsymbols* decl = pd.include(null);
        if (!decl)
            return;

        foreach (s; *decl)
        {
            if (adparent || s.prot().kind >= AST.Prot.Kind.public_)
                s.accept(this);
        }
    }

    override void visit(AST.LinkDeclaration ld)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.LinkDeclaration enter] %s\n", ld.toChars());
            scope(exit) printf("[AST.LinkDeclaration exit] %s\n", ld.toChars());
        }
        auto save = linkage;
        linkage = ld.linkage;
        if (ld.linkage != LINK.c && ld.linkage != LINK.cpp)
        {
            indent();
            buf.printf("// ignoring %s block because of linkage\n", ld.toPrettyChars());
        }
        else
        {
            visit(cast(AST.AttribDeclaration)ld);
        }
        linkage = save;
    }

    override void visit(AST.Module m)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.Module enter] %s\n", m.toChars());
            scope(exit) printf("[AST.Module exit] %s\n", m.toChars());
        }
        foreach (s; *m.members)
        {
            if (s.prot().kind < AST.Prot.Kind.public_)
                continue;
            s.accept(this);
        }
    }

    override void visit(AST.FuncDeclaration fd)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.FuncDeclaration enter] %s\n", fd.toChars());
            scope(exit) printf("[AST.FuncDeclaration exit] %s\n", fd.toChars());
        }
        if (cast(void*)fd in visited)
            return;
        if (isBuildingCompiler && fd.getModule() && fd.getModule().isIgnoredModule())
            return;

        // printf("FuncDeclaration %s %s\n", fd.toPrettyChars(), fd.type.toChars());
        visited[cast(void*)fd] = true;

        auto tf = cast(AST.TypeFunction)fd.type;
        indent();
        if (!tf || !tf.deco)
        {
            buf.printf("// ignoring function %s because semantic hasn't been run\n", fd.toPrettyChars());
            return;
        }
        if (tf.linkage != LINK.c && tf.linkage != LINK.cpp)
        {
            buf.printf("// ignoring function %s because of linkage\n", fd.toPrettyChars());
            return;
        }
        if (!adparent && !fd.fbody)
        {
            buf.printf("// ignoring function %s because it's extern\n", fd.toPrettyChars());
            return;
        }

        if (tf.linkage == LINK.c)
            buf.writestring("extern \"C\" ");
        else if (!adparent)
            buf.writestring("extern ");
        if (adparent && fd.isStatic())
            buf.writestring("static ");
        if (adparent && fd.vtblIndex != -1)
        {
            if (!fd.isOverride())
                buf.writestring("virtual ");

            auto s = adparent.search(Loc.initial, fd.ident);
            if (!(adparent.storage_class & AST.STC.abstract_) &&
                !(cast(AST.ClassDeclaration)adparent).isAbstract() &&
                s is fd && !fd.overnext)
            {
                auto save = buf;
                buf = checkbuf;
                buf.writestring("    assert(getSlotNumber<");
                buf.writestring(adparent.ident.toChars());
                buf.writestring(">(0, &");
                buf.writestring(adparent.ident.toChars());
                buf.writestring("::");
                buf.writestring(fd.ident.toChars());
                buf.printf(") == %d);\n", fd.vtblIndex);
                buf = save;
            }
        }

        if (adparent && fd.isDisabled && global.params.cplusplus < CppStdRevision.cpp11)
            buf.printf("private: ");
        funcToBuffer(tf, fd);
        if (adparent && tf.isConst())
        {
            bool fdOverridesAreConst = true;
            foreach (fdv; fd.foverrides)
            {
                auto tfv = cast(AST.TypeFunction)fdv.type;
                if (!tfv.isConst())
                {
                    fdOverridesAreConst = false;
                    break;
                }
            }

            buf.writestring(fdOverridesAreConst ? " const" : " /* const */");
        }
        if (adparent && fd.isAbstract())
            buf.writestring(" = 0");
        if (adparent && fd.isDisabled && global.params.cplusplus >= CppStdRevision.cpp11)
            buf.printf(" = delete");
        buf.printf(";\n");
        if (adparent && fd.isDisabled && global.params.cplusplus < CppStdRevision.cpp11)
            buf.printf("public:\n");
        if (!adparent)
            buf.printf("\n");
    }

    override void visit(AST.UnitTestDeclaration utd)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.UnitTestDeclaration enter] %s\n", utd.toChars());
            scope(exit) printf("[AST.UnitTestDeclaration exit] %s\n", utd.toChars());
        }
    }

    override void visit(AST.VarDeclaration vd)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.VarDeclaration enter] %s\n", vd.toChars());
            scope(exit) printf("[AST.VarDeclaration exit] %s\n", vd.toChars());
        }
        if (cast(void*)vd in visited)
            return;
        if (isBuildingCompiler && vd.getModule() && vd.getModule().isIgnoredModule())
            return;

        visited[cast(void*)vd] = true;

        if (vd.type == AST.Type.tsize_t)
            origType = &vd.originalType;
        scope(exit) origType = null;

        if (vd.alignment != uint.max)
        {
            indent();
            buf.printf("// Ignoring var %s alignment %u\n", vd.toChars(), vd.alignment);
        }

        if (vd.storage_class & AST.STC.manifest &&
            vd._init && vd._init.isExpInitializer())
        {
            AST.Type type = vd.type;
            EnumKind kind = getEnumKind(type);
            indent();
            if (kind != EnumKind.Other)
            {
                hasNumericConstant = true;
                buf.writestring("ENUM_CONSTANT_NUMERIC(");
            }
            else
            {
                hasTypedConstant = true;
                buf.writestring("ENUM_CONSTANT(");
            }
            writeEnumTypeName(type);
            buf.writestring(", ");
            buf.writestring(vd.ident.toString());
            buf.writestring(", ");
            auto e = AST.initializerToExpression(vd._init);
            if (kind != EnumKind.Other)
            {
                auto ie = cast(AST.IntegerExp)e;
                visitInteger(ie.toInteger(), type);
            }
            else
                e.accept(this);
            buf.writestring(")\n\n");
            return;
        }

        if (tdparent && vd.type && !vd.type.deco)
        {
            indent();
            if (linkage != LINK.c && linkage != LINK.cpp)
            {
                buf.printf("// ignoring variable %s because of linkage\n", vd.toPrettyChars());
                return;
            }
            typeToBuffer(vd.type, vd.ident);
            buf.writestring(";\n");
            return;
        }

        if (vd.storage_class & (AST.STC.static_ | AST.STC.extern_ | AST.STC.tls | AST.STC.gshared) ||
        vd.parent && vd.parent.isModule())
        {
            indent();
            if (vd.linkage != LINK.c && vd.linkage != LINK.cpp)
            {
                buf.printf("// ignoring variable %s because of linkage\n", vd.toPrettyChars());
                return;
            }
            if (vd.storage_class & AST.STC.tls)
            {
                buf.printf("// ignoring variable %s because of thread-local storage\n", vd.toPrettyChars());
                return;
            }
            if (vd.linkage == LINK.c)
                buf.writestring("extern \"C\" ");
            else if (!adparent)
                buf.writestring("extern ");
            if (adparent)
                buf.writestring("static ");
            typeToBuffer(vd.type, vd.ident);
            buf.writestring(";\n");
            if (!adparent)
                buf.printf("\n");
            return;
        }

        if (adparent && vd.type && vd.type.deco)
        {
            indent();
            auto save = cdparent;
            cdparent = vd.isField() ? adparent.isClassDeclaration() : null;
            typeToBuffer(vd.type, vd.ident);
            cdparent = save;
            buf.writestring(";\n");

            if (auto t = vd.type.isTypeStruct())
                includeSymbol(t.sym);

            auto savex = buf;
            buf = checkbuf;
            buf.writestring("    assert(offsetof(");
            buf.writestring(adparent.ident.toChars());
            buf.writestring(", ");
            buf.writestring(vd.ident.toChars());
            buf.printf(") == %d);\n", vd.offset);
            buf = savex;
            return;
        }
        visit(cast(AST.Dsymbol)vd);
    }

    override void visit(AST.TypeInfoDeclaration tid)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeInfoDeclaration enter] %s\n", tid.toChars());
            scope(exit) printf("[AST.TypeInfoDeclaration exit] %s\n", tid.toChars());
        }
    }

    override void visit(AST.AliasDeclaration ad)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.AliasDeclaration enter] %s\n", ad.toChars());
            scope(exit) printf("[AST.AliasDeclaration exit] %s\n", ad.toChars());
        }
        if (isBuildingCompiler && ad.getModule() && ad.getModule().isIgnoredModule())
            return;

        if (auto t = ad.type)
        {
            if (t.ty == AST.Tdelegate)
            {
                visit(cast(AST.Dsymbol)ad);
                return;
            }

            // for function pointers we need to original type
            if (ad.type.ty == AST.Tpointer &&
                (cast(AST.TypePointer)t).nextOf.ty == AST.Tfunction)
            {
                origType = &ad.originalType;
            }
            scope(exit) origType = null;

            buf.writestring("typedef ");
            typeToBuffer(origType ? *origType : t, ad.ident);
            buf.writestring(";\n");
            if (!adparent)
                buf.printf("\n");
            return;
        }
        if (!ad.aliassym)
        {
            assert(0);
        }
        if (auto ti = ad.aliassym.isTemplateInstance())
        {
            visitTi(ti);
            return;
        }
        if (auto sd = ad.aliassym.isStructDeclaration())
        {
            buf.writestring("typedef ");
            sd.type.accept(this);
            buf.writestring(" ");
            buf.writestring(ad.ident.toChars());
            buf.writestring(";\n");
            if (!adparent)
                buf.printf("\n");
            return;
        }
        if (ad.aliassym.isDtorDeclaration())
        {
            // Ignore. It's taken care of while visiting FuncDeclaration
            return;
        }
        indent();
        buf.printf("// ignored %s %s\n", ad.aliassym.kind(), ad.aliassym.toPrettyChars());
    }

    override void visit(AST.Nspace ns)
    {
        handleNspace(ns.ident, ns.members);
    }

    override void visit(AST.CPPNamespaceDeclaration ns)
    {
        handleNspace(ns.ident, ns.decl);
    }

    void handleNspace(Identifier name, Dsymbols* members)
    {
        buf.printf("namespace %s", name.toChars());
        buf.writenl();
        buf.writestring("{");
        buf.writenl();
        buf.level++;
        foreach(decl;(*members))
        {
            decl.accept(this);
        }
        buf.level--;
        buf.writestring("}");
        buf.writenl();
    }

    override void visit(AST.AnonDeclaration ad)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.AnonDeclaration enter] %s\n", ad.toChars());
            scope(exit) printf("[AST.AnonDeclaration exit] %s\n", ad.toChars());
        }
        indent();
        buf.writestring(ad.isunion ? "union\n" : "struct\n");
        indent();
        buf.writestring("{\n");
        foreach (s; *ad.decl)
        {
            indent();
            s.accept(this);
        }
        indent();
        buf.writestring("};\n");
    }

    private bool memberField(AST.VarDeclaration vd)
    {
        if (!vd.type || !vd.type.deco || !vd.ident)
            return false;
        if (!vd.isField())
            return false;
        if (vd.type.ty == AST.Tfunction)
            return false;
        if (vd.type.ty == AST.Tsarray)
            return false;
        return true;
    }

    override void visit(AST.StructDeclaration sd)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.StructDeclaration enter] %s\n", sd.toChars());
            scope(exit) printf("[AST.StructDeclaration exit] %s\n", sd.toChars());
        }
        if (sd.isInstantiated())
            return;
        if (cast(void*)sd in visited)
            return;
        if (!sd.type || !sd.type.deco)
            return;
        if (isBuildingCompiler && sd.getModule() && sd.getModule().isIgnoredModule())
            return;

        visited[cast(void*)sd] = true;
        if (linkage != LINK.c && linkage != LINK.cpp)
        {
            buf.printf("// ignoring non-cpp struct %s because of linkage\n", sd.toChars());
            return;
        }

        buf.writestring(sd.isUnionDeclaration() ? "union" : "struct");
        pushAlignToBuffer(sd.alignment);
        buf.writestring(sd.ident.toChars());
        if (!sd.members)
        {
            buf.writestring(";\n\n");
            return;
        }

        buf.writestring("\n{\n");
        auto save = adparent;
        adparent = sd;
        foreach (m; *sd.members)
        {
            m.accept(this);
        }
        adparent = save;
        // Generate default ctor
        if (!sd.noDefaultCtor)
        {
            buf.printf("    %s()", sd.ident.toChars());
            size_t varCount;
            bool first = true;
            foreach (m; *sd.members)
            {
                if (auto vd = m.isVarDeclaration())
                {
                    if (!memberField(vd))
                        continue;
                    varCount++;

                    if (!vd._init && !vd.type.isTypeBasic() && !vd.type.isTypePointer && !vd.type.isTypeStruct &&
                        !vd.type.isTypeClass && !vd.type.isTypeDArray && !vd.type.isTypeSArray)
                    {
                        continue;
                    }
                    if (vd._init && vd._init.isVoidInitializer())
                        continue;

                    if (first)
                    {
                        buf.printf(" : ");
                        first = false;
                    }
                    else
                    {
                        buf.printf(", ");
                    }
                    buf.printf("%s(", vd.ident.toChars());

                    if (vd._init)
                    {
                        AST.initializerToExpression(vd._init).accept(this);
                    }
                    buf.printf(")");
                }
            }
            buf.printf(" {}\n");
        }

        version (none)
        {
            if (varCount)
            {
                buf.printf("    %s(", sd.ident.toChars());
                bool first = true;
                foreach (m; *sd.members)
                {
                    if (auto vd = m.isVarDeclaration())
                    {
                        if (!memberField(vd))
                            continue;
                        if (first)
                            first = false;
                        else
                            buf.writestring(", ");
                        assert(vd.type);
                        assert(vd.ident);
                        typeToBuffer(vd.type, vd.ident);
                    }
                }
                buf.printf(") {");
                foreach (m; *sd.members)
                {
                    if (auto vd = m.isVarDeclaration())
                    {
                        if (!memberField(vd))
                            continue;
                        buf.printf(" this->%s = %s;", vd.ident.toChars(), vd.ident.toChars());
                    }
                }
                buf.printf(" }\n");
            }
        }
        buf.writestring("};\n");

        popAlignToBuffer(sd.alignment);
        buf.writestring("\n");

        auto savex = buf;
        buf = checkbuf;
        buf.writestring("    assert(sizeof(");
        buf.writestring(sd.ident.toChars());
        buf.printf(") == %d);\n", sd.size(Loc.initial));
        buf = savex;
    }

    private void pushAlignToBuffer(uint alignment)
    {
        // DMD ensures alignment is a power of two
        //assert(alignment > 0 && ((alignment & (alignment - 1)) == 0),
        //       "Invalid alignment size");

        // When no alignment is specified, `uint.max` is the default
        if (alignment == uint.max)
        {
            buf.writeByte(' ');
            return;
        }

        buf.writestring("\n#if defined(__GNUC__) || defined(__clang__)\n");
        // The equivalent of `#pragma pack(push, n)` is `__attribute__((packed, aligned(n)))`
        // NOTE: removing the packed attribute will might change the resulting size
        buf.printf("    __attribute__((packed, aligned(%d)))\n", alignment);
        buf.writestring("#elif defined(_MSC_VER)\n");
        buf.printf("    __declspec(align(%d))\n", alignment);
        buf.writestring("#elif defined(__DMC__)\n");
        buf.printf("    #pragma pack(push, %d)\n", alignment);
        //buf.printf("#pragma pack(%d)\n", alignment);
        buf.writestring("#endif\n");
    }

    private void popAlignToBuffer(uint alignment)
    {
        if (alignment == uint.max)
            return;

        buf.writestring("#if defined(__DMC__)\n");
        buf.writestring("    #pragma pack(pop)\n");
        //buf.writestring("#pragma pack()\n");
        buf.writestring("#endif\n");
    }

    private void includeSymbol(AST.Dsymbol ds)
    {
        debug (Debug_DtoH)
        {
            printf("[includeSymbol(AST.Dsymbol) enter] %s\n", ds.toChars());
            scope(exit) printf("[includeSymbol(AST.Dsymbol) exit] %s\n", ds.toChars());
        }
        if (cast(void*) ds in visited)
            return;

        OutBuffer decl;
        auto save = buf;
        buf = &decl;
        ds.accept(this);
        buf = save;
        donebuf.writestring(decl.peekChars());
    }

    override void visit(AST.ClassDeclaration cd)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.ClassDeclaration enter] %s\n", cd.toChars());
            scope(exit) printf("[AST.ClassDeclaration exit] %s\n", cd.toChars());
        }
        if (cast(void*)cd in visited)
            return;
        if (isBuildingCompiler)
        {
            if (cd.getModule() && cd.getModule().isIgnoredModule())
                return;
            if (cd.isVisitorClass())
                return;
        }

        visited[cast(void*)cd] = true;
        if (!cd.isCPPclass())
        {
            buf.printf("// ignoring non-cpp class %s\n", cd.toChars());
            return;
        }

        buf.writestring("class ");
        buf.writestring(cd.ident.toChars());
        if (cd.baseClass)
        {
            buf.writestring(" : public ");
            buf.writestring(cd.baseClass.ident.toChars());

            includeSymbol(cd.baseClass);
        }
        if (!cd.members)
        {
            buf.writestring(";\n\n");
            return;
        }

        buf.writestring("\n{\npublic:\n");
        auto save = adparent;
        adparent = cd;
        foreach (m; *cd.members)
        {
            m.accept(this);
        }
        adparent = save;

        // Generate special static inline function.
        if (isBuildingCompiler && cd.isIdentifierClass())
        {
            buf.writestring("    static inline Identifier *idPool(const char *s) { return idPool(s, strlen(s)); }\n");
        }

        buf.writestring("};\n\n");
    }

    override void visit(AST.EnumDeclaration ed)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.EnumDeclaration enter] %s\n", ed.toChars());
            scope(exit) printf("[AST.EnumDeclaration exit] %s\n", ed.toChars());
        }
        if (cast(void*)ed in visited)
            return;

        if (isBuildingCompiler && ed.getModule() && ed.getModule().isIgnoredModule())
            return;

        visited[cast(void*)ed] = true;

        //if (linkage != LINK.c && linkage != LINK.cpp)
        //{
            //buf.printf("// ignoring non-cpp enum %s because of linkage\n", ed.toChars());
            //return;
        //}

        // we need to know a bunch of stuff about the enum...
        bool isAnonymous = ed.ident is null;
        AST.Type type = ed.memtype;
        if (!type)
        {
            // check all keys have matching type
            foreach (_m; *ed.members)
            {
                auto m = _m.isEnumMember();
                if (!type)
                    type = m.type;
                else if (m.type !is type)
                {
                    type = null;
                    break;
                }
            }
        }
        EnumKind kind = getEnumKind(type);

        // determine if this is an enum, or just a group of manifest constants
        bool manifestConstants = !type || (isAnonymous && kind == EnumKind.Other);
        assert(!manifestConstants || isAnonymous);

        const(char)[] name = null;
        char[] nameLower = null;
        char[] nameUpper = null;
        char[] nameAbbrev = null;
        if (!isAnonymous)
        {
            name = ed.ident.toString;
            nameLower = new char[name.length];
            nameUpper = new char[name.length];
            foreach (i, c; name)
            {
                nameUpper[i] = cast(char)toupper(c);
                nameLower[i] = cast(char)tolower(c);
                if (isupper(c))
                    nameAbbrev ~= c;
            }
        }

        // write the enum header
        if (!manifestConstants)
        {
            indent();
            if (!isAnonymous && kind == EnumKind.Int)
            {
                hasDefaultEnum = true;
                buf.writestring("BEGIN_ENUM(");
            }
            else if (!isAnonymous && kind == EnumKind.Numeric)
            {
                hasNumericEnum = true;
                buf.writestring("BEGIN_ENUM_NUMERIC(");
            }
            else if(!isAnonymous)
            {
                hasTypedEnum = true;
                buf.writestring("BEGIN_ENUM_TYPE(");
            }
            else if (kind == EnumKind.Int)
            {
                hasAnonEnum = true;
                buf.writestring("BEGIN_ANON_ENUM(");
            }
            else
            {
                hasAnonNumericEnum = true;
                buf.writestring("BEGIN_ANON_ENUM_NUMERIC(");
            }
            if (kind != EnumKind.Int)
                writeEnumTypeName(type);
            if (!isAnonymous)
            {
                if (kind != EnumKind.Int)
                    buf.writestring(", ");
                buf.writestring(name);
                buf.writestring(", ");
                buf.writestring(nameUpper);
                buf.writestring(", ");
                buf.writestring(nameLower);
            }
            buf.writestring(")\n");
        }

        // emit constant for each member
        foreach (_m; *ed.members)
        {
            auto m = _m.isEnumMember();
            AST.Type memberType = type ? type : m.type;
            const EnumKind memberKind = type ? kind : getEnumKind(memberType);

            indent();
            if (!manifestConstants && !isAnonymous && kind == EnumKind.Int)
                buf.writestring("  ENUM_KEY(");
            else if (!manifestConstants && !isAnonymous && kind == EnumKind.Numeric)
                buf.writestring("  ENUM_KEY_NUMERIC(");
            else if(!manifestConstants && !isAnonymous)
                buf.writestring("  ENUM_KEY_TYPE(");
            else if (!manifestConstants && kind == EnumKind.Int)
                buf.writestring("  ANON_ENUM_KEY(");
            else if (!manifestConstants)
                buf.writestring("  ANON_ENUM_KEY_NUMERIC(");
            else if (manifestConstants && memberKind != EnumKind.Other)
            {
                hasNumericConstant = true;
                buf.writestring("ENUM_CONSTANT_NUMERIC(");
            }
            else if (manifestConstants)
            {
                hasTypedConstant = true;
                buf.writestring("ENUM_CONSTANT(");
            }
            writeEnumTypeName(memberType);
            buf.writestring(", ");
            buf.writestring(m.ident.toString());
            buf.writestring(", ");
            if (memberKind != EnumKind.Other)
            {
                auto ie = cast(AST.IntegerExp)m.value;
                visitInteger(ie.toInteger(), memberType);
            }
            else
                m.value.accept(this);
            if (!isAnonymous)
            {
                buf.writestring(", ");
                buf.writestring(name);
                buf.writestring(", ");
                buf.writestring(nameUpper);
                buf.writestring(", ");
                buf.writestring(nameLower);
                if (!manifestConstants)
                {
                    buf.writestring(", ");
                    buf.writestring(nameAbbrev);
                }
            }
            buf.writestring(")\n");
        }

        // write the enum tail
        if (!manifestConstants)
        {
            indent();
            if (!isAnonymous && kind == EnumKind.Int)
                buf.writestring("END_ENUM(");
            else if (!isAnonymous && kind == EnumKind.Numeric)
                buf.writestring("END_ENUM_NUMERIC(");
            else if(!isAnonymous)
                buf.writestring("END_ENUM_TYPE(");
            else if (kind == EnumKind.Int)
                buf.writestring("END_ANON_ENUM(");
            else
                buf.writestring("END_ANON_ENUM_NUMERIC(");
            if (kind != EnumKind.Int)
                writeEnumTypeName(type);
            if (!isAnonymous)
            {
                if (kind != EnumKind.Int)
                    buf.writestring(", ");
                buf.writestring(name);
                buf.writestring(", ");
                buf.writestring(nameUpper);
                buf.writestring(", ");
                buf.writestring(nameLower);
            }
            buf.writestring(")\n");
        }
        buf.writestring("\n");
    }

    override void visit(AST.EnumMember em)
    {
        assert(false, "This node type should be handled in the EnumDeclaration");
    }

    private void typeToBuffer(AST.Type t, Identifier ident)
    {
        debug (Debug_DtoH)
        {
            printf("[typeToBuffer(AST.Type) enter] %s ident %s\n", t.toChars(), ident.toChars());
            scope(exit) printf("[typeToBuffer(AST.Type) exit] %s ident %s\n", t.toChars(), ident.toChars());
        }

        this.ident = ident;
        origType ? origType.accept(this) : t.accept(this);
        if (this.ident)
        {
            buf.writeByte(' ');
            buf.writestring(ident.toChars());
        }
        this.ident = null;
        if (auto tsa = t.isTypeSArray())
        {
            buf.writeByte('[');
            tsa.dim.accept(this);
            buf.writeByte(']');
        }
    }

    override void visit(AST.Type t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.Type enter] %s\n", t.toChars());
            scope(exit) printf("[AST.Type exit] %s\n", t.toChars());
        }
        printf("Invalid type: %s\n", t.toPrettyChars());
        assert(0);
    }

    override void visit(AST.TypeIdentifier t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeIdentifier enter] %s\n", t.toChars());
            scope(exit) printf("[AST.TypeIdentifier exit] %s\n", t.toChars());
        }
        buf.writestring(t.ident.toChars());
    }

    override void visit(AST.TypeBasic t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeBasic enter] %s\n", t.toChars());
            scope(exit) printf("[AST.TypeBasic exit] %s\n", t.toChars());
        }
        if (!cdparent && t.isConst())
            buf.writestring("const ");
        string typeName;
        switch (t.ty)
        {
            case AST.Tvoid:     typeName = "void";      break;
            case AST.Tbool:     typeName = "bool";      break;
            case AST.Tchar:     typeName = "char";      break;
            case AST.Twchar:    typeName = "char16_t";  break;
            case AST.Tdchar:    typeName = "char32_t";  break;
            case AST.Tint8:     typeName = "int8_t";    break;
            case AST.Tuns8:     typeName = "uint8_t";   break;
            case AST.Tint16:    typeName = "int16_t";   break;
            case AST.Tuns16:    typeName = "uint16_t";  break;
            case AST.Tint32:    typeName = "int32_t";   break;
            case AST.Tuns32:    typeName = "uint32_t";  break;
            case AST.Tint64:    typeName = "int64_t";   break;
            case AST.Tuns64:    typeName = "uint64_t";  break;
            case AST.Tfloat32:  typeName = "float";     break;
            case AST.Tfloat64:  typeName = "double";    break;
            case AST.Tfloat80:
                typeName = "_d_real";
                hasReal = true;
                break;
            default:
                //t.print();
                assert(0);
        }
        buf.writestring(typeName);
    }

    override void visit(AST.TypePointer t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypePointer enter] %s\n", t.toChars());
            scope(exit) printf("[AST.TypePointer exit] %s\n", t.toChars());
        }
        auto ts = t.next.isTypeStruct();
        if (ts && !strcmp(ts.sym.ident.toChars(), "__va_list_tag"))
        {
            buf.writestring("va_list");
            return;
        }
        t.next.accept(this);
        if (t.next.ty != AST.Tfunction)
            buf.writeByte('*');
        if (!cdparent && t.isConst())
            buf.writestring(" const");
    }

    override void visit(AST.TypeSArray t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeSArray enter] %s\n", t.toChars());
            scope(exit) printf("[AST.TypeSArray exit] %s\n", t.toChars());
        }
        t.next.accept(this);
    }

    override void visit(AST.TypeAArray t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeAArray enter] %s\n", t.toChars());
            scope(exit) printf("[AST.TypeAArray exit] %s\n", t.toChars());
        }
        AST.Type.tvoidptr.accept(this);
    }

    override void visit(AST.TypeFunction tf)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeFunction enter] %s\n", tf.toChars());
            scope(exit) printf("[AST.TypeFunction exit] %s\n", tf.toChars());
        }
        tf.next.accept(this);
        buf.writeByte('(');
        buf.writeByte('*');
        if (ident)
            buf.writestring(ident.toChars());
        ident = null;
        buf.writeByte(')');
        buf.writeByte('(');
        foreach (i; 0 .. AST.Parameter.dim(tf.parameterList.parameters))
        {
            if (i)
                buf.writestring(", ");
            auto fparam = AST.Parameter.getNth(tf.parameterList.parameters, i);
            fparam.accept(this);
        }
        if (tf.parameterList.varargs)
        {
            if (tf.parameterList.parameters.dim && tf.parameterList.varargs == 1)
                buf.writestring(", ");
            buf.writestring("...");
        }
        buf.writeByte(')');
    }

    private void enumToBuffer(AST.EnumDeclaration ed)
    {
        debug (Debug_DtoH)
        {
            printf("[enumToBuffer(AST.EnumDeclaration) enter] %s\n", ed.toChars());
            scope(exit) printf("[enumToBuffer(AST.EnumDeclaration) exit] %s\n", ed.toChars());
        }
        if (ed.isSpecial())
        {
            if (ed.ident == DMDType.c_long)
                buf.writestring("long");
            else if (ed.ident == DMDType.c_ulong)
                buf.writestring("unsigned long");
            else if (ed.ident == DMDType.c_longlong)
                buf.writestring("long long");
            else if (ed.ident == DMDType.c_ulonglong)
                buf.writestring("unsigned long long");
            else if (ed.ident == DMDType.c_long_double)
                buf.writestring("long double");
            else if (ed.ident == DMDType.c_wchar_t)
                buf.writestring("wchar_t");
            else
            {
                //ed.print();
                assert(0);
            }
            return;
        }

        buf.writestring(ed.toChars());
    }

    override void visit(AST.TypeEnum t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeEnum enter] %s\n", t.toChars());
            scope(exit) printf("[AST.TypeEnum exit] %s\n", t.toChars());
        }
        if (cast(void*)t.sym !in forwarded)
        {
            forwarded[cast(void*)t.sym] = true;
            auto save = buf;
            buf = fwdbuf;
            //printf("Visiting enum %s from module %s %s\n", t.sym.toPrettyChars(), t.toChars(), t.sym.loc.toChars());
            t.sym.accept(this);
            buf = save;
        }
        if (!cdparent && t.isConst())
            buf.writestring("const ");
        enumToBuffer(t.sym);
    }

    override void visit(AST.TypeStruct t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeStruct enter] %s\n", t.toChars());
            scope(exit) printf("[AST.TypeStruct exit] %s\n", t.toChars());
        }
        if (cast(void*)t.sym !in forwarded && !t.sym.parent.isTemplateInstance())
        {
            forwarded[cast(void*)t.sym] = true;
            fwdbuf.writestring(t.sym.isUnionDeclaration() ? "union " : "struct ");
            fwdbuf.writestring(t.sym.toChars());
            fwdbuf.writestring(";\n");
        }

        if (!cdparent && t.isConst())
            buf.writestring("const ");
        if (auto ti = t.sym.parent.isTemplateInstance())
        {
            visitTi(ti);
            return;
        }
        buf.writestring(t.sym.toChars());
    }

    override void visit(AST.TypeDArray t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeDArray enter] %s\n", t.toChars());
            scope(exit) printf("[AST.TypeDArray exit] %s\n", t.toChars());
        }
        if (!cdparent && t.isConst())
            buf.writestring("const ");
        buf.writestring("DArray< ");
        t.next.accept(this);
        buf.writestring(" >");
    }

    private void visitTi(AST.TemplateInstance ti)
    {
        debug (Debug_DtoH)
        {
            printf("[visitTi(AST.TemplateInstance) enter] %s\n", ti.toChars());
            scope(exit) printf("[visitTi(AST.TemplateInstance) exit] %s\n", ti.toChars());
        }

        // FIXME: Restricting this to DMD seems wrong ...
        if (isBuildingCompiler)
        {
            if (ti.tempdecl.ident == DMDType.AssocArray)
            {
                if (!forwardedAA)
                {
                    forwardedAA = true;
                    fwdbuf.writestring("struct AA;\n");
                }
                buf.writestring("AA*");
                return;
            }
            if (ti.tempdecl.ident == DMDType.Array)
            {
                buf.writestring("Array");
            }
            else
                goto LprintTypes;
        }
        else
        {
            LprintTypes:
            foreach (o; *ti.tiargs)
            {
                if (!AST.isType(o))
                    return;
            }
            buf.writestring(ti.tempdecl.ident.toChars());
        }
        buf.writeByte('<');
        foreach (i, o; *ti.tiargs)
        {
            if (i)
                buf.writestring(", ");
            if (auto tt = AST.isType(o))
            {
                tt.accept(this);
            }
            else
            {
                //ti.print();
                //o.print();
                assert(0);
            }
        }
        buf.writeByte('>');
    }

    override void visit(AST.TemplateDeclaration td)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TemplateDeclaration enter] %s\n", td.toChars());
            scope(exit) printf("[AST.TemplateDeclaration exit] %s\n", td.toChars());
        }
        if (cast(void*)td in visited)
            return;
        visited[cast(void*)td] = true;

        if (isBuildingCompiler && td.getModule() && td.getModule().isIgnoredModule())
            return;

        if (!td.parameters || !td.onemember || !td.onemember.isStructDeclaration())
        {
            visit(cast(AST.Dsymbol)td);
            return;
        }

        // Explicitly disallow templates with non-type parameters or specialization.
        foreach (p; *td.parameters)
        {
            if (!p.isTemplateTypeParameter() || p.specialization())
            {
                visit(cast(AST.Dsymbol)td);
                return;
            }
        }

        if (linkage != LINK.c && linkage != LINK.cpp)
        {
            buf.printf("// ignoring template %s because of linkage\n", td.toPrettyChars());
            return;
        }

        auto sd = td.onemember.isStructDeclaration();
        auto save = tdparent;
        tdparent = td;
        indent();
        buf.writestring("template <");
        bool first = true;
        foreach (p; *td.parameters)
        {
            if (first)
                first = false;
            else
                buf.writestring(", ");
            buf.writestring("typename ");
            buf.writestring(p.ident.toChars());
        }
        buf.writestring(">\n");
        buf.writestring(sd.isUnionDeclaration() ? "union " : "struct ");
        buf.writestring(sd.ident.toChars());
        if (sd.members)
        {
            buf.writestring("\n{\n");
            auto savex = adparent;
            adparent = sd;
            foreach (m; *sd.members)
            {
                m.accept(this);
            }
            adparent = savex;
            buf.writestring("};\n\n");
        }
        else
        {
            buf.writestring(";\n\n");
        }
        tdparent = save;
    }

    override void visit(AST.TypeClass t)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.TypeClass enter] %s\n", t.toChars());
            scope(exit) printf("[AST.TypeClass exit] %s\n", t.toChars());
        }
        if (cast(void*)t.sym !in forwarded)
        {
            forwarded[cast(void*)t.sym] = true;
            fwdbuf.writestring("class ");
            fwdbuf.writestring(t.sym.toChars());
            fwdbuf.writestring(";\n");
        }

        if (!cdparent && t.isConst())
            buf.writestring("const ");
        buf.writestring(t.sym.toChars());
        buf.writeByte('*');
        if (!cdparent && t.isConst())
            buf.writestring(" const");
    }

    private void funcToBuffer(AST.TypeFunction tf, AST.FuncDeclaration fd)
    {
        debug (Debug_DtoH)
        {
            printf("[funcToBuffer(AST.TypeFunction) enter] %s\n", tf.toChars());
            scope(exit) printf("[funcToBuffer(AST.TypeFunction) exit] %s\n", tf.toChars());
        }

        Identifier ident = fd.ident;
        auto originalType = cast(AST.TypeFunction)fd.originalType;

        assert(tf.next);

        if (fd.isCtorDeclaration() || fd.isDtorDeclaration())
        {
            if (fd.isDtorDeclaration())
            {
                buf.writeByte('~');
            }
            buf.writestring(adparent.toChars());
        }
        else
        {
            tf.next == AST.Type.tsize_t ? originalType.next.accept(this) : tf.next.accept(this);
            if (tf.isref)
                buf.writeByte('&');
            buf.writeByte(' ');
            buf.writestring(ident.toChars());
        }

        buf.writeByte('(');
        foreach (i; 0 .. AST.Parameter.dim(tf.parameterList.parameters))
        {
            if (i)
                buf.writestring(", ");
            auto fparam = AST.Parameter.getNth(tf.parameterList.parameters, i);
            if (fparam.type == AST.Type.tsize_t && originalType)
            {
                fparam = AST.Parameter.getNth(originalType.parameterList.parameters, i);
            }
            fparam.accept(this);

        }
        if (tf.parameterList.varargs)
        {
            if (tf.parameterList.parameters.dim && tf.parameterList.varargs == 1)
                buf.writestring(", ");
            buf.writestring("...");
        }
        buf.writeByte(')');
    }

    override void visit(AST.Parameter p)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.Parameter enter] %s\n", p.toChars());
            scope(exit) printf("[AST.Parameter exit] %s\n", p.toChars());
        }
        ident = p.ident;
        p.type.accept(this);
        assert(!(p.storageClass & ~(AST.STC.ref_)));
        if (p.storageClass & AST.STC.ref_)
            buf.writeByte('&');
        buf.writeByte(' ');
        if (ident)
            buf.writestring(ident.toChars());
        ident = null;
        version (all)
        {
            if (p.defaultArg && p.defaultArg.op >= TOK.int32Literal && p.defaultArg.op < TOK.struct_)
            {
                //printf("%s %d\n", p.defaultArg.toChars, p.defaultArg.op);
                buf.writestring(" = ");
                buf.writestring(p.defaultArg.toChars());
            }
        }
        else
        {
            if (p.defaultArg)
            {
                //printf("%s %d\n", p.defaultArg.toChars, p.defaultArg.op);
                //return;
                buf.writestring("/*");
                buf.writestring(" = ");
                buf.writestring(p.defaultArg.toChars());
                //p.defaultArg.accept(this);
                buf.writestring("*/");
            }
        }
    }

    override void visit(AST.Expression e)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.Expression enter] %s\n", e.toChars());
            scope(exit) printf("[AST.Expression exit] %s\n", e.toChars());
        }
        assert(0);
    }

    override void visit(AST.NullExp e)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.NullExp enter] %s\n", e.toChars());
            scope(exit) printf("[AST.NullExp exit] %s\n", e.toChars());
        }
        buf.writestring("nullptr");
    }

    override void visit(AST.ArrayLiteralExp e)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.ArrayLiteralExp enter] %s\n", e.toChars());
            scope(exit) printf("[AST.ArrayLiteralExp exit] %s\n", e.toChars());
        }
        buf.writestring("arrayliteral");
    }

    override void visit(AST.StringExp e)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.StringExp enter] %s\n", e.toChars());
            scope(exit) printf("[AST.StringExp exit] %s\n", e.toChars());
        }
        if (e.sz == 2)
            buf.writeByte('u');
        else if (e.sz == 4)
            buf.writeByte('U');
        buf.writeByte('"');

        for (size_t i = 0; i < e.len; i++)
        {
            uint c = e.charAt(i);
            switch (c)
            {
                case '"':
                case '\\':
                    buf.writeByte('\\');
                    goto default;
                default:
                    if (c <= 0xFF)
                    {
                        if (c >= 0x20 && c < 0x80)
                            buf.writeByte(c);
                        else
                            buf.printf("\\x%02x", c);
                    }
                    else if (c <= 0xFFFF)
                        buf.printf("\\u%04x", c);
                    else
                        buf.printf("\\U%08x", c);
                    break;
            }
        }
        buf.writeByte('"');
    }

    override void visit(AST.RealExp e)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.RealExp enter] %s\n", e.toChars());
            scope(exit) printf("[AST.RealExp exit] %s\n", e.toChars());
        }

        // TODO: Needs to implemented, used e.g. for struct member initializers
        buf.writestring("0");
    }

    override void visit(AST.IntegerExp e)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.IntegerExp enter] %s\n", e.toChars());
            scope(exit) printf("[AST.IntegerExp exit] %s\n", e.toChars());
        }
        visitInteger(e.toInteger, e.type);
    }

    private void visitInteger(dinteger_t v, AST.Type t)
    {
        debug (Debug_DtoH)
        {
            printf("[visitInteger(AST.Type) enter] %s\n", t.toChars());
            scope(exit) printf("[visitInteger(AST.Type) exit] %s\n", t.toChars());
        }
        switch (t.ty)
        {
            case AST.Tenum:
                auto te = cast(AST.TypeEnum)t;
                buf.writestring("(");
                enumToBuffer(te.sym);
                buf.writestring(")");
                visitInteger(v, te.sym.memtype);
                break;
            case AST.Tbool:
                buf.writestring(v ? "true" : "false");
                break;
            case AST.Tint8:
                buf.printf("%d", cast(byte)v);
                break;
            case AST.Tuns8:
                buf.printf("%uu", cast(ubyte)v);
                break;
            case AST.Tint16:
                buf.printf("%d", cast(short)v);
                break;
            case AST.Tuns16:
            case AST.Twchar:
                buf.printf("%uu", cast(ushort)v);
                break;
            case AST.Tint32:
            case AST.Tdchar:
                buf.printf("%d", cast(int)v);
                break;
            case AST.Tuns32:
                buf.printf("%uu", cast(uint)v);
                break;
            case AST.Tint64:
                buf.printf("%lldLL", v);
                break;
            case AST.Tuns64:
                buf.printf("%lluLLU", v);
                break;
            case AST.Tchar:
                if (v > 0x20 && v < 0x80)
                    buf.printf("'%c'", cast(int)v);
                else
                    buf.printf("%uu", cast(ubyte)v);
                break;
            default:
                //t.print();
                assert(0);
        }
    }

    override void visit(AST.StructLiteralExp sle)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.StructLiteralExp enter] %s\n", sle.toChars());
            scope(exit) printf("[AST.StructLiteralExp exit] %s\n", sle.toChars());
        }
        buf.writestring(sle.sd.ident.toChars());
        buf.writeByte('(');
        foreach(i, e; *sle.elements)
        {
            if (i)
                buf.writestring(", ");
            e.accept(this);
        }
        buf.writeByte(')');
    }
}
