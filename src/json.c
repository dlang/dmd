
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
#include <string.h>
#include <time.h>
#include <ctype.h>
#include <assert.h>

#include "rmem.h"
#include "root.h"

#include "mars.h"
#include "dsymbol.h"
#include "macro.h"
#include "template.h"
#include "lexer.h"
#include "aggregate.h"
#include "declaration.h"
#include "enum.h"
#include "id.h"
#include "module.h"
#include "scope.h"
#include "hdrgen.h"
#include "json.h"
#include "mtype.h"
#include "attrib.h"
#include "cond.h"

const char Pname[] = "name";
const char Pkind[] = "kind";
const char Pfile[] = "file";
const char Pline[] = "line";
const char Ptype[] = "type";
const char Pcomment[] = "comment";
const char Pmembers[] = "members";
const char Pprotection[] = "protection";
const char* Pprotectionnames[] = {NULL, "none", "private", "package", "protected", "public", "export"};

void JsonRemoveComma(OutBuffer *buf);
void JsonArrayStart(OutBuffer *buf);
void JsonArrayEnd(OutBuffer *buf);

void json_generate(Modules *modules)
{   OutBuffer buf;

    JsonArrayStart(&buf);
    for (size_t i = 0; i < modules->dim; i++)
    {   Module *m = (*modules)[i];
        if (global.params.verbose)
            printf("json gen %s\n", m->toChars());
        m->toJsonBuffer(&buf);
    }
    JsonArrayEnd(&buf);
    JsonRemoveComma(&buf);

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


// Json helper functions

// TODO: better solution than global variable?
static int indentLevel = 0;

void JsonIndent(OutBuffer *buf)
{
    if (buf->offset >= 1 && 
        buf->data[buf->offset - 1] == '\n')
        for (int i = 0; i < indentLevel; i++)
            buf->writeByte('\t');
}

void JsonRemoveComma(OutBuffer *buf)
{
    if (buf->offset >= 2 &&
        buf->data[buf->offset - 2] == ',' &&
        (buf->data[buf->offset - 1] == '\n' || buf->data[buf->offset - 1] == ' '))
        buf->offset -= 2;
}


// Json value functions

/*********************************
 * Encode string into buf, and wrap it in double quotes.
 */
void JsonString(OutBuffer *buf, const char *s)
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

void JsonInt(OutBuffer *buf, int value)
{
    buf->printf("%d", value);
}

void JsonBool(OutBuffer *buf, bool value)
{
    buf->writestring(value? "true" : "false");
}


// Json array functions

void JsonArrayStart(OutBuffer *buf)
{
    JsonIndent(buf);
    buf->writestring("[\n");
    indentLevel++;
}

void JsonArrayEnd(OutBuffer *buf)
{
    indentLevel--;
    if (buf->offset >= 2 &&
        buf->data[buf->offset - 2] == '[' &&
        buf->data[buf->offset - 1] == '\n')
        buf->offset -= 1;
    else
    {
        JsonRemoveComma(buf);
        buf->writestring("\n");
        JsonIndent(buf);
    }
    buf->writestring("],\n");
}


// Json object functions

void JsonObjectStart(OutBuffer *buf)
{
    JsonIndent(buf);
    buf->writestring("{\n");
    indentLevel++;
}

void JsonObjectEnd(OutBuffer *buf)
{
    indentLevel--;
    if (buf->offset >= 2 &&
        buf->data[buf->offset - 2] == '{' &&
        buf->data[buf->offset - 1] == '\n')
        buf->offset -= 1;
    else
    {
        JsonRemoveComma(buf);
        buf->writestring("\n");
        JsonIndent(buf);
    }
    buf->writestring("},\n");
}


// Json object property functions

void JsonPropertyStart(OutBuffer *buf, const char *name)
{
    JsonIndent(buf);
    JsonString(buf, name);
    buf->writestring(" : ");
}

void JsonProperty(OutBuffer *buf, const char *name, const char *value)
{
    JsonPropertyStart(buf, name);
    JsonString(buf, value);
    buf->writestring(",\n");
}

void JsonProperty(OutBuffer *buf, const char *name, int value)
{
    JsonPropertyStart(buf, name);
    JsonInt(buf, value);
    buf->writestring(",\n");
}

void JsonPropertyBool(OutBuffer *buf, const char *name, bool value)
{
    JsonPropertyStart(buf, name);
    JsonBool(buf, value);
    buf->writestring(",\n");
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
            return "unknown";
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
            return "unknown";
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
            return "unknown";
    }
}


