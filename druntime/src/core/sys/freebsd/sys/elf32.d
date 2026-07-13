/**
 * D header file for FreeBSD.
 *
 * $(LINK2 http://svnweb.freebsd.org/base/head/sys/sys/elf32.h?view=markup, sys/elf32.h)
 */
module core.sys.freebsd.sys.elf32;

version (FreeBSD):
extern (C):
pure:
nothrow:

import core.stdc.stdint;
public import core.sys.freebsd.sys.elf_common;

alias Elf32_Lword = uint64_t;
alias Elf32_Hashelt = Elf32_Word;
alias Elf32_Size = Elf32_Word;
alias Elf32_Ssize = Elf32_Sword;

struct Elf32_Dyn
{
  Elf32_Sword   d_tag;
  union _d_un
  {
      Elf32_Word d_val;
      Elf32_Addr d_ptr;
  } _d_un d_un;
}

alias Elf32_Nhdr = Elf_Note;

struct Elf32_Cap
{
    Elf32_Word    c_tag;
    union _c_un
    {
        Elf32_Word      c_val;
        Elf32_Addr      c_ptr;
    } _c_un c_un;
}

extern (D)
{
    auto ELF32_ST_VISIBILITY(O)(O o) { return o & 0x03; }
}
