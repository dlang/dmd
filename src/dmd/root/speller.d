/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/speller.d, root/_speller.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_speller.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/speller.d
 */

module dmd.root.speller;

import core.stdc.stdlib;
import core.stdc.string;

immutable string idchars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";

/**************************************************
 * combine a new result from the spell checker to
 * find the one with the closest symbol with
 * respect to the cost defined by the search function
 * Input/Output:
 *      p       best found spelling (NULL if none found yet)
 *      cost    cost of p (int.max if none found yet)
 * Input:
 *      np      new found spelling (NULL if none found)
 *      ncost   cost of np if non-NULL
 * Returns:
 *      true    if the cost is less or equal 0
 *      false   otherwise
 */
private bool combineSpellerResult(T)(ref T p, ref int cost, T np, int ncost)
{
    if (np && ncost < cost)
    {
        p = np;
        cost = ncost;
        if (cost <= 0)
            return true;
    }
    return false;
}

private auto spellerY(alias dg)(const(char)[] seed, size_t index, ref int cost)
{
    if (!seed.length)
        return null;
    char[30] tmp;
    char[] buf;
    if (seed.length <= tmp.sizeof - 1)
        buf = tmp;
    else
    {
        buf = (cast(char*)alloca(seed.length + 1))[0 .. seed.length + 1]; // leave space for extra char
        if (!buf.ptr)
            return null; // no matches
    }
    buf[0 .. index] = seed[0 .. index];
    cost = int.max;
    searchFunctionType!dg p = null;
    int ncost;
    /* Delete at seed[index] */
    if (index < seed.length)
    {
        buf[index .. seed.length - 1] = seed[index + 1 .. $];
        auto np = dg(buf[0 .. seed.length - 1], ncost);
        if (combineSpellerResult(p, cost, np, ncost))
            return p;
    }
    /* Substitutions */
    if (index < seed.length)
    {
        buf[0 .. seed.length] = seed;
        foreach (s; idchars)
        {
            buf[index] = s;
            //printf("sub buf = '%s'\n", buf);
            auto np = dg(buf[0 .. seed.length], ncost);
            if (combineSpellerResult(p, cost, np, ncost))
                return p;
        }
    }
    /* Insertions */
    buf[index + 1 .. seed.length + 1] = seed[index .. $];
    foreach (s; idchars)
    {
        buf[index] = s;
        //printf("ins buf = '%s'\n", buf);
        auto np = dg(buf[0 .. seed.length + 1], ncost);
        if (combineSpellerResult(p, cost, np, ncost))
            return p;
    }
    return p; // return "best" result
}

private auto spellerX(alias dg)(const(char)* seed, size_t seedlen, bool flag)
{
    if (!seedlen)
        return null;
    char[30] tmp;
    char* buf;
    if (seedlen <= tmp.sizeof - 2)
        buf = tmp.ptr;
    else
    {
        buf = cast(char*)alloca(seedlen + 2); // leave space for extra char
        if (!buf)
            return null; // no matches
    }
    int cost = int.max, ncost;
    searchFunctionType!dg p = null, np;
    /* Deletions */
    buf[0 .. seedlen] = seed[1 .. seedlen + 1];
    for (size_t i = 0; i < seedlen; i++)
    {
        //printf("del buf = '%s'\n", buf);
        if (flag)
            np = spellerY!dg(buf[0 .. seedlen - 1], i, ncost);
        else
            np = dg(buf[0 .. seedlen - 1], ncost);
        if (combineSpellerResult(p, cost, np, ncost))
            return p;
        buf[i] = seed[i];
    }
    /* Transpositions */
    if (!flag)
    {
        buf[0 .. seedlen + 1] = seed[0 .. seedlen + 1];
        for (size_t i = 0; i + 1 < seedlen; i++)
        {
            // swap [i] and [i + 1]
            buf[i] = seed[i + 1];
            buf[i + 1] = seed[i];
            //printf("tra buf = '%s'\n", buf);
            if (combineSpellerResult(p, cost, dg(buf[0 .. seedlen], ncost), ncost))
                return p;
            buf[i] = seed[i];
        }
    }
    /* Substitutions */
    buf[0 .. seedlen + 1] = seed[0 .. seedlen + 1];
    for (size_t i = 0; i < seedlen; i++)
    {
        foreach (s; idchars)
        {
            buf[i] = s;
            //printf("sub buf = '%s'\n", buf);
            if (flag)
                np = spellerY!dg(buf[0 .. seedlen], i + 1, ncost);
            else
                np = dg(buf[0 .. seedlen], ncost);
            if (combineSpellerResult(p, cost, np, ncost))
                return p;
        }
        buf[i] = seed[i];
    }
    /* Insertions */
    buf[1 .. seedlen + 2] = seed[0 .. seedlen + 1];
    for (size_t i = 0; i <= seedlen; i++) // yes, do seedlen+1 iterations
    {
        foreach (s; idchars)
        {
            buf[i] = s;
            //printf("ins buf = '%s'\n", buf);
            if (flag)
                np = spellerY!dg(buf[0 .. seedlen + 1], i + 1, ncost);
            else
                np = dg(buf[0 .. seedlen + 1], ncost);
            if (combineSpellerResult(p, cost, np, ncost))
                return p;
        }
        buf[i] = seed[i]; // going past end of seed[] is ok, as we hit the 0
    }
    return p; // return "best" result
}

