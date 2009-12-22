/**
 * Support for 64-bit longs.
 *
 * Copyright: Copyright Digital Mars 1993 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 *
 *          Copyright Digital Mars 1993 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.llmath;

extern (C):


/***************************************
 * Unsigned long divide.
 * Input:
 *      [EDX,EAX],[ECX,EBX]
 * Output:
 *      [EDX,EAX] = [EDX,EAX] / [ECX,EBX]
 *      [ECX,EBX] = [EDX,EAX] % [ECX,EBX]
 */

void __ULDIV__()
{
    asm
    {
        naked                   ;
        test    ECX,ECX         ;
        jz      uldiv           ;

        // if ECX > EDX, then quotient is 0 and remainder is [EDX,EAX]
        cmp     ECX,EDX         ;
        ja      quo0            ;

        test    ECX,ECX         ;
        js      Lleft           ;

        /* We have n>d, and know that n/d will fit in 32 bits.
         * d will be left justified if we shift it left s bits.
         * [d1,d0] <<= s
         * [n2,n1,n0] = [n1,n0] << s
         *
         * Use one divide, by this reasoning:
         * ([n2,n1]<<32 + n0)/(d1<<32 + d0)
         * becomes:
         * ([n2,n1]<<32)/(d1<<32 + d0) + n0/(d1<<32 + d0)
         * The second divide is always 0.
         * Ignore the d0 in the first divide, which will yield a quotient
         * that might be too high by 1 (because d1 is left justified).
         * We can tell if it's too big if:
         *  q*[d1,d0] > [n2,n1,n0]
         * which is:
         *  q*[d1,d0] > [[q*[d1,0]+q%[d1,0],n1,n0]
         * If we subtract q*[d1,0] from both sides, we get:
         *  q*d0 > [[n2,n1]%d1,n0]
         * So if it is too big by one, reduce q by one to q'=q-one.
         * Compute remainder as:
         *  r = ([n1,n0] - q'*[d1,d0]) >> s
         * Again, we can subtract q*[d1,0]:
         *  r = ([n1,n0] - q*[d1,0] - (q'*[d1,d0] - q*[d1,0])) >> s
         *  r = ([[n2,n1]%d1,n0] + (q*[d1,0] - (q - one)*[d1,d0])) >> s
         *  r = ([[n2,n1]%d1,n0] + (q*[d1,0] - [d1 *(q-one),d0*(1-q)])) >> s
         *  r = ([[n2,n1]%d1,n0] + [d1 *one,d0*(one-q)])) >> s
         */

        push    EBP             ;
        push    ESI             ;
        push    EDI             ;

        mov     ESI,EDX         ;
        mov     EDI,EAX         ;
        mov     EBP,ECX         ;

        bsr     EAX,ECX         ;       // EAX is now 30..0
        xor     EAX,0x1F        ;       // EAX is now 1..31
        mov     CH,AL           ;
        neg     EAX             ;
        add     EAX,32          ;
        mov     CL,AL           ;

        mov     EAX,EBX         ;
        shr     EAX,CL          ;
        xchg    CH,CL           ;
        shl     EBP,CL          ;
        or      EBP,EAX         ;
        shl     EBX,CL          ;

        mov     EDX,ESI         ;
        xchg    CH,CL           ;
        shr     EDX,CL          ;

        mov     EAX,EDI         ;
        shr     EAX,CL          ;
        xchg    CH,CL           ;
        shl     EDI,CL          ;
        shl     ESI,CL          ;
        or      EAX,ESI         ;

        div     EBP             ;
        push    EBP             ;
        mov     EBP,EAX         ;
        mov     ESI,EDX         ;

        mul     EBX             ;
        cmp     EDX,ESI         ;
        ja      L1              ;
        jb      L2              ;
        cmp     EAX,EDI         ;
        jbe     L2              ;
L1:     dec     EBP             ;
        sub     EAX,EBX         ;
        sbb     EDX,0[ESP]      ;
L2:
        add     ESP,4           ;
        sub     EDI,EAX         ;
        sbb     ESI,EDX         ;
        mov     EAX,ESI         ;
        xchg    CH,CL           ;
        shl     EAX,CL          ;
        xchg    CH,CL           ;
        shr     EDI,CL          ;
        or      EDI,EAX         ;
        shr     ESI,CL          ;
        mov     EBX,EDI         ;
        mov     ECX,ESI         ;
        mov     EAX,EBP         ;
        xor     EDX,EDX         ;

        pop     EDI             ;
        pop     ESI             ;
        pop     EBP             ;
        ret                     ;

uldiv:  test    EDX,EDX         ;
        jnz     D3              ;
        // Both high words are 0, we can use the DIV instruction
        div     EBX             ;
        mov     EBX,EDX         ;
        mov     EDX,ECX         ;       // EDX = ECX = 0
        ret                     ;

        even                    ;
D3:     // Divide [EDX,EAX] by EBX
        mov     ECX,EAX         ;
        mov     EAX,EDX         ;
        xor     EDX,EDX         ;
        div     EBX             ;
        xchg    ECX,EAX         ;
        div     EBX             ;
        // ECX,EAX = result
        // EDX = remainder
        mov     EBX,EDX         ;
        mov     EDX,ECX         ;
        xor     ECX,ECX         ;
        ret                     ;

quo0:   // Quotient is 0
        // Remainder is [EDX,EAX]
        mov     EBX,EAX         ;
        mov     ECX,EDX         ;
        xor     EAX,EAX         ;
        xor     EDX,EDX         ;
        ret                     ;

Lleft:  // The quotient is 0 or 1 and EDX >= ECX
        cmp     EDX,ECX         ;
        ja      quo1            ;       // [EDX,EAX] > [ECX,EBX]
        // EDX == ECX
        cmp     EAX,EBX         ;
        jb      quo0            ;

quo1:   // Quotient is 1
        // Remainder is [EDX,EAX] - [ECX,EBX]
        sub     EAX,EBX         ;
        sbb     EDX,ECX         ;
        mov     EBX,EAX         ;
        mov     ECX,EDX         ;
        mov     EAX,1           ;
        xor     EDX,EDX         ;
        ret                     ;
    }
}


