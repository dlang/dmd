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
// import core.stdc.ctype : ;

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

void hashIf(ref OutBuffer buf, string content)
{
    buf.writestring("#if ");
    buf.writestringln(content);
}

void hashElIf(ref OutBuffer buf, string content)
{
    buf.writestring("#elif ");
    buf.writestringln(content);
}

void hashEndIf(ref OutBuffer buf)
{
    buf.writestringln("#endif");
}

void hashDefine(ref OutBuffer buf, string content)
{
    buf.writestring("# define ");
    buf.writestringln(content);
}

void hashInclude(ref OutBuffer buf, string content)
{
    buf.writestring("#include ");
    buf.writestringln(content);
}



extern(C++) void genCppHdrFiles(ref Modules ms)
{
    initialize();

    OutBuffer fwd;
    OutBuffer check;
    OutBuffer done;
    OutBuffer decl;

    // enable indent by spaces on buffers
    fwd.doindent = true;
    fwd.spaces = true;
    decl.doindent = true;
    decl.spaces = true;
    check.doindent = true;
    check.spaces = true;

    scope v = new ToCppBuffer(&check, &fwd, &done, &decl);

    OutBuffer buf;
    buf.doindent = true;
    buf.spaces = true;

    foreach (m; ms)
        m.accept(v);

    if (global.params.doCxxHdrGeneration == CxxHeaderMode.verbose)
        buf.printf("// Automatically generated by %s Compiler v%d", global.vendor.ptr, global.versionNumber());
    else
        buf.printf("// Automatically generated by %s Compiler", global.vendor.ptr);

    buf.writenl();
    buf.writenl();
    buf.writestringln("#pragma once");
    buf.writenl();
//    buf.writestring("#include <assert.h>\n");
    hashInclude(buf, "<stddef.h>");
    hashInclude(buf, "<stdint.h>");
//    buf.writestring(buf, "#include <stdio.h>\n");
//    buf.writestring("#include <string.h>\n");
    buf.writenl();
    if (v.hasReal)
    {
        hashIf(buf, "!defined(_d_real)");
        {
            hashDefine(buf, "_d_real long double");
        }
        hashEndIf(buf);
    }
    buf.writenl();

    buf.write(&fwd);
    if (fwd.length > 0)
        buf.writenl();

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
extern(C++) final class ToCppBuffer : Visitor
{
    alias visit = Visitor.visit;
public:
    enum EnumKind
    {
        Int,
        Numeric,
        String,
        Enum,
        Other
    }

    alias AST = ASTCodegen;

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
    const bool printIgnored;

    this(OutBuffer* checkbuf, OutBuffer* fwdbuf, OutBuffer* donebuf, OutBuffer* buf)
    {
        this.checkbuf = checkbuf;
        this.fwdbuf = fwdbuf;
        this.donebuf = donebuf;
        this.buf = buf;
        this.printIgnored = global.params.doCxxHdrGeneration == CxxHeaderMode.verbose;
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
            case AST.Tarray:
                if (type.isString())
                    return EnumKind.String;
                break;
            case AST.Tenum:
                return EnumKind.Enum;
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

    void writeDeclEnd()
    {
        buf.writestringln(";");

        if (!adparent)
            buf.writenl();
    }

    override void visit(AST.Dsymbol s)
    {
        debug (Debug_DtoH)
        {
            printf("[AST.Dsymbol enter] %s\n", s.toChars());
            import dmd.asttypename;
            printf("[AST.Dsymbol enter] %s\n", s.astTypeName().ptr);
            scope(exit) printf("[AST.Dsymbol exit] %s\n", s.toChars());
        }

        if (isBuildingCompiler && s.getModule() && s.getModule().isFrontendModule())
        {
            if (printIgnored)
            {
                buf.printf("// ignored %s %s", s.kind(), s.toPrettyChars());
                buf.writenl();
            }
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
            if (printIgnored)
            {
                buf.printf("// ignoring %s block because of linkage", ld.toPrettyChars());
                buf.writenl();
            }
        }
        else
        {
            visit(cast(AST.AttribDeclaration)ld);
        }
        linkage = save;
    }

    override void visit(AST.CPPMangleDeclaration md)
    {
        const oldLinkage = this.linkage;
        this.linkage = LINK.cpp;
        visit(cast(AST.AttribDeclaration) md);
        this.linkage = oldLinkage;
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
        if (!tf || !tf.deco)
        {
            if (printIgnored)
            {
                buf.printf("// ignoring function %s because semantic hasn't been run", fd.toPrettyChars());
                buf.writenl();
            }
            return;
        }
        if (tf.linkage != LINK.c && tf.linkage != LINK.cpp)
        {
            if (printIgnored)
            {
                buf.printf("// ignoring function %s because of linkage", fd.toPrettyChars());
                buf.writenl();
            }
            return;
        }
        if (!adparent && !fd.fbody)
        {
            if (printIgnored)
            {
                buf.printf("// ignoring function %s because it's extern", fd.toPrettyChars());
                buf.writenl();
            }
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
                const cn = adparent.ident.toChars();
                const fn = fd.ident.toChars();
                const vi = fd.vtblIndex;

                checkbuf.printf("assert(getSlotNumber <%s>(0, &%s::%s) == %d);",
                                                       cn,     cn, fn,    vi);
                checkbuf.writenl();
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
            buf.writestring(" = delete");
        buf.writestringln(";");
        if (adparent && fd.isDisabled && global.params.cplusplus < CppStdRevision.cpp11)
            buf.writestringln("public:");

        if (!adparent)
            buf.writenl();

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

        // Tuple field are expanded into multiple VarDeclarations
        // (we'll visit them later)
        if (vd.type && vd.type.isTypeTuple())
            return;

        if (vd.type == AST.Type.tsize_t)
            origType = &vd.originalType;
        scope(exit) origType = null;

        if (vd.alignment != STRUCTALIGN_DEFAULT)
        {
            buf.printf("// Ignoring var %s alignment %u", vd.toChars(), vd.alignment);
            buf.writenl();
        }

        if (vd.storage_class & AST.STC.manifest &&
            vd._init && vd._init.isExpInitializer() && vd.type !is null)
        {
            AST.Type type = vd.type;
            EnumKind kind = getEnumKind(type);
            enum ProtPublic = AST.Prot(AST.Prot.Kind.public_);
            if (vd.protection.isMoreRestrictiveThan(ProtPublic)) {
                if (printIgnored)
                {
                    buf.printf("// ignoring enum `%s` because it is `%s`.", vd.toPrettyChars(), AST.protectionToChars(vd.protection.kind));
                    buf.writenl;
                }
                return;
            }

            final switch (kind)
            {
                case EnumKind.Int, EnumKind.Numeric:
                    // 'enum : type' is only available from C++-11 onwards.
                    if (global.params.cplusplus < CppStdRevision.cpp11)
                        goto case;
                    buf.writestring("enum : ");
                    writeEnumTypeName(type);
                    buf.printf(" { %s = ", vd.ident.toChars());
                    auto ie = AST.initializerToExpression(vd._init).isIntegerExp();
                    visitInteger(ie.toInteger(), type);
                    buf.writestring(" };");
                    break;

                case EnumKind.String, EnumKind.Enum:
                    buf.writestring("static ");
                    writeEnumTypeName(type);
                    buf.printf(" const %s = ", vd.ident.toChars());
                    auto e = AST.initializerToExpression(vd._init);
                    e.accept(this);
                    buf.writestring(";");
                    break;

                case EnumKind.Other:
                    if (printIgnored)
                    {
                        buf.printf("// ignoring enum `%s` because type `%s` is currently not supported for enum constants.", vd.toPrettyChars(), type.toChars());
                        buf.writenl;
                    }
                    return;
            }
            buf.writenl();
            buf.writenl();
            return;
        }

        if (tdparent && vd.type && !vd.type.deco)
        {
            if (linkage != LINK.c && linkage != LINK.cpp)
            {
                if (printIgnored)
                {
                    buf.printf("// ignoring variable %s because of linkage", vd.toPrettyChars());
                    buf.writenl();
                }
                return;
            }
            typeToBuffer(vd.type, vd.ident);
            buf.writestringln(";");
            return;
        }

        if (vd.storage_class & (AST.STC.static_ | AST.STC.extern_ | AST.STC.tls | AST.STC.gshared) ||
        vd.parent && vd.parent.isModule())
        {
            if (vd.linkage != LINK.c && vd.linkage != LINK.cpp)
            {
                if (printIgnored)
                {
                    buf.printf("// ignoring variable %s because of linkage", vd.toPrettyChars());
                    buf.writenl();
                }
                return;
            }
            if (vd.storage_class & AST.STC.tls)
            {
                if (printIgnored)
                {
                    buf.printf("// ignoring variable %s because of thread-local storage", vd.toPrettyChars());
                    buf.writenl();
                }
                return;
            }
            if (vd.linkage == LINK.c)
                buf.writestring("extern \"C\" ");
            else if (!adparent)
                buf.writestring("extern ");
            if (adparent)
                buf.writestring("static ");
            typeToBuffer(vd.type, vd.ident);
            writeDeclEnd();
            return;
        }

        if (adparent && vd.type && vd.type.deco)
        {
            auto save = cdparent;
            cdparent = vd.isField() ? adparent.isClassDeclaration() : null;
            typeToBuffer(vd.type, vd.ident);
            cdparent = save;
            buf.writestringln(";");

            if (auto t = vd.type.isTypeStruct())
                includeSymbol(t.sym);

            checkbuf.level++;
            const pn = adparent.ident.toChars();
            const vn = vd.ident.toChars();
            const vo = vd.offset;
            checkbuf.printf("assert(offsetof(%s, %s) == %d);",
                                             pn, vn,    vo);
            checkbuf.writenl();
            checkbuf.level--;
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
            writeDeclEnd();
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
            writeDeclEnd();
            return;
        }
        if (ad.aliassym.isDtorDeclaration())
        {
            // Ignore. It's taken care of while visiting FuncDeclaration
            return;
        }

        if (printIgnored)
        {
            buf.printf("// ignored %s %s", ad.aliassym.kind(), ad.aliassym.toPrettyChars());
            buf.writenl();
        }
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

        buf.writestringln(ad.isunion ? "union" : "struct");
        buf.writestringln("{");
        buf.level++;
        foreach (s; *ad.decl)
        {
            s.accept(this);
        }
        buf.level--;
        buf.writestringln("};");
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
            if (printIgnored)
            {
                buf.printf("// ignoring non-cpp struct %s because of linkage", sd.toChars());
                buf.writenl();
            }
            return;
        }

        pushAlignToBuffer(sd.alignment);

        const structAsClass = sd.cppmangle == CPPMANGLE.asClass;
        if (sd.isUnionDeclaration())
            buf.writestring("union ");
        else
            buf.writestring(structAsClass ? "class " : "struct ");

        buf.writestring(sd.ident.toChars());
        if (!sd.members)
        {
            buf.writestringln(";");
            buf.writenl();
            return;
        }

        buf.writenl();
        buf.writestring("{");

        if (structAsClass)
        {
            buf.writenl();
            buf.writestring("public:");
        }

        buf.level++;
        buf.writenl();
        auto save = adparent;
        adparent = sd;

        foreach (m; *sd.members)
        {
            m.accept(this);
        }
        buf.level--;
        adparent = save;
        // Generate default ctor
        if (!sd.noDefaultCtor)
        {
            buf.level++;
            buf.printf("%s()", sd.ident.toChars());
            size_t varCount;
            bool first = true;
            buf.level++;
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
                        buf.writestringln(" :");
                        first = false;
                    }
                    else
                    {
                        buf.writestringln(",");
                    }
                    buf.printf("%s(", vd.ident.toChars());

                    if (vd._init)
                    {
                        AST.initializerToExpression(vd._init).accept(this);
                    }
                    buf.printf(")");
                }
            }
            buf.level--;
            buf.writenl();
            buf.writestringln("{");
            buf.writestringln("}");
            buf.level--;
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
                buf.printf(" }");
                buf.writenl();
            }
        }
        buf.writestringln("};");

        popAlignToBuffer(sd.alignment);
        buf.writenl();

        checkbuf.level++;
        const sn = sd.ident.toChars();
        const sz = sd.size(Loc.initial);
        checkbuf.printf("assert(sizeof(%s) == %llu);", sn, sz);
        checkbuf.writenl();
        checkbuf.level--;
    }

    private void pushAlignToBuffer(uint alignment)
    {
        // DMD ensures alignment is a power of two
        //assert(alignment > 0 && ((alignment & (alignment - 1)) == 0),
        //       "Invalid alignment size");

        // When no alignment is specified, `uint.max` is the default
        if (alignment == STRUCTALIGN_DEFAULT)
        {
            return;
        }

        buf.printf("#pragma pack(push, %d)", alignment);
        buf.writenl();
    }

    private void popAlignToBuffer(uint alignment)
    {
        if (alignment == STRUCTALIGN_DEFAULT)
            return;

        buf.writestringln("#pragma pack(pop)");
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
        decl.doindent = true;
        decl.spaces = true;
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
            if (printIgnored)
                buf.printf("// ignoring non-cpp class %s\n", cd.toChars());
            return;
        }

        const classAsStruct = cd.cppmangle == CPPMANGLE.asStruct;
        buf.writestring(classAsStruct ? "struct " : "class ");
        buf.writestring(cd.ident.toChars());

        assert(cd.baseclasses);

        foreach (i, base; *cd.baseclasses)
        {
            buf.writestring(i == 0 ? " : public " : ", public ");

            buf.writestring(base.sym.ident.toChars());
            includeSymbol(base.sym);
        }

        if (!cd.members)
        {
            buf.writestring(";");
            buf.writenl();
            buf.writenl();
            return;
        }

        buf.writenl();
        buf.writestringln("{");
        if (!classAsStruct)
            buf.writestringln("public:");

        auto save = adparent;
        adparent = cd;
        buf.level++;
        foreach (m; *cd.members)
        {
            m.accept(this);
        }
        buf.level--;
        adparent = save;

        // Generate special static inline function.
        if (isBuildingCompiler && cd.isIdentifierClass())
        {
            buf.writestringln("static inline Identifier *idPool(const char *s) { return idPool(s, strlen(s)); }");
        }

        buf.writestringln("};");
        buf.writenl();
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
            //if (printIgnored)
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

        // write the enum header
        if (!manifestConstants)
        {
            if (kind == EnumKind.Int || kind == EnumKind.Numeric)
            {
                buf.writestring("enum");
                // D enums are strong enums, but there exists only a direct mapping
                // with 'enum class' from C++-11 onwards.
                if (global.params.cplusplus >= CppStdRevision.cpp11)
                {
                    if (!isAnonymous)
                    {
                        buf.writestring(" class ");
                        buf.writestring(ed.ident.toString());
                    }
                    if (kind == EnumKind.Numeric)
                    {
                        buf.writestring(" : ");
                        writeEnumTypeName(type);
                    }
                }
                else if (!isAnonymous)
                {
                    buf.writeByte(' ');
                    buf.writestring(ed.ident.toString());
                }
            }
            else
            {
                buf.writestring("namespace");
                if(!isAnonymous)
                {
                    buf.writeByte(' ');
                    buf.writestring(ed.ident.toString());
                }
            }
            buf.writenl();
            buf.writestringln("{");
        }

        // emit constant for each member
        if (!manifestConstants)
            buf.level++;

        foreach (_m; *ed.members)
        {
            auto m = _m.isEnumMember();
            AST.Type memberType = type ? type : m.type;
            const EnumKind memberKind = type ? kind : getEnumKind(memberType);

            if (!manifestConstants && (kind == EnumKind.Int || kind == EnumKind.Numeric))
            {
                // C++-98 compatible enums must use the typename as a prefix to avoid
                // collisions with other identifiers in scope.  For consistency with D,
                // the enum member `Type.member` is emitted as `Type_member` in C++-98.
                if (isAnonymous || global.params.cplusplus >= CppStdRevision.cpp11)
                    buf.printf("%s = ", m.ident.toChars());
                else
                    buf.printf("%s_%s = ", ed.ident.toChars(), m.ident.toChars());
                auto ie = cast(AST.IntegerExp)m.value;
                visitInteger(ie.toInteger(), memberType);
                buf.writestring(",");
            }
            else if (global.params.cplusplus >= CppStdRevision.cpp11 &&
                     manifestConstants && (memberKind == EnumKind.Int || memberKind == EnumKind.Numeric))
            {
                buf.writestring("enum : ");
                writeEnumTypeName(memberType);
                buf.printf(" { %s = ", m.ident.toChars());
                auto ie = cast(AST.IntegerExp)m.value;
                visitInteger(ie.toInteger(), memberType);
                buf.writestring(" };");
            }
            else
            {
                buf.writestring("static ");
                writeEnumTypeName(memberType);
                buf.printf(" const %s = ", m.ident.toChars());
                m.value.accept(this);
                buf.writestring(";");
            }
            buf.writenl();
        }

        if (!manifestConstants)
            buf.level--;
        // write the enum tail
        if (!manifestConstants)
            buf.writestring("};");
        buf.writenl();
        buf.writenl();
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
        foreach (i, fparam; tf.parameterList)
        {
            if (i)
                buf.writestring(", ");
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
            fwdbuf.writestringln(";");
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
            if (printIgnored)
            {
                buf.printf("// ignoring template %s because of linkage", td.toPrettyChars());
                buf.writenl();
            }
            return;
        }

        auto sd = td.onemember.isStructDeclaration();
        auto save = tdparent;
        tdparent = td;

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
        buf.writestringln(">");

        // TODO replace this block with a sd.accept
        {
            buf.writestring(sd.isUnionDeclaration() ? "union " : "struct ");
            buf.writestring(sd.ident.toChars());
            if (sd.members)
            {
                buf.writenl();
                buf.writestringln("{");
                auto savex = adparent;
                adparent = sd;
                buf.level++;
                foreach (m; *sd.members)
                {
                    m.accept(this);
                }
                buf.level--;
                adparent = savex;
                buf.writestringln("};");
                buf.writenl();
            }
            else
            {
                buf.writestringln(";");
                buf.writenl();
            }
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
            fwdbuf.writestringln(";");
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
        foreach (i, fparam; tf.parameterList)
        {
            if (i)
                buf.writestring(", ");
            if (fparam.type == AST.Type.tsize_t && originalType)
            {
                fparam = originalType.parameterList[i];
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

        // TODO: Needs to implemented, properly switching on the e.type
        buf.printf("%ff", cast(double)e.value);
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
