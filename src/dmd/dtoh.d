/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
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
import dmd.json;
import dmd.mars;
import dmd.root.array;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.rmem;
import dmd.visitor;

import dmd.root.outbuffer;
version(BUILD_COMPILER)
{
    immutable string[] sources = [
        "access.d", "aggregate.d", "aliasthis.d", "apply.d", "argtypes.d", "arrayop.d", "arraytypes.d", "attrib.d",
        "blockexit.d", "builtin.d",
        "canthrow.d", "clone.d", "compiler.d", "complex.d", "cond.d", "console.d", "constfold.d", "cppmangle.d", "cppmanglewin.d", "ctfeexpr.d", "ctorflow.d",
        "dcast.d", "dclass.d", "declaration.d", "delegatize.d", "denum.d", "dimport.d", "dinterpret.d",
        "dmacro.d", "dmangle.d", "dmodule.d", "doc.d", "dscope.d", "dstruct.d", "dsymbol.d", "dsymbolsem.d", "dtemplate.d", "dversion.d",
        "entity.d", "errors.d", "escape.d", "expression.d", "expressionsem.d",
        "func.d",
        "globals.d", "gluelayer.d",
        "hdrgen.d",
        "iasm.d", "id.d", "identifier.d", "impcnvtab.d", "imphint.d", "init.d", "initsem.d", "inline.d", "inlinecost.d", "intrange.d",
        "json.d",
        "lambdacomp.d", "lexer.d",
        "mtype.d",
        "nogc.d", "nspace.d",
        "objc.d", "opover.d", "optimize.d",
        "parse.d", "printast.d",
        "safe.d", "sapply.d", "semantic2.d", "semantic3.d", "sideeffect.d", "statement.d",
        "statementsem.d", "staticassert.d", "staticcond.d",
        "target.d", "templateparamsem.d", "tokens.d", "traits.d", "typesem.d", "typinf.d",
        "utf.d", "utils.d",
    ];
}

