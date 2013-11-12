// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// This implements the JSON capability.

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "rmem.h"

#include "dsymbol.h"
#include "template.h"
#include "aggregate.h"
#include "declaration.h"
#include "enum.h"
#include "module.h"
#include "json.h"
#include "mtype.h"
#include "attrib.h"
#include "cond.h"
#include "init.h"
#include "import.h"
#include "id.h"

struct JsonOut
{
    OutBuffer *buf;
    int indentLevel;
    const char *filename;

    JsonOut(OutBuffer *buf) {this->buf = buf; indentLevel = 0; filename = NULL;}

    void indent();
    void removeComma();
    void comma();
    void stringStart();
    void stringEnd();
    void stringPart(const char* part);

    void value(const char* s);
    void value(int value);
    void valueBool(bool value);

    void item(const char*);
    void item(int);
    void itemBool(bool);


    void arrayStart();
    void arrayEnd();
    void objectStart();
    void objectEnd();

    void propertyStart(const char* name);

    void property(const char *name, const char* s);
    void property(const char *name, int value);
    void propertyBool(const char *name, bool value);
    void propertyStorageClass(const char *name, StorageClass stc);
    void property(const char *name, Loc* loc);
    void property(const char *name, Type* type);
    void property(const char *name, const char *deconame, Type* type);
    void property(const char *name, Parameters* parameters);
    void property(const char *name, TRUST trust);
    void property(const char *name, PURE purity);
    void property(const char *name, LINK linkage);
};


void json_generate(OutBuffer *buf, Modules *modules)
{
    JsonOut json(buf);

    json.arrayStart();
    for (size_t i = 0; i < modules->dim; i++)
    {   Module *m = (*modules)[i];
        if (global.params.verbose)
            fprintf(global.stdmsg, "json gen %s\n", m->toChars());
        m->toJson(&json);
    }
    json.arrayEnd();
    json.removeComma();
}




void JsonOut::indent()
{
    if (buf->offset >= 1 &&
        buf->data[buf->offset - 1] == '\n')
        for (int i = 0; i < indentLevel; i++)
            buf->writeByte(' ');
}

void JsonOut::removeComma()
{
    if (buf->offset >= 2 &&
        buf->data[buf->offset - 2] == ',' &&
        (buf->data[buf->offset - 1] == '\n' || buf->data[buf->offset - 1] == ' '))
        buf->offset -= 2;
}

void JsonOut::comma()
{
    if (indentLevel > 0)
        buf->writestring(",\n");
}

void JsonOut::stringStart()
{
    buf->writeByte('\"');
}

void JsonOut::stringEnd()
{
    buf->writeByte('\"');
}

void JsonOut::stringPart(const char *s)
{
    for (; *s; s++)
    {
        utf8_t c = (utf8_t) *s;
        switch (c)
        {
            case '\n':
                buf->writestring("\\n");
                break;

            case '\r':
                buf->writestring("\\r");
                break;

            case '\t':
                buf->writestring("\\t");
                break;

            case '\"':
                buf->writestring("\\\"");
                break;

            case '\\':
                buf->writestring("\\\\");
                break;

            case '\b':
                buf->writestring("\\b");
                break;

            case '\f':
                buf->writestring("\\f");
                break;

            default:
                if (c < 0x20)
                    buf->printf("\\u%04x", c);
                else
                    // Note that UTF-8 chars pass through here just fine
                    buf->writeByte(c);
                break;
        }
    }
}


// Json value functions

/*********************************
 * Encode string into buf, and wrap it in double quotes.
 */
void JsonOut::value(const char *s)
{
    stringStart();
    stringPart(s);
    stringEnd();
}

void JsonOut::value(int value)
{
    buf->printf("%d", value);
}

void JsonOut::valueBool(bool value)
{
    buf->writestring(value? "true" : "false");
}

/*********************************
 * Item is an intented value and a comma, for use in arrays
 */
void JsonOut::item(const char *s)
{
    indent();
    value(s);
    comma();
}

void JsonOut::item(int i)
{
    indent();
    value(i);
    comma();
}

void JsonOut::itemBool(bool b)
{
    indent();
    valueBool(b);
    comma();
}


// Json array functions

void JsonOut::arrayStart()
{
    indent();
    buf->writestring("[\n");
    indentLevel++;
}