/***************************************
 * Signed long divide.
 * Input:
 *      [EDX,EAX],[ECX,EBX]
 * Output:
 *      [EDX,EAX] = [EDX,EAX] / [ECX,EBX]
 *      [ECX,EBX] = [EDX,EAX] % [ECX,EBX]
 *      ESI,EDI destroyed
 */

void __LDIV__()
{
    asm
    {
        naked                   ;
        test    EDX,EDX         ;       // [EDX,EAX] negative?
        jns     L10             ;       // no
        //neg64 EDX,EAX         ;       // [EDX,EAX] = -[EDX,EAX]
          neg   EDX             ;
          neg   EAX             ;
          sbb   EDX,0           ;
        test    ECX,ECX         ;       // [ECX,EBX] negative?
        jns     L11             ;       // no
        //neg64 ECX,EBX         ;
          neg   ECX             ;
          neg   EBX             ;
          sbb   ECX,0           ;
        call    __ULDIV__       ;
        //neg64 ECX,EBX         ;       // remainder same sign as dividend
          neg   ECX             ;
          neg   EBX             ;
          sbb   ECX,0           ;
        ret                     ;

L11:    call    __ULDIV__       ;
        //neg64 ECX,EBX         ;       // remainder same sign as dividend
          neg   ECX             ;
          neg   EBX             ;
          sbb   ECX,0           ;
        //neg64 EDX,EAX         ;       // quotient is negative
          neg   EDX             ;
          neg   EAX             ;
          sbb   EDX,0           ;
        ret                     ;

L10:    test    ECX,ECX         ;       // [ECX,EBX] negative?
        jns     L12             ;       // no (all is positive)
        //neg64 ECX,EBX         ;
          neg   ECX             ;
          neg   EBX             ;
          sbb   ECX,0           ;
        call    __ULDIV__       ;
        //neg64 EDX,EAX         ;       // quotient is negative
          neg   EDX             ;
          neg   EAX             ;
          sbb   EDX,0           ;
        ret                     ;

L12:    jmp     __ULDIV__       ;
    }
}


