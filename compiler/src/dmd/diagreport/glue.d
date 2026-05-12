module dmd.diagreport.glue;

import core.stdc.stdio : vsnprintf, fwrite, fflush, stderr;
import core.stdc.stdarg;
import core.stdc.string : strlen;
import dmd.common.outbuffer;
import dmd.diagreport.defs;
import dmd.diagreport.geometry;
import dmd.diagreport.renderer;
import dmd.errors;
import dmd.globals;
import dmd.location;

dmd.diagreport.defs.Diagnostic convert(dmd.errors.Diagnostic d) nothrow
{
    dmd.diagreport.defs.Diagnostic obj;
    obj.start = d.loc.line;
    obj.end = d.loc.line;

    const startCol = cast(int) getMessageStartColumn(d.loc.fileContent, d.loc.fileOffset);
    obj.startMessage.startColumn = startCol;
    obj.startMessage.endColumn = startCol + getTokenLength(d.loc.fileContent, d.loc.fileOffset);
    obj.startMessage.isMultiline = false;
    return obj;
}

void callEvent(ref dmd.errors.Diagnostic[] group) nothrow
{
    if (group.length == 0) return;

    auto primary = group[0];

    dmd.diagreport.defs.Diagnostic[] diags;
    string[] messages;

    try
    {
        foreach (i, ref d; group)
        {
            auto diag = convert(d);
            diag.startMessage.id = i + 1;
            diags ~= diag;
            messages ~= d.message;
        }
    }
    catch (Exception) { return; }

    event(cast(string) primary.loc.filename, cast(string) primary.loc.fileContent, diags, messages, null);
}

void event(string filename, string source, dmd.diagreport.defs.Diagnostic[] diagnostics, string[] messagesText, dmd.diagreport.defs.Help[] help) nothrow
{
    OutBuffer buf;

    string[] lines = splitLines(source);

    Renderer renderer;
    renderer.filename = filename;
    renderer.diagnostics = diagnostics;
    renderer.help = help;

    int firstLineNumber = 1; // for 1 based indexing

    renderer.emitRaw = (string text) nothrow
        => buf.printDiagnostic(text);

    renderer.emitRawFormat = (const(char)* fmt, ...) nothrow
    {
        va_list args;
        va_start(args, fmt);
        char[64] tmp = void;
        int n = vsnprintf(tmp.ptr, tmp.length, fmt, args);
        va_end(args);
        if (n > 0)
            buf.printDiagnostic(cast(string) tmp[0 .. n]);
    };

    if(global.params.v.color)
    {
        renderer.emitMargin = (string text) nothrow
            => buf.printDiagnostic("\x1b[33m", text, "\x1b[0m");

        renderer.emitHeader = () nothrow
            => buf.printDiagnostic("\x1b[31merror\x1b[0m: ");

        renderer.emitHeaderMultiLinePrefix = () nothrow
            => buf.printDiagnostic("       ");

        renderer.emitFooter = () nothrow
            => buf.printDiagnostic("\x1b[34mnote:\x1b[0m ");

        renderer.emitFooterMultiLinePrefix = () nothrow
            => buf.printDiagnostic("      ");

        renderer.emitHelp = () nothrow
            => buf.printDiagnostic("\x1b[34mhelp:\x1b[0m ");

        renderer.emitHelpMultiLinePrefix = () nothrow
            => buf.printDiagnostic("      ");

        renderer.emitGutter = (string text) nothrow
            => buf.printDiagnostic("\x1b[34m", text, "\x1b[0m");

        renderer.emitSquiggle = (string text) nothrow
            => buf.printDiagnostic("\x1b[31m", text, "\x1b[0m");
    }
    else
    {
        renderer.emitMargin = (string text) nothrow
            => buf.printDiagnostic(text);
        renderer.emitHeader = () nothrow
            => buf.printDiagnostic("error: ");
        renderer.emitHeaderMultiLinePrefix = () nothrow
            => buf.printDiagnostic("       ");
        renderer.emitFooter = () nothrow
            => buf.printDiagnostic("note: ");
        renderer.emitFooterMultiLinePrefix = () nothrow
            => buf.printDiagnostic("      ");
        renderer.emitHelp = () nothrow
            => buf.printDiagnostic("help: ");
        renderer.emitHelpMultiLinePrefix = () nothrow
            => buf.printDiagnostic("      ");
        renderer.emitGutter = (string text) nothrow
            => buf.printDiagnostic(text);
        renderer.emitSquiggle = (string text) nothrow
            => buf.printDiagnostic(text);
    }

    renderer.getSourceCode = (int lineNumber) nothrow @trusted
    {
        int idx = lineNumber - firstLineNumber;
        if (idx < 0 || idx >= lines.length)
            return "";
        return lines[idx];
    };

    renderer.emitMessageSingleLine = (ref Message message) nothrow
    {
        if (message.id > 0 && message.id <= messagesText.length)
            buf.printDiagnostic(messagesText[message.id - 1]);
    };

    renderer.emitMessageMultiLine = (scope void delegate(bool isLast) nothrow beforeTextOnLine,
            ref Message message) nothrow @trusted
    {
        if (message.id == 0 || message.id > messagesText.length)
            return;

        string text1 = messagesText[message.id - 1];
        size_t start = 0;

        while (start < text1.length)
        {
            size_t i = start;
            while (i < text1.length && text1[i] != '\n' && text1[i] != '\r')
                i++;

            if (i < text1.length)
            {
                if (text1[i] == '\r' && i + 1 < text1.length && text1[i + 1] == '\n')
                    i += 2;
                else
                    i += 1;
            }

            string text2 = text1[start .. i];
            start = i;
            const isLast = (start == text1.length);

            beforeTextOnLine(isLast);
            buf.printDiagnostic(text2);

            if (isLast)
                buf.writeByte('\n');
        }
    };

    renderer.render();

    const data = buf[];
    fwrite(data.ptr, 1, data.length, stderr);
    fflush(stderr);
}

