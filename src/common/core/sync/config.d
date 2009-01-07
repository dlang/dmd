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


    void getTimespec( inout timespec t )
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
    }


    void adjTimespec( inout timespec t, double v )
    {
        enum
        {
            SECS_TO_NANOS = 1_000_000_000
        }

        // NOTE: The fractional value added to period is to correct fp error.
        v += 0.000_000_000_1;

        if( t.tv_sec.max - t.tv_sec < v )
        {
            t.tv_sec  = t.tv_sec.max;
            t.tv_nsec = 0;
        }
        else
        {
            alias typeof(t.tv_sec)  Secs;
            alias typeof(t.tv_nsec) Nanos;

            t.tv_sec  += cast(Secs) v;
            auto  ns   = cast(long)((v % 1.0) * SECS_TO_NANOS);
            if( SECS_TO_NANOS - t.tv_nsec < ns )
            {
                t.tv_sec += 1;
                ns -= SECS_TO_NANOS;
            }
            t.tv_nsec += cast(Nanos) ns;
        }
    }
}
