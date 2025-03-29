/**
 * Provides SARIF (Static Analysis Results Interchange Format) reporting functionality.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
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
import core.stdc.string;
import dmd.errorsink;
import dmd.globals;
import dmd.location;
import dmd.common.outbuffer;
import dmd.root.rmem;
import dmd.console;
import dmd.errors;

/// Contains information about the tool used for analysis in SARIF reports.
struct ToolInformation {
    string name;        /// Name of the tool.
    string toolVersion; /// Version of the tool.

    /// Converts the tool information to a JSON string.
    ///
    /// Returns:
    /// - A JSON representation of the tool's name and version.
    string toJson() nothrow {
        OutBuffer buffer;
        buffer.writestring(`{"name": "`);
        buffer.writestring(name);
        buffer.writestring(`", "version": "`);
        buffer.writestring(toolVersion);
        buffer.writestring(`"}`);
        return cast(string) buffer.extractChars()[0 .. buffer.length()].dup;
    }
}

/**
Converts an integer to a string.

Params:
  value = The integer value to convert.

Returns:
  A string representation of the integer.
*/
string intToString(int value) nothrow {
    char[32] buffer;
    import core.stdc.stdio : sprintf;
    sprintf(buffer.ptr, "%d", value);
    return buffer[0 .. buffer.length].dup;
}

/// Represents a SARIF result containing a rule ID, message, and location.
struct SarifResult
{
    string ruleId;      /// Rule identifier.
    string message;     /// Error or warning message.
    string uri;         /// URI of the affected file.
    int startLine;      /// Line number where the issue occurs.
    int startColumn;    /// Column number where the issue occurs.

    /// Converts the SARIF result to a JSON string.
    ///
    /// Returns:
    /// - A JSON string representing the SARIF result, including the rule ID, message, and location.
    string toJson() nothrow
    {
        OutBuffer buffer;
        buffer.writestring(`{"ruleId": "`);
        buffer.writestring(ruleId);
        buffer.writestring(`", "message": "`);
        buffer.writestring(message);
        buffer.writestring(`", "location": {"artifactLocation": {"uri": "`);
        buffer.writestring(uri);
        buffer.writestring(`"}, "region": {"startLine": `);
        buffer.writestring(intToString(startLine));
        buffer.writestring(`, "startColumn": `);
        buffer.writestring(intToString(startColumn));
        buffer.writestring(`}}}`);
        return cast(string) buffer.extractChars()[0 .. buffer.length()].dup;
    }
}

/**
Adds a SARIF diagnostic entry to the diagnostics list.

Formats a diagnostic message and appends it to the global diagnostics array, allowing errors, warnings, or other diagnostics to be captured in SARIF format.

Params:
  loc = The location in the source code where the diagnostic was generated (includes file, line, and column).
  format = The printf-style format string for the diagnostic message.
  ap = The variadic argument list containing values to format into the diagnostic message.
  kind = The type of diagnostic, indicating whether it is an error, warning, deprecation, etc.
*/
void addSarifDiagnostic(const SourceLoc loc, const(char)* format, va_list ap, ErrorKind kind) nothrow
{
    char[1024] buffer;
    int written = vsnprintf(buffer.ptr, buffer.length, format, ap);

    // Handle any truncation
    string formattedMessage = cast(string) buffer[0 .. (written < 0 || written > buffer.length ? buffer.length : written)].dup;

    // Add the Diagnostic to the global diagnostics array
    diagnostics ~= Diagnostic(loc, formattedMessage, kind);
}

/// Represents a SARIF report containing tool information, invocation, and results.
struct SarifReport
{
    ToolInformation tool;  /// Information about the analysis tool.
    Invocation invocation;  /// Execution information.
    SarifResult[] results;  /// List of SARIF results (errors, warnings, etc.).

    /// Converts the SARIF report to a JSON string.
    ///
    /// Returns:
    /// - A JSON string representing the SARIF report, including the tool information, invocation, and results.
    string toJson() nothrow
    {
        OutBuffer buffer;
        buffer.writestring(`{"tool": `);
        buffer.writestring(tool.toJson());
        buffer.writestring(`, "invocation": `);
        buffer.writestring(invocation.toJson());
        buffer.writestring(`, "results": [`);
        if (results.length > 0)
        {
            buffer.writestring(results[0].toJson());
            foreach (result; results[1 .. $])
            {
                buffer.writestring(`, `);
                buffer.writestring(result.toJson());
            }
        }
        buffer.writestring(`]}`);
        return cast(string) buffer.extractChars()[0 .. buffer.length()].dup;
    }
}

/// Represents invocation information for the analysis process.
struct Invocation
{
    bool executionSuccessful;  /// Whether the execution was successful.

    /// Converts the invocation information to a JSON string.
    ///
    /// Returns:
    /// - A JSON representation of the invocation status.
    string toJson() nothrow
    {
        OutBuffer buffer;
        buffer.writestring(`{"executionSuccessful": `);
        buffer.writestring(executionSuccessful ? "true" : "false");
        buffer.writestring(`}`);
        return cast(string) buffer.extractChars()[0 .. buffer.length()].dup;
    }
}

/**
Formats an error message using a format string and a variable argument list.

Params:
  format = The format string to use.
  ap = A variable argument list for the format string.

Returns:
  A formatted error message string.
*/
string formatErrorMessage(const(char)* format, va_list ap) nothrow
{
    char[2048] buffer;
    import core.stdc.stdio : vsnprintf;
    vsnprintf(buffer.ptr, buffer.length, format, ap);
    return buffer[0 .. buffer.length].dup;
}

