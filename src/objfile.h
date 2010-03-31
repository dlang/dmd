

#ifndef OBJFILE_H
#define OBJFILE_H

#include "root.h"

typedef void *SymHandle;
typedef unsigned SegOffset;

enum ObjFormat
{
        NTCOFF,
        ELF
};

struct ObjFile : File
{
    ObjFile(FileName *);
    ~ObjFile();

    ObjFile *init(ObjFormat);

    void comment(const char *);         // insert comment into object file
    void modulename(const char *);      // set module name
    void library(const char *);         // add default library
    void startaddress(SegHandle seg, SegOffset offset);         // set start address

    // Segments
    enum SegHandle
    {   code = 1,
        data, bss
    };

    SymHandle defineSym(const char *name, SegHandle seg, SegOffset offset);
    SymHandle externSym(const char *name);

    SegOffset write(SegHandle seg, const void *data, unsigned nbytes);
    SegOffset writestring(SegHandle seg, char *string);
    SegOffset write8(SegHandle seg, unsigned b);
    SegOffset write16(SegHandle seg, unsigned w);
    SegOffset write32(SegHandle seg, unsigned long v);
    SegOffset write64(SegHandle seg, unsigned long long v);
    SegOffset fill0(SegHandle seg, unsigned nbytes);
    SegOffset align(SegHandle seg, unsigned size);
    SegOffset writefixup(SegHandle seg, SymHandle sym, unsigned value, int selfrelative);

    // Non-binding hint as to how big seg will grow
    void reserve(SegHandle seg, SegOffset size);

    // Set actual size
    void setSize(SegHandle seg, SegOffset size);

    // Get/set offset for subsequent writes
    void setOffset(SegHandle seg, SegOffset offset);
    SegOffset getOffset(SegHandle seg);

    SegHandle createSeg(const char *name);
};

#endif
