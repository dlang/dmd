/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) ?-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/xmm.d, backend/_xmm.d)
 */

module dmd.backend.xmm;

// Online documentation: https://dlang.org/phobos/dmd_backend_xmm.html

@safe:

// XMM opcodes

enum
{
    ADDSS = 0xF30F58,           // ADDSS xmm1, xmm2/mem32 F3 0F 58 /r
    ADDSD = 0xF20F58,           // ADDSD xmm1, xmm2/mem64 F2 0F 58 /r
    ADDPS = 0x000F58,           // ADDPS xmm1, xmm2/mem128 0F 58 /r
    ADDPD = 0x660F58,           // ADDPD xmm1, xmm2/mem128 66 0F 58 /r
    PADDB = 0x660FFC,           // PADDB xmm1, xmm2/mem128 66 0F FC /r
    PADDW = 0x660FFD,           // PADDW xmm1, xmm2/mem128 66 0F FD /r
    PADDD = 0x660FFE,           // PADDD xmm1, xmm2/mem128 66 0F FE /r
    PADDQ = 0x660FD4,           // PADDQ xmm1, xmm2/mem128 66 0F D4 /r

    SUBSS = 0xF30F5C,           // SUBSS xmm1, xmm2/mem32 F3 0F 5C /r
    SUBSD = 0xF20F5C,           // SUBSD xmm1, xmm2/mem64 F2 0F 5C /r
    SUBPS = 0x000F5C,           // SUBPS xmm1, xmm2/mem128 0F 5C /r
    SUBPD = 0x660F5C,           // SUBPD xmm1, xmm2/mem128 66 0F 5C /r
    PSUBB = 0x660FF8,           // PSUBB xmm1, xmm2/mem128 66 0F F8 /r
    PSUBW = 0x660FF9,           // PSUBW xmm1, xmm2/mem128 66 0F F9 /r
    PSUBD = 0x660FFA,           // PSUBD xmm1, xmm2/mem128 66 0F FA /r
    PSUBQ = 0x660FFB,           // PSUBQ xmm1, xmm2/mem128 66 0F FB /r

    MULSS = 0xF30F59,           // MULSS  xmm1, xmm2/mem32 F3 0F 59 /r
    MULSD = 0xF20F59,           // MULSD  xmm1, xmm2/mem64 F2 0F 59 /r
    MULPS = 0x000F59,           // MULPS  xmm1, xmm2/mem128 0F 59 /r
    MULPD = 0x660F59,           // MULPD  xmm1, xmm2/mem128 66 0F 59 /r
    PMULLW = 0x660FD5,          // PMULLW xmm1, xmm2/mem128 66 0F D5 /r

    DIVSS = 0xF30F5E,           // DIVSS xmm1, xmm2/mem32 F3 0F 5E /r
    DIVSD = 0xF20F5E,           // DIVSD xmm1, xmm2/mem64 F2 0F 5E /r
    DIVPS = 0x000F5E,           // DIVPS xmm1, xmm2mem/128 0F 5E /r
    DIVPD = 0x660F5E,           // DIVPD xmm1, xmm2/mem128 66 0F 5E /r

    PAND  = 0x660FDB,           // PAND xmm1, xmm2/mem128 66 0F DB /r
    POR   = 0x660FEB,           // POR  xmm1, xmm2/mem128 66 0F EB /r

    UCOMISS = 0x000F2E,         // UCOMISS xmm1, xmm2/mem32 0F 2E /r
    UCOMISD = 0x660F2E,         // UCOMISD xmm1, xmm2/mem64 66 0F 2E /r

    XORPS = 0x000F57,           // XORPS xmm1, xmm2/mem128 0F 57 /r
    XORPD = 0x660F57,           // XORPD xmm1, xmm2/mem128 66 0F 57 /r

    // Use STO and LOD instead of MOV to distinguish the direction
    STOSS  = 0xF30F11,          // MOVSS  xmm1/mem32, xmm2 F3 0F 11 /r
    STOSD  = 0xF20F11,          // MOVSD  xmm1/mem64, xmm2 F2 0F 11 /r
    STOAPS = 0x000F29,          // MOVAPS xmm1/mem128, xmm2 0F 29 /r
    STOAPD = 0x660F29,          // MOVAPD xmm1/mem128, xmm2   66 0F 29 /r
    STODQA = 0x660F7F,          // MOVDQA xmm1/mem128, xmm2 66 0F 7F /r
    STOD   = 0x660F7E,          // MOVD   reg/mem64, xmm   66 0F 7E /r
    STOQ   = 0x660FD6,          // MOVQ   xmm1/mem64, xmm2 66 0F D6 /

