
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

struct JsonOut
{
    OutBuffer buf;

    void removeComma();

    void arrayStart();
    void arrayEnd();
    void objectStart();
    void objectEnd();
};

void json_generate(Modules *modules)
{
    JsonOut json;

    json.buf.writestring("[\n");
    for (size_t i = 0; i < modules->dim; i++)
    {   Module *m = (*modules)[i];
        if (global.params.verbose)
            printf("json gen %s\n", m->toChars());
        m->toJson(&json);
        json.buf.writestring(",\n");
    }
    json.removeComma();
    json.buf.writestring("]\n");

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
        size_t n = fwrite(json.buf.data, 1, json.buf.offset, stdout);
        assert(n == json.buf.offset);        // keep gcc happy about return values
        return;
    }
//    if (!FileName::absolute(arg))
//        arg = FileName::combine(dir, arg);
    FileName *jsonfilename = FileName::defaultExt(arg, global.json_ext);
    File *jsonfile = new File(jsonfilename);
    assert(jsonfile);
    jsonfile->setbuffer(json.buf.data, json.buf.offset);
    jsonfile->ref = 1;
    char *pt = FileName::path(jsonfile->toChars());
    if (*pt)
        FileName::ensurePathExists(pt);
    mem.free(pt);
    jsonfile->writev();
}


void JsonOut::removeComma()
{
    if (buf.offset >= 2 &&
        buf.data[buf.offset - 2] == ',' &&
        buf.data[buf.offset - 1] == '\n')
        buf.offset -= 2;
}

// Json array functions

void JsonOut::arrayStart()
{
    buf.writestring("[\n");
}

void JsonOut::arrayEnd()
{
    buf.writestring("]\n");
}


// Json object functions

void JsonOut::objectStart()
{
    buf.writestring("{\n");
}

void JsonOut::objectEnd()
{
    buf.writestring("}\n");
}



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

            case '/':
                buf->writestring("\\/");
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

void JsonProperty(OutBuffer *buf, const char *name, const char *value)
{
    JsonString(buf, name);
    buf->writestring(" : ");
    JsonString(buf, value);
    buf->writestring(",\n");
}

void JsonProperty(OutBuffer *buf, const char *name, int value)
{
    JsonString(buf, name);
    buf->writestring(" : ");
    buf->printf("%d", value);
    buf->writestring(",\n");
}

void Type::toJson(JsonOut *json)
{
}

void TypeSArray::toJson(JsonOut *json)
{
}

void TypeDArray::toJson(JsonOut *json)
{
}

void TypeAArray::toJson(JsonOut *json)
{
}

void TypePointer::toJson(JsonOut *json)
{
}

void TypeReference::toJson(JsonOut *json)
{
}

void TypeFunction::toJson(JsonOut *json)
{
}

void TypeDelegate::toJson(JsonOut *json)
{
}

void TypeQualified::toJson(JsonOut *json) // ident.ident.ident.etc
{
}

void TypeIdentifier::toJson(JsonOut *json)
{
}

void TypeInstance::toJson(JsonOut *json)
{
}

void TypeTypeof::toJson(JsonOut *json)
{
}

void TypeReturn::toJson(JsonOut *json)
{
}

void TypeStruct::toJson(JsonOut *json)
{
}

void TypeEnum::toJson(JsonOut *json)
{
}

void TypeTypedef::toJson(JsonOut *json)
{
}

void TypeClass::toJson(JsonOut *json)
{
}

void TypeTuple::toJson(JsonOut *json)
{
}

void TypeSlice::toJson(JsonOut *json)
{
}

void TypeNull::toJson(JsonOut *json) { }

void TypeVector::toJson(JsonOut *json)
{
}

void Dsymbol::toJson(JsonOut *json)
{
}

void Dsymbol::jsonProperties(JsonOut *json)
{
}

void Module::toJson(JsonOut *json)
{
    json->objectStart();

    if (md)
        JsonProperty(&json->buf, Pname, md->toChars());

    JsonProperty(&json->buf, Pkind, kind());

    JsonProperty(&json->buf, Pfile, srcfile->toChars());

    if (comment)
        JsonProperty(&json->buf, Pcomment, (const char *)comment);

    JsonString(&json->buf, Pmembers);
    json->buf.writestring(" : ");
    json->arrayStart();

    size_t offset = json->buf.offset;
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        if (offset != json->buf.offset)
        {   json->buf.writestring(",\n");
            offset = json->buf.offset;
        }
        s->toJson(json);
    }

    json->removeComma();
    json->arrayEnd();

    json->objectEnd();
}

void Module::jsonProperties(JsonOut *json)
{
}

void AttribDeclaration::toJson(JsonOut *json)
{
    //printf("AttribDeclaration::toJsonBuffer()\n");

    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        size_t offset = json->buf.offset;
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            //printf("AttribDeclaration::toJsonBuffer %s\n", s->toChars());
            if (offset != json->buf.offset)
            {   json->buf.writestring(",\n");
                offset = json->buf.offset;
            }
            s->toJson(json);
        }
        json->removeComma();
    }
}


void ConditionalDeclaration::toJson(JsonOut *json)
{
    //printf("ConditionalDeclaration::toJson()\n");
    if (condition->inc)
    {
        AttribDeclaration::toJson(json);
    }
}


