/**
    Defines the vertical state of a diagnostic on a given line for drawing purposes.
    This enumeration captures the vertical state machine logic for a single diagnostic span.
*/
module dmd.diagreport.defs;

enum LineClassification
{
    /// The line is not part of the diagnostic span.
    Inactive,
    /// The line is the start of the span and continues below. Implies the previous line was Inactive.
    SpanStart,
    /// The line is between the start and end. Implies the previous line and next line are Active.
    SpanContinue,
    /// The line is the end of the span and no other active diagnostics follow it. Implies the next line is Inactive.
    SpanEnd,
    /// The span starts and ends on the same line (a one-line diagnostic).
    SpanStartEnd
}

struct Diagnostic
{
    /// The line number where the diagnostic span begins (inclusive).
    int start;
    /// The line number where the diagnostic span ends (inclusive).
    int end;

    Message startMessage;
    Message endMessage;

    size_t id;

    size_t offset()
    {
        return originalOffset;
    }

package:
    size_t originalOffset;
    int column;
}

struct Message
{
    int startColumn, endColumn;
    bool isMultiline;

    size_t id;
}

struct Help
{
    Diagnostic[] diagnostics;

    Message startMessage;
    Message endMessage;

    size_t id;
}
