
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

#endif /* DT_H */