    LODSS  = 0xF30F10,          // MOVSS  xmm1, xmm2/mem32 F3 0F 10 /r
    LODSD  = 0xF20F10,          // MOVSD  xmm1, xmm2/mem64 F2 0F 10 /r
    LODAPS = 0x000F28,          // MOVAPS xmm1, xmm2/mem128 0F 28 /r
    LODAPD = 0x660F28,          // MOVAPD xmm1, xmm2/mem128   66 0F 28 /r
    LODDQA = 0x660F6F,          // MOVDQA xmm1, xmm2/mem128 66 0F 6F /r
    LODD   = 0x660F6E,          // MOVD   xmm, reg/mem64   66 0F 6E /r
    LODQ   = 0xF30F7E,          // MOVQ   xmm1, xmm2/mem64 F3 0F 7E /r

    LODDQU   = 0xF30F6F,        // MOVDQU xmm1, xmm2/mem128  F3 0F 6F /r
    STODQU   = 0xF30F7F,        // MOVDQU xmm1/mem128, xmm2  F3 0F 7F /r
    MOVDQ2Q  = 0xF20FD6,        // MOVDQ2Q mmx, xmm          F2 0F D6 /r
    LODHPD   = 0x660F16,        // MOVHPD xmm, mem64         66 0F 16 /r
    STOHPD   = 0x660F17,        // MOVHPD mem64, xmm         66 0F 17 /r
    LODHPS   = 0x0F16,          // MOVHPS xmm, mem64         0F 16 /r
    STOHPS   = 0x0F17,          // MOVHPS mem64, xmm         0F 17 /r
    MOVLHPS  = 0x0F16,          // MOVLHPS xmm1, xmm2        0F 16 /r
    LODLPD   = 0x660F12,        // MOVLPD xmm, mem64         66 0F 12 /r
    STOLPD   = 0x660F13,        // MOVLPD mem64, xmm         66 0F 13 /r
    MOVHLPS  = 0x0F12,          // MOVHLPS xmm1, xmm2        0F 12 /r
    LODLPS   = 0x0F12,          // MOVLPS xmm, mem64         0F 12 /r
    STOLPS   = 0x0F13,          // MOVLPS mem64, xmm         0F 13 /r
    MOVMSKPD = 0x660F50,        // MOVMSKPD reg32, xmm 66 0F 50 /r
    MOVMSKPS = 0x0F50,          // MOVMSKPS reg32, xmm 0F 50 /r
    MOVNTDQ  = 0x660FE7,        // MOVNTDQ mem128, xmm 66 0F E7 /r
    MOVNTI   = 0x0FC3,          // MOVNTI m32,r32 0F C3 /r
                                // MOVNTI m64,r64 0F C3 /r
    MOVNTPD  = 0x660F2B,        // MOVNTPD mem128, xmm 66 0F 2B /r
    MOVNTPS  = 0x0F2B,          // MOVNTPS mem128, xmm 0F 2B /r
    MOVNTQ   = 0x0FE7,          // MOVNTQ m64, mmx 0F E7 /r
    MOVQ2DQ  = 0xF30FD6,        // MOVQ2DQ xmm, mmx F3 0F D6 /r
    LODUPD   = 0x660F10,        // MOVUPD xmm1, xmm2/mem128 66 0F 10 /r
    STOUPD   = 0x660F11,        // MOVUPD xmm1/mem128, xmm2 66 0F 11 /r
    LODUPS   = 0x0F10,          // MOVUPS xmm1, xmm2/mem128 0F 10 /r
    STOUPS   = 0x0F11,          // MOVUPS xmm1/mem128, xmm2 0F 11 /r

