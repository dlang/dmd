
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/import.c
 */

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "dsymbol.h"
#include "import.h"
#include "identifier.h"
#include "module.h"
#include "scope.h"
#include "hdrgen.h"
#include "mtype.h"
#include "declaration.h"
#include "id.h"
#include "attrib.h"

/********************************* Import ****************************/

Import::Import(Loc loc, Identifiers *packages, Identifier *id, Identifier *aliasId,
        int isstatic)
    : Dsymbol(NULL)
{
    assert(id);
#if 0
    printf("Import::Import(");
    if (packages && packages->dim)
    {
        for (size_t i = 0; i < packages->dim; i++)
        {
            Identifier *id = (*packages)[i];
            printf("%s.", id->toChars());
        }
    }
    printf("%s)\n", id->toChars());
#endif
    this->loc = loc;
    this->packages = packages;
    this->id = id;
    this->aliasId = aliasId;
    this->isstatic = isstatic;
    this->protection = PROTprivate; // default to private
    this->pkg = NULL;
    this->mod = NULL;

    // Set symbol name (bracketed)
    if (aliasId)
    {
        // import [cstdio] = std.stdio;
        this->ident = aliasId;
    }
    else if (packages && packages->dim)
    {
        // import [std].stdio;
        this->ident = (*packages)[0];
    }
    else
    {
        // import [foo];
        this->ident = id;
    }
}

void Import::addAlias(Identifier *name, Identifier *alias)
{
    if (isstatic)
        error("cannot have an import bind list");

    if (!aliasId)
        this->ident = NULL;     // make it an anonymous import

    names.push(name);
    aliases.push(alias);
}

const char *Import::kind()
{
    return isstatic ? (char *)"static import" : (char *)"import";
}

PROT Import::prot()
{
    return protection;
}

Dsymbol *Import::syntaxCopy(Dsymbol *s)
{
    assert(!s);

    Import *si = new Import(loc, packages, id, aliasId, isstatic);

    for (size_t i = 0; i < names.dim; i++)
    {
        si->addAlias(names[i], aliases[i]);
    }

    return si;
}

void Import::load(Scope *sc)
{
    //printf("Import::load('%s') %p\n", toPrettyChars(), this);

    // See if existing module
    DsymbolTable *dst = Package::resolve(packages, NULL, &pkg);
#if 0
    if (pkg && pkg->isModule())
    {
        ::error(loc, "can only import from a module, not from a member of module %s. Did you mean `import %s : %s`?",
             pkg->toChars(), pkg->toPrettyChars(), id->toChars());
        mod = pkg->isModule(); // Error recovery - treat as import of that module
        return;
    }
#endif
    Dsymbol *s = dst->lookup(id);
    if (s)
    {
        if (s->isModule())
            mod = (Module *)s;
        else
        {
            if (s->isAliasDeclaration())
            {
                ::error(loc, "%s %s conflicts with %s", s->kind(), s->toPrettyChars(), id->toChars());
            }
            else if (Package *p = s->isPackage())
            {
                if (p->isPkgMod == PKGunknown)
                {
                    mod = Module::load(loc, packages, id);
                    if (!mod)
                        p->isPkgMod = PKGpackage;
                    else
                        assert(p->isPkgMod == PKGmodule);
                }
                else
                {
                    mod = p->isPackageMod();
                }
                if (!mod)
                {
                    ::error(loc, "can only import from a module, not from package %s.%s",
                        p->toPrettyChars(), id->toChars());
                }
            }
            else if (pkg)
            {
                ::error(loc, "can only import from a module, not from package %s.%s",
                    pkg->toPrettyChars(), id->toChars());
            }
            else
            {
                ::error(loc, "can only import from a module, not from package %s",
                    id->toChars());
            }
        }
    }

    if (!mod)
    {
        // Load module
        mod = Module::load(loc, packages, id);
        if (mod)
        {
            dst->insert(id, mod);           // id may be different from mod->ident,
                                            // if so then insert alias
        }
    }
    if (mod && !mod->importedFrom)
        mod->importedFrom = sc ? sc->module->importedFrom : Module::rootModule;
    if (!pkg)
        pkg = mod;

    //printf("-Import::load('%s'), pkg = %p\n", toChars(), pkg);
}

