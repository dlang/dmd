/**
 * Support for 64-bit longs.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_llmath.d)
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

void __ULDIV2__()
{
    version (D_InlineAsm_X86)
    {
        asm
        {
            naked                   ;
            mov     EBX,4[ESP]      ;   // the only difference between this and __ULDIV__
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
L1:         dec     EBP             ;
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

uldiv:      test    EDX,EDX         ;
            jnz     D3              ;
            // Both high words are 0, we can use the DIV instruction
            div     EBX             ;
            mov     EBX,EDX         ;
            mov     EDX,ECX         ;       // EDX = ECX = 0
            ret                     ;

            even                    ;
D3:         // Divide [EDX,EAX] by EBX
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

quo0:       // Quotient is 0
            // Remainder is [EDX,EAX]
            mov     EBX,EAX         ;
            mov     ECX,EDX         ;
            xor     EAX,EAX         ;
            xor     EDX,EDX         ;
            ret                     ;

Lleft:      // The quotient is 0 or 1 and EDX >= ECX
            cmp     EDX,ECX         ;
            ja      quo1            ;       // [EDX,EAX] > [ECX,EBX]
            // EDX == ECX
            cmp     EAX,EBX         ;
            jb      quo0            ;

quo1:       // Quotient is 1
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
    else version (D_InlineAsm_X86_64)
        assert(0);
    else
        static assert(0);
}

void __ULDIV__()
{
    version (D_InlineAsm_X86)
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
L1:         dec     EBP             ;
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

uldiv:      test    EDX,EDX         ;
            jnz     D3              ;
            // Both high words are 0, we can use the DIV instruction
            div     EBX             ;
            mov     EBX,EDX         ;
            mov     EDX,ECX         ;       // EDX = ECX = 0
            ret                     ;

            even                    ;
D3:         // Divide [EDX,EAX] by EBX
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

quo0:       // Quotient is 0
            // Remainder is [EDX,EAX]
            mov     EBX,EAX         ;
            mov     ECX,EDX         ;
            xor     EAX,EAX         ;
            xor     EDX,EDX         ;
            ret                     ;

Lleft:      // The quotient is 0 or 1 and EDX >= ECX
            cmp     EDX,ECX         ;
            ja      quo1            ;       // [EDX,EAX] > [ECX,EBX]
            // EDX == ECX
            cmp     EAX,EBX         ;
            jb      quo0            ;

quo1:       // Quotient is 1
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
    else version (D_InlineAsm_X86_64)
        assert(0);
    else
        static assert(0);
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

void __LDIV2__()
{
    version (D_InlineAsm_X86)
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
              neg   dword ptr 4[ESP] ;
              sbb   ECX,0           ;
            push    dword ptr 4[ESP] ;
            call    __ULDIV2__      ;
            add     ESP,4           ;
            //neg64 ECX,EBX         ;       // remainder same sign as dividend
              neg   ECX             ;
              neg   EBX             ;
              sbb   ECX,0           ;
            ret                     ;

L11:
            push    dword ptr 4[ESP] ;
            call    __ULDIV2__      ;
            add     ESP,4           ;
            //neg64 ECX,EBX         ;       // remainder same sign as dividend
              neg   ECX             ;
              neg   EBX             ;
              sbb   ECX,0           ;
            //neg64 EDX,EAX         ;       // quotient is negative
              neg   EDX             ;
              neg   EAX             ;
              sbb   EDX,0           ;
            ret                     ;

L10:        test    ECX,ECX         ;       // [ECX,EBX] negative?
            jns     L12             ;       // no (all is positive)
            //neg64 ECX,EBX         ;
              neg   ECX             ;
              neg   dword ptr 4[ESP] ;
              sbb   ECX,0           ;
            push    dword ptr 4[ESP] ;
            call    __ULDIV2__      ;
            add     ESP,4           ;
            //neg64 EDX,EAX         ;       // quotient is negative
              neg   EDX             ;
              neg   EAX             ;
              sbb   EDX,0           ;
            ret                     ;

L12:        jmp     __ULDIV2__      ;
        }
    }
    else version (D_InlineAsm_X86_64)
        assert(0);
    else
        static assert(0);
}

void __LDIV__()
{
    version (D_InlineAsm_X86)
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

L11:        call    __ULDIV__       ;
            //neg64 ECX,EBX         ;       // remainder same sign as dividend
              neg   ECX             ;
              neg   EBX             ;
              sbb   ECX,0           ;
            //neg64 EDX,EAX         ;       // quotient is negative
              neg   EDX             ;
              neg   EAX             ;
              sbb   EDX,0           ;
            ret                     ;

L10:        test    ECX,ECX         ;       // [ECX,EBX] negative?
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

L12:        jmp     __ULDIV__       ;
        }
    }
    else version (D_InlineAsm_X86_64)
        assert(0);
    else
        static assert(0);
}


version(Win32) version(CRuntime_Microsoft)
{
    extern(C) void _alldiv();
    extern(C) void _aulldiv();
    extern(C) void _allrem();
    extern(C) void _aullrem();

    void _ms_alldiv()
    {
        asm
        {
            naked            ;
            push ECX         ;
            push EBX         ;
            push EDX         ;
            push EAX         ;
            call _alldiv     ;
            ret              ;
        }
    }

    void _ms_aulldiv()
    {
        asm
        {
            naked            ;
            push ECX         ;
            push EBX         ;
            push EDX         ;
            push EAX         ;
            call _aulldiv    ;
            ret              ;
        }
    }

    void _ms_allrem()
    {
        asm
        {
            naked            ;
            push ECX         ;
            push EBX         ;
            push EDX         ;
            push EAX         ;
            call _allrem     ;
            mov EBX,EAX      ;
            mov ECX,EDX      ;
            ret              ;
        }
    }

    void _ms_aullrem()
    {
        asm
        {
            naked            ;
            push ECX         ;
            push EBX         ;
            push EDX         ;
            push EAX         ;
            call _aullrem    ;
            mov EBX,EAX      ;
            mov ECX,EDX      ;
            ret              ;
        }
    }
}
