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

    void delegate(string) emitRaw;
    void delegate(const(char)* fmt, ...) emitRawFormat;
    // num | << it is the |
    void delegate(string) emitMargin;
    // error:
    void delegate() emitHeader;
    // For multiline error messages, first is emitError.
    void delegate() emitHeaderMultiLinePrefix;
    void delegate() emitFooter;
    void delegate() emitFooterMultiLinePrefix;
    void delegate() emitHelp;
    void delegate() emitHelpMultiLinePrefix;

    // The ASCII art
    void delegate(string text) emitGutter;
    void delegate(string text) emitSquiggle;

    string delegate(int lineNumber) getSourceCode;

    void delegate(ref Message message) emitMessageSingleLine;
    void delegate(scope void delegate(bool isLast) beforeTextOnLine, ref Message message) emitMessageMultiLine;

    private
    {
        int minLineNumber;
        string columnWithoutNumber;
        string columnNumberFormat;

        // temporary
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

    void render() 
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

    void calculate()
    {
        import core.stdc.stdio;
        import core.stdc.string : strlen;
        // import std.conv : text;
        // import std.uni;
        // import std.algorithm : sort;

        int maxLineNumber;
        minLineNumber = int.max;

        foreach (i, diag; diagnostics)
        {
            diag.originalOffset = i;

            if (diag.start < minLineNumber)
                minLineNumber = diag.start;
            if (diag.end > maxLineNumber)
                maxLineNumber = diag.end;
        }
        // diagnostics.sort!((a, b) => a.start < b.start || (a.start == b.start && a.end < b.end));

        void sortDiagnostics(ref Diagnostic[] diagnostics) // bubble sort to sort diagnostics
        {
            for(int i=0; i<diagnostics.length; i++)
            {
                bool swapped = false;
                for(int j=i+1; j<diagnostics.length; j++)
                {
                    if(diagnostics[j].start < diagnostics[i].start || (diagnostics[j].start == diagnostics[i].start 
                        && diagnostics[j].end < diagnostics[i].end))
                    {
                        Diagnostic temp = diagnostics[j];
                        diagnostics[j] = diagnostics[i];
                        diagnostics[i] = temp;
                        swapped = true;
                    }
                }
                if(!swapped)
                    break;
            }
        }
        sortDiagnostics(diagnostics);

        // Calculate the line number length, to get the required with and without number strings.
        {
            int lineNumberLength = snprintf(null, 0, "%d", maxLineNumber);

            char[] temp;
            temp.length = lineNumberLength;
            temp[] = ' ';

            columnWithoutNumber = cast(string) temp;

            char[16] buf;
            snprintf(buf.ptr,buf.length,"%d",lineNumberLength);

            columnNumberFormat = cast(string) buf[0 .. strlen(buf.ptr)];
        }
    }

    void emitHeader2()
    {
        bool doneFirst;

        void beforeTextOnLine(bool isLast)
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
            emitRawFormat("(%d)\n", minLineNumber);
        }
    }

    void emitMainDiag()
    {
        lastLineNumber = 0;
        TimeLineGeometry(diagnostics, 3, 1, &columnDrawHandler,
                &columnEmptyHandler, &onLineStart, &onLineEnd, &onLineSource,
                &onLinesSkippedBeforeMargin, &onLinesSkippedAfterMargin,
                &graphemesBetweenPositions, &lineHighlight, &printSingleLine, &printMultiLine)
            .calculate;
    }

    void emitFooter2()
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

        void beforeTextOnLine(bool isLast)
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
                    emitRaw("  ");
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

    void emitHelp2()
    {
        bool doneFirst;

        void beforeTextOnLine(bool isLast)
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
                    emitRaw("  ");
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

        void emitMessage(ref Message message)
        {
            if (message.id == 0)
                return;

            doneFirst = false;

            if (message.isMultiline)
            {
                emitMessageMultiLine(&beforeTextOnLine, message);
            }
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

    void columnDrawHandler(int line, ref Diagnostic, LineClassification classification)
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
            bool previousLineColumnIsActive)
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

    void onLineStart(int line)
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

    void onLineEnd(int line)
    {
        emitRaw("\n");
    }

    void onLineSource(int line)
    {
        emitRaw(getSourceCode(line));
    }

    void onLinesSkippedAfterMargin(int startLine, int endLine)
    {
        emitRawFormat("%.*s(%d)", cast(int) filename.length, filename.ptr, endLine);
    }

    uint graphemesBetweenPositions(int line, int startColumn, int endColumn,
            ref Diagnostic diag, ref Message message)
    {
        // import std.uni;
        import dmd.root.utf;

        string text = getSourceCode(line);

        if (text.length < startColumn || text.length < endColumn)
            return 0;

        text = text[startColumn .. endColumn];
        uint count;
        size_t i = startColumn;

        /*foreach (_; text.byGrapheme)
        {
            count++;
        }*/
        while(i<endColumn)
        {
            dchar c;
            if(utf_decodeChar(text,i,c) !is null)
            {
                break;
            }
            count++;
        }

        return count;
    }

    void lineHighlight(int line, int offsetToSquiggles, int numberOfSquiggles,
            ref Diagnostic diag, ref Message message, bool spansMultipleLines)
    {
        string offsetToSquigglesText = spansMultipleLines ? config.gutterToLabel : " ";

        foreach (_; 0 .. offsetToSquiggles)
        {
            emitGutter(offsetToSquigglesText);
        }

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

    void printSingleLine(int line, ref Diagnostic diag, ref Message message)
    {
        emitRaw(" ");
        emitMessageSingleLine(message);
    }

    void onLinesSkippedBeforeMargin(int startLine, int endLine)
    {
        emitRaw(columnWithoutNumber);
        emitRaw(" ");
        emitMargin(config.skippedLines);
        emitRaw(" ");
    }

    void printMultiLine(scope void delegate() printMargin, uint offsetToMessage, int line,
            int offsetToSquiggles, int numberOfSquiggles, ref Diagnostic diag, ref Message message)
    {
        void beforeTextOnLine(bool isLast)
        {
            onLineStart(line);
            printMargin();

            foreach (_; 0 .. offsetToMessage)
                emitRaw(" ");
        }

        emitMessageMultiLine(&beforeTextOnLine, message);
    }
}