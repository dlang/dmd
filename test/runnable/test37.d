// PERMUTE_ARGS:
// REQUIRED_ARGS: -Jrunnable/extra-files

import std.stdio;

void main()
{
    writefln(import("foo37.txt"));
    // also want to ensure that we can access
    // imports in a subdirectory of the -J path
    writefln(import("std14198/uni.d"));
    // and also that paths can be dealt with properly
	// regardless of how stupid they are
    writefln(import("std14198/../std14198/uni.d"));
}
