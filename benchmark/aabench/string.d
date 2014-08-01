/**
 * Benchmark string hashing.
 *
 * Copyright: Copyright Martin Nowak 2011 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:    Martin Nowak
 */

// EXECUTE_ARGS: extra-files/dante.txt

import std.array, std.file, std.path;

void runTest(string[] words)
{
    size_t[string] aa;

    foreach(word; words)
        ++aa[word];

    assert(aa.length == 20795);
}

void main(string[] args)
{
    string path;
    if (args.length > 1)
        path = args[1];
    else
    {
        // test/bin/aabench/string => test/extra-files/dante.txt
        path = dirName(dirName(dirName(absolutePath(args[0]))));
        path = buildPath(path, "extra-files", "dante.txt");
    }
    auto words = split(std.file.readText(path));
    runTest(words);
}