    PACKSSDW = 0x660F6B,        // PACKSSDW xmm1, xmm2/mem128 66 0F 6B /r
    PACKSSWB = 0x660F63,        // PACKSSWB xmm1, xmm2/mem128 66 0F 63 /r
    PACKUSWB = 0x660F67,        // PACKUSWB xmm1, xmm2/mem128 66 0F 67 /r
    PADDSB = 0x660FEC,          // PADDSB xmm1, xmm2/mem128 66 0F EC /r
    PADDSW = 0x660FED,          // PADDSW xmm1, xmm2/mem128 66 0F ED /r
    PADDUSB = 0x660FDC,         // PADDUSB xmm1, xmm2/mem128 66 0F DC /r
    PADDUSW = 0x660FDD,         // PADDUSW xmm1, xmm2/mem128 66 0F DD /r
    PANDN = 0x660FDF,           // PANDN xmm1, xmm2/mem128 66 0F DF /r
    PCMPEQB = 0x660F74,         // PCMPEQB xmm1, xmm2/mem128 66 0F 74 /r
    PCMPEQD = 0x660F76,         // PCMPEQD xmm1, xmm2/mem128 66 0F 76 /r
    PCMPEQW = 0x660F75,         // PCMPEQW xmm1, xmm2/mem128 66 0F 75 /r
    PCMPGTB = 0x660F64,         // PCMPGTB xmm1, xmm2/mem128 66 0F 64 /r
    PCMPGTD = 0x660F66,         // PCMPGTD xmm1, xmm2/mem128 66 0F 66 /r
    PCMPGTW = 0x660F65,         // PCMPGTW xmm1, xmm2/mem128 66 0F 65 /r
    PMADDWD = 0x660FF5,         // PMADDWD xmm1, xmm2/mem128 66 0F F5 /r
    PSLLW = 0x660FF1,           // PSLLW xmm1, xmm2/mem128    66 0F F1 /r
                                // PSLLW xmm, imm8            66 0F 71 /6 ib
    PSLLD = 0x660FF2,           // PSLLD xmm1, xmm2/mem128    66 0F F2 /r
                                // PSLLD xmm, imm8            66 0F 72 /6 ib
    PSLLQ = 0x660FF3,           // PSLLQ xmm1, xmm2/mem128    66 0F F3 /r
                                // PSLLQ xmm, imm8            66 0F 73 /6 ib
    PSRAW = 0x660FE1,           // PSRAW xmm1, xmm2/mem128    66 0F E1 /r
                                // PSRAW xmm, imm8            66 0F 71 /4 ib
    PSRAD = 0x660FE2,           // PSRAD xmm1, xmm2/mem128    66 0F E2 /r
                                // PSRAD xmm, imm8            66 0F 72 /4 ib
    PSRLW = 0x660FD1,           // PSRLW xmm1, xmm2/mem128    66 0F D1 /r
                                // PSRLW xmm, imm8            66 0F 71 /2 ib
    PSRLD = 0x660FD2,           // PSRLD xmm1, xmm2/mem128    66 0F D2 /r
                                // PSRLD xmm, imm8            66 0F 72 /2 ib
    PSRLQ = 0x660FD3,           // PSRLQ xmm1, xmm2/mem128    66 0F D3 /r
                                // PSRLQ xmm, imm8            66 0F 73 /2 ib
    PSUBSB = 0x660FE8,          // PSUBSB xmm1, xmm2/mem128 66 0F E8 /r
    PSUBSW = 0x660FE9,          // PSUBSW xmm1, xmm2/mem128 66 0F E9 /r
    PSUBUSB = 0x660FD8,         // PSUBUSB xmm1, xmm2/mem128 66 0F D8 /r
    PSUBUSW = 0x660FD9,         // PSUBUSW xmm1, xmm2/mem128 66 0F D9 /r
    PUNPCKHBW = 0x660F68,       // PUNPCKHBW xmm1, xmm2/mem128 66 0F 68 /r
    PUNPCKHDQ = 0x660F6A,       // PUNPCKHDQ xmm1, xmm2/mem128 66 0F 6A /r
    PUNPCKHWD = 0x660F69,       // PUNPCKHWD xmm1, xmm2/mem128 66 0F 69 /r
    PUNPCKLBW = 0x660F60,       // PUNPCKLBW xmm1, xmm2/mem128 66 0F 60 /r
    PUNPCKLDQ = 0x660F62,       // PUNPCKLDQ xmm1, xmm2/mem128 66 0F 62 /r
    PUNPCKLWD = 0x660F61,       // PUNPCKLWD xmm1, xmm2/mem128 66 0F 61 /r
    PXOR = 0x660FEF,            // PXOR xmm1, xmm2/mem128 66 0F EF /r
    ANDPD = 0x660F54,           // ANDPD xmm1, xmm2/mem128 66 0F 54 /r
    ANDPS = 0x0F54,             // ANDPS xmm1, xmm2/mem128 0F 54 /r
    ANDNPD = 0x660F55,          // ANDNPD xmm1, xmm2/mem128 66 0F 55 /r
    ANDNPS = 0x0F55,            // ANDNPS xmm1, xmm2/mem128 0F 55 /r
    CMPPS = 0x0FC2,             // CMPPS xmm1, xmm2/mem128, imm8 0F C2 /r ib
    CMPPD = 0x660FC2,           // CMPPD xmm1, xmm2/mem128, imm8 66 0F C2 /r ib
    CMPSD = 0xF20FC2,           // CMPSD xmm1, xmm2/mem64, imm8 F2 0F C2 /r ib
    CMPSS = 0xF30FC2,           // CMPSS xmm1, xmm2/mem32, imm8 F3 0F C2 /r ib
    COMISD = 0x660F2F,          // COMISD xmm1, xmm2/mem64 66 0F 2F /r
    COMISS = 0x0F2F,            // COMISS xmm1, xmm2/mem32 0F 2F /r
    CVTDQ2PD = 0xF30FE6,        // CVTDQ2PD   xmm1, xmm2/mem64  F3 0F E6 /r
    CVTDQ2PS = 0x0F5B,          // CVTDQ2PS   xmm1, xmm2/mem128 0F 5B /r
    CVTPD2DQ = 0xF20FE6,        // CVTPD2DQ   xmm1, xmm2/mem128 F2 0F E6 /r
    CVTPD2PI = 0x660F2D,        // CVTPD2PI   mmx, xmm2/mem128  66 0F 2D /r
    CVTPD2PS = 0x660F5A,        // CVTPD2PS   xmm1, xmm2/mem128 66 0F 5A /r
    CVTPI2PD = 0x660F2A,        // CVTPI2PD   xmm, mmx/mem64    66 0F 2A /r
    CVTPI2PS = 0x0F2A,          // CVTPI2PS   xmm, mmx/mem64    0F 2A /r
    CVTPS2DQ = 0x660F5B,        // CVTPS2DQ   xmm1, xmm2/mem128 66 0F 5B /r
    CVTPS2PD = 0x0F5A,          // CVTPS2PD   xmm1, xmm2/mem64  0F 5A /r
    CVTPS2PI = 0x0F2D,          // CVTPS2PI   mmx, xmm/mem64    0F 2D /r
    CVTSD2SI = 0xF20F2D,        // CVTSD2SI   reg32, xmm/mem64  F2 0F 2D /r
                                // CVTSD2SI   reg64, xmm/mem64  F2 0F 2D /r
    CVTSD2SS = 0xF20F5A,        // CVTSD2SS   xmm1, xmm2/mem64  F2 0F 5A /r
    CVTSI2SD = 0xF20F2A,        // CVTSI2SD   xmm, reg/mem32    F2 0F 2A /r
                                // CVTSI2SD   xmm, reg/mem64    F2 0F 2A /r
    CVTSI2SS = 0xF30F2A,        // CVTSI2SS   xmm, reg/mem32    F3 0F 2A /r
                                // CVTSI2SS   xmm, reg/mem64    F3 0F 2A /r
    CVTSS2SD = 0xF30F5A,        // CVTSS2SD   xmm1, xmm2/mem32  F3 0F 5A /r
    CVTSS2SI = 0xF30F2D,        // CVTSS2SI   reg32, xmm2/mem32 F3 0F 2D /r
                                // CVTSS2SI   reg64, xmm2/mem32 F3 0F 2D /r
    CVTTPD2PI = 0x660F2C,       // CVTPD2PI   mmx, xmm/mem128   66 0F 2C /r
    CVTTPD2DQ = 0x660FE6,       // CVTTPD2DQ  xmm1, xmm2/mem128 66 0F E6 /r
    CVTTPS2DQ = 0xF30F5B,       // CVTTPS2DQ  xmm1, xmm2/mem128 F3 0F 5B /r
    CVTTPS2PI = 0x0F2C,         // CVTTPS2PI  mmx xmm/mem64     0F 2C /r
    CVTTSD2SI = 0xF20F2C,       // CVTTSD2SI  reg32, xmm/mem64  F2 0F 2C /r
                                // CVTTSD2SI  reg64, xmm/mem64  F2 0F 2C /r
    CVTTSS2SI = 0xF30F2C,       // CVTTSS2SI  reg32, xmm/mem32  F3 0F 2C /r
                                // CVTTSS2SI  reg64, xmm/mem32  F3 0F 2C /r
    MASKMOVDQU = 0x660FF7,      // MASKMOVDQU xmm1, xmm2        66 0F F7 /r
    MASKMOVQ = 0x0FF7,          // MASKMOVQ   mm1,mm2           0F F7 /r
    MAXPD = 0x660F5F,           // MAXPD      xmm1, xmm2/mem128 66 0F 5F /r
    MAXPS = 0x0F5F,             // MAXPS      xmm1, xmm2/mem128 0F 5F /r
    MAXSD = 0xF20F5F,           // MAXSD      xmm1, xmm2/mem64  F2 0F 5F /r
    MAXSS = 0xF30F5F,           // MAXSS xmm1, xmm2/mem32 F3 0F 5F /r
    MINPD = 0x660F5D,           // MINPD xmm1, xmm2/mem128 66 0F 5D /r
    MINPS = 0x0F5D,             // MINPS xmm1, xmm2/mem128 0F 5D /r
    MINSD = 0xF20F5D,           // MINSD xmm1, xmm2/mem64 F2 0F 5D /r
    MINSS = 0xF30F5D,           // MINSS xmm1, xmm2/mem32   F3 0F 5D /r
    ORPD = 0x660F56,            // ORPD xmm1, xmm2/mem128 66 0F 56 /r
    ORPS = 0x0F56,              // ORPS xmm1, xmm2/mem128 0F 56 /r
    PAVGB = 0x660FE0,           // PAVGB xmm1, xmm2/mem128 66 0F E0 /r
    PAVGW = 0x660FE3,           // PAVGW xmm1, xmm2/mem128 66 0F E3 /r
    PMAXSW = 0x660FEE,          // PMAXSW xmm1, xmm2/mem128 66 0F EE /
    PINSRW = 0x660FC4,          // PINSRW xmm, reg32/mem16, imm8   66 0F C4 /r ib
    PMAXUB = 0x660FDE,          // PMAXUB xmm1, xmm2/mem128 66 0F DE /r
    PMINSW = 0x660FEA,          // PMINSW xmm1, xmm2/mem128 66 0F EA /r
    PMINUB = 0x660FDA,          // PMINUB xmm1, xmm2/mem128 66 0F DA /r
    PMOVMSKB = 0x660FD7,        // PMOVMSKB reg32, xmm   66 0F D7 /r
    PMULHUW = 0x660FE4,         // PMULHUW xmm1, xmm2/mem128 66 0F E4 /r
    PMULHW = 0x660FE5,          // PMULHW xmm1, xmm2/mem128 66 0F E5 /
    PMULUDQ = 0x660FF4,         // PMULUDQ xmm1, xmm2/mem128 66 0F F4 /r
    PSADBW = 0x660FF6,          // PSADBW xmm1, xmm2/mem128 66 0F F6 /r
    PUNPCKHQDQ = 0x660F6D,      // PUNPCKHQDQ xmm1, xmm2/mem128 66 0F 6D /r
    PUNPCKLQDQ = 0x660F6C,      // PUNPCKLQDQ xmm1, xmm2/mem128 66 0F 6C /r
    RCPPS = 0x0F53,             // RCPPS xmm1, xmm2/mem128 0F 53 /r
    RCPSS = 0xF30F53,           // RCPSS xmm1, xmm2/mem32 F3 0F 53 /r
    RSQRTPS = 0x0F52,           // RSQRTPS xmm1, xmm2/mem128 0F 52 /r
    RSQRTSS = 0xF30F52,         // RSQRTSS xmm1, xmm2/mem32 F3 0F 52 /r
    SQRTPD = 0x660F51,          // SQRTPD xmm1, xmm2/mem128 66 0F 51 /r
    SHUFPD = 0x660FC6,          // SHUFPD xmm1, xmm2/mem128, imm8 66 0F C6 /r ib
    SHUFPS = 0x0FC6,            // SHUFPS xmm1, xmm2/mem128, imm8 0F C6 /r ib
    SQRTPS = 0x0F51,            // SQRTPS xmm1, xmm2/mem128 0F 51 /r
    SQRTSD = 0xF20F51,          // SQRTSD xmm1, xmm2/mem64 F2 0F 51 /r
    SQRTSS = 0xF30F51,          // SQRTSS xmm1, xmm2/mem32 F3 0F 51 /r
    UNPCKHPD = 0x660F15,        // UNPCKHPD xmm1, xmm2/mem12866 0F 15 /r
    UNPCKHPS = 0x0F15,          // UNPCKHPS xmm1, xmm2/mem1280F 15 /r
    UNPCKLPD = 0x660F14,        // UNPCKLPD xmm1, xmm2/mem128   66 0F 14 /r
    UNPCKLPS = 0x0F14,          // UNPCKLPS xmm1, xmm2/mem1280F 14 /r

