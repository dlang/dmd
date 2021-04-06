/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/util2.d, backend/util2.d)
 */

// Only used for DMD

module dmd.backend.util2;

// Utility subroutines

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.stdint : uint64_t;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.global;
import dmd.backend.mem;

extern (C++):

nothrow:
@safe:

void *ph_malloc(size_t nbytes);
void *ph_calloc(size_t nbytes);
void ph_free(void *p);
void *ph_realloc(void *p , size_t nbytes);

extern (C) void printInternalFailure(FILE* stream); // from dmd/mars.d


void file_progress()
{
}

/*******************************
 * Alternative assert failure.
 */
@trusted
void util_assert(const(char)* file, int line)
{
    fflush(stdout);
    printInternalFailure(stdout);
    printf("Internal error: %s %d\n",file,line);
    err_exit();
//#if __clang__
//    __builtin_unreachable();
//#endif
}

/****************************
 * Clean up and exit program.
 */

void err_exit()
{
    util_exit(EXIT_FAILURE);
}

/********************************
 * Clean up and exit program.
 */

void err_break()
{
    util_exit(255);
}


/****************************
 * Clean up and exit program.
 */
@trusted
void util_exit(int exitcode)
{
    exit(exitcode);                     /* terminate abnormally         */
}

version (CRuntime_DigitalMars)
{

extern (C) extern __gshared int controlc_saw;

/********************************
 * Control C interrupts go here.
 */
@trusted
private extern (C) void controlc_handler()
{
    //printf("saw controlc\n");
    controlc_saw = 1;
}

/*********************************
 * Trap control C interrupts.
 */

version (MARS) { } else
{

extern (C)
{
void controlc_open();
void controlc_close();
alias _controlc_handler_t = void function();
extern __gshared _controlc_handler_t _controlc_handler;

void _STI_controlc()
{
    //printf("_STI_controlc()\n");
    _controlc_handler = &controlc_handler;
    controlc_open();                    /* trap control C               */
}

void _STD_controlc()
{
    //printf("_STD_controlc()\n");
    controlc_close();
}
}

}
}

/***********************************
 * Send progress report.
 */

void util_progress()
{
    version (MARS) { } else {
    version (CRuntime_DigitalMars)
    {
        if (controlc_saw)
            err_break();
    }
    }
}

void util_progress(int linnum)
{
    version (MARS) { } else {
    version (CRuntime_DigitalMars)
    {
        if (controlc_saw)
            err_break();
    }
    }
}


/**********************************
 * Binary string search.
 * Input:
 *      p .    string of characters
 *      tab     array of pointers to strings
 *      n =     number of pointers in the array
 * Returns:
 *      index (0..n-1) into tab[] if we found a string match
 *      else -1
 */

version (X86) version (CRuntime_DigitalMars)
    version = X86asm;

@trusted
int binary(const(char)* p, const(char)*  *table,int high)
{
version (X86asm)
{
    alias len = high;        // reuse parameter storage
    asm nothrow
    {

// First find the length of the identifier.
        xor     EAX,EAX         ; // Scan for a 0.
        mov     EDI,p           ;
        mov     ECX,EAX         ;
        dec     ECX             ; // Longest possible string.
        repne                   ;
        scasb                   ;
        mov     EDX,high        ; // EDX = high
        not     ECX             ; // length of the id including '/0', stays in ECX
        dec     EDX             ; // high--
        js      short Lnotfound ;
        dec     EAX             ; // EAX = -1, so that eventually EBX = low (0)
        mov     len,ECX         ;

        even                    ;
L4D:    lea     EBX,[EAX + 1]   ; // low = mid + 1
        cmp     EBX,EDX         ;
        jg      Lnotfound       ;

        even                    ;
L15:    lea     EAX,[EBX + EDX] ; // EAX = low + high

// Do the string compare.

        mov     EDI,table       ;
        sar     EAX,1           ; // mid = (low + high) >> 1
        mov     ESI,p           ;
        mov     EDI,[4*EAX+EDI] ; // Load table[mid]
        mov     ECX,len         ; // length of id
        repe                    ;
        cmpsb                   ;

        je      short L63       ; // return mid if equal
        jns     short L4D       ; // if (cond < 0)
        lea     EDX,-1[EAX]     ; // high = mid - 1
        cmp     EBX,EDX         ;
        jle     L15             ;

Lnotfound:
        mov     EAX,-1          ; // Return -1.

        even                    ;
L63:                            ;
    }
}
else
{
    int low = 0;
    char cp = *p;
    high--;
    p++;

    while (low <= high)
    {
        int mid = (low + high) >> 1;
        int cond = table[mid][0] - cp;
        if (cond == 0)
            cond = strcmp(table[mid] + 1,p);
        if (cond > 0)
            high = mid - 1;
        else if (cond < 0)
            low = mid + 1;
        else
            return mid;                 /* match index                  */
    }
    return -1;
}
}


