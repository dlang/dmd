/*
EXTRA_ARGS: -gdwarf=5
MIN_OBJDUMP_VERSION: 2.30

// Issue https://issues.dlang.org/show_bug.cgi?id=22855
DWARF_VERIFY: false
*/

void main()
{
    immutable(void)[] arr;
}
