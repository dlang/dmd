/**
 * This module provides MS VC runtime helper functions that
 * wrap differences between MS C runtime versions.
 *
 * Copyright: Copyright Digital Mars 2015.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Source:    $(DRUNTIMESRC rt/_msvc.d)
 * Authors:   Rainer Schuetze
 * Source: $(DRUNTIMESRC rt/_msvc.d)
 */
module rt.msvc;

version (CRuntime_Microsoft):

import core.stdc.stdarg : va_list;
import core.stdc.stdio : FILE, stdin, stdout, stderr, _vsnprintf;

extern(C):
nothrow:
@nogc:

// VS2013- FILE.
struct _iobuf
{
    char* _ptr;
    int   _cnt;
    char* _base;
    int   _flag;
    int   _file;
    int   _charbuf;
    int   _bufsiz;
    char* _tmpfname;
}

FILE* __acrt_iob_func(int hnd);     // VS2015+
_iobuf* __iob_func();               // VS2013-

int _set_output_format(int format); // VS2013-

immutable void* _nullfunc = null;

__gshared ubyte msvcUsesUCRT;

version (X86)
    enum cPrefix = "_";
else
    enum cPrefix = "";

mixin template declareAlternateName(string name, string alternateName)
{
    mixin(`pragma(linkerDirective, "/alternatename:` ~ cPrefix~name ~ `=` ~ cPrefix~alternateName ~ `");`);
}

mixin declareAlternateName!("__acrt_iob_func", "_msvc_acrt_iob_func");
mixin declareAlternateName!("__iob_func", "_nullfunc");
mixin declareAlternateName!("_set_output_format", "_nullfunc");

private bool isAvailable(alias f)()
{
    auto p = cast(void**) &f; // required to prevent frontend 'optimization'...
    return p != &_nullfunc;
}

void init_msvc()
{
    if (isAvailable!_set_output_format)
    {
        enum _TWO_DIGIT_EXPONENT = 1;
        _set_output_format(_TWO_DIGIT_EXPONENT);
    }
    else
        msvcUsesUCRT = 1;
}

// VS2013- implements stdin/out/err using a macro, VS2015+ provides __acrt_iob_func
FILE* _msvc_acrt_iob_func(int hnd)
{
    if (isAvailable!__iob_func)
        return cast(FILE*) (__iob_func() + hnd);
    else
        assert(false);
}

// VS2015+ wraps (v)snprintf into an inlined function calling __stdio_common_vsprintf
//  wrap it back to the original function if it doesn't exist in the C library
int _msvc_stdio_common_vsprintf(
    ulong options,
    char* buffer,
    size_t buffer_count,
    const char* format,
    void* locale,
    va_list arglist
)
{
    enum _CRT_INTERNAL_PRINTF_STANDARD_SNPRINTF_BEHAVIOR = 2;
    int r = _vsnprintf(buffer, buffer_count, format, arglist);
    if ((options & _CRT_INTERNAL_PRINTF_STANDARD_SNPRINTF_BEHAVIOR) &&
        (buffer_count != 0 && buffer))
    {
        // mimic vsnprintf semantics for most use cases
        if (r == buffer_count)
        {
            buffer[buffer_count - 1] = 0;
            return r;
        }
        if (r == -1)
        {
            buffer[buffer_count - 1] = 0;
            return _vsnprintf(null, 0, format, arglist);
        }
    }
    return r;
}

mixin declareAlternateName!("__stdio_common_vsprintf", "_msvc_stdio_common_vsprintf");

// VS2015+ provides C99-conformant (v)snprintf functions, so weakly
// link to legacy _(v)snprintf (not C99-conformant!) for VS2013- only

mixin declareAlternateName!("snprintf", "_snprintf");
mixin declareAlternateName!("vsnprintf", "_vsnprintf");

// VS2013- implements these functions as macros, VS2015+ provides symbols

mixin declareAlternateName!("_fputc_nolock", "_msvc_fputc_nolock");
mixin declareAlternateName!("_fgetc_nolock", "_msvc_fgetc_nolock");
mixin declareAlternateName!("rewind", "_msvc_rewind");
mixin declareAlternateName!("clearerr", "_msvc_clearerr");
mixin declareAlternateName!("feof", "_msvc_feof");
mixin declareAlternateName!("ferror", "_msvc_ferror");
mixin declareAlternateName!("fileno", "_msvc_fileno");

// VS2013- helper functions
int _filbuf(_iobuf* fp);
int _flsbuf(int c, _iobuf* fp);

mixin declareAlternateName!("_filbuf", "_nullfunc");
mixin declareAlternateName!("_flsbuf", "_nullfunc");

int _msvc_fputc_nolock(int c, _iobuf* fp)
{
    fp._cnt--;
    if (fp._cnt >= 0)
    {
        *fp._ptr = cast(char) c;
        fp._ptr++;
        return cast(char) c;
    }
    else
        return _flsbuf(c, fp);
}

int _msvc_fgetc_nolock(_iobuf* fp)
{
    fp._cnt--;
    if (fp._cnt >= 0)
    {
        const char c = *fp._ptr;
        fp._ptr++;
        return c;
    }
    else
        return _filbuf(fp);
}

enum
{
    SEEK_SET = 0,
    _IOEOF   = 0x10,
    _IOERR   = 0x20
}

int fseek(_iobuf* stream, int offset, int origin);

void _msvc_rewind(_iobuf* stream)
{
    fseek(stream, 0, SEEK_SET);
    stream._flag &= ~_IOERR;
}

void _msvc_clearerr(_iobuf* stream)
{
    stream._flag &= ~(_IOERR | _IOEOF);
}

int  _msvc_feof(_iobuf* stream)
{
    return stream._flag & _IOEOF;
}

int  _msvc_ferror(_iobuf* stream)
{
    return stream._flag & _IOERR;
}

int  _msvc_fileno(_iobuf* stream)
{
    return stream._file;
}



/**
 * 32-bit x86 MS VC runtimes lack most single-precision math functions.
 * Declare alternate implementations to be pulled in from msvc_math.d.
 */

version (X86):
mixin declareAlternateName!("acosf",  "_msvc_acosf");
mixin declareAlternateName!("asinf",  "_msvc_asinf");
mixin declareAlternateName!("atanf",  "_msvc_atanf");
mixin declareAlternateName!("atan2f", "_msvc_atan2f");
mixin declareAlternateName!("cosf",   "_msvc_cosf");
mixin declareAlternateName!("sinf",   "_msvc_sinf");
mixin declareAlternateName!("tanf",   "_msvc_tanf");
mixin declareAlternateName!("coshf",  "_msvc_coshf");
mixin declareAlternateName!("sinhf",  "_msvc_sinhf");
mixin declareAlternateName!("tanhf",  "_msvc_tanhf");
mixin declareAlternateName!("expf",   "_msvc_expf");
mixin declareAlternateName!("logf",   "_msvc_logf");
mixin declareAlternateName!("log10f", "_msvc_log10f");
mixin declareAlternateName!("powf",   "_msvc_powf");
mixin declareAlternateName!("sqrtf",  "_msvc_sqrtf");
mixin declareAlternateName!("ceilf",  "_msvc_ceilf");
mixin declareAlternateName!("floorf", "_msvc_floorf");
mixin declareAlternateName!("fmodf",  "_msvc_fmodf");
mixin declareAlternateName!("modff",  "_msvc_modff");
