module dmd.diagreport.app;

import core.stdc.stdio : vprintf, fflush, stderr;
import core.stdc.string;
import dmd.common.outbuffer;
import dmd.errors;
import dmd.diagreport.defs;
import dmd.diagreport.geometry;
import dmd.diagreport.renderer;
import dmd.location;
// import std.stdio;
// import std.conv;
import std.range;
// import std.array;
import std.string;


/// Function to convert dmd.errors.Diagnostic object to dmd.diagreport.defs.Diagnostic objects
dmd.diagreport.defs.Diagnostic convert(dmd.errors.Diagnostic d) nothrow
{
    dmd.diagreport.defs.Diagnostic obj;
    obj.start = d.loc.line;
    obj.end = d.loc.line;
    obj.originalOffset = d.loc.fileOffset;
    obj.startMessage.startColumn = cast(int) getMessageStartColumn(d.loc.fileContent, d.loc.fileOffset);
    obj.startMessage.isMultiline = false;
    return obj;
}

/// function to call event() for diagnostics
void callEvent(ref dmd.errors.Diagnostic[] diagnostics) nothrow
{
    foreach(d; diagnostics)
    {
        dmd.diagreport.defs.Diagnostic diag = convert(d);
        event(cast(string) d.loc.filename, cast(string) d.loc.fileContent, d.loc.line, [diag], [d.message], null);
    }
}

void event(string filename, string source, int firstLineNumber, dmd.diagreport.defs.Diagnostic[] diagnostics, string[] messagesText, Help[] help) nothrow
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

void printDiagnostic(ref OutBuffer buf, string[] arr...) nothrow
{
    foreach(s; arr)
        buf.write(s);
}

// Given an error happening in source code `text`and at index `offset`, get the offending line
// and a caret pointing to the error
size_t getMessageStartColumn(const(char)[] text, size_t offset) nothrow @safe
{
    import dmd.root.utf : utf_decodeChar;

    if (offset >= text.length)
        return 0; // Out of bounds (missing source content in SourceLoc)

    // Scan backwards for beginning of line
    size_t s = offset;
    while (s > 0 && text[s - 1] != '\n')
        s--;

    const line = text[s .. $];
    const byteColumn = offset - s; // column as reported in the error message (byte offset)
    enum tabWidth = 4;

    size_t currentColumn = 0;
    size_t caretColumn = 0; // actual display column taking into account tabs and unicode characters
    for (size_t i = 0; i < line.length; )
    {
        dchar u;
        const start = i;
        const msg = utf_decodeChar(line, i, u);
        assert(msg is null, msg);
        if (u == '\t')
        {
            // How many spaces until column is the next multiple of tabWidth
            const equivalentSpaces = tabWidth - (currentColumn % tabWidth);
            currentColumn += equivalentSpaces;
        }
        else if (u == '\r' || u == '\n')
            break;
        else
        {
            currentColumn++;
        }
        if (i <= byteColumn)
            caretColumn = currentColumn;
    }
    return caretColumn;
}
