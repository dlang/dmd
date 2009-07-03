
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#if MARS
struct OutBuffer;
#else
struct Outbuffer;
#endif

struct Html
{
    const char *sourcename;

    unsigned char *base;	// pointer to start of buffer
    unsigned char *end;		// past end of buffer
    unsigned char *p;		// current character
    unsigned linnum;		// current line number
#if MARS
    OutBuffer *dbuf;		// code source buffer
#else
    Outbuffer *dbuf;		// code source buffer
#endif
    int inCode;			// !=0 if in code


    Html(const char *sourcename, unsigned char *base, unsigned length);

    void error(const char *format, ...);
#if MARS
    void extractCode(OutBuffer *buf);
#else
    void extractCode(Outbuffer *buf);
#endif
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
