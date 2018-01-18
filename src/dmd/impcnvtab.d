/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/impcnvtab.d, _impcnvtab.d)
 * Documentation:  https://dlang.org/phobos/dmd_impcnvtab.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/impcnvtab.d
 */

module dmd.impcnvtab;

import dmd.mtype;

immutable TY[TY.MAX][TY.MAX] impcnvResult = impCnvTab.impcnvResultTab;
immutable TY[TY.MAX][TY.MAX] impcnvType1 = impCnvTab.impcnvType1Tab;
immutable TY[TY.MAX][TY.MAX] impcnvType2 = impCnvTab.impcnvType2Tab;

private:

struct ImpCnvTab
{
    TY[TY.MAX][TY.MAX] impcnvResultTab;
    TY[TY.MAX][TY.MAX] impcnvType1Tab;
    TY[TY.MAX][TY.MAX] impcnvType2Tab;
}

enum ImpCnvTab impCnvTab = generateImpCnvTab();

ImpCnvTab generateImpCnvTab()
{
    ImpCnvTab impCnvTab;

    // Set conversion tables
    foreach (i; 0 .. cast(size_t)TY.MAX)
    {
        foreach (j; 0 .. cast(size_t)TY.MAX)
        {
            impCnvTab.impcnvResultTab[i][j] = TY.error;
            impCnvTab.impcnvType1Tab[i][j] = TY.error;
            impCnvTab.impcnvType2Tab[i][j] = TY.error;
        }
    }

    void X(TY t1, TY t2, TY nt1, TY nt2, TY rt)
    {
        impCnvTab.impcnvResultTab[t1][t2] = rt;
        impCnvTab.impcnvType1Tab[t1][t2] = nt1;
        impCnvTab.impcnvType2Tab[t1][t2] = nt2;
    }

    /* ======================= */

    X(TY.bool_,TY.bool_,   TY.bool_,TY.bool_,    TY.bool_);
    X(TY.bool_,TY.int8,   TY.int32,TY.int32,  TY.int32);
    X(TY.bool_,TY.uns8,   TY.int32,TY.int32,  TY.int32);
    X(TY.bool_,TY.int16,  TY.int32,TY.int32,  TY.int32);
    X(TY.bool_,TY.uns16,  TY.int32,TY.int32,  TY.int32);
    X(TY.bool_,TY.int32,  TY.int32,TY.int32,  TY.int32);
    X(TY.bool_,TY.uns32,  TY.uns32,TY.uns32,  TY.uns32);
    X(TY.bool_,TY.int64,  TY.int64,TY.int64,  TY.int64);
    X(TY.bool_,TY.uns64,  TY.uns64,TY.uns64,  TY.uns64);
    X(TY.bool_,TY.int128, TY.int128,TY.int128, TY.int128);
    X(TY.bool_,TY.uns128, TY.uns128,TY.uns128, TY.uns128);

    X(TY.bool_,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.bool_,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.bool_,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.bool_,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.bool_,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.bool_,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.bool_,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.bool_,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.bool_,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.int8,TY.int8,   TY.int32,TY.int32,  TY.int32);
    X(TY.int8,TY.uns8,   TY.int32,TY.int32,  TY.int32);
    X(TY.int8,TY.int16,  TY.int32,TY.int32,  TY.int32);
    X(TY.int8,TY.uns16,  TY.int32,TY.int32,  TY.int32);
    X(TY.int8,TY.int32,  TY.int32,TY.int32,  TY.int32);
    X(TY.int8,TY.uns32,  TY.uns32,TY.uns32,  TY.uns32);
    X(TY.int8,TY.int64,  TY.int64,TY.int64,  TY.int64);
    X(TY.int8,TY.uns64,  TY.uns64,TY.uns64,  TY.uns64);
    X(TY.int8,TY.int128, TY.int128,TY.int128, TY.int128);
    X(TY.int8,TY.uns128, TY.uns128,TY.uns128, TY.uns128);

    X(TY.int8,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.int8,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.int8,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.int8,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.int8,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.int8,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.int8,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.int8,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.int8,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.uns8,TY.uns8,   TY.int32,TY.int32,  TY.int32);
    X(TY.uns8,TY.int16,  TY.int32,TY.int32,  TY.int32);
    X(TY.uns8,TY.uns16,  TY.int32,TY.int32,  TY.int32);
    X(TY.uns8,TY.int32,  TY.int32,TY.int32,  TY.int32);
    X(TY.uns8,TY.uns32,  TY.uns32,TY.uns32,  TY.uns32);
    X(TY.uns8,TY.int64,  TY.int64,TY.int64,  TY.int64);
    X(TY.uns8,TY.uns64,  TY.uns64,TY.uns64,  TY.uns64);
    X(TY.uns8,TY.int128,  TY.int128,TY.int128,  TY.int128);
    X(TY.uns8,TY.uns128,  TY.uns128,TY.uns128,  TY.uns128);

    X(TY.uns8,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.uns8,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.uns8,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.uns8,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.uns8,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.uns8,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.uns8,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.uns8,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.uns8,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.int16,TY.int16,  TY.int32,TY.int32,  TY.int32);
    X(TY.int16,TY.uns16,  TY.int32,TY.int32,  TY.int32);
    X(TY.int16,TY.int32,  TY.int32,TY.int32,  TY.int32);
    X(TY.int16,TY.uns32,  TY.uns32,TY.uns32,  TY.uns32);
    X(TY.int16,TY.int64,  TY.int64,TY.int64,  TY.int64);
    X(TY.int16,TY.uns64,  TY.uns64,TY.uns64,  TY.uns64);
    X(TY.int16,TY.int128,  TY.int128,TY.int128,  TY.int128);
    X(TY.int16,TY.uns128,  TY.uns128,TY.uns128,  TY.uns128);

    X(TY.int16,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.int16,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.int16,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.int16,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.int16,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.int16,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.int16,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.int16,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.int16,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.uns16,TY.uns16,  TY.int32,TY.int32,  TY.int32);
    X(TY.uns16,TY.int32,  TY.int32,TY.int32,  TY.int32);
    X(TY.uns16,TY.uns32,  TY.uns32,TY.uns32,  TY.uns32);
    X(TY.uns16,TY.int64,  TY.int64,TY.int64,  TY.int64);
    X(TY.uns16,TY.uns64,  TY.uns64,TY.uns64,  TY.uns64);
    X(TY.uns16,TY.int128, TY.int128,TY.int128,  TY.int128);
    X(TY.uns16,TY.uns128, TY.uns128,TY.uns128,  TY.uns128);

    X(TY.uns16,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.uns16,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.uns16,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.uns16,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.uns16,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.uns16,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.uns16,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.uns16,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.uns16,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.int32,TY.int32,  TY.int32,TY.int32,  TY.int32);
    X(TY.int32,TY.uns32,  TY.uns32,TY.uns32,  TY.uns32);
    X(TY.int32,TY.int64,  TY.int64,TY.int64,  TY.int64);
    X(TY.int32,TY.uns64,  TY.uns64,TY.uns64,  TY.uns64);
    X(TY.int32,TY.int128, TY.int128,TY.int128,  TY.int128);
    X(TY.int32,TY.uns128, TY.uns128,TY.uns128,  TY.uns128);

    X(TY.int32,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.int32,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.int32,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.int32,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.int32,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.int32,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.int32,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.int32,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.int32,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.uns32,TY.uns32,  TY.uns32,TY.uns32,  TY.uns32);
    X(TY.uns32,TY.int64,  TY.int64,TY.int64,  TY.int64);
    X(TY.uns32,TY.uns64,  TY.uns64,TY.uns64,  TY.uns64);
    X(TY.uns32,TY.int128,  TY.int128,TY.int128,  TY.int128);
    X(TY.uns32,TY.uns128,  TY.uns128,TY.uns128,  TY.uns128);

    X(TY.uns32,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.uns32,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.uns32,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.uns32,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.uns32,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.uns32,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.uns32,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.uns32,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.uns32,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.int64,TY.int64,  TY.int64,TY.int64,  TY.int64);
    X(TY.int64,TY.uns64,  TY.uns64,TY.uns64,  TY.uns64);
    X(TY.int64,TY.int128,  TY.int128,TY.int128,  TY.int128);
    X(TY.int64,TY.uns128,  TY.uns128,TY.uns128,  TY.uns128);

    X(TY.int64,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.int64,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.int64,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.int64,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.int64,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.int64,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.int64,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.int64,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.int64,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.uns64,TY.uns64,  TY.uns64,TY.uns64,  TY.uns64);
    X(TY.uns64,TY.int128,  TY.int128,TY.int128,  TY.int128);
    X(TY.uns64,TY.uns128,  TY.uns128,TY.uns128,  TY.uns128);

    X(TY.uns64,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.uns64,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.uns64,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.uns64,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.uns64,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.uns64,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.uns64,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.uns64,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.uns64,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.int128,TY.int128,  TY.int128,TY.int128,  TY.int128);
    X(TY.int128,TY.uns128,  TY.uns128,TY.uns128,  TY.uns128);

    X(TY.int128,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.int128,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.int128,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.int128,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.int128,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.int128,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.int128,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.int128,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.int128,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.uns128,TY.uns128,  TY.uns128,TY.uns128,  TY.uns128);

    X(TY.uns128,TY.float32,     TY.float32,TY.float32,     TY.float32);
    X(TY.uns128,TY.float64,     TY.float64,TY.float64,     TY.float64);
    X(TY.uns128,TY.float80,     TY.float80,TY.float80,     TY.float80);
    X(TY.uns128,TY.imaginary32, TY.float32,TY.imaginary32, TY.float32);
    X(TY.uns128,TY.imaginary64, TY.float64,TY.imaginary64, TY.float64);
    X(TY.uns128,TY.imaginary80, TY.float80,TY.imaginary80, TY.float80);
    X(TY.uns128,TY.complex32,   TY.float32,TY.complex32,   TY.complex32);
    X(TY.uns128,TY.complex64,   TY.float64,TY.complex64,   TY.complex64);
    X(TY.uns128,TY.complex80,   TY.float80,TY.complex80,   TY.complex80);

    /* ======================= */

    X(TY.float32,TY.float32,  TY.float32,TY.float32, TY.float32);
    X(TY.float32,TY.float64,  TY.float64,TY.float64, TY.float64);
    X(TY.float32,TY.float80,  TY.float80,TY.float80, TY.float80);

    X(TY.float32,TY.imaginary32,  TY.float32,TY.imaginary32, TY.float32);
    X(TY.float32,TY.imaginary64,  TY.float64,TY.imaginary64, TY.float64);
    X(TY.float32,TY.imaginary80,  TY.float80,TY.imaginary80, TY.float80);

    X(TY.float32,TY.complex32,  TY.float32,TY.complex32, TY.complex32);
    X(TY.float32,TY.complex64,  TY.float64,TY.complex64, TY.complex64);
    X(TY.float32,TY.complex80,  TY.float80,TY.complex80, TY.complex80);

    /* ======================= */

    X(TY.float64,TY.float64,  TY.float64,TY.float64, TY.float64);
    X(TY.float64,TY.float80,  TY.float80,TY.float80, TY.float80);

    X(TY.float64,TY.imaginary32,  TY.float64,TY.imaginary64, TY.float64);
    X(TY.float64,TY.imaginary64,  TY.float64,TY.imaginary64, TY.float64);
    X(TY.float64,TY.imaginary80,  TY.float80,TY.imaginary80, TY.float80);

    X(TY.float64,TY.complex32,  TY.float64,TY.complex64, TY.complex64);
    X(TY.float64,TY.complex64,  TY.float64,TY.complex64, TY.complex64);
    X(TY.float64,TY.complex80,  TY.float80,TY.complex80, TY.complex80);

    /* ======================= */

    X(TY.float80,TY.float80,  TY.float80,TY.float80, TY.float80);

    X(TY.float80,TY.imaginary32,  TY.float80,TY.imaginary80, TY.float80);
    X(TY.float80,TY.imaginary64,  TY.float80,TY.imaginary80, TY.float80);
    X(TY.float80,TY.imaginary80,  TY.float80,TY.imaginary80, TY.float80);

    X(TY.float80,TY.complex32,  TY.float80,TY.complex80, TY.complex80);
    X(TY.float80,TY.complex64,  TY.float80,TY.complex80, TY.complex80);
    X(TY.float80,TY.complex80,  TY.float80,TY.complex80, TY.complex80);

    /* ======================= */

    X(TY.imaginary32,TY.imaginary32,  TY.imaginary32,TY.imaginary32, TY.imaginary32);
    X(TY.imaginary32,TY.imaginary64,  TY.imaginary64,TY.imaginary64, TY.imaginary64);
    X(TY.imaginary32,TY.imaginary80,  TY.imaginary80,TY.imaginary80, TY.imaginary80);

    X(TY.imaginary32,TY.complex32,  TY.imaginary32,TY.complex32, TY.complex32);
    X(TY.imaginary32,TY.complex64,  TY.imaginary64,TY.complex64, TY.complex64);
    X(TY.imaginary32,TY.complex80,  TY.imaginary80,TY.complex80, TY.complex80);

    /* ======================= */

    X(TY.imaginary64,TY.imaginary64,  TY.imaginary64,TY.imaginary64, TY.imaginary64);
    X(TY.imaginary64,TY.imaginary80,  TY.imaginary80,TY.imaginary80, TY.imaginary80);

    X(TY.imaginary64,TY.complex32,  TY.imaginary64,TY.complex64, TY.complex64);
    X(TY.imaginary64,TY.complex64,  TY.imaginary64,TY.complex64, TY.complex64);
    X(TY.imaginary64,TY.complex80,  TY.imaginary80,TY.complex80, TY.complex80);

    /* ======================= */

    X(TY.imaginary80,TY.imaginary80,  TY.imaginary80,TY.imaginary80, TY.imaginary80);

    X(TY.imaginary80,TY.complex32,  TY.imaginary80,TY.complex80, TY.complex80);
    X(TY.imaginary80,TY.complex64,  TY.imaginary80,TY.complex80, TY.complex80);
    X(TY.imaginary80,TY.complex80,  TY.imaginary80,TY.complex80, TY.complex80);

    /* ======================= */

    X(TY.complex32,TY.complex32,  TY.complex32,TY.complex32, TY.complex32);
    X(TY.complex32,TY.complex64,  TY.complex64,TY.complex64, TY.complex64);
    X(TY.complex32,TY.complex80,  TY.complex80,TY.complex80, TY.complex80);

    /* ======================= */

    X(TY.complex64,TY.complex64,  TY.complex64,TY.complex64, TY.complex64);
    X(TY.complex64,TY.complex80,  TY.complex80,TY.complex80, TY.complex80);

    /* ======================= */

    X(TY.complex80,TY.complex80,  TY.complex80,TY.complex80, TY.complex80);

    foreach (i; 0 .. cast(size_t)TY.MAX)
    {
        foreach (j; 0 .. cast(size_t)TY.MAX)
        {
            if (impCnvTab.impcnvResultTab[i][j] == TY.error)
            {
                impCnvTab.impcnvResultTab[i][j] = impCnvTab.impcnvResultTab[j][i];
                impCnvTab.impcnvType1Tab[i][j] = impCnvTab.impcnvType2Tab[j][i];
                impCnvTab.impcnvType2Tab[i][j] = impCnvTab.impcnvType1Tab[j][i];
            }
        }
    }

    return impCnvTab;
}
