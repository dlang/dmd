// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.dimport;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdio;

import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.expression;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.mars;
import ddmd.mtype;
import ddmd.root.outbuffer;
import ddmd.root.rmem;
import ddmd.visitor;

extern (C++) Package findPackage(DsymbolTable dst, Identifiers* packages, size_t dim)
{
    if (!packages || !dim)
        return null;
    assert(dim <= packages.dim);

    Package pkg;
    for (size_t i = 0; i < dim; i++)
    {
        assert(dst);
        Identifier pid = (*packages)[i];
        Dsymbol p = dst.lookup(pid);
        if (!p)
            return null;
        pkg = p.isPackage();
        assert(pkg);
        dst = pkg.symtab;
    }
    return pkg;
}

/***********************************************************
 */
extern (C++) final class Import : Dsymbol
{
public:
    /* static import aliasId = pkg1.pkg2.id : alias1 = name1, alias2 = name2;
     */
    Identifiers* packages;  // array of Identifier's representing packages
    Identifier id;          // module Identifier
    Identifier aliasId;
    int isstatic;           // !=0 if static import
    PROTKIND protection;

    // Pairs of alias=name to bind into current namespace
    Identifiers names;
    Identifiers aliases;

    Module mod;
    Import overnext;

    // corresponding AliasDeclarations for alias=name pairs
    AliasDeclarations aliasdecls;

    extern (D) this(Loc loc, Identifiers* packages, Identifier id, Identifier aliasId, int isstatic)
    {
        super(null);
        assert(id);
        version (none)
        {
            printf("Import::Import(");
            if (packages && packages.dim)
            {
                for (size_t i = 0; i < packages.dim; i++)
                {
                    Identifier id = (*packages)[i];
                    printf("%s.", id.toChars());
                }
            }
            printf("%s)\n", id.toChars());
        }
        this.loc = loc;
        this.packages = packages;
        this.id = id;
        this.aliasId = aliasId;
        this.isstatic = isstatic;
        this.protection = PROTprivate; // default to private

        // Set symbol name (bracketed)
        if (aliasId)
        {
            // import [cstdio] = std.stdio;
            this.ident = aliasId;
        }
        else if (packages && packages.dim)
        {
            // import [std].stdio;
            this.ident = (*packages)[0];
        }
        else
        {
            // import [foo];
            this.ident = id;
        }
    }

    void addAlias(Identifier name, Identifier _alias)
    {
        if (isstatic)
            error("cannot have an import bind list");
        if (!aliasId)
            this.ident = null; // make it an anonymous import
        names.push(name);
        aliases.push(_alias);
    }

    override const(char)* kind() const
    {
        return isstatic ? cast(char*)"static import" : cast(char*)"import";
    }

    override Prot prot()
    {
        return Prot(protection);
    }

    final Import copy()
    {
        auto imp = cast(Import)mem.xmalloc(__traits(classInstanceSize, Import));
        memcpy(cast(void*)imp, cast(void*)this, __traits(classInstanceSize, Import));
        return imp;
    }

    // copy only syntax trees
    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        auto si = new Import(loc, packages, id, aliasId, isstatic);
        for (size_t i = 0; i < names.dim; i++)
        {
            si.addAlias(names[i], aliases[i]);
        }
        return si;
    }

    void load(Scope* sc)
    {
        //printf("Import::load('%s') %p\n", toPrettyChars(), this);
        // See if existing module
        auto dst = Package.resolve(null, packages, null, null);
        if (auto s = dst.lookup(id))
        {
            if (s.isModule())
                mod = cast(Module)s;
            else
            {
                if (s.isAliasDeclaration())
                {
                    .error(loc, "%s %s conflicts with %s", s.kind(), s.toPrettyChars(), id.toChars());
                }
                else if (Package p = s.isPackage())
                {
                    if (p.isPkgMod == PKGunknown)
                    {
                        mod = Module.load(loc, packages, id);
                        if (!mod)
                            p.isPkgMod = PKGpackage;
                        else
                        {
                            // mod is a package.d, or a normal module which conflicts with the package name.
                            assert(mod.isPackageFile == (p.isPkgMod == PKGmodule));
                        }
                    }
                    else
                    {
                        mod = p.isPackageMod();
                    }
                    if (!mod)
                    {
                        .error(loc, "can only import from a module, not from package %s.%s", p.toPrettyChars(), id.toChars());
                    }
                }
                else
                {
                    .error(loc, "can only import from a module, not from package %s", id.toChars());
                }
            }
        }
        if (!mod)
        {
            // Load module
            mod = Module.load(loc, packages, id);
            if (mod)
            {
                dst.insert(id, mod); // id may be different from mod.ident,
                // if so then insert alias
            }
        }
        if (mod && !mod.importedFrom)
            mod.importedFrom = sc ? sc._module.importedFrom : Module.rootModule;

        //printf("-Import::load('%s'), pkg = %p\n", toChars(), pkg);
    }

    /*****************************
     * Add import to sds's symbol table.
     */
    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        if (!mod)
        {
            load(sc);
            // filling mod will break some existing assumptions
            if (!mod)
                return;     // fails to load module
        }

        if (mod.md && mod.md.isdeprecated)
        {
            auto msg = mod.md.msg;
            if (auto se = msg ? msg.toStringExp() : null)
                mod.deprecation(loc, "is deprecated - %s", se.string);
            else
                mod.deprecation(loc, "is deprecated");
        }

        //printf("Import::addMember[%s]('%s'), prot = %d\n", loc.toChars(), toChars(), sc.explicitProtection ? sc.protection : protection);
        if (sc.explicitProtection)
            protection = sc.protection.kind;

        // FQN is visible if this is not an unrenamed selective import.
        if (this.ident)
        {
            addPackage(sc, sds);
        }

        /* Instead of adding the import to sds's symbol table,
         * add each of the alias=name pairs
         */
        for (size_t i = 0; i < names.dim; i++)
        {
            auto name = names[i];
            auto aliasName = aliases[i];
            if (!aliasName)
                aliasName = name;
            auto tname = new TypeIdentifier(loc, name);
            auto ad = new AliasDeclaration(loc, aliasName, tname);
            ad._import = this;
            ad.addMember(sc, sds);

            aliasdecls.push(ad);
        }
    }

    /********************************************
     * Add fully qualified package name in scope
     */
    final void addPackage(Scope* sc, ScopeDsymbol sds)
    {
        assert(mod);

        Scope* scx = null;  // Innermost enclosing scope of sds
        for (Scope* scy = sc; scy; scy = scy.enclosing)
        {
            if (!scy.scopesym)
                continue;
            if (!scx && scy.scopesym !is sds)
            {
                if (sds is null)
                    sds = scy.scopesym;
                else
                    scx = scy;
            }
            else if (scx && scy.scopesym == sds)
                scx = null;
        }
        assert(sds);
        assert(scx && scx.scopesym && scx.scopesym !is sds);

        if (!sds.symtab)
            sds.symtab = new DsymbolTable();

        // `this.ident` is null if this is an unrenamed selective import.
        auto leftmostId = this.ident;
        if (!leftmostId)
        {
            if (aliasId)
                leftmostId = aliasId;
            else if (packages && packages.dim)
                leftmostId = (*packages)[0];
            else
                leftmostId = id;
        }

        // Validate whether the leftmost package name is already exists in symtab?
        assert(leftmostId);
        if (auto ss = sds.symtab.lookup(leftmostId))
        {
            if (aliasId || !packages || packages.dim == 0)
            {
                auto imp = ss.isImport();
                if (imp && imp.mod is mod)
                {
                    // OK
                }
                else if (sc.func && !sds.isAggregateDeclaration())
                {
                    /* For backward compatibility:
                     *  void foo() {
                     *    int std;
                     *    import std.stdio;  // 'std' package is implicitly hidden
                     *    std = 10;          // refer variable 'std'
                     *    writeln("hello");  // refer imported symbol
                     *  }
                     */
                    return;
                }
                else
                {
                    ScopeDsymbol.multiplyDefined(loc, ss, mod);
                    return;
                }
            }
            else
            {
                if (ss.isPackage())
                {
                    // OK
                }
                else if (sc.func && !sds.isAggregateDeclaration())
                {
                    // For backward compatibility.
                    return;
                }
                else
                {
                    ScopeDsymbol.multiplyDefined(loc, ss, this);
                    return;
                }
            }
        }

        /* Insert the fully qualified name of imported module
         * in local package tree.
         */
        DsymbolTable dst;       // rightmost DsymbolTable
        Identifier id;          // rightmost import identifier:
        Dsymbol ss = this;      // local package tree stores Import instead of Module
        if (aliasId)
        {
            dst = sds.symtab;
            id = aliasId;               // import [A] = std.stdio;
        }
        else
        {
            Package ppack = null;
            Package pparent = null;     // rightmost package
            dst = Package.resolve(sds.symtab, packages, &ppack, &pparent);
            id = this.id;               // import std.[stdio];

            if (mod.isPackageFile)
            {
                Package p = new Package(id);
                p.parent = pparent;     // may be NULL
                p.isPkgMod = PKGmodule;
                p.aliassym = this;
                p.symtab = new DsymbolTable();
                ss = p;

                if (!pparent)
                    ppack = p;
            }
        }
        if (dst.insert(id, ss))
        {
            /* Make links from inner packages to the corresponding outer packages.
             *
             *  import std.algorithm;
             *  // In here, symtab have a Package 'std' (a),
             *  // and it contains a module 'algorithm'.
             *
             *  class C {
             *    import std.range;
             *    // In here, symtab contains a Package 'std' (b),
             *    // and it contains a module 'range'.
             *
             *    void test() {
             *      std.algorithm.map!(a=>a*2)(...);
             *      // 'algorithm' doesn't exist in (b).symtab, so (b) should have
             *      // a link to (a).
             *    }
             *  }
             *
             * After following, (b).enclosingPkg() will return (a).
             */
            if (aliasId || !packages || !packages.dim)
                return;
            assert(packages);
            dst = sds.symtab;

            for (size_t i = 0; i < packages.dim; i++)
            {
                assert(dst);
                auto s = dst.lookup((*packages)[i]);
                assert(s);
                auto inn_pkg = s.isPackage();
                assert(inn_pkg);
                //printf("\t[%d] inn_pkg = %s\n", i, inn_pkg.toChars());

                Package out_pkg = null;
                for (; scx; scx = scx.enclosing)
                {
                    if (!scx.scopesym || !scx.scopesym.symtab)
                        continue;

                    out_pkg = findPackage(scx.scopesym.symtab, packages, i + 1);
                    if (!out_pkg)
                        continue;

                    assert(inn_pkg !is out_pkg);
                    //printf("\t[%d] out_pkg = %s\n", i, out_pkg.toChars());

                    /* Importing package.d hides outer scope imports, so
                     * further searching is not necessary.
                     *
                     *  import std.algorithm;
                     *  class C1 {
                     *    import std;
                     *    // Here is 'scx.scopesym'
                     *    // out_pkg == 'std' (isPackageMod() != NULL)
                     *
                     *    class C2 {
                     *      import std.range;
                     *      // Here is 'this'
                     *      // inn_pkg == 'std' (isPackageMod() == NULL)
                     *
                     *      void test() {
                     *        auto r1 = std.range.iota(10);   // OK
                     *        auto r2 = std.algorithm.map!(a=>a*2)([1,2,3]);   // NG
                     *        // std.range is accessible, but
                     *        // std.algorithm isn't. Because identifier
                     *        // 'algorithm' is found in std/package.d
                     *      }
                     *    }
                     *  }
                     */
                    if (out_pkg.isPackageMod())
                        return;

                    //printf("link out(%s:%p) to (%s:%p)\n", out_pkg.toPrettyChars(), out_pkg, inn_pkg.toPrettyChars(), inn_pkg);
                    inn_pkg.aliassym = out_pkg;
                    break;
                }

                /* There's no corresponding package in enclosing scope, so
                 * further searching is not necessary.
                 */
                if (!out_pkg)
                    break;

                dst = inn_pkg.symtab;
            }
        }
        else
        {
            auto prev = dst.lookup(id);
            assert(prev);
            if (auto imp = prev.isImport())
            {
                if (imp.mod is mod)
                {
                    if (imp is this)
                        return;

                    /* OK:
                     *  import A = std.algorithm : find;
                     *  import A = std.algorithm : filter;
                     */
                    auto pimp = &imp.overnext;
                    while (*pimp)
                    {
                        if (*pimp is this)
                            return;
                        pimp = &(*pimp).overnext;
                    }
                    (*pimp) = this;
                }
                else
                {
                    /* NG:
                     *  import A = std.algorithm;
                     *  import A = std.stdio;
                     */
                    error("import '%s' conflicts with import '%s'", toChars(), prev.toChars());
                }
            }
            else
            {
                auto pkg = prev.isPackage();
                assert(pkg);
                //printf("[%s] pkg = %d, pkg.aliassym = %p, mod = %p, mod.isPackageFile = %d\n",
                //        loc.toChars(), pkg.isPkgMod, pkg.aliassym, mod, mod.isPackageFile);
                if (pkg.isPkgMod == PKGunknown && mod.isPackageFile)
                {
                    /* OK:
                     *  import std.datetime;
                     *  import std;  // std/package.d
                     */
                    pkg.isPkgMod = PKGmodule;
                    pkg.aliassym = this;
                }
                else if (pkg.isPackageMod() == mod)
                {
                    /* OK:
                     *  import std;  // std/package.d
                     *  import std: writeln;
                     */
                    auto imp = pkg.aliassym.isImport();
                    assert(imp);
                    auto pimp = &imp.overnext;
                    while (*pimp)
                    {
                        if (*pimp is this)
                            return;
                        pimp = &(*pimp).overnext;
                    }
                    (*pimp) = this;
                }
                else
                {
                    /* NG:
                     *  import std.stdio;
                     *  import std = std.algorithm;
                     */
                    error("import '%s' conflicts with package '%s'", toChars(), prev.toChars());
                }
            }
        }
    }

    override void setScope(Scope* sc)
    {
        Dsymbol.setScope(sc);
        if (aliasdecls.dim)
        {
            if (!mod)
                importAll(sc);

            sc = sc.push(mod);
            /* BUG: Protection checks can't be enabled yet. The issue is
             * that Dsymbol::search errors before overload resolution.
             */
            version (none)
            {
                sc.protection = protection;
            }
            else
            {
                sc.protection = Prot(PROTpublic);
            }
            foreach (ad; aliasdecls)
            {
                ad.setScope(sc);
            }
            sc = sc.pop();
        }
    }

    override void importAll(Scope* sc)
    {
        if (!mod)
            return;

        mod.importAll(null);

        ScopeDsymbol sds = null;
        for (Scope* scx = sc; scx; scx = scx.enclosing)
        {
            sds = scx.scopesym;
            if (sds)
                break;
        }
        assert(sds);

        if (!isstatic && !aliasId && !names.dim)
        {
            sds.importScope(this, Prot(protection));
        }

        /* Excepting unnamed selective imports, the full package name of public imports
         * would be pulled to other *derived* scopes.
         */
        if (!names.dim || aliasId)
        {
            Dsymbols* publicImports = null;
            if (auto m = sds.isModule())
            {
                if (protection == PROTpublic)
                {
                    if (!m.publicImports)
                        m.publicImports = new Dsymbols();
                    publicImports = m.publicImports;
                }
            }
            else if (auto cd = sds.isClassDeclaration())
            {
                if (protection == PROTpublic || protection == PROTprotected)
                {
                    if (!cd.publicImports)
                        cd.publicImports = new Dsymbols();
                    publicImports = cd.publicImports;
                }
            }
            if (publicImports)
            {
                for (size_t i = 0; ; i++)
                {
                    if (i == publicImports.dim)
                    {
                        publicImports.push(this);
                        break;
                    }
                    if ((*publicImports)[i] == this)
                        break;
                }
            }
        }
    }

    override void semantic(Scope* sc)
    {
        //printf("Import::semantic[%s]('%s') prot = %d\n", loc.toChars(), toPrettyChars(), protection);
        if (_scope)
        {
            sc = _scope;
            _scope = null;
        }

        // Load if not already done so
        importAll(sc);

        if (mod)
        {
            // Modules need a list of each imported module
            //printf("%s imports %s\n", sc.module.toChars(), mod.toChars());
            sc._module.aimports.push(mod);

            mod.semantic();

            if (mod.needmoduleinfo)
            {
                //printf("module4 %s because of %s\n", sc.module.toChars(), mod.toChars());
                sc._module.needmoduleinfo = 1;
            }

            // Pull public imports from mod into the importing scope.
            if (!names.dim && mod.publicImports)
            {
                foreach (s; *mod.publicImports)
                {
                    auto imp = s.isImport();
                    if (!imp)
                        continue;

                    //printf("\t[%s] imp = %s at %s\n", loc.toChars(), imp.toChars(), imp.loc.toChars());
                    imp = imp.copy();
                    imp.loc = loc;
                    imp.protection = protection;
                    imp.overnext = null;
                    imp.addPackage(sc, null);
                }
            }

            sc = sc.push(mod);
            /* BUG: Protection checks can't be enabled yet. The issue is
             * that Dsymbol::search errors before overload resolution.
             */
            version (none)
            {
                sc.protection = Preot(protection);
            }
            else
            {
                sc.protection = Prot(PROTpublic);
            }
            for (size_t i = 0; i < aliasdecls.dim; i++)
            {
                AliasDeclaration ad = aliasdecls[i];
                //printf("\tImport %s alias %s = %s, scope = %p\n", toPrettyChars(), aliases[i].toChars(), names[i].toChars(), ad._scope);
                if (mod.search(loc, names[i]))
                {
                    ad.semantic(sc);
                }
                else
                {
                    Dsymbol s = mod.search_correct(names[i]);
                    if (s)
                        mod.error(loc, "import '%s' not found, did you mean %s '%s'?", names[i].toChars(), s.kind(), s.toChars());
                    else
                        mod.error(loc, "import '%s' not found", names[i].toChars());
                    ad.type = Type.terror;
                }
            }
            sc = sc.pop();
        }
        // object self-imports itself, so skip that (Bugzilla 7547)
        // don't list pseudo modules __entrypoint.d, __main.d (Bugzilla 11117, 11164)
        if (global.params.moduleDeps !is null && !(id == Id.object && sc._module.ident == Id.object) && sc._module.ident != Id.entrypoint && strcmp(sc._module.ident.string, "__main") != 0)
        {
            /* The grammar of the file is:
             *      ImportDeclaration
             *          ::= BasicImportDeclaration [ " : " ImportBindList ] [ " -> "
             *      ModuleAliasIdentifier ] "\n"
             *
             *      BasicImportDeclaration
             *          ::= ModuleFullyQualifiedName " (" FilePath ") : " Protection|"string"
             *              " [ " static" ] : " ModuleFullyQualifiedName " (" FilePath ")"
             *
             *      FilePath
             *          - any string with '(', ')' and '\' escaped with the '\' character
             */
            OutBuffer* ob = global.params.moduleDeps;
            Module imod = sc.instantiatingModule();
            if (!global.params.moduleDepsFile)
                ob.writestring("depsImport ");
            ob.writestring(imod.toPrettyChars());
            ob.writestring(" (");
            escapePath(ob, imod.srcfile.toChars());
            ob.writestring(") : ");
            // use protection instead of sc.protection because it couldn't be
            // resolved yet, see the comment above
            protectionToBuffer(ob, Prot(protection));
            ob.writeByte(' ');
            if (isstatic)
            {
                stcToBuffer(ob, STCstatic);
                ob.writeByte(' ');
            }
            ob.writestring(": ");
            if (packages)
            {
                for (size_t i = 0; i < packages.dim; i++)
                {
                    Identifier pid = (*packages)[i];
                    ob.printf("%s.", pid.toChars());
                }
            }
            ob.writestring(id.toChars());
            ob.writestring(" (");
            if (mod)
                escapePath(ob, mod.srcfile.toChars());
            else
                ob.writestring("???");
            ob.writeByte(')');
            for (size_t i = 0; i < names.dim; i++)
            {
                if (i == 0)
                    ob.writeByte(':');
                else
                    ob.writeByte(',');
                Identifier name = names[i];
                Identifier _alias = aliases[i];
                if (!_alias)
                {
                    ob.printf("%s", name.toChars());
                    _alias = name;
                }
                else
                    ob.printf("%s=%s", _alias.toChars(), name.toChars());
            }
            if (aliasId)
                ob.printf(" -> %s", aliasId.toChars());
            ob.writenl();
        }
        //printf("-Import::semantic('%s')\n", toChars());
    }

    override void semantic2(Scope* sc)
    {
        //printf("Import::semantic2('%s')\n", toChars());
        if (mod)
        {
            mod.semantic2();
            if (mod.needmoduleinfo)
            {
                //printf("module5 %s because of %s\n", sc.module.toChars(), mod.toChars());
                sc._module.needmoduleinfo = 1;
            }
        }
    }

    override Dsymbol toAlias()
    {
        if (aliasId)
            return mod;
        return this;
    }

    override Dsymbol search(Loc loc, Identifier ident, int flags = IgnoreNone)
    {
        //printf("%p [%s].Import::search(ident = '%s', flags = x%x)\n", this, loc.toChars(), ident.toChars(), flags);
        //printf("%p\tfrom [%s] mod = %s\n", this, this.loc.toChars(), mod ? mod.toChars() : null);

        if (mod && !mod._scope)
        {
            mod.importAll(null);
            mod.semantic();
        }

        Dsymbol s = null;

        if (names.dim)
        {
            for (size_t i = 0; i < names.dim; i++)
            {
                auto name = names[i];
                auto aliasName = aliases[i];
                if ((aliasName ? aliasName : name) is ident)
                {
                    // Forward it to the module
                    s = mod.search(loc, name, flags | IgnoreImportedFQN | IgnorePrivateSymbols);
                    break;
                }
            }
        }
        else
        {
            // Forward it to the module
            s = mod.search(loc, ident, flags | IgnoreImportedFQN | IgnorePrivateSymbols);
        }
        if (!s && overnext && !(flags & IgnoreOverloadImports))
        {
            s = overnext.search(loc, ident, flags);
        }

        return s;
    }

    override bool overloadInsert(Dsymbol s)
    {
        /* Allow multiple imports with the same package base, but disallow
         * alias collisions (Bugzilla 5412).
         */
        assert(ident && ident == s.ident);
        Import imp;
        if (!aliasId && (imp = s.isImport()) !is null && !imp.aliasId)
            return true;
        else
            return false;
    }

    override inout(Import) isImport() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
