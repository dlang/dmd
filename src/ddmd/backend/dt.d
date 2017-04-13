/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/dt.d
 */

module ddmd.backend.dt;

import ddmd.backend.cc;
import ddmd.backend.ty;
import ddmd.backend.type;

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
}

extern (C++) class DtBuilder
{
private:

    dt_t* head;
    dt_t** pTail;

public:
    this()
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
    void size(ulong value);
    void nzeros(uint size);
    void xoff(Symbol* s, uint offset, tym_t ty);
    dt_t* xoffpatch(Symbol* s, uint offset, tym_t ty);
    void xoff(Symbol* s, uint offset);
    Symbol* dtoff(dt_t* dt, uint offset);
    void coff(uint offset);
    void cat(dt_t* dt);
    void cat(DtBuilder dtb);
    void repeat(dt_t* dt, size_t count);
    uint length();
    bool isZeroLength();
};

