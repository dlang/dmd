/**
 * Provides SARIF (Static Analysis Results Interchange Format) reporting functionality.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/sarif.d, sarif.d)
 * Coverage:    $(LINK2 https://codecov.io/gh/dlang/dmd/src/master/src/dmd/sarif.d, Code Coverage)
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
struct SarifResult {
    string ruleId;      /// Rule identifier.
    string message;     /// Error or warning message.
    string uri;         /// URI of the affected file.
    int startLine;      /// Line number where the issue occurs.
    int startColumn;    /// Column number where the issue occurs.

    /// Converts the SARIF result to a JSON string.
    ///
    /// Returns:
    /// - A JSON string representing the SARIF result, including the rule ID, message, and location.
    string toJson() nothrow {
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

/// Represents a SARIF report containing tool information, invocation, and results.
struct SarifReport {
    ToolInformation tool;  /// Information about the analysis tool.
    Invocation invocation;  /// Execution information.
    SarifResult[] results;  /// List of SARIF results (errors, warnings, etc.).

    /// Converts the SARIF report to a JSON string.
    ///
    /// Returns:
    /// - A JSON string representing the SARIF report, including the tool information, invocation, and results.
    string toJson() nothrow {
        OutBuffer buffer;
        buffer.writestring(`{"tool": `);
        buffer.writestring(tool.toJson());
        buffer.writestring(`, "invocation": `);
        buffer.writestring(invocation.toJson());
        buffer.writestring(`, "results": [`);
        if (results.length > 0) {
            buffer.writestring(results[0].toJson());
            foreach (result; results[1 .. $]) {
                buffer.writestring(`, `);
                buffer.writestring(result.toJson());
            }
        }
        buffer.writestring(`]}`);
        return cast(string) buffer.extractChars()[0 .. buffer.length()].dup;
    }
}

/// Represents invocation information for the analysis process.
struct Invocation {
    bool executionSuccessful;  /// Whether the execution was successful.

    /// Converts the invocation information to a JSON string.
    ///
    /// Returns:
    /// - A JSON representation of the invocation status.
    string toJson() nothrow {
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
string formatErrorMessage(const(char)* format, va_list ap) nothrow {
    char[2048] buffer;
    import core.stdc.stdio : vsnprintf;
    vsnprintf(buffer.ptr, buffer.length, format, ap);
    return buffer[0 .. buffer.length].dup;
}

/**
Generates a SARIF (Static Analysis Results Interchange Format) report and prints it to `stdout`.

This function builds a JSON-formatted SARIF report, including information about the tool,
invocation status, error message, severity level, and the location of the issue in the source code.

Params:
  loc = The source location where the error occurred (file, line, and column).
  format = A format string for constructing the error message.
  ap = A variable argument list used with the format string.
  kind = The kind of error (error, warning, deprecation, note, or message).

Throws:
  This function is marked as `nothrow` and does not throw exceptions.

See_Also:
  $(LINK2 https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0.json, SARIF 2.1.0 schema)
*/
void generateSarifReport(const ref SourceLoc loc, const(char)* format, va_list ap, ErrorKind kind) nothrow
{
    // Format the error message
    string formattedMessage = formatErrorMessage(format, ap);

    // Map ErrorKind to SARIF levels
    const(char)* level;
    string ruleId;
    final switch (kind) {
        case ErrorKind.error:
            level = "error";
            ruleId = "DMD-ERROR";
            break;
        case ErrorKind.warning:
            level = "warning";
            ruleId = "DMD-WARNING";
            break;
        case ErrorKind.deprecation:
            level = "deprecation";
            ruleId = "DMD-DEPRECATION";
            break;
        case ErrorKind.tip:
            level = "note";
            ruleId = "DMD-NOTE";
            break;
        case ErrorKind.message:
            level = "none";
            ruleId = "DMD-MESSAGE";
            break;
    }

    // Create an OutBuffer to store the SARIF report
    OutBuffer ob;
    ob.doindent = true;

    // Extract and clean the version string
    string toolVersion = global.versionString();
    // Remove 'v' prefix if it exists
    if (toolVersion.length > 0 && toolVersion[0] == 'v') {
        toolVersion = toolVersion[1 .. $];
    }
    // Find the first non-numeric character after the version number
    size_t length = toolVersion.length;
    const(char)* nonNumeric = strchr(toolVersion.ptr, '-');
    if (nonNumeric) {
        length = cast(size_t)(nonNumeric - toolVersion.ptr);
    }
    string cleanedVersion = toolVersion[0 .. length];

    // Build SARIF report
    ob.level = 0;
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
    ob.writestringln(`"executionSuccessful": false`);
    ob.level -= 1;
    ob.writestringln("}],");

    // Results Array
    ob.writestringln(`"results": [{`);
    ob.level += 1;

    // Rule ID
    ob.writestring(`"ruleId": "`);
    ob.writestring(ruleId);
    ob.writestringln(`",`);

    // Message Information
    ob.writestringln(`"message": {`);
    ob.level += 1;
    ob.writestring(`"text": "`);
    ob.writestring(formattedMessage.ptr);
    ob.writestringln(`"`);
    ob.level -= 1;
    ob.writestringln(`},`);

    // Error Severity Level
    ob.writestring(`"level": "`);
    ob.writestring(level);
    ob.writestringln(`",`);

    // Location Information
    ob.writestringln(`"locations": [{`);
    ob.level += 1;
    ob.writestringln(`"physicalLocation": {`);
    ob.level += 1;

    // Artifact Location
    ob.writestringln(`"artifactLocation": {`);
    ob.level += 1;
    ob.writestring(`"uri": "`);
    ob.writestring(loc.filename);
    ob.writestringln(`"`);
    ob.level -= 1;
    ob.writestringln(`},`);

    // Region Information
    ob.writestringln(`"region": {`);
    ob.level += 1;
    ob.writestring(`"startLine": `);
    ob.printf(`%d,`, loc.linnum);
    ob.writestringln(``);
    ob.writestring(`"startColumn": `);
    ob.printf(`%d`, loc.charnum);
    ob.writestringln(``);
    ob.level -= 1;
    ob.writestringln(`}`);

    // Close physicalLocation and locations
    ob.level -= 1;
    ob.writestringln(`}`);
    ob.level -= 1;
    ob.writestringln(`}]`);
    ob.level -= 1;
    ob.writestringln("}]");

    // Close the run and SARIF JSON
    ob.level -= 1;
    ob.writestringln("}]");
    ob.level = 0;
    ob.writestringln("}");

    // Extract the final null-terminated string and print it to stdout
    const(char)* sarifOutput = ob.extractChars();
    fputs(sarifOutput, stdout);
    fflush(stdout);
}
