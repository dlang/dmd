/**
 * The runtime module exposes information specific to the D runtime code.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 *
 *          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.runtime;


private
{
    extern (C) bool rt_isHalting();

    alias bool function() ModuleUnitTester;
    alias bool function(Object) CollectHandler;
    alias Throwable.TraceInfo function( void* ptr = null ) TraceHandler;

    extern (C) void rt_setCollectHandler( CollectHandler h );
    extern (C) void rt_setTraceHandler( TraceHandler h );
    extern (C) TraceHandler rt_getTraceHandler();

    alias void delegate( Throwable ) ExceptionHandler;
    extern (C) bool rt_init( ExceptionHandler dg = null );
    extern (C) bool rt_term( ExceptionHandler dg = null );

    extern (C) void* rt_loadLibrary( in char[] name );
    extern (C) bool  rt_unloadLibrary( void* ptr );
    
    version( linux )
    {
        import core.stdc.stdlib : free;
        import core.stdc.string : strlen;
        extern (C) int    backtrace(void**, size_t);
        extern (C) char** backtrace_symbols(void**, int);
        extern (C) void   backtrace_symbols_fd(void**,int,int);
        import core.sys.posix.signal; // segv handler
    }
    else version( OSX )
    {
        import core.stdc.stdlib : free;
        import core.stdc.string : strlen;
        extern (C) int    backtrace(void**, size_t);
        extern (C) char** backtrace_symbols(void**, int);
        extern (C) void   backtrace_symbols_fd(void**,int,int);
        import core.sys.posix.signal; // segv handler
    }
}


static this()
{
    // NOTE: Some module ctors will run before this handler is set, so it's
    //       still possible the app could exit without a stack trace.  If
    //       this becomes an issue, the handler could be set in C main
    //       before the module ctors are run.
    Runtime.traceHandler = &defaultTraceHandler;
}


///////////////////////////////////////////////////////////////////////////////
// Runtime
///////////////////////////////////////////////////////////////////////////////


/**
 * This struct encapsulates all functionality related to the underlying runtime
 * module for the calling context.
 */
struct Runtime
{
    /**
     * Initializes the runtime.  This call is to be used in instances where the
     * standard program initialization process is not executed.  This is most
     * often in shared libraries or in libraries linked to a C program.
     *
     * Params:
     *  dg = A delegate which will receive any exception thrown during the
     *       initialization process or null if such exceptions should be
     *       discarded.
     *
     * Returns:
     *  true if initialization succeeds and false if initialization fails.
     */
    static bool initialize( ExceptionHandler dg = null )
    {
        return rt_init( dg );
    }


    /**
     * Terminates the runtime.  This call is to be used in instances where the
     * standard program termination process will not be not executed.  This is
     * most often in shared libraries or in libraries linked to a C program.
     *
     * Params:
     *  dg = A delegate which will receive any exception thrown during the
     *       termination process or null if such exceptions should be
     *       discarded.
     *
     * Returns:
     *  true if termination succeeds and false if termination fails.
     */
    static bool terminate( ExceptionHandler dg = null )
    {
        return rt_term( dg );
    }


    /**
     * Returns true if the runtime is halting.  Under normal circumstances,
     * this will be set between the time that normal application code has
     * exited and before module dtors are called.
     *
     * Returns:
     *  true if the runtime is halting.
     */
    static bool isHalting()
    {
        return rt_isHalting();
    }


    /**
     * Locates a dynamic library with the supplied library name and dynamically
     * loads it into the caller's address space.  If the library contains a D
     * runtime it will be integrated with the current runtime.
     *
     * Params:
     *  name = The name of the dynamic library to load.
     *
     * Returns:
     *  A reference to the library or null on error.
     */
    static void* loadLibrary( in char[] name )
    {
        return rt_loadLibrary( name );
    }


    /**
     * Unloads the dynamic library referenced by p.  If this library contains a
     * D runtime then any necessary finalization or cleanup of that runtime
     * will be performed.
     *
     * Params:
     *  p = A reference to the library to unload.
     */
    static bool unloadLibrary( void* p )
    {
        return rt_unloadLibrary( p );
    }


    /**
     * Overrides the default trace mechanism with s user-supplied version.  A
     * trace represents the context from which an exception was thrown, and the
     * trace handler will be called when this occurs.  The pointer supplied to
     * this routine indicates the base address from which tracing should occur.
     * If the supplied pointer is null then the trace routine should determine
     * an appropriate calling context from which to begin the trace.
     *
     * Params:
     *  h = The new trace handler.  Set to null to use the default handler.
     */
    static void traceHandler( TraceHandler h )
    {
        rt_setTraceHandler( h );
    }

