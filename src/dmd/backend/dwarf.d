/**
 * Definitions for DWARF debug infos (v3 to v5)
 *
 * See_Also:
 *  - $(LINK2 http://www.dwarfstd.org/doc/Dwarf3.pdf, DWARFv3 standard)
 *  - $(LINK2 http://www.dwarfstd.org/doc/DWARF4.pdf, DWARFv4 standard)
 *  - $(LINK2 http://www.dwarfstd.org/doc/DWARF5.pdf, DWARFv5 standard)
 * Source: $(DMDSRC backend/_dwarf.d)
 */

module dmd.backend.dwarf;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.outbuf;
import dmd.backend.type;

extern (C++):

nothrow:
@safe
{
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
int mach_dwarf_reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val);
int elf_dwarf_reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val);
void dwarf_except_gentables(Funcsym *sfunc, uint startoffset, uint retoffset);
void genDwarfEh(Funcsym *sfunc, int seg, Outbuffer *et, bool scancode, uint startoffset, uint retoffset);
int dwarf_eh_frame_fixup(int seg, targ_size_t offset, Symbol *s, targ_size_t val, Symbol *seh);
}
