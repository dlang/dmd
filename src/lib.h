
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_LIB_H
#define DMD_LIB_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

struct ObjModule;

struct ObjSymbol
{
    char *name;
    ObjModule *om;
};

#include "arraytypes.h"

typedef ArrayBase<ObjModule> ObjModules;
typedef ArrayBase<ObjSymbol> ObjSymbols;

struct Library
{
    File *libfile;
    ObjModules objmodules;   // ObjModule[]
    ObjSymbols objsymbols;   // ObjSymbol[]

    StringTable tab;

    Library();
    void setFilename(char *dir, char *filename);
    void addObject(const char *module_name, void *buf, size_t buflen);
    void addLibrary(void *buf, size_t buflen);
    void write();

  private:
    void addSymbol(ObjModule *om, char *name, int pickAny = 0);
    void scanObjModule(ObjModule *om);
    unsigned short numDictPages(unsigned padding);
    int FillDict(unsigned char *bucketsP, unsigned short uNumPages);
    void WriteLibToBuffer(OutBuffer *libbuf);
};

#endif /* DMD_LIB_H */