// search table[0 .. high] for p[0 .. len] (where p.length not necessairily equal to len)
@trusted
int binary(const(char)* p, size_t len, const(char)** table, int high)
{
    int low = 0;
    char cp = *p;
    high--;
    p++;
    len--;

    while (low <= high)
    {
        int mid = (low + high) >> 1;
        int cond = table[mid][0] - cp;

        if (cond == 0)
        {
            cond = strncmp(table[mid] + 1, p, len);
            if (cond == 0)
                cond = table[mid][len+1]; // same as: if (table[mid][len+1] != '\0') cond = 1;
        }

        if (cond > 0)
            high = mid - 1;
        else if (cond < 0)
            low = mid + 1;
        else
            return mid;                 /* match index                  */
    }
    return -1;
}

/**********************
 * If c is a power of 2, return that power else -1.
 */

int ispow2(uint64_t c)
{       int i;

        if (c == 0 || (c & (c - 1)))
            i = -1;
        else
            for (i = 0; c >>= 1; i++)
            { }
        return i;
}

/***************************
 */

enum UTIL_PH = true;

version (MEM_DEBUG)
    enum MEM_DEBUG = false; //true;
else
    enum MEM_DEBUG = false;

version (Windows)
{
void *util_malloc(uint n,uint size)
{
static if (MEM_DEBUG)
{
    void *p;

    p = mem_malloc(n * size);
    //dbg_printf("util_calloc(%d) = %p\n",n * size,p);
    return p;
}
else static if (UTIL_PH)
{
    return ph_malloc(n * size);
}
else
{
    size_t nbytes = cast(size_t)n * cast(size_t)size;
    void *p = malloc(nbytes);
    if (!p && nbytes)
        err_nomem();
    return p;
}
}
}

/***************************
 */

version (Windows)
{
void *util_calloc(uint n,uint size)
{
static if (MEM_DEBUG)
{
    void *p;

    p = mem_calloc(n * size);
    //dbg_printf("util_calloc(%d) = %p\n",n * size,p);
    return p;
}
else static if (UTIL_PH)
{
    return ph_calloc(n * size);
}
else
{
    size_t nbytes = cast(size_t) n * cast(size_t) size;
    void *p = calloc(n,size);
    if (!p && nbytes)
        err_nomem();
    return p;
}
}
}

/***************************
 */

version (Windows)
{
void util_free(void *p)
{
    //dbg_printf("util_free(%p)\n",p);
static if (MEM_DEBUG)
{
    mem_free(p);
}
else static if (UTIL_PH)
{
    ph_free(p);
}
else
{
    free(p);
}
}
}

/***************************
 */

version (Windows)
{
void *util_realloc(void *oldp,size_t n,size_t size)
{
static if (MEM_DEBUG)
{
    //dbg_printf("util_realloc(%p,%d)\n",oldp,n * size);
    return mem_realloc(oldp,n * size);
}
else static if (UTIL_PH)
{
    return ph_realloc(oldp,n * size);
}
else
{
    const nbytes = n * size;
    void *p = realloc(oldp,nbytes);
    if (!p && nbytes)
        err_nomem();
    return p;
}
}
}

/*****************************
 */
void *mem_malloc2(uint size)
{
    return mem_malloc(size);
}
