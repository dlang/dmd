/**
 * The thread module provides support for thread creation and management.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly, Walter Bright
 * Source:    $(DRUNTIMESRC core/_thread.d)
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 * Source: $(LINK http://www.dsource.org/projects/druntime/browser/trunk/src/core/thread.d)
 */
module core.thread;


public import core.time; // for Duration


// this should be true for most architectures
version = StackGrowsDown;

/**
 * Returns the process ID of the calling process, which is guaranteed to be
 * unique on the system. This call is always successful.
 *
 * Example:
 * ---
 * writefln("Current process id: %s", getpid());
 * ---
 */
version(Posix)
{
    import core.sys.posix.unistd;
    alias core.sys.posix.unistd.getpid getpid;
}
else version (Windows)
{
    import core.sys.windows.windows;
    alias core.sys.windows.windows.GetCurrentProcessId getpid;
}


///////////////////////////////////////////////////////////////////////////////
// Thread and Fiber Exceptions
///////////////////////////////////////////////////////////////////////////////


/**
 * Base class for thread exceptions.
 */
class ThreadException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null);
    this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__);
}


/**
 * Base class for fiber exceptions.
 */
class FiberException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null);
    this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__);
}


///////////////////////////////////////////////////////////////////////////////
// Thread
///////////////////////////////////////////////////////////////////////////////


/**
 * This class encapsulates all threading functionality for the D
 * programming language.  As thread manipulation is a required facility
 * for garbage collection, all user threads should derive from this
 * class, and instances of this class should never be explicitly deleted.
 * A new thread may be created using either derivation or composition, as
 * in the following example.
 *
 * Example:
 * ----------------------------------------------------------------------------
 *
 * class DerivedThread : Thread
 * {
 *     this()
 *     {
 *         super( &run );
 *     }
 *
 * private :
 *     void run()
 *     {
 *         printf( "Derived thread running.\n" );
 *     }
 * }
 *
 * void threadFunc()
 * {
 *     printf( "Composed thread running.\n" );
 * }
 *
 * // create instances of each type
 * Thread derived = new DerivedThread();
 * Thread composed = new Thread( &threadFunc );
 *
 * // start both threads
 * derived.start();
 * composed.start();
 *
 * ----------------------------------------------------------------------------
 */
class Thread
{
    ///////////////////////////////////////////////////////////////////////////
    // Initialization
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Initializes a thread object which is associated with a static
     * D function.
     *
     * Params:
     *  fn = The thread function.
     *  sz = The stack size for this thread.
     *
     * In:
     *  fn must not be null.
     */
    this( void function() fn, size_t sz = 0 );


    /**
     * Initializes a thread object which is associated with a dynamic
     * D function.
     *
     * Params:
     *  dg = The thread function.
     *  sz = The stack size for this thread.
     *
     * In:
     *  dg must not be null.
     */
    this( void delegate() dg, size_t sz = 0 );


    /**
     * Cleans up any remaining resources used by this object.
     */
    ~this();


    ///////////////////////////////////////////////////////////////////////////
    // General Actions
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Starts the thread and invokes the function or delegate passed upon
     * construction.
     *
     * In:
     *  This routine may only be called once per thread instance.
     *
     * Throws:
     *  ThreadException if the thread fails to start.
     */
    final void start();


    /**
     * Waits for this thread to complete.  If the thread terminated as the
     * result of an unhandled exception, this exception will be rethrown.
     *
     * Params:
     *  rethrow = Rethrow any unhandled exception which may have caused this
     *            thread to terminate.
     *
     * Throws:
     *  ThreadException if the operation fails.
     *  Any exception not handled by the joined thread.
     *
     * Returns:
     *  Any exception not handled by this thread if rethrow = false, null
     *  otherwise.
     */
    final Throwable join( bool rethrow = true );


    ///////////////////////////////////////////////////////////////////////////
    // General Properties
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Gets the user-readable label for this thread.
     *
     * Returns:
     *  The name of this thread.
     */
    final @property string name();


