/**
 * The barrier module provides a primitive for synchronizing the progress of
 * a group of threads.
 *
 * Copyright: Copyright (C) 2005-2009 Sean Kelly.  All rights reserved.
 * License:   BSD Style, see LICENSE
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
