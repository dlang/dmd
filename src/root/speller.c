
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
 *	seed		wrongly spelled word
 *	fp		search function
 *	fparg		argument to search function
 *	charset		character set
 * Returns:
 *	NULL		no correct spellings found
 *	void*		value returned by fp() for first possible correct spelling
 */

void *speller(const char *seed, fp_speller_t fp, void *fparg, const char *charset)
{
    size_t seedlen = strlen(seed);
    if (!seedlen)
	return NULL;

    char *buf = (char *)alloca(seedlen + 2);	// leave space for extra char
    if (!buf)
	return NULL;				// no matches

    /* Deletions */
    memcpy(buf, seed + 1, seedlen);
    for (int i = 0; i < seedlen; i++)
    {
	//printf("del buf = '%s'\n", buf);
	void *p = (*fp)(fparg, buf);
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
	void *p = (*fp)(fparg, buf);
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
		void *p = (*fp)(fparg, buf);
		if (p)
		    return p;
	    }
	    buf[i] = seed[i];
	}

	/* Insertions */
	memcpy(buf + 1, seed, seedlen + 1);
	for (int i = 0; i <= seedlen; i++)	// yes, do seedlen+1 iterations
	{
	    for (const char *s = charset; *s; s++)
	    {
		buf[i] = *s;

		//printf("ins buf = '%s'\n", buf);
		void *p = (*fp)(fparg, buf);
		if (p)
		    return p;
	    }
	    buf[i] = seed[i];	// going past end of seed[] is ok, as we hit the 0
	}
    }

    return NULL;		// didn't find any corrections
}
