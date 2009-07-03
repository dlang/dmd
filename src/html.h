
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_HTML_H
#define DMD_HTML_H 1

struct OutBuffer;

struct Html
{
    const char *sourcename;

    unsigned char *base;	// pointer to start of buffer
    unsigned char *end;		// past end of buffer
    unsigned char *p;		// current character
    unsigned linnum;		// current line number
    OutBuffer *dbuf;		// code source buffer
    int inCode;			// !=0 if in code


    Html(const char *sourcename, unsigned char *base, unsigned length);

    void error(const char *format, ...);
    void extractCode(OutBuffer *buf);
    void skipTag();
    void skipString();
    unsigned char *skipWhite(unsigned char *q);
    void scanComment();
    int isCommentStart();
    void scanCDATA();
    int isCDATAStart();
    int charEntity();
    static int namedEntity(unsigned char *p, int length);
};

#endif