void JsonProperty(OutBuffer *buf, const char *name, Type *type);

void JsonProperties(OutBuffer *buf, Module *module)
{
    if (module->md)
    {
        JsonProperty(buf, Pname, module->md->id->toChars());

        if (module->md->packages)
        {
            JsonPropertyStart(buf, "package");
            JsonArrayStart(buf);
            for (size_t i = 0; i < module->md->packages->dim; i++)
            {   Identifier *pid = module->md->packages->tdata()[i];

                JsonString(buf, pid->toChars());
                buf->writestring(", ");
            }
            JsonArrayEnd(buf);
        }
    }

    JsonProperty(buf, "prettyName", module->toPrettyChars());
}

void JsonProperties(OutBuffer *buf, Dsymbol *sym)
{
    JsonProperty(buf, Pname, sym->ident->toChars());
    JsonPropertyStart(buf, "loc");
    JsonObjectStart(buf);

    if (sym->loc.filename)
        JsonProperty(buf, "file", sym->loc.filename);

    if (sym->loc.linnum)
        JsonProperty(buf, "line", sym->loc.linnum);

    JsonObjectEnd(buf);

    JsonPropertyStart(buf, "module");
    JsonObjectStart(buf);

    JsonProperties(buf, sym->getModule());

    JsonObjectEnd(buf);
}


void JsonProperties(OutBuffer *buf, TypeSArray *type)
{
    JsonProperty(buf, "next", type->next);
    JsonProperty(buf, "dim", type->dim->toChars());
}

void JsonProperties(OutBuffer *buf, TypeDArray *type)
{
    JsonProperty(buf, "next", type->next);
}

void JsonProperties(OutBuffer *buf, TypeAArray *type)
{
    JsonProperty(buf, "next", type->next);
    JsonProperty(buf, "index", type->index);
}

void JsonProperties(OutBuffer *buf, TypePointer *type)
{
    JsonProperty(buf, "next", type->next);
}

void JsonProperties(OutBuffer *buf, TypeReference *type)
{
    JsonProperty(buf, "next", type->next);
}

void JsonProperties(OutBuffer *buf, TypeFunction *type)
{
    JsonPropertyBool(buf, "nothrow", type->isnothrow);
    JsonPropertyBool(buf, "property", type->isproperty);
    JsonPropertyBool(buf, "ref", type->isref);

    JsonProperty(buf, "trust", TrustToChars(type->trust));
    JsonProperty(buf, "purity", PurityToChars(type->purity));
    JsonProperty(buf, "linkage", LinkageToChars(type->linkage));
        
    JsonProperty(buf, "returnType", type->next);
}

void JsonProperties(OutBuffer *buf, TypeDelegate *type)
{
    JsonProperties(buf, (TypeFunction *)type->next);
}

void JsonProperties(OutBuffer *buf, TypeQualified *type) // ident.ident.ident.etc
{
    JsonPropertyStart(buf, "idents");
    JsonArrayStart(buf);

    for (size_t i = 0; i < type->idents.dim; i++)
    {   Identifier *ident = type->idents.tdata()[i];
        JsonString(buf, ident->toChars());
        buf->writestring(", ");
    }

    JsonArrayEnd(buf);
}

void JsonProperties(OutBuffer *buf, TypeIdentifier *type)
{
    JsonProperties(buf, (TypeQualified *)type);
    JsonProperty(buf, "ident", type->ident->toChars());
}

void JsonProperties(OutBuffer *buf, TypeInstance *type)
{
    JsonProperties(buf, (TypeQualified *)type);
    JsonProperty(buf, "tempinst", type->tempinst->toChars());
}

void JsonProperties(OutBuffer *buf, TypeTypeof *type)
{
    JsonProperties(buf, (TypeQualified *)type);
    JsonProperty(buf, "exp", type->exp->toChars());
    JsonProperty(buf, "type", type->exp->type);
}