void JsonOut::arrayEnd()
{
    indentLevel--;
    removeComma();
    if (buf->offset >= 2 &&
        buf->data[buf->offset - 2] == '[' &&
        buf->data[buf->offset - 1] == '\n')
        buf->offset -= 1;
    else if (!(buf->offset >= 1 &&
        buf->data[buf->offset - 1] == '['))
    {
        buf->writestring("\n");
        indent();
    }
    buf->writestring("]");
    comma();
}


// Json object functions

void JsonOut::objectStart()
{
    indent();
    buf->writestring("{\n");
    indentLevel++;
}

void JsonOut::objectEnd()
{
    indentLevel--;
    removeComma();
    if (buf->offset >= 2 &&
        buf->data[buf->offset - 2] == '{' &&
        buf->data[buf->offset - 1] == '\n')
        buf->offset -= 1;
    else
    {
        buf->writestring("\n");
        indent();
    }
    buf->writestring("}");
    comma();
}



// Json object property functions

void JsonOut::propertyStart(const char *name)
{
    indent();
    value(name);
    buf->writestring(" : ");
}

void JsonOut::property(const char *name, const char *s)
{
    if (s == NULL) return;

    propertyStart(name);
    value(s);
    comma();
}

void JsonOut::property(const char *name, int i)
{
    propertyStart(name);
    value(i);
    comma();
}

void JsonOut::propertyBool(const char *name, bool b)
{
    propertyStart(name);
    valueBool(b);
    comma();
}


void JsonOut::property(const char *name, TRUST trust)
{
    switch (trust)
    {
        case TRUSTdefault:
            // Should not be printed
            //property(name, "default");
            break;
        case TRUSTsystem:
            property(name, "system");
            break;
        case TRUSTtrusted:
            property(name, "trusted");
            break;
        case TRUSTsafe:
            property(name, "safe");
            break;
        default:
            assert(false);
    }
}

void JsonOut::property(const char *name, PURE purity)
{
    switch (purity)
    {
        case PUREimpure:
            // Should not be printed
            //property(name, "impure");
            break;
        case PUREweak:
            property(name, "weak");
            break;
        case PUREconst:
            property(name, "const");
            break;
        case PUREstrong:
            property(name, "strong");
            break;
        case PUREfwdref:
            property(name, "fwdref");
            break;
        default:
            assert(false);
    }
}

void JsonOut::property(const char *name, LINK linkage)
{
    switch (linkage)
    {
        case LINKdefault:
            // Should not be printed
            //property(name, "default");
            break;
        case LINKd:
            // Should not be printed
            //property(name, "d");
            break;
        case LINKc:
            property(name, "c");
            break;
        case LINKcpp:
            property(name, "cpp");
            break;
        case LINKwindows:
            property(name, "windows");
            break;
        case LINKpascal:
            property(name, "pascal");
            break;
        default:
            assert(false);
    }
}

void JsonOut::propertyStorageClass(const char *name, StorageClass stc)
{
    stc &= STCStorageClass;
    if (stc)
    {
        propertyStart(name);
        arrayStart();

        while (stc)
        {   char tmp[20];
            const char *p = StorageClassDeclaration::stcToChars(tmp, stc);
            assert(p);
            assert(strlen(p) < sizeof(tmp) / sizeof(tmp[0]));
            if (p[0] == '@')
            {
                indent();
                stringStart();
                buf->writestring(p);
                stringEnd();
                comma();
            }
            else
                item(p);
        }

        arrayEnd();
    }
}

void JsonOut::property(const char *name, Loc *loc)
{
    if (loc)
    {
        const char *filename = loc->filename;
        if (filename)
        {
            if (!this->filename || strcmp(filename, this->filename))
            {   this->filename = filename;
                property("file", filename);
            }
        }

        if (loc->linnum)
            property(name, loc->linnum);
    }
}

void JsonOut::property(const char *name, Type *type)
{
    if (type)
    {
        property(name, type->toChars());
    }
}

void JsonOut::property(const char *name, const char *deconame, Type *type)
{
    if (type)
    {
        if (type->deco)
            property(deconame, type->deco);
        else
            property(name, type->toChars());
    }
}

void JsonOut::property(const char *name, Parameters *parameters)
{
    if (parameters == NULL || parameters->dim == 0)
        return;

    propertyStart(name);
    arrayStart();

    if (parameters)
        for (size_t i = 0; i < parameters->dim; i++)
        {   Parameter *p = (*parameters)[i];
            objectStart();

            if (p->ident)
                property("name", p->ident->toChars());

            property("type", "deco", p->type);

            propertyStorageClass("storageClass", p->storageClass);

            if (p->defaultArg)
                property("default", p->defaultArg->toChars());


            objectEnd();
        }

    arrayEnd();
}

