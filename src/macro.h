
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_MACRO_H
#define DMD_MACRO_H 1

#include <stdio.h>
#include <string.h>
#include <time.h>
#include <ctype.h>

#include "root.h"


struct Macro
{
  private:
    Macro *next;                // next in list

    unsigned char *name;        // macro name
    size_t namelen;             // length of macro name

    unsigned char *text;        // macro replacement text
    size_t textlen;             // length of replacement text

    int inuse;                  // macro is in use (don't expand)

    Macro(unsigned char *name, size_t namelen, unsigned char *text, size_t textlen);
    Macro *search(unsigned char *name, size_t namelen);

  public:
    static Macro *define(Macro **ptable, unsigned char *name, size_t namelen, unsigned char *text, size_t textlen);

    void expand(OutBuffer *buf, unsigned start, unsigned *pend,
        unsigned char *arg, unsigned arglen);
};

#endif
