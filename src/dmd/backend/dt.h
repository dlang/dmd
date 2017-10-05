
//#pragma once
#ifndef DT_H
#define DT_H    1

#include <stddef.h>     // for size_t

#if __APPLE__ && __i386__
    /* size_t is 'unsigned long', which makes it mangle differently
     * than D's 'uint'
     */
    typedef unsigned d_size_t;
#else
    typedef size_t d_size_t;
#endif


struct dt_t;
struct Symbol;
typedef unsigned        tym_t;          // data type big enough for type masks

void dt_free(dt_t *);
void dt_term();

void dtpatchoffset(dt_t *dt, unsigned offset);
void init_common(Symbol *);
unsigned dt_size(const dt_t *dtstart);
dt_t **dtend(dt_t** pdt);
bool dtallzeros(const dt_t *dt);
bool dtpointers(const dt_t *dt);
void dt2common(dt_t **pdt);

#if __LP64__
#define d_ulong unsigned long
#else
#define d_ulong unsigned long long
#endif

class DtBuilder
{
private:

    dt_t *head;
    dt_t **pTail;

public:

    DtBuilder();
    virtual dt_t *finish();
    void nbytes(unsigned size, const char *ptr);
    void abytes(tym_t ty, unsigned offset, unsigned size, const char *ptr, unsigned nzeros);
    void abytes(unsigned offset, unsigned size, const char *ptr, unsigned nzeros);
    void dword(int value);
    void size(d_ulong value);
    void nzeros(unsigned size);
    void xoff(Symbol *s, unsigned offset, tym_t ty);
    dt_t *xoffpatch(Symbol *s, unsigned offset, tym_t ty);
    void xoff(Symbol *s, unsigned offset);
    Symbol* dtoff(dt_t *dt, unsigned offset);
    void coff(unsigned offset);
    void cat(dt_t *dt);
    void cat(DtBuilder *dtb);
    void repeat(dt_t *dt, d_size_t count);
    unsigned length();
    bool isZeroLength();
};

#endif /* DT_H */

