/*******************************************************************************

    D binding for the POSIX iconv library.

    Defines external functions required to use iconv codeset conversion
    function.

    iconv_open(3)   Allocates the descriptor for code conversion
    iconv(3)        Performs the conversion
    iconv_close(3)  Deallocates allocated resources

    Copyright:  Copyright (c) 2016 Sociomantic Labs. All rights reserved.
    License:    $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:    Nemanja Boric
    Standards:  POSIX.1-2001, POSIX.1-2008
    See_Also:
       http://pubs.opengroup.org/onlinepubs/009695399/functions/iconv_open.html

*******************************************************************************/

module core.sys.posix.iconv;

version (Posix):
extern (C):
nothrow:
@nogc:


alias void* iconv_t;

/// Allocate descriptor for code conversion from codeset FROMCODE to
/// codeset TOCODE.
iconv_t iconv_open (in char* tocode, in char* fromcode);

/// Convert at most *INBYTESLEFT bytes from *INBUF according to the
/// code conversion algorithm specified by CD and place up to
/// *OUTBYTESLEFT bytes in buffer at *OUTBUF.
size_t iconv (iconv_t cd, char** inbuf,
         size_t* inbytesleft,
         char** outbuf,
         size_t* outbytesleft);

/// Free resources allocated for descriptor CD for code conversion.
int iconv_close (iconv_t cd);
