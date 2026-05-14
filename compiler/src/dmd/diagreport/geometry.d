/**
    Defines the elements of the geometry of the diagnostic reporting mechanism
**/
module dmd.diagreport.geometry;
import dmd.diagreport.defs;

struct TimeLineGeometry
{
    Diagnostic[] diagnostics;

    int minToSkip;
    int toSkipBuffer;

    void delegate(int line, ref Diagnostic, LineClassification classification) nothrow columnDrawHandler;
    void delegate(int line, bool haveStartOrEndColumnsToLeft, bool previousLineColumnIsActive) nothrow columnEmptyHandler;
    void delegate(int line) nothrow onLineStart;
    void delegate(int line) nothrow onLineEnd;
    void delegate(int line) nothrow onLineSource;
    void delegate(int startLine, int endLine) nothrow onLinesSkippedBeforeMargin;
    void delegate(int startLine, int endLine) nothrow onLinesSkippedAfterMargin;
    uint delegate(int line, int startColumn, int endColumn, ref Diagnostic diag, ref Message message) nothrow graphemesBetweenPositions;
    void delegate(int line, int offsetToSquiggles, int numberOfSquiggles,
            ref Diagnostic diag, ref Message message, bool spansMultipleLines) nothrow lineHighlight;
    void delegate(int line, ref Diagnostic diag, ref Message message) nothrow printSingleLine;
    void delegate(scope void delegate() nothrow printMargin, uint offsetToMessage, int line,
        int offsetToSquiggles, int numberOfSquiggles, ref Diagnostic diag, ref Message message) nothrow printMultiLine;

    void calculate() nothrow
    {
        assignColumns;

        int lineNumber = diagnostics[0].start;
        int allowBeforeSkipTo;
        int skipTo;

        for (;;)
        {
            int lastColumnEmitted = -numberOfTokenColumns;
            int minimumActiveColumn = -numberOfTokenColumns;
            int numberOfEventsForThisLine;
            int nextActiveLine = int.max;

            if (allowBeforeSkipTo > 0)
            {
                allowBeforeSkipTo--;

                if (allowBeforeSkipTo == 0)
                {
                    onLinesSkippedBeforeMargin(lineNumber, skipTo);
                    processDiagnosticLineEvents(lineNumber, 0,
                            lastColumnEmitted, true, false, false);
                    onLinesSkippedAfterMargin(lineNumber, skipTo);
                    this.onLineEnd(lineNumber);

                    lineNumber = skipTo;
                    continue;
                }
            }
            else
            {
                foreach (ref diag; diagnostics)
                {
                    bool startEndOnlyRange;
                    const classification = calculateLineClassification(diag,
                            lineNumber, startEndOnlyRange);

                    if (classification != LineClassification.Inactive)
                    {
                        if (diag.column < minimumActiveColumn)
                            minimumActiveColumn = diag.column;

                        if (classification != LineClassification.SpanContinue)
                            numberOfEventsForThisLine++;
                    }

                    if (diag.end >= lineNumber)
                    {
                        const nextLine = diag.start >= lineNumber ? diag.start : diag.end;
                        if (nextLine < nextActiveLine)
                            nextActiveLine = nextLine;
                    }
                }

                if (nextActiveLine == int.max)
                    break;
                else if (nextActiveLine - lineNumber > minToSkip)
                {
                    allowBeforeSkipTo = toSkipBuffer;
                    skipTo = nextActiveLine - toSkipBuffer;
                }
            }

            {
                onLineStart(lineNumber);

                processDiagnosticLineEvents(lineNumber, minimumActiveColumn,
                        lastColumnEmitted, true, false, false);

                onLineSource(lineNumber);
                onLineEnd(lineNumber);

                lastColumnEmitted = -numberOfTokenColumns;
            }

            while ((numberOfColumns == 0 || lastColumnEmitted < numberOfColumns)
                    && numberOfEventsForThisLine > 0)
            {
                onLineStart(lineNumber);
                processDiagnosticLineEvents(lineNumber, minimumActiveColumn,
                        lastColumnEmitted, false, false, true);

                numberOfEventsForThisLine--;
            }

            lineNumber++;
        }
    }

private:
    int numberOfColumns;
    int numberOfTokenColumns;

