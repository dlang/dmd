
//#pragma once
#ifndef DT_H
#define DT_H    1

struct dt_t;
struct Symbol;
typedef unsigned        tym_t;          // data type big enough for type masks

void dt_free(dt_t *);
void dt_term();

void dtpatchoffset(dt_t *dt, unsigned offset);
void dt_optimize(dt_t *dt);
void init_common(Symbol *);
unsigned dt_size(const dt_t *dtstart);
dt_t **dtend(dt_t** pdt);
bool dtallzeros(const dt_t *dt);
bool dtpointers(const dt_t *dt);
void dt2common(dt_t **pdt);

struct DtBuilder
{
  private:

    dt_t *head;
    dt_t **pTail;

  public:

    DtBuilder();
    dt_t *finish();
    void nbytes(unsigned size, const char *ptr);
    void abytes(tym_t ty, unsigned offset, unsigned size, const char *ptr, unsigned nzeros);
    void abytes(unsigned offset, unsigned size, const char *ptr, unsigned nzeros);
    void dword(int value);
    void size(unsigned long long value);
    void nzeros(unsigned size);
    void xoff(Symbol *s, unsigned offset, tym_t ty);
    dt_t *xoffpatch(Symbol *s, unsigned offset, tym_t ty);
    void xoff(Symbol *s, unsigned offset);
    void dtoff(dt_t *dt, unsigned offset);
    void coff(unsigned offset);
    void cat(dt_t *dt);
    void repeat(dt_t *dt, size_t count);
    unsigned length();
    bool isZeroLength();
};

#endif /* DT_H */

