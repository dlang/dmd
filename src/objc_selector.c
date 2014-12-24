
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_selector.c
 */

#include "declaration.h"
#include "mtype.h"
#include "objc.h"
#include "outbuffer.h"

void mangleToBuffer(Type *t, OutBuffer *buf);

// MARK: Selector

StringTable ObjcSelector::stringtable;
StringTable ObjcSelector::vTableDispatchSelectors;
int ObjcSelector::incnum = 0;

void ObjcSelector::init ()
{
    stringtable._init();
    vTableDispatchSelectors._init();

    if (global.params.isObjcNonFragileAbi)
    {
        vTableDispatchSelectors.insert("alloc", 5);
        vTableDispatchSelectors.insert("class", 5);
        vTableDispatchSelectors.insert("self", 4);
        vTableDispatchSelectors.insert("isFlipped", 9);
        vTableDispatchSelectors.insert("length", 6);
        vTableDispatchSelectors.insert("count", 5);

        vTableDispatchSelectors.insert("allocWithZone:", 14);
        vTableDispatchSelectors.insert("isKindOfClass:", 14);
        vTableDispatchSelectors.insert("respondsToSelector:", 19);
        vTableDispatchSelectors.insert("objectForKey:", 13);
        vTableDispatchSelectors.insert("objectAtIndex:", 14);
        vTableDispatchSelectors.insert("isEqualToString:", 16);
        vTableDispatchSelectors.insert("isEqual:", 8);

        // These three use vtable dispatch if the Objective-C GC is disabled
        vTableDispatchSelectors.insert("retain", 6);
        vTableDispatchSelectors.insert("release", 7);
        vTableDispatchSelectors.insert("autorelease", 11);

        // These three use vtable dispatch if the Objective-C GC is enabled
        // vTableDispatchSelectors.insert("hash", 4);
        // vTableDispatchSelectors.insert("addObject:", 10);
        // vTableDispatchSelectors.insert("countByEnumeratingWithState:objects:count:", 42);
    }
}

ObjcSelector::ObjcSelector(const char *sv, size_t len, size_t pcount, const char* mangled)
{
    stringvalue = sv;
    stringlen = len;
    paramCount = pcount;
    mangledStringValue = mangled;
}

ObjcSelector *ObjcSelector::lookup(ObjcSelectorBuilder *builder)
{
    const char* stringValue = builder->toString();
    const char* mangledStringValue = NULL;

    if (ObjcSelector::isVTableDispatchSelector(stringValue, builder->slen))
        mangledStringValue = builder->toMangledString();

    return lookup(stringValue, builder->slen, builder->colonCount, mangledStringValue);
}

ObjcSelector *ObjcSelector::lookup(const char *s)
{
    size_t len = 0;
    size_t pcount = 0;
    const char *i = s;
    while (*i != 0)
    {
        ++len;
        if (*i == ':') ++pcount;
        ++i;
    }
    return lookup(s, len, pcount);
}

ObjcSelector *ObjcSelector::lookup(const char *s, size_t len, size_t pcount, const char* mangled)
{
    StringValue *sv = stringtable.update(s, len);
    ObjcSelector *sel = (ObjcSelector *) sv->ptrvalue;
    if (!sel)
    {
        sel = new ObjcSelector(sv->toDchars(), len, pcount, mangled);
        sv->ptrvalue = sel;
    }
    return sel;
}

ObjcSelector *ObjcSelector::create(FuncDeclaration *fdecl)
{
    OutBuffer buf;
    size_t pcount = 0;
    TypeFunction *ftype = (TypeFunction *)fdecl->type;

    // Special case: property setter
    if (ftype->isproperty && ftype->parameters && ftype->parameters->dim == 1)
    {   // rewrite "identifier" as "setIdentifier"
        char firstChar = fdecl->ident->string[0];
        if (firstChar >= 'a' && firstChar <= 'z')
            firstChar = firstChar - 'a' + 'A';

        buf.write("set", 3);
        buf.writeByte(firstChar);
        buf.write(fdecl->ident->string+1, fdecl->ident->len-1);
        buf.writeByte(':');
        goto Lcomplete;
    }

    // write identifier in selector
    buf.write(fdecl->ident->string, fdecl->ident->len);

    // add mangled type and colon for each parameter
    if (ftype->parameters && ftype->parameters->dim)
    {
        buf.writeByte('_');
        Parameters *arguments = ftype->parameters;
        size_t dim = Parameter::dim(arguments);
        for (size_t i = 0; i < dim; i++)
        {
            Parameter *arg = Parameter::getNth(arguments, i);
            mangleToBuffer(arg->type, &buf);
            buf.writeByte(':');
        }
        pcount = dim;
    }
Lcomplete:
    buf.writeByte('\0');

    return lookup((const char *)buf.data, buf.size, pcount);
}

bool ObjcSelector::isVTableDispatchSelector(const char* selector, size_t length)
{
    return global.params.isObjcNonFragileAbi && vTableDispatchSelectors.lookup(selector, length) != NULL;
}

// MARK: ObjcSelectorBuilder

const char* ObjcSelectorBuilder::fixupSelector (ObjcSelector* selector, const char* fixupName, size_t fixupLength, size_t* fixupSelectorLength)
{
    assert(selector->usesVTableDispatch());

    size_t length = 1 + fixupLength + 1 + selector->stringlen + 1; // + 1 for the 'l' prefix, '_' and trailing \0
    char* fixupSelector = (char*) malloc(length * sizeof(char));
    fixupSelector[0] = 'l';
    size_t position = 1;

    memcpy(fixupSelector + position, fixupName, fixupLength);
    position += fixupLength;
    fixupSelector[position] = '_';
    position++;

    memcpy(fixupSelector + position, selector->mangledStringValue, selector->stringlen);
    fixupSelector[length - 1] = '\0';

    *fixupSelectorLength = length - 1;
    return fixupSelector;
}

void ObjcSelectorBuilder::addIdentifier(Identifier *id)
{
    assert(partCount < 10);
    parts[partCount] = id;
    slen += id->len;
    partCount += 1;
}

void ObjcSelectorBuilder::addColon()
{
    slen += 1;
    colonCount += 1;
}

int ObjcSelectorBuilder::isValid()
{
    if (colonCount == 0)
        return partCount == 1;
    else
        return partCount >= 1 && partCount <= colonCount;
}

const char *ObjcSelectorBuilder::buildString(char separator)
{
    char *s = (char*)malloc(slen + 1);
    size_t spos = 0;
    for (size_t i = 0; i < partCount; ++i)
    {
        memcpy(&s[spos], parts[i]->string, parts[i]->len);
        spos += parts[i]->len;
        if (colonCount)
        {
            s[spos] = separator;
            spos += 1;
        }
    }
    assert(colonCount == 0 || partCount <= colonCount);
    if (colonCount > partCount)
    {
        for (size_t i = 0; i < colonCount - partCount; ++i)
        {
            s[spos] = separator;
            spos += 1;
        }
    }
    assert(slen == spos);
    s[slen] = '\0';
    return s;
}
