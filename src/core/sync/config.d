/**
 * The config module contains utility routines and configuration information
 * specific to this package.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/sync/_semaphore.d)
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sync.config;


version( Posix )
{
    private import core.sys.posix.time;
    private import core.sys.posix.sys.time;


    void mktspec( ref timespec t, long delta = 0 )
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
        mvtspec( t, delta );
    }


    void mvtspec( ref timespec t, long delta )
    {
        if( delta == 0 )
            return;

        enum : uint
        {
            NANOS_PER_TICK   = 100,
            TICKS_PER_SECOND = 10_000_000,
            NANOS_PER_SECOND = NANOS_PER_TICK * TICKS_PER_SECOND,
        }

        if( t.tv_sec.max - t.tv_sec < delta / TICKS_PER_SECOND )
        {
            t.tv_sec  = t.tv_sec.max;
            t.tv_nsec = 0;
        }
        else
        {
            t.tv_sec += cast(typeof(t.tv_sec)) (delta / TICKS_PER_SECOND);
            long ns = (delta % TICKS_PER_SECOND) * NANOS_PER_TICK;
            if( NANOS_PER_SECOND - t.tv_nsec > ns )
            {
                t.tv_nsec = cast(typeof(t.tv_nsec)) ns;
                return;
            }
            t.tv_sec  += 1;
            t.tv_nsec += cast(typeof(t.tv_nsec)) (ns - NANOS_PER_SECOND);
        }
    }
}
