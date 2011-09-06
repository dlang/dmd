
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#if __sun&&__SVR4
#include <alloca.h>
#endif

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

void *spellerY(const char *seed, size_t seedlen, fp_speller_t fp, void *fparg,
        const char *charset, size_t index)
{
    if (!seedlen)
        return NULL;
    assert(seed[seedlen] == 0);

    char tmp[30];
    char *buf;
    if (seedlen <= sizeof(tmp) - 2)
        buf = tmp;
    else
    {
        buf = (char *)alloca(seedlen + 2);    // leave space for extra char
        if (!buf)
            return NULL;                      // no matches
    }

    memcpy(buf, seed, index);

    /* Delete at seed[index] */
    if (index < seedlen)
    {
        memcpy(buf + index, seed + index + 1, seedlen - index);
        assert(buf[seedlen - 1] == 0);
        void *p = (*fp)(fparg, buf);
        if (p)
            return p;
    }

    if (charset && *charset)
    {
        /* Substitutions */
        if (index < seedlen)
        {
            memcpy(buf, seed, seedlen + 1);
            for (const char *s = charset; *s; s++)
            {
                buf[index] = *s;

                //printf("sub buf = '%s'\n", buf);
                void *p = (*fp)(fparg, buf);
                if (p)
                    return p;
            }
            assert(buf[seedlen] == 0);
        }

        /* Insertions */
        memcpy (buf + index + 1, seed + index, seedlen + 1 - index);

        for (const char *s = charset; *s; s++)
        {
            buf[index] = *s;

            //printf("ins buf = '%s'\n", buf);
            void *p = (*fp)(fparg, buf);
            if (p)
                return p;
        }
        assert(buf[seedlen + 1] == 0);
    }

    return NULL;                // didn't find any corrections
}

void *spellerX(const char *seed, size_t seedlen, fp_speller_t fp, void *fparg,
        const char *charset, int flag)
{
    if (!seedlen)
        return NULL;

    char tmp[30];
    char *buf;
    if (seedlen <= sizeof(tmp) - 2)
        buf = tmp;
    else
    {
        buf = (char *)alloca(seedlen + 2);    // leave space for extra char
        if (!buf)
            return NULL;                      // no matches
    }

    /* Deletions */
    memcpy(buf, seed + 1, seedlen);
    for (size_t i = 0; i < seedlen; i++)
    {
        //printf("del buf = '%s'\n", buf);
        void *p;
        if (flag)
            p = spellerY(buf, seedlen - 1, fp, fparg, charset, i);
        else
            p = (*fp)(fparg, buf);
        if (p)
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
            void *p = (*fp)(fparg, buf);
            if (p)
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
            for (const char *s = charset; *s; s++)
            {
                buf[i] = *s;

                //printf("sub buf = '%s'\n", buf);
                void *p;
                if (flag)
                    p = spellerY(buf, seedlen, fp, fparg, charset, i + 1);
                else
                    p = (*fp)(fparg, buf);
                if (p)
                    return p;
            }
            buf[i] = seed[i];
        }

        /* Insertions */
        memcpy(buf + 1, seed, seedlen + 1);
        for (size_t i = 0; i <= seedlen; i++)      // yes, do seedlen+1 iterations
        {
            for (const char *s = charset; *s; s++)
            {
                buf[i] = *s;

                //printf("ins buf = '%s'\n", buf);
                void *p;
                if (flag)
                    p = spellerY(buf, seedlen + 1, fp, fparg, charset, i + 1);
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
    size_t seedlen = strlen(seed);
    for (int distance = 0; distance < 2; distance++)
    {   void *p = spellerX(seed, seedlen, fp, fparg, charset, distance);
        if (p)
            return p;
//      if (seedlen > 10)
//          break;
    }
    return NULL;   // didn't find it
}


#if UNITTEST

#include <stdio.h>
#include <string.h>
#include <assert.h>

void *speller_test(void *fparg, const char *s)
{
    //printf("speller_test(%s, %s)\n", fparg, s);
    if (strcmp((char *)fparg, s) == 0)
        return fparg;
    return NULL;
}

void unittest_speller()
{
    static const char *cases[][3] =
    {
        { "hello", "hell",  "y" },
        { "hello", "hel",   "y" },
        { "hello", "ello",  "y" },
        { "hello", "llo",   "y" },
        { "hello", "hellox",  "y" },
        { "hello", "helloxy",  "y" },
        { "hello", "xhello",  "y" },
        { "hello", "xyhello",  "y" },
        { "hello", "ehllo",  "y" },
        { "hello", "helol",  "y" },
        { "hello", "abcd",  "n" },
        //{ "ehllo", "helol", "y" },
        { "hello", "helxxlo", "y" },
        { "hello", "ehlxxlo", "n" },
        { "hello", "heaao", "y" },
        { "_123456789_123456789_123456789_123456789", "_123456789_123456789_123456789_12345678", "y" },
    };
    //printf("unittest_speller()\n");
    const void *p = speller("hello", &speller_test, (void *)"hell", idchars);
    assert(p != NULL);
    for (int i = 0; i < sizeof(cases)/sizeof(cases[0]); i++)
    {
        //printf("case [%d]\n", i);
        void *p = speller(cases[i][0], &speller_test, (void *)cases[i][1], idchars);
        if (p)
            assert(cases[i][2][0] == 'y');
        else
            assert(cases[i][2][0] == 'n');
    }
    //printf("unittest_speller() success\n");
}

#endif
