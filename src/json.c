
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// This implements the JSON capability.

#include <stdio.h>
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


struct JsonOut
{
    OutBuffer *buf;
    int indentLevel;

    JsonOut(OutBuffer *buf) {this->buf = buf; indentLevel = 0;}

    void indent();
    void removeComma();
    void comma();
    void stringStart();
    void stringEnd();
    void stringPart(const char*);

    void value(const char*);
    void value(int);
    void valueBool(bool);

    void item(const char*);
    void item(int);
    void itemBool(bool);


    void arrayStart();
    void arrayEnd();
    void objectStart();
    void objectEnd();

    void propertyStart(const char*);

    void property(const char*, const char*);
    void property(const char*, int);
    void propertyBool(const char*, bool);
    void propertyStorageClass(const char*, StorageClass);
    void property(const char*, Type*);
    void property(const char*, Parameters*);
    void property(const char*, enum TRUST);
    void property(const char*, enum PURE);
    void property(const char*, enum LINK);
};


void json_generate(Modules *modules)
{   OutBuffer buf;
    JsonOut json(&buf);

    json.arrayStart();
    for (size_t i = 0; i < modules->dim; i++)
    {   Module *m = (*modules)[i];
        if (global.params.verbose)
            printf("json gen %s\n", m->toChars());
        m->toJson(&json);
    }
    json.arrayEnd();

    // Write buf to file
    char *arg = global.params.xfilename;
    if (!arg || !*arg)
    {   // Generate lib file name from first obj name
        char *n = (*global.params.objfiles)[0];

        n = FileName::name(n);
        FileName *fn = FileName::forceExt(n, global.json_ext);
        arg = fn->toChars();
    }
    else if (arg[0] == '-' && arg[1] == 0)
    {   // Write to stdout; assume it succeeds
        int n = fwrite(buf.data, 1, buf.offset, stdout);
        assert(n == buf.offset);        // keep gcc happy about return values
        return;
    }
//    if (!FileName::absolute(arg))
//        arg = FileName::combine(dir, arg);
    FileName *jsonfilename = FileName::defaultExt(arg, global.json_ext);
    File *jsonfile = new File(jsonfilename);
    assert(jsonfile);
    jsonfile->setbuffer(buf.data, buf.offset);
    jsonfile->ref = 1;
    char *pt = FileName::path(jsonfile->toChars());
    if (*pt)
        FileName::ensurePathExists(pt);
    mem.free(pt);
    jsonfile->writev();
}