void JsonProperties(OutBuffer *buf, TypeReturn *type)
{
    JsonProperties(buf, (TypeQualified *)type);
}

void JsonProperties(OutBuffer *buf, TypeStruct *type)
{
    JsonProperties(buf, (Dsymbol *)type->sym);
}

void JsonProperties(OutBuffer *buf, TypeEnum *type)
{
    JsonProperties(buf, (Dsymbol *)type->sym);
}

void JsonProperties(OutBuffer *buf, TypeTypedef *type)
{
    JsonProperties(buf, (Dsymbol *)type->sym);
}

void JsonProperties(OutBuffer *buf, TypeClass *type)
{
    JsonProperties(buf, (Dsymbol *)type->sym);
}

void JsonProperties(OutBuffer *buf, TypeTuple *type)
{
    JsonProperty(buf, "arguments", type->arguments);
}

void JsonProperties(OutBuffer *buf, TypeSlice *type)
{
    JsonProperty(buf, "lower", type->lwr->toChars());
    JsonProperty(buf, "upper", type->upr->toChars());
}

void JsonProperties(OutBuffer *buf, TypeNull *type) { }

void JsonProperties(OutBuffer *buf, TypeVector *type)
{
    JsonProperty(buf, "basetype", type->basetype);
}





void JsonProperty(OutBuffer *buf, const char *name, Type *type)
{
    if (type == NULL) return;

    JsonPropertyStart(buf, name);
    JsonObjectStart(buf);

    JsonProperty(buf, "raw", type->toChars());


    switch (type->ty)
    {
        case Tarray: // slice array, aka T[]
            JsonProperty(buf, "kind", "array");
            JsonProperties(buf, (TypeDArray *)type);
            break;
        case Tsarray: // static array, aka T[dimension]
            JsonProperty(buf, "kind", "sarray");
            JsonProperties(buf, (TypeSArray *)type);
            break;
        case Taarray: // associative array, aka T[type]
            JsonProperty(buf, "kind", "aarray");
            JsonProperties(buf, (TypeAArray *)type);
            break;
        case Tpointer:
            JsonProperty(buf, "kind", "pointer");
            JsonProperties(buf, (TypePointer *)type);
            break;
        case Treference:
            JsonProperty(buf, "kind", "reference");
            JsonProperties(buf, (TypeReference *)type);
            break;
        case Tfunction:
            JsonProperty(buf, "kind", "function");
            JsonProperties(buf, (TypeFunction *)type);
            break;
        case Tident:
            JsonProperty(buf, "kind", "ident");
            // JsonProperties(buf, (TypeIdent *)type);
            break;
        case Tclass:
            JsonProperty(buf, "kind", "class");
            JsonProperties(buf, (TypeClass *)type);
            break;
        case Tstruct:
            JsonProperty(buf, "kind", "struct");
            JsonProperties(buf, (TypeStruct *)type);
            break;
        case Tenum:
            JsonProperty(buf, "kind", "enum");
            JsonProperties(buf, (TypeEnum *)type);
            break;
        case Ttypedef:
            JsonProperty(buf, "kind", "typedef");
            JsonProperties(buf, (TypeTypedef *)type);
            break;
        case Tdelegate:
            JsonProperty(buf, "kind", "delegate");
            JsonProperties(buf, (TypeDelegate *)type);
            break;
        case Tnone:
            JsonProperty(buf, "kind", "none");
            // JsonProperties(buf, (TypeNone *)type);
            break;
        case Tvoid:
            JsonProperty(buf, "kind", "void");
            // JsonProperties(buf, (TypeVoid *)type);
            break;
        case Tint8:
            JsonProperty(buf, "kind", "int8");
            // JsonProperties(buf, (TypeInt8 *)type);
            break;
        case Tuns8:
            JsonProperty(buf, "kind", "uns8");
            // JsonProperties(buf, (TypeUns8 *)type);
            break;
        case Tint16:
            JsonProperty(buf, "kind", "int16");
            // JsonProperties(buf, (TypeInt16 *)type);
            break;
        case Tuns16:
            JsonProperty(buf, "kind", "uns16");
            // JsonProperties(buf, (TypeUns16 *)type);
            break;
        case Tint32:
            JsonProperty(buf, "kind", "int32");
            // JsonProperties(buf, (TypeInt32 *)type);
            break;
        case Tuns32:
            JsonProperty(buf, "kind", "uns32");
            // JsonProperties(buf, (TypeUns32 *)type);
            break;
        case Tint64:
            JsonProperty(buf, "kind", "int64");
            // JsonProperties(buf, (TypeInt64 *)type);
            break;
        case Tuns64:
            JsonProperty(buf, "kind", "uns64");
            // JsonProperties(buf, (TypeUns64 *)type);
            break;
        case Tfloat32:
            JsonProperty(buf, "kind", "float32");
            // JsonProperties(buf, (TypeFloat32 *)type);
            break;
        case Tfloat64:
            JsonProperty(buf, "kind", "float64");
            // JsonProperties(buf, (TypeFloat64 *)type);
            break;
        case Tfloat80:
            JsonProperty(buf, "kind", "float80");
            // JsonProperties(buf, (TypeFloat80 *)type);
            break;
        case Timaginary32:
            JsonProperty(buf, "kind", "imaginary32");
            // JsonProperties(buf, (TypeImaginary32 *)type);
            break;
        case Timaginary64:
            JsonProperty(buf, "kind", "imaginary64");
            // JsonProperties(buf, (TypeImaginary64 *)type);
            break;
        case Timaginary80:
            JsonProperty(buf, "kind", "imaginary80");
            // JsonProperties(buf, (TypeImaginary80 *)type);
            break;
        case Tcomplex32:
            JsonProperty(buf, "kind", "complex32");
            // JsonProperties(buf, (TypeComplex32 *)type);
            break;
        case Tcomplex64:
            JsonProperty(buf, "kind", "complex64");
            // JsonProperties(buf, (TypeComplex64 *)type);
            break;
        case Tcomplex80:
            JsonProperty(buf, "kind", "complex80");
            // JsonProperties(buf, (TypeComplex80 *)type);
            break;
        case Tbool:
            JsonProperty(buf, "kind", "bool");
            // JsonProperties(buf, (TypeBool *)type);
            break;
        case Tchar:
            JsonProperty(buf, "kind", "char");
            // JsonProperties(buf, (TypeChar *)type);
            break;
        case Twchar:
            JsonProperty(buf, "kind", "wchar");
            // JsonProperties(buf, (TypeWchar *)type);
            break;
        case Tdchar:
            JsonProperty(buf, "kind", "dchar");
            // JsonProperties(buf, (TypeDchar *)type);
            break;
        case Terror:
            JsonProperty(buf, "kind", "error");
            // JsonProperties(buf, (TypeError *)type);
            break;
        case Tinstance:
            JsonProperty(buf, "kind", "instance");
            JsonProperties(buf, (TypeInstance *)type);
            break;
        case Ttypeof:
            JsonProperty(buf, "kind", "typeof");
            JsonProperties(buf, (TypeTypeof *)type);
            break;
        case Ttuple:
            JsonProperty(buf, "kind", "tuple");
            JsonProperties(buf, (TypeTuple *)type);
            break;
        case Tslice:
            JsonProperty(buf, "kind", "slice");
            JsonProperties(buf, (TypeSlice *)type);
            break;
        case Treturn:
            JsonProperty(buf, "kind", "return");
            JsonProperties(buf, (TypeReturn *)type);
            break;
        case Tnull:
            JsonProperty(buf, "kind", "null");
            JsonProperties(buf, (TypeNull *)type);
            break;
        case Tvector:
            JsonProperty(buf, "kind", "vector");
            JsonProperties(buf, (TypeVector *)type);
            break;
    }

    JsonObjectEnd(buf);
}


