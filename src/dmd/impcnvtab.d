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

immutable Type.Kind[Type.Kind.max_][Type.Kind.max_] impcnvResult = impCnvTab.impcnvResultTab;
immutable Type.Kind[Type.Kind.max_][Type.Kind.max_] impcnvType1 = impCnvTab.impcnvType1Tab;
immutable Type.Kind[Type.Kind.max_][Type.Kind.max_] impcnvType2 = impCnvTab.impcnvType2Tab;

private:

struct ImpCnvTab
{
    Type.Kind[Type.Kind.max_][Type.Kind.max_] impcnvResultTab;
    Type.Kind[Type.Kind.max_][Type.Kind.max_] impcnvType1Tab;
    Type.Kind[Type.Kind.max_][Type.Kind.max_] impcnvType2Tab;
}

enum ImpCnvTab impCnvTab = generateImpCnvTab();

ImpCnvTab generateImpCnvTab()
{
    ImpCnvTab impCnvTab;

    // Set conversion tables
    foreach (i; 0 .. cast(size_t)Type.Kind.max_)
    {
        foreach (j; 0 .. cast(size_t)Type.Kind.max_)
        {
            impCnvTab.impcnvResultTab[i][j] = Type.Kind.error;
            impCnvTab.impcnvType1Tab[i][j] = Type.Kind.error;
            impCnvTab.impcnvType2Tab[i][j] = Type.Kind.error;
        }
    }

    void X(Type.Kind t1, Type.Kind t2, Type.Kind nt1, Type.Kind nt2, Type.Kind rt)
    {
        impCnvTab.impcnvResultTab[t1][t2] = rt;
        impCnvTab.impcnvType1Tab[t1][t2] = nt1;
        impCnvTab.impcnvType2Tab[t1][t2] = nt2;
    }

    /* ======================= */

    X(Type.Kind.bool_,Type.Kind.bool_,   Type.Kind.bool_,Type.Kind.bool_,    Type.Kind.bool_);
    X(Type.Kind.bool_,Type.Kind.int8,   Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.bool_,Type.Kind.uint8,   Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.bool_,Type.Kind.int16,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.bool_,Type.Kind.uint16,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.bool_,Type.Kind.int32,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.bool_,Type.Kind.uint32,  Type.Kind.uint32,Type.Kind.uint32,  Type.Kind.uint32);
    X(Type.Kind.bool_,Type.Kind.int64,  Type.Kind.int64,Type.Kind.int64,  Type.Kind.int64);
    X(Type.Kind.bool_,Type.Kind.uint64,  Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64);
    X(Type.Kind.bool_,Type.Kind.int128, Type.Kind.int128,Type.Kind.int128, Type.Kind.int128);
    X(Type.Kind.bool_,Type.Kind.uint128, Type.Kind.uint128,Type.Kind.uint128, Type.Kind.uint128);

    X(Type.Kind.bool_,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.bool_,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.bool_,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.bool_,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.bool_,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.bool_,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.bool_,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.bool_,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.bool_,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.int8,Type.Kind.int8,   Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.int8,Type.Kind.uint8,   Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.int8,Type.Kind.int16,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.int8,Type.Kind.uint16,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.int8,Type.Kind.int32,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.int8,Type.Kind.uint32,  Type.Kind.uint32,Type.Kind.uint32,  Type.Kind.uint32);
    X(Type.Kind.int8,Type.Kind.int64,  Type.Kind.int64,Type.Kind.int64,  Type.Kind.int64);
    X(Type.Kind.int8,Type.Kind.uint64,  Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64);
    X(Type.Kind.int8,Type.Kind.int128, Type.Kind.int128,Type.Kind.int128, Type.Kind.int128);
    X(Type.Kind.int8,Type.Kind.uint128, Type.Kind.uint128,Type.Kind.uint128, Type.Kind.uint128);

    X(Type.Kind.int8,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.int8,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.int8,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.int8,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.int8,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.int8,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.int8,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.int8,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.int8,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.uint8,Type.Kind.uint8,   Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.uint8,Type.Kind.int16,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.uint8,Type.Kind.uint16,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.uint8,Type.Kind.int32,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.uint8,Type.Kind.uint32,  Type.Kind.uint32,Type.Kind.uint32,  Type.Kind.uint32);
    X(Type.Kind.uint8,Type.Kind.int64,  Type.Kind.int64,Type.Kind.int64,  Type.Kind.int64);
    X(Type.Kind.uint8,Type.Kind.uint64,  Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64);
    X(Type.Kind.uint8,Type.Kind.int128,  Type.Kind.int128,Type.Kind.int128,  Type.Kind.int128);
    X(Type.Kind.uint8,Type.Kind.uint128,  Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128);

    X(Type.Kind.uint8,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.uint8,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.uint8,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.uint8,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.uint8,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.uint8,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.uint8,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.uint8,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.uint8,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.int16,Type.Kind.int16,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.int16,Type.Kind.uint16,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.int16,Type.Kind.int32,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.int16,Type.Kind.uint32,  Type.Kind.uint32,Type.Kind.uint32,  Type.Kind.uint32);
    X(Type.Kind.int16,Type.Kind.int64,  Type.Kind.int64,Type.Kind.int64,  Type.Kind.int64);
    X(Type.Kind.int16,Type.Kind.uint64,  Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64);
    X(Type.Kind.int16,Type.Kind.int128,  Type.Kind.int128,Type.Kind.int128,  Type.Kind.int128);
    X(Type.Kind.int16,Type.Kind.uint128,  Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128);

    X(Type.Kind.int16,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.int16,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.int16,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.int16,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.int16,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.int16,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.int16,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.int16,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.int16,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.uint16,Type.Kind.uint16,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.uint16,Type.Kind.int32,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.uint16,Type.Kind.uint32,  Type.Kind.uint32,Type.Kind.uint32,  Type.Kind.uint32);
    X(Type.Kind.uint16,Type.Kind.int64,  Type.Kind.int64,Type.Kind.int64,  Type.Kind.int64);
    X(Type.Kind.uint16,Type.Kind.uint64,  Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64);
    X(Type.Kind.uint16,Type.Kind.int128, Type.Kind.int128,Type.Kind.int128,  Type.Kind.int128);
    X(Type.Kind.uint16,Type.Kind.uint128, Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128);

    X(Type.Kind.uint16,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.uint16,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.uint16,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.uint16,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.uint16,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.uint16,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.uint16,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.uint16,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.uint16,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32,Type.Kind.int32,  Type.Kind.int32);
    X(Type.Kind.int32,Type.Kind.uint32,  Type.Kind.uint32,Type.Kind.uint32,  Type.Kind.uint32);
    X(Type.Kind.int32,Type.Kind.int64,  Type.Kind.int64,Type.Kind.int64,  Type.Kind.int64);
    X(Type.Kind.int32,Type.Kind.uint64,  Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64);
    X(Type.Kind.int32,Type.Kind.int128, Type.Kind.int128,Type.Kind.int128,  Type.Kind.int128);
    X(Type.Kind.int32,Type.Kind.uint128, Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128);

    X(Type.Kind.int32,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.int32,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.int32,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.int32,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.int32,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.int32,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.int32,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.int32,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.int32,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.uint32,Type.Kind.uint32,  Type.Kind.uint32,Type.Kind.uint32,  Type.Kind.uint32);
    X(Type.Kind.uint32,Type.Kind.int64,  Type.Kind.int64,Type.Kind.int64,  Type.Kind.int64);
    X(Type.Kind.uint32,Type.Kind.uint64,  Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64);
    X(Type.Kind.uint32,Type.Kind.int128,  Type.Kind.int128,Type.Kind.int128,  Type.Kind.int128);
    X(Type.Kind.uint32,Type.Kind.uint128,  Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128);

    X(Type.Kind.uint32,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.uint32,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.uint32,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.uint32,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.uint32,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.uint32,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.uint32,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.uint32,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.uint32,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.int64,Type.Kind.int64,  Type.Kind.int64,Type.Kind.int64,  Type.Kind.int64);
    X(Type.Kind.int64,Type.Kind.uint64,  Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64);
    X(Type.Kind.int64,Type.Kind.int128,  Type.Kind.int128,Type.Kind.int128,  Type.Kind.int128);
    X(Type.Kind.int64,Type.Kind.uint128,  Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128);

    X(Type.Kind.int64,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.int64,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.int64,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.int64,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.int64,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.int64,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.int64,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.int64,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.int64,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64,Type.Kind.uint64,  Type.Kind.uint64);
    X(Type.Kind.uint64,Type.Kind.int128,  Type.Kind.int128,Type.Kind.int128,  Type.Kind.int128);
    X(Type.Kind.uint64,Type.Kind.uint128,  Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128);

    X(Type.Kind.uint64,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.uint64,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.uint64,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.uint64,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.uint64,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.uint64,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.uint64,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.uint64,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.uint64,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.int128,Type.Kind.int128,  Type.Kind.int128,Type.Kind.int128,  Type.Kind.int128);
    X(Type.Kind.int128,Type.Kind.uint128,  Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128);

    X(Type.Kind.int128,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.int128,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.int128,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.int128,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.int128,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.int128,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.int128,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.int128,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.int128,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128,Type.Kind.uint128,  Type.Kind.uint128);

    X(Type.Kind.uint128,Type.Kind.float32,     Type.Kind.float32,Type.Kind.float32,     Type.Kind.float32);
    X(Type.Kind.uint128,Type.Kind.float64,     Type.Kind.float64,Type.Kind.float64,     Type.Kind.float64);
    X(Type.Kind.uint128,Type.Kind.float80,     Type.Kind.float80,Type.Kind.float80,     Type.Kind.float80);
    X(Type.Kind.uint128,Type.Kind.imaginary32, Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.uint128,Type.Kind.imaginary64, Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.uint128,Type.Kind.imaginary80, Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.uint128,Type.Kind.complex32,   Type.Kind.float32,Type.Kind.complex32,   Type.Kind.complex32);
    X(Type.Kind.uint128,Type.Kind.complex64,   Type.Kind.float64,Type.Kind.complex64,   Type.Kind.complex64);
    X(Type.Kind.uint128,Type.Kind.complex80,   Type.Kind.float80,Type.Kind.complex80,   Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.float32,Type.Kind.float32,  Type.Kind.float32,Type.Kind.float32, Type.Kind.float32);
    X(Type.Kind.float32,Type.Kind.float64,  Type.Kind.float64,Type.Kind.float64, Type.Kind.float64);
    X(Type.Kind.float32,Type.Kind.float80,  Type.Kind.float80,Type.Kind.float80, Type.Kind.float80);

    X(Type.Kind.float32,Type.Kind.imaginary32,  Type.Kind.float32,Type.Kind.imaginary32, Type.Kind.float32);
    X(Type.Kind.float32,Type.Kind.imaginary64,  Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.float32,Type.Kind.imaginary80,  Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);

    X(Type.Kind.float32,Type.Kind.complex32,  Type.Kind.float32,Type.Kind.complex32, Type.Kind.complex32);
    X(Type.Kind.float32,Type.Kind.complex64,  Type.Kind.float64,Type.Kind.complex64, Type.Kind.complex64);
    X(Type.Kind.float32,Type.Kind.complex80,  Type.Kind.float80,Type.Kind.complex80, Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.float64,Type.Kind.float64,  Type.Kind.float64,Type.Kind.float64, Type.Kind.float64);
    X(Type.Kind.float64,Type.Kind.float80,  Type.Kind.float80,Type.Kind.float80, Type.Kind.float80);

    X(Type.Kind.float64,Type.Kind.imaginary32,  Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.float64,Type.Kind.imaginary64,  Type.Kind.float64,Type.Kind.imaginary64, Type.Kind.float64);
    X(Type.Kind.float64,Type.Kind.imaginary80,  Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);

    X(Type.Kind.float64,Type.Kind.complex32,  Type.Kind.float64,Type.Kind.complex64, Type.Kind.complex64);
    X(Type.Kind.float64,Type.Kind.complex64,  Type.Kind.float64,Type.Kind.complex64, Type.Kind.complex64);
    X(Type.Kind.float64,Type.Kind.complex80,  Type.Kind.float80,Type.Kind.complex80, Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.float80,Type.Kind.float80,  Type.Kind.float80,Type.Kind.float80, Type.Kind.float80);

    X(Type.Kind.float80,Type.Kind.imaginary32,  Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.float80,Type.Kind.imaginary64,  Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);
    X(Type.Kind.float80,Type.Kind.imaginary80,  Type.Kind.float80,Type.Kind.imaginary80, Type.Kind.float80);

    X(Type.Kind.float80,Type.Kind.complex32,  Type.Kind.float80,Type.Kind.complex80, Type.Kind.complex80);
    X(Type.Kind.float80,Type.Kind.complex64,  Type.Kind.float80,Type.Kind.complex80, Type.Kind.complex80);
    X(Type.Kind.float80,Type.Kind.complex80,  Type.Kind.float80,Type.Kind.complex80, Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.imaginary32,Type.Kind.imaginary32,  Type.Kind.imaginary32,Type.Kind.imaginary32, Type.Kind.imaginary32);
    X(Type.Kind.imaginary32,Type.Kind.imaginary64,  Type.Kind.imaginary64,Type.Kind.imaginary64, Type.Kind.imaginary64);
    X(Type.Kind.imaginary32,Type.Kind.imaginary80,  Type.Kind.imaginary80,Type.Kind.imaginary80, Type.Kind.imaginary80);

    X(Type.Kind.imaginary32,Type.Kind.complex32,  Type.Kind.imaginary32,Type.Kind.complex32, Type.Kind.complex32);
    X(Type.Kind.imaginary32,Type.Kind.complex64,  Type.Kind.imaginary64,Type.Kind.complex64, Type.Kind.complex64);
    X(Type.Kind.imaginary32,Type.Kind.complex80,  Type.Kind.imaginary80,Type.Kind.complex80, Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.imaginary64,Type.Kind.imaginary64,  Type.Kind.imaginary64,Type.Kind.imaginary64, Type.Kind.imaginary64);
    X(Type.Kind.imaginary64,Type.Kind.imaginary80,  Type.Kind.imaginary80,Type.Kind.imaginary80, Type.Kind.imaginary80);

    X(Type.Kind.imaginary64,Type.Kind.complex32,  Type.Kind.imaginary64,Type.Kind.complex64, Type.Kind.complex64);
    X(Type.Kind.imaginary64,Type.Kind.complex64,  Type.Kind.imaginary64,Type.Kind.complex64, Type.Kind.complex64);
    X(Type.Kind.imaginary64,Type.Kind.complex80,  Type.Kind.imaginary80,Type.Kind.complex80, Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.imaginary80,Type.Kind.imaginary80,  Type.Kind.imaginary80,Type.Kind.imaginary80, Type.Kind.imaginary80);

    X(Type.Kind.imaginary80,Type.Kind.complex32,  Type.Kind.imaginary80,Type.Kind.complex80, Type.Kind.complex80);
    X(Type.Kind.imaginary80,Type.Kind.complex64,  Type.Kind.imaginary80,Type.Kind.complex80, Type.Kind.complex80);
    X(Type.Kind.imaginary80,Type.Kind.complex80,  Type.Kind.imaginary80,Type.Kind.complex80, Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.complex32,Type.Kind.complex32,  Type.Kind.complex32,Type.Kind.complex32, Type.Kind.complex32);
    X(Type.Kind.complex32,Type.Kind.complex64,  Type.Kind.complex64,Type.Kind.complex64, Type.Kind.complex64);
    X(Type.Kind.complex32,Type.Kind.complex80,  Type.Kind.complex80,Type.Kind.complex80, Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.complex64,Type.Kind.complex64,  Type.Kind.complex64,Type.Kind.complex64, Type.Kind.complex64);
    X(Type.Kind.complex64,Type.Kind.complex80,  Type.Kind.complex80,Type.Kind.complex80, Type.Kind.complex80);

    /* ======================= */

    X(Type.Kind.complex80,Type.Kind.complex80,  Type.Kind.complex80,Type.Kind.complex80, Type.Kind.complex80);

    foreach (i; 0 .. cast(size_t)Type.Kind.max_)
    {
        foreach (j; 0 .. cast(size_t)Type.Kind.max_)
        {
            if (impCnvTab.impcnvResultTab[i][j] == Type.Kind.error)
            {
                impCnvTab.impcnvResultTab[i][j] = impCnvTab.impcnvResultTab[j][i];
                impCnvTab.impcnvType1Tab[i][j] = impCnvTab.impcnvType2Tab[j][i];
                impCnvTab.impcnvType2Tab[i][j] = impCnvTab.impcnvType1Tab[j][i];
            }
        }
    }

    return impCnvTab;
}
