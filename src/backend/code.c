// Copyright (C) 1987-1998 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if !SPP

#include        <stdio.h>
#include        <time.h>
#include        "cc.h"
#include        "el.h"
#include        "code.h"
#include        "global.h"

static code *code_list;

/*****************
 * Allocate code
 */

#if SCPP && __SC__ && __INTSIZE == 4 && TX86 && !_DEBUG_TRACE && !MEM_DEBUG

__declspec(naked) code *code_calloc()
{
    if (sizeof(code) != 0x28)
        util_assert("code",__LINE__);
    __asm
    {
        mov     EAX,code_list
        test    EAX,EAX
        je      L20
        mov     ECX,[EAX]
        mov     code_list,ECX
        jmp     L29

L20:    push    sizeof(code)
        call    mem_fmalloc
        ;add    ESP,4
L29:
        xor     ECX,ECX
        mov     DWORD PTR [EAX],0

        mov     4[EAX],ECX      ;these pair
        mov     8[EAX],ECX

        mov     12[EAX],ECX
        mov     16[EAX],ECX

        mov     20[EAX],ECX
        mov     24[EAX],ECX

        mov     28[EAX],ECX
        mov     32[EAX],ECX

        mov     36[EAX],ECX

        ret
    }
}

#else

code *code_calloc()
{   code *c;
    static code czero;

    //printf("code %x\n", sizeof(code));
    c = code_list;
    if (c)
        code_list = code_next(c);
    else
        c = (code *)mem_fmalloc(sizeof(*c));
    *c = czero;                         // zero it out
    //dbg_printf("code_calloc: %p\n",c);
    return c;
}

#endif

/*****************
 * Free code
 */

void code_free(code *cstart)
{   code **pc;
    code *c;

    for (pc = &cstart; (c = *pc) != NULL; pc = &code_next(c))
    {
        if (c->Iop == ASM)
        {
            mem_free(c->IEV1.as.bytes);
        }
    }
    *pc = code_list;
    code_list = cstart;
}

/*****************
 * Terminate code
 */

void code_term()
{
#if TERMCODE
    code *cn;
    int count = 0;

    while (code_list)
    {   cn = code_next(code_list);
        mem_ffree(code_list);
        code_list = cn;
        count++;
    }
#ifdef DEBUG
    printf("Max # of codes = %d\n",count);
#endif
#else
#ifdef DEBUG
    int count = 0;

    for (code *cn = code_list; cn; cn = code_next(cn))
        count++;
    printf("Max # of codes = %d\n",count);
#endif
#endif
}

#endif // !SPP