    /**
     * Sets the user-readable label for this thread.
     *
     * Params:
     *  val = The new name of this thread.
     */
    final @property void name( string val );


    /**
     * Gets the daemon status for this thread.  While the runtime will wait for
     * all normal threads to complete before tearing down the process, daemon
     * threads are effectively ignored and thus will not prevent the process
     * from terminating.  In effect, daemon threads will be terminated
     * automatically by the OS when the process exits.
     *
     * Returns:
     *  true if this is a daemon thread.
     */
    final @property bool isDaemon();


    /**
     * Sets the daemon status for this thread.  While the runtime will wait for
     * all normal threads to complete before tearing down the process, daemon
     * threads are effectively ignored and thus will not prevent the process
     * from terminating.  In effect, daemon threads will be terminated
     * automatically by the OS when the process exits.
     *
     * Params:
     *  val = The new daemon status for this thread.
     */
    final @property void isDaemon( bool val );


    /**
     * Tests whether this thread is running.
     *
     * Returns:
     *  true if the thread is running, false if not.
     */
    final @property bool isRunning();


    ///////////////////////////////////////////////////////////////////////////
    // Thread Priority Actions
    ///////////////////////////////////////////////////////////////////////////


    /**
     * The minimum scheduling priority that may be set for a thread.  On
     * systems where multiple scheduling policies are defined, this value
     * represents the minimum valid priority for the scheduling policy of
     * the process.
     */
    __gshared const int PRIORITY_MIN;


    /**
     * The maximum scheduling priority that may be set for a thread.  On
     * systems where multiple scheduling policies are defined, this value
     * represents the minimum valid priority for the scheduling policy of
     * the process.
     */
    __gshared const int PRIORITY_MAX;


    /**
     * Gets the scheduling priority for the associated thread.
     *
     * Returns:
     *  The scheduling priority of this thread.
     */
    final @property int priority();


    /**
     * Sets the scheduling priority for the associated thread.
     *
     * Params:
     *  val = The new scheduling priority of this thread.
     */
    final @property void priority( int val );


    ///////////////////////////////////////////////////////////////////////////
    // Actions on Calling Thread
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Suspends the calling thread for at least the supplied period.  This may
     * result in multiple OS calls if period is greater than the maximum sleep
     * duration supported by the operating system.
     *
     * Params:
     *  val = The minimum duration the calling thread should be suspended.
     *
     * In:
     *  period must be non-negative.
     *
     * Example:
     * ------------------------------------------------------------------------
     *
     * Thread.sleep( dur!("msecs")( 50 ) );  // sleep for 50 milliseconds
     * Thread.sleep( dur!("seconds")( 5 ) ); // sleep for 5 seconds
     *
     * ------------------------------------------------------------------------
     */
    static void sleep( Duration val );


    /**
     * $(RED Scheduled for deprecation in January 2012. Please use the version
     *       which takes a $(D Duration) instead.)
     *
     * Suspends the calling thread for at least the supplied period.  This may
     * result in multiple OS calls if period is greater than the maximum sleep
     * duration supported by the operating system.
     *
     * Params:
     *  period = The minimum duration the calling thread should be suspended,
     *           in 100 nanosecond intervals.
     *
     * In:
     *  period must be non-negative.
     *
     * Example:
     * ------------------------------------------------------------------------
     *
     * Thread.sleep( 500_000 );    // sleep for 50 milliseconds
     * Thread.sleep( 50_000_000 ); // sleep for 5 seconds
     *
     * ------------------------------------------------------------------------
     */
    static void sleep( long period );


    /**
     * Forces a context switch to occur away from the calling thread.
     */
    static void yield();


    ///////////////////////////////////////////////////////////////////////////
    // Thread Accessors
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Provides a reference to the calling thread.
     *
     * Returns:
     *  The thread object representing the calling thread.  The result of
     *  deleting this object is undefined.
     */
    static Thread getThis();


