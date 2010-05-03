/**
 * The exception module defines all system-level exceptions and provides a
 * mechanism to alter system-level error handling.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 *
 *          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.exception;


private
{
    alias void function( string file, size_t line, string msg = null ) errorHandlerType;

    // NOTE: One assert handler is used for all threads.  Thread-local
    //       behavior should occur within the handler itself.  This delegate
    //       is __gshared for now based on the assumption that it will only
    //       set by the main thread during program initialization.
    __gshared errorHandlerType assertHandler = null;

    // For onUnittestErrorMsg implementation.
    version (Windows)
    {
        import core.sys.windows.windows;
    }
    else version( Posix )
    {
        import core.sys.posix.unistd;
    }
}


/**
 * Thrown on a range error.
 */
class RangeError : Error
{
    this( string file, size_t line )
    {
        super( "Range violation", file, line );
    }
}


/**
 * Thrown on an assert error.
 */
class AssertError : Error
{
    this( string file, size_t line )
    {
        super( "Assertion failure", file, line );
    }

    this( string msg, string file, size_t line )
    {
        super( msg, file, line );
    }
}


/**
 * Thrown on finalize error.
 */
class FinalizeError : Error
{
    ClassInfo   info;

    this( ClassInfo c, Exception e = null )
    {
        super( "Finalization error", e );
        info = c;
    }

    override string toString()
    {
        return "An exception was thrown while finalizing an instance of class " ~ info.name;
    }
}


/**
 * Thrown on hidden function error.
 */
class HiddenFuncError : Error
{
    this( ClassInfo ci )
    {
        super( "Hidden method called for " ~ ci.name );
    }
}


/**
 * Thrown on an out of memory error.
 */
class OutOfMemoryError : Error
{
    this( string file, size_t line )
    {
        super( "Memory allocation failed", file, line );
    }

    override string toString()
    {
        return msg ? super.toString() : "Memory allocation failed";
    }
}


/**
 * Thrown on a switch error.
 */
class SwitchError : Error
{
    this( string file, size_t line )
    {
        super( "No appropriate switch clause found", file, line );
    }
}


/**
 * Thrown on a unicode conversion error.
 */
class UnicodeException : Exception
{
    size_t idx;

    this( string msg, size_t idx )
    {
        super( msg );
        this.idx = idx;
    }
}


///////////////////////////////////////////////////////////////////////////////
// Overrides
///////////////////////////////////////////////////////////////////////////////


/**
 * Overrides the default assert hander with a user-supplied version.
 *
 * Params:
 *  h = The new assert handler.  Set to null to use the default handler.
 */
void setAssertHandler( errorHandlerType h )
{
    assertHandler = h;
}


///////////////////////////////////////////////////////////////////////////////
// Overridable Callbacks
///////////////////////////////////////////////////////////////////////////////


/**
 * A callback for assert errors in D.  The user-supplied assert handler will
 * be called if one has been supplied, otherwise an AssertError will be thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 */
extern (C) void onAssertError( string file, size_t line )
{
    if( assertHandler is null )
        throw new AssertError( file, line );
    assertHandler( file, line );
}


/**
 * A callback for assert errors in D.  The user-supplied assert handler will
 * be called if one has been supplied, otherwise an AssertError will be thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *  msg  = An error message supplied by the user.
 */
extern (C) void onAssertErrorMsg( string file, size_t line, string msg )
{
    if( assertHandler is null )
        throw new AssertError( msg, file, line );
    assertHandler( file, line, msg );
}


/**
 * A callback for unittest errors in D.  The user-supplied unittest handler
 * will be called if one has been supplied, otherwise the error will be
 * written to stderr.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *  msg  = An error message supplied by the user.
 */
extern (C) void onUnittestErrorMsg( string file, size_t line, string msg )
{
    static char[] intToString( char[] buf, uint val )
    {
        assert( buf.length > 9 );
        auto p = buf.ptr + buf.length;

        do
        {
            *--p = cast(char)(val % 10 + '0');
        } while( val /= 10 );

        return buf[p - buf.ptr .. $];
    }

    static struct Console
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
            return opCall( intToString( tmp, val ) );
        }
    }

    static __gshared Console console;

    console( file )( "(" )( line )( "): " )( msg )( "\n" );
}


///////////////////////////////////////////////////////////////////////////////
// Internal Error Callbacks
///////////////////////////////////////////////////////////////////////////////


/**
 * A callback for array bounds errors in D.  A RangeError will be thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *
 * Throws:
 *  RangeError.
 */
extern (C) void onRangeError( string file, size_t line )
{
    throw new RangeError( file, line );
}


/**
 * A callback for finalize errors in D.  A FinalizeError will be thrown.
 *
 * Params:
 *  e = The exception thrown during finalization.
 *
 * Throws:
 *  FinalizeError.
 */
extern (C) void onFinalizeError( ClassInfo info, Exception ex )
{
    throw new FinalizeError( info, ex );
}


/**
 * A callback for hidden function errors in D.  A HiddenFuncError will be
 * thrown.
 *
 * Throws:
 *  HiddenFuncError.
 */
extern (C) void onHiddenFuncError( Object o )
{
    throw new HiddenFuncError( o.classinfo );
}


/**
 * A callback for out of memory errors in D.  An OutOfMemoryError will be
 * thrown.
 *
 * Throws:
 *  OutOfMemoryError.
 */
extern (C) void onOutOfMemoryError()
{
    // NOTE: Since an out of memory condition exists, no allocation must occur
    //       while generating this object.
    throw cast(OutOfMemoryError) cast(void*) OutOfMemoryError.classinfo.init;
}


/**
 * A callback for switch errors in D.  A SwitchError will be thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *
 * Throws:
 *  SwitchError.
 */
extern (C) void onSwitchError( string file, size_t line )
{
    throw new SwitchError( file, line );
}


/**
 * A callback for unicode errors in D.  A UnicodeException will be thrown.
 *
 * Params:
 *  msg = Information about the error.
 *  idx = String index where this error was detected.
 *
 * Throws:
 *  UnicodeException.
 */
extern (C) void onUnicodeError( string msg, size_t idx )
{
    throw new UnicodeException( msg, idx );
}
