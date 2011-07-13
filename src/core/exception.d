/**
 * The exception module defines all system-level exceptions and provides a
 * mechanism to alter system-level error handling.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly and Jonathan M Davis
 * Source:    $(DRUNTIMESRC core/_exception.d)
 */

/*          Copyright Sean Kelly 2005 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.exception;

import core.stdc.stdio;

private
{
    alias void function( string file, size_t line, string msg ) errorHandlerType;

    // NOTE: One assert handler is used for all threads.  Thread-local
    //       behavior should occur within the handler itself.  This delegate
    //       is __gshared for now based on the assumption that it will only
    //       set by the main thread during program initialization.
    __gshared errorHandlerType assertHandler = null;
}


/**
 * Thrown on a range error.
 */
class RangeError : Error
{
    this( string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( "Range violation", file, line, next );
    }
}

unittest
{
    {
        auto re = new RangeError();
        assert(re.file == __FILE__);
        assert(re.line == __LINE__ - 2);
        assert(re.next is null);
        assert(re.msg == "Range violation");
    }

    {
        auto re = new RangeError("hello", 42, new Exception("It's an Exception!"));
        assert(re.file == "hello");
        assert(re.line == 42);
        assert(re.next !is null);
        assert(re.msg == "Range violation");
    }
}


/**
 * Thrown on an assert error.
 */
class AssertError : Error
{
    this( string file, size_t line )
    {
        this(cast(Throwable)null, file, line);
    }

    this( Throwable next, string file = __FILE__, size_t line = __LINE__ )
    {
        this( "Assertion failure", file, line, next);
    }

    this( string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( msg, file, line, next );
    }
}

unittest
{
    {
        auto ae = new AssertError("hello", 42);
        assert(ae.file == "hello");
        assert(ae.line == 42);
        assert(ae.next is null);
        assert(ae.msg == "Assertion failure");
    }

    {
        auto ae = new AssertError(new Exception("It's an Exception!"));
        assert(ae.file == __FILE__);
        assert(ae.line == __LINE__ - 2);
        assert(ae.next !is null);
        assert(ae.msg == "Assertion failure");
    }

    {
        auto ae = new AssertError(new Exception("It's an Exception!"), "hello", 42);
        assert(ae.file == "hello");
        assert(ae.line == 42);
        assert(ae.next !is null);
        assert(ae.msg == "Assertion failure");
    }

    {
        auto ae = new AssertError("msg");
        assert(ae.file == __FILE__);
        assert(ae.line == __LINE__ - 2);
        assert(ae.next is null);
        assert(ae.msg == "msg");
    }

    {
        auto ae = new AssertError("msg", "hello", 42);
        assert(ae.file == "hello");
        assert(ae.line == 42);
        assert(ae.next is null);
        assert(ae.msg == "msg");
    }

    {
        auto ae = new AssertError("msg", "hello", 42, new Exception("It's an Exception!"));
        assert(ae.file == "hello");
        assert(ae.line == 42);
        assert(ae.next !is null);
        assert(ae.msg == "msg");
    }
}


/**
 * Thrown on finalize error.
 */
class FinalizeError : Error
{
    ClassInfo   info;

    this( ClassInfo ci, Throwable next, string file = __FILE__, size_t line = __LINE__ )
    {
        this(ci, file, line, next);
    }

    this( ClassInfo ci, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( "Finalization error", file, line, next );
        info = ci;
    }

    override string toString()
    {
        return "An exception was thrown while finalizing an instance of class " ~ info.name;
    }
}