void Dsymbol::toJsonBuffer(OutBuffer *buf)
{
}

void Module::toJsonBuffer(OutBuffer *buf)
{
    JsonObjectStart(buf);

    JsonProperties(buf, this);

    JsonProperty(buf, Pfile, srcfile->toChars());

    JsonProperty(buf, Pkind, kind());

    if (comment)
        JsonProperty(buf, Pcomment, (const char *)comment);


    JsonPropertyStart(buf, Pmembers);
    JsonArrayStart(buf);

    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        s->toJsonBuffer(buf);
    }

    JsonArrayEnd(buf);

    JsonObjectEnd(buf);
}

void AttribDeclaration::toJsonBuffer(OutBuffer *buf)
{
    //printf("AttribDeclaration::toJsonBuffer()\n");

    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            //printf("AttribDeclaration::toJsonBuffer %s\n", s->toChars());
            s->toJsonBuffer(buf);
        }
        JsonRemoveComma(buf);
    }
}


void ConditionalDeclaration::toJsonBuffer(OutBuffer *buf)
{
    //printf("ConditionalDeclaration::toJsonBuffer()\n");
    if (condition->inc)
    {
        AttribDeclaration::toJsonBuffer(buf);
    }
}


void InvariantDeclaration::toJsonBuffer(OutBuffer *buf)  { }
void DtorDeclaration::toJsonBuffer(OutBuffer *buf)       { }
void StaticCtorDeclaration::toJsonBuffer(OutBuffer *buf) { }
void StaticDtorDeclaration::toJsonBuffer(OutBuffer *buf) { }
void ClassInfoDeclaration::toJsonBuffer(OutBuffer *buf)  { }
void ModuleInfoDeclaration::toJsonBuffer(OutBuffer *buf) { }
void TypeInfoDeclaration::toJsonBuffer(OutBuffer *buf)   { }
void UnitTestDeclaration::toJsonBuffer(OutBuffer *buf)   { }
#if DMDV2
void PostBlitDeclaration::toJsonBuffer(OutBuffer *buf)   { }
#endif

