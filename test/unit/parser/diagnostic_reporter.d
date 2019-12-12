module parser.diagnostic_reporter;

import core.stdc.stdarg;

import dmd.frontend : parseModule;
import dmd.globals : Loc;

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

        override void error(const ref Loc, const(char)*, va_list)
        {
            errorCount++;
        }
    }

    scope reporter = new ErrorCountingDiagnosticReporter;

    parseModule("test.d", q{
        deprecated deprecated module test;
    }, reporter);

    assert(reporter.errorCount == 1);
}

@("errors supplemental: there's no `static else`, use `else` instead")
unittest
{
    static class ErrorSupplementalCountingDiagnosticReporter : NoopDiagnosticReporter
    {
        int supplementalCount;

        override void errorSupplemental(const ref Loc, const(char)*, va_list)
        {
            supplementalCount++;
        }
    }

    scope reporter = new ErrorSupplementalCountingDiagnosticReporter;

    parseModule("test.d", q{
        void main()
        {
            static if (true) {}
            static else {}
        }
    }, reporter);

    assert(reporter.supplementalCount == 1);
}

@("warnings: dangling else")
unittest
{
    static class WarningCountingDiagnosticReporter : NoopDiagnosticReporter
    {
        int warningCount;

        override void warning(const ref Loc, const(char)*, va_list)
        {
            warningCount++;
        }
    }

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
    }, reporter);

    assert(reporter.warningCount == 1);
}

@("deprecations: extern(Pascal)")
unittest
{
    static class DeprecationsCountingDiagnosticReporter : NoopDiagnosticReporter
    {
        int deprecationCount;

        override void deprecation(const ref Loc, const(char)*, va_list)
        {
            deprecationCount++;
        }
    }

    scope reporter = new DeprecationsCountingDiagnosticReporter;

    parseModule("test.d", q{
        extern (Pascal) void foo();
    }, reporter);

    assert(reporter.deprecationCount == 1);
}
