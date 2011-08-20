/**
 * The runtime module exposes information specific to the D runtime code.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/_runtime.d)
 */

/*          Copyright Sean Kelly 2005 - 2009.
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
    alias Throwable.TraceInfo function( void* ptr ) TraceHandler;

    extern (C) void rt_setCollectHandler( CollectHandler h );
    extern (C) CollectHandler rt_getCollectHandler();

    extern (C) void rt_setTraceHandler( TraceHandler h );
    extern (C) TraceHandler rt_getTraceHandler();

    alias void delegate( Throwable ) ExceptionHandler;
    extern (C) bool rt_init( ExceptionHandler dg = null );
    extern (C) bool rt_term( ExceptionHandler dg = null );

    extern (C) void* rt_loadLibrary( in char[] name );
    extern (C) bool  rt_unloadLibrary( void* ptr );

    extern (C) string[] rt_args();

    version( linux )
    {
        import core.demangle;
        import core.stdc.stdlib : free;
        import core.stdc.string : strlen, memchr;
        extern (C) int    backtrace(void**, int);
        extern (C) char** backtrace_symbols(void**, int);
        extern (C) void   backtrace_symbols_fd(void**, int, int);
        import core.sys.posix.signal; // segv handler
    }
    else version( OSX )
    {
        import core.demangle;
        import core.stdc.stdlib : free;
        import core.stdc.string : strlen;
        extern (C) int    backtrace(void**, int);
        extern (C) char** backtrace_symbols(void**, int);
        extern (C) void   backtrace_symbols_fd(void**, int, int);
        import core.sys.posix.signal; // segv handler
    }
    else version( Windows )
    {
        import core.sys.windows.stacktrace;
    }

    // For runModuleUnitTests error reporting.
    version( Windows )
    {
        import core.sys.windows.windows;
    }
    else version( Posix )
    {
        import core.sys.posix.unistd;
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
    deprecated static @property bool isHalting()
    {
        return rt_isHalting();
    }


    /**
     * Returns the arguments supplied when the process was started.
     *
     * Returns:
     *  The arguments supplied when this process was started.
     */
    static @property string[] args()
    {
        return rt_args();
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
    static @property void traceHandler( TraceHandler h )
    {
        rt_setTraceHandler( h );
    }

    /**
     * Gets the current trace handler.
     *
     * Returns:
     *  The current trace handler or null if no trace handler is set.
     */
    static @property TraceHandler traceHandler()
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
    static @property void collectHandler( CollectHandler h )
    {
        rt_setCollectHandler( h );
    }


    /**
     * Gets the current collect handler.
     *
     * Returns:
     *  The current collect handler or null if no trace handler is set.
     */
    static @property CollectHandler collectHandler()
    {
        return rt_getCollectHandler();
    }


    /**
     * Overrides the default module unit tester with a user-supplied version.
     * This routine will be called once on program initialization.  The return
     * value of this routine indicates to the runtime whether the tests ran
     * without error.
     *
     * Params:
     *  h = The new unit tester.  Set to null to use the default unit tester.
     */
    static @property void moduleUnitTester( ModuleUnitTester h )
    {
        sm_moduleUnitTester = h;
    }


    /**
     * Gets the current module unit tester.
     *
     * Returns:
     *  The current module unit tester handler or null if no trace handler is
     *  set.
     */
    static @property ModuleUnitTester moduleUnitTester()
    {
        return sm_moduleUnitTester;
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

    static struct Console
    {
        Console opCall( in char[] val )
        {
            version( Windows )
            {
                uint count = void;
                WriteFile( GetStdHandle( 0xfffffff5 ), val.ptr, val.length, &count, null );
            }
            else version( Posix )
            {
                write( 2, val.ptr, val.length );
            }
            return this;
        }
    }

    static __gshared Console console;

    if( Runtime.sm_moduleUnitTester is null )
    {
        size_t failed = 0;
        foreach( m; ModuleInfo )
        {
            if( m )
            {
                auto fp = m.unitTest;

                if( fp )
                {
                    try
                    {
                        fp();
                    }
                    catch( Throwable e )
                    {
                        console( e.toString() )( "\n" );
                        failed++;
                    }
                }
            }
        }
        return failed == 0;
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

            override int opApply( scope int delegate(ref char[]) dg )
            {
                return opApply( (ref size_t, ref char[] buf)
                                {
                                    return dg( buf );
                                } );
            }

            override int opApply( scope int delegate(ref size_t, ref char[]) dg )
            {
                version( Posix )
                {
                    // NOTE: The first 5 frames with the current implementation are
                    //       inside core.runtime and the object code, so eliminate
                    //       these for readability.  The alternative would be to
                    //       exclude the first N frames that are in a list of
                    //       mangled function names.
                    static enum FIRSTFRAME = 5;
                }
                else
                {
                    // NOTE: On Windows, the number of frames to exclude is based on
                    //       whether the exception is user or system-generated, so
                    //       it may be necessary to exclude a list of function names
                    //       instead.
                    static enum FIRSTFRAME = 0;
                }
                int ret = 0;

                for( int i = FIRSTFRAME; i < numframes; ++i )
                {
                    auto buf = framelist[i][0 .. strlen(framelist[i])];
                    auto pos = cast(size_t)(i - FIRSTFRAME);
                    buf = fixline( buf );
                    ret = dg( pos, buf );
                    if( ret )
                        break;
                }
                return ret;
            }

            override string toString()
            {
                string buf;
                foreach( i, line; this )
                    buf ~= i ? "\n" ~ line : line;
                return buf;
            }

        private:
            int     numframes;
            char**  framelist;

        private:
            char[4096] fixbuf;
            char[] fixline( char[] buf )
            {
                version( OSX )
                {
                    // format is:
                    //  1  module    0x00000000 D6module4funcAFZv + 0
                    for( size_t i = 0, n = 0; i < buf.length; i++ )
                    {
                        if( ' ' == buf[i] )
                        {
                            n++;
                            while( i < buf.length && ' ' == buf[i] )
                                i++;
                            if( 3 > n )
                                continue;
                            auto bsym = i;
                            while( i < buf.length && ' ' != buf[i] )
                                i++;
                            auto esym = i;
                            auto tail = buf.length - esym;
                            fixbuf[0 .. bsym] = buf[0 .. bsym];
                            auto m = demangle( buf[bsym .. esym], fixbuf[bsym .. $] );
                            fixbuf[bsym + m.length .. bsym + m.length + tail] = buf[esym .. $];
                            return fixbuf[0 .. bsym + m.length + tail];
                        }
                    }
                    return buf;
                }
                else version( linux )
                {
                    // format is:
                    // module(_D6module4funcAFZv) [0x00000000]
                    auto bptr = cast(char*) memchr( buf.ptr, '(', buf.length );
                    auto eptr = cast(char*) memchr( buf.ptr, ')', buf.length );

                    if( bptr++ && eptr )
                    {
                        size_t bsym = bptr - buf.ptr;
                        size_t esym = eptr - buf.ptr;
                        auto tail = buf.length - esym;
                        fixbuf[0 .. bsym] = buf[0 .. bsym];
                        auto m = demangle( buf[bsym .. esym], fixbuf[bsym .. $] );
                        fixbuf[bsym + m.length .. bsym + m.length + tail] = buf[esym .. $];
                        return fixbuf[0 .. bsym + m.length + tail];
                    }
                    return buf;
                }
                else
                {
                    return buf;
                }
            }
        }

        return new DefaultTraceInfo;
    }
    else static if( __traits( compiles, new StackTrace ) )
    {
        return new StackTrace;
    }
    else
    {
        return null;
    }
}