    void assignColumns() nothrow
    {
        {
            foreach (diag1; diagnostics)
            {
                if (diag1.start == diag1.end)
                {
                    uint overlappingDiagCount;

                    foreach (diag2; diagnostics)
                    {
                        if (diag2.start != diag2.end || diag1.start != diag2.start)
                            continue;
                        overlappingDiagCount++;
                    }

                    if (overlappingDiagCount > numberOfTokenColumns)
                        numberOfTokenColumns = overlappingDiagCount;
                }
                else
                {
                    uint overlappingDiagCount;

                    foreach (diag2; diagnostics)
                    {
                        if (diag2.start == diag2.end)
                            continue;
                        else if (diag1.end < diag2.start)
                            break;

                        if (diag1.start <= diag2.end && diag1.end > diag2.start)
                            overlappingDiagCount++;
                    }

                    if (overlappingDiagCount > numberOfColumns)
                        numberOfColumns = overlappingDiagCount;
                }
            }
        }

        if (numberOfTokenColumns + numberOfColumns > 0)
        {
            int[] columnReleaseLine = new int[numberOfTokenColumns + numberOfColumns];

            foreach (ref diag; diagnostics)
            {
                bool assigned;

                if (diag.start == diag.end)
                {
                    if (numberOfTokenColumns > 1)
                    {
                        foreach (column; 0 .. numberOfTokenColumns)
                        {
                            if (diag.start <= columnReleaseLine[column])
                                continue;

                            diag.column = column - numberOfTokenColumns;
                            columnReleaseLine[column] = diag.end;
                            assigned = true;
                            break;
                        }
                    }
                    else
                    {
                        diag.column = -1;
                        assigned = true;
                    }
                }
                else if (numberOfColumns > 1)
                {
                    foreach (column; numberOfTokenColumns .. numberOfColumns + 1)
                    {
                        if (diag.start <= columnReleaseLine[column])
                            continue;

                        diag.column = column - numberOfTokenColumns;
                        columnReleaseLine[column] = diag.end;
                        assigned = true;
                        break;
                    }
                }
                else
                    assigned = true;

                assert(assigned);
            }
        }

        if (numberOfColumns > 0)
            numberOfColumns++;
    }

