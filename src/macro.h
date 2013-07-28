
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

    utf8_t *name;        // macro name
    size_t namelen;             // length of macro name

    utf8_t *text;        // macro replacement text
    size_t textlen;             // length of replacement text

    int inuse;                  // macro is in use (don't expand)

    Macro(utf8_t *name, size_t namelen, utf8_t *text, size_t textlen);
    Macro *search(utf8_t *name, size_t namelen);

  public:
    static Macro *define(Macro **ptable, utf8_t *name, size_t namelen, utf8_t *text, size_t textlen);

    void expand(OutBuffer *buf, size_t start, size_t *pend,
        utf8_t *arg, size_t arglen);
};

#endif
