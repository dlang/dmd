/**
 * Define base class for synchronization exceptions.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/sync/_exception.d)
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
