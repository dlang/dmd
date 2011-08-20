/**
 * The console module contains some simple routines for console output.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.util.console;


private
{
    version (Windows)
    {
        import core.sys.windows.windows;
    }
    else version( Posix )
    {
        import core.sys.posix.unistd;
    }
    import rt.util.string;
}


struct Console
{
    Console opCall( in char[] val )
    {
        version( Windows )
        {
            uint count = void;
            WriteFile( GetStdHandle( 0xfffffff5 ), val.ptr, val.length, &count, null );
        }
        else version( Posix )
        {
            write( 2, val.ptr, val.length );
        }
        return this;
    }


    Console opCall( ulong val )
    {
            char[10] tmp = void;
            return opCall( tmp.intToString( val ) );
    }
}

__gshared Console console;