void JsonCommonProperties(OutBuffer *buf, Declaration *decl)
{
    JsonProperty(buf, Pname, decl->toChars());
    JsonProperty(buf, Pkind, decl->kind());

    if (decl->prot())
        JsonProperty(buf, Pprotection, Pprotectionnames[decl->prot()]);

    JsonProperty(buf, Ptype, decl->type);


    if (decl->comment)
        JsonProperty(buf, Pcomment, (const char *)decl->comment);

    if (decl->loc.linnum)
        JsonProperty(buf, Pline, decl->loc.linnum);
}

void Declaration::toJsonBuffer(OutBuffer *buf)
{
    //printf("Declaration::toJsonBuffer()\n");
    JsonObjectStart(buf);

    JsonCommonProperties(buf, this);

    TypedefDeclaration *td = isTypedefDeclaration();
    if (td)
    {
        JsonProperty(buf, "base", td->basetype);
    }

    JsonObjectEnd(buf);
}

void AggregateDeclaration::toJsonBuffer(OutBuffer *buf)
{
    //printf("AggregateDeclaration::toJsonBuffer()\n");
    JsonObjectStart(buf);

    JsonProperty(buf, Pname, toChars());
    JsonProperty(buf, Pkind, kind());

    if (prot())
        JsonProperty(buf, Pprotection, Pprotectionnames[prot()]);

    if (comment)
        JsonProperty(buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(buf, Pline, loc.linnum);

    ClassDeclaration *cd = isClassDeclaration();
    if (cd)
    {
        if (cd->baseClass)
        {
            JsonProperty(buf, "base", cd->baseClass->toChars());
        }
        if (cd->interfaces_dim)
        {
            JsonPropertyStart(buf, "interfaces");
            JsonArrayStart(buf);
            for (size_t i = 0; i < cd->interfaces_dim; i++)
            {   BaseClass *b = cd->interfaces[i];
                JsonString(buf, b->base->toChars());
                buf->writestring(",\n");
            }
            JsonArrayEnd(buf);
        }
    }

    if (members)
    {
        JsonPropertyStart(buf, Pmembers);
        JsonArrayStart(buf);
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            s->toJsonBuffer(buf);
        }
        JsonRemoveComma(buf);
        JsonArrayEnd(buf);
    }

    JsonObjectEnd(buf);
}

