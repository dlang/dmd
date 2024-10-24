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

// Struct for SARIF Tool Information
struct ToolInformation {
    string name;
    string toolVersion;

    string toJson() nothrow {
        return `{"name": "` ~ name ~ `", "version": "` ~ toolVersion ~ `"}`;
    }
}

// Function to convert int to string
string intToString(int value) nothrow {
    char[32] buffer;
    import core.stdc.stdio : sprintf;
    sprintf(buffer.ptr, "%d", value);
    return buffer[0 .. buffer.length].dup;
}

// Struct for SARIF Result
struct Result {
    string ruleId;  // Rule identifier
    string message;  // Error message
    string uri;  // File path (URI)
    int startLine;  // Line number where the error occurs
    int startColumn;  // Column number where the error occurs

    string toJson() nothrow {
        return `{"ruleId": "` ~ ruleId ~ `", "message": "` ~ message ~ `", "location": {"artifactLocation": {"uri": "` ~ uri ~ `"}, "region": {"startLine": ` ~ intToString(startLine) ~ `, "startColumn": ` ~ intToString(startColumn) ~ `}}}`;
    }
}

// SARIF Report Struct
struct SarifReport {
    ToolInformation tool;  // Information about the tool
    Invocation invocation;  // Information about the execution
    Result[] results;  // List of results (errors, warnings, etc.)

    string toJson() nothrow {
        string resultsJson = "[" ~ results[0].toJson();
        foreach (result; results[1 .. $]) {
            resultsJson ~= ", " ~ result.toJson();
        }
        resultsJson ~= "]";

        return `{"tool": ` ~ tool.toJson() ~ `, "invocation": ` ~ invocation.toJson() ~ `, "results": ` ~ resultsJson ~ `}`;
    }
}

// Function to convert SourceLoc to JSON string
string sourceLocToJson(const SourceLoc sourceLoc) nothrow {
    OutBuffer result;

    // Write the JSON for the file URI
    result.writestring(`{
        "artifactLocation": {
            "uri": "file://`);
    result.writestring(sourceLoc.filename);
    result.writestring(`"
        },
        "region": {
            "startLine": `);
    result.print(sourceLoc.line);
    result.writestring(`,
            "startColumn": `);
    result.print(sourceLoc.column);
    result.writestring(`
        }
    }`);

    return result.extractSlice();
}

// Struct for Invocation Information
struct Invocation {
    bool executionSuccessful;

    string toJson() nothrow {
        return `{"executionSuccessful": ` ~ (executionSuccessful ? "true" : "false") ~ `}`;
    }
}

// Helper function to format error messages
string formatErrorMessage(const(char)* format, va_list ap) nothrow
{
    char[2048] buffer;  // Buffer for the formatted message
    import core.stdc.stdio : vsnprintf;
    vsnprintf(buffer.ptr, buffer.length, format, ap);
    return buffer[0 .. buffer.length].dup;
}

void generateSarifReport(const ref Loc loc, const(char)* format, va_list ap, ErrorKind kind) nothrow
{
    // Format the error message
    string formattedMessage = formatErrorMessage(format, ap);

    // Create an OutBuffer to store the SARIF report
    OutBuffer ob;
    ob.doindent = true;

    // Extract and clean the version string
    const(char)* rawVersionChars = global.versionChars();

    // Remove 'v' prefix if it exists
    if (*rawVersionChars == 'v') {
        rawVersionChars += 1;
    }

    // Find the first non-numeric character after the version number
    const(char)* nonNumeric = strchr(rawVersionChars, '-');
    size_t length = nonNumeric ? cast(size_t)(nonNumeric - rawVersionChars) : strlen(rawVersionChars);

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
    ob.writestringln(`"driver": {`);
    ob.printf(`"name": "%s",`, global.compileEnv.vendor.ptr);
    ob.printf(`"version": "%.*s",`, cast(int)length, rawVersionChars);
    ob.writestringln(`"informationUri": "https://dlang.org/dmd.html"`);
    ob.writestringln("}");
    ob.writestringln("},");

    // Invocation Information
    ob.writestringln(`"invocations": [{`);
    ob.writestringln(`"executionSuccessful": false`);
    ob.writestringln("}],");

    // Results Array
    ob.writestringln(`"results": [{`);
    ob.writestringln(`"ruleId": "DMD",`);
    ob.printf(`"message": { "text": "%s" },`, formattedMessage.ptr);

    // Location Information
    ob.writestringln(`"locations": [{`);
    ob.writestringln(`"physicalLocation": {`);
    ob.writestringln(`"artifactLocation": {`);
    ob.printf(`"uri": "%s"`, loc.filename);
    ob.writestringln("},");
    ob.writestringln(`"region": {`);
    ob.printf(`"startLine": %d,`, loc.linnum);
    ob.printf(`"startColumn": %d`, loc.charnum);
    ob.writestringln("}");
    ob.writestringln("}");
    ob.writestringln("}]");
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