    void processDiagnosticLineEvents(int lineNumber, int minimumActiveColumn,
            ref int lastColumnEmitted, bool noStartEndAsInactive,
            bool noStartEndAsContinue, bool withUser) nothrow
    {
        int emittedDiags = lastColumnEmitted;
        const ifCalledMoreThanOnceForLine = lastColumnEmitted > numberOfTokenColumns;
        scope (exit)
            lastColumnEmitted = emittedDiags;

        Diagnostic* findActiveDiagInColumn(int lineNumber, int col,
                out LineClassification classification, out bool startEndOnlyRange) nothrow
        {
            if (lineNumber == 0)
                return null;

            foreach (ref diag; diagnostics)
            {
                if (diag.column != col)
                    continue;

                classification = calculateLineClassification(diag, lineNumber, startEndOnlyRange);
                if (classification != LineClassification.Inactive)
                    return &diag;
            }

            return null;
        }

        void emptyColumn(int onLine, int columnNumber, bool haveStartOrEndColumnsToLeft) nothrow
        {
            if (columnNumber < 0)
                return;

            LineClassification classification;
            bool startEndOnlyRange;
            // Diagnostic* diag = findActiveDiagInColumn(onLine, columnNumber, classification, startEndOnlyRange);
            const isActive = classification == LineClassification.SpanStart
                || classification == LineClassification.SpanContinue;

            columnEmptyHandler(lineNumber, haveStartOrEndColumnsToLeft, isActive);
        }

        void printMargin() nothrow
        {
            int tempMaxDiagsEmitted = emittedDiags + 1;
            processDiagnosticLineEvents(lineNumber, minimumActiveColumn,
                    tempMaxDiagsEmitted, false, true, false);
        }

        void userMessage(ref Diagnostic diag, ref Message message, bool spansMultipleLines) nothrow
        {
            if (!withUser)
                return;

            const offsetToSquiggles = this.graphemesBetweenPositions(lineNumber,
                    0, message.startColumn, diag, message);
            const lengthOfSquiggles = this.graphemesBetweenPositions(lineNumber,
                    message.startColumn, message.endColumn, diag, message);

            lineHighlight(lineNumber, offsetToSquiggles, lengthOfSquiggles,
                    diag, message, spansMultipleLines);

            if (message.isMultiline)
            {
                this.onLineEnd(lineNumber);

                printMultiLine(&printMargin, offsetToSquiggles, lineNumber,
                        offsetToSquiggles, lengthOfSquiggles, diag, message);
            }
            else
            {
                this.printSingleLine(lineNumber, diag, message);
                this.onLineEnd(lineNumber);
            }
        }

        foreach (int column; 0 .. minimumActiveColumn)
            columnEmptyHandler(lineNumber, false, false);

        for (int column = minimumActiveColumn; column < numberOfColumns; column++)
        {
            LineClassification classification;
            bool startEndOnlyRange;
            Diagnostic* currentDiag = findActiveDiagInColumn(lineNumber,
                    column, classification, startEndOnlyRange);

            if (column < lastColumnEmitted)
                classification = LineClassification.Inactive;
            else if (noStartEndAsInactive)
            {
                final switch (classification)
                {
                case LineClassification.SpanStart:
                case LineClassification.SpanStartEnd:
                case LineClassification.SpanEnd:
                    classification = LineClassification.Inactive;
                    break;
                case LineClassification.SpanContinue:
                case LineClassification.Inactive:
                    break;
                }
            }
            else if (noStartEndAsContinue)
            {
                final switch (classification)
                {
                case LineClassification.SpanStart:
                    classification = LineClassification.SpanContinue;
                    break;
                case LineClassification.SpanStartEnd:
                    classification = LineClassification.Inactive;
                    break;
                case LineClassification.SpanEnd:
                    classification = (column < lastColumnEmitted)
                        ? LineClassification.Inactive : LineClassification.SpanContinue;
                    break;
                case LineClassification.SpanContinue:
                case LineClassification.Inactive:
                    break;
                }
            }

            final switch (classification)
            {
            case LineClassification.SpanStart:
            case LineClassification.SpanEnd:
            case LineClassification.SpanStartEnd:

                if (column >= 0)
                    columnDrawHandler(lineNumber, *currentDiag, classification);
                emittedDiags++;

                const haveBefore = classification != LineClassification.SpanStartEnd;

                foreach (column2; column + 1 .. numberOfColumns)
                {
                    LineClassification classification2;
                    bool startEndOnlyRange2;
                    Diagnostic* currentDiag2 = findActiveDiagInColumn(lineNumber,
                            column2, classification2, startEndOnlyRange2);

                    if (startEndOnlyRange2)
                        columnDrawHandler(lineNumber, *currentDiag2, classification2);
                    else
                        emptyColumn(lineNumber - 1, column2, haveBefore);
                }

                userMessage(*currentDiag, classification == LineClassification.SpanEnd
                        ? currentDiag.endMessage : currentDiag.startMessage, haveBefore);
                return;

            case LineClassification.SpanContinue:
                columnDrawHandler(lineNumber, *currentDiag, classification);
                emittedDiags++;
                break;

            case LineClassification.Inactive:
                emptyColumn(lineNumber - (!ifCalledMoreThanOnceForLine
                        && !noStartEndAsContinue), column, false);
                emittedDiags++;
                break;
            }
        }
    }
}

private:

LineClassification calculateLineClassification(ref Diagnostic diagnostic,
        int lineNumber, out bool startEndOnlyRange) nothrow
{
    if (lineNumber < diagnostic.start || lineNumber > diagnostic.end)
        return LineClassification.Inactive;

    const isStart = (lineNumber == diagnostic.start), isEnd = (lineNumber == diagnostic.end);
    LineClassification ret;

    if (isStart && isEnd)
        ret = LineClassification.SpanStartEnd;
    else if (isStart)
        ret = LineClassification.SpanStart;
    else if (isEnd)
        ret = LineClassification.SpanEnd;
    else
        ret = LineClassification.SpanContinue;

    final switch (ret)
    {
    case LineClassification.SpanStart:
        if (diagnostic.startMessage.startColumn == 0
                && diagnostic.startMessage.endColumn == 0 && diagnostic.startMessage.id == 0)
            startEndOnlyRange = true;
        break;
    case LineClassification.SpanEnd:
        if (diagnostic.endMessage.startColumn == 0
                && diagnostic.endMessage.endColumn == 0 && diagnostic.endMessage.id == 0)
            startEndOnlyRange = true;
        break;

    case LineClassification.SpanStartEnd:
    case LineClassification.SpanContinue:
    case LineClassification.Inactive:
        break;
    }

    if (startEndOnlyRange)
        ret = LineClassification.SpanContinue;

    return ret;
}
