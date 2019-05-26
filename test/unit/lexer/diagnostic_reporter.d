module lexer.diagnostic_reporter;

import core.stdc.stdarg;

import dmd.errors : DiagnosticReporter;
import dmd.globals : Loc;

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

        override void error(const ref Loc, const(char)*, va_list)
        {
            errorCount++;
        }
    }

    scope reporter = new ErrorCountingDiagnosticReporter;
    lexUntilEndOfFile("/*", reporter);

    assert(reporter.errorCount == 1);
}

@("warnings: C preprocessor directive")
unittest
{
    static final class WarningCountingDiagnosticReporter : NoopDiagnosticReporter
    {
        int warningCount;

        override void warning(const ref Loc, const(char)*, va_list)
        {
            warningCount++;
        }
    }

    scope reporter = new WarningCountingDiagnosticReporter;
    lexUntilEndOfFile(`#foo`, reporter);

    assert(reporter.warningCount == 1);
}

@("deprecations: Invalid integer")
unittest
{
    static final class DeprecationsCountingDiagnosticReporter : NoopDiagnosticReporter
    {
        int deprecationCount;

        override void deprecation(const ref Loc, const(char)*, va_list)
        {
            deprecationCount++;
        }
    }

    scope reporter = new DeprecationsCountingDiagnosticReporter;
    lexUntilEndOfFile(`auto a = 0b;`, reporter);

    assert(reporter.deprecationCount == 1);
}

private void lexUntilEndOfFile(string code, DiagnosticReporter reporter)
{
    import dmd.lexer : Lexer;
    import dmd.tokens : TOK;

    scope lexer = new Lexer("test", code.ptr, 0, code.length, 0, 0, reporter);
    lexer.nextToken;

    while (lexer.nextToken != TOK.endOfFile) {}
}
