/**
 * errorsinkjson.d
 *
 * JSON-based implementation of ErrorSink for DMD.
 * Emits compiler diagnostics as JSON objects for tools, editors, or LSP servers.
 */

module errorsinkjson;

import core.stdc.stdarg : va_list, vsnprintf;
import dmd.errorsink : ErrorSink;
import dmd.location : Loc;
import std.json : JSONValue, toJSON;
import std.stdio : writeln;

/// JSON-based error sink implementation for structured diagnostics.
class ErrorSinkJson : ErrorSink
{
nothrow:
extern (C++):
override:

    private JSONValue[] diagnostics;

    /// Helper to convert a message into a JSON entry
    private void addMessage(string severity, Loc loc, const(char)* format, va_list ap)
    {
        char[1024] buf;
        vsnprintf(buf.ptr, buf.length, format, ap);

        string filename = loc.filename ? loc.filename.toString() : "";
        JSONValue msg = [
            "file"    : JSONValue(filename),
            "line"    : JSONValue(loc.linnum),
            "column"  : JSONValue(loc.charnum),
            "severity": JSONValue(severity),
            "message" : JSONValue(buf[0 .. buf.length].idup)
        ];
        diagnostics ~= msg;
    }

    /// Implementation of all virtual functions from ErrorSink

    void verror(Loc loc, const(char)* format, va_list ap)
    {
        addMessage("error", loc, format, ap);
    }

    void verrorSupplemental(Loc loc, const(char)* format, va_list ap)
    {
        addMessage("error-supplemental", loc, format, ap);
    }

    void vwarning(Loc loc, const(char)* format, va_list ap)
    {
        addMessage("warning", loc, format, ap);
    }

    void vwarningSupplemental(Loc loc, const(char)* format, va_list ap)
    {
        addMessage("warning-supplemental", loc, format, ap);
    }

    void vmessage(Loc loc, const(char)* format, va_list ap)
    {
        addMessage("message", loc, format, ap);
    }

    void vdeprecation(Loc loc, const(char)* format, va_list ap)
    {
        addMessage("deprecation", loc, format, ap);
    }

    void vdeprecationSupplemental(Loc loc, const(char)* format, va_list ap)
    {
        addMessage("deprecation-supplemental", loc, format, ap);
    }


    /// Called when compilation is done
    override void plugSink()
    {
        // Emit all collected diagnostics as a JSON array
        writeln(toJSON(diagnostics));
        diagnostics.length = 0;
    }
}