unittest
{
    ClassInfo info = new ClassInfo;
    info.name = "testInfo";

    {
        auto fe = new FinalizeError(info);
        assert(fe.file == __FILE__);
        assert(fe.line == __LINE__ - 2);
        assert(fe.next is null);
        assert(fe.msg == "Finalization error");
        assert(fe.info == info);
    }

    {
        auto fe = new FinalizeError(info, new Exception("It's an Exception!"));
        assert(fe.file == __FILE__);
        assert(fe.line == __LINE__ - 2);
        assert(fe.next !is null);
        assert(fe.msg == "Finalization error");
        assert(fe.info == info);
    }

    {
        auto fe = new FinalizeError(info, "hello", 42);
        assert(fe.file == "hello");
        assert(fe.line == 42);
        assert(fe.next is null);
        assert(fe.msg == "Finalization error");
        assert(fe.info == info);
    }

    {
        auto fe = new FinalizeError(info, "hello", 42, new Exception("It's an Exception!"));
        assert(fe.file == "hello");
        assert(fe.line == 42);
        assert(fe.next !is null);
        assert(fe.msg == "Finalization error");
        assert(fe.info == info);
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

unittest
{
    ClassInfo info = new ClassInfo;
    info.name = "testInfo";

    {
        auto hfe = new HiddenFuncError(info);
        assert(hfe.next is null);
        assert(hfe.msg == "Hidden method called for testInfo");
    }
}


/**
 * Thrown on an out of memory error.
 */
class OutOfMemoryError : Error
{
    this(string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( "Memory allocation failed", file, line, next );
    }

    override string toString()
    {
        return msg ? super.toString() : "Memory allocation failed";
    }
}

unittest
{
    {
        auto oome = new OutOfMemoryError();
        assert(oome.file == __FILE__);
        assert(oome.line == __LINE__ - 2);
        assert(oome.next is null);
        assert(oome.msg == "Memory allocation failed");
    }

    {
        auto oome = new OutOfMemoryError("hello", 42, new Exception("It's an Exception!"));
        assert(oome.file == "hello");
        assert(oome.line == 42);
        assert(oome.next !is null);
        assert(oome.msg == "Memory allocation failed");
    }
}


/**
 * Thrown on a switch error.
 */
class SwitchError : Error
{
    this( string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( "No appropriate switch clause found", file, line, next );
    }
}

unittest
{
    {
        auto se = new SwitchError();
        assert(se.file == __FILE__);
        assert(se.line == __LINE__ - 2);
        assert(se.next is null);
        assert(se.msg == "No appropriate switch clause found");
    }

    {
        auto se = new SwitchError("hello", 42, new Exception("It's an Exception!"));
        assert(se.file == "hello");
        assert(se.line == 42);
        assert(se.next !is null);
        assert(se.msg == "No appropriate switch clause found");
    }
}


/**
 * Thrown on a unicode conversion error.
 */
class UnicodeException : Exception
{
    size_t idx;

    this( string msg, size_t idx, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( msg, file, line, next );
        this.idx = idx;
    }
}

unittest
{
    {
        auto ue = new UnicodeException("msg", 2);
        assert(ue.file == __FILE__);
        assert(ue.line == __LINE__ - 2);
        assert(ue.next is null);
        assert(ue.msg == "msg");
        assert(ue.idx == 2);
    }

    {
        auto ue = new UnicodeException("msg", 2, "hello", 42, new Exception("It's an Exception!"));
        assert(ue.file == "hello");
        assert(ue.line == 42);
        assert(ue.next !is null);
        assert(ue.msg == "msg");
        assert(ue.idx == 2);
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
deprecated void setAssertHandler( errorHandlerType h )
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
extern (C) void onAssertError( string file = __FILE__, size_t line = __LINE__ )
{
    if( assertHandler is null )
        throw new AssertError( file, line );
    assertHandler( file, line, null);
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
    onAssertErrorMsg( file, line, msg );
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
extern (C) void onRangeError( string file = __FILE__, size_t line = __LINE__ )
{
    throw new RangeError( file, line, null );
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
extern (C) void onFinalizeError( ClassInfo info, Exception e, string file = __FILE__, size_t line = __LINE__ )
{
    throw new FinalizeError( info, file, line, e );
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
extern (C) void onSwitchError( string file = __FILE__, size_t line = __LINE__ )
{
    throw new SwitchError( file, line, null );
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
extern (C) void onUnicodeError( string msg, size_t idx, string file = __FILE__, size_t line = __LINE__ )
{
    throw new UnicodeException( msg, idx, file, line );
}
