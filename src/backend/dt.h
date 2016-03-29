
//#pragma once
#ifndef DT_H
#define DT_H    1

struct dt_t;
struct Symbol;
typedef unsigned        tym_t;          // data type big enough for type masks

void dt_free(dt_t *);
void dt_term();

dt_t **dtnbytes(dt_t **,unsigned,const char *);
dt_t **dtabytes(dt_t **pdtend,tym_t ty, unsigned offset, unsigned size, const char *ptr, unsigned nzeros);
dt_t **dtabytes(dt_t **pdtend, unsigned offset, unsigned size, const char *ptr, unsigned nzeros);
dt_t **dtdword(dt_t **, int value);
dt_t **dtsize_t(dt_t **, unsigned long long value);
dt_t **dtnzeros(dt_t **pdtend,unsigned size);
dt_t **dtxoff(dt_t **pdtend,Symbol *s,unsigned offset,tym_t ty);
dt_t **dtxoff(dt_t **pdtend,Symbol *s,unsigned offset);
dt_t **dtdtoff(dt_t **pdtend, dt_t *dt, unsigned offset);
dt_t **dtcoff(dt_t **pdtend,unsigned offset);
dt_t ** dtcat(dt_t **pdtend,dt_t *dt);
dt_t ** dtrepeat(dt_t **pdtend, dt_t *dt, size_t count);
void dtpatchoffset(dt_t *dt, unsigned offset);
void dt_optimize(dt_t *dt);
void dtsymsize(Symbol *);
void init_common(Symbol *);
unsigned dt_size(const dt_t *dtstart);
dt_t **dtend(dt_t** pdt);
bool dtallzeros(const dt_t *dt);
bool dtpointers(const dt_t *dt);
void dt2common(dt_t **pdt);

struct DtBuilder
{
//  private:

    dt_t *head;
    dt_t **pTail;

  public:

    DtBuilder()
    {
        head = NULL;
        pTail = &head;
    }

    /*************************
     * Finish and return completed data structure.
     */
    dt_t *finish()
    {
        return head;
    }

    void nbytes(unsigned size, const char *ptr)
    {
        pTail = dtnbytes(pTail, size, ptr);
    }

    void abytes(tym_t ty, unsigned offset, unsigned size, const char *ptr, unsigned nzeros)
    {
        pTail = dtabytes(pTail, ty, offset, size, ptr, nzeros);
    }

    void abytes(unsigned offset, unsigned size, const char *ptr, unsigned nzeros)
    {
        pTail = dtabytes(pTail, offset, size, ptr, nzeros);
    }

    void dword(int value)
    {
        pTail = dtdword(pTail, value);
    }

    void size(unsigned long long value)
    {
        pTail = dtsize_t(pTail, value);
    }

    void nzeros(unsigned size)
    {
        pTail = dtnzeros(pTail, size);
    }

    void xoff(Symbol *s, unsigned offset, tym_t ty)
    {
        pTail = dtxoff(pTail, s, offset, ty);
    }

    void xoff(Symbol *s, unsigned offset)
    {
        pTail = dtxoff(pTail, s, offset);
    }

    void dtoff(dt_t *dt, unsigned offset)
    {
        pTail = dtdtoff(pTail, dt, offset);
    }

    void coff(unsigned offset)
    {
        pTail = dtcoff(pTail, offset);
    }

    void cat(dt_t *dt)
    {
        pTail = dtcat(pTail, dt);
    }

    void repeat(dt_t *dt, size_t count)
    {
        pTail = dtrepeat(pTail, dt, count);
    }
};

#endif /* DT_H */

