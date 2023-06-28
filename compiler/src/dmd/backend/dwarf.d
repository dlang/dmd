/**
 * Definitions for DWARF debug infos (v3 to v5)
 *
 * See_Also:
 *  - $(LINK2 https://www.dwarfstd.org/doc/Dwarf3.pdf, DWARFv3 standard)
 *  - $(LINK2 https://www.dwarfstd.org/doc/DWARF4.pdf, DWARFv4 standard)
 *  - $(LINK2 https://www.dwarfstd.org/doc/DWARF5.pdf, DWARFv5 standard)
 * Source: $(DMDSRC backend/_dwarf.d)
 */

module dmd.backend.dwarf;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.type;
import dmd.backend.dwarfeh : DwEhTable;

import dmd.common.outbuffer;

public import dmd.backend.dwarfeh : genDwarfEh;
public import dmd.backend.dwarfdbginf : dwarf_initfile, dwarf_termfile, dwarf_initmodule,
    dwarf_termmodule, dwarf_func_start, dwarf_func_term, dwarf_typidx, dwarf_abbrev_code,
    dwarf_regno, dwarf_addrel;
public import dmd.backend.elfobj : elf_dwarf_reftoident;
public import dmd.backend.machobj : mach_dwarf_reftoident, dwarf_eh_frame_fixup;