/**
Converts an `ErrorKind` value to a SARIF-compatible string representation for the severity level.

Params:
  kind = The `ErrorKind` value to convert (e.g., error, warning, deprecation).

Returns:
  A SARIF-compatible string representing the `ErrorKind` level, such as "error" or "warning".
*/
string errorKindToString(ErrorKind kind) nothrow
{
    final switch (kind)
    {
        case ErrorKind.error: return "error";       // Serious problem
        case ErrorKind.warning: return "warning";   // Problem found
        case ErrorKind.deprecation: return "note";  // Minor problem, opportunity for improvement
        case ErrorKind.tip: return "note";          // Minor improvement suggestion
        case ErrorKind.message: return "none";      // Not applicable for "fail" kind, so use "none"
    }
}

/**
Generates a SARIF (Static Analysis Results Interchange Format) report and prints it to `stdout`.

This function constructs a JSON-formatted SARIF report that includes information about the tool used (such as compiler version and URI), the invocation status (indicating whether the execution was successful), and a detailed array of diagnostics (results) when `executionSuccessful` is set to `false`. Each diagnostic entry in the results array contains the rule identifier (`ruleId`), a text message describing the issue (`message`), the severity level (`level`), and the location of the issue in the source code, including the file path, line number, and column number. The SARIF report adheres to the SARIF 2.1.0 standard.

Params:
   executionSuccessful = `true` for an empty `results` array; `false` for detailed errors.

Throws:
  This function is marked as `nothrow` and does not throw exceptions.

See_Also:
  $(LINK2 https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0.json, SARIF 2.1.0 schema)
*/
void generateSarifReport(bool executionSuccessful) nothrow
{
    // Create an OutBuffer to store the SARIF report
    OutBuffer ob;
    ob.doindent = true;

    // Extract and clean the version string
    string toolVersion = global.versionString();
    // Remove 'v' prefix if it exists
    if (toolVersion.length > 0 && toolVersion[0] == 'v')
        toolVersion = toolVersion[1 .. $];

    // Find the first non-numeric character after the version number
    size_t length = toolVersion.length;
    const(char)* nonNumeric = strchr(toolVersion.ptr, '-');
    if (nonNumeric)
        length = cast(size_t)(nonNumeric - toolVersion.ptr);

    string cleanedVersion = toolVersion[0 .. length];

    // Build SARIF report
    ob.writestringln("{");
    ob.level = 1;

    ob.writestringln(`"version": "2.1.0",`);
    ob.writestringln(`"$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0.json",`);
    ob.writestringln(`"runs": [{`);

    // Tool Information
    ob.level += 1;
    ob.writestringln(`"tool": {`);
    ob.level += 1;
    ob.writestringln(`"driver": {`);
    ob.level += 1;

    // Write "name" field
    ob.writestring(`"name": "`);
    ob.writestring(global.compileEnv.vendor.ptr);
    ob.writestringln(`",`);

    // Write "version" field
    ob.writestring(`"version": "`);
    ob.writestring(cleanedVersion);
    ob.writestringln(`",`);

    // Write "informationUri" field
    ob.writestringln(`"informationUri": "https://dlang.org/dmd.html"`);
    ob.level -= 1;
    ob.writestringln("}");
    ob.level -= 1;
    ob.writestringln("},");

    // Invocation Information
    ob.writestringln(`"invocations": [{`);
    ob.level += 1;
    ob.writestring(`"executionSuccessful": `);
    ob.writestring(executionSuccessful ? "true" : "false");
    ob.writestringln("");
    ob.level -= 1;
    ob.writestringln("}],");

    // Results Array
    ob.writestringln(`"results": [`);
    ob.level += 1;

    foreach (idx, diag; diagnostics)
    {
        ob.writestringln("{");
        ob.level += 1;

        // Rule ID
        ob.writestring(`"ruleId": "DMD-` ~ errorKindToString(diag.kind) ~ `",`);
        ob.writestringln("");

        // Message Information
        ob.writestringln(`"message": {`);
        ob.level += 1;
        ob.writestring(`"text": "`);
        ob.writestring(diag.message);
        ob.writestringln(`"`);
        ob.level -= 1;
        ob.writestringln("},");

        // Error Severity Level
        ob.writestring(`"level": "` ~ errorKindToString(diag.kind) ~ `",`);
        ob.writestringln("");

        // Location Information
        ob.writestringln(`"locations": [{`);
        ob.level += 1;
        ob.writestringln(`"physicalLocation": {`);
        ob.level += 1;

        // Artifact Location
        ob.writestringln(`"artifactLocation": {`);
        ob.level += 1;
        ob.writestring(`"uri": "`);
        ob.writestring(diag.loc.filename);
        ob.writestringln(`"`);
        ob.level -= 1;
        ob.writestringln("},");

        // Region Information
        ob.writestringln(`"region": {`);
        ob.level += 1;
        ob.writestring(`"startLine": `);
        ob.printf(`%d,`, diag.loc.linnum);
        ob.writestringln("");
        ob.writestring(`"startColumn": `);
        ob.printf(`%d`, diag.loc.charnum);
        ob.writestringln("");
        ob.level -= 1;
        ob.writestringln("}");

        // Close physicalLocation and locations
        ob.level -= 1;
        ob.writestringln("}");
        ob.level -= 1;
        ob.writestringln("}]");

        // Closing brace for each diagnostic item
        ob.level -= 1;
        if (idx < diagnostics.length - 1)
            ob.writestringln("},");
        else
            ob.writestringln("}");
    }

    // Close the run and SARIF JSON
    ob.level -= 1;
    ob.writestringln("]");
    ob.level -= 1;
    ob.writestringln("}]");
    ob.level -= 1;
    ob.writestringln("}");

    // Extract the final null-terminated string and print it to stdout
    const(char)* sarifOutput = ob.extractChars();
    fputs(sarifOutput, stdout);
    fflush(stdout);
}
