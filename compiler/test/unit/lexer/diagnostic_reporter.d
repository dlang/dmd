// See ../../README.md for information about DMD unit tests.

module lexer.diagnostic_reporter;

import core.stdc.stdarg;

import dmd.globals : global, DiagnosticReporting;
import dmd.location;
import dmd.errors;

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

private void lexUntilEndOfFile(string code)
{
    import dmd.lexer : Lexer;
    import dmd.tokens : TOK;

    if (!global.errorSink)
	global.errorSink = new ErrorSinkCompiler;
    scope lexer = new Lexer("test", code.ptr, 0, code.length, 0, 0, global.errorSink, null);
    lexer.nextToken;

    while (lexer.nextToken != TOK.endOfFile) {}
}