void ClassInfoDeclaration::toJson(JsonOut *json)  { }
void ModuleInfoDeclaration::toJson(JsonOut *json) { }
void TypeInfoDeclaration::toJson(JsonOut *json)   { }

void Declaration::toJson(JsonOut *json)
{
    //printf("Declaration::toJson()\n");
    json->objectStart();

    JsonProperty(&json->buf, Pname, toChars());
    JsonProperty(&json->buf, Pkind, kind());

    if (prot())
        JsonProperty(&json->buf, Pprotection, Pprotectionnames[prot()]);

    if (type)
        JsonProperty(&json->buf, Ptype, type->toChars());

    if (originalType && type != originalType)
        JsonProperty(&json->buf, "originalType", originalType->toChars());

    if (comment)
        JsonProperty(&json->buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(&json->buf, Pline, loc.linnum);

    TypedefDeclaration *td = isTypedefDeclaration();
    if (td)
    {
        JsonProperty(&json->buf, "base", td->basetype->toChars());
    }

    json->removeComma();
    json->objectEnd();
}

void Declaration::jsonProperties(JsonOut *json)
{
}

void AggregateDeclaration::toJson(JsonOut *json)
{
    //printf("AggregateDeclaration::toJson()\n");
    json->objectStart();

    JsonProperty(&json->buf, Pname, toChars());
    JsonProperty(&json->buf, Pkind, kind());

    if (prot())
        JsonProperty(&json->buf, Pprotection, Pprotectionnames[prot()]);

    if (comment)
        JsonProperty(&json->buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(&json->buf, Pline, loc.linnum);

    ClassDeclaration *cd = isClassDeclaration();
    if (cd)
    {
        if (cd->baseClass)
        {
            JsonProperty(&json->buf, "base", cd->baseClass->toChars());
        }
        if (cd->interfaces_dim)
        {
            JsonString(&json->buf, "interfaces");
            json->buf.writestring(" : [\n");
            size_t offset = json->buf.offset;
            for (size_t i = 0; i < cd->interfaces_dim; i++)
            {   BaseClass *b = cd->interfaces[i];
                if (offset != json->buf.offset)
                {   json->buf.writestring(",\n");
                    offset = json->buf.offset;
                }
                JsonString(&json->buf, b->base->toChars());
            }
            json->removeComma();
            json->buf.writestring("],\n");
        }
    }

    if (members)
    {
        JsonString(&json->buf, Pmembers);
        json->buf.writestring(" : ");
        json->arrayStart();
        size_t offset = json->buf.offset;
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            if (offset != json->buf.offset)
            {   json->buf.writestring(",\n");
                offset = json->buf.offset;
            }
            s->toJson(json);
        }
        json->removeComma();
        json->arrayEnd();
    }
    json->removeComma();

    json->objectEnd();
}

void TemplateDeclaration::toJson(JsonOut *json)
{
    //printf("TemplateDeclaration::toJson()\n");

    json->objectStart();

    JsonProperty(&json->buf, Pname, toChars());
    JsonProperty(&json->buf, Pkind, "template");       // TemplateDeclaration::kind() does something else

    if (prot())
        JsonProperty(&json->buf, Pprotection, Pprotectionnames[prot()]);

    if (comment)
        JsonProperty(&json->buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(&json->buf, Pline, loc.linnum);

    JsonString(&json->buf, Pmembers);
    json->buf.writestring(" : ");
    json->arrayStart();
    size_t offset = json->buf.offset;
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        if (offset != json->buf.offset)
        {   json->buf.writestring(",\n");
            offset = json->buf.offset;
        }
        s->toJson(json);
    }
    json->removeComma();
    json->arrayEnd();

    json->objectEnd();
}

void EnumDeclaration::toJson(JsonOut *json)
{
    //printf("EnumDeclaration::toJson()\n");
    if (isAnonymous())
    {
        if (members)
        {
            for (size_t i = 0; i < members->dim; i++)
            {
                Dsymbol *s = (*members)[i];
                s->toJson(json);
                json->buf.writestring(",\n");
            }
            json->removeComma();
        }
        return;
    }

    json->objectStart();

    JsonProperty(&json->buf, Pname, toChars());
    JsonProperty(&json->buf, Pkind, kind());

    if (prot())
        JsonProperty(&json->buf, Pprotection, Pprotectionnames[prot()]);

    if (comment)
        JsonProperty(&json->buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(&json->buf, Pline, loc.linnum);

    if (memtype)
        JsonProperty(&json->buf, "base", memtype->toChars());

    if (members)
    {
        JsonString(&json->buf, Pmembers);
        json->buf.writestring(" : ");
        json->arrayStart();
        size_t offset = json->buf.offset;
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            if (offset != json->buf.offset)
            {   json->buf.writestring(",\n");
                offset = json->buf.offset;
            }
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
    //printf("EnumMember::toJson()\n");
    json->objectStart();

    JsonProperty(&json->buf, Pname, toChars());
    JsonProperty(&json->buf, Pkind, kind());

    if (prot())
        JsonProperty(&json->buf, Pprotection, Pprotectionnames[prot()]);

    if (comment)
        JsonProperty(&json->buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(&json->buf, Pline, loc.linnum);

    json->removeComma();
    json->objectEnd();
}


