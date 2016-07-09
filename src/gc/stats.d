/**
 * Contains a struct for storing GC statistics.
 *
 * Copyright: Copyright Digital Mars 2005 - 2013.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2005 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.stats;

/**
 * Aggregation of GC stats to be exposed via public API
 */
struct GCStats
{
    /// total size of GC heap
    size_t usedSize;
    /// free bytes on the GC heap (might only get updated after a collection)
    size_t freeSize;
}
