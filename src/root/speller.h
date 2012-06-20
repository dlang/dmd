
// Copyright (c) 2010-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

typedef void *(fp_speller_t)(void *, const char *);

extern const char idchars[];

void *speller(const char *seed, fp_speller_t fp, void *fparg, const char *charset);

