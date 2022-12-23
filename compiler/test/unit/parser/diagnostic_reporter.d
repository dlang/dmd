// See ../../README.md for information about DMD unit tests.

module parser.diagnostic_reporter;

import core.stdc.stdarg;

import dmd.frontend : parseModule;
import dmd.globals : global, DiagnosticReporting;
import dmd.location;

import support : afterEach, beforeEach, NoopDiagnosticReporter;

@beforeEach initializeFrontend()
{
    import dmd.frontend : initDMD;
    initDMD();
}

@afterEach deinitializeFrontend()
{
    import dmd.frontend : deinitializeDMD;
    deinitializeDMD();
}

@("errors: duplicated `deprecated` attribute for module declaration")
unittest
{
    static class ErrorCountingDiagnosticReporter : NoopDiagnosticReporter
    {
        int errorCount;

        override bool error(const ref Loc, const(char)*, va_list, const(char)*, const(char)*)
        {
            errorCount++;
            return true;
        }
    }

    scope reporter = new ErrorCountingDiagnosticReporter;

    parseModule("test.d", q{
        deprecated deprecated module test;
    });

    assert(reporter.errorCount == 1);
}

@("errors supplemental: there's no `static else`, use `else` instead")
unittest
{
    static class ErrorSupplementalCountingDiagnosticReporter : NoopDiagnosticReporter
    {
        int supplementalCount;

        override bool errorSupplemental(const ref Loc, const(char)*, va_list, const(char)*, const(char)*)
        {
            supplementalCount++;
            return true;
        }
    }

    scope reporter = new ErrorSupplementalCountingDiagnosticReporter;

    parseModule("test.d", q{
        void main()
        {
            static if (true) {}
            static else {}
        }
    });

    assert(reporter.supplementalCount == 1);
}

@("warnings: dangling else")
unittest
{
    static class WarningCountingDiagnosticReporter : NoopDiagnosticReporter
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

    parseModule("test.d", q{
        void main()
        {
        	if (true)
        		if (false)
        			assert(3);
            else
                assert(4);
        }
    });

    assert(reporter.warningCount == 1);
}
