
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "speller.h"

const char idchars[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";

/**************************************************
 * Looks for correct spelling.
 * Currently only looks a 'distance' of one from the seed[].
 * This does an exhaustive search, so can potentially be very slow.
 * Input:
 *      seed            wrongly spelled word
 *      fp              search function
 *      fparg           argument to search function
 *      charset         character set
 * Returns:
 *      NULL            no correct spellings found
 *      void*           value returned by fp() for first possible correct spelling
 */

void *spellerX(const char *seed, fp_speller_t fp, void *fparg, const char *charset, int flag)
{
    size_t seedlen = strlen(seed);
    if (!seedlen)
        return NULL;

    char *buf = (char *)alloca(seedlen + 2);    // leave space for extra char
    if (!buf)
        return NULL;                            // no matches

    /* Deletions */
    memcpy(buf, seed + 1, seedlen);
    for (int i = 0; i < seedlen; i++)
    {
        //printf("del buf = '%s'\n", buf);
        void *p;
        if (flag)
            p = spellerX(buf, fp, fparg, charset, flag - 1);
        else
            p = (*fp)(fparg, buf);
        if (p)
            return p;

        buf[i] = seed[i];
    }

    /* Transpositions */
    memcpy(buf, seed, seedlen + 1);
    for (int i = 0; i + 1 < seedlen; i++)
    {
        // swap [i] and [i + 1]
        buf[i] = seed[i + 1];
        buf[i + 1] = seed[i];

        //printf("tra buf = '%s'\n", buf);
        void *p;
        if (flag)
            p = spellerX(buf, fp, fparg, charset, flag - 1);
        else
            p = (*fp)(fparg, buf);
        if (p)
            return p;

        buf[i] = seed[i];
    }

    if (charset && *charset)
    {
        /* Substitutions */
        memcpy(buf, seed, seedlen + 1);
        for (int i = 0; i < seedlen; i++)
        {
            for (const char *s = charset; *s; s++)
            {
                buf[i] = *s;

                //printf("sub buf = '%s'\n", buf);
                void *p;
                if (flag)
                    p = spellerX(buf, fp, fparg, charset, flag - 1);
                else
                    p = (*fp)(fparg, buf);
                if (p)
                    return p;
            }
            buf[i] = seed[i];
        }

        /* Insertions */
        memcpy(buf + 1, seed, seedlen + 1);
        for (int i = 0; i <= seedlen; i++)      // yes, do seedlen+1 iterations
        {
            for (const char *s = charset; *s; s++)
            {
                buf[i] = *s;

                //printf("ins buf = '%s'\n", buf);
                void *p;
                if (flag)
                    p = spellerX(buf, fp, fparg, charset, flag - 1);
                else
                    p = (*fp)(fparg, buf);
                if (p)
                    return p;
            }
            buf[i] = seed[i];   // going past end of seed[] is ok, as we hit the 0
        }
    }

    return NULL;                // didn't find any corrections
}

void *speller(const char *seed, fp_speller_t fp, void *fparg, const char *charset)
{
    for (int distance = 0; distance < 2; distance++)
    {   void *p = spellerX(seed, fp, fparg, charset, distance);
        if (p)
            return p;
    }
    return NULL;   // didn't find it
}


#if UNITTEST

#include <stdio.h>
#include <string.h>
#include <assert.h>

void *speller_test(void *fparg, const char *s)
{
    if (strcmp((char *)fparg, s) == 0)
        return fparg;
    return NULL;
}

void unittest_speller()
{
    static const char *cases[][3] =
    {
        { "hello", "hell",  "y" },
        { "hello", "abcd",  "n" },
        { "hello", "hel",   "y" },
        { "ehllo", "helol", "y" },
        { "hello", "helxxlo", "y" },
        { "hello", "ehlxxlo", "n" },
        { "hello", "heaao", "y" },
    };
    //printf("unittest_speller()\n");
    void *p = speller("hello", &speller_test, (void *)"hell", idchars);
    assert(p != NULL);
    for (int i = 0; i < sizeof(cases)/sizeof(cases[0]); i++)
    {
        void *p = speller(cases[i][0], &speller_test, (void *)cases[i][1], idchars);
        if (p)
            assert(cases[i][2][0] == 'y');
        else
            assert(cases[i][2][0] == 'n');
    }
    //printf("unittest_speller() success\n");
}

#endif
