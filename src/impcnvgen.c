
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>

#include "mtype.h"

TY impcnvResult[TMAX][TMAX];
TY impcnvType1[TMAX][TMAX];
TY impcnvType2[TMAX][TMAX];
int impcnvWarn[TMAX][TMAX];

int integral_promotion(int t)
{
    switch (t)
    {
        case Tchar:
        case Twchar:
        case Tbool:
        case Tint8:
        case Tuns8:
        case Tint16:
        case Tuns16:    return Tint32;
        case Tdchar:    return Tuns32;
        default:        return t;
    }
}

void init()
{   int i, j;

    // Set conversion tables
    for (i = 0; i < TMAX; i++)
        for (j = 0; j < TMAX; j++)
        {   impcnvResult[i][j] = Terror;
            impcnvType1[i][j] = Terror;
            impcnvType2[i][j] = Terror;
            impcnvWarn[i][j] = 0;
        }

#define X(t1,t2, nt1,nt2, rt)           \
        impcnvResult[t1][t2] = rt;      \
        impcnvType1[t1][t2] = nt1;      \
        impcnvType2[t1][t2] = nt2;


    /* ======================= */

    X(Tbool,Tbool,   Tbool,Tbool,    Tbool)
    X(Tbool,Tint8,   Tint32,Tint32,  Tint32)
    X(Tbool,Tuns8,   Tint32,Tint32,  Tint32)
    X(Tbool,Tint16,  Tint32,Tint32,  Tint32)
    X(Tbool,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tbool,Tint32,  Tint32,Tint32,  Tint32)
    X(Tbool,Tuns32,  Tuns32,Tuns32,  Tuns32)
    X(Tbool,Tint64,  Tint64,Tint64,  Tint64)
    X(Tbool,Tuns64,  Tuns64,Tuns64,  Tuns64)

    X(Tbool,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tbool,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tbool,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tbool,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tbool,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tbool,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tbool,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tbool,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tbool,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tint8,Tint8,   Tint32,Tint32,  Tint32)
    X(Tint8,Tuns8,   Tint32,Tint32,  Tint32)
    X(Tint8,Tint16,  Tint32,Tint32,  Tint32)
    X(Tint8,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tint8,Tint32,  Tint32,Tint32,  Tint32)
    X(Tint8,Tuns32,  Tuns32,Tuns32,  Tuns32)
    X(Tint8,Tint64,  Tint64,Tint64,  Tint64)
    X(Tint8,Tuns64,  Tuns64,Tuns64,  Tuns64)

    X(Tint8,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tint8,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tint8,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tint8,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tint8,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tint8,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tint8,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tint8,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tint8,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tuns8,Tuns8,   Tint32,Tint32,  Tint32)
    X(Tuns8,Tint16,  Tint32,Tint32,  Tint32)
    X(Tuns8,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tuns8,Tint32,  Tint32,Tint32,  Tint32)
    X(Tuns8,Tuns32,  Tuns32,Tuns32,  Tuns32)
    X(Tuns8,Tint64,  Tint64,Tint64,  Tint64)
    X(Tuns8,Tuns64,  Tuns64,Tuns64,  Tuns64)

    X(Tuns8,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tuns8,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tuns8,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tuns8,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tuns8,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tuns8,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tuns8,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tuns8,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tuns8,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tint16,Tint16,  Tint32,Tint32,  Tint32)
    X(Tint16,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tint16,Tint32,  Tint32,Tint32,  Tint32)
    X(Tint16,Tuns32,  Tuns32,Tuns32,  Tuns32)
    X(Tint16,Tint64,  Tint64,Tint64,  Tint64)
    X(Tint16,Tuns64,  Tuns64,Tuns64,  Tuns64)

    X(Tint16,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tint16,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tint16,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tint16,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tint16,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tint16,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tint16,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tint16,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tint16,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tuns16,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tuns16,Tint32,  Tint32,Tint32,  Tint32)
    X(Tuns16,Tuns32,  Tuns32,Tuns32,  Tuns32)
    X(Tuns16,Tint64,  Tint64,Tint64,  Tint64)
    X(Tuns16,Tuns64,  Tuns64,Tuns64,  Tuns64)

    X(Tuns16,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tuns16,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tuns16,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tuns16,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tuns16,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tuns16,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tuns16,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tuns16,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tuns16,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tint32,Tint32,  Tint32,Tint32,  Tint32)
    X(Tint32,Tuns32,  Tuns32,Tuns32,  Tuns32)
    X(Tint32,Tint64,  Tint64,Tint64,  Tint64)
    X(Tint32,Tuns64,  Tuns64,Tuns64,  Tuns64)

    X(Tint32,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tint32,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tint32,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tint32,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tint32,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tint32,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tint32,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tint32,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tint32,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tuns32,Tuns32,  Tuns32,Tuns32,  Tuns32)
    X(Tuns32,Tint64,  Tint64,Tint64,  Tint64)
    X(Tuns32,Tuns64,  Tuns64,Tuns64,  Tuns64)

    X(Tuns32,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tuns32,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tuns32,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tuns32,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tuns32,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tuns32,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tuns32,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tuns32,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tuns32,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tint64,Tint64,  Tint64,Tint64,  Tint64)
    X(Tint64,Tuns64,  Tuns64,Tuns64,  Tuns64)

    X(Tint64,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tint64,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tint64,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tint64,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tint64,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tint64,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tint64,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tint64,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tint64,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tuns64,Tuns64,  Tuns64,Tuns64,  Tuns64)

    X(Tuns64,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tuns64,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tuns64,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tuns64,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tuns64,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tuns64,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tuns64,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tuns64,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tuns64,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tfloat32,Tfloat32,  Tfloat32,Tfloat32, Tfloat32)
    X(Tfloat32,Tfloat64,  Tfloat64,Tfloat64, Tfloat64)
    X(Tfloat32,Tfloat80,  Tfloat80,Tfloat80, Tfloat80)

    X(Tfloat32,Timaginary32,  Tfloat32,Timaginary32, Tfloat32)
    X(Tfloat32,Timaginary64,  Tfloat64,Timaginary64, Tfloat64)
    X(Tfloat32,Timaginary80,  Tfloat80,Timaginary80, Tfloat80)

    X(Tfloat32,Tcomplex32,  Tfloat32,Tcomplex32, Tcomplex32)
    X(Tfloat32,Tcomplex64,  Tfloat64,Tcomplex64, Tcomplex64)
    X(Tfloat32,Tcomplex80,  Tfloat80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Tfloat64,Tfloat64,  Tfloat64,Tfloat64, Tfloat64)
    X(Tfloat64,Tfloat80,  Tfloat80,Tfloat80, Tfloat80)

    X(Tfloat64,Timaginary32,  Tfloat64,Timaginary64, Tfloat64)
    X(Tfloat64,Timaginary64,  Tfloat64,Timaginary64, Tfloat64)
    X(Tfloat64,Timaginary80,  Tfloat80,Timaginary80, Tfloat80)

    X(Tfloat64,Tcomplex32,  Tfloat64,Tcomplex64, Tcomplex64)
    X(Tfloat64,Tcomplex64,  Tfloat64,Tcomplex64, Tcomplex64)
    X(Tfloat64,Tcomplex80,  Tfloat80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Tfloat80,Tfloat80,  Tfloat80,Tfloat80, Tfloat80)

    X(Tfloat80,Timaginary32,  Tfloat80,Timaginary80, Tfloat80)
    X(Tfloat80,Timaginary64,  Tfloat80,Timaginary80, Tfloat80)
    X(Tfloat80,Timaginary80,  Tfloat80,Timaginary80, Tfloat80)

    X(Tfloat80,Tcomplex32,  Tfloat80,Tcomplex80, Tcomplex80)
    X(Tfloat80,Tcomplex64,  Tfloat80,Tcomplex80, Tcomplex80)
    X(Tfloat80,Tcomplex80,  Tfloat80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Timaginary32,Timaginary32,  Timaginary32,Timaginary32, Timaginary32)
    X(Timaginary32,Timaginary64,  Timaginary64,Timaginary64, Timaginary64)
    X(Timaginary32,Timaginary80,  Timaginary80,Timaginary80, Timaginary80)

    X(Timaginary32,Tcomplex32,  Timaginary32,Tcomplex32, Tcomplex32)
    X(Timaginary32,Tcomplex64,  Timaginary64,Tcomplex64, Tcomplex64)
    X(Timaginary32,Tcomplex80,  Timaginary80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Timaginary64,Timaginary64,  Timaginary64,Timaginary64, Timaginary64)
    X(Timaginary64,Timaginary80,  Timaginary80,Timaginary80, Timaginary80)

    X(Timaginary64,Tcomplex32,  Timaginary64,Tcomplex64, Tcomplex64)
    X(Timaginary64,Tcomplex64,  Timaginary64,Tcomplex64, Tcomplex64)
    X(Timaginary64,Tcomplex80,  Timaginary80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Timaginary80,Timaginary80,  Timaginary80,Timaginary80, Timaginary80)

    X(Timaginary80,Tcomplex32,  Timaginary80,Tcomplex80, Tcomplex80)
    X(Timaginary80,Tcomplex64,  Timaginary80,Tcomplex80, Tcomplex80)
    X(Timaginary80,Tcomplex80,  Timaginary80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Tcomplex32,Tcomplex32,  Tcomplex32,Tcomplex32, Tcomplex32)
    X(Tcomplex32,Tcomplex64,  Tcomplex64,Tcomplex64, Tcomplex64)
    X(Tcomplex32,Tcomplex80,  Tcomplex80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Tcomplex64,Tcomplex64,  Tcomplex64,Tcomplex64, Tcomplex64)
    X(Tcomplex64,Tcomplex80,  Tcomplex80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Tcomplex80,Tcomplex80,  Tcomplex80,Tcomplex80, Tcomplex80)

#undef X

#define Y(t1,t2)        impcnvWarn[t1][t2] = 1;

    Y(Tuns8, Tint8)
    Y(Tint16, Tint8)
    Y(Tuns16, Tint8)
    Y(Tint32, Tint8)
    Y(Tuns32, Tint8)
    Y(Tint64, Tint8)
    Y(Tuns64, Tint8)

    Y(Tint8, Tuns8)
    Y(Tint16, Tuns8)
    Y(Tuns16, Tuns8)
    Y(Tint32, Tuns8)
    Y(Tuns32, Tuns8)
    Y(Tint64, Tuns8)
    Y(Tuns64, Tuns8)

    Y(Tint8, Tchar)
    Y(Tint16, Tchar)
    Y(Tuns16, Tchar)
    Y(Tint32, Tchar)
    Y(Tuns32, Tchar)
    Y(Tint64, Tchar)
    Y(Tuns64, Tchar)

    Y(Tuns16, Tint16)
    Y(Tint32, Tint16)
    Y(Tuns32, Tint16)
    Y(Tint64, Tint16)
    Y(Tuns64, Tint16)

    Y(Tint16, Tuns16)
    Y(Tint32, Tuns16)
    Y(Tuns32, Tuns16)
    Y(Tint64, Tuns16)
    Y(Tuns64, Tuns16)

    Y(Tint16, Twchar)
    Y(Tint32, Twchar)
    Y(Tuns32, Twchar)
    Y(Tint64, Twchar)
    Y(Tuns64, Twchar)

//    Y(Tuns32, Tint32)
    Y(Tint64, Tint32)
    Y(Tuns64, Tint32)

//    Y(Tint32, Tuns32)
    Y(Tint64, Tuns32)
    Y(Tuns64, Tuns32)

    Y(Tint64, Tdchar)
    Y(Tuns64, Tdchar)

//    Y(Tint64, Tuns64)
//    Y(Tuns64, Tint64)

    for (i = 0; i < TMAX; i++)
        for (j = 0; j < TMAX; j++)
        {
            if (impcnvResult[i][j] == Terror)
            {
                impcnvResult[i][j] = impcnvResult[j][i];
                impcnvType1[i][j] = impcnvType2[j][i];
                impcnvType2[i][j] = impcnvType1[j][i];
            }
        }
}

