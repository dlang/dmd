/**
 * The config module contains utility routines and configuration information
 * specific to this package.
 *
 * Copyright: Copyright (C) 2005-2009 Sean Kelly.  All rights reserved.
 * License:   BSD style: $(LICENSE)
 * Authors:   Sean Kelly
 */
module core.sync.config;


version( Posix )
{
    private import core.sys.posix.time;
    private import core.sys.posix.sys.time;


    void mktspec( inout timespec t, long delta = 0 )
    {
        static if( is( typeof( clock_gettime ) ) )
        {
            clock_gettime( CLOCK_REALTIME, &t );
        }
        else
        {
            timeval tv;

            gettimeofday( &tv, null );
            (cast(byte*) &t)[0 .. t.sizeof] = 0;
            t.tv_sec  = cast(typeof(t.tv_sec))  tv.tv_sec;
            t.tv_nsec = cast(typeof(t.tv_nsec)) tv.tv_usec * 1_000;
        }

        if( delta == 0 )
            return;

        enum : uint
        {
            NANOS_PER_TICK   = 100,
            TICKS_PER_SECOND = 10_000_000,
        }

        if( t.tv_sec.max - t.tv_sec < delta / TICKS_PER_SECOND )
        {
            t.tv_sec  = t.tv_sec.max;
            t.tv_nsec = 0;
        }
        else
        {
            t.tv_sec = cast(typeof(t.tv_sec)) (delta / TICKS_PER_SECOND);
            t.tv_nsec = cast(typeof(t.tv_nsec)) (delta % TICKS_PER_SECOND) * NANOS_PER_TICK;
        }
    }
}
