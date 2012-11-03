// XMM opcodes

enum
{
    ADDSS = 0xF30F58,
    ADDSD = 0xF20F58,
    ADDPS = 0x000F58,
    ADDPD = 0x660F58,
    PADDB = 0x660FFC,
    PADDW = 0x660FFD,
    PADDD = 0x660FFE,
    PADDQ = 0x660FD4,

    SUBSS = 0xF30F5C,
    SUBSD = 0xF20F5C,
    SUBPS = 0x000F5C,
    SUBPD = 0x660F5C,
    PSUBB = 0x660FF8,
    PSUBW = 0x660FF9,
    PSUBD = 0x660FFA,
    PSUBQ = 0x660FFB,

    MULSS = 0xF30F59,
    MULSD = 0xF20F59,
    MULPS = 0x000F59,
    MULPD = 0x660F59,
    PMULLW = 0x660FD5,

    DIVSS = 0xF30F5E,
    DIVSD = 0xF20F5E,
    DIVPS = 0x000F5E,
    DIVPD = 0x660F5E,

    PAND  = 0x660FDB,
    POR   = 0x660FEB,

    UCOMISS = 0x000F2E,
    UCOMISD = 0x660F2E,

    XORPS = 0x000F57,
    XORPD = 0x660F57,

    // Use STO and LOD instead of MOV to distinguish the direction
    STOSS  = 0xF30F11,      // MOVSS
    STOSD  = 0xF20F11,
    STOAPS = 0x000F29,
    STOAPD = 0x660F29,          // MOVAPD xmm1/mem128, xmm2   66 0F 29 /r
    STODQA = 0x660F7F,
    STOD   = 0x660F7E,          // MOVD reg/mem64, xmm   66 0F 7E /r
    STOQ   = 0x660FD6,

    LODSS  = 0xF30F10,      // MOVSS
    LODSD  = 0xF20F10,
    LODAPS = 0x000F28,
    LODAPD = 0x660F28,          // MOVAPD xmm1, xmm2/mem128   66 0F 28 /r
    LODDQA = 0x660F6F,
    LODD   = 0x660F6E,          // MOVD xmm, reg/mem64   66 0F 6E /r
    LODQ   = 0xF30F7E,

    LODDQU   = 0xF30F6F,        // MOVDQU xmm1, xmm2/mem128  F3 0F 6F /r
    STODQU   = 0xF30F7F,        // MOVDQU xmm1/mem128, xmm2  F3 0F 7F /r
    MOVDQ2Q  = 0xF20FD6,        // MOVDQ2Q mmx, xmm          F2 0F D6 /r
    MOVHLPS  = 0x0F12,          // MOVHLPS xmm1, xmm2        0F 12 /r
    LODHPD   = 0x660F16,
    STOHPD   = 0x660F17,        // MOVHPD mem64, xmm         66 0F 17 /r
    LODHPS   = 0x0F16,          // MOVHPD xmm, mem64         66 0F 16 /r
    STOHPS   = 0x0F17,
    MOVLHPS  = 0x0F16,
    LODLPD   = 0x660F12,
    STOLPD   = 0x660F13,
    LODLPS   = 0x0F12,
    STOLPS   = 0x0F13,
    MOVMSKPD = 0x660F50,
    MOVMSKPS = 0x0F50,
    MOVNTDQ  = 0x660FE7,
    MOVNTI   = 0x0FC3,
    MOVNTPD  = 0x660F2B,
    MOVNTPS  = 0x0F2B,
    MOVNTQ   = 0x0FE7,
    MOVQ2DQ  = 0xF30FD6,
    LODUPD   = 0x660F10,
    STOUPD   = 0x660F11,
    LODUPS   = 0x0F10,
    STOUPS   = 0x0F11,

