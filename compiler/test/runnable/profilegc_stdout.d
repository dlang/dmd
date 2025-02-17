/*
REQUIRED_ARGS: -profile=gc
RUN_OUTPUT:
---
bytes allocated, allocations, type, function, file:line
             96	              1	ubyte profilegc_stdout.main runnable/profilegc_stdout.d:17
---
*/

import core.runtime;

void main()
{
	// test that stdout output works
	profilegc_setlogfilename("");

	ubyte[] arr = new ubyte[64];
}
