// llmath.d
// Copyright (C) 1993-2003 by Digital Mars, www.digitalmars.com
// All Rights Reserved
// Written by Walter Bright

module rt.llmath;

// Compiler runtime support for 64 bit longs

extern (C):


/***************************************
 * Unsigned long divide.
 * Input:
 *      [EDX,EAX],[ECX,EBX]
 * Output:
 *      [EDX,EAX] = [EDX,EAX] / [ECX,EBX]
 *      [ECX,EBX] = [EDX,EAX] % [ECX,EBX]
 *      ESI,EDI destroyed
 */

void __ULDIV__()
{
    asm
    {
        naked                   ;
        test    ECX,ECX         ;
        jz      uldiv           ;

        push    EBP             ;

        // left justify [ECX,EBX] and leave count of shifts + 1 in EBP

        mov     EBP,1           ;       // at least 1 shift
        test    ECX,ECX         ;       // left justified?
        js      L1              ;       // yes
        jnz     L2              ;
        add     EBP,8           ;
        mov     CH,CL           ;
        mov     CL,BH           ;
        mov     BH,BL           ;
        xor     BL,BL           ;       // [ECX,EBX] <<= 8
        test    ECX,ECX         ;
        js      L1              ;
        even                    ;
L2:     inc     EBP             ;       // another shift
        shl     EBX,1           ;
        rcl     ECX,1           ;       // [ECX,EBX] <<= 1
        jno     L2              ;       // not left justified yet

L1:     mov     ESI,ECX         ;
        mov     EDI,EBX         ;       // [ESI,EDI] = divisor

        mov     ECX,EDX         ;
        mov     EBX,EAX         ;       // [ECX,EBX] = [EDX,EAX]
        xor     EAX,EAX         ;
        cdq                     ;       // [EDX,EAX] = 0
        even                    ;
L4:     cmp     ESI,ECX         ;       // is [ECX,EBX] > [ESI,EDI]?
        ja      L3              ;       // yes
        jb      L5              ;       // definitely less than
        cmp     EDI,EBX         ;       // check low order word
        ja      L3              ;
L5:     sub     EBX,EDI         ;
        sbb     ECX,ESI         ;       // [ECX,EBX] -= [ESI,EDI]
        stc                     ;       // rotate in a 1
L3:     rcl     EAX,1           ;
        rcl     EDX,1           ;       // [EDX,EAX] = ([EDX,EAX] << 1) + C
        shr     ESI,1           ;
        rcr     EDI,1           ;       // [ESI,EDI] >>= 1
        dec     EBP             ;       // control count
        jne     L4              ;
        pop     EBP             ;
        ret                     ;

div0:   mov     EAX,-1          ;
        cwd                     ;       // quotient is -1
//      xor     ECX,ECX         ;
//      mov     EBX,ECX         ;       // remainder is 0 (ECX and EBX already 0)
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

private real adjust = cast(real)0x800_0000_0000_0000 * 0x10;

real __U64_LDBL()
{
    asm
    {   naked                                   ;
        push    EDX                             ;
        push    EAX                             ;
        and     dword ptr 4[ESP], 0x7FFFFFFF    ;
        fild    qword ptr [ESP]                 ;
        test    EDX,EDX                         ;
        jns     L1                              ;
        fld     real ptr adjust                 ;
        faddp   ST(1), ST                       ;
    L1:                                         ;
        add     ESP, 8                          ;
        ret                                     ;
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

// Convert double to ulong

private short roundTo0 = 0xFBF;

ulong __DBLULLNG()
{
    // BUG: should handle NAN's and overflows
    asm
    {   naked                                   ;
        push    EDX                             ;
        push    EAX                             ;
        fld     double ptr [ESP]                ;
        sub     ESP,8                           ;
        fld     real ptr adjust                 ;
        fcomp                                   ;
        fstsw   AX                              ;
        fstcw   8[ESP]                          ;
        fldcw   roundTo0                        ;
        sahf                                    ;
        jae     L1                              ;
        fld     real ptr adjust                 ;
        fsubp   ST(1), ST                       ;
        fistp   qword ptr [ESP]                 ;
        pop     EAX                             ;
        pop     EDX                             ;
        fldcw   [ESP]                           ;
        add     ESP,8                           ;
        add     EDX,0x8000_0000                 ;
        ret                                     ;
    L1:                                         ;
        fistp   qword ptr [ESP]                 ;
        pop     EAX                             ;
        pop     EDX                             ;
        fldcw   [ESP]                           ;
        add     ESP,8                           ;
        ret                                     ;
    }
}

// Convert double in ST0 to uint

uint __DBLULNG()
{
    // BUG: should handle NAN's and overflows
    asm
    {   naked                                   ;
        sub     ESP,16                          ;
        fstcw   8[ESP]                          ;
        fldcw   roundTo0                        ;
        fistp   qword ptr [ESP]                 ;
        fldcw   8[ESP]                          ;
        pop     EAX                             ;
        add     ESP,12                          ;
        ret                                     ;
    }
}