    PSHUFD = 0x660F70,          // PSHUFD  xmm1, xmm2/mem128, imm8 66 0F 70 /r ib
    PSHUFHW = 0xF30F70,         // PSHUFHW xmm1, xmm2/mem128, imm8 F3 0F 70 /r ib
    PSHUFLW = 0xF20F70,         // PSHUFLW xmm1, xmm2/mem128, imm8  F2 0F 70 /r ib
    PSHUFW = 0x0F70,            // PSHUFW  mm1, mm2/mem64, imm8  0F 70 /r ib
    PSLLDQ = 0x07660F73,        // PSLLDQ  xmm, imm8   66 0F 73 /7 ib
    PSRLDQ = 0x03660F73,        // PSRLDQ  xmm, imm8   66 0F 73 /3 ib

    PREFETCH = 0x0F18,

    PEXTRW = 0x660FC5,          // PEXTRW  reg32, xmm, imm8 66 0F C5 /r ib
    STMXCSR = 0x0FAE,           // STMXCSR mem32 0F AE /3

// SSE3 Pentium 4 (Prescott)

    ADDSUBPD = 0x660FD0,        // ADDSUBPD xmm1, xmm2/m128
    ADDSUBPS = 0xF20FD0,
    HADDPD   = 0x660F7C,
    HADDPS   = 0xF20F7C,
    HSUBPD   = 0x660F7D,
    HSUBPS   = 0xF20F7D,
    MOVDDUP  = 0xF20F12,
    MOVSHDUP = 0xF30F16,
    MOVSLDUP = 0xF30F12,
    LDDQU    = 0xF20FF0,
    MONITOR  = 0x0F01C8,
    MWAIT    = 0x0F01C9,

// SSSE3
    PALIGNR = 0x660F3A0F,
    PHADDD = 0x660F3802,
    PHADDW = 0x660F3801,
    PHADDSW = 0x660F3803,
    PABSB = 0x660F381C,
    PABSD = 0x660F381E,
    PABSW = 0x660F381D,
    PSIGNB = 0x660F3808,
    PSIGND = 0x660F380A,
    PSIGNW = 0x660F3809,
    PSHUFB = 0x660F3800,
    PMADDUBSW = 0x660F3804,
    PMULHRSW = 0x660F380B,
    PHSUBD = 0x660F3806,
    PHSUBW = 0x660F3805,
    PHSUBSW = 0x660F3807,

// SSE4.1
// See Intel SSE4 Programming Reference

