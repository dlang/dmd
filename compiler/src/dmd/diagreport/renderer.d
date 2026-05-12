module dmd.diagreport.renderer;
import dmd.diagreport.defs;
import dmd.diagreport.geometry;

struct Renderer
{
    Config config;

    string filename;

    Message header;
    Diagnostic[] diagnostics;
    Message footer;
    Help[] help;

    void delegate(string) nothrow emitRaw;
    void delegate(const(char)* fmt, ...) nothrow emitRawFormat;
    void delegate(string) nothrow emitMargin;
    void delegate() nothrow emitHeader;
    void delegate() nothrow emitHeaderMultiLinePrefix;
    void delegate() nothrow emitFooter;
    void delegate() nothrow emitFooterMultiLinePrefix;
    void delegate() nothrow emitHelp;
    void delegate() nothrow emitHelpMultiLinePrefix;
    void delegate(string text) nothrow emitGutter;
    void delegate(string text) nothrow emitSquiggle;
    string delegate(int lineNumber) nothrow getSourceCode;
    void delegate(ref Message message) nothrow emitMessageSingleLine;
    void delegate(scope void delegate(bool isLast) nothrow beforeTextOnLine,
            ref Message message) nothrow emitMessageMultiLine;

    private
    {
        int primaryLineNumber;
        int minLineNumber;
        string columnWithoutNumber;
        string columnNumberFormat;

        int lastLineNumber;
    }

    /// Assumption, all members of this are one grapheme in size.
    struct Config
    {
        string margin = "│";
        string marginRight = "├";
        string marginToRight = "─";
        string marginUpLeft = "╮";
        string marginUpRight = "╭";
        string marginDownLeft = "╯";
        string marginDownRight = "╰";

        string skippedLines = "╌";

        string gutter = "│";
        string gutterUpRight = "┌";
        string gutterDownRight = "└";
        string gutterToLabel = "─";
        string gutterLeftRightUpDown = "┼";
        string gutterAsSquiggle = "┘";

        string squiggle = "^";
    }

    void render() nothrow
    {
        if (diagnostics.length == 0)
            return;

        calculate;
        emitHeader2;
        emitMainDiag;
        emitFooter2;
        emitHelp2;
    }

private:

    void calculate() nothrow
    {
        import core.stdc.stdio : snprintf;
        import core.stdc.string : strlen;

        int maxLineNumber;
        minLineNumber = int.max;
        primaryLineNumber = diagnostics[0].start;

        foreach (i, ref diag; diagnostics)
        {
            diag.originalOffset = i;

            if (diag.start < minLineNumber)
                minLineNumber = diag.start;
            if (diag.end > maxLineNumber)
                maxLineNumber = diag.end;
        }

        // Selection sort — avoids Phobos
        for (int i = 0; i < cast(int) diagnostics.length; i++)
        {
            for (int j = i + 1; j < cast(int) diagnostics.length; j++)
            {
                if (diagnostics[j].start < diagnostics[i].start ||
                   (diagnostics[j].start == diagnostics[i].start &&
                    diagnostics[j].end   <  diagnostics[i].end))
                {
                    Diagnostic tmp = diagnostics[i];
                    diagnostics[i] = diagnostics[j];
                    diagnostics[j] = tmp;
                }
            }
        }

        // Build columnWithoutNumber — spaces matching width of maxLineNumber
        {
            int lineNumberLength = snprintf(null, 0, "%d", maxLineNumber);

            char[] temp;
            try { temp.length = lineNumberLength; }
            catch (Exception) { temp = [' ']; }
            temp[] = ' ';
            columnWithoutNumber = cast(string) temp;
        }

        // Build columnNumberFormat — e.g. "%3d" for a 3-digit max line number
        {
            int lineNumberLength = snprintf(null, 0, "%d", maxLineNumber);
            char[32] buf;
            int n = snprintf(buf.ptr, buf.length, "%%%dd", lineNumberLength);

            char[] fmt;
            try { fmt = new char[n + 1]; }
            catch (Exception) { fmt = buf[0 .. n + 1]; }
            fmt[0 .. n] = buf[0 .. n];
            fmt[n] = '\0';
            columnNumberFormat = cast(string) fmt[0 .. n];
        }
    }

