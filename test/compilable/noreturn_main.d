/*
https://issues.dlang.org/show_bug.cgi?id=22113
Allow main to return noreturn.

ARG_SETS: -version=Use_D_Main
ARG_SETS: -version=Use_C_Main
ARG_SETS: -version=Use_Extended_C_Main
ARG_SETS(windows64): -version=Use_Win_Main
ARG_SETS(windows64): -version=Use_Dll_Main -shared

LINK:
*/

// import core.stdc.stdio;

version (Use_D_Main)
noreturn main()
{
	// puts("Hello, World!");
	assert(false);
}

version (Use_C_Main)
extern(C) noreturn main(int argc, const char** argv)
{
	// puts("Hello, World!");
	assert(false);
}

version (Use_Extended_C_Main)
extern(C) noreturn main(int argc, const char** argv, const char** env)
{
	// puts("Hello, World!");
	assert(false);
}

version (Use_Win_Main)
{
	import core.sys.windows.windef;

	extern(Windows)
	noreturn WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
	{
		// puts("Hello, World!");
		assert(false);
	}
}

version (Use_Dll_Main)
{
	import core.sys.windows.windef;

	extern (Windows)
	noreturn DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
	{
		// puts("Hello, World!");
		assert(false);
	}
}
