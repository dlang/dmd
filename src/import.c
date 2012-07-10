
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
    this->loc = loc;
    this->packages = packages;
    this->id = id;
    this->aliasId = aliasId;
    this->isstatic = isstatic;
    this->protection = PROTprivate; // default to private
    this->pkg = NULL;
    this->mod = NULL;

    // Set symbol name (bracketed)
    // import [cstdio] = std.stdio;
    if (aliasId)
        this->ident = aliasId;
    // import [std].stdio;
    else if (packages && packages->dim)
        this->ident = (*packages)[0];
    // import [foo];
    else
        this->ident = id;
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

enum PROT Import::prot()
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
    //printf("Import::load('%s')\n", toChars());

    // See if existing module
    DsymbolTable *dst = Package::resolve(packages, NULL, &pkg);
#if TARGET_NET  //dot net needs modules and packages with same name
#else
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
#if TARGET_NET
        mod = (Module *)s;
#else
        if (s->isModule())
            mod = (Module *)s;
        else
        {
            if (pkg)
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
#endif
    }

    if (!mod)
    {
        // Load module
        mod = Module::load(loc, packages, id);
        if (mod)
        {
            dst->insert(id, mod);           // id may be different from mod->ident,
                                            // if so then insert alias
            if (!mod->importedFrom)
                mod->importedFrom = sc ? sc->module->importedFrom : Module::rootModule;
        }
    }
    if (!pkg)
        pkg = mod;

    //printf("-Import::load('%s'), pkg = %p\n", toChars(), pkg);
}

void escapePath(OutBuffer *buf, const char *fname)
{
    while (1)
    {
        switch (*fname)
        {
            case 0:
                return;
            case '(':
            case ')':
            case '\\':
                buf->writebyte('\\');
            default:
                buf->writebyte(*fname);
                break;
        }
        fname++;
    }
}

void Import::importAll(Scope *sc)
{
    if (!mod)
    {
       load(sc);
       mod->importAll(0);

       if (!isstatic && !aliasId && !names.dim)
       {
           if (sc->explicitProtection)
               protection = sc->protection;
           sc->scopesym->importScope(mod, protection);
       }
    }
}

void Import::semantic(Scope *sc)
{
    //printf("Import::semantic('%s')\n", toChars());

    // Load if not already done so
    if (!mod)
    {   load(sc);
        if (mod)
            mod->importAll(0);
    }

    if (mod)
    {
#if 0
        if (mod->loc.linnum != 0)
        {   /* If the line number is not 0, then this is not
             * a 'root' module, i.e. it was not specified on the command line.
             */
            mod->importedFrom = sc->module->importedFrom;
            assert(mod->importedFrom);
        }
#endif

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
        {   //printf("module4 %s because of %s\n", sc->module->toChars(), mod->toChars());
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
        {   Dsymbol *s = aliasdecls[i];

            //printf("\tImport alias semantic('%s')\n", s->toChars());
            if (mod->search(loc, names[i], 0))
                s->semantic(sc);
            else
            {
                s = mod->search_correct(names[i]);
                if (s)
                    mod->error(loc, "import '%s' not found, did you mean '%s %s'?", names[i]->toChars(), s->kind(), s->toChars());
                else
                    mod->error(loc, "import '%s' not found", names[i]->toChars());
            }
        }
        sc = sc->pop();
    }

    if (global.params.moduleDeps != NULL &&
        // object self-imports itself, so skip that (Bugzilla 7547)
        !(id == Id::object && sc->module->ident == Id::object))
    {
        /* The grammar of the file is:
         *      ImportDeclaration
         *          ::= BasicImportDeclaration [ " : " ImportBindList ] [ " -> "
         *      ModuleAliasIdentifier ] "\n"
         *
         *      BasicImportDeclaration
         *          ::= ModuleFullyQualifiedName " (" FilePath ") : " Protection
         *              " [ " static" ] : " ModuleFullyQualifiedName " (" FilePath ")"
         *
         *      FilePath
         *          - any string with '(', ')' and '\' escaped with the '\' character
         */

        OutBuffer *ob = global.params.moduleDeps;

        ob->writestring(sc->module->toPrettyChars());
        ob->writestring(" (");
        escapePath(ob, sc->module->srcfile->toChars());
        ob->writestring(") : ");

        ProtDeclaration::protectionToCBuffer(ob, sc->protection);
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
        ob->writebyte(')');

        for (size_t i = 0; i < names.dim; i++)
        {
            if (i == 0)
                ob->writebyte(':');
            else
                ob->writebyte(',');

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
    mod->semantic2();
    if (mod->needmoduleinfo)
    {   //printf("module5 %s because of %s\n", sc->module->toChars(), mod->toChars());
        sc->module->needmoduleinfo = 1;
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
        result |= ad->addMember(sc, sd, memnum);

        aliasdecls.push(ad);
    }

    return result;
}

Dsymbol *Import::search(Loc loc, Identifier *ident, int flags)
{
    //printf("%s.Import::search(ident = '%s', flags = x%x)\n", toChars(), ident->toChars(), flags);

    if (!pkg)
    {   load(NULL);
        mod->semantic();
    }

    // Forward it to the package/module
    return pkg->search(loc, ident, flags);
}

int Import::overloadInsert(Dsymbol *s)
{
    /* Allow multiple imports with the same package base, but disallow
     * alias collisions (Bugzilla 5412).
     */
    assert(ident && ident == s->ident);
    Import *imp;
    if (!aliasId && (imp = s->isImport()) != NULL && !imp->aliasId)
        return TRUE;
    else
        return FALSE;
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