    BLENDPD   = 0x660F3A0D,     // 66 0F 3A 0D /r ib  BLENDPD  xmm1, xmm2/m128, imm8
    BLENDPS   = 0x660F3A0C,     // 66 0F 3A 0C /r ib  BLENDPS  xmm1, xmm2/m128, imm8
    BLENDVPD  = 0x660F3815,     // 66 0F 38 15 /r     BLENDVPD xmm1, xmm2/m128, <XMM0>
    BLENDVPS  = 0x660F3814,     // 66 0F 38 14 /r     BLENDVPS xmm1, xmm2/m128, <XMM0>
    DPPD      = 0x660F3A41,
    DPPS      = 0x660F3A40,
    EXTRACTPS = 0x660F3A17,
    INSERTPS  = 0x660F3A21,
    MPSADBW   = 0x660F3A42,
    PBLENDVB  = 0x660F3810,
    PBLENDW   = 0x660F3A0E,
    PEXTRD    = 0x660F3A16,
    PEXTRQ    = 0x660F3A16,
    PINSRB    = 0x660F3A20,     // 66 0F 3A 20 /r ib PINSRB xmm1, r32/m8, imm8
    PINSRD    = 0x660F3A22,
    PINSRQ    = 0x660F3A22,

    MOVNTDQA = 0x660F382A,
    PACKUSDW = 0x660F382B,
    PCMPEQQ = 0x660F3829,
    PEXTRB = 0x660F3A14,        // 66 0F 3A 14 /r ib       PEXTRB r32/m8, xmm2, imm8
                                // 66 REX.W 0F 3A 14 /r ib PEXTRB r64/m8, xmm2, imm8
    PHMINPOSUW = 0x660F3841,    // 66 0F 38 41 /r          PHMINPOSUW xmm1, xmm2/m128
    PMAXSB = 0x660F383C,
    PMAXSD = 0x660F383D,
    PMAXUD = 0x660F383F,
    PMAXUW = 0x660F383E,
    PMINSB = 0x660F3838,
    PMINSD = 0x660F3839,
    PMINUD = 0x660F383B,
    PMINUW = 0x660F383A,
    PMOVSXBW = 0x660F3820,
    PMOVSXBD = 0x660F3821,
    PMOVSXBQ = 0x660F3822,
    PMOVSXWD = 0x660F3823,
    PMOVSXWQ = 0x660F3824,
    PMOVSXDQ = 0x660F3825,
    PMOVZXBW = 0x660F3830,
    PMOVZXBD = 0x660F3831,
    PMOVZXBQ = 0x660F3832,
    PMOVZXWD = 0x660F3833,
    PMOVZXWQ = 0x660F3834,
    PMOVZXDQ = 0x660F3835,
    PMULDQ   = 0x660F3828,
    PMULLD   = 0x660F3840,
    PTEST    = 0x660F3817,      // 66 0F 38 17 /r PTEST xmm1, xmm2/m128

