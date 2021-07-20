// https://issues.dlang.org/show_bug.cgi?id=13727

import std.array;
import std.parallelism;
import std.stdio;

void main()
{
    foreach (fn;
        ["runnable/extra-files/extra13727.txt"]
        .replicate(1000)
        .parallel
    )
    {
        // synchronized
	version (Windows)
	    string mode = "rb";
	else
	    string mode = "r";
        { File f = File(fn, mode); }
    }
}

