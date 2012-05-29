// Compiler implementation of the D programming language
// utf.h
// Copyright (c) 2003-2010 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_UTF_H
#define DMD_UTF_H

/// A UTF-8 code unit
typedef unsigned char   utf8_t;
/// A UTF-16 code unit
typedef unsigned short  utf16_t;
/// A UTF-32 code unit
typedef unsigned int    utf32_t;
typedef utf32_t         dchar_t;

char const *const UTF8_DECODE_OK = NULL;
extern char const UTF8_DECODE_OUTSIDE_CODE_SPACE[];
extern char const UTF8_DECODE_TRUNCATED_SEQUENCE[];
extern char const UTF8_DECODE_OVERLONG[];
extern char const UTF8_DECODE_INVALID_TRAILER[];
extern char const UTF8_DECODE_INVALID_CODE_POINT[];

/// \return true if \a c is a valid, non-private UTF-32 code point
bool utf_isValidDchar(dchar_t c);

const char *utf_decodeChar(utf8_t const *s, size_t len, size_t *pidx, dchar_t *presult);
const char *utf_decodeWchar(utf16_t const *s, size_t len, size_t *pidx, dchar_t *presult);

const char *utf_validateString(utf8_t const *s, size_t len);

extern int isUniAlpha(dchar_t);

void utf_encodeChar(utf8_t *s, dchar_t c);
void utf_encodeWchar(utf16_t *s, dchar_t c);

int utf_codeLengthChar(dchar_t c);
int utf_codeLengthWchar(dchar_t c);

int utf_codeLength(int sz, dchar_t c);
void utf_encode(int sz, void *s, dchar_t c);

#endif  // DMD_UTF_H