    /**
     * Provides a list of all threads currently being tracked by the system.
     *
     * Returns:
     *  An array containing references to all threads currently being
     *  tracked by the system.  The result of deleting any contained
     *  objects is undefined.
     */
    static Thread[] getAll();


    /**
     * Operates on all threads currently being tracked by the system.  The
     * result of deleting any Thread object is undefined.
     *
     * Params:
     *  dg = The supplied code as a delegate.
     *
     * Returns:
     *  Zero if all elemented are visited, nonzero if not.
     */
    static int opApply( scope int delegate( ref Thread ) dg );


    ///////////////////////////////////////////////////////////////////////////
    // Static Initalizer
    ///////////////////////////////////////////////////////////////////////////


    /**
     * This initializer is used to set thread constants.  All functional
     * initialization occurs within thread_init().
     */
    shared static this();


    ///////////////////////////////////////////////////////////////////////////
    // Stuff That Should Go Away
    ///////////////////////////////////////////////////////////////////////////


    deprecated alias thread_findByAddr findThread;


private:
    //
    // Standard types
    //
    version( Windows )
    {
        alias uint TLSKey;
        alias uint ThreadAddr;
    }
    else version( Posix )
    {
        import core.sys.posix.pthread;
        alias pthread_key_t TLSKey;
        alias pthread_t     ThreadAddr;
    }

    // These must be kept in sync with core/thread.d
    version (D_LP64)
    {
        version (Windows)      enum ThreadSize = 312;
        else version (OSX)     enum ThreadSize = 320;
        else version (Posix)   enum ThreadSize = 184;
        else static assert(0, "Platform not supported.");
    }
    else
    {
        static assert((void*).sizeof == 4); // 32-bit

        version (Windows)      enum ThreadSize = 128;
        else version (OSX)     enum ThreadSize = 128;
        else version (Posix)   enum ThreadSize =  92;
        else static assert(0, "Platform not supported.");
    }

    void data[ThreadSize - __traits(classInstanceSize, Object)] = void;
}


///////////////////////////////////////////////////////////////////////////////
// GC Support Routines
///////////////////////////////////////////////////////////////////////////////


/**
 * Initializes the thread module.  This function must be called by the
 * garbage collector on startup and before any other thread routines
 * are called.
 */
extern (C) void thread_init();


/**
 *
 */
extern (C) bool thread_isMainThread();


/**
 * Registers the calling thread for use with the D Runtime.  If this routine
 * is called for a thread which is already registered, the result is undefined.
 */
extern (C) Thread thread_attachThis();


version( Windows )
{
    // NOTE: These calls are not safe on Posix systems that use signals to
    //       perform garbage collection.  The suspendHandler uses getThis()
    //       to get the thread handle so getThis() must be a simple call.
    //       Mutexes can't safely be acquired inside signal handlers, and
    //       even if they could, the mutex needed (Thread.slock) is held by
    //       thread_suspendAll().  So in short, these routines will remain
    //       Windows-specific.  If they are truly needed elsewhere, the
    //       suspendHandler will need a way to call a version of getThis()
    //       that only does the TLS lookup without the fancy fallback stuff.

    /// ditto
    extern (C) Thread thread_attachByAddr( Thread.ThreadAddr addr );

    /// ditto
    extern (C) Thread thread_attachByAddrB( Thread.ThreadAddr addr, void* bstack );

    /// This should be handled automatically by thread_attach.
    deprecated extern (C) void thread_setNeedLock( bool need ) nothrow;

    /// Renamed to be more consistent with other extern (C) routines.
    deprecated alias thread_attachByAddr thread_attach;

    /// ditto
    deprecated alias thread_detachByAddr thread_detach;
}


/**
 * Deregisters the calling thread from use with the runtime.  If this routine
 * is called for a thread which is not registered, the result is undefined.
 */
extern (C) void thread_detachThis();


/// ditto
extern (C) void thread_detachByAddr( Thread.ThreadAddr addr );


/**
 * Search the list of all threads for a thread with the given thread identifier.
 *
 * Params:
 *  addr = The thread identifier to search for.
 * Returns:
 *  The thread object associated with the thread identifier, null if not found.
 */