/**************************************************
 * Looks for correct spelling.
 * Currently only looks a 'distance' of one from the seed[].
 * This does an exhaustive search, so can potentially be very slow.
 * Params:
 *      seed = wrongly spelled word
 *      dg = search delegate
 * Returns:
 *      null = no correct spellings found, otherwise
 *      the value returned by dg() for first possible correct spelling
 */
auto speller(alias dg)(const(char)* seed)
if (isSearchFunction!dg)
{
    size_t seedlen = strlen(seed);
    size_t maxdist = seedlen < 4 ? seedlen / 2 : 2;
    for (int distance = 0; distance < maxdist; distance++)
    {
        auto p = spellerX!dg(seed, seedlen, distance > 0);
        if (p)
            return p;
        //      if (seedlen > 10)
        //          break;
    }
    return null; // didn't find it
}

enum isSearchFunction(alias fun) = is(searchFunctionType!fun);
alias searchFunctionType(alias fun) = typeof(() {int x; return fun("", x);}());

unittest
{
    static immutable string[][] cases =
    [
        ["hello", "hell", "y"],
        ["hello", "hel", "y"],
        ["hello", "ello", "y"],
        ["hello", "llo", "y"],
        ["hello", "hellox", "y"],
        ["hello", "helloxy", "y"],
        ["hello", "xhello", "y"],
        ["hello", "xyhello", "y"],
        ["hello", "ehllo", "y"],
        ["hello", "helol", "y"],
        ["hello", "abcd", "n"],
        ["hello", "helxxlo", "y"],
        ["hello", "ehlxxlo", "n"],
        ["hello", "heaao", "y"],
        ["_123456789_123456789_123456789_123456789", "_123456789_123456789_123456789_12345678", "y"],
        [null, null, null]
    ];
    //printf("unittest_speller()\n");

    string dgarg;

    string speller_test(const(char)[] s, ref int cost)
    {
        assert(s[$-1] != '\0');
        //printf("speller_test(%s, %s)\n", dgarg, s);
        cost = 0;
        if (dgarg == s)
            return dgarg;
        return null;
    }

    dgarg = "hell";
    auto p = speller!speller_test(cast(const(char)*)"hello");
    assert(p !is null);
    for (int i = 0; cases[i][0]; i++)
    {
        //printf("case [%d]\n", i);
        dgarg = cases[i][1];
        auto p2 = speller!speller_test(cases[i][0].ptr);
        if (p2)
            assert(cases[i][2][0] == 'y');
        else
            assert(cases[i][2][0] == 'n');
    }
    //printf("unittest_speller() success\n");
}
