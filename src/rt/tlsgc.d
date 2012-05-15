/**
 *
 * Copyright: Copyright Digital Mars 2011 - 2012.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Martin Nowak
 */

/*          Copyright Digital Mars 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.tlsgc;

import core.stdc.stdlib;

static import rt.lifetime;

/**
 * Per thread record to store thread associated data for garbage collection.
 */
struct Data
{
    rt.lifetime.BlkInfo** blockInfoCache;
}

/**
 * Initialization hook, called FROM each thread. No assumptions about
 * module initialization state should be made.
 */
Data* init()
{
    auto p = cast(Data*).malloc(Data.sizeof);
    *p = Data.init;

    // do module specific initialization
    p.blockInfoCache = &rt.lifetime.__blkcache_storage;

    return p;
}

/**
 * Finalization hook, called FOR each thread. No assumptions about
 * module initialization state should be made.
 */
void destroy(Data* data)
{
    // do module specific finalization

    .free(data);
}

alias void delegate(void* pstart, void* pend) ScanDg;

/**
 * GC scan hook, called FOR each thread. Can be used to scan
 * additional thread local memory.
 */
void scan(Data* data, scope ScanDg dg)
{
    // do module specific marking
}

alias int delegate(void* addr) IsMarkedDg;

/**
 * GC sweep hook, called FOR each thread. Can be used to free
 * additional thread local memory or associated data structures. Note
 * that only memory allocated from the GC can have marks.
 */
void processGCMarks(Data* data, scope IsMarkedDg dg)
{
    // do module specific sweeping
    rt.lifetime.processGCMarks(*data.blockInfoCache, dg);
}
