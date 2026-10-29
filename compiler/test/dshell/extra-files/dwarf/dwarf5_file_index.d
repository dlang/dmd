/*
EXTRA_ARGS: -gdwarf=5
MIN_OBJDUMP_VERSION: 2.35

// Issue https://issues.dlang.org/show_bug.cgi?id=22855
DWARF_VERIFY: false
*/

// In DWARF 5, the file_names table of the line number program is 0-based,
// with entry 0 being the primary source file.
// `DW_LNS_set_file` and `DW_AT_decl_file` must use 0-based indices.

void main()
{
    int x = 42;
}