/***************************************
 * Compare [EDX,EAX] with [ECX,EBX]
 * Signed
 * Returns result in flags
 */

void __LCMP__()
{
    asm
    {
        naked                   ;
        cmp     EDX,ECX         ;
        jne     C1              ;
        push    EDX             ;
        xor     EDX,EDX         ;
        cmp     EAX,EBX         ;
        jz      C2              ;
        ja      C3              ;
        dec     EDX             ;
        pop     EDX             ;
        ret                     ;

C3:     inc     EDX             ;
C2:     pop     EDX             ;
C1:     ret                     ;
    }
}




// Convert ulong to real

private enum real adjust = 1.0L/real.epsilon;
static assert((cast(real)0x800_0000_0000_0000 * 0x10) == 1.0L/real.epsilon);

real __U64_LDBL()
{
    version (OSX)
    {   /* OSX version has to be concerned about 16 byte stack
         * alignment and the inability to reference the data segment
         * because of PIC.
         */
        asm
        {   naked                               ;
            push        EDX                     ;
            push        EAX                     ;
            and         dword ptr 4[ESP], 0x7FFFFFFF    ;
            fild        qword ptr [ESP]         ;
            test        EDX,EDX                 ;
            jns         L1                      ;
            push        0x0000403e              ;
            push        0x80000000              ;
            push        0                       ;
            fld         real ptr [ESP]          ; // adjust
            add         ESP,12                  ;
            faddp       ST(1), ST               ;
        L1:                                     ;
            add         ESP, 8                  ;
            ret                                 ;
        }
    }
    else
    {
        asm
        {   naked                               ;
            push        EDX                     ;
            push        EAX                     ;
            and         dword ptr 4[ESP], 0x7FFFFFFF    ;
            fild        qword ptr [ESP]         ;
            test        EDX,EDX                 ;
            jns         L1                      ;
            fld         real ptr adjust         ;
            faddp       ST(1), ST               ;
        L1:                                     ;
            add         ESP, 8                  ;
            ret                                 ;
        }
    }
}

// Same as __U64_LDBL, but return result as double in [EDX,EAX]
ulong __ULLNGDBL()
{
    asm
    {   naked                                   ;
        call __U64_LDBL                         ;
        sub  ESP,8                              ;
        fstp double ptr [ESP]                   ;
        pop  EAX                                ;
        pop  EDX                                ;
        ret                                     ;
    }
}

// Convert double in EDX:EAX to ulong

private __gshared short roundTo0 = 0xFBF;

ulong __DBLULLNG()
{
    // BUG: should handle NAN's and overflows
    version (OSX)
    {
        asm
        {   naked                               ;
            push        0xFBF                   ; // roundTo0
            push        0x0000403e              ;
            push        0x80000000              ;
            push        0                       ; // adjust
            push        EDX                     ;
            push        EAX                     ;
            fld         double ptr [ESP]        ;
            sub         ESP,8                   ;
            fld         real ptr 16[ESP]        ; // adjust
            fcomp                               ;
            fstsw       AX                      ;
            fstcw       8[ESP]                  ;
            fldcw       28[ESP]                 ; // roundTo0
            sahf                                ;
            jae         L1                      ;
            fld         real ptr 16[ESP]        ; // adjust
            fsubp       ST(1), ST               ;
            fistp       qword ptr [ESP]         ;
            pop         EAX                     ;
            pop         EDX                     ;
            fldcw       [ESP]                   ;
            add         ESP,24                  ;
            add         EDX,0x8000_0000         ;
            ret                                 ;
        L1:                                     ;
            fistp       qword ptr [ESP]         ;
            pop         EAX                     ;
            pop         EDX                     ;
            fldcw       [ESP]                   ;
            add         ESP,24                  ;
            ret                                 ;
        }
    }
    else
    {
        asm
        {   naked                               ;
            push        EDX                     ;
            push        EAX                     ;
            fld         double ptr [ESP]        ;
            sub         ESP,8                   ;
            fld         real ptr adjust         ;
            fcomp                               ;
            fstsw       AX                      ;
            fstcw       8[ESP]                  ;
            fldcw       roundTo0                ;
            sahf                                ;
            jae         L1                      ;
            fld         real ptr adjust         ;
            fsubp       ST(1), ST               ;
            fistp       qword ptr [ESP]         ;
            pop         EAX                     ;
            pop         EDX                     ;
            fldcw       [ESP]                   ;
            add         ESP,8                   ;
            add         EDX,0x8000_0000         ;
            ret                                 ;
        L1:                                     ;
            fistp       qword ptr [ESP]         ;
            pop         EAX                     ;
            pop         EDX                     ;
            fldcw       [ESP]                   ;
            add         ESP,8                   ;
            ret                                 ;
        }
    }
}