static Thread thread_findByAddr( Thread.ThreadAddr addr );


/**
 * Joins all non-daemon threads that are currently running.  This is done by
 * performing successive scans through the thread list until a scan consists
 * of only daemon threads.
 */
extern (C) void thread_joinAll();


/**
 * Performs intermediate shutdown of the thread module.
 */
shared static ~this();


/**
 * This function is used to determine whether the the process is
 * multi-threaded.  Optimizations may only be performed on this
 * value if the programmer can guarantee that no path from the
 * enclosed code will start a thread.
 *
 * Returns:
 *  True if Thread.start() has been called in this process.
 */
extern (C) bool thread_needLock() nothrow;


/**
 * Suspend all threads but the calling thread for "stop the world" garbage
 * collection runs.  This function may be called multiple times, and must
 * be followed by a matching number of calls to thread_resumeAll before
 * processing is resumed.
 *
 * Throws:
 *  ThreadException if the suspend operation fails for a running thread.
 */
extern (C) void thread_suspendAll();


/**
 * Resume all threads but the calling thread for "stop the world" garbage
 * collection runs.  This function must be called once for each preceding
 * call to thread_suspendAll before the threads are actually resumed.
 *
 * In:
 *  This routine must be preceded by a call to thread_suspendAll.
 *
 * Throws:
 *  ThreadException if the resume operation fails for a running thread.
 */
extern (C) void thread_resumeAll();


enum ScanType
{
    stack,
    tls,
}

alias void delegate(void*, void*) ScanAllThreadsFn;
alias void delegate(ScanType, void*, void*) ScanAllThreadsTypeFn;

/**
 * The main entry point for garbage collection.  The supplied delegate
 * will be passed ranges representing both stack and register values.
 *
 * Params:
 *  scan        = The scanner function.  It should scan from p1 through p2 - 1.
 *  curStackTop = An optional pointer to the top of the calling thread's stack.
 *
 * In:
 *  This routine must be preceded by a call to thread_suspendAll.
 */
extern (C) void thread_scanAllType( scope ScanAllThreadsTypeFn scan, void* curStackTop = null );


/**
 * The main entry point for garbage collection.  The supplied delegate
 * will be passed ranges representing both stack and register values.
 *
 * Params:
 *  scan        = The scanner function.  It should scan from p1 through p2 - 1.
 *  curStackTop = An optional pointer to the top of the calling thread's stack.
 *
 * In:
 *  This routine must be preceded by a call to thread_suspendAll.
 */
extern (C) void thread_scanAll( scope ScanAllThreadsFn scan, void* curStackTop = null );

enum IsMarked : int
{
         no,
        yes,
    unknown, // memory is not managed by GC
}

alias IsMarked delegate( void* addr ) IsMarkedDg;

/**
 * This routine allows the runtime to process any special per-thread handling
 * for the GC.  This is needed for taking into account any memory that is
 * referenced by non-scanned pointers but is about to be freed.  That currently
 * means the array append cache.
 *
 * Params:
 *  hasMarks = The probe function. It should return true for pointers into marked memory blocks.
 *
 * In:
 *  This routine must be called just prior to resuming all threads.
 */
extern(C) void thread_processGCMarks( scope IsMarkedDg isMarked );


/**
 *
 */
extern (C) void* thread_stackBottom();


///////////////////////////////////////////////////////////////////////////////
// Thread Group
///////////////////////////////////////////////////////////////////////////////


/**
 * This class is intended to simplify certain common programming techniques.
 */
class ThreadGroup
{
    /**
     * Creates and starts a new Thread object that executes fn and adds it to
     * the list of tracked threads.
     *
     * Params:
     *  fn = The thread function.
     *
     * Returns:
     *  A reference to the newly created thread.
     */
    final Thread create( void function() fn );


    /**
     * Creates and starts a new Thread object that executes dg and adds it to
     * the list of tracked threads.
     *
     * Params:
     *  dg = The thread function.
     *
     * Returns:
     *  A reference to the newly created thread.
     */
    final Thread create( void delegate() dg );


