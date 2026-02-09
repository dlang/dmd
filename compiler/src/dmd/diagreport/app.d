module dmd.diagreport.app;

import core.stdc.stdio : vprintf, fflush, stderr;
import dmd.common.outbuffer;
import dmd.diagreport.defs;
import dmd.diagreport.geometry;
import dmd.diagreport.renderer;
// import std.stdio;
// import std.conv;
import std.range;
// import std.array;
import std.string;

/*void addDFADiagnostic(const SourceLoc loc, const(char)* format, va_list ap, ErrorKind kind) nothrow
{
    char[1024] buffer;
    int written = vsnprintf(buffer.ptr, buffer.length, format, ap);
    string messagesText = cast(string) buffer[0 .. (written < 0 || written > buffer.length ? buffer.length : written)].dup;
    // add diagnostic to the array
    if(diagnostics.length == 0 || diagnostics[diagnostics.length-1].filename == loc.filename)
    {
        Diagnostic diag;
        diag start = loc.line;
        diag end = loc.line + 1;
        diag.Message = Message(loc.column,)
    }
    else
    {

    }
}*/

void event(string filename, string source, int firstLineNumber, Diagnostic[] diagnostics, string[] messagesText, Help[] help)
{
    OutBuffer buf;
    string[] lines = source.splitLines;

    Renderer renderer;
    renderer.filename = filename;
    renderer.diagnostics = diagnostics;
    renderer.help = help;

    renderer.emitRaw = (string text) => buf.printDiagnostic(text);
    renderer.emitRawFormat = (const(char)* fmt, ...) {
        import core.stdc.stdarg;

        va_list args;
        va_start(args, fmt);
        vprintf(fmt, args);
        va_end(args);
    };
    renderer.emitMargin = (string text) => buf.printDiagnostic("\x1b[33m", text, "\x1b[0m");
    renderer.emitHeader = () => buf.printDiagnostic("\x1b[31merror\x1b[0m: ");
    renderer.emitHeaderMultiLinePrefix = () => buf.printDiagnostic("       ");
    renderer.emitFooter = () => buf.printDiagnostic("\x1b[34mnote:\x1b[0m ");
    renderer.emitFooterMultiLinePrefix = () => buf.printDiagnostic("      ");
    renderer.emitHelp = () => buf.printDiagnostic("\x1b[34mhelp:\x1b[0m ");
    renderer.emitHelpMultiLinePrefix = () => buf.printDiagnostic("      ");
    renderer.emitGutter = (string text) => buf.printDiagnostic("\x1b[34m", text, "\x1b[0m");
    renderer.emitSquiggle = (string text) => buf.printDiagnostic("\x1b[31m", text, "\x1b[0m");
    renderer.getSourceCode = (int lineNumber) => lines[lineNumber - firstLineNumber];

    renderer.emitMessageSingleLine = (ref Message message) {
        if (message.id > 0 && message.id <= messagesText.length)
            buf.printDiagnostic(messagesText[message.id - 1]);
    };
    renderer.emitMessageMultiLine = (scope void delegate(bool isLast) beforeTextOnLine,
            ref Message message) {
        if (message.id > 0 && message.id <= messagesText.length)
        {
            string text1 = messagesText[message.id - 1];
            size_t done;

            foreach (text2; text1.lineSplitter!(Yes.keepTerminator))
            {
                done += text2.length;
                const isLast = done == text1.length;

                beforeTextOnLine(isLast);
                buf.printDiagnostic(text2);

                if (isLast)
                    buf.writeByte('\n');
            }
        }
    };
    renderer.render();
    fflush(stderr);
}

void printDiagnostic(ref OutBuffer buf, string[] arr...)
{
    foreach(s; arr)
        buf.write(s);
}
