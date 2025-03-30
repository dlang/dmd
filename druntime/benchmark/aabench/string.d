/**
 * Benchmark string hashing.
 *
 * Copyright: Copyright Martin Nowak 2011 - 2015.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
module aabench.string;

import std.algorithm, std.file;

void runTest(R)(R words)
{
    size_t[string] aa;

    foreach (_; 0 .. 10)
        foreach (word; words)
            ++aa[word];

    if (aa.length != 24900)
        assert(0);
}

void main(string[] args)
{
    auto path = args.length > 1 ? args[1] : "extra-files/dante.txt";
    auto words = splitter(cast(string) read(path), ' ');
    runTest(words);
}