/* ========================================================================== */

void Type::toJson(JsonOut *json)
{
}

void TypeSArray::toJson(JsonOut *json)
{
    json->property("elementType", next);
    json->property("dim", dim->toChars());
}

void TypeDArray::toJson(JsonOut *json)
{
    json->property("elementType", next);
}

void TypeAArray::toJson(JsonOut *json)
{
    json->property("elementType", next);
    json->property("index", index);
}

void TypePointer::toJson(JsonOut *json)
{
    json->property("targetType", next);
}

void TypeReference::toJson(JsonOut *json)
{
    json->property("targetType", next);
}

void TypeFunction::toJson(JsonOut *json)
{
    if (purity || isnothrow || isproperty || isref)
    {
        json->propertyStart("attributes");
        json->arrayStart();
        if (purity) json->item("pure");
        if (isnothrow) json->item("nothrow");
        if (isproperty) json->item("@property");
        if (isref) json->item("ref");
        json->arrayEnd();
    }

    json->property("trust", trust);
    json->property("purity", purity);
    json->property("linkage", linkage);

    json->property("returnType", next);
    json->property("parameters", parameters);
}

void TypeDelegate::toJson(JsonOut *json)
{
    next->toJson(json); // next is TypeFunction
}

void TypeQualified::toJson(JsonOut *json) // ident.ident.ident.etc
{
    json->propertyStart("idents");
    json->arrayStart();

    for (size_t i = 0; i < idents.dim; i++)
    {   RootObject *ident = idents[i];
        json->item(ident->toChars());
    }

    json->arrayEnd();
}

void TypeIdentifier::toJson(JsonOut *json)
{
    TypeQualified::toJson(json);
    json->property("rawIdentifier", ident->toChars());
    json->property("identifier", ident->toHChars2());
}

void TypeInstance::toJson(JsonOut *json)
{
    TypeQualified::toJson(json);
    json->property("tempinst", tempinst->toChars());
}

void TypeTypeof::toJson(JsonOut *json)
{
    TypeQualified::toJson(json);
    json->property("exp", exp->toChars());
    json->property("type", exp->type);
}

void TypeReturn::toJson(JsonOut *json)
{
    TypeQualified::toJson(json);
}

void TypeStruct::toJson(JsonOut *json)
{
    json->propertyStorageClass("storageClass", sym->storage_class);
}

void TypeEnum::toJson(JsonOut *json)
{
    sym->jsonProperties(json);
}

void TypeTypedef::toJson(JsonOut *json)
{
    sym->jsonProperties(json);
}

void TypeClass::toJson(JsonOut *json)
{
    json->propertyStorageClass("storageClass", sym->storage_class);
}

void TypeTuple::toJson(JsonOut *json)
{
    json->property("arguments", arguments);
}

void TypeSlice::toJson(JsonOut *json)
{
    json->property("lower", lwr->toChars());
    json->property("upper", upr->toChars());
}

void TypeNull::toJson(JsonOut *json) { }

void TypeVector::toJson(JsonOut *json)
{
    json->property("basetype", basetype);
}


/* ========================================================================== */

void Dsymbol::toJson(JsonOut *json)
{
#if 0
    json->objectStart();
    jsonProperties(json);
    json->objectEnd();
#endif
}

void Dsymbol::jsonProperties(JsonOut *json)
{
    if (!isTemplateDeclaration()) // TemplateDeclaration::kind() acts weird sometimes
    {
        json->property("name", toChars());
        json->property("kind", kind());
    }

    if (prot() != PROTpublic)
        json->property("protection", Pprotectionnames[prot()]);

    json->property("comment", (const char *)comment);

    json->property("line", &loc);

#if 0
    if (!isModule())
    {
        Module *module = getModule();
        if (module)
        {
            json->propertyStart("module");
            json->objectStart();
            module->jsonProperties(json);
            json->objectEnd();
        }

        Module *accessModule = getAccessModule();
        if (accessModule && accessModule != module)
        {
            json->propertyStart("accessModule");
            json->objectStart();
            accessModule->jsonProperties(json);
            json->objectEnd();
        }
    }
#endif
}

void Module::toJson(JsonOut *json)
{
    json->objectStart();

    if (md)
        json->property("name", md->toChars());

    json->property("kind", kind());

    json->filename = srcfile->toChars();
    json->property("file", json->filename);

    json->property("comment", (const char *)comment);

    json->propertyStart("members");
    json->arrayStart();
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        s->toJson(json);
    }
    json->arrayEnd();

    json->objectEnd();
}

