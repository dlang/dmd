/**
 * Provides SARIF (Static Analysis Results Interchange Format) reporting functionality.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/sarif.d, sarif.d)
 * Coverage:    $(LINK2 https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/sarif.d, Code Coverage)
 *
 * Description:
 * - This module generates SARIF reports for DMD errors, warnings, and messages.
 * - It supports JSON serialization of SARIF tools, results, and invocations.
 * - The generated reports are compatible with SARIF 2.1.0 schema.
 */

module dmd.sarif;

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.string : strchr;

import dmd.errors;
import dmd.errorsink;
import dmd.globals;
import dmd.json : writeEscapeJSONString;
import dmd.location;
import dmd.common.outbuffer;

/**
 * Maps an `ErrorKind` value to its SARIF severity-level string.
 */
private string errorKindToString(ErrorKind kind) nothrow
{
    final switch (kind)
    {
        case ErrorKind.error: return "error";
        case ErrorKind.warning: return "warning";
        case ErrorKind.deprecation: return "note";
        case ErrorKind.tip: return "note";
        case ErrorKind.message: return "none";
    }
}

/**
 * Error sink that produces a SARIF 2.1.0 report.
 *
 * Inherits all gating logic (gag handling, error limit, warning/deprecation
 * modes) from $(D ErrorSinkCompiler). The only customisation is the output
 * format: $(D emit) appends a `results[]` entry to $(D buf), and $(D plugSink)
 * writes the complete SARIF document to `stdout` at the end of compilation.
 */
class ErrorSinkSarif : ErrorSinkCompiler
{
    /// Accumulates the `results` array entries (without surrounding `[ ]`).
    OutBuffer buf;

    private int resultCount;
    private bool plugged;

  nothrow:

    extern (C++) override void emit(const SourceLoc loc, const(char)* format, va_list ap,
        ErrorKind kind, bool supplemental, bool gagged)
    {
        // Gagged diagnostics are speculative; don't include them in the report.
        // Supplemental notes are folded into the primary entry by convention.
        if (gagged || supplemental)
            return;

        if (resultCount > 0)
            buf.writestring(",\n");
        resultCount++;

        OutBuffer msg;
        msg.vprintf(format, ap);

        const kindStr = errorKindToString(kind);
        const(char)[] uri = loc.filename;

        buf.printf(
            "\t\t\t{\n" ~
            "\t\t\t\t\"ruleId\": \"DMD-%s\",\n" ~
            "\t\t\t\t\"message\": {\n" ~
            "\t\t\t\t\t\"text\": \"",
            kindStr.ptr);
        writeEscapeJSONString(buf, msg[]);
        buf.printf(
            "\"\n" ~
            "\t\t\t\t},\n" ~
            "\t\t\t\t\"level\": \"%s\",\n" ~
            "\t\t\t\t\"locations\": [{\n" ~
            "\t\t\t\t\t\"physicalLocation\": {\n" ~
            "\t\t\t\t\t\t\"artifactLocation\": {\n" ~
            "\t\t\t\t\t\t\t\"uri\": \"",
            kindStr.ptr);
        writeEscapeJSONString(buf, uri);
        buf.printf(
            "\"\n" ~
            "\t\t\t\t\t\t},\n" ~
            "\t\t\t\t\t\t\"region\": {\n" ~
            "\t\t\t\t\t\t\t\"startLine\": %u,\n" ~
            "\t\t\t\t\t\t\t\"startColumn\": %u\n" ~
            "\t\t\t\t\t\t}\n" ~
            "\t\t\t\t\t}\n" ~
            "\t\t\t\t}]\n" ~
            "\t\t\t}",
            loc.linnum,
            loc.charnum);
    }

    extern (C++) override void plugSink()
    {
        if (plugged)
            return;
        plugged = true;
        writeSarifReport(global.errors == 0);
    }

    /**
     * Emit the complete SARIF JSON document, wrapping the accumulated
     * results in $(D buf) with the required prologue and epilogue.
     */
    private void writeSarifReport(bool executionSuccessful)
    {
        // Clean up the version string: strip leading 'v', strip any suffix
        // starting at '-', and strip trailing newlines.
        string toolVersion = global.versionString();
        if (toolVersion.length > 0 && toolVersion[0] == 'v')
            toolVersion = toolVersion[1 .. $];

        size_t length = toolVersion.length;
        const(char)* dash = strchr(toolVersion.ptr, '-');
        if (dash)
            length = cast(size_t)(dash - toolVersion.ptr);
        string cleanedVersion = toolVersion[0 .. length];
        while (cleanedVersion.length > 0 &&
               (cleanedVersion[$ - 1] == '\n' || cleanedVersion[$ - 1] == '\r'))
            cleanedVersion = cleanedVersion[0 .. $ - 1];

        OutBuffer ob;
        ob.writestring(
            "{\n" ~
            "\t\"version\": \"2.1.0\",\n" ~
            "\t\"$schema\": \"https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0.json\",\n" ~
            "\t\"runs\": [{\n" ~
            "\t\t\"tool\": {\n" ~
            "\t\t\t\"driver\": {\n" ~
            "\t\t\t\t\"name\": \"");
        writeEscapeJSONString(ob, global.compileEnv.vendor);
        ob.writestring(
            "\",\n" ~
            "\t\t\t\t\"version\": \"");
        writeEscapeJSONString(ob, cleanedVersion);
        ob.writestring(
            "\",\n" ~
            "\t\t\t\t\"informationUri\": \"https://dlang.org/dmd.html\"\n" ~
            "\t\t\t}\n" ~
            "\t\t},\n" ~
            "\t\t\"invocations\": [{\n" ~
            "\t\t\t\"executionSuccessful\": ");
        ob.writestring(executionSuccessful ? "true" : "false");
        ob.writestring(
            "\n" ~
            "\t\t}],\n" ~
            "\t\t\"results\": [");

        if (resultCount > 0)
        {
            ob.writeByte('\n');
            ob.write(buf[]);
            ob.writeByte('\n');
        }
        else
        {
            ob.writeByte('\n');
        }

        ob.writestring("\t\t]\n\t}]\n}\n");

        fputs(ob.extractChars(), stdout);
        fflush(stdout);
    }
}