void TemplateDeclaration::toJsonBuffer(OutBuffer *buf)
{
    //printf("TemplateDeclaration::toJsonBuffer()\n");

    JsonObjectStart(buf);

    JsonProperty(buf, Pname, ident->toChars());
    JsonProperty(buf, Pkind, "template");

    if (prot())
        JsonProperty(buf, Pprotection, Pprotectionnames[prot()]);

    if (comment)
        JsonProperty(buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(buf, Pline, loc.linnum);

    JsonPropertyStart(buf, "parameters");
    JsonArrayStart(buf);
    for (size_t i = 0; i < parameters->dim; i++)
    {   TemplateParameter *s = (*parameters)[i];
        JsonObjectStart(buf);

        JsonProperty(buf, Pname, s->ident->toChars());

        TemplateTypeParameter *type = s->isTemplateTypeParameter();
        if (type)
        {
            JsonProperty(buf, Pkind, "type");

            if (type->specType)
                JsonProperty(buf, "specType", type->specType->toChars());
            
            if (type->defaultType)
                JsonProperty(buf, "defaultType", type->defaultType->toChars());
        }

        TemplateValueParameter *value = s->isTemplateValueParameter();
        if (value)
        {
            JsonProperty(buf, Pkind, "value");

            if (value->valType)
                JsonProperty(buf, "valType", value->valType->toChars());
            
            if (value->specValue)
                JsonProperty(buf, "specValue", value->specValue->toChars());
            
            if (value->defaultValue)
                JsonProperty(buf, "defaultValue", value->defaultValue->toChars());
        }

        TemplateAliasParameter *alias = s->isTemplateAliasParameter();
        if (alias)
        {
            JsonProperty(buf, Pkind, "alias");

            if (alias->specType)
                JsonProperty(buf, "specType", alias->specType->toChars());
            
            if (alias->specAlias)
                JsonProperty(buf, "specAlias", alias->specAlias->toChars());
            
            if (alias->defaultAlias)
                JsonProperty(buf, "defaultAlias", alias->defaultAlias->toChars());
        }

        TemplateTupleParameter *tuple = s->isTemplateTupleParameter();
        if (tuple)
        {
            JsonProperty(buf, Pkind, "tuple");
        }

#if DMDV2
        TemplateThisParameter *thisp = s->isTemplateThisParameter();
        if (thisp)
        {
            JsonProperty(buf, Pkind, "this");

            if (type->specType)
                JsonProperty(buf, "specType", type->specType->toChars());
            
            if (type->defaultType)
                JsonProperty(buf, "defaultType", type->defaultType->toChars());
        }
#endif

        JsonObjectEnd(buf);
    }
    JsonRemoveComma(buf);
    JsonArrayEnd(buf);

    JsonPropertyStart(buf, Pmembers);
    JsonArrayStart(buf);
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        s->toJsonBuffer(buf);
    }
    JsonRemoveComma(buf);
    JsonArrayEnd(buf);

    JsonObjectEnd(buf);
}

void EnumDeclaration::toJsonBuffer(OutBuffer *buf)
{
    //printf("EnumDeclaration::toJsonBuffer()\n");
    if (isAnonymous())
    {
        if (members)
        {
            for (size_t i = 0; i < members->dim; i++)
            {
                Dsymbol *s = (*members)[i];
                s->toJsonBuffer(buf);
            }
        }
        return;
    }

    JsonObjectStart(buf);

    JsonCommonProperties(buf, (Declaration *)this);

    if (memtype)
        JsonProperty(buf, "base", memtype);

    if (members)
    {
        JsonPropertyStart(buf, Pmembers);
        JsonArrayStart(buf);
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            s->toJsonBuffer(buf);
        }
        JsonRemoveComma(buf);
        JsonArrayEnd(buf);
    }
    JsonRemoveComma(buf);

    JsonObjectEnd(buf);
}

void EnumMember::toJsonBuffer(OutBuffer *buf)
{
    //printf("EnumMember::toJsonBuffer()\n");
    JsonObjectStart(buf);

    JsonCommonProperties(buf, (Declaration *)this);

    JsonRemoveComma(buf);
    JsonObjectEnd(buf);
}


