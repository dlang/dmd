/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/dt.d, backend/dt.d)
 */

module dmd.backend.dt;

// Online documentation: https://dlang.org/phobos/dmd_backend_dt.html

import dmd.backend.cc;
import dmd.backend.ty;
import dmd.backend.type;

//struct Symbol;
//alias uint tym_t;
//struct dt_t;

nothrow:
@nogc:

extern (C++)
{
    void dt_free(dt_t*);
    void dtpatchoffset(dt_t *dt, uint offset);
    bool dtallzeros(const(dt_t)* dt);
    bool dtpointers(const(dt_t)* dt);
    void dt2common(dt_t **pdt);
    uint dt_size(const(dt_t)* dtstart);
}

extern (C++) class DtBuilder
{
private:

    dt_t* head;
    dt_t** pTail;

public:
    extern (D) this()
    {
        pTail = &head;
    }

extern (C++):
    dt_t* finish();
final:
    void nbytes(uint size, const(char)* ptr);
    void abytes(tym_t ty, uint offset, uint size, const(char)* ptr, uint nzeros);
    void abytes(uint offset, uint size, const(char)* ptr, uint nzeros);
    void dword(int value);
version (OSX)
{
    void size(ulong value, int dummy = 0)
    {
        nbytes(_tysize[TYnptr], cast(char*)&value);
    }
}
else
{
    void size(ulong value);
}
    void nzeros(uint size);
    void xoff(Symbol* s, uint offset, tym_t ty);
    dt_t* xoffpatch(Symbol* s, uint offset, tym_t ty);
    void xoff(Symbol* s, uint offset);
    Symbol* dtoff(dt_t* dt, uint offset);
    void coff(uint offset);
    void cat(dt_t* dt);
    void cat(DtBuilder dtb);
    void repeat(dt_t* dt, uint count);
    uint length();
    bool isZeroLength();
};

