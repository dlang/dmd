// See ../../README.md for information about DMD unit tests.

module lexer.diagnostic_reporter;

import core.stdc.stdarg;

import dmd.globals : Loc, global, DiagnosticReporting;

import support : afterEach, NoopDiagnosticReporter;

@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

@("errors: unterminated /* */ comment")
unittest
{
    static final class ErrorCountingDiagnosticReporter : NoopDiagnosticReporter
    {
        int errorCount;

        override bool error(const ref Loc, const(char)*, va_list, const(char)*, const(char)*)
        {
            errorCount++;
            return true;
        }
    }

    scope reporter = new ErrorCountingDiagnosticReporter;
    lexUntilEndOfFile("/*");

    assert(reporter.errorCount == 1);
}

@("warnings: C preprocessor directive")
unittest
{
    static final class WarningCountingDiagnosticReporter : NoopDiagnosticReporter
    {
        int warningCount;

        override bool warning(const ref Loc, const(char)*, va_list, const(char)*, const(char)*)
        {
            warningCount++;
            return true;
        }
    }

    global.params.warnings = DiagnosticReporting.inform;
    scope reporter = new WarningCountingDiagnosticReporter;
    lexUntilEndOfFile(`#foo`);

    assert(reporter.warningCount == 1);
}

private void lexUntilEndOfFile(string code)
{
    import dmd.lexer : Lexer;
    import dmd.tokens : TOK;

    scope lexer = new Lexer("test", code.ptr, 0, code.length, 0, 0);
    lexer.nextToken;

    while (lexer.nextToken != TOK.endOfFile) {}
}
