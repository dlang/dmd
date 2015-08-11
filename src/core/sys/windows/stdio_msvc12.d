/**
* This module provides MS VC runtime helper function to be used
* with VS versions before VS 2015
*
* Copyright: Copyright Digital Mars 2015.
* License: Distributed under the
*      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
*    (See accompanying file LICENSE)
* Source:    $(DRUNTIMESRC core/sys/windows/_stdio_msvc12.d)
* Authors:   Rainer Schuetze
*/

module core.sys.windows.stdio_msvc12;

version( CRuntime_Microsoft ):

import core.stdc.stdio;

extern (C):
@system:
nothrow:
@nogc:

alias stdio_FILE = core.stdc.stdio.FILE;

FILE* __iob_func();

uint _set_output_format(uint format);

enum _TWO_DIGIT_EXPONENT = 1;

void init_msvc()
{
    // stdin,stdout and stderr internally in a static array __iob[3]
    auto fp = __iob_func();
    stdin  = cast(stdio_FILE*) &fp[0];
    stdout = cast(stdio_FILE*) &fp[1];
    stderr = cast(stdio_FILE*) &fp[2];

    // ensure that sprintf generates only 2 digit exponent when writing floating point values
    _set_output_format(_TWO_DIGIT_EXPONENT);
}

struct _iobuf
{
    char* _ptr;
    int   _cnt;  // _cnt and _base exchanged for VS2015
    char* _base;
    int   _flag;
    int   _file;
    int   _charbuf;
    int   _bufsiz;
    char* _tmpfname;
}

alias shared(_iobuf) FILE;

int _filbuf(FILE *fp);
int _flsbuf(int c, FILE *fp);

int _fputc_nolock(int c, FILE *fp)
{
    fp._cnt = fp._cnt - 1;
    if (fp._cnt >= 0)
    {
        *fp._ptr = cast(char)c;
        fp._ptr = fp._ptr + 1;
        return cast(char)c;
    }
    else
        return _flsbuf(c, fp);
}

int _fgetc_nolock(FILE *fp)
{
    fp._cnt = fp._cnt - 1;
    if (fp._cnt >= 0)
    {
        char c = *fp._ptr;
        fp._ptr = fp._ptr + 1;
        return c;
    }
    else
        return _filbuf(fp);
}

@trusted
{
    ///
    void rewind(FILE* stream)
    {
        fseek(cast(stdio_FILE*)stream,0L,SEEK_SET);
        stream._flag = stream._flag & ~_IOERR;
    }
    ///
    pure void clearerr(FILE* stream) { stream._flag = stream._flag & ~(_IOERR|_IOEOF);   }
    ///
    pure int  feof(FILE* stream)     { return stream._flag&_IOEOF;                       }
    ///
    pure int  ferror(FILE* stream)   { return stream._flag&_IOERR;                       }
    ///
    pure int  fileno(FILE* stream)   { return stream._file;                              }
}