// Split source into lines without Phobos
private string[] splitLines(string source) nothrow
{
    string[] result;
    auto range = LineRange(source);
    while (!range.empty)
    {
        try { result ~= range.front(); }
        catch (Exception) { break; }
        range.popFront();
    }
    return result;
}

void printDiagnostic(ref OutBuffer buf, string[] arr...) nothrow
{
    foreach (s; arr)
        buf.write(s);
}

size_t getMessageStartColumn(const(char)[] text, size_t offset) nothrow @safe
{
    import dmd.root.utf : utf_decodeChar;

    if (offset >= text.length)
        return 0;

    size_t s = offset;
    while (s > 0 && text[s - 1] != '\n')
        s--;

    const line = text[s .. $];
    const byteColumn = offset - s;
    enum tabWidth = 4;

    size_t currentColumn = 0;
    size_t caretColumn = 0;
    for (size_t i = 0; i < line.length; )
    {
        dchar u;
        const start = i;
        const msg = utf_decodeChar(line, i, u);
        assert(msg is null, msg);
        if (u == '\t')
            currentColumn += tabWidth - (currentColumn % tabWidth);
        else if (u == '\r' || u == '\n')
            break;
        else
            currentColumn++;

        if (start < byteColumn)
            caretColumn = currentColumn;
    }
    return caretColumn;
}

struct LineRange
{
    private const(char)[] content;
    private size_t pos;

    this(const(char)[] source) nothrow { content = source; }
    bool empty() const nothrow { return pos >= content.length; }

    string front() const nothrow
    {
        size_t end = pos;
        while (end < content.length && content[end] != '\n' && content[end] != '\r')
            end++;
        return cast(string) content[pos .. end];
    }

    void popFront() nothrow
    {
        while (pos < content.length && content[pos] != '\n' && content[pos] != '\r')
            pos++;
        if (pos < content.length && content[pos] == '\r')
            pos++;
        if (pos < content.length && content[pos] == '\n')
            pos++;
    }
}

private int getTokenLength(const(char)[] text, size_t offset) nothrow @safe
{
    import dmd.root.utf : utf_decodeChar;

    if (offset >= text.length)
        return 1;

    // Find start of line
    size_t s = offset;
    while (s > 0 && text[s - 1] != '\n')
        s--;

    // Scan forward from offset to end of token
    // Simple heuristic: scan until whitespace, punctuation, or end of line
    size_t i = offset;
    int count = 0;

    while (i < text.length)
    {
        dchar c;
        const prev = i;
        if (utf_decodeChar(text, i, c) !is null)
            break;
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r' ||
            c == ',' || c == ';' || c == ')' || c == '(' ||
            c == ']' || c == '[' || c == '{' || c == '}')
        {
            if (count == 0) count = 1;
            break;
        }
        count++;
    }

    return count == 0 ? 1 : count;
}
