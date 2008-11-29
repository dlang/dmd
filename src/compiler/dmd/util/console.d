/**
 * The console module contains some simple routines for console output.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 */
module util.console;


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
    import util.string;
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


    Console opCall( uint val )
    {
            char[10] tmp = void;
            return opCall( tmp.intToString( val ) );
    }
}

Console console;
