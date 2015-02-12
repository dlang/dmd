
#ifndef DWARF_H
#define DWARF_H

/* ==================== Dwarf debug ======================= */

// #define USE_DWARF_D_EXTENSIONS
#define DWARF_VERSION 2

void dwarf_initfile(const char *filename);
void dwarf_termfile();
void dwarf_initmodule(const char *filename, const char *modulename);
void dwarf_termmodule();
void dwarf_func_start(Symbol *sfunc);
void dwarf_func_term(Symbol *sfunc);
unsigned dwarf_typidx(type *t);
unsigned dwarf_abbrev_code(unsigned char *data, size_t nbytes);

int dwarf_regno(int reg);

#endif
