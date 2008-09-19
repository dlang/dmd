/*_ _alloca.d
 * Copyright (C) 1990-2003 by Digital Mars, www.digitalmars.com
 * All Rights Reserved
 * Written by Walter Bright
 */

module rt.alloca;

/+
#if DOS386
extern size_t _x386_break;
#else
extern size_t _pastdata;
#endif
+/

/*******************************************
 * Allocate data from the caller's stack frame.
 * This is a 'magic' function that needs help from the compiler to
 * work right, do not change its name, do not call it from other compilers.
 * Input:
 *      nbytes  number of bytes to allocate
 *      ECX     address of variable with # of bytes in locals
 *              This is adjusted upon return to reflect the additional
 *              size of the stack frame.
 * Returns:
 *      EAX     allocated data, null if stack overflows
 */

extern (C) void* __alloca(int nbytes)
{
    asm
    {
        naked                   ;
        mov     EDX,ECX         ;
        mov     EAX,4[ESP]      ; // get nbytes
        push    EBX             ;
        push    EDI             ;
        push    ESI             ;
        add     EAX,3           ;
        and     EAX,0xFFFFFFFC  ; // round up to dword
        jnz     Abegin          ;
        mov     EAX,4           ; // allow zero bytes allocation, 0 rounded to dword is 4..
    Abegin:
        mov     ESI,EAX         ; // ESI = nbytes
        neg     EAX             ;
        add     EAX,ESP         ; // EAX is now what the new ESP will be.
        jae     Aoverflow       ;
    }
    version (Windows)
    {
    asm
    {
        // We need to be careful about the guard page
        // Thus, for every 4k page, touch it to cause the OS to load it in.
        mov     ECX,EAX         ; // ECX is new location for stack
        mov     EBX,ESI         ; // EBX is size to "grow" stack
    L1:
        test    [ECX+EBX],EBX   ; // bring in page
        sub     EBX,0x1000      ; // next 4K page down
        jae     L1              ; // if more pages
        test    [ECX],EBX       ; // bring in last page
    }
    }
    version (DOS386)
    {
    asm
    {
        // is ESP off bottom?
        cmp     EAX,_x386_break ;
        jbe     Aoverflow       ;
    }
    }
    version (Unix)
    {
    asm
    {
        cmp     EAX,_pastdata   ;
        jbe     Aoverflow       ; // Unlikely - ~2 Gbytes under UNIX
    }
    }
    asm
    {
        // Copy down to [ESP] the temps on the stack.
        // The number of temps is (EBP - ESP - locals).
        mov     ECX,EBP         ;
        sub     ECX,ESP         ;
        sub     ECX,[EDX]       ; // ECX = number of temps (bytes) to move.
        add     [EDX],ESI       ; // adjust locals by nbytes for next call to alloca()
        mov     ESP,EAX         ; // Set up new stack pointer.
        add     EAX,ECX         ; // Return value = ESP + temps.
        mov     EDI,ESP         ; // Destination of copy of temps.
        add     ESI,ESP         ; // Source of copy.
        shr     ECX,2           ; // ECX to count of dwords in temps
                                  // Always at least 4 (nbytes, EIP, ESI,and EDI).
        rep                     ;
        movsd                   ;
        jmp     done            ;

    Aoverflow:
        // Overflowed the stack.  Return null
        xor     EAX,EAX         ;

    done:
        pop     ESI             ;
        pop     EDI             ;
        pop     EBX             ;
        ret                     ;
    }
}