// Convert double in ST0 to uint

uint __DBLULNG()
{
    // BUG: should handle NAN's and overflows
    version (OSX)
    {
        asm
        {   naked                               ;
            push        0xFBF                   ; // roundTo0
            sub         ESP,12                  ;
            fstcw       8[ESP]                  ;
            fldcw       12[ESP]                 ; // roundTo0
            fistp       qword ptr [ESP]         ;
            fldcw       8[ESP]                  ;
            pop         EAX                     ;
            add         ESP,12                  ;
            ret                                 ;
        }
    }
    else
    {
        asm
        {   naked                               ;
            sub         ESP,16                  ;
            fstcw       8[ESP]                  ;
            fldcw       roundTo0                ;
            fistp       qword ptr [ESP]         ;
            fldcw       8[ESP]                  ;
            pop         EAX                     ;
            add         ESP,12                  ;
            ret                                 ;
        }
    }
}

// Convert real in ST0 to ulong

ulong __LDBLULLNG()
{
    version (OSX)
    {
        asm
        {   naked                               ;
            push        0xFBF                   ; // roundTo0
            push        0x0000403e              ;
            push        0x80000000              ;
            push        0                       ; // adjust
            sub         ESP,16                  ;
            fld         real ptr 16[ESP]        ; // adjust
            fcomp                               ;
            fstsw       AX                      ;
            fstcw       8[ESP]                  ;
            fldcw       28[ESP]                 ; // roundTo0
            sahf                                ;
            jae         L1                      ;
            fld         real ptr 16[ESP]        ; // adjust
            fsubp       ST(1), ST               ;
            fistp       qword ptr [ESP]         ;
            pop         EAX                     ;
            pop         EDX                     ;
            fldcw       [ESP]                   ;
            add         ESP,24                  ;
            add         EDX,0x8000_0000         ;
            ret                                 ;
        L1:                                     ;
            fistp       qword ptr [ESP]         ;
            pop         EAX                     ;
            pop         EDX                     ;
            fldcw       [ESP]                   ;
            add         ESP,24                  ;
            ret                                 ;
        }
    }
    else
    {
        asm
        {   naked                               ;
            sub         ESP,16                  ;
            fld         real ptr adjust         ;
            fcomp                               ;
            fstsw       AX                      ;
            fstcw       8[ESP]                  ;
            fldcw       roundTo0                ;
            sahf                                ;
            jae         L1                      ;
            fld         real ptr adjust         ;
            fsubp       ST(1), ST               ;
            fistp       qword ptr [ESP]         ;
            pop         EAX                     ;
            pop         EDX                     ;
            fldcw       [ESP]                   ;
            add         ESP,8                   ;
            add         EDX,0x8000_0000         ;
            ret                                 ;
        L1:                                     ;
            fistp       qword ptr [ESP]         ;
            pop         EAX                     ;
            pop         EDX                     ;
            fldcw       [ESP]                   ;
            add         ESP,8                   ;
            ret                                 ;
        }
    }
}


