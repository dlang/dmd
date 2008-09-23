/**
 * The exception module defines all system-level exceptions and provides a
 * mechanism to alter system-level error handling.
 *
 * Copyright: Copyright (c) 2005-2008, The D Runtime Project
 * License:   BSD Style, see LICENSE
 * Authors:   Sean Kelly
 */
module exception;


private
{
    alias void  function( string file, size_t line, string msg = null ) assertHandlerType;

    assertHandlerType   assertHandler   = null;
}


/**
 * Thrown on an array bounds error.
 */
class ArrayBoundsException : Exception
{
    this( string file, size_t line )
    {
        super( "Array index out of bounds", file, line );
    }
}


/**
 * Thrown on an assert error.
 */
class AssertException : Exception
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
class FinalizeException : Exception
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
 * Thrown on an out of memory error.
 */
class OutOfMemoryException : Exception
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
class SwitchException : Exception
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
void setAssertHandler( assertHandlerType h )
{
    assertHandler = h;
}


///////////////////////////////////////////////////////////////////////////////
// Overridable Callbacks
///////////////////////////////////////////////////////////////////////////////


/**
 * A callback for assert errors in D.  The user-supplied assert handler will
 * be called if one has been supplied, otherwise an AssertException will be
 * thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 */
extern (C) void onAssertError( string file, size_t line )
{
    if( assertHandler is null )
        throw new AssertException( file, line );
    assertHandler( file, line );
}


/**
 * A callback for assert errors in D.  The user-supplied assert handler will
 * be called if one has been supplied, otherwise an AssertException will be
 * thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *  msg  = An error message supplied by the user.
 */
extern (C) void onAssertErrorMsg( string file, size_t line, string msg )
{
    if( assertHandler is null )
        throw new AssertException( msg, file, line );
    assertHandler( file, line, msg );
}


///////////////////////////////////////////////////////////////////////////////
// Internal Error Callbacks
///////////////////////////////////////////////////////////////////////////////


/**
 * A callback for array bounds errors in D.  An ArrayBoundsException will be
 * thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *
 * Throws:
 *  ArrayBoundsException.
 */
extern (C) void onArrayBoundsError( string file, size_t line )
{
    throw new ArrayBoundsException( file, line );
}


/**
 * A callback for finalize errors in D.  A FinalizeException will be thrown.
 *
 * Params:
 *  e = The exception thrown during finalization.
 *
 * Throws:
 *  FinalizeException.
 */
extern (C) void onFinalizeError( ClassInfo info, Exception ex )
{
    throw new FinalizeException( info, ex );
}


/**
 * A callback for out of memory errors in D.  An OutOfMemoryException will be
 * thrown.
 *
 * Throws:
 *  OutOfMemoryException.
 */
extern (C) void onOutOfMemoryError()
{
    // NOTE: Since an out of memory condition exists, no allocation must occur
    //       while generating this object.
    throw cast(OutOfMemoryException) cast(void*) OutOfMemoryException.classinfo.init;
}


/**
 * A callback for switch errors in D.  A SwitchException will be thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *
 * Throws:
 *  SwitchException.
 */
extern (C) void onSwitchError( string file, size_t line )
{
    throw new SwitchException( file, line );
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