void JsonOut::indent()
{
    if (buf->offset >= 1 && 
        buf->data[buf->offset - 1] == '\n')
        for (int i = 0; i < indentLevel; i++)
            buf->writeByte('\t');
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
        unsigned char c = (unsigned char) *s;
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
    if (buf->offset >= 2 &&
        buf->data[buf->offset - 2] == '[' &&
        buf->data[buf->offset - 1] == '\n')
        buf->offset -= 1;
    else if (!(buf->offset >= 1 &&
        buf->data[buf->offset - 1] == '['))
    {
        removeComma();
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
    if (buf->offset >= 2 &&
        buf->data[buf->offset - 2] == '{' &&
        buf->data[buf->offset - 1] == '\n')
        buf->offset -= 1;
    else
    {
        removeComma();
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

void JsonOut::property(const char *name, const char *string)
{
    propertyStart(name);
    value(string);
    comma();
}

void JsonOut::property(const char *name, int num)
{
    propertyStart(name);
    value(num);
    comma();
}

void JsonOut::propertyBool(const char *name, bool b)
{
    propertyStart(name);
    valueBool(b);
    comma();
}


void JsonOut::property(const char *name, enum TRUST trust)
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

void JsonOut::property(const char *name, enum PURE purity)
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

void JsonOut::property(const char *name, enum LINK linkage)
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

// borrowed from attrib.c
struct SCstring
{
    StorageClass stc;
    enum TOK tok;
    Identifier *id;
};
// Defined in attrib.c
extern SCstring *SCtable;
extern size_t SCtable_len;

void JsonOut::propertyStorageClass(const char *name, StorageClass stc)
{
    propertyStart(name);
    arrayStart();

    for (int i = 0; i < SCtable_len; i++)
    {
        if (stc & SCtable[i].stc)
        {
            enum TOK tok = SCtable[i].tok;
#if DMDV2
            if (tok == TOKat)
            {
                indent();
                stringStart();
                buf->writeByte('@');
                buf->writestring(SCtable[i].id->toChars());
                stringEnd();
                comma();
            }
            else
#endif
                item(Token::toChars(tok));
        }
    }

    arrayEnd();
}

void JsonOut::property(const char *name, Type *type)
{
    if (type == NULL) return;

    propertyStart(name);
    objectStart();

    property("kind", type->kind());

    property("pretty", type->toChars());

    if (type->mod)
    {
        propertyStart("modifiers");
        stringStart();
        type->modToBuffer(buf);
        stringEnd();
        comma();
    }

    type->toJson(this);

    objectEnd();
}

void JsonOut::property(const char *name, Parameters *parameters)
{
    propertyStart(name);
    arrayStart();

    if (parameters)
        for (size_t i = 0; i < parameters->dim; i++)
        {   Parameter *p = parameters->tdata()[i];
            objectStart();

            if (p->ident)
                property("name", p->ident->toChars());

            property("type", p->type);

            propertyStorageClass("storageClass", p->storageClass);
            
            if (p->defaultArg)
                property("default", p->defaultArg->toChars());


            objectEnd();
        }

    arrayEnd();
}


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
    json->propertyBool("nothrow", isnothrow);
    json->propertyBool("property", isproperty);
    json->propertyBool("ref", isref);

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
    {   Identifier *ident = idents[i];
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

void Dsymbol::toJson(JsonOut *json)
{
    json->objectStart();

    //json->property("unknown", "dsymbol");

    json->property("kind", kind());

    jsonProperties(json);

    json->objectEnd();
}

const char* Pprotectionnames[] = {NULL, "none", "private", "package", "protected", "public", "export"};

void Dsymbol::jsonProperties(JsonOut *json)
{
    json->property("name", toChars());
    if (!isTemplateDeclaration()) // TemplateDeclaration::kind() acts weird sometimes
        json->property("kind", kind());

    if (prot())
        json->property("protection", Pprotectionnames[prot()]);

    if (comment)
        json->property("comment", (const char *)comment);

    if (loc.filename || loc.linnum)
    {
        json->propertyStart("loc");
        json->objectStart();

        if (loc.filename)
            json->property("file", loc.filename);

        if (loc.linnum)
            json->property("line", loc.linnum);

        json->objectEnd();
    }

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
}

void Module::toJson(JsonOut *json)
{
    json->objectStart();

    jsonProperties(json);

    json->property("file", srcfile->toChars());

    json->property("kind", kind());

    if (comment)
        json->property("comment", (const char *)comment);

    json->propertyStart("imports");
    json->arrayStart();

    for (size_t i = 0; i < aimports.dim; i++)
    {   Module *m = aimports[i];
        json->objectStart();

        json->property("name", m->toPrettyChars());

        json->property("kind", m->kind());

        json->property("file", m->srcfile->toChars());

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

void Module::jsonProperties(JsonOut *json)
{
    Dsymbol::jsonProperties(json);

    if (md && md->packages)
    {
        json->propertyStart("package");
        json->arrayStart();
        for (size_t i = 0; i < md->packages->dim; i++)
        {   Identifier *pid = md->packages->tdata()[i];
            json->item(pid->toChars());
        }
        json->arrayEnd();
    }

    json->property("prettyName", toPrettyChars());
}

void AttribDeclaration::toJson(JsonOut *json)
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            //printf("AttribDeclaration::toJson %s\n", s->toChars());
            s->toJson(json);
        }
        json->removeComma();
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
void ModuleInfoDeclaration::toJson(JsonOut *json) { }
void TypeInfoDeclaration::toJson(JsonOut *json)   { }
#if DMDV2
void PostBlitDeclaration::toJson(JsonOut *json)   { }
#endif


void Declaration::toJson(JsonOut *json)
{
    json->objectStart();

    //json->property("unknown", "declaration");

    jsonProperties(json);

    TypedefDeclaration *td = isTypedefDeclaration();
    if (td)
    {
        json->property("base", td->basetype);
    }

    json->objectEnd();
}

void Declaration::jsonProperties(JsonOut *json)
{
    Dsymbol::jsonProperties(json);

    json->propertyStorageClass("storageClass", storage_class);

    json->property("type", type);

    if (type != originalType)
        json->property("originalType", originalType);
}

void AggregateDeclaration::toJson(JsonOut *json)
{
    json->objectStart();

    jsonProperties(json);

    ClassDeclaration *cd = isClassDeclaration();
    if (cd)
    {
        if (cd->baseClass)
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
        json->removeComma();
        json->arrayEnd();
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
            json->property("kind", "type");

            if (type->specType)
                json->property("specType", type->specType->toChars());
            
            if (type->defaultType)
                json->property("defaultType", type->defaultType->toChars());
        }

        TemplateValueParameter *value = s->isTemplateValueParameter();
        if (value)
        {
            json->property("kind", "value");

            if (value->valType)
                json->property("valType", value->valType->toChars());
            
            if (value->specValue)
                json->property("specValue", value->specValue->toChars());
            
            if (value->defaultValue)
                json->property("defaultValue", value->defaultValue->toChars());
        }

        TemplateAliasParameter *alias = s->isTemplateAliasParameter();
        if (alias)
        {
            json->property("kind", "alias");

            if (alias->specType)
                json->property("specType", alias->specType->toChars());
            
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

#if DMDV2
        TemplateThisParameter *thisp = s->isTemplateThisParameter();
        if (thisp)
        {
            json->property("kind", "this");

            if (type->specType)
                json->property("specType", type->specType->toChars());
            
            if (type->defaultType)
                json->property("defaultType", type->defaultType->toChars());
        }
#endif

        json->objectEnd();
    }
    json->removeComma();
    json->arrayEnd();

    json->propertyStart("members");
    json->arrayStart();
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        s->toJson(json);
    }
    json->removeComma();
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

    json->property("type", type);

    if (memtype)
        json->property("base", memtype);

    if (members)
    {
        json->propertyStart("members");
        json->arrayStart();
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            s->toJson(json);
        }
        json->removeComma();
        json->arrayEnd();
    }
    json->removeComma();

    json->objectEnd();
}

void EnumMember::toJson(JsonOut *json)
{
    json->objectStart();

    jsonProperties(json);

    json->property("type", type);

    json->removeComma();
    json->objectEnd();
}


