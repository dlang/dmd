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
import std.stdio;
import std.conv;
import std.file;
import std.string;
import std.exception;

void main(string[] args)
{
    string txt = cast(string)std.file.read(args.length > 1 ? args[1] : "extra-files/dante.txt");
    uint cnt = args.length > 2 ? to!uint(args[2]) : 100;

    string data;
    for(int b = 31; b >= 0; b--)
    {
        data ~= data;
        if(cnt & (1 << b))
            data ~= txt;
    }

    auto words = data.split().length;
    enforce(words == (args.length > 3 ? to!size_t(args[3]) : 9767600));
}
