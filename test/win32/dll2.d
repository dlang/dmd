// Public Domain

import core.sys.windows.windows;
import core.stdc.stdlib;

version(D_Version2)
{
    import core.runtime;
    import core.memory;
version(use_patch)
    import core.sys.windows.dll;
    import core.stdc.string;

	extern (C) void _moduleTlsCtor();
	extern (C) void _moduleTlsDtor();
}
else
{
    import std.gc;
    import std.thread;

version(use_patch)
    import std.thread_helper;

    extern (C)
    {
	void gc_init();
	void gc_term();
	void _minit();
	void _moduleCtor();
	void _moduleDtor();
	void _moduleUnitTests();
    }
}

extern (Windows)
BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
    switch (ulReason)
    {
	case DLL_PROCESS_ATTACH:
version(D_Version2)
{
    version(use_patch)
    {
	    if( !dll_fixTLS( hInstance, &_tlsstart, &_tlsend, &_tls_callbacks_a, &_tls_index ) )
		return false;

	    Runtime.initialize();

	    // attach to all other threads
	    enumProcessThreads( function (uint id, void* context) {
			if( !thread_findByAddr( id ) )
			{
				thread_attachByAddr( id );
				thread_moduleTlsCtor( id );
			}
			return true;
	    }, null );
    }
    else
	    Runtime.initialize();
}
else
{
	    gc_init();			// initialize GC
	    _minit();			// initialize module list
	    _moduleCtor();		// run module constructors
	    _moduleUnitTests();		// run module unit tests

    version(use_patch)
    {
	    // attach to all other threads
	    enumProcessThreads( function (uint id, void* context) {
		if( !Thread._getThreadById( id ) )
		    Thread.thread_attach( id, OpenThreadHandle( id ), getThreadStackBottom( id ) );
		return true;
	    }, null );
    }
//	    enumThreads();
}
	    break;

	case DLL_PROCESS_DETACH:
version(D_Version2)
{
    version(use_patch)
    {
		// detach from all other threads
		enumProcessThreads(
			function (uint id, void* context) {
				if( id != GetCurrentThreadId() && thread_findByAddr( id ) )
					thread_detachByAddr( id );
				return true;
			}, null );
    }
		Runtime.terminate();
}
else
{
    version(use_patch)
    {
		// detach from all other threads
		enumProcessThreads(
			function (uint id, void* context) {
				if( id != GetCurrentThreadId() )
				{
					thread_moduleTlsDtor( id );
					Thread.thread_detach( id );
				}
				return true;
			}, null );
    }
	    _moduleDtor();
	    gc_term();			// shut down GC
}
	    break;

	case DLL_THREAD_ATTACH:
version(use_patch)
{
	version(D_Version2)
	{
			thread_attachThis();
			_moduleTlsCtor();
	}
    else
	    Thread.thread_attach();
}
	    break;

	case DLL_THREAD_DETACH:
version(use_patch)
{
	version(D_Version2)
	{
		if( thread_findByAddr( GetCurrentThreadId() ) )
			_moduleTlsDtor();
	    thread_detachThis();
	}
    else
	    Thread.thread_detach();
}
	    break;

	default:
	    assert(0);
    }
    return true;
}

