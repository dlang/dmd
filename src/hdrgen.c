
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// Initial header generation implementation by Dave Fladebo
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Routines to emit header files

#define PRETTY_PRINT
#define TEST_EMIT_ALL  0        // For Testing

#define LOG 0

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "rmem.h"

#include "id.h"
#include "init.h"

#include "attrib.h"
#include "cond.h"
#include "enum.h"
#include "import.h"
#include "module.h"
#include "mtype.h"
#include "scope.h"
#include "staticassert.h"
#include "template.h"
#include "utf.h"
#include "version.h"

#include "declaration.h"
#include "aggregate.h"
#include "expression.h"
#include "statement.h"
#include "mtype.h"
#include "hdrgen.h"

void argsToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs);

void Module::genhdrfile()
{
    OutBuffer hdrbufr;
    hdrbufr.doindent = 1;

    hdrbufr.printf("// D import file generated from '%s'", srcfile->toChars());
    hdrbufr.writenl();

    HdrGenState hgs;
    memset(&hgs, 0, sizeof(hgs));
    hgs.hdrgen = 1;

    toCBuffer(&hdrbufr, &hgs);

    // Transfer image to file
    hdrfile->setbuffer(hdrbufr.data, hdrbufr.offset);
    hdrbufr.data = NULL;

    FileName::ensurePathToNameExists(hdrfile->toChars());
    hdrfile->writev();
}


void Module::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (md)
    {
        buf->writestring("module ");
        buf->writestring(md->toChars());
        buf->writebyte(';');
        buf->writenl();
    }

    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];

        s->toHBuffer(buf, hgs);
    }
}


void Dsymbol::toHBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    toCBuffer(buf, hgs);
}


/*************************************/