int main(string[] args)
{
    import std.algorithm.sorting : sort;
    import std.array : array;
    import std.file : readText;
    import std.path : baseName, buildPath, dirName;
    import std.string : toStringz;

    import dmd.dsymbolsem;
    import dmd.errors;
    import dmd.id;
    import dmd.dinifile;
    import dmd.parse;

    import dmd.semantic2;
    import dmd.semantic3;
    import dmd.builtin : builtin_init;
    import dmd.dmodule : Module;
    import dmd.expression : Expression;
    import dmd.frontend;
    import dmd.objc : Objc;
    import dmd.root.response;
    import dmd.root.stringtable;
    import dmd.target : Target;
    
    import core.memory;
    import core.stdc.stdio : printf;
    
    GC.disable();
    initDMD();
    
    Strings arguments = Strings(args.length);
    for (size_t i = 0; i < args.length; i++)
    {
        arguments[i] = args[i].ptr;
    }
    if (response_expand(&arguments)) // expand response files
        error(Loc.initial, "can't open response file");
    auto files = Strings(arguments.dim - 1);
    global.params.argv0 = args[0];

    
    global.inifilename = parse_conf_arg(&arguments);
    if (global.inifilename)
    {
        // can be empty as in -conf=
        if (strlen(global.inifilename) && !FileName.exists(global.inifilename))
        error(Loc.initial, "Config file '%s' does not exist.", global.inifilename);
    }
    else
    {
        version (Windows)
        {
            global.inifilename = findConfFile(global.params.argv0, "sc.ini").ptr;
        }
        else version (Posix)
        {
            global.inifilename = findConfFile(global.params.argv0, "dmd.conf").ptr;
        }
        else
        {
            static assert(0, "fix this");
        }
    }
    // Read the configurarion file
    auto inifile = File(global.inifilename);
    inifile.read();
    /* Need path of configuration file, for use in expanding @P macro
     */
    const(char)* inifilepath = FileName.path(global.inifilename);
    Strings sections;
    StringTable environment;
    environment._init(7);
    /* Read the [Environment] section, so we can later
     * pick up any DFLAGS settings.
     */
    sections.push("Environment");
    parseConfFile(&environment, global.inifilename, inifilepath, inifile.len, inifile.buffer, &sections);
    
    const(char)* arch = global.params.is64bit ? "64" : "32"; // use default
    arch = parse_arch_arg(&arguments, arch);
    
    // parse architecture from DFLAGS read from [Environment] section
    {
        Strings dflags;
        getenv_setargv(readFromEnv(&environment, "DFLAGS"), &dflags);
        environment.reset(7); // erase cached environment updates
        arch = parse_arch_arg(&dflags, arch);
    }
    
    bool is64bit = arch[0] == '6';
    
    version(Windows) // delete LIB entry in [Environment] (necessary for optlink) to allow inheriting environment for MS-COFF
    if (is64bit || strcmp(arch, "32mscoff") == 0)
    environment.update("LIB", 3).ptrvalue = null;
    
    // read from DFLAGS in [Environment{arch}] section
    char[80] envsection = void;
    sprintf(envsection.ptr, "Environment%s", arch);
    sections.push(envsection.ptr);
    parseConfFile(&environment, global.inifilename, inifilepath, inifile.len, inifile.buffer, &sections);
    getenv_setargv(readFromEnv(&environment, "DFLAGS"), &arguments);
    updateRealEnvironment(&environment);
    environment.reset(1); // don't need environment cache any more
    
    if (parseCommandLine(arguments, args.length, global.params, files))
    {
        Loc loc;
        errorSupplemental(loc, "run 'dmd -man' to open browser on manual");
        return 1;
    }
    

    version(BUILD_COMPILER)
    {
        global.path.push(druntimeFullPath.toStringz());
        //TODO: fixme for LDC
        global.filePath.push(__FILE_FULL_PATH__.dirName.buildPath("../../").toStringz());
        global.filePath.push(__FILE_FULL_PATH__.dirName.buildPath("../../res/").toStringz());
    }
    
    DMDType._init();
    version(BUILD_COMPILER)
    {
        DMDModule._init();
        DMDClass._init();
    }

    setVersions();

    Modules modules;
    
    string path = __FILE_FULL_PATH__.dirName.buildPath("../dmd/");
    version (BUILD_COMPILER)
        auto srcs = sources;
    else
        auto srcs = args [1 .. $];
    foreach (f; srcs)
    {
        string fn = buildPath(path, f);
        
        auto id = Identifier.idPool(baseName(fn, ".d"));
        auto m = new Module(fn.toStringz(), id, false, false);
        auto input = readText(fn);
        
        if (!Module.rootModule)
            Module.rootModule = m;
        
        m.importedFrom = m;
        m.srcfile.setbuffer(cast(void*)input.ptr, input.length);
        m.srcfile._ref = 1;
        m.parse();
        modules.push(m);
    }
    
    foreach (m; modules)
        m.importAll(null);
    foreach (m; modules)
        m.dsymbolSemantic(null);

    Module.dprogress = 1;
    Module.runDeferredSemantic();

    foreach (m; modules)
        m.semantic2(null);
    Module.runDeferredSemantic2();

    foreach (m; modules)
        m.semantic3(null);
    Module.runDeferredSemantic3();
    
    OutBuffer buf;
    genCppFiles(&buf, &modules);
    
    printf("%s\n", buf.peekString());
    return 0;
}

void setVersions()
{
    import dmd.cond : VersionCondition;
    version(BUILD_COMPILER)
    {
        VersionCondition.addPredefinedGlobalIdent("NoBackend");
        VersionCondition.addPredefinedGlobalIdent("NoMain");
    }
}

