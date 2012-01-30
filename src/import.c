
// Compiler implementation of the D programming language
// Copyright (c) 1999-2009 by Digital Mars
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
    : Dsymbol()
{
    assert(id);
    this->loc = loc;
    this->packages = packages;
    this->id = id;
    this->aliasId = aliasId;
    this->isstatic = isstatic;
    pkg = NULL;
    mod = NULL;
}

void Import::addAlias(Identifier *name, Identifier *alias)
{
    if (isstatic)
        error("cannot have an import bind list");

    names.push(name);
    aliases.push(alias);
}

const char *Import::kind()
{
    return isstatic ? (char *)"static import" : (char *)"import";
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

    Dsymbol *s = dst->lookup(id);
    if (s)
    {
#if TARGET_NET
        mod = (Module *)s;
#else
        if (s->isModule())
            mod = (Module *)s;
        else
            error("package and module have the same name");
#endif
    }

    if (!mod)
    {
        // Load module
        mod = Module::load(loc, packages, id);
        dst->insert(id, mod);           // id may be different from mod->ident,
                                        // if so then insert alias
        if (!mod->importedFrom)
            mod->importedFrom = sc ? sc->module->importedFrom : Module::rootModule;
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

       /* Default to private importing
        */
       enum PROT prot = sc->protection;
       if (!sc->explicitProtection)
           prot = PROTprivate;
       sc->scopesym->importScope(this, prot);
    }
}

void Import::semantic(Scope *sc)
{
    //printf("Import::semantic('%s')\n", toChars());

    // Load if not already done so
    if (!mod)
    {   load(sc);
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

        /* Default to private importing
         */
        enum PROT prot = sc->protection;
        if (!sc->explicitProtection)
            prot = PROTprivate;
        for (Scope *scd = sc; scd; scd = scd->enclosing)
        {
            if (scd->scopesym)
            {
                scd->scopesym->importScope(this, prot);
                break;
            }
        }

        mod->semantic();

        if (mod->needmoduleinfo)
        {   //printf("module4 %s because of %s\n", sc->module->toChars(), mod->toChars());
            sc->module->needmoduleinfo = 1;
        }

        if (aliasId)
        {
            AliasDeclaration *ad = new AliasDeclaration(loc, aliasId, mod);
            sc->insert(ad);
            ad->semantic(sc);
        }
    }

    if (global.params.moduleDeps != NULL)
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

Dsymbol *Import::search(Loc loc, Identifier *ident, int flags)
{
    //printf("%s.Import::search(ident = '%s', flags = x%x)\n", toChars(), ident->toChars(), flags);

    if (!pkg)
    {   load(NULL);
        mod->semantic();
    }

    if (names.dim) // selective import
    {
        for (size_t i = 0; i < names.dim; i++)
        {
            Identifier *name = (Identifier *)names[i];
            Identifier *alias = (Identifier *)aliases[i];

            if (!alias)
                alias = name;

            if (alias->equals(ident))
                return mod->search(loc, name, flags);
        }

        // What should happen when renamed and selective imports are mixed?
        // This makes the whole module available with the renamed id.
        if (aliasId && aliasId->equals(ident))
            return mod;
    }
    else // non-selective import
    {
        // For renamed imports, only the alias name is visible.
        if (aliasId)
        {
            if (aliasId->equals(ident))
                return mod;
            return 0;
        }

        // For non-static imports, prefer symbols in the module over the module name.
        if (!isstatic)
        {
            Dsymbol *s = mod->search(loc, ident, flags);
            if (s)
                return s;
        }

        // Make the start of the package name available.
        if (pkg->ident->equals(ident))
        {
            return pkg;
        }
    }
    return 0;
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
    buf->printf("%s;", id->toChars());
    buf->writenl();
}

char *Import::toChars()
{
    return id->toChars();
}
