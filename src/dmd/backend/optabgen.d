/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/optabgen.d, backend/optabgen.d)
 */

module optabgen;

/* Generate op-code tables
 * Creates optab.d,tytab.d,debtab.d
 */

import core.stdc.stdio;
import core.stdc.stdlib;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.oper;
import dmd.backend.ty;

nothrow:

FILE *fdeb;

int main()
{
    printf("OPTABGEN... generating files\n");
    dotytab();
    return 0;
}


/********************************************************
 */

void dotytab()
{
    struct TypeTab
    {
        string str;     /* name of type                 */
        tym_t ty;       /* TYxxxx                       */
        tym_t unsty;    /* conversion to unsigned type  */
        tym_t relty;    /* type for relaxed type checking */
        int size;
        int debtyp;     /* Codeview 1 type in debugger record   */
        int debtyp4;    /* Codeview 4 type in debugger record   */
    }
    static TypeTab[] typetab =
    [
/* Note that chars are signed, here     */
{"bool",         TYbool,         TYbool,    TYchar,      1,      0x80,   0x30},
{"char",         TYchar,         TYuchar,   TYchar,      1,      0x80,   0x70},
{"signed char",  TYschar,        TYuchar,   TYchar,      1,      0x80,   0x10},
{"unsigned char",TYuchar,        TYuchar,   TYchar,      1,      0x84,   0x20},
{"char16_t",     TYchar16,       TYchar16,  TYint,       2,      0x85,   0x21},
{"short",        TYshort,        TYushort,  TYint,       SHORTSIZE, 0x81,0x11},
{"wchar_t",      TYwchar_t,      TYwchar_t, TYint,       SHORTSIZE, 0x85,0x71},
{"unsigned short",TYushort,      TYushort,  TYint,       SHORTSIZE, 0x85,0x21},

// These values are adjusted for 32 bit ints in cv_init() and util_set32()
{"enum",         TYenum,         TYuint,    TYint,       -1,        0x81,0x72},
{"int",          TYint,          TYuint,    TYint,       2,         0x81,0x72},
{"unsigned",     TYuint,         TYuint,    TYint,       2,         0x85,0x73},

{"long",         TYlong,         TYulong,   TYlong,      LONGSIZE,  0x82,0x12},
{"unsigned long",TYulong,        TYulong,   TYlong,      LONGSIZE,  0x86,0x22},
{"dchar",        TYdchar,        TYdchar,   TYlong,      4,         0x86,0x22},
{"long long",    TYllong,        TYullong,  TYllong,     LLONGSIZE, 0x82,0x13},
{"uns long long",TYullong,       TYullong,  TYllong,     LLONGSIZE, 0x86,0x23},
{"cent",         TYcent,         TYucent,   TYcent,      16,        0x82,0x603},
{"ucent",        TYucent,        TYucent,   TYcent,      16,        0x86,0x603},
{"float",        TYfloat,        TYfloat,   TYfloat,     FLOATSIZE, 0x88,0x40},
{"double",       TYdouble,       TYdouble,  TYdouble,    DOUBLESIZE,0x89,0x41},
{"double alias", TYdouble_alias, TYdouble_alias,  TYdouble_alias,8, 0x89,0x41},
{"long double",  TYldouble,      TYldouble,  TYldouble,  -1, 0x89,0x42},

{"imaginary float",      TYifloat,       TYifloat,   TYifloat,   FLOATSIZE, 0x88,0x40},
{"imaginary double",     TYidouble,      TYidouble,  TYidouble,  DOUBLESIZE,0x89,0x41},
{"imaginary long double",TYildouble,     TYildouble, TYildouble, -1,0x89,0x42},

{"complex float",        TYcfloat,       TYcfloat,   TYcfloat,   2*FLOATSIZE, 0x88,0x50},
{"complex double",       TYcdouble,      TYcdouble,  TYcdouble,  2*DOUBLESIZE,0x89,0x51},
{"complex long double",  TYcldouble,     TYcldouble, TYcldouble, -1,0x89,0x52},

{"float[4]",              TYfloat4,    TYfloat4,  TYfloat4,    16,     0,      0},
{"double[2]",             TYdouble2,   TYdouble2, TYdouble2,   16,     0,      0},
{"signed char[16]",       TYschar16,   TYuchar16, TYschar16,   16,     0,      0},
{"unsigned char[16]",     TYuchar16,   TYuchar16, TYuchar16,   16,     0,      0},
{"short[8]",              TYshort8,    TYushort8, TYshort8,    16,     0,      0},
{"unsigned short[8]",     TYushort8,   TYushort8, TYushort8,   16,     0,      0},
{"long[4]",               TYlong4,     TYulong4,  TYlong4,     16,     0,      0},
{"unsigned long[4]",      TYulong4,    TYulong4,  TYulong4,    16,     0,      0},
{"long long[2]",          TYllong2,    TYullong2, TYllong2,    16,     0,      0},
{"unsigned long long[2]", TYullong2,   TYullong2, TYullong2,   16,     0,      0},

{"float[8]",              TYfloat8,    TYfloat8,  TYfloat8,    32,     0,      0},
{"double[4]",             TYdouble4,   TYdouble4, TYdouble4,   32,     0,      0},
{"signed char[32]",       TYschar32,   TYuchar32, TYschar32,   32,     0,      0},
{"unsigned char[32]",     TYuchar32,   TYuchar32, TYuchar32,   32,     0,      0},
{"short[16]",             TYshort16,   TYushort16, TYshort16,  32,     0,      0},
{"unsigned short[16]",    TYushort16,  TYushort16, TYushort16, 32,     0,      0},
{"long[8]",               TYlong8,     TYulong8,  TYlong8,     32,     0,      0},
{"unsigned long[8]",      TYulong8,    TYulong8,  TYulong8,    32,     0,      0},
{"long long[4]",          TYllong4,    TYullong4, TYllong4,    32,     0,      0},
{"unsigned long long[4]", TYullong4,   TYullong4, TYullong4,   32,     0,      0},

{"float[16]",             TYfloat16,   TYfloat16, TYfloat16,   64,     0,      0},
{"double[8]",             TYdouble8,   TYdouble8, TYdouble8,   64,     0,      0},
{"signed char[64]",       TYschar64,   TYuchar64, TYschar64,   64,     0,      0},
{"unsigned char[64]",     TYuchar64,   TYuchar64, TYuchar64,   64,     0,      0},
{"short[32]",             TYshort32,   TYushort32, TYshort32,  64,     0,      0},
{"unsigned short[32]",    TYushort32,  TYushort32, TYushort32, 64,     0,      0},
{"long[16]",              TYlong16,    TYulong16, TYlong16,    64,     0,      0},
{"unsigned long[16]",     TYulong16,   TYulong16, TYulong16,   64,     0,      0},
{"long long[8]",          TYllong8,    TYullong8, TYllong8,    64,     0,      0},
{"unsigned long long[8]", TYullong8,   TYullong8, TYullong8,   64,     0,      0},

{"nullptr_t",    TYnullptr,      TYnullptr, TYptr,       2,  0x20,       0x100},
{"*",            TYnptr,         TYnptr,    TYnptr,      2,  0x20,       0x100},
{"&",            TYref,          TYref,     TYref,       -1,     0,      0},
{"void",         TYvoid,         TYvoid,    TYvoid,      -1,     0x85,   3},
{"struct",       TYstruct,       TYstruct,  TYstruct,    -1,     0,      0},
{"array",        TYarray,        TYarray,   TYarray,     -1,     0x78,   0},
{"C func",       TYnfunc,        TYnfunc,   TYnfunc,     -1,     0x63,   0},
{"Pascal func",  TYnpfunc,       TYnpfunc,  TYnpfunc,    -1,     0x74,   0},
{"std func",     TYnsfunc,       TYnsfunc,  TYnsfunc,    -1,     0x63,   0},
{"*",            TYptr,          TYptr,     TYptr,       2,  0x20,       0x100},
{"member func",  TYmfunc,        TYmfunc,   TYmfunc,     -1,     0x64,   0},
{"D func",       TYjfunc,        TYjfunc,   TYjfunc,     -1,     0x74,   0},
{"C func",       TYhfunc,        TYhfunc,   TYhfunc,     -1,     0,      0},
{"__near &",     TYnref,         TYnref,    TYnref,      2,      0,      0},

{"__ss *",       TYsptr,         TYsptr,    TYsptr,      2,  0x20,       0x100},
{"__cs *",       TYcptr,         TYcptr,    TYcptr,      2,  0x20,       0x100},
{"__far16 *",    TYf16ptr,       TYf16ptr,  TYf16ptr,    4,  0x40,       0x200},
{"__far *",      TYfptr,         TYfptr,    TYfptr,      4,  0x40,       0x200},
{"__huge *",     TYhptr,         TYhptr,    TYhptr,      4,  0x40,       0x300},
{"__handle *",   TYvptr,         TYvptr,    TYvptr,      4,  0x40,       0x200},
{"__immutable *", TYimmutPtr,    TYimmutPtr,TYimmutPtr,  2,  0x20,       0x100},
{"__shared *",   TYsharePtr,     TYsharePtr,TYsharePtr,  2,  0x20,       0x100},
{"__fg *",       TYfgPtr,        TYfgPtr,   TYfgPtr,     2,  0x20,       0x100},
{"far C func",   TYffunc,        TYffunc,   TYffunc,     -1,     0x64,   0},
{"far Pascal func", TYfpfunc,    TYfpfunc,  TYfpfunc,    -1,     0x73,   0},
{"far std func", TYfsfunc,       TYfsfunc,  TYfsfunc,    -1,     0x64,   0},
{"_far16 Pascal func", TYf16func, TYf16func, TYf16func,  -1,     0x63,   0},
{"sys func",     TYnsysfunc,     TYnsysfunc,TYnsysfunc,  -1,     0x63,   0},
{"far sys func", TYfsysfunc,     TYfsysfunc,TYfsysfunc,  -1,     0x64,   0},
{"__far &",      TYfref,         TYfref,    TYfref,      4,      0,      0},

{"interrupt func", TYifunc,      TYifunc,   TYifunc,     -1,     0x64,   0},
{"memptr",       TYmemptr,       TYmemptr,  TYmemptr,    -1,     0,      0},
{"ident",        TYident,        TYident,   TYident,     -1,     0,      0},
{"template",     TYtemplate,     TYtemplate, TYtemplate, -1,     0,      0},
{"vtshape",      TYvtshape,      TYvtshape,  TYvtshape,  -1,     0,      0},
    ];

    FILE *f;
    static tym_t[64 * 4] tytouns;
    static tym_t[TYMAX] _tyrelax;
    static tym_t[TYMAX] _tyequiv;
    static byte[64 * 4] _tysize;
    static ubyte[TYMAX] dttab;
    static ushort[TYMAX] dttab4;
    int i;

    f = fopen("tytab.d","w");

    for (i = 0; i < typetab.length; i++)
    {   tytouns[typetab[i].ty] = typetab[i].unsty;
    }
    fprintf(f,"__gshared tym_t[256] tytouns =\n[ ");
    for (i = 0; i < tytouns.length; i++)
    {   fprintf(f,"0x%02x,",tytouns[i]);
        if ((i & 7) == 7 && i < tytouns.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < typetab.length; i++)
    {   _tysize[typetab[i].ty | 0x00] = cast(byte)typetab[i].size;
        /*printf("_tysize[%d] = %d\n",typetab[i].ty,typetab[i].size);*/
    }
    fprintf(f,"__gshared byte[256] _tysize =\n[ ");
    for (i = 0; i < _tysize.length; i++)
    {   fprintf(f,"%d,",_tysize[i]);
        if ((i & 7) == 7 && i < _tysize.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < _tysize.length; i++)
        _tysize[i] = 0;
    for (i = 0; i < typetab.length; i++)
    {   byte sz = cast(byte)typetab[i].size;
        switch (typetab[i].ty)
        {
            case TYldouble:
            case TYildouble:
            case TYcldouble:
static if (TARGET_OSX)
{
                sz = 16;
}
else static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS)
{
                sz = 4;
}
else static if (TARGET_WINDOS)
{
                sz = 2;
}
else
{
                static assert(0, "fix this");
}
                break;

            case TYcent:
            case TYucent:
                sz = 8;
                break;

            default:
                break;
        }
        _tysize[typetab[i].ty | 0x00] = sz;
        /*printf("_tyalignsize[%d] = %d\n",typetab[i].ty,typetab[i].size);*/
    }

    fprintf(f,"__gshared byte[256] _tyalignsize =\n[ ");
    for (i = 0; i < _tysize.length; i++)
    {   fprintf(f,"%d,",_tysize[i]);
        if ((i & 7) == 7 && i < _tysize.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < typetab.length; i++)
    {   _tyrelax[typetab[i].ty] = typetab[i].relty;
        /*printf("_tyrelax[%d] = %d\n",typetab[i].ty,typetab[i].relty);*/
    }
    fprintf(f,"__gshared ubyte[TYMAX] _tyrelax =\n[ ");
    for (i = 0; i < _tyrelax.length; i++)
    {   fprintf(f,"0x%02x,",_tyrelax[i]);
        if ((i & 7) == 7 && i < _tyrelax.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    /********** tyequiv ************/
    for (i = 0; i < _tyequiv.length; i++)
        _tyequiv[i] = i;
    _tyequiv[TYchar] = TYschar;         /* chars are signed by default  */

    // These values are adjusted in util_set32() for 32 bit ints
    _tyequiv[TYint] = TYshort;
    _tyequiv[TYuint] = TYushort;

    fprintf(f,"__gshared ubyte[TYMAX] tyequiv =\n[ ");
    for (i = 0; i < _tyequiv.length; i++)
    {   fprintf(f,"0x%02x,",_tyequiv[i]);
        if ((i & 7) == 7 && i < _tyequiv.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < typetab.length; i++)
        dttab[typetab[i].ty] = cast(ubyte)typetab[i].debtyp;
    fprintf(f,"__gshared ubyte[TYMAX] dttab =\n[ ");
    for (i = 0; i < dttab.length; i++)
    {   fprintf(f,"0x%02x,",dttab[i]);
        if ((i & 7) == 7 && i < dttab.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    for (i = 0; i < typetab.length; i++)
        dttab4[typetab[i].ty] = cast(ushort)typetab[i].debtyp4;
    fprintf(f,"__gshared ushort[TYMAX] dttab4 =\n[ ");
    for (i = 0; i < dttab4.length; i++)
    {   fprintf(f,"0x%02x,",dttab4[i]);
        if ((i & 7) == 7 && i < dttab4.length - 1)
            fprintf(f,"\n  ");
    }
    fprintf(f,"\n];\n");

    fclose(f);
}
