// PERMUTE_ARGS:
// EXTRA_SOURCES: import/test1imp.d

class File
{
    import imports.test1imp;

    static char[] read(char[] name)
    {
	DWORD size;	// DWORD is defined in test1imp
	return null;
    }

}