struct DMDType
{
    static Identifier c_long;
    static Identifier c_ulong;
    static Identifier c_longlong;
    static Identifier c_ulonglong;
    static Identifier c_long_double;
    version(BUILD_COMPILER)
    {
        static Identifier AssocArray;
        static Identifier Array;
    }
    static void _init()
    {
        c_long          = Identifier.idPool("__c_long");
        c_ulong         = Identifier.idPool("__c_ulong");
        c_longlong      = Identifier.idPool("__c_longlong");
        c_ulonglong     = Identifier.idPool("__c_ulonglong");
        c_long_double   = Identifier.idPool("__c_long_double");
        version(BUILD_COMPILER)
        {
            AssocArray      = Identifier.idPool("AssocArray");
            Array           = Identifier.idPool("Array");
        }

    }
}
version(BUILD_COMPILER)
{
    struct DMDModule
    {
        static Identifier identifier;
        static Identifier root;
        static Identifier visitor;
        static Identifier parsetimevisitor;
        static Identifier permissivevisitor;
        static Identifier strictvisitor;
        static Identifier transitivevisitor;
        static Identifier dmd;
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
    struct DMDClass
    {
        static Identifier ID; ////Identifier
        static Identifier Visitor;
        static Identifier ParseTimeVisitor;
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
            if (cdb.ident == DMClass.Visitor ||
                cdb.ident == DMClass.ParseTimeVisitor)
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
    
    string druntimeFullPath()
    {
        version (IN_LLVM)
            string path = "../runtime/druntime/src";
        else
            string path = "../../../druntime/src/";
        
        return __FILE_FULL_PATH__.dirName.buildPath(path);
    }
}

/****************************************************
 */
extern(C++) final class ToCppBuffer(AST) : Visitor
{
    alias visit = Visitor.visit;
public:
    bool[void*] visited;
    bool[void*] forwarded;
    OutBuffer *fwdbuf;
    OutBuffer *checkbuf;
    OutBuffer *donebuf;
    OutBuffer *buf;
    AST.AggregateDeclaration adparent;
    AST.ClassDeclaration cdparent;
    AST.TemplateDeclaration tdparent;
    Identifier ident;
    LINK linkage = LINK.d;
    
    this(OutBuffer* checkbuf, OutBuffer* fwdbuf, OutBuffer* donebuf, OutBuffer* buf)
    {
        this.checkbuf = checkbuf;
        this.fwdbuf = fwdbuf;
        this.donebuf = donebuf;
        this.buf = buf;
    }
    
    private void indent()
    {
        if (adparent)
            buf.writestring("    ");
    }
    
    override void visit(AST.Dsymbol s)
    {
        version(BUILD_COMPILER)
        {
            if (s.getModule() && s.getModule().isFrontendModule())
            {
                indent();
                buf.printf("// ignored %s %s\n", s.kind(), s.toPrettyChars());
            }
        }
        
    }
    
    override void visit(AST.Import)
    {
    }
    
    override void visit(AST.AttribDeclaration pd)
    {
        Dsymbols* decl = pd.include(null);
        if (decl)
        {
            foreach (s; *decl)
            {
                if (!adparent && s.prot().kind < AST.Prot.Kind.public_)
                    continue;
                s.accept(this);
            }
        }
    }
    
    override void visit(AST.LinkDeclaration ld)
    {
        auto save = linkage;
        linkage = ld.linkage;
        if (ld.linkage != LINK.c && ld.linkage != LINK.cpp)
        {
            indent();
            buf.printf("// ignoring %s block because of linkage\n", ld.toPrettyChars());
        }
        else
            visit(cast(AST.AttribDeclaration)ld);
        linkage = save;
    }
    
    override void visit(AST.Module m)
    {
        foreach (s; *m.members)
        {
            if (s.prot().kind < AST.Prot.Kind.public_)
                continue;
            s.accept(this);
        }
    }
    
    override void visit(AST.FuncDeclaration fd)
    {
        if (cast(void*)fd in visited)
            return;
        version(BUILD_COMPILER)
        {
            if (fd.getModule() && !fd.getModule().isFrontendModule())
            return;
        }
        
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
        funcToBuffer(tf, fd.ident);
        if (adparent && tf.isConst())
            buf.writestring(" const");
        if (adparent && fd.isAbstract())
            buf.writestring(" = 0");
        buf.printf(";\n");
        if (!adparent)
            buf.printf("\n");
    }
    
    override void visit(AST.UnitTestDeclaration fd)
    {
    }
    
    override void visit(AST.VarDeclaration vd)
    {
        if (cast(void*)vd in visited)
        return;
        version(BUILD_COMPILER)
        {
            if (vd.getModule() && !vd.getModule().isFrontendModule())
                return;
        }
        
        visited[cast(void*)vd] = true;
        
        if (vd.storage_class & AST.STC.manifest &&
            vd.type.isintegral() &&
            vd._init && vd._init.isExpInitializer())
        {
            indent();
            buf.writestring("#define ");
            buf.writestring(vd.ident.toChars());
            buf.writestring(" ");
            auto e = AST.initializerToExpression(vd._init);
            if (e.type.ty == AST.Tbool)
                buf.printf("%d", e.toInteger());
            else
                AST.initializerToExpression(vd._init).accept(this);
            buf.writestring("\n");
            if (!adparent)
                buf.printf("\n");
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
            if (vd.type.ty == AST.Tstruct)
            {
                auto t = cast(AST.TypeStruct)vd.type;
                includeSymbol(t.sym);
            }
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
    
    override void visit(AST.TypeInfoDeclaration)
    {
    }
    
    override void visit(AST.AliasDeclaration ad)
    {
        version(BUILD_COMPILER)
        {
            if (ad.getModule() && !ad.getModule().isFrontendModule())
            return;
        }
        
        if (auto t = ad.type)
        {
            if (t.ty == AST.Tdelegate)
            {
                visit(cast(AST.Dsymbol)ad);
                return;
            }
            buf.writestring("typedef ");
            typeToBuffer(t, ad.ident);
            buf.writestring(";\n");
            if (!adparent)
                buf.printf("\n");
            return;
        }
        if (!ad.aliassym)
        {
            //ad.print();
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
        indent();
        buf.printf("// ignored %s %s\n", ad.aliassym.kind(), ad.aliassym.toPrettyChars());
    }
    
    override void visit(AST.AnonDeclaration ad)
    {
        buf.writestring(ad.isunion ? "union" : "struct");
        buf.writestring("\n{\n");
        foreach (s; *ad.decl)
        {
            s.accept(this);
        }
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
        if (sd.isInstantiated())
            return;
        if (cast(void*)sd in visited)
            return;
        if (!sd.type || !sd.type.deco)
            return;
        version(BUILD_COMPILER)
        {
            if (sd.getModule() && !sd.getModule().isFrontendModule())
            return;
        }
        
        visited[cast(void*)sd] = true;
        
        if (sd.alignment == 1)
        buf.writestring("#pragma pack(push, 1)\n");
        buf.writestring(sd.isUnionDeclaration() ? "union " : "struct ");
        buf.writestring(sd.ident.toChars());
        if (sd.members)
        {
            buf.writestring("\n{\n");
            auto save = adparent;
            adparent = sd;
            foreach (m; *sd.members)
            {
                m.accept(this);
            }
            adparent = save;
            // Generate default ctor
            buf.printf("    %s(", sd.ident.toChars());
            buf.printf(") {");
            size_t varCount;
            foreach (m; *sd.members)
            {
                if (auto vd = m.isVarDeclaration())
                {
                    if (!memberField(vd))
                        continue;
                    varCount++;
                    if (!vd._init && !vd.type.isTypeBasic())
                        continue;
                    buf.printf(" this->%s = ", vd.ident.toChars());
                    if (vd._init)
                        AST.initializerToExpression(vd._init).accept(this);
                    else if (vd.type.isTypeBasic())
                        vd.type.defaultInitLiteral(Loc.initial).accept(this);
                    buf.printf(";");
                }
            }
            buf.printf(" }\n");
            
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
            
            buf.writestring("};\n\n");
            
            if (sd.alignment == 1)
                buf.writestring("#pragma pack(pop)\n");
            
            auto savex = buf;
            buf = checkbuf;
            buf.writestring("    assert(sizeof(");
            buf.writestring(sd.ident.toChars());
            buf.printf(") == %d);\n", sd.size(Loc.initial));
            buf = savex;
        }
        else
            buf.writestring(";\n\n");
    }
    
    private void includeSymbol(AST.Dsymbol ds)
    {
        // printf("Forward declaring %s %d\n", ds.toChars(), level);
        if (cast(void*)ds !in visited)
        {
            OutBuffer decl;
            auto save = buf;
            buf = &decl;
            ds.accept(this);
            buf = save;
            donebuf.writestring(decl.peekString());
        }
    }
    
    override void visit(AST.ClassDeclaration cd)
    {
        if (cast(void*)cd in visited)
        return;
        version(BUILD_COMPILER)
        {
            if (cd.getModule() && !cd.getModule().isFrontendModule())
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
        if (cd.members)
        {
            buf.writestring("\n{\npublic:\n");
            auto save = adparent;
            adparent = cd;
            foreach (m; *cd.members)
            {
                m.accept(this);
            }
            adparent = save;
            version(BUILD_COMPILER)
            {
                // Generate special static inline function.
                if (cd.isIdentifierClass())
                {
                    buf.writestring("    static inline Identifier *idPool(const char *s) { return idPool(s, strlen(s)); }\n");
                }
            }
            
            buf.writestring("};\n\n");
        }
        else
            buf.writestring(";\n\n");
    }
    
    override void visit(AST.EnumDeclaration ed)
    {
        if (cast(void*)ed in visited)
        return;
        version(BUILD_COMPILER)
        {
            if (ed.getModule() && !ed.getModule().isFrontendModule())
            return;
        }
        
        visited[cast(void*)ed] = true;
        if (ed.isSpecial())
            return;
        buf.writestring("enum");
        const(char)* ident = null;
        if (ed.ident)
            ident = ed.ident.toChars();
        if (ident)
        {
            buf.writeByte(' ');
            buf.writestring(ident);
        }
        if (ed.members)
        {
            buf.writestring("\n{\n");
            foreach (i, m; *ed.members)
            {
                if (i)
                buf.writestring(",\n");
                buf.writestring("    ");
                if (ident)
                {
                    foreach (c; ident[0 .. strlen(ident)])
                    buf.writeByte(toupper(c));
                }
                m.accept(this);
            }
            buf.writestring("\n};\n\n");
        }
        else
            buf.writestring(";\n\n");
    }
    
    override void visit(AST.EnumMember em)
    {
        buf.writestring(em.ident.toChars());
        buf.writestring(" = ");
        if (cast(AST.StringExp)em.value)
        {
            em.value.error("cannot convert string enum");
            return ;
        }
        auto ie = cast(AST.IntegerExp)em.value;
        visitInteger(ie.toInteger(), em.ed.memtype);
    }
    
    private void typeToBuffer(AST.Type t, Identifier ident)
    {
        this.ident = ident;
        t.accept(this);
        if (this.ident)
        {
            buf.writeByte(' ');
            buf.writestring(ident.toChars());
        }
        this.ident = null;
        if (t.ty == AST.Tsarray)
        {
            auto tsa = cast(AST.TypeSArray)t;
            buf.writeByte('[');
            tsa.dim.accept(this);
            buf.writeByte(']');
        }
    }
    
    override void visit(AST.Type t)
    {
        printf("Invalid type: %s\n", t.toPrettyChars());
        assert(0);
    }
    
    override void visit(AST.TypeIdentifier t)
    {
        buf.writestring(t.ident.toChars());
    }
    
    override void visit(AST.TypeBasic t)
    {
        if (!cdparent && t.isConst())
        buf.writestring("const ");
        switch (t.ty)
        {
            case AST.Tbool, AST.Tvoid:
            case AST.Tchar, AST.Twchar, AST.Tdchar:
            case AST.Tint8, AST.Tuns8:
            case AST.Tint16, AST.Tuns16:
            case AST.Tint32, AST.Tuns32:
            case AST.Tint64, AST.Tuns64:
            case AST.Tfloat32, AST.Tfloat64, AST.Tfloat80:
                buf.writestring("_d_");
                buf.writestring(t.dstring);
                break;
            default:
                //t.print();
                assert(0);
        }
    }
    
    override void visit(AST.TypePointer t)
    {
        if (t.next.ty == AST.Tstruct &&
        !strcmp((cast(AST.TypeStruct)t.next).sym.ident.toChars(), "__va_list_tag"))
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
        t.next.accept(this);
    }
    
    override void visit(AST.TypeAArray t)
    {
        AST.Type.tvoidptr.accept(this);
    }
    
    override void visit(AST.TypeFunction tf)
    {
        tf.next.accept(this);
        buf.writeByte('(');
        buf.writeByte('*');
        if (ident)
            buf.writestring(ident.toChars());
        ident = null;
        buf.writeByte(')');
        buf.writeByte('(');
        foreach (i; 0 .. AST.Parameter.dim(tf.parameters))
        {
            if (i)
                buf.writestring(", ");
            auto fparam = AST.Parameter.getNth(tf.parameters, i);
            fparam.accept(this);
        }
        if (tf.varargs)
        {
            if (tf.parameters.dim && tf.varargs == 1)
            buf.writestring(", ");
            buf.writestring("...");
        }
        buf.writeByte(')');
    }
    
    private void enumToBuffer(AST.EnumDeclaration ed)
    {
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
            else
            {
                //ed.print();
                assert(0);
            }
        }
        else
            buf.writestring(ed.toChars());
    }
    
    override void visit(AST.TypeEnum t)
    {
        if (cast(void*)t.sym !in forwarded)
        {
            forwarded[cast(void*)t.sym] = true;
            auto save = buf;
            buf = fwdbuf;
            t.sym.accept(this);
            buf = save;
        }
        if (!cdparent && t.isConst())
        buf.writestring("const ");
        enumToBuffer(t.sym);
    }
    
    override void visit(AST.TypeStruct t)
    {
        if (cast(void*)t.sym !in forwarded &&
        !t.sym.parent.isTemplateInstance())
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
        if (!cdparent && t.isConst())
        buf.writestring("const ");
        buf.writestring("DArray<");
        t.next.accept(this);
        buf.writestring(">");
    }
    
    private void visitTi(AST.TemplateInstance ti)
    {
        version(BUILD_COMPILER)
        {
            if (ti.tempdecl.ident == DMDType.AssocArray)
            {
                buf.writestring("AA*");
                return;
            }
            if (ti.tempdecl.ident == DMDType.Array)
                buf.writestring("Array");
            else
            {
                foreach (o; *ti.tiargs)
                {
                    if (!AST.isType(o))
                    return;
                }
                buf.writestring(ti.tempdecl.ident.toChars());
            }
        }
        else
        {
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
        if (cast(void*)td in visited)
            return;
        visited[cast(void*)td] = true;
        version(BUILD_COMPILER)
        {
            if (td.getModule() && !td.getModule().isFrontendModule())
                return;
        }
        
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
        buf.writestring(";\n\n");
        tdparent = save;
    }
    
    override void visit(AST.TypeClass t)
    {
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
    
    private void funcToBuffer(AST.TypeFunction tf, Identifier ident)
    {
        assert(tf.next);
        tf.next.accept(this);
        if (tf.isref)
        buf.writeByte('&');
        buf.writeByte(' ');
        buf.writestring(ident.toChars());
        
        buf.writeByte('(');
        foreach (i; 0 .. AST.Parameter.dim(tf.parameters))
        {
            if (i)
            buf.writestring(", ");
            auto fparam = AST.Parameter.getNth(tf.parameters, i);
            fparam.accept(this);
        }
        if (tf.varargs)
        {
            if (tf.parameters.dim && tf.varargs == 1)
            buf.writestring(", ");
            buf.writestring("...");
        }
        buf.writeByte(')');
    }
    
    override void visit(AST.Parameter p)
    {
        ident = p.ident;
        p.type.accept(this);
        assert(!(p.storageClass & ~(AST.STC.ref_)));
        if (p.storageClass & AST.STC.ref_)
            buf.writeByte('&');
        buf.writeByte(' ');
        if (ident)
            buf.writestring(ident.toChars());
        ident = null;
        if (p.defaultArg)
        {
            // buf.writestring("/*");
            buf.writestring(" = ");
            p.defaultArg.accept(this);
            // buf.writestring("*/");
        }
    }
    
    override void visit(AST.Expression e)
    {
        //e.print();
        assert(0);
    }
    
    override void visit(AST.NullExp e)
    {
        buf.writestring("_d_null");
    }
    
    override void visit(AST.ArrayLiteralExp e)
    {
        buf.writestring("arrayliteral");
    }
    
    override void visit(AST.StringExp e)
    {
        assert(e.sz == 1 || e.sz == 2);
        if (e.sz == 2)
        buf.writeByte('L');
        buf.writeByte('"');
        size_t o = buf.offset;
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
                    if (c <= 0x7F && isprint(c))
                    buf.writeByte(c);
                    else
                    buf.printf("\\x%02x", c);
                }
                else if (c <= 0xFFFF)
                    buf.printf("\\x%02x\\x%02x", c & 0xFF, c >> 8);
                else
                    buf.printf("\\x%02x\\x%02x\\x%02x\\x%02x", c & 0xFF, (c >> 8) & 0xFF, (c >> 16) & 0xFF, c >> 24);
                break;
            }
        }
        buf.writeByte('"');
    }
    
    override void visit(AST.RealExp e)
    {
        buf.writestring("0");
    }
    
    override void visit(AST.IntegerExp e)
    {
        visitInteger(e.toInteger, e.type);
    }
    
    private void visitInteger(dinteger_t v, AST.Type t)
    {
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
            case AST.Tchar:
                buf.printf("%uu", cast(ubyte)v);
                break;
            case AST.Tint16:
                buf.printf("%d", cast(short)v);
                break;
            case AST.Tuns16:
                buf.printf("%uu", cast(ushort)v);
                break;
            case AST.Tint32:
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
            default:
                //t.print();
                assert(0);
        }
    }
    
    override void visit(AST.StructLiteralExp sle)
    {
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
void genCppFiles(OutBuffer* buf, Modules *ms)
{
    import dmd.tokens;

    buf.writeByte('\n');
    buf.printf("// Automatically generated by dtoh\n");
    buf.writeByte('\n');
    buf.writestring("#include <assert.h>\n");
    buf.writestring("#include <stddef.h>\n");
    buf.writestring("#include <stdio.h>\n");
    buf.writestring("#include <string.h>\n");
    buf.writeByte('\n');
    buf.writestring("#define _d_void void\n");
    buf.writestring("#define _d_bool bool\n");
    buf.writestring("#define _d_byte signed char\n");
    buf.writestring("#define _d_ubyte unsigned char\n");
    buf.writestring("#define _d_short short\n");
    buf.writestring("#define _d_ushort unsigned short\n");
    buf.writestring("#define _d_int int\n");
    buf.writestring("#define _d_uint unsigned\n");
    if (global.params.isLP64)
    {
        buf.writestring("#define _d_long long\n");
        buf.writestring("#define _d_ulong unsigned long\n");
    }
    else
    {
        buf.writestring("#define _d_long long long\n");
        buf.writestring("#define _d_ulong unsigned long long\n");
    }
    buf.writestring("#define _d_float float\n");
    buf.writestring("#define _d_double double\n");
    buf.writestring("#define _d_real long double\n");
    buf.writestring("#define _d_char char\n");
    buf.writestring("#define _d_wchar wchar_t\n");
    buf.writestring("#define _d_dchar unsigned\n");
    buf.writestring("\n");
    buf.writestring("#define _d_null NULL\n");
    buf.writestring("\n");
    version(BUILD_COMPILER)
        buf.writestring("struct AA;\n");
    buf.writestring("\n");
    
    OutBuffer check;
    check.writestring(`
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
        
        OutBuffer done;
        OutBuffer decl;
        scope v = new ToCppBuffer!ASTCodegen(&check, buf, &done, &decl);
        foreach (m; *ms)
        {
            buf.printf("// Parsing module %s\n", m.toPrettyChars());
            m.accept(v);
        }
        buf.write(&done);
        buf.write(&decl);
        
        check.writestring(`
    }
    #endif
    `);
    
    debug buf.write(&check);
}
