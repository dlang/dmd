// Compiler implementation of the D programming language
// utf.h
// Copyright (c) 2003-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_UTF_H
#define DMD_UTF_H


typedef unsigned dchar_t;

int utf_isValidDchar(dchar_t c);

char *utf_decodeChar(unsigned char *s, size_t len, size_t *pidx, dchar_t *presult);
char *utf_decodeWchar(unsigned short *s, size_t len, size_t *pidx, dchar_t *presult);

char *utf_validateString(unsigned char *s, size_t len);

extern int isUniAlpha(dchar_t);

#endif