    /**
     * Add t to the list of tracked threads if it is not already being tracked.
     *
     * Params:
     *  t = The thread to add.
     *
     * In:
     *  t must not be null.
     */
    final void add( Thread t );


    /**
     * Removes t from the list of tracked threads.  No operation will be
     * performed if t is not currently being tracked by this object.
     *
     * Params:
     *  t = The thread to remove.
     *
     * In:
     *  t must not be null.
     */
    final void remove( Thread t );


    /**
     * Operates on all threads currently tracked by this object.
     */
    final int opApply( scope int delegate( ref Thread ) dg );


    /**
     * Iteratively joins all tracked threads.  This function will block add,
     * remove, and opApply until it completes.
     *
     * Params:
     *  rethrow = Rethrow any unhandled exception which may have caused the
     *            current thread to terminate.
     *
     * Throws:
     *  Any exception not handled by the joined threads.
     */
    final void joinAll( bool rethrow = true );


private:

    // These must be kept in sync with core/thread.d
    version (D_LP64)
    {
        enum ThreadGroupSize = 24;
    }
    else
    {
        static assert((void*).sizeof == 4); // 32-bit
        enum ThreadGroupSize = 12;
    }

    void data[ThreadGroupSize - __traits(classInstanceSize, Object)] = void;
}


///////////////////////////////////////////////////////////////////////////////
// Fiber Platform Detection and Memory Allocation
///////////////////////////////////////////////////////////////////////////////

private extern __gshared const size_t PAGESIZE;

shared static this();


///////////////////////////////////////////////////////////////////////////////
// Fiber
///////////////////////////////////////////////////////////////////////////////


/**
 * This class provides a cooperative concurrency mechanism integrated with the
 * threading and garbage collection functionality.  Calling a fiber may be
 * considered a blocking operation that returns when the fiber yields (via
 * Fiber.yield()).  Execution occurs within the context of the calling thread
 * so synchronization is not necessary to guarantee memory visibility so long
 * as the same thread calls the fiber each time.  Please note that there is no
 * requirement that a fiber be bound to one specific thread.  Rather, fibers
 * may be freely passed between threads so long as they are not currently
 * executing.  Like threads, a new fiber thread may be created using either
 * derivation or composition, as in the following example.
 *
 * Example:
 * ----------------------------------------------------------------------
 *
 * class DerivedFiber : Fiber
 * {
 *     this()
 *     {
 *         super( &run );
 *     }
 *
 * private :
 *     void run()
 *     {
 *         printf( "Derived fiber running.\n" );
 *     }
 * }
 *
 * void fiberFunc()
 * {
 *     printf( "Composed fiber running.\n" );
 *     Fiber.yield();
 *     printf( "Composed fiber running.\n" );
 * }
 *
 * // create instances of each type
 * Fiber derived = new DerivedFiber();
 * Fiber composed = new Fiber( &fiberFunc );
 *
 * // call both fibers once
 * derived.call();
 * composed.call();
 * printf( "Execution returned to calling context.\n" );
 * composed.call();
 *
 * // since each fiber has run to completion, each should have state TERM
 * assert( derived.state == Fiber.State.TERM );
 * assert( composed.state == Fiber.State.TERM );
 *
 * ----------------------------------------------------------------------
 *
 * Authors: Based on a design by Mikola Lysenko.
 */
class Fiber
{
    ///////////////////////////////////////////////////////////////////////////
    // Initialization
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Initializes a fiber object which is associated with a static
     * D function.
     *
     * Params:
     *  fn = The thread function.
     *  sz = The stack size for this fiber.
     *
     * In:
     *  fn must not be null.
     */
    this( void function() fn, size_t sz = PAGESIZE*4 );


    /**
     * Initializes a fiber object which is associated with a dynamic
     * D function.
     *
     * Params:
     *  dg = The thread function.
     *  sz = The stack size for this fiber.
     *
     * In:
     *  dg must not be null.
     */
    this( void delegate() dg, size_t sz = PAGESIZE*4 );


