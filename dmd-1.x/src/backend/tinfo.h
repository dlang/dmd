
// Copyright (c) 2000-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gpl.txt.
// See the included readme.txt for details.


#ifndef TYPEINFO_H
#define TYPEINFO_H

#include <stdlib.h>

typedef size_t hash_t;

struct TypeInfo
{
    virtual const char* toString() = 0;
    virtual hash_t getHash(void *p) = 0;
    virtual int equals(void *p1, void *p2) = 0;
    virtual int compare(void *p1, void *p2) = 0;
    virtual size_t tsize() = 0;
    virtual void swap(void *p1, void *p2) = 0;
};

struct TypeInfo_Achar : TypeInfo
{
    const char* toString();
    hash_t getHash(void *p);
    int equals(void *p1, void *p2);
    int compare(void *p1, void *p2);
    size_t tsize();
    void swap(void *p1, void *p2);
};

extern TypeInfo_Achar ti_achar;

#endif