void Import::importAll(Scope *sc)
{
    if (!mod)
    {
        load(sc);
        if (mod)                // if successfully loaded module
        {
            mod->importAll(NULL);

            if (!isstatic && !aliasId && !names.dim)
            {
                if (sc->explicitProtection)
                    protection = sc->protection;
                sc->scopesym->importScope(mod, protection);
            }
        }
    }
}

void Import::semantic(Scope *sc)
{
    //printf("Import::semantic('%s')\n", toPrettyChars());

    if (scope)
    {
        sc = scope;
        scope = NULL;
    }

    // Load if not already done so
    if (!mod)
    {
        load(sc);
        if (mod)
            mod->importAll(NULL);
    }

    if (mod)
    {
        // Modules need a list of each imported module
        //printf("%s imports %s\n", sc->module->toChars(), mod->toChars());
        sc->module->aimports.push(mod);

        if (!isstatic && !aliasId && !names.dim)
        {
            if (sc->explicitProtection)
                protection = sc->protection;
            for (Scope *scd = sc; scd; scd = scd->enclosing)
            {
                if (scd->scopesym)
                {
                    scd->scopesym->importScope(mod, protection);
                    break;
                }
            }
        }

        mod->semantic();

        if (mod->needmoduleinfo)
        {
            //printf("module4 %s because of %s\n", sc->module->toChars(), mod->toChars());
            sc->module->needmoduleinfo = 1;
        }

        sc = sc->push(mod);
        /* BUG: Protection checks can't be enabled yet. The issue is
         * that Dsymbol::search errors before overload resolution.
         */
#if 0
        sc->protection = protection;
#else
        sc->protection = PROTpublic;
#endif
        for (size_t i = 0; i < aliasdecls.dim; i++)
        {
            AliasDeclaration *ad = aliasdecls[i];
            //printf("\tImport alias semantic('%s')\n", ad->toChars());
            if (mod->search(loc, names[i]))
            {
                ad->semantic(sc);
            }
            else
            {
                Dsymbol *s = mod->search_correct(names[i]);
                if (s)
                    mod->error(loc, "import '%s' not found, did you mean '%s %s'?", names[i]->toChars(), s->kind(), s->toChars());
                else
                    mod->error(loc, "import '%s' not found", names[i]->toChars());
                ad->type = Type::terror;
            }
        }
        sc = sc->pop();
    }

    // object self-imports itself, so skip that (Bugzilla 7547)
    // don't list pseudo modules __entrypoint.d, __main.d (Bugzilla 11117, 11164)
    if (global.params.moduleDeps != NULL &&
        !(id == Id::object && sc->module->ident == Id::object) &&
        sc->module->ident != Id::entrypoint &&
        strcmp(sc->module->ident->string, "__main") != 0)
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

        OutBuffer *ob = global.params.moduleDeps;
        Module* imod = sc->instantiatingModule();
        if (!global.params.moduleDepsFile)
            ob->writestring("depsImport ");
        ob->writestring(imod->toPrettyChars());
        ob->writestring(" (");
        escapePath(ob,  imod->srcfile->toChars());
        ob->writestring(") : ");

        // use protection instead of sc->protection because it couldn't be
        // resolved yet, see the comment above
        protectionToBuffer(ob, protection);
        ob->writeByte(' ');
        if (isstatic)
            StorageClassDeclaration::stcToCBuffer(ob, STCstatic);
        ob->writestring(": ");

        if (packages)
        {
            for (size_t i = 0; i < packages->dim; i++)
            {
                Identifier *pid = (*packages)[i];
                ob->printf("%s.", pid->toChars());
            }
        }

        ob->writestring(id->toChars());
        ob->writestring(" (");
        if (mod)
            escapePath(ob, mod->srcfile->toChars());
        else
            ob->writestring("???");
        ob->writeByte(')');

        for (size_t i = 0; i < names.dim; i++)
        {
            if (i == 0)
                ob->writeByte(':');
            else
                ob->writeByte(',');

            Identifier *name = names[i];
            Identifier *alias = aliases[i];

            if (!alias)
            {
                ob->printf("%s", name->toChars());
                alias = name;
            }
            else
                ob->printf("%s=%s", alias->toChars(), name->toChars());
        }

        if (aliasId)
                ob->printf(" -> %s", aliasId->toChars());

        ob->writenl();
    }

    //printf("-Import::semantic('%s'), pkg = %p\n", toChars(), pkg);
}

