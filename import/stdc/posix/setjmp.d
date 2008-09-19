/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module stdc.posix.setjmp;

private import stdc.posix.config;
private import stdc.posix.signal; // for sigset_t

extern (C):

//
// Required
//
/*
jmp_buf

int  setjmp(jmp_buf);
void longjmp(jmp_buf, int);
*/

version( linux )
{
    version( X86_64 )
    {
        //const JB_BX     = 0;
        //const JB_BP     = 1;
        //const JB_12     = 2;
        //const JB_13     = 3;
        //const JB_14     = 4;
        //const JB_15     = 5;
        //const JB_SP     = 6;
        //const JB_PC     = 7;
        //const JB_SIZE   = 64;

        alias long[8] __jmp_buf;
    }
    else version( X86 )
    {
        //const JB_BX     = 0;
        //const JB_SI     = 1;
        //const JB_DI     = 2;
        //const JB_BP     = 3;
        //const JB_SP     = 4;
        //const JB_PC     = 5;
        //const JB_SIZE   = 24;

        alias int[6] __jmp_buf;
    }
    else version ( SPARC )
    {
        alias int[3] __jmp_buf;
    }

    struct __jmp_buf_tag
    {
        __jmp_buf   __jmpbuf;
        int         __mask_was_saved;
        sigset_t    __saved_mask;
    }

    alias __jmp_buf_tag[1] jmp_buf;

    alias _setjmp setjmp; // see XOpen block
    void longjmp(jmp_buf, int);
}

//
// C Extension (CX)
//
/*
sigjmp_buf

int  sigsetjmp(sigjmp_buf, int);
void siglongjmp(sigjmp_buf, int);
*/

version( linux )
{
    alias jmp_buf sigjmp_buf;

    int __sigsetjmp(sigjmp_buf, int);
    alias __sigsetjmp sigsetjmp;
    void siglongjmp(sigjmp_buf, int);
}

//
// XOpen (XSI)
//
/*
int  _setjmp(jmp_buf);
void _longjmp(jmp_buf, int);
*/

version( linux )
{
    int  _setjmp(jmp_buf);
    void _longjmp(jmp_buf, int);
}
