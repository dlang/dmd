// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.dimport;

import core.stdc.string;
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
import ddmd.visitor;

extern (C++) final class Import : Dsymbol
{
public:
    /* static import aliasId = pkg1.pkg2.id : alias1 = name1, alias2 = name2;
     */
    Identifiers* packages; // array of Identifier's representing packages
    Identifier id; // module Identifier
    Identifier aliasId;
    int isstatic; // !=0 if static import
    PROTKIND protection;
    // Pairs of alias=name to bind into current namespace
    Identifiers names;
    Identifiers aliases;
    Module mod;
    Package pkg; // leftmost package/module
    AliasDeclarations aliasdecls; // corresponding AliasDeclarations for alias=name pairs

    /********************************* Import ****************************/
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
        this.pkg = null;
        this.mod = null;
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

    override const(char)* kind()
    {
        return isstatic ? cast(char*)"static import" : cast(char*)"import";
    }

    override Prot prot()
    {
        return Prot(protection);
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
        DsymbolTable dst = Package.resolve(packages, null, &pkg);
        version (none)
        {
            if (pkg && pkg.isModule())
            {
                .error(loc, "can only import from a module, not from a member of module %s. Did you mean `import %s : %s`?", pkg.toChars(), pkg.toPrettyChars(), id.toChars());
                mod = pkg.isModule(); // Error recovery - treat as import of that module
                return;
            }
        }
        Dsymbol s = dst.lookup(id);
        if (s)
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
                else if (pkg)
                {
                    .error(loc, "can only import from a module, not from package %s.%s", pkg.toPrettyChars(), id.toChars());
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
                dst.insert(id, mod); // id may be different from mod->ident,
                // if so then insert alias
            }
        }
        if (mod && !mod.importedFrom)
            mod.importedFrom = sc ? sc._module.importedFrom : Module.rootModule;
        if (!pkg)
            pkg = mod;
        //printf("-Import::load('%s'), pkg = %p\n", toChars(), pkg);
    }

    override void importAll(Scope* sc)
    {
        if (!mod)
        {
            load(sc);
            if (mod) // if successfully loaded module
            {
                if (mod.md && mod.md.isdeprecated)
                {
                    Expression msg = mod.md.msg;
                    if (StringExp se = msg ? msg.toStringExp() : null)
                        mod.deprecation(loc, "is deprecated - %s", se.string);
                    else
                        mod.deprecation(loc, "is deprecated");
                }
                mod.importAll(null);
                if (!isstatic && !aliasId && !names.dim)
                {
                    if (sc.explicitProtection)
                        protection = sc.protection.kind;
                    sc.scopesym.importScope(mod, Prot(protection));
                }
            }
        }
    }

    override void semantic(Scope* sc)
    {
        //printf("Import::semantic('%s')\n", toPrettyChars());
        if (_scope)
        {
            sc = _scope;
            _scope = null;
        }
        // Load if not already done so
        if (!mod)
        {
            load(sc);
            if (mod)
                mod.importAll(null);
        }
        if (mod)
        {
            // Modules need a list of each imported module
            //printf("%s imports %s\n", sc->module->toChars(), mod->toChars());
            sc._module.aimports.push(mod);
            if (!isstatic && !aliasId && !names.dim)
            {
                if (sc.explicitProtection)
                    protection = sc.protection.kind;
                for (Scope* scd = sc; scd; scd = scd.enclosing)
                {
                    if (scd.scopesym)
                    {
                        scd.scopesym.importScope(mod, Prot(protection));
                        break;
                    }
                }
            }
            mod.semantic();
            if (mod.needmoduleinfo)
            {
                //printf("module4 %s because of %s\n", sc->module->toChars(), mod->toChars());
                sc._module.needmoduleinfo = 1;
            }
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
            for (size_t i = 0; i < aliasdecls.dim; i++)
            {
                AliasDeclaration ad = aliasdecls[i];
                //printf("\tImport alias semantic('%s')\n", ad->toChars());
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
            // use protection instead of sc->protection because it couldn't be
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
        //printf("-Import::semantic('%s'), pkg = %p\n", toChars(), pkg);
    }

    override void semantic2(Scope* sc)
    {
        //printf("Import::semantic2('%s')\n", toChars());
        if (mod)
        {
            mod.semantic2();
            if (mod.needmoduleinfo)
            {
                //printf("module5 %s because of %s\n", sc->module->toChars(), mod->toChars());
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

    /*****************************
     * Add import to sd's symbol table.
     */
    override void addMember(Scope* sc, ScopeDsymbol sd)
    {
        if (names.dim == 0)
            return Dsymbol.addMember(sc, sd);
        if (aliasId)
            Dsymbol.addMember(sc, sd);
        /* Instead of adding the import to sd's symbol table,
         * add each of the alias=name pairs
         */
        for (size_t i = 0; i < names.dim; i++)
        {
            Identifier name = names[i];
            Identifier _alias = aliases[i];
            if (!_alias)
                _alias = name;
            auto tname = new TypeIdentifier(loc, name);
            auto ad = new AliasDeclaration(loc, _alias, tname);
            ad._import = this;
            ad.addMember(sc, sd);
            aliasdecls.push(ad);
        }
    }

    override Dsymbol search(Loc loc, Identifier ident, int flags = IgnoreNone)
    {
        //printf("%s.Import::search(ident = '%s', flags = x%x)\n", toChars(), ident->toChars(), flags);
        if (!pkg)
        {
            load(null);
            mod.importAll(null);
            mod.semantic();
        }
        // Forward it to the package/module
        return pkg.search(loc, ident, flags);
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

    override Import isImport()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
