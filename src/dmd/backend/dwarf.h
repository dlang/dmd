
#ifndef DWARF_H
#define DWARF_H

/* ==================== Dwarf debug ======================= */

#define DWARF_VERSION 3

void dwarf_initfile(const char *filename);
void dwarf_termfile();
void dwarf_initmodule(const char *filename, const char *modulename);
void dwarf_termmodule();
void dwarf_func_start(Symbol *sfunc);
void dwarf_func_term(Symbol *sfunc);
unsigned dwarf_typidx(type *t);
unsigned dwarf_abbrev_code(unsigned char *data, size_t nbytes);

int dwarf_regno(int reg);

void dwarf_addrel(int seg, targ_size_t offset, int targseg, targ_size_t val = 0);
int dwarf_reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val);
void dwarf_except_gentables(Funcsym *sfunc, unsigned startoffset, unsigned retoffset);
void genDwarfEh(Funcsym *sfunc, int seg, Outbuffer *et, bool scancode, unsigned startoffset, unsigned retoffset);
int dwarf_eh_frame_fixup(int seg, targ_size_t offset, Symbol *s, targ_size_t val, Symbol *seh);

#endif