    void emitHeader2() nothrow
    {
        bool doneFirst;

        void beforeTextOnLine(bool isLast) nothrow
        {
            if (doneFirst)
                emitHeaderMultiLinePrefix();
            else
                emitHeader();

            doneFirst = true;
        }

        if (header.id > 0)
        {
            if (!header.isMultiline)
            {
                beforeTextOnLine(false);
                emitMessageSingleLine(header);
            }
            else
                emitMessageMultiLine(&beforeTextOnLine, header);
        }

        {
            emitRaw(columnWithoutNumber);
            emitRaw(" ");
            emitMargin(config.marginUpRight);
            emitRaw(" ");
            emitRaw(filename);
            emitRawFormat("(%d)\n", primaryLineNumber);
        }
    }

    void emitMainDiag() nothrow
    {
        lastLineNumber = 0;
        TimeLineGeometry(diagnostics, 3, 1, &columnDrawHandler,
                &columnEmptyHandler, &onLineStart, &onLineEnd, &onLineSource,
                &onLinesSkippedBeforeMargin, &onLinesSkippedAfterMargin,
                &graphemesBetweenPositions, &lineHighlight, &printSingleLine, &printMultiLine)
            .calculate;
    }

    void emitFooter2() nothrow
    {
        bool doneFirst;
        bool haveSomethingAfter;

        foreach (ref h; help)
        {
            if (h.startMessage.id != 0 || h.endMessage.id != 0)
            {
                haveSomethingAfter = true;
                break;
            }
        }

        void beforeTextOnLine(bool isLast) nothrow
        {
            emitRaw(columnWithoutNumber);

            if (doneFirst)
            {
                if (isLast && haveSomethingAfter)
                {
                    emitRaw(" ");
                    emitMargin(config.marginUpRight);
                    emitMargin(config.marginDownLeft);
                }
                else
                {
                    emitRaw(" ");
                    emitMargin(config.margin);
                }

                emitRaw(" ");
                emitFooterMultiLinePrefix();
            }
            else
            {
                if (isLast)
                {
                    emitRaw(" ");
                    emitMargin(config.marginRight);
                    emitMargin(config.marginToRight);
                }
                else
                {
                    emitRaw(" ");
                    emitMargin(config.marginDownRight);
                    emitMargin(config.marginUpLeft);
                }

                emitRaw(" ");
                emitFooter();
            }

            doneFirst = true;
        }

        if (footer.id > 0)
        {
            if (!footer.isMultiline)
            {
                beforeTextOnLine(true);
                emitMessageSingleLine(footer);
            }
            else
                emitMessageMultiLine(&beforeTextOnLine, footer);
        }
    }

    void emitHelp2() nothrow
    {
        bool doneFirst;

        void beforeTextOnLine(bool isLast) nothrow
        {
            emitRaw(columnWithoutNumber);

            if (doneFirst)
            {
                if (isLast && help.length > 0)
                {
                    emitRaw(" ");
                    emitMargin(config.marginUpRight);
                    emitMargin(config.marginDownLeft);
                }
                else
                {
                    emitRaw(" ");
                    emitMargin(config.margin);
                }

                emitRaw(" ");
                emitHelpMultiLinePrefix();
            }
            else
            {
                if (isLast)
                {
                    emitRaw(" ");
                    emitMargin(config.marginRight);
                    emitMargin(config.marginToRight);
                }
                else
                {
                    emitRaw(" ");
                    emitMargin(config.marginDownRight);
                    emitMargin(config.marginUpLeft);
                }

                emitRaw(" ");
                emitHelp();
            }

            doneFirst = true;
        }

        void emitMessage(ref Message message) nothrow
        {
            if (message.id == 0)
                return;

            doneFirst = false;

            if (message.isMultiline)
                emitMessageMultiLine(&beforeTextOnLine, message);
            else
            {
                beforeTextOnLine(true);
                emitMessageSingleLine(message);
                emitRaw("\n");
            }
        }

        foreach (h; help)
        {
            if (h.startMessage.id == 0 && h.endMessage.id == 0)
                continue;

            emitMessage(h.startMessage);

            lastLineNumber = 0;
            TimeLineGeometry(h.diagnostics, 3, 1, &columnDrawHandler,
                    &columnEmptyHandler, &onLineStart, &onLineEnd, &onLineSource,
                    &onLinesSkippedBeforeMargin, &onLinesSkippedAfterMargin,
                    &graphemesBetweenPositions, &lineHighlight,
                    &printSingleLine, &printMultiLine).calculate;

            emitMessage(h.endMessage);
        }
    }

