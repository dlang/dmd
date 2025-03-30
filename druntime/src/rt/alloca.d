/**
 * Implementation of alloca() standard C routine.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright
 * Source: $(DRUNTIMESRC rt/_alloca.d)
 */

module rt.alloca;

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
  version (D_InlineAsm_X86)
  {
    asm
    {
        naked                   ;
        mov     EDX,ECX         ;
        mov     EAX,4[ESP]      ; // get nbytes
        push    EBX             ;
        push    EDI             ;
        push    ESI             ;

        add     EAX,15          ;
        and     EAX,0xFFFFFFF0  ; // round up to 16 byte boundary
        jnz     Abegin          ;
        mov     EAX,16          ; // minimum allocation is 16
    Abegin:
        mov     ESI,EAX         ; // ESI = nbytes
        neg     EAX             ;
        add     EAX,ESP         ; // EAX is now what the new ESP will be.
        jae     Aoverflow       ;
    }
    version (Win32)
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
  else version (D_InlineAsm_X86_64)
  {
    version (Win64)
    {
    asm
    {
        /* RCX     nbytes
         * RDX     address of variable with # of bytes in locals
         * Must save registers RBX,RDI,RSI,R12..R15
         */
        naked                   ;
        push    RBX             ;
        push    RDI             ;
        push    RSI             ;
        mov     RAX,RCX         ; // get nbytes
        add     RAX,15          ;
        and     AL,0xF0         ; // round up to 16 byte boundary
        test    RAX,RAX         ;
        jnz     Abegin          ;
        mov     RAX,16          ; // allow zero bytes allocation
    Abegin:
        mov     RSI,RAX         ; // RSI = nbytes
        neg     RAX             ;
        add     RAX,RSP         ; // RAX is now what the new RSP will be.
        jae     Aoverflow       ;

        // We need to be careful about the guard page
        // Thus, for every 4k page, touch it to cause the OS to load it in.
        mov     RCX,RAX         ; // RCX is new location for stack
        mov     RBX,RSI         ; // RBX is size to "grow" stack
    L1:
        test    [RCX+RBX],RBX   ; // bring in page
        sub     RBX,0x1000      ; // next 4K page down
        jae     L1              ; // if more pages
        test    [RCX],RBX       ; // bring in last page

        // Copy down to [RSP] the temps on the stack.
        // The number of temps is (RBP - RSP - locals).
        mov     RCX,RBP         ;
        sub     RCX,RSP         ;
        sub     RCX,[RDX]       ; // RCX = number of temps (bytes) to move.
        add     [RDX],RSI       ; // adjust locals by nbytes for next call to alloca()
        mov     RSP,RAX         ; // Set up new stack pointer.
        add     RAX,RCX         ; // Return value = RSP + temps.
        mov     RDI,RSP         ; // Destination of copy of temps.
        add     RSI,RSP         ; // Source of copy.
        shr     RCX,3           ; // RCX to count of qwords in temps
        rep                     ;
        movsq                   ;
        jmp     done            ;

    Aoverflow:
        // Overflowed the stack.  Return null
        xor     RAX,RAX         ;

    done:
        pop     RSI             ;
        pop     RDI             ;
        pop     RBX             ;
        ret                     ;
    }
    }
    else
    {
    asm
    {
        /* Parameter is passed in RDI
         * Must save registers RBX,R12..R15
         */
        naked                   ;
        mov     RDX,RCX         ;
        mov     RAX,RDI         ; // get nbytes
        add     RAX,15          ;
        and     AL,0xF0         ; // round up to 16 byte boundary
        test    RAX,RAX         ;
        jnz     Abegin          ;
        mov     RAX,16          ; // allow zero bytes allocation
    Abegin:
        mov     RSI,RAX         ; // RSI = nbytes
        neg     RAX             ;
        add     RAX,RSP         ; // RAX is now what the new RSP will be.
        jae     Aoverflow       ;

        // Copy down to [RSP] the temps on the stack.
        // The number of temps is (RBP - RSP - locals).
        mov     RCX,RBP         ;
        sub     RCX,RSP         ;
        sub     RCX,[RDX]       ; // RCX = number of temps (bytes) to move.
        add     [RDX],RSI       ; // adjust locals by nbytes for next call to alloca()
        mov     RSP,RAX         ; // Set up new stack pointer.
        add     RAX,RCX         ; // Return value = RSP + temps.
        mov     RDI,RSP         ; // Destination of copy of temps.
        add     RSI,RSP         ; // Source of copy.
        shr     RCX,3           ; // RCX to count of qwords in temps
        rep                     ;
        movsq                   ;
        jmp     done            ;

    Aoverflow:
        // Overflowed the stack.  Return null
        xor     RAX,RAX         ;

    done:
        ret                     ;
    }
    }
  }
  else
        static assert(0);
}
