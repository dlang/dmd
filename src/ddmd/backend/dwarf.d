/** Dwarf debug
 *
 * Source: $(DMDSRC backend/_dwarf.d)
 */

module ddmd.backend.dwarf;

import ddmd.backend.cc;
import ddmd.backend.cdef;
import ddmd.backend.outbuf;
import ddmd.backend.type;

enum DWARF_VERSION = 3;

void dwarf_initfile(const(char) *filename);
void dwarf_termfile();
void dwarf_initmodule(const(char) *filename, const(char) *modulename);
void dwarf_termmodule();
void dwarf_func_start(Symbol *sfunc);
void dwarf_func_term(Symbol *sfunc);
uint dwarf_typidx(type *t);
uint dwarf_abbrev_code(ubyte *data, size_t nbytes);

int dwarf_regno(int reg);

void dwarf_addrel(int seg, targ_size_t offset, int targseg, targ_size_t val = 0);
int dwarf_reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val);
void dwarf_except_gentables(Funcsym *sfunc, uint startoffset, uint retoffset);
void genDwarfEh(Funcsym *sfunc, int seg, Outbuffer *et, bool scancode, uint startoffset, uint retoffset);
int dwarf_eh_frame_fixup(int seg, targ_size_t offset, Symbol *s, targ_size_t val, Symbol *seh);
