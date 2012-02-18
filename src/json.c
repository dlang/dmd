
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
            buf->writestring("\t");
}

void JsonRemoveComma(OutBuffer *buf)
{
    if (buf->offset >= 2 &&
        buf->data[buf->offset - 2] == ',' &&
        buf->data[buf->offset - 1] == '\n')
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

void JsonInt(OutBuffer *buf, int value)
{
    buf->printf("%d", value);
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



void Dsymbol::toJsonBuffer(OutBuffer *buf)
{
}

void Module::toJsonBuffer(OutBuffer *buf)
{
    JsonObjectStart(buf);

    if (md)
        JsonProperty(buf, Pname, md->toChars());

    JsonProperty(buf, Pkind, kind());

    JsonProperty(buf, Pfile, srcfile->toChars());

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

void Declaration::toJsonBuffer(OutBuffer *buf)
{
    //printf("Declaration::toJsonBuffer()\n");
    JsonObjectStart(buf);

    JsonProperty(buf, Pname, toChars());
    JsonProperty(buf, Pkind, kind());

    if (prot())
        JsonProperty(buf, Pprotection, Pprotectionnames[prot()]);

    if (type)
        JsonProperty(buf, Ptype, type->toChars());

    if (comment)
        JsonProperty(buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(buf, Pline, loc.linnum);

    TypedefDeclaration *td = isTypedefDeclaration();
    if (td)
    {
        JsonProperty(buf, "base", td->basetype->toChars());
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
    JsonRemoveComma(buf);

    JsonObjectEnd(buf);
}

void TemplateDeclaration::toJsonBuffer(OutBuffer *buf)
{
    //printf("TemplateDeclaration::toJsonBuffer()\n");

    JsonObjectStart(buf);

    JsonProperty(buf, Pname, toChars());
    JsonProperty(buf, Pkind, kind());

    if (prot())
        JsonProperty(buf, Pprotection, Pprotectionnames[prot()]);

    if (comment)
        JsonProperty(buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(buf, Pline, loc.linnum);

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

    JsonProperty(buf, Pname, toChars());
    JsonProperty(buf, Pkind, kind());

    if (prot())
        JsonProperty(buf, Pprotection, Pprotectionnames[prot()]);

    if (comment)
        JsonProperty(buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(buf, Pline, loc.linnum);

    if (memtype)
        JsonProperty(buf, "base", memtype->toChars());

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

    JsonProperty(buf, Pname, toChars());
    JsonProperty(buf, Pkind, kind());

    if (prot())
        JsonProperty(buf, Pprotection, Pprotectionnames[prot()]);

    if (comment)
        JsonProperty(buf, Pcomment, (const char *)comment);

    if (loc.linnum)
        JsonProperty(buf, Pline, loc.linnum);

    JsonRemoveComma(buf);
    JsonObjectEnd(buf);
}