    /**
     * Cleans up any remaining resources used by this object.
     */
    ~this();


    ///////////////////////////////////////////////////////////////////////////
    // General Actions
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Transfers execution to this fiber object.  The calling context will be
     * suspended until the fiber calls Fiber.yield() or until it terminates
     * via an unhandled exception.
     *
     * Params:
     *  rethrow = Rethrow any unhandled exception which may have caused this
     *            fiber to terminate.
     *
     * In:
     *  This fiber must be in state HOLD.
     *
     * Throws:
     *  Any exception not handled by the joined thread.
     *
     * Returns:
     *  Any exception not handled by this fiber if rethrow = false, null
     *  otherwise.
     */
    final Object call( bool rethrow = true );


    /**
     * Resets this fiber so that it may be re-used.  This routine may only be
     * called for fibers that have terminated, as doing otherwise could result
     * in scope-dependent functionality that is not executed.  Stack-based
     * classes, for example, may not be cleaned up properly if a fiber is reset
     * before it has terminated.
     *
     * In:
     *  This fiber must be in state TERM.
     */
    final void reset();


    ///////////////////////////////////////////////////////////////////////////
    // General Properties
    ///////////////////////////////////////////////////////////////////////////


    /**
     * A fiber may occupy one of three states: HOLD, EXEC, and TERM.  The HOLD
     * state applies to any fiber that is suspended and ready to be called.
     * The EXEC state will be set for any fiber that is currently executing.
     * And the TERM state is set when a fiber terminates.  Once a fiber
     * terminates, it must be reset before it may be called again.
     */
    enum State
    {
        HOLD,   ///
        EXEC,   ///
        TERM    ///
    }


    /**
     * Gets the current state of this fiber.
     *
     * Returns:
     *  The state of this fiber as an enumerated value.
     */
    final @property State state() const;


    ///////////////////////////////////////////////////////////////////////////
    // Actions on Calling Fiber
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Forces a context switch to occur away from the calling fiber.
     */
    static void yield();


    /**
     * Forces a context switch to occur away from the calling fiber and then
     * throws obj in the calling fiber.
     *
     * Params:
     *  t = The object to throw.
     *
     * In:
     *  t must not be null.
     */
    static void yieldAndThrow( Throwable t );


    ///////////////////////////////////////////////////////////////////////////
    // Fiber Accessors
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Provides a reference to the calling fiber or null if no fiber is
     * currently active.
     *
     * Returns:
     *  The fiber object representing the calling fiber or null if no fiber
     *  is currently active within this thread. The result of deleting this object is undefined.
     */
    static Fiber getThis();


    ///////////////////////////////////////////////////////////////////////////
    // Static Initialization
    ///////////////////////////////////////////////////////////////////////////


    version( Posix )
    {
        static this();
    }

private:

    // These must be kept in sync with core/thread.d
    version (D_LP64)
    {
        version (Windows)      enum FiberSize = 88;
        else version (OSX)     enum FiberSize = 88;
        else version (Posix)   enum FiberSize = 88;
        else static assert(0, "Platform not supported.");
    }
    else
    {
        static assert((void*).sizeof == 4); // 32-bit

        version (Windows)      enum FiberSize = 44;
        else version (OSX)     enum FiberSize = 44;
        else version (Posix)   enum FiberSize = 44;
        else static assert(0, "Platform not supported.");
    }

    void data[FiberSize - __traits(classInstanceSize, Object)] = void;
}

version( OSX )
{
    // NOTE: The Mach-O object file format does not allow for thread local
    //       storage declarations. So instead we roll our own by putting tls
    //       into the sections bracketed by _tls_beg and _tls_end.
    //
    //       This function is called by the code emitted by the compiler.  It
    //       is expected to translate an address into the TLS static data to
    //       the corresponding address in the TLS dynamic per-thread data.
    extern (D) void* ___tls_get_addr( void* p );
}
