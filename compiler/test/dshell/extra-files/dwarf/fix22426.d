/*
EXTRA_ARGS: -gdwarf=5 -main

// Issue https://issues.dlang.org/show_bug.cgi?id=22855
DWARF_VERIFY: false
*/

noreturn noret()
{
	assert(0);
}