void Module::jsonProperties(JsonOut *json)
{
#if 0
    Dsymbol::jsonProperties(json);

    if (md && md->packages)
    {
        json->propertyStart("package");
        json->arrayStart();
        for (size_t i = 0; i < md->packages->dim; i++)
        {   Identifier *pid = (*md->packages)[i];
            json->item(pid->toChars());
        }
        json->arrayEnd();
    }

    json->property("prettyName", toPrettyChars());
#endif
}

void Import::toJson(JsonOut *json)
{
    if (id == Id::object)
        return;

    json->objectStart();

    json->propertyStart("name");
    json->stringStart();
    if (packages && packages->dim)
    {
        for (size_t i = 0; i < packages->dim; i++)
        {   Identifier *pid = (*packages)[i];

            json->stringPart(pid->toChars());
            json->buf->writeByte('.');
        }
    }
    json->stringPart(id->toChars());
    json->stringEnd();
    json->comma();

    json->property("kind", kind());
    json->property("comment", (const char *)comment);
    json->property("line", &loc);
    if (prot() != PROTpublic)
        json->property("protection", Pprotectionnames[prot()]);
    if (aliasId)
        json->property("alias", aliasId->toChars());

    bool hasRenamed = false;
    bool hasSelective = false;
    for (size_t i = 0; i < aliases.dim; i++)
    {   // avoid empty "renamed" and "selective" sections
        if (hasRenamed && hasSelective)
            break;
        else if (aliases[i])
            hasRenamed = true;
        else
            hasSelective = true;
    }

    if (hasRenamed)
    {
        // import foo : alias1 = target1;
        json->propertyStart("renamed");
        json->objectStart();
        for (size_t i = 0; i < aliases.dim; i++)
        {
            Identifier *name = names[i];
            Identifier *alias = aliases[i];
            if (alias) json->property(alias->toChars(), name->toChars());
        }
        json->objectEnd();
    }

    if (hasSelective)
    {
        // import foo : target1;
        json->propertyStart("selective");
        json->arrayStart();
        for (size_t i = 0; i < names.dim; i++)
        {
            Identifier *name = names[i];
            if (!aliases[i]) json->item(name->toChars());
        }
        json->arrayEnd();
    }

    json->objectEnd();
}

void AttribDeclaration::toJson(JsonOut *json)
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            s->toJson(json);
        }
    }
}


void ConditionalDeclaration::toJson(JsonOut *json)
{
    if (condition->inc)
    {
        AttribDeclaration::toJson(json);
    }
}


void ClassInfoDeclaration::toJson(JsonOut *json)  { }
void TypeInfoDeclaration::toJson(JsonOut *json)   { }
void PostBlitDeclaration::toJson(JsonOut *json)   { }


void Declaration::toJson(JsonOut *json)
{
    json->objectStart();

    //json->property("unknown", "declaration");

    jsonProperties(json);

    json->objectEnd();
}

void Declaration::jsonProperties(JsonOut *json)
{
    Dsymbol::jsonProperties(json);

    json->propertyStorageClass("storageClass", storage_class);

    json->property("type", "deco", type);

    // Emit originalType if it differs from type
    if (type != originalType && originalType)
    {
        const char *ostr = originalType->toChars();
        if (type)
        {   const char *tstr = type->toChars();
            if (strcmp(tstr, ostr))
            {
                //printf("tstr = %s, ostr = %s\n", tstr, ostr);
                json->property("originalType", ostr);
            }
        }
        else
            json->property("originalType", ostr);
    }
}

void TemplateDeclaration::jsonProperties(JsonOut *json)
{
    Dsymbol::jsonProperties(json);

    if (onemember && onemember->isCtorDeclaration())
        json->property("name", "this");  // __ctor -> this
    else
        json->property("name", ident->toChars());  // Foo(T) -> Foo
}

void TypedefDeclaration::toJson(JsonOut *json)
{
    json->objectStart();

    jsonProperties(json);

    json->property("base", "baseDeco", basetype);

    json->objectEnd();
}