void Import::semantic2(Scope *sc)
{
    //printf("Import::semantic2('%s')\n", toChars());
    if (mod)
    {
        mod->semantic2();
        if (mod->needmoduleinfo)
        {
            //printf("module5 %s because of %s\n", sc->module->toChars(), mod->toChars());
            sc->module->needmoduleinfo = 1;
        }
    }
}

Dsymbol *Import::toAlias()
{
    if (aliasId)
        return mod;
    return this;
}

/*****************************
 * Add import to sd's symbol table.
 */

int Import::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    int result = 0;

    if (names.dim == 0)
        return Dsymbol::addMember(sc, sd, memnum);

    if (aliasId)
        result = Dsymbol::addMember(sc, sd, memnum);

    /* Instead of adding the import to sd's symbol table,
     * add each of the alias=name pairs
     */
    for (size_t i = 0; i < names.dim; i++)
    {
        Identifier *name = names[i];
        Identifier *alias = aliases[i];

        if (!alias)
            alias = name;

        TypeIdentifier *tname = new TypeIdentifier(loc, name);
        AliasDeclaration *ad = new AliasDeclaration(loc, alias, tname);
        ad->import = this;
        result |= ad->addMember(sc, sd, memnum);

        aliasdecls.push(ad);
    }

    return result;
}

Dsymbol *Import::search(Loc loc, Identifier *ident, int flags)
{
    //printf("%s.Import::search(ident = '%s', flags = x%x)\n", toChars(), ident->toChars(), flags);

    if (!pkg)
    {
        load(NULL);
        mod->importAll(NULL);
        mod->semantic();
    }

    // Forward it to the package/module
    return pkg->search(loc, ident, flags);
}

bool Import::overloadInsert(Dsymbol *s)
{
    /* Allow multiple imports with the same package base, but disallow
     * alias collisions (Bugzilla 5412).
     */
    assert(ident && ident == s->ident);
    Import *imp;
    if (!aliasId && (imp = s->isImport()) != NULL && !imp->aliasId)
        return true;
    else
        return false;
}

void Import::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (hgs->hdrgen && id == Id::object)
        return;         // object is imported by default

    if (isstatic)
        buf->writestring("static ");
    buf->writestring("import ");
    if (aliasId)
    {
        buf->printf("%s = ", aliasId->toChars());
    }
    if (packages && packages->dim)
    {
        for (size_t i = 0; i < packages->dim; i++)
        {   Identifier *pid = (*packages)[i];

            buf->printf("%s.", pid->toChars());
        }
    }
    buf->printf("%s", id->toChars());
    if (names.dim)
    {
        buf->writestring(" : ");
        for (size_t i = 0; i < names.dim; i++)
        {
            Identifier *name = names[i];
            Identifier *alias = aliases[i];

            if (alias)
                buf->printf("%s = %s", alias->toChars(), name->toChars());
            else
                buf->printf("%s", name->toChars());

            if (i < names.dim - 1)
                buf->writestring(", ");
        }
    }
    buf->printf(";");
    buf->writenl();
}

