
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

    void properties(Module*);
    void properties(Dsymbol*);
    void properties(Declaration*);
    void properties(TypeSArray*);
    void properties(TypeDArray*);
    void properties(TypeAArray*);
    void properties(TypePointer*);
    void properties(TypeReference*);
    void properties(TypeFunction*);
    void properties(TypeDelegate*);
    void properties(TypeQualified*);
    void properties(TypeIdentifier*);
    void properties(TypeInstance*);
    void properties(TypeTypeof*);
    void properties(TypeReturn*);
    void properties(TypeStruct*);
    void properties(TypeEnum*);
    void properties(TypeTypedef*);
    void properties(TypeClass*);
    void properties(TypeTuple*);
    void properties(TypeSlice*);
    void properties(TypeNull*);
    void properties(TypeVector*);
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


// Json value functions

/*********************************
 * Encode string into buf, and wrap it in double quotes.
 */
void JsonOut::value(const char *s)
{
    buf->writeByte('\"');
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
    buf->writeByte('\"');
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


const char *TrustToChars(enum TRUST trust)
{
    switch (trust)
    {
        case TRUSTdefault:
            return "default";
        case TRUSTsystem:
            return "system";
        case TRUSTtrusted:
            return "trusted";
        case TRUSTsafe:
            return "safe";
        default:
            assert(false);
    }
}

const char *PurityToChars(enum PURE purity)
{
    switch (purity)
    {
        case PUREimpure:
            return "impure";
        case PUREweak:
            return "weak";
        case PUREconst:
            return "const";
        case PUREstrong:
            return "strong";
        case PUREfwdref:
            return "fwdref";
        default:
            assert(false);
    }
}

const char *LinkageToChars(enum LINK linkage)
{
    switch (linkage)
    {
        case LINKdefault:
            return "default";
        case LINKd:
            return "d";
        case LINKc:
            return "c";
        case LINKcpp:
            return "cpp";
        case LINKwindows:
            return "windows";
        case LINKpascal:
            return "pascal";
        default:
            assert(false);
    }
}


void JsonOut::propertyStorageClass(const char *name, StorageClass stc)
{
    propertyStart(name);
    arrayStart();

    if (stc & STCstatic) item("static");
    if (stc & STCextern) item("extern");
    if (stc & STCconst) item("const");
    if (stc & STCfinal) item("final");
    if (stc & STCabstract) item("abstract");
    if (stc & STCparameter) item("parameter");
    if (stc & STCfield) item("field");
    if (stc & STCoverride) item("override");
    if (stc & STCauto) item("auto");
    if (stc & STCsynchronized) item("synchronized");
    if (stc & STCdeprecated) item("deprecated");
    if (stc & STCin) item("in");
    if (stc & STCout) item("out");
    if (stc & STClazy) item("lazy");
    if (stc & STCforeach) item("foreach");
    if (stc & STCcomdat) item("comdat");
    if (stc & STCvariadic) item("variadic");
    if (stc & STCctorinit) item("ctorinit");
    if (stc & STCtemplateparameter) item("templateparameter");
    if (stc & STCscope) item("scope");
    if (stc & STCimmutable) item("immutable");
    if (stc & STCref) item("ref");
    if (stc & STCinit) item("init");
    if (stc & STCmanifest) item("manifest");
    if (stc & STCnodtor) item("nodtor");
    if (stc & STCnothrow) item("nothrow");
    if (stc & STCpure) item("pure");
    if (stc & STCtls) item("tls");
    if (stc & STCalias) item("alias");
    if (stc & STCshared) item("shared");
    if (stc & STCgshared) item("gshared");
    if (stc & STCwild) item("wild");
    if (stc & STCproperty) item("property");
    if (stc & STCsafe) item("safe");
    if (stc & STCtrusted) item("trusted");
    if (stc & STCsystem) item("system");
    if (stc & STCctfe) item("ctfe");
    if (stc & STCdisable) item("disable");
    if (stc & STCresult) item("result");
    if (stc & STCnodefaultctor) item("nodefaultctor");

    arrayEnd();
}

void JsonOut::properties(Module *module)
{
    if (module->md)
    {
        property("name", module->md->id->toChars());

        if (module->md->packages)
        {
            propertyStart("package");
            arrayStart();
            for (size_t i = 0; i < module->md->packages->dim; i++)
            {   Identifier *pid = (*module->md->packages)[i];
                item(pid->toChars());
            }
            arrayEnd();
        }
    }

    property("prettyName", module->toPrettyChars());
}

void JsonOut::properties(Dsymbol *sym)
{
    property("name", sym->toChars());
    propertyStart("loc");
    objectStart();

    if (sym->loc.filename)
        property("file", sym->loc.filename);

    if (sym->loc.linnum)
        property("line", sym->loc.linnum);

    objectEnd();

    Module *module = sym->getModule();
    if (module)
    {
        propertyStart("module");
        objectStart();

        properties(module);

        objectEnd();
    }
}

void JsonOut::properties(Declaration *decl)
{
    properties((Dsymbol *)decl);

    propertyStorageClass("modifiers", decl->storage_class);
}


void JsonOut::properties(TypeSArray *type)
{
    property("next", type->next);
    property("dim", type->dim->toChars());
}

void JsonOut::properties(TypeDArray *type)
{
    property("next", type->next);
}

void JsonOut::properties(TypeAArray *type)
{
    property("next", type->next);
    property("index", type->index);
}

void JsonOut::properties(TypePointer *type)
{
    property("next", type->next);
}

void JsonOut::properties(TypeReference *type)
{
    property("next", type->next);
}

void JsonOut::properties(TypeFunction *type)
{
    propertyBool("nothrow", type->isnothrow);
    propertyBool("property", type->isproperty);
    propertyBool("ref", type->isref);

    property("trust", TrustToChars(type->trust));
    property("purity", PurityToChars(type->purity));
    property("linkage", LinkageToChars(type->linkage));
        
    property("returnType", type->next);
    if (type->parameters)
        property("parameters", type->parameters);
}

void JsonOut::properties(TypeDelegate *type)
{
    properties((TypeFunction *)type->next);
}

void JsonOut::properties(TypeQualified *type) // ident.ident.ident.etc
{
    propertyStart("idents");
    arrayStart();

    for (size_t i = 0; i < type->idents.dim; i++)
    {   Identifier *ident = (*type->idents)[i];
        item(ident->toChars());
    }

    arrayEnd();
}

void JsonOut::properties(TypeIdentifier *type)
{
    properties((TypeQualified *)type);
    property("ident", type->ident->toChars());
}

void JsonOut::properties(TypeInstance *type)
{
    properties((TypeQualified *)type);
    property("tempinst", type->tempinst->toChars());
}

void JsonOut::properties(TypeTypeof *type)
{
    properties((TypeQualified *)type);
    property("exp", type->exp->toChars());
    property("type", type->exp->type);
}

void JsonOut::properties(TypeReturn *type)
{
    properties((TypeQualified *)type);
}

void JsonOut::properties(TypeStruct *type)
{
    properties((Declaration *)type->sym);
}

void JsonOut::properties(TypeEnum *type)
{
    properties((Declaration *)type->sym);
}

void JsonOut::properties(TypeTypedef *type)
{
    properties((Declaration *)type->sym);
}

void JsonOut::properties(TypeClass *type)
{
    properties((Declaration *)type->sym);
}

void JsonOut::properties(TypeTuple *type)
{
    property("arguments", type->arguments);
}

void JsonOut::properties(TypeSlice *type)
{
    property("lower", type->lwr->toChars());
    property("upper", type->upr->toChars());
}

void JsonOut::properties(TypeNull *type) { }

void JsonOut::properties(TypeVector *type)
{
    property("basetype", type->basetype);
}





void JsonOut::property(const char *name, Type *type)
{
    if (type == NULL) return;

    propertyStart(name);
    objectStart();

    property("raw", type->toChars());


    propertyStart("modifiers");
    arrayStart();

    if (type->isConst()) item("const");

    if (type->isImmutable()) item("immutable");

    if (type->isShared()) item("shared");

    arrayEnd();


    switch (type->ty)
    {
        case Tarray: // slice array, aka T[]
            property("kind", "array");
            properties((TypeDArray *)type);
            break;
        case Tsarray: // static array, aka T[dimension]
            property("kind", "sarray");
            properties((TypeSArray *)type);
            break;
        case Taarray: // associative array, aka T[type]
            property("kind", "aarray");
            properties((TypeAArray *)type);
            break;
        case Tpointer:
            property("kind", "pointer");
            properties((TypePointer *)type);
            break;
        case Treference:
            property("kind", "reference");
            properties((TypeReference *)type);
            break;
        case Tfunction:
            property("kind", "function");
            properties((TypeFunction *)type);
            break;
        case Tident:
            property("kind", "ident");
            // properties((TypeIdent *)type);
            break;
        case Tclass:
            property("kind", "class");
            properties((TypeClass *)type);
            break;
        case Tstruct:
            property("kind", "struct");
            properties((TypeStruct *)type);
            break;
        case Tenum:
            property("kind", "enum");
            properties((TypeEnum *)type);
            break;
        case Ttypedef:
            property("kind", "typedef");
            properties((TypeTypedef *)type);
            break;
        case Tdelegate:
            property("kind", "delegate");
            properties((TypeDelegate *)type);
            break;
        case Tnone:
            property("kind", "none");
            // properties((TypeNone *)type);
            break;
        case Tvoid:
            property("kind", "void");
            // properties((TypeVoid *)type);
            break;
        case Tint8:
            property("kind", "int8");
            // properties((TypeInt8 *)type);
            break;
        case Tuns8:
            property("kind", "uns8");
            // properties((TypeUns8 *)type);
            break;
        case Tint16:
            property("kind", "int16");
            // properties((TypeInt16 *)type);
            break;
        case Tuns16:
            property("kind", "uns16");
            // properties((TypeUns16 *)type);
            break;
        case Tint32:
            property("kind", "int32");
            // properties((TypeInt32 *)type);
            break;
        case Tuns32:
            property("kind", "uns32");
            // properties((TypeUns32 *)type);
            break;
        case Tint64:
            property("kind", "int64");
            // properties((TypeInt64 *)type);
            break;
        case Tuns64:
            property("kind", "uns64");
            // properties((TypeUns64 *)type);
            break;
        case Tfloat32:
            property("kind", "float32");
            // properties((TypeFloat32 *)type);
            break;
        case Tfloat64:
            property("kind", "float64");
            // properties((TypeFloat64 *)type);
            break;
        case Tfloat80:
            property("kind", "float80");
            // properties((TypeFloat80 *)type);
            break;
        case Timaginary32:
            property("kind", "imaginary32");
            // properties((TypeImaginary32 *)type);
            break;
        case Timaginary64:
            property("kind", "imaginary64");
            // properties((TypeImaginary64 *)type);
            break;
        case Timaginary80:
            property("kind", "imaginary80");
            // properties((TypeImaginary80 *)type);
            break;
        case Tcomplex32:
            property("kind", "complex32");
            // properties((TypeComplex32 *)type);
            break;
        case Tcomplex64:
            property("kind", "complex64");
            // properties((TypeComplex64 *)type);
            break;
        case Tcomplex80:
            property("kind", "complex80");
            // properties((TypeComplex80 *)type);
            break;
        case Tbool:
            property("kind", "bool");
            // properties((TypeBool *)type);
            break;
        case Tchar:
            property("kind", "char");
            // properties((TypeChar *)type);
            break;
        case Twchar:
            property("kind", "wchar");
            // properties((TypeWchar *)type);
            break;
        case Tdchar:
            property("kind", "dchar");
            // properties((TypeDchar *)type);
            break;
        case Tinstance:
            property("kind", "instance");
            properties((TypeInstance *)type);
            break;
        case Ttypeof:
            property("kind", "typeof");
            properties((TypeTypeof *)type);
            break;
        case Ttuple:
            property("kind", "tuple");
            properties((TypeTuple *)type);
            break;
        case Tslice:
            property("kind", "slice");
            properties((TypeSlice *)type);
            break;
        case Treturn:
            property("kind", "return");
            properties((TypeReturn *)type);
            break;
        case Tnull:
            property("kind", "null");
            properties((TypeNull *)type);
            break;
        case Tvector:
            property("kind", "vector");
            properties((TypeVector *)type);
            break;
        case Terror:
            assert(false); // shouldn't ever happen
        default:
            assert(false);
    }

    objectEnd();
}

void JsonOut::property(const char *name, Parameters *parameters)
{
    propertyStart(name);
    arrayStart();

    for (size_t i = 0; i < parameters->dim; i++)
    {   Parameter *p = (*parameters)[i];
        objectStart();

        if (p->ident)
            property("name", p->ident->toChars());

        property("type", p->type);



        propertyStorageClass("modifiers", p->storageClass);
        
        if (p->defaultArg)
            property("default", p->defaultArg->toChars());


        objectEnd();
    }

    arrayEnd();
}



void Dsymbol::toJson(JsonOut *json)
{
    json->objectStart();

    //json->property("unknown", "dsymbol");

    json->property("kind", kind());

    json->properties(this);

    json->objectEnd();
}

void Module::toJson(JsonOut *json)
{
    json->objectStart();

    json->properties(this);

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


const char* Pprotectionnames[] = {NULL, "none", "private", "package", "protected", "public", "export"};

void JsonCommonProperties(JsonOut *json, Dsymbol *sym)
{
    json->property("name", sym->toChars());
    json->property("kind", sym->kind());

    if (sym->prot())
        json->property("protection", Pprotectionnames[sym->prot()]);

    if (sym->comment)
        json->property("comment", (const char *)sym->comment);

    if (sym->loc.linnum)
        json->property("line", (int)sym->loc.linnum);
}

void JsonCommonProperties(JsonOut *json, Declaration *decl)
{
    JsonCommonProperties(json, (Dsymbol *)decl);

    json->property("type", decl->type);

    if (decl->type != decl->originalType)
        json->property("originalType", decl->originalType);
}

void Declaration::toJson(JsonOut *json)
{
    json->objectStart();

    //json->property("unknown", "declaration");

    JsonCommonProperties(json, this);

    TypedefDeclaration *td = isTypedefDeclaration();
    if (td)
    {
        json->property("base", td->basetype);
    }

    json->objectEnd();
}

void AggregateDeclaration::toJson(JsonOut *json)
{
    json->objectStart();

    JsonCommonProperties(json, this);

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

    JsonCommonProperties(json, this);

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

    JsonCommonProperties(json, this);

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

    JsonCommonProperties(json, this);

    json->property("type", type);

    json->removeComma();
    json->objectEnd();
}


