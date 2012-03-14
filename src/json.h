

// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_JSON_H
#define DMD_JSON_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "arraytypes.h"

void json_generate(Modules *);

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

#endif /* DMD_JSON_H */

