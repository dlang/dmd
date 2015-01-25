/**
 * Unit tests for the D runtime.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2010.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly
 */

/*          Copyright Sean Kelly 2005 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
public import core.atomic;
public import core.bitop;
public import core.cpuid;
public import core.demangle;
public import core.exception;
public import core.memory;
public import core.runtime;
public import core.thread;
public import core.vararg;

public import core.sync.condition;
public import core.sync.mutex;
public import core.sync.rwmutex;
public import core.sync.semaphore;

version(Posix)
    public import core.sys.posix.sys.select;

void main()
{
    // Bring in unit test for module by referencing a function in it
    shared(int) i;
    cas( &i, 0, 1 ); // atomic
    auto b = bsf( 0 ); // bitop
    mmx; // cpuid
    demangle( "" ); // demangle
    // SES - disabled because you cannot enable the GC without disabling it.
    //GC.enable(); // memory
    Runtime.collectHandler = null; // runtime
    static void fn() {}
    new Thread( &fn ); // thread
    va_end( null ); // vararg

    auto m = new Mutex; // mutex
    auto c = new Condition( m ); // condition
    auto r = new ReadWriteMutex; // rwmutex
    auto s = new Semaphore; // semaphore
}
