/**
 * Define base class for synchronization exceptions.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License: Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy
 *	at <a href="http://www.boost.org/LICENSE_1_0.txt">boost.org</a>)
 * Authors:   Sean Kelly
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
