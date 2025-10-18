
__gshared int x = 7;
__gshared int*[70000] px = &x;

shared static this()
{
	foreach(p; px)
		assert(p && *p == 7);
}
