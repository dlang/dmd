// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.speller;

import core.stdc.limits, core.stdc.stdlib, core.stdc.string;

alias dg_speller_t = void* delegate(const(char)*, ref int);

__gshared const(char)* idchars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";

/**************************************************
 * combine a new result from the spell checker to
 * find the one with the closest symbol with
 * respect to the cost defined by the search function
 * Input/Output:
 *      p       best found spelling (NULL if none found yet)
 *      cost    cost of p (INT_MAX if none found yet)
 * Input:
 *      np      new found spelling (NULL if none found)
 *      ncost   cost of np if non-NULL
 * Returns:
 *      true    if the cost is less or equal 0
 *      false   otherwise
 */
bool combineSpellerResult(ref void* p, ref int cost, void* np, int ncost)
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

void* spellerY(const(char)* seed, size_t seedlen, dg_speller_t dg, const(char)* charset, size_t index, int* cost)
{
    if (!seedlen)
        return null;
    assert(seed[seedlen] == 0);
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
    memcpy(buf, seed, index);
    *cost = INT_MAX;
    void* p = null;
    int ncost;
    /* Delete at seed[index] */
    if (index < seedlen)
    {
        memcpy(buf + index, seed + index + 1, seedlen - index);
        assert(buf[seedlen - 1] == 0);
        void* np = dg(buf, ncost);
        if (combineSpellerResult(p, *cost, np, ncost))
            return p;
    }
    if (charset && *charset)
    {
        /* Substitutions */
        if (index < seedlen)
        {
            memcpy(buf, seed, seedlen + 1);
            for (const(char)* s = charset; *s; s++)
            {
                buf[index] = *s;
                //printf("sub buf = '%s'\n", buf);
                void* np = dg(buf, ncost);
                if (combineSpellerResult(p, *cost, np, ncost))
                    return p;
            }
            assert(buf[seedlen] == 0);
        }
        /* Insertions */
        memcpy(buf + index + 1, seed + index, seedlen + 1 - index);
        for (const(char)* s = charset; *s; s++)
        {
            buf[index] = *s;
            //printf("ins buf = '%s'\n", buf);
            void* np = dg(buf, ncost);
            if (combineSpellerResult(p, *cost, np, ncost))
                return p;
        }
        assert(buf[seedlen + 1] == 0);
    }
    return p; // return "best" result
}

void* spellerX(const(char)* seed, size_t seedlen, dg_speller_t dg, const(char)* charset, int flag)
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
    int cost = INT_MAX, ncost;
    void* p = null, np;
    /* Deletions */
    memcpy(buf, seed + 1, seedlen);
    for (size_t i = 0; i < seedlen; i++)
    {
        //printf("del buf = '%s'\n", buf);
        if (flag)
            np = spellerY(buf, seedlen - 1, dg, charset, i, &ncost);
        else
            np = dg(buf, ncost);
        if (combineSpellerResult(p, cost, np, ncost))
            return p;
        buf[i] = seed[i];
    }
    /* Transpositions */
    if (!flag)
    {
        memcpy(buf, seed, seedlen + 1);
        for (size_t i = 0; i + 1 < seedlen; i++)
        {
            // swap [i] and [i + 1]
            buf[i] = seed[i + 1];
            buf[i + 1] = seed[i];
            //printf("tra buf = '%s'\n", buf);
            if (combineSpellerResult(p, cost, dg(buf, ncost), ncost))
                return p;
            buf[i] = seed[i];
        }
    }
    if (charset && *charset)
    {
        /* Substitutions */
        memcpy(buf, seed, seedlen + 1);
        for (size_t i = 0; i < seedlen; i++)
        {
            for (const(char)* s = charset; *s; s++)
            {
                buf[i] = *s;
                //printf("sub buf = '%s'\n", buf);
                if (flag)
                    np = spellerY(buf, seedlen, dg, charset, i + 1, &ncost);
                else
                    np = dg(buf, ncost);
                if (combineSpellerResult(p, cost, np, ncost))
                    return p;
            }
            buf[i] = seed[i];
        }
        /* Insertions */
        memcpy(buf + 1, seed, seedlen + 1);
        for (size_t i = 0; i <= seedlen; i++) // yes, do seedlen+1 iterations
        {
            for (const(char)* s = charset; *s; s++)
            {
                buf[i] = *s;
                //printf("ins buf = '%s'\n", buf);
                if (flag)
                    np = spellerY(buf, seedlen + 1, dg, charset, i + 1, &ncost);
                else
                    np = dg(buf, ncost);
                if (combineSpellerResult(p, cost, np, ncost))
                    return p;
            }
            buf[i] = seed[i]; // going past end of seed[] is ok, as we hit the 0
        }
    }
    return p; // return "best" result
}

/**************************************************
 * Looks for correct spelling.
 * Currently only looks a 'distance' of one from the seed[].
 * This does an exhaustive search, so can potentially be very slow.
 * Input:
 *      seed            wrongly spelled word
 *      dg              search delegate
 *      charset         character set
 * Returns:
 *      NULL            no correct spellings found
 *      void*           value returned by dg() for first possible correct spelling
 */
void* speller(const(char)* seed, scope dg_speller_t dg, const(char)* charset)
{
    size_t seedlen = strlen(seed);
    size_t maxdist = seedlen < 4 ? seedlen / 2 : 2;
    for (int distance = 0; distance < maxdist; distance++)
    {
        void* p = spellerX(seed, seedlen, dg, charset, distance);
        if (p)
            return p;
        //      if (seedlen > 10)
        //          break;
    }
    return null; // didn't find it
}

version (unittest)
{
    void unittest_speller()
    {
        static __gshared const(char)*** cases =
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

        void* dgarg;

        void* speller_test(const(char)* s, ref int cost)
        {
            //printf("speller_test(%s, %s)\n", dgarg, s);
            cost = 0;
            if (strcmp(cast(char*)dgarg, s) == 0)
                return dgarg;
            return null;
        }

        dgarg = cast(char*)"hell";
        const(void)* p = speller(cast(const(char)*)"hello", &speller_test, idchars);
        assert(p !is null);
        for (int i = 0; cases[i][0]; i++)
        {
            //printf("case [%d]\n", i);
            dgarg = cast(void*)cases[i][1];
            void* p2 = speller(cases[i][0], &speller_test, idchars);
            if (p2)
                assert(cases[i][2][0] == 'y');
            else
                assert(cases[i][2][0] == 'n');
        }
        //printf("unittest_speller() success\n");
    }
}
