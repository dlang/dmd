/**
The output of -ftime-trace is not deterministic because it contains timer data,
and it's also full of implementation details (such as the order of semantic analysis).
In order to test the output, this program extracts only 'name' and 'details' strings of events,
and sorts them, so the output can be tested.
*/
module sanitize_timetrace;

import std.algorithm;
import std.array;
import std.conv;
import std.json;
import std.range;
import std.string;

void sanitizeTimeTrace(ref string testOutput)
{
    parseJSON(testOutput);
    auto json = parseJSON(testOutput);
    string result = json["traceEvents"].array
        .filter!(x => x["ph"].str == "X")
        .map!(x => strip(x["name"].str ~ ", " ~ x["args"]["detail"].str))
        .array
        .sort
        .uniq
        .joiner("\n").text;
    testOutput = result;
}