void AggregateDeclaration::toJson(JsonOut *json)
{
    json->objectStart();

    jsonProperties(json);

    ClassDeclaration *cd = isClassDeclaration();
    if (cd)
    {
        if (cd->baseClass && cd->baseClass->ident != Id::Object)
        {
            json->property("base", cd->baseClass->toChars());
        }
        if (cd->interfaces_dim)
        {
            json->propertyStart("interfaces");
            json->arrayStart();
            for (size_t i = 0; i < cd->interfaces_dim; i++)
            {   BaseClass *b = cd->interfaces[i];
                json->item(b->base->toChars());
            }
            json->arrayEnd();
        }
    }

    if (members)
    {
        json->propertyStart("members");
        json->arrayStart();
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            s->toJson(json);
        }
        json->arrayEnd();
    }

    json->objectEnd();
}

void FuncDeclaration::toJson(JsonOut *json)
{
    json->objectStart();

    jsonProperties(json);

    TypeFunction *tf = (TypeFunction *)type;
    if (tf && tf->ty == Tfunction)
        json->property("parameters", tf->parameters);

    json->property("endline", &endloc);

    if (foverrides.dim)
    {
        json->propertyStart("overrides");
        json->arrayStart();
        for (size_t i = 0; i < foverrides.dim; i++)
        {   FuncDeclaration *fd = foverrides[i];
            json->item(fd->toPrettyChars());
        }
        json->arrayEnd();
    }

    if (fdrequire)
    {
        json->propertyStart("in");
        fdrequire->toJson(json);
    }

    if (fdensure)
    {
        json->propertyStart("out");
        fdensure->toJson(json);
    }

    json->objectEnd();
}

void TemplateDeclaration::toJson(JsonOut *json)
{
    json->objectStart();

    // TemplateDeclaration::kind returns the kind of its Aggregate onemember, if it is one
    json->property("kind", "template");

    jsonProperties(json);

    json->propertyStart("parameters");
    json->arrayStart();
    for (size_t i = 0; i < parameters->dim; i++)
    {   TemplateParameter *s = (*parameters)[i];
        json->objectStart();

        json->property("name", s->ident->toChars());

        TemplateTypeParameter *type = s->isTemplateTypeParameter();
        if (type)
        {
            if (s->isTemplateThisParameter())
                json->property("kind", "this");
            else
                json->property("kind", "type");
            json->property("type", "deco", type->specType);

            json->property("default", "defaultDeco", type->defaultType);
        }

        TemplateValueParameter *value = s->isTemplateValueParameter();
        if (value)
        {
            json->property("kind", "value");

            json->property("type", "deco", value->valType);

            if (value->specValue)
                json->property("specValue", value->specValue->toChars());

            if (value->defaultValue)
                json->property("defaultValue", value->defaultValue->toChars());
        }

        TemplateAliasParameter *alias = s->isTemplateAliasParameter();
        if (alias)
        {
            json->property("kind", "alias");

            json->property("type", "deco", alias->specType);

            if (alias->specAlias)
                json->property("specAlias", alias->specAlias->toChars());

            if (alias->defaultAlias)
                json->property("defaultAlias", alias->defaultAlias->toChars());
        }

        TemplateTupleParameter *tuple = s->isTemplateTupleParameter();
        if (tuple)
        {
            json->property("kind", "tuple");
        }

        json->objectEnd();
    }
    json->arrayEnd();

    json->propertyStart("members");
    json->arrayStart();
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        s->toJson(json);
    }
    json->arrayEnd();

    json->objectEnd();
}

void EnumDeclaration::toJson(JsonOut *json)
{
    if (isAnonymous())
    {
        if (members)
        {
            for (size_t i = 0; i < members->dim; i++)
            {   Dsymbol *s = (*members)[i];
                s->toJson(json);
            }
        }
        return;
    }

    json->objectStart();

    jsonProperties(json);

    json->property("base", "baseDeco", memtype);

    if (members)
    {
        json->propertyStart("members");
        json->arrayStart();
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            s->toJson(json);
        }
        json->arrayEnd();
    }

    json->objectEnd();
}

void EnumMember::toJson(JsonOut *json)
{
    json->objectStart();

    jsonProperties(json);

    json->property("type", "deco", type);

    json->objectEnd();
}

void VarDeclaration::toJson(JsonOut *json)
{
    json->objectStart();

    jsonProperties(json);

    if (init)
        json->property("init", init->toChars());

    if (isField())
        json->property("offset", offset);

    if (alignment && alignment != STRUCTALIGN_DEFAULT)
        json->property("align", alignment);

    json->objectEnd();
}

void TemplateMixin::toJson(JsonOut *json)
{
    json->objectStart();

    jsonProperties(json);

    json->objectEnd();
}

