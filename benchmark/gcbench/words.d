/**
 * Copyright: Copyright Rainer Schuetze 2014.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Rainer Schuetze
 *
 * This test reads a text file, duplicates it in memory the given number of times,
 * then splits the result into white space delimited words. The result is an array
 * of strings referencing the full text.
 * Regarding GC activity, this test probes concatenation of long strings and appending
 * to a large array of strings.
 */
// EXECUTE_ARGS: extra-files/dante.txt 100 9767600

import std.stdio;
import std.conv;
import std.file;
import std.string;
import std.exception;

void main(string[] args)
{
    enforce(args.length > 2, "usage: words <file-name> <duplicates> [expected-result]");
    string txt = cast(string) std.file.read(args[1]);
    uint cnt = to!uint(args[2]);

    string data;
    for(int b = 31; b >= 0; b--)
    {
        data ~= data;
        if(cnt & (1 << b))
            data ~= txt;
    }

    auto words = data.split().length;
    writeln("words: ", words);

    if(args.length > 3)
        enforce(words == to!size_t(args[3]));
}