int main()
{   FILE *fp;
    int i;
    int j;

    init();

    fp = fopen("impcnvtab.c","w");

    fprintf(fp,"// This file is generated by impcnvgen.c\n");
    fprintf(fp,"#include \"mtype.h\"\n");

    fprintf(fp,"unsigned char Type::impcnvResult[TMAX][TMAX] =\n{\n");
    for (i = 0; i < TMAX; i++)
    {
        for (j = 0; j < TMAX; j++)
        {
            fprintf(fp, "%d,",impcnvResult[i][j]);
        }
        fprintf(fp, "\n");
    }
    fprintf(fp,"};\n");

    fprintf(fp,"unsigned char Type::impcnvType1[TMAX][TMAX] =\n{\n");
    for (i = 0; i < TMAX; i++)
    {
        for (j = 0; j < TMAX; j++)
        {
            fprintf(fp, "%d,",impcnvType1[i][j]);
        }
        fprintf(fp, "\n");
    }
    fprintf(fp,"};\n");

    fprintf(fp,"unsigned char Type::impcnvType2[TMAX][TMAX] =\n{\n");
    for (i = 0; i < TMAX; i++)
    {
        for (j = 0; j < TMAX; j++)
        {
            fprintf(fp, "%d,",impcnvType2[i][j]);
        }
        fprintf(fp, "\n");
    }
    fprintf(fp,"};\n");

    fprintf(fp,"unsigned char Type::impcnvWarn[TMAX][TMAX] =\n{\n");
    for (i = 0; i < TMAX; i++)
    {
        for (j = 0; j < TMAX; j++)
        {
            fprintf(fp, "%d,",impcnvWarn[i][j]);
        }
        fprintf(fp, "\n");
    }
    fprintf(fp,"};\n");

    fclose(fp);
    return EXIT_SUCCESS;
}
