
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>

#include "mtype.h"

enum TY impcnvResult[TMAX][TMAX];
enum TY impcnvType1[TMAX][TMAX];
enum TY impcnvType2[TMAX][TMAX];

void init()
{   int i, j;

    // Set conversion tables
    for (i = 0; i < TMAX; i++)
	for (j = 0; j < TMAX; j++)
	{   impcnvResult[i][j] = Terror;
	    impcnvType1[i][j] = Terror;
	    impcnvType2[i][j] = Terror;
	}

#define X(t1,t2, nt1,nt2, rt)		\
	impcnvResult[t1][t2] = rt;	\
	impcnvType1[t1][t2] = nt1;	\
	impcnvType2[t1][t2] = nt2;

    /* ======================= */

    X(Tbit,Tbit,    Tint32,Tint32,  Tint32)
    X(Tbit,Tint8,   Tint32,Tint32,  Tint32)
    X(Tbit,Tuns8,   Tint32,Tint32,  Tint32)
    X(Tbit,Tint16,  Tint32,Tint32,  Tint32)
    X(Tbit,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tbit,Tint32,  Tint32,Tint32,  Tint32)
    X(Tbit,Tuns32,  Tint32,Tuns32,  Tint32)
    X(Tbit,Tint64,  Tint64,Tint64,  Tint64)
    X(Tbit,Tuns64,  Tint64,Tuns64,  Tint64)

    X(Tbit,Tfloat32,     Tfloat32,Tfloat32,     Tfloat32)
    X(Tbit,Tfloat64,     Tfloat64,Tfloat64,     Tfloat64)
    X(Tbit,Tfloat80,     Tfloat80,Tfloat80,     Tfloat80)
    X(Tbit,Timaginary32, Tfloat32,Timaginary32, Tfloat32)
    X(Tbit,Timaginary64, Tfloat64,Timaginary64, Tfloat64)
    X(Tbit,Timaginary80, Tfloat80,Timaginary80, Tfloat80)
    X(Tbit,Tcomplex32,   Tfloat32,Tcomplex32,   Tcomplex32)
    X(Tbit,Tcomplex64,   Tfloat64,Tcomplex64,   Tcomplex64)
    X(Tbit,Tcomplex80,   Tfloat80,Tcomplex80,   Tcomplex80)

    /* ======================= */

    X(Tint8,Tbit,    Tint32,Tint32,  Tint32)
    X(Tint8,Tint8,   Tint32,Tint32,  Tint32)
    X(Tint8,Tuns8,   Tint32,Tint32,  Tint32)
    X(Tint8,Tint16,  Tint32,Tint32,  Tint32)
    X(Tint8,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tint8,Tint32,  Tint32,Tint32,  Tint32)
    X(Tint8,Tuns32,  Tint32,Tuns32,  Tint32)
    X(Tint8,Tint64,  Tint64,Tint64,  Tint64)
    X(Tint8,Tuns64,  Tint64,Tuns64,  Tint64)

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

    X(Tuns8,Tbit,    Tint32,Tint32,  Tint32)
    X(Tuns8,Tint8,   Tint32,Tint32,  Tint32)
    X(Tuns8,Tuns8,   Tint32,Tint32,  Tint32)
    X(Tuns8,Tint16,  Tint32,Tint32,  Tint32)
    X(Tuns8,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tuns8,Tint32,  Tint32,Tint32,  Tint32)
    X(Tuns8,Tuns32,  Tint32,Tuns32,  Tint32)
    X(Tuns8,Tint64,  Tint64,Tint64,  Tint64)
    X(Tuns8,Tuns64,  Tint64,Tuns64,  Tint64)

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

    X(Tint16,Tbit,    Tint32,Tint32,  Tint32)
    X(Tint16,Tint8,   Tint32,Tint32,  Tint32)
    X(Tint16,Tuns8,   Tint32,Tint32,  Tint32)
    X(Tint16,Tint16,  Tint32,Tint32,  Tint32)
    X(Tint16,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tint16,Tint32,  Tint32,Tint32,  Tint32)
    X(Tint16,Tuns32,  Tint32,Tuns32,  Tint32)
    X(Tint16,Tint64,  Tint64,Tint64,  Tint64)
    X(Tint16,Tuns64,  Tint64,Tuns64,  Tint64)

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

    X(Tuns16,Tbit,    Tint32,Tint32,  Tint32)
    X(Tuns16,Tint8,   Tint32,Tint32,  Tint32)
    X(Tuns16,Tuns8,   Tint32,Tint32,  Tint32)
    X(Tuns16,Tint16,  Tint32,Tint32,  Tint32)
    X(Tuns16,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tuns16,Tint32,  Tint32,Tint32,  Tint32)
    X(Tuns16,Tuns32,  Tint32,Tuns32,  Tint32)
    X(Tuns16,Tint64,  Tint64,Tint64,  Tint64)
    X(Tuns16,Tuns64,  Tint64,Tuns64,  Tint64)

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

    X(Tint32,Tbit,    Tint32,Tint32,  Tint32)
    X(Tint32,Tint8,   Tint32,Tint32,  Tint32)
    X(Tint32,Tuns8,   Tint32,Tint32,  Tint32)
    X(Tint32,Tint16,  Tint32,Tint32,  Tint32)
    X(Tint32,Tuns16,  Tint32,Tint32,  Tint32)
    X(Tint32,Tint32,  Tint32,Tint32,  Tint32)
    X(Tint32,Tuns32,  Tint32,Tuns32,  Tint32)
    X(Tint32,Tint64,  Tint64,Tint64,  Tint64)
    X(Tint32,Tuns64,  Tint64,Tuns64,  Tint64)

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

    X(Tuns32,Tbit,    Tuns32,Tint32,  Tint32)
    X(Tuns32,Tint8,   Tuns32,Tint32,  Tint32)
    X(Tuns32,Tuns8,   Tuns32,Tint32,  Tint32)
    X(Tuns32,Tint16,  Tuns32,Tint32,  Tint32)
    X(Tuns32,Tuns16,  Tuns32,Tint32,  Tint32)
    X(Tuns32,Tint32,  Tuns32,Tint32,  Tint32)
    X(Tuns32,Tuns32,  Tuns32,Tuns32,  Tint32)
    X(Tuns32,Tint64,  Tuns64,Tint64,  Tint64)
    X(Tuns32,Tuns64,  Tuns64,Tuns64,  Tint64)

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

    X(Tint64,Tbit,    Tint64,Tint64,  Tint64)
    X(Tint64,Tint8,   Tint64,Tint64,  Tint64)
    X(Tint64,Tuns8,   Tint64,Tint64,  Tint64)
    X(Tint64,Tint16,  Tint64,Tint64,  Tint64)
    X(Tint64,Tuns16,  Tint64,Tint64,  Tint64)
    X(Tint64,Tint32,  Tint64,Tint64,  Tint64)
    X(Tint64,Tuns32,  Tint64,Tint64,  Tint64)
    X(Tint64,Tint64,  Tint64,Tint64,  Tint64)
    X(Tint64,Tuns64,  Tint64,Tuns64,  Tint64)

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

    X(Tuns64,Tbit,    Tuns64,Tint64,  Tint64)
    X(Tuns64,Tint8,   Tuns64,Tint64,  Tint64)
    X(Tuns64,Tuns8,   Tuns64,Tint64,  Tint64)
    X(Tuns64,Tint16,  Tuns64,Tint64,  Tint64)
    X(Tuns64,Tuns16,  Tuns64,Tint64,  Tint64)
    X(Tuns64,Tint32,  Tuns64,Tint64,  Tint64)
    X(Tuns64,Tuns32,  Tuns64,Tint64,  Tint64)
    X(Tuns64,Tint64,  Tuns64,Tint64,  Tint64)
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

    X(Tfloat32,Tbit,    Tfloat32,Tfloat32,  Tfloat32)
    X(Tfloat32,Tint8,   Tfloat32,Tfloat32,  Tfloat32)
    X(Tfloat32,Tuns8,   Tfloat32,Tfloat32,  Tfloat32)
    X(Tfloat32,Tint16,  Tfloat32,Tfloat32,  Tfloat32)
    X(Tfloat32,Tuns16,  Tfloat32,Tfloat32,  Tfloat32)
    X(Tfloat32,Tint32,  Tfloat32,Tfloat32,  Tfloat32)
    X(Tfloat32,Tuns32,  Tfloat32,Tfloat32,  Tfloat32)
    X(Tfloat32,Tint64,  Tfloat32,Tfloat32,  Tfloat32)
    X(Tfloat32,Tuns64,  Tfloat32,Tfloat32,  Tfloat32)

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

    X(Tfloat64,Tbit,    Tfloat64,Tfloat64,  Tfloat64)
    X(Tfloat64,Tint8,   Tfloat64,Tfloat64,  Tfloat64)
    X(Tfloat64,Tuns8,   Tfloat64,Tfloat64,  Tfloat64)
    X(Tfloat64,Tint16,  Tfloat64,Tfloat64,  Tfloat64)
    X(Tfloat64,Tuns16,  Tfloat64,Tfloat64,  Tfloat64)
    X(Tfloat64,Tint32,  Tfloat64,Tfloat64,  Tfloat64)
    X(Tfloat64,Tuns32,  Tfloat64,Tfloat64,  Tfloat64)
    X(Tfloat64,Tint64,  Tfloat64,Tfloat64,  Tfloat64)
    X(Tfloat64,Tuns64,  Tfloat64,Tfloat64,  Tfloat64)

    X(Tfloat64,Tfloat32,  Tfloat64,Tfloat64, Tfloat64)
    X(Tfloat64,Tfloat64,  Tfloat64,Tfloat64, Tfloat64)
    X(Tfloat64,Tfloat80,  Tfloat80,Tfloat80, Tfloat80)

    X(Tfloat64,Timaginary32,  Tfloat64,Timaginary64, Tfloat64)
    X(Tfloat64,Timaginary64,  Tfloat64,Timaginary64, Tfloat64)
    X(Tfloat64,Timaginary80,  Tfloat80,Timaginary80, Tfloat80)

    X(Tfloat64,Tcomplex32,  Tfloat64,Tcomplex64, Tcomplex64)
    X(Tfloat64,Tcomplex64,  Tfloat64,Tcomplex64, Tcomplex64)
    X(Tfloat64,Tcomplex80,  Tfloat80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Tfloat80,Tbit,    Tfloat80,Tfloat80,  Tfloat80)
    X(Tfloat80,Tint8,   Tfloat80,Tfloat80,  Tfloat80)
    X(Tfloat80,Tuns8,   Tfloat80,Tfloat80,  Tfloat80)
    X(Tfloat80,Tint16,  Tfloat80,Tfloat80,  Tfloat80)
    X(Tfloat80,Tuns16,  Tfloat80,Tfloat80,  Tfloat80)
    X(Tfloat80,Tint32,  Tfloat80,Tfloat80,  Tfloat80)
    X(Tfloat80,Tuns32,  Tfloat80,Tfloat80,  Tfloat80)
    X(Tfloat80,Tint64,  Tfloat80,Tfloat80,  Tfloat80)
    X(Tfloat80,Tuns64,  Tfloat80,Tfloat80,  Tfloat80)

    X(Tfloat80,Tfloat32,  Tfloat80,Tfloat80, Tfloat80)
    X(Tfloat80,Tfloat64,  Tfloat80,Tfloat80, Tfloat80)
    X(Tfloat80,Tfloat80,  Tfloat80,Tfloat80, Tfloat80)

    X(Tfloat80,Timaginary32,  Tfloat80,Timaginary80, Tfloat80)
    X(Tfloat80,Timaginary64,  Tfloat80,Timaginary80, Tfloat80)
    X(Tfloat80,Timaginary80,  Tfloat80,Timaginary80, Tfloat80)

    X(Tfloat80,Tcomplex32,  Tfloat80,Tcomplex80, Tcomplex80)
    X(Tfloat80,Tcomplex64,  Tfloat80,Tcomplex80, Tcomplex80)
    X(Tfloat80,Tcomplex80,  Tfloat80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Timaginary32,Tbit,    Timaginary32,Tfloat32,  Tfloat32)
    X(Timaginary32,Tint8,   Timaginary32,Tfloat32,  Tfloat32)
    X(Timaginary32,Tuns8,   Timaginary32,Tfloat32,  Tfloat32)
    X(Timaginary32,Tint16,  Timaginary32,Tfloat32,  Tfloat32)
    X(Timaginary32,Tuns16,  Timaginary32,Tfloat32,  Tfloat32)
    X(Timaginary32,Tint32,  Timaginary32,Tfloat32,  Tfloat32)
    X(Timaginary32,Tuns32,  Timaginary32,Tfloat32,  Tfloat32)
    X(Timaginary32,Tint64,  Timaginary32,Tfloat32,  Tfloat32)
    X(Timaginary32,Tuns64,  Timaginary32,Tfloat32,  Tfloat32)

    X(Timaginary32,Tfloat32,  Timaginary32,Tfloat32, Tfloat32)
    X(Timaginary32,Tfloat64,  Timaginary64,Tfloat64, Tfloat64)
    X(Timaginary32,Tfloat80,  Timaginary80,Tfloat80, Tfloat80)

    X(Timaginary32,Timaginary32,  Timaginary32,Timaginary32, Timaginary32)
    X(Timaginary32,Timaginary64,  Timaginary64,Timaginary64, Timaginary64)
    X(Timaginary32,Timaginary80,  Timaginary80,Timaginary80, Timaginary80)

    X(Timaginary32,Tcomplex32,  Timaginary32,Tcomplex32, Tcomplex32)
    X(Timaginary32,Tcomplex64,  Timaginary64,Tcomplex64, Tcomplex64)
    X(Timaginary32,Tcomplex80,  Timaginary80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Timaginary64,Tbit,    Timaginary64,Tfloat64,  Tfloat64)
    X(Timaginary64,Tint8,   Timaginary64,Tfloat64,  Tfloat64)
    X(Timaginary64,Tuns8,   Timaginary64,Tfloat64,  Tfloat64)
    X(Timaginary64,Tint16,  Timaginary64,Tfloat64,  Tfloat64)
    X(Timaginary64,Tuns16,  Timaginary64,Tfloat64,  Tfloat64)
    X(Timaginary64,Tint32,  Timaginary64,Tfloat64,  Tfloat64)
    X(Timaginary64,Tuns32,  Timaginary64,Tfloat64,  Tfloat64)
    X(Timaginary64,Tint64,  Timaginary64,Tfloat64,  Tfloat64)
    X(Timaginary64,Tuns64,  Timaginary64,Tfloat64,  Tfloat64)

    X(Timaginary64,Tfloat32,  Timaginary64,Tfloat64, Tfloat64)
    X(Timaginary64,Tfloat64,  Timaginary64,Tfloat64, Tfloat64)
    X(Timaginary64,Tfloat80,  Timaginary80,Tfloat80, Tfloat80)

    X(Timaginary64,Timaginary32,  Timaginary64,Timaginary64, Timaginary64)
    X(Timaginary64,Timaginary64,  Timaginary64,Timaginary64, Timaginary64)
    X(Timaginary64,Timaginary80,  Timaginary80,Timaginary80, Timaginary80)

    X(Timaginary64,Tcomplex32,  Timaginary64,Tcomplex64, Tcomplex64)
    X(Timaginary64,Tcomplex64,  Timaginary64,Tcomplex64, Tcomplex64)
    X(Timaginary64,Tcomplex80,  Timaginary80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Timaginary80,Tbit,    Timaginary80,Tfloat80,  Tfloat80)
    X(Timaginary80,Tint8,   Timaginary80,Tfloat80,  Tfloat80)
    X(Timaginary80,Tuns8,   Timaginary80,Tfloat80,  Tfloat80)
    X(Timaginary80,Tint16,  Timaginary80,Tfloat80,  Tfloat80)
    X(Timaginary80,Tuns16,  Timaginary80,Tfloat80,  Tfloat80)
    X(Timaginary80,Tint32,  Timaginary80,Tfloat80,  Tfloat80)
    X(Timaginary80,Tuns32,  Timaginary80,Tfloat80,  Tfloat80)
    X(Timaginary80,Tint64,  Timaginary80,Tfloat80,  Tfloat80)
    X(Timaginary80,Tuns64,  Timaginary80,Tfloat80,  Tfloat80)

    X(Timaginary80,Tfloat32,  Timaginary80,Tfloat80, Tfloat80)
    X(Timaginary80,Tfloat64,  Timaginary80,Tfloat80, Tfloat80)
    X(Timaginary80,Tfloat80,  Timaginary80,Tfloat80, Tfloat80)

    X(Timaginary80,Timaginary32,  Timaginary80,Timaginary80, Timaginary80)
    X(Timaginary80,Timaginary64,  Timaginary80,Timaginary80, Timaginary80)
    X(Timaginary80,Timaginary80,  Timaginary80,Timaginary80, Timaginary80)

    X(Timaginary80,Tcomplex32,  Timaginary80,Tcomplex80, Tcomplex80)
    X(Timaginary80,Tcomplex64,  Timaginary80,Tcomplex80, Tcomplex80)
    X(Timaginary80,Tcomplex80,  Timaginary80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Tcomplex32,Tbit,    Tcomplex32,Tfloat32,  Tcomplex32)
    X(Tcomplex32,Tint8,   Tcomplex32,Tfloat32,  Tcomplex32)
    X(Tcomplex32,Tuns8,   Tcomplex32,Tfloat32,  Tcomplex32)
    X(Tcomplex32,Tint16,  Tcomplex32,Tfloat32,  Tcomplex32)
    X(Tcomplex32,Tuns16,  Tcomplex32,Tfloat32,  Tcomplex32)
    X(Tcomplex32,Tint32,  Tcomplex32,Tfloat32,  Tcomplex32)
    X(Tcomplex32,Tuns32,  Tcomplex32,Tfloat32,  Tcomplex32)
    X(Tcomplex32,Tint64,  Tcomplex32,Tfloat32,  Tcomplex32)
    X(Tcomplex32,Tuns64,  Tcomplex32,Tfloat32,  Tcomplex32)

    X(Tcomplex32,Tfloat32,  Tcomplex32,Tfloat32, Tcomplex32)
    X(Tcomplex32,Tfloat64,  Tcomplex64,Tfloat64, Tcomplex64)
    X(Tcomplex32,Tfloat80,  Tcomplex80,Tfloat80, Tcomplex80)

    X(Tcomplex32,Timaginary32,  Tcomplex32,Timaginary32, Tcomplex32)
    X(Tcomplex32,Timaginary64,  Tcomplex64,Timaginary64, Tcomplex64)
    X(Tcomplex32,Timaginary80,  Tcomplex80,Timaginary80, Tcomplex80)

    X(Tcomplex32,Tcomplex32,  Tcomplex32,Tcomplex32, Tcomplex32)
    X(Tcomplex32,Tcomplex64,  Tcomplex64,Tcomplex64, Tcomplex64)
    X(Tcomplex32,Tcomplex80,  Tcomplex80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Tcomplex64,Tbit,    Tcomplex64,Tfloat64,  Tcomplex64)
    X(Tcomplex64,Tint8,   Tcomplex64,Tfloat64,  Tcomplex64)
    X(Tcomplex64,Tuns8,   Tcomplex64,Tfloat64,  Tcomplex64)
    X(Tcomplex64,Tint16,  Tcomplex64,Tfloat64,  Tcomplex64)
    X(Tcomplex64,Tuns16,  Tcomplex64,Tfloat64,  Tcomplex64)
    X(Tcomplex64,Tint32,  Tcomplex64,Tfloat64,  Tcomplex64)
    X(Tcomplex64,Tuns32,  Tcomplex64,Tfloat64,  Tcomplex64)
    X(Tcomplex64,Tint64,  Tcomplex64,Tfloat64,  Tcomplex64)
    X(Tcomplex64,Tuns64,  Tcomplex64,Tfloat64,  Tcomplex64)

    X(Tcomplex64,Tfloat32,  Tcomplex64,Tfloat64, Tcomplex64)
    X(Tcomplex64,Tfloat64,  Tcomplex64,Tfloat64, Tcomplex64)
    X(Tcomplex64,Tfloat80,  Tcomplex80,Tfloat80, Tcomplex80)

    X(Tcomplex64,Timaginary32,  Tcomplex64,Timaginary64, Tcomplex64)
    X(Tcomplex64,Timaginary64,  Tcomplex64,Timaginary64, Tcomplex64)
    X(Tcomplex64,Timaginary80,  Tcomplex80,Timaginary80, Tcomplex80)

    X(Tcomplex64,Tcomplex32,  Tcomplex64,Tcomplex64, Tcomplex64)
    X(Tcomplex64,Tcomplex64,  Tcomplex64,Tcomplex64, Tcomplex64)
    X(Tcomplex64,Tcomplex80,  Tcomplex80,Tcomplex80, Tcomplex80)

    /* ======================= */

    X(Tcomplex80,Tbit,    Tcomplex80,Tfloat80,  Tcomplex80)
    X(Tcomplex80,Tint8,   Tcomplex80,Tfloat80,  Tcomplex80)
    X(Tcomplex80,Tuns8,   Tcomplex80,Tfloat80,  Tcomplex80)
    X(Tcomplex80,Tint16,  Tcomplex80,Tfloat80,  Tcomplex80)
    X(Tcomplex80,Tuns16,  Tcomplex80,Tfloat80,  Tcomplex80)
    X(Tcomplex80,Tint32,  Tcomplex80,Tfloat80,  Tcomplex80)
    X(Tcomplex80,Tuns32,  Tcomplex80,Tfloat80,  Tcomplex80)
    X(Tcomplex80,Tint64,  Tcomplex80,Tfloat80,  Tcomplex80)
    X(Tcomplex80,Tuns64,  Tcomplex80,Tfloat80,  Tcomplex80)

    X(Tcomplex80,Tfloat32,  Tcomplex80,Tfloat80, Tcomplex80)
    X(Tcomplex80,Tfloat64,  Tcomplex80,Tfloat80, Tcomplex80)
    X(Tcomplex80,Tfloat80,  Tcomplex80,Tfloat80, Tcomplex80)

    X(Tcomplex80,Timaginary32,  Tcomplex80,Timaginary80, Tcomplex80)
    X(Tcomplex80,Timaginary64,  Tcomplex80,Timaginary80, Tcomplex80)
    X(Tcomplex80,Timaginary80,  Tcomplex80,Timaginary80, Tcomplex80)

    X(Tcomplex80,Tcomplex32,  Tcomplex80,Tcomplex80, Tcomplex80)
    X(Tcomplex80,Tcomplex64,  Tcomplex80,Tcomplex80, Tcomplex80)
    X(Tcomplex80,Tcomplex80,  Tcomplex80,Tcomplex80, Tcomplex80)
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

    fclose(fp);
    return EXIT_SUCCESS;
}
