/**
 * The thread module provides support for thread creation and management.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly, Walter Bright, Alex Rønne Petersen, Martin Nowak
 * Source:    $(DRUNTIMESRC core/thread/package.d)
 */

module core.thread;

public import core.time;
public import core.thread.fiber;
public import core.thread.osthread;
public import core.thread.threadbase;
public import core.thread.threadgroup;
public import core.thread.types;
public import core.thread.context;


// this test is here to avoid a cyclic dependency between
// core.thread and core.atomic
@system unittest
{
    import core.atomic;

    shared uint x;
    shared bool f;
    shared uint r;

    auto thr = new Thread(()
    {
        while (!atomicLoad(f))
        {
        }

        atomicFence(); // make sure load+store below happens after waiting for f

        cast() r = cast() x;
    });

    thr.start(); // new thread will wait until f is set

    cast() x = 42;

    atomicFence(); // make sure x is set before setting f

    cast() f = true;

    atomicFence();

    thr.join();

    assert(cast() r == 42);
}
