module mydll2;

import std.stdio;

version(D_Version2)
{
	import core.memory;
}
else
{
	import std.gc;
}

export void dllprint() 
{
	writefln("hello dll world"); 
}

int glob;


// test access to (tls) globals
export int getglob() 
{
	return glob;
}

// test gc-mem-allocation from different threads
export char* alloc(int sz) 
{
	char* p = (new char[sz]).ptr;
version(D_Version2)
	GC.addRange(p, sz);
else
	addRange(p, p + sz);

	return p;
}

export void free(char* p, int sz) 
{
version(D_Version2)
	GC.removeRange(p);
else
	removeRange(p);

	// delete p;
}

export __gshared int globvar;