    /**
     * Return the current trace handler
     */
    static TraceHandler traceHandler()
    {
        return rt_getTraceHandler();
    }

    /**
     * Overrides the default collect hander with a user-supplied version.  This
     * routine will be called for each resource object that is finalized in a
     * non-deterministic manner--typically during a garbage collection cycle.
     * If the supplied routine returns true then the object's dtor will called
     * as normal, but if the routine returns false than the dtor will not be
     * called.  The default behavior is for all object dtors to be called.
     *
     * Params:
     *  h = The new collect handler.  Set to null to use the default handler.
     */
    static void collectHandler( CollectHandler h )
    {
        rt_setCollectHandler( h );
    }


    /**
     * Overrides the default module unit tester with a user-supplied version.
     * This routine will be called once on program initialization.  The return
     * value of this routine indicates to the runtime whether the body of the
     * program will be executed.
     *
     * Params:
     *  h = The new unit tester.  Set to null to use the default unit tester.
     */
    static void moduleUnitTester( ModuleUnitTester h )
    {
        sm_moduleUnitTester = h;
    }


private:
    // NOTE: This field will only ever be set in a static ctor and should
    //       never occur within any but the main thread, so it is safe to
    //       make it __gshared.
    __gshared ModuleUnitTester sm_moduleUnitTester = null;
}


///////////////////////////////////////////////////////////////////////////////
// Overridable Callbacks
///////////////////////////////////////////////////////////////////////////////


/**
 * This routine is called by the runtime to run module unit tests on startup.
 * The user-supplied unit tester will be called if one has been supplied,
 * otherwise all unit tests will be run in sequence.
 *
 * Returns:
 *  true if execution should continue after testing is complete and false if
 *  not.  Default behavior is to return true.
 */
extern (C) bool runModuleUnitTests()
{
    static if( __traits( compiles, backtrace ) )
    {
        static extern (C) void unittestSegvHandler( int signum, siginfo_t* info, void* ptr )
        {
            static enum MAXFRAMES = 128;
            void*[MAXFRAMES]  callstack;
            int               numframes;

            numframes = backtrace( callstack, MAXFRAMES );
            backtrace_symbols_fd( callstack, numframes, 2 );
        }

        sigaction_t action = void;
        sigaction_t oldseg = void;
        sigaction_t oldbus = void;
        
        (cast(byte*) &action)[0 .. action.sizeof] = 0;
        sigfillset( &action.sa_mask ); // block other signals
        action.sa_flags = SA_SIGINFO | SA_RESETHAND;
        action.sa_sigaction = &unittestSegvHandler;
        sigaction( SIGSEGV, &action, &oldseg );
        sigaction( SIGBUS, &action, &oldbus );
        scope( exit )
        {
            sigaction( SIGSEGV, &oldseg, null );
            sigaction( SIGBUS, &oldbus, null );
        }
    }

    if( Runtime.sm_moduleUnitTester is null )
    {
        foreach( m; ModuleInfo )
        {
            if( m )
            {
                auto fp = m.unitTest;
                
                if( fp )
                    fp();
            }
        }
        return true;
    }
    return Runtime.sm_moduleUnitTester();
}


///////////////////////////////////////////////////////////////////////////////
// Default Implementations
///////////////////////////////////////////////////////////////////////////////


/** 
 *
 */
Throwable.TraceInfo defaultTraceHandler( void* ptr = null )
{
    static if( __traits( compiles, backtrace ) )
    {
        class DefaultTraceInfo : Throwable.TraceInfo
        {
            this()
            {
                static enum MAXFRAMES = 128;
                void*[MAXFRAMES]  callstack;

                numframes = backtrace( callstack, MAXFRAMES );
                framelist = backtrace_symbols( callstack, numframes );
            }
            
            ~this()
            {
                free( framelist );
            }
            
            int opApply( scope int delegate(ref char[]) dg )
            {
                // NOTE: The first 5 frames with the current implementation are
                //       inside core.runtime and the object code, so eliminate
                //       these for readability.  The alternative would be to
                //       exclude the first N frames that have a prefix of:
                //          "D4core7runtime19defaultTraceHandler"
                //          "D6object12traceContext"
                //          "D6object9Throwable6__ctor"
                //          "D6object9Exception6__ctor"
                static enum FIRSTFRAME = 5;
                int ret = 0;

                for( int i = FIRSTFRAME; i < numframes; ++i )
                {
                    ret = dg( framelist[i][0 .. strlen(framelist[i])] );
                    if( ret )
                        break;
                }
                return ret;
            }
        
        private:
            int     numframes; 
            char**  framelist;
        }
        
        return new DefaultTraceInfo;
    }
    else
    {
        return null;
    }
}