    void columnDrawHandler(int line, ref Diagnostic, LineClassification classification) nothrow
    {
        string glyph;

        final switch (classification)
        {
        case LineClassification.SpanStart:
            glyph = config.gutterUpRight;
            break;
        case LineClassification.SpanContinue:
            glyph = config.gutter;
            break;
        case LineClassification.SpanEnd:
            glyph = config.gutterDownRight;
            break;
        case LineClassification.SpanStartEnd:
            glyph = " ";
            break;
        case LineClassification.Inactive:
            break;
        }

        if (glyph.length > 0)
            emitGutter(glyph);
    }

    void columnEmptyHandler(int line, bool haveStartOrEndColumnsToLeft,
            bool previousLineColumnIsActive) nothrow
    {
        string glyph;

        if (haveStartOrEndColumnsToLeft && previousLineColumnIsActive)
            glyph = config.gutterLeftRightUpDown;
        else if (previousLineColumnIsActive)
            glyph = config.gutter;
        else if (haveStartOrEndColumnsToLeft)
            glyph = config.gutterToLabel;
        else
            glyph = " ";

        if (glyph.length > 0)
            emitGutter(glyph);
    }

    void onLineStart(int line) nothrow
    {
        if (lastLineNumber == line)
            emitRaw(columnWithoutNumber);
        else
            emitRawFormat(columnNumberFormat.ptr, line);

        emitRaw(" ");
        emitMargin(config.gutter);
        emitRaw(" ");

        lastLineNumber = line;
    }

    void onLineEnd(int line) nothrow
    {
        emitRaw("\n");
    }

    void onLineSource(int line) nothrow
    {
        emitRaw(getSourceCode(line));
    }

    void onLinesSkippedBeforeMargin(int startLine, int endLine) nothrow
    {
        emitRaw(columnWithoutNumber);
        emitRaw(" ");
        emitMargin(config.skippedLines);
        emitRaw(" ");
    }

    void onLinesSkippedAfterMargin(int startLine, int endLine) nothrow
    {
        emitRawFormat("%.*s(%d)", cast(int) filename.length, filename.ptr, endLine);
    }

    uint graphemesBetweenPositions(int line, int startColumn, int endColumn,
            ref Diagnostic diag, ref Message message) nothrow
    {
        import dmd.root.utf : utf_decodeChar;

        string text = getSourceCode(line);

        if (text.length < startColumn || text.length < endColumn)
            return 0;

        text = text[startColumn .. endColumn];
        uint count;
        size_t i = 0;

        while (i < text.length)
        {
            dchar c;
            if (utf_decodeChar(text, i, c) !is null)
                break;
            count++;
        }

        return count;
    }

    void lineHighlight(int line, int offsetToSquiggles, int numberOfSquiggles,
            ref Diagnostic diag, ref Message message, bool spansMultipleLines) nothrow
    {
        string offsetToSquigglesText = spansMultipleLines ? config.gutterToLabel : " ";

        foreach (_; 0 .. offsetToSquiggles)
            emitGutter(offsetToSquigglesText);

        if (numberOfSquiggles > 1)
        {
            foreach (_; 0 .. numberOfSquiggles)
                emitSquiggle(config.squiggle);
        }
        else if (spansMultipleLines)
            emitGutter(config.gutterAsSquiggle);
        else
            emitSquiggle(config.squiggle);
    }

    void printSingleLine(int line, ref Diagnostic diag, ref Message message) nothrow
    {
        emitRaw(" ");
        emitMessageSingleLine(message);
    }

    void printMultiLine(scope void delegate() nothrow printMargin, uint offsetToMessage,
            int line, int offsetToSquiggles, int numberOfSquiggles,
            ref Diagnostic diag, ref Message message) nothrow
    {
        void beforeTextOnLine(bool isLast) nothrow
        {
            onLineStart(line);
            printMargin();

            foreach (_; 0 .. offsetToMessage)
                emitRaw(" ");
        }

        emitMessageMultiLine(&beforeTextOnLine, message);
    }
}
