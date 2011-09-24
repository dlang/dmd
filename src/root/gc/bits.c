// Copyright (c) 2000-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include <assert.h>
#include <stdlib.h>

#include "bits.h"

GCBits::GCBits()
{
    data = NULL;
    nwords = 0;
    nbits = 0;
}

GCBits::~GCBits()
{
    if (data)
        ::free(data);
    data = NULL;
}

void GCBits::invariant()
{
    if (data)
    {
        assert(nwords * sizeof(*data) * 8 >= nbits);
    }
}

void GCBits::alloc(unsigned nbits)
{
    this->nbits = nbits;
    nwords = (nbits + (BITS_PER_WORD - 1)) >> BITS_SHIFT;
    data = (unsigned *)::calloc(nwords + 2, sizeof(unsigned));
    assert(data);
}
