
/*
 * MyDll demonstration of how to write D DLLs.
 */

import core.stdc.stdio;
import core.stdc.stdlib;
import std.string;
import core.sys.windows.windows;
import core.memory;
import core.runtime;
import core.sys.windows.dll;

HINSTANCE g_hInst;

extern (Windows)
    BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    switch (ulReason)
    {
        case DLL_PROCESS_ATTACH:
	    printf("DLL_PROCESS_ATTACH\n");
	    dll_process_attach(hInstance);
	    //Runtime.initialize();
	    break;

        case DLL_PROCESS_DETACH:
	    printf("DLL_PROCESS_DETACH\n");
	    core.stdc.stdio._fcloseallp = null;	// so stdio doesn't get closed
	    dll_process_detach(hInstance);
	    //Runtime.terminate();
	    break;

        case DLL_THREAD_ATTACH:
	    printf("DLL_THREAD_ATTACH\n");
	    return false;

        case DLL_THREAD_DETACH:
	    printf("DLL_THREAD_DETACH\n");
	    return false;

	default:
	    assert(0);
    }

    g_hInst=hInstance;
    return true;
}

static this()
{
    printf("static this for mydll\n");
}

static ~this()
{
    printf("static ~this for mydll\n");
}

/* --------------------------------------------------------- */

class MyClass
{
    string concat(string a, string b)
    {
	return a ~ " " ~ b;
    }

    void free(string s)
    {
	delete s;
    }
}

export MyClass getMyClass()
{
    printf("getMyClass()\n");
    auto c = new MyClass();
    printf("allocated\n");
    return c;
}
