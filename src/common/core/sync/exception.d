/**
 * The barrier module provides a primitive for synchronizing the progress of
 * a group of threads.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt>Boost License 1.0</a>.
 * Authors:   Sean Kelly
 *
 *          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sync.exception;


/**
 * Base class for synchronization exceptions.
 */
class SyncException : Exception
{
    this( string msg )
    {
        super( msg );
    }
}
