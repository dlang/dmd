/**
 * D header file for FreeBSD.
 *
 * $(LINK2 http://svnweb.freebsd.org/base/head/sys/sys/elf64.h?view=markup, sys/elf64.h)
 */
module core.sys.freebsd.sys.elf64;

version (FreeBSD):
extern (C):
pure:
nothrow:

import core.stdc.stdint;
public import core.sys.freebsd.sys.elf_common;

alias Elf64_Lword = uint64_t;
alias Elf64_Hashelt = Elf64_Word;
alias Elf64_Size = Elf64_Xword;
alias Elf64_Ssize = Elf64_Sxword;

struct Elf64_Dyn
{
  Elf64_Sxword  d_tag;
  union _d_un
  {
      Elf64_Xword d_val;
      Elf64_Addr d_ptr;
  } _d_un d_un;
}

extern (D)
{
    auto ELF64_R_TYPE_DATA(I)(I i) { return (cast(Elf64_Xword) i << 32) >> 40; }
    auto ELF64_R_TYPE_ID(I)(I i) { return (cast(Elf64_Xword) i << 56 ) >> 56; }
    auto ELF64_R_TYPE_INFO(D, T)(D d, T t) { return cast(Elf64_Xword) d << 8 + cast(Elf64_Xword) t; }
}

alias Elf64_Nhdr = Elf_Note;

struct Elf64_Cap
{
    Elf64_Xword   c_tag;
    union _c_un
    {
        Elf64_Xword     c_val;
        Elf64_Addr      c_ptr;
    } _c_un c_un;
}

extern (D)
{
    auto ELF64_ST_VISIBILITY(O)(O o) { return o & 0x03; }
}