    PACKSSDW = 0x660F6B,
    PACKSSWB = 0x660F63,
    PACKUSWB = 0x660F67,
    PADDSB = 0x660FEC,
    PADDSW = 0x660FED,
    PADDUSB = 0x660FDC,
    PADDUSW = 0x660FDD,
    PANDN = 0x660FDF,
    PCMPEQB = 0x660F74,
    PCMPEQD = 0x660F76,
    PCMPEQW = 0x660F75,
    PCMPGTB = 0x660F64,
    PCMPGTD = 0x660F66,
    PCMPGTW = 0x660F65,
    PMADDWD = 0x660FF5,
    PSLLW = 0x660FF1,   // PSLLW xmm1, xmm2/mem128    66 0F F1 /r
                        // PSLLW xmm, imm8            66 0F 71 /6 ib
    PSLLD = 0x660FF2,   // PSLLD xmm1, xmm2/mem128    66 0F F2 /r
                        // PSLLD xmm, imm8            66 0F 72 /6 ib
    PSLLQ = 0x660FF3,   // PSLLQ xmm1, xmm2/mem128    66 0F F3 /r
                        // PSLLQ xmm, imm8            66 0F 73 /6 ib
    PSRAW = 0x660FE1,   // PSRAW xmm1, xmm2/mem128    66 0F E1 /r
                        // PSRAW xmm, imm8            66 0F 71 /4 ib
    PSRAD = 0x660FE2,   // PSRAD xmm1, xmm2/mem128    66 0F E2 /r
                        // PSRAD xmm, imm8            66 0F 72 /4 ib
    PSRLW = 0x660FD1,   // PSRLW xmm1, xmm2/mem128    66 0F D1 /r
                        // PSRLW xmm, imm8            66 0F 71 /2 ib
    PSRLD = 0x660FD2,   // PSRLD xmm1, xmm2/mem128    66 0F D2 /r
                        // PSRLD xmm, imm8            66 0F 72 /2 ib
    PSRLQ = 0x660FD3,   // PSRLQ xmm1, xmm2/mem128    66 0F D3 /r
                        // PSRLQ xmm, imm8            66 0F 73 /2 ib
    PSUBSB = 0x660FE8,
    PSUBSW = 0x660FE9,
    PSUBUSB = 0x660FD8,
    PSUBUSW = 0x660FD9,
    PUNPCKHBW = 0x660F68,
    PUNPCKHDQ = 0x660F6A,
    PUNPCKHWD = 0x660F69,
    PUNPCKLBW = 0x660F60,
    PUNPCKLDQ = 0x660F62,
    PUNPCKLWD = 0x660F61,
    PXOR = 0x660FEF,
    ANDPD = 0x660F54,
    ANDPS = 0x0F54,
    ANDNPD = 0x660F55,
    ANDNPS = 0x0F55,
    CMPPS = 0x0FC2,
    CMPPD = 0x660FC2,
    CMPSD = 0xF20FC2,
    CMPSS = 0xF30FC2,
    COMISD = 0x660F2F,
    COMISS = 0x0F2F,
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
    MAXSS = 0xF30F5F,
    MINPD = 0x660F5D,
    MINPS = 0x0F5D,
    MINSD = 0xF20F5D,
    MINSS = 0xF30F5D,           // MINSS xmm1, xmm2/mem32   F3 0F 5D /r
    ORPD = 0x660F56,
    ORPS = 0x0F56,
    PAVGB = 0x660FE0,
    PAVGW = 0x660FE3,
    PMAXSW = 0x660FEE,
    PINSRW = 0x660FC4,          // PINSRW xmm, reg32/mem16, imm8   66 0F C4 /r ib
    PMAXUB = 0x660FDE,
    PMINSW = 0x660FEA,
    PMINUB = 0x660FDA,
    PMOVMSKB = 0x660FD7,        // PMOVMSKB reg32, xmm   66 0F D7 /r
    PMULHUW = 0x660FE4,
    PMULHW = 0x660FE5,
    PMULUDQ = 0x660FF4,
    PSADBW = 0x660FF6,
    PUNPCKHQDQ = 0x660F6D,
    PUNPCKLQDQ = 0x660F6C,
    RCPPS = 0x0F53,
    RCPSS = 0xF30F53,
    RSQRTPS = 0x0F52,
    RSQRTSS = 0xF30F52,
    SQRTPD = 0x660F51,
    SHUFPD = 0x660FC6,
    SHUFPS = 0x0FC6,
    SQRTPS = 0x0F51,
    SQRTSD = 0xF20F51,
    SQRTSS = 0xF30F51,
    UNPCKHPD = 0x660F15,
    UNPCKHPS = 0x0F15,
    UNPCKLPD = 0x660F14,        // UNPCKLPD xmm1, xmm2/mem128   66 0F 14 /r
    UNPCKLPS = 0x0F14,

    PSHUFD = 0x660F70,
    PSHUFHW = 0xF30F70,
    PSHUFLW = 0xF20F70,         // PSHUFLW xmm1, xmm2/mem128, imm8  F2 0F 70 /r ib
    PSHUFW = 0x0F70,
    PSLLDQ = 0x07660F73,        // PSLLDQ xmm, imm8   66 0F 73 /7 ib
    PSRLDQ = 0x03660F73,        // PSRLDQ xmm, imm8   66 0F 73 /3 ib

    PREFETCH = 0x0F18,

// SSE3 Pentium 4 (Prescott)

    ADDSUBPD = 0x660FD0,
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

    BLENDPD   = 0x660F3A0D,
    BLENDPS   = 0x660F3A0C,
    BLENDVPD  = 0x660F3815,
    BLENDVPS  = 0x660F3814,
    DPPD      = 0x660F3A41,
    DPPS      = 0x660F3A40,
    EXTRACTPS = 0x660F3A17,
    INSERTPS  = 0x660F3A21,
    MPSADBW   = 0x660F3A42,
    PBLENDVB  = 0x660F3810,
    PBLENDW   = 0x660F3A0E,
    PEXTRD    = 0x660F3A16,
    PEXTRQ    = 0x660F3A16,
    PINSRB    = 0x660F3A20,
    PINSRD    = 0x660F3A22,
    PINSRQ    = 0x660F3A22,

    MOVNTDQA = 0x660F382A,
    PACKUSDW = 0x660F382B,
    PCMPEQQ = 0x660F3829,
    PEXTRB = 0x660F3A14,
    PHMINPOSUW = 0x660F3841,
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
    PTEST    = 0x660F3817,

    ROUNDPD = 0x660F3A09,
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

// AES
    AESENC     = 0x660F38DC,
    AESENCLAST = 0x660F38DD,
    AESDEC     = 0x660F38DE,
    AESDECLAST = 0x660F38DF,
    AESIMC     = 0x660F38DB,
    AESKEYGENASSIST = 0x660F3ADF,
};