    ROUNDPD = 0x660F3A09,       // 66 0F 3A 09 /r ib ROUNDPD xmm1, xmm2/m128, imm8
    ROUNDPS = 0x660F3A08,
    ROUNDSD = 0x660F3A0B,
    ROUNDSS = 0x660F3A0A,

// SSE4.2
    PCMPESTRI  = 0x660F3A61,
    PCMPESTRM  = 0x660F3A60,
    PCMPISTRI  = 0x660F3A63,
    PCMPISTRM  = 0x660F3A62,
    PCMPGTQ    = 0x660F3837,
    // CRC32

// SSE4a (AMD only)
    // EXTRQ,INSERTQ,MOVNTSD,MOVNTSS

// POPCNT and LZCNT (have their own CPUID bits)
    POPCNT     = 0xF30FB8,
    // LZCNT

// AVX
    XGETBV = 0x0F01D0,
    XSETBV = 0x0F01D1,
    VBROADCASTSS   = 0x660F3818,
    VBROADCASTSD   = 0x660F3819,
    VBROADCASTF128 = 0x660F381A,
    VINSERTF128    = 0x660F3A18,

// AVX2
    VPBROADCASTB   = 0x660F3878,
    VPBROADCASTW   = 0x660F3879,
    VPBROADCASTD   = 0x660F3858,
    VPBROADCASTQ   = 0x660F3859,
    VBROADCASTI128 = 0x660F385A,
    VINSERTI128    = 0x660F3A38,

// AES
    AESENC     = 0x660F38DC,
    AESENCLAST = 0x660F38DD,
    AESDEC     = 0x660F38DE,
    AESDECLAST = 0x660F38DF,
    AESIMC     = 0x660F38DB,
    AESKEYGENASSIST = 0x660F3ADF,
}
