/**
 * The time module is intended to provide some basic support for time-based
 * operations.
 *
 * Copyright: Copyright Sean Kelly 2010 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 *
 *          Copyright Sean Kelly 2010 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.time;


private
{
    auto _mkpos(T)( T val )
    {
        return 0 > val ? -val : val;
    }
}


//////////////////////////////////////////////////////////////////////////////
// Duration
//////////////////////////////////////////////////////////////////////////////


struct Duration
{
    alias int   DayType;
    alias int   HourType;
    alias int   MinType;
    alias int   SecType;
    alias long  FracType;
    alias long  TickType;
    
    
    //////////////////////////////////////////////////////////////////////////
    // Constructors
    //////////////////////////////////////////////////////////////////////////
    

    this( HourType h, MinType m, SecType s = 0, FracType f = 0 )
    {
        m_ticks = toTicks( h, m, s, f );
    }
    
    
    this( Duration other )
    {
        m_ticks = other.m_ticks;
    }
    
    
    //////////////////////////////////////////////////////////////////////////
    // Time
    //////////////////////////////////////////////////////////////////////////


    const @property HourType hours() nothrow
    {
        return cast(HourType)(ticks / (3600 * ticksPerSecond));
    }
    
    
    const @property MinType minutes() nothrow
    {
        return cast(MinType)((ticks / (60 * ticksPerSecond)) % 60);
    }
    
    
    const @property SecType seconds() nothrow
    {
        return cast(SecType)((ticks / ticksPerSecond) % 60);
    }
    
    
    const @property SecType totalSeconds() nothrow
    {
        // TODO: Boost uses SecType here, but the result is really a tick count
        //       and could be quite large, particularly if ticksPerSecond is
        //       small.  Perhaps the return type should be changed to TickType?
        return cast(SecType)(ticks / ticksPerSecond);
    }
    
    
    const @property TickType totalMilliseconds() nothrow
    {
        if( 1000 <= ticksPerSecond )
            return ticks / (ticksPerSecond / cast(TickType) 1000);
        return ticks * (cast(TickType) 1000 / ticksPerSecond);
    }
    
    
    const @property TickType totalMicroseconds() nothrow
    {
        if( 1000_000 <= ticksPerSecond )
            return ticks / (ticksPerSecond / cast(TickType) 1000_000);
        return ticks * (cast(TickType) 1000_000 / ticksPerSecond);
    }
    
    
    const @property TickType totalNanoseconds() nothrow
    {
        if( 1000_000_000 <= ticksPerSecond )
            return ticks / (ticksPerSecond / cast(TickType) 1000_000_000);
        return ticks * (cast(TickType) 1000_000_000 / ticksPerSecond);
    }
    
    
    const @property FracType fractionalSeconds() nothrow
    {
        return ticks % ticksPerSecond;
    }
    
    
    const @property TickType ticks() nothrow
    {
        return m_ticks;
    }
    
    
    //////////////////////////////////////////////////////////////////////////
    // Properties
    //////////////////////////////////////////////////////////////////////////
    
    
    const @property bool isNegative() nothrow
    {
        return 0 > ticks;
    }
    
    
    // TODO: Add support for specials and decide about the utility of NotDateTime.
    
    
    const @property bool isNegInfinity() nothrow
    {
        return false;
    }
    
    
    const @property bool isPosInfinity() nothrow
    {
        return false;
    }
    
    
    const @property bool isNotDateTime() nothrow
    {
        return false;
    }
    
    
    const @property bool isSpecial() nothrow
    {
        return false;
    }
    
    
    //////////////////////////////////////////////////////////////////////////
    // Mutators
    //////////////////////////////////////////////////////////////////////////
    
    
    const @property Duration invertSign() //nothrow
    {
        return Duration( -ticks );
    }
    
    
    //////////////////////////////////////////////////////////////////////////
    // Operators
    //////////////////////////////////////////////////////////////////////////
    
    
    Duration opUnary(string op)()
        if( op == "-" || op == "+" )
    {
        static if( op == "-" )
        {
            return Duration( -m_ticks );
        }
        else
        static if( op == "+" )
        {
            return Duration( +m_ticks );
        }
    }

    
    Duration opBinary(string op)( ref const(Duration) other )
        if( op == "+" || op == "-" || op == "*" || op == "/" )
    {
        auto   x = this;
        return x.opOpAssign!(op)( other );
    }
    
    
    Duration opOpAssign(string op)( ref const(Duration) other )
        if( op == "+" || op == "-" || op == "*" || op == "/" )
    {
        static if( op == "+" )
        {
            m_ticks += other.m_ticks;
        }
        else
        static if( op == "-" )
        {
            m_ticks -= other.m_ticks;
        }
        else
        static if( op == "*" )
        {
            m_ticks *= other.m_ticks;
        }
        else
        static if( op == "/" )
        {
            m_ticks /= other.m_ticks;
        }
        return this;
    }
    
    
    const equals_t opEquals( ref const(Duration) other ) nothrow
    {
        return m_ticks == other.m_ticks;
    }
    
    
    const int opCmp( ref const(Duration) other ) nothrow
    {
        return m_ticks < other.m_ticks ?
                 -1 : m_ticks > other.m_ticks ?
                        1 : 0;
    }
    
    
    //////////////////////////////////////////////////////////////////////////
    // Statics
    //////////////////////////////////////////////////////////////////////////
 
/+
    pure @property TimeResolution resolution() nothrow
    {
        return TimeResolution.nano;
    }
+/
    
    static @property ushort numFractionalDigits() nothrow
    {
        return 9;
    }
    
    
    static @property TickType ticksPerSecond() nothrow
    {
        return 1000_000_000; // nanosecond
    }
    
    
    static @property Duration unit() //nothrow
    {
        return Duration( 0, 0, 0, 1 );
    }
    
    
private:
    TickType toTicks( HourType h, MinType m, SecType s, FracType f )
    {
        if( 0 <= h && 0 <= m && 0 <= s && 0 <= f )
        {
            return (((cast(FracType) h * 3600) +
                     (cast(FracType) m * 60) +
                     (cast(FracType) s)) *
                     ticksPerSecond) +
                     f;
        }
        h = _mkpos( h ); m = _mkpos( m );
        s = _mkpos( s ); f = _mkpos( f );
        return ((((cast(FracType) h * 3600) +
                  (cast(FracType) m * 60) +
                  (cast(FracType) s)) *
                  ticksPerSecond) +
                  f) * -1;
    }
    
    
    this( TickType t )
    {
        m_ticks = t;
    }
    
    
private:
    TickType    m_ticks;
}


//////////////////////////////////////////////////////////////////////////////
// Utility Functions
//////////////////////////////////////////////////////////////////////////////


Duration hours( Duration.HourType n )
{
    return Duration( n, 0, 0, 0 );
}


Duration minutes( Duration.MinType n )
{
    return Duration( 0, n, 0, 0 );
}


Duration seconds( Duration.SecType n )
{
    return Duration( 0, 0, n, 0 );
}


Duration milliseconds( Duration.FracType n )
{
    if( 1000 <= Duration.ticksPerSecond )
    {
        n *= (Duration.ticksPerSecond / 1000);
        return Duration( 0, 0, 0, n ); 
    }
    n /= (1000 / Duration.ticksPerSecond);
    return Duration( 0, 0, 0, n );
}


Duration microseconds( Duration.FracType n )
{
    if( 1000_000 <= Duration.ticksPerSecond )
    {
        n *= (Duration.ticksPerSecond / 1000_000);
        return Duration( 0, 0, 0, n ); 
    }
    n /= (1000_000 / Duration.ticksPerSecond);
    return Duration( 0, 0, 0, n );   
}


Duration nanoseconds( Duration.FracType n )
{
    if( 1000_000_000 <= Duration.ticksPerSecond )
    {
        n *= (Duration.ticksPerSecond / 1000_000_000);
        return Duration( 0, 0, 0, n ); 
    }
    n /= (1000_000_000 / Duration.ticksPerSecond);
    return Duration( 0, 0, 0, n );
}
