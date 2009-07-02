/**
 * Implementation of exception handling support routines for Windows.
 *
 * Copyright: Copyright Digital Mars 1999 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt>Boost License 1.0</a>.
 * Authors:   Walter Bright
 *
 *          Copyright Digital Mars 1999 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
#include        <stdio.h>
#include        <string.h>
#include        <assert.h>
#include        <stdlib.h>

/* ======================== Win32 =============================== */

#if _WIN32

#include        <excpt.h>
#include        <windows.h>

//#include      "\sc\src\include\ehsup.h"

/*** From Digital Mars C runtime library ***/
EXCEPTION_DISPOSITION __cdecl _local_except_handler (EXCEPTION_RECORD *ExceptionRecord,
    void* EstablisherFrame,
        void *ContextRecord,
        void *DispatcherContext
        );
void __cdecl _global_unwind(void *frame,EXCEPTION_RECORD *eRecord);
#define EXCEPTION_UNWIND  6  // Flag to indicate if the system is unwinding

extern DWORD _except_list;
/*** ***/

#include        "mars.h"

extern ClassInfo D6object9Throwable7__ClassZ;
#define _Class_9Throwable D6object9Throwable7__ClassZ;

extern ClassInfo D6object5Error7__ClassZ;
#define _Class_5Error D6object5Error7__ClassZ

typedef int (__pascal *fp_t)();   // function pointer in ambient memory model

// The layout of DEstablisherFrame is the same for C++

struct DEstablisherFrame
{
    void *prev;                 // pointer to previous exception list
    void *handler;              // pointer to routine for exception handler
    DWORD table_index;          // current index into handler_info[]
    DWORD ebp;                  // this is EBP of routine
};

struct DHandlerInfo
{
    int prev_index;             // previous table index
    unsigned cioffset;          // offset to DCatchInfo data from start of table (!=0 if try-catch)
    void *finally_code;         // pointer to finally code to execute
                                // (!=0 if try-finally)
};

// Address of DHandlerTable is passed in EAX to _d_framehandler()

struct DHandlerTable
{
    void *fptr;                 // pointer to start of function
    unsigned espoffset;         // offset of ESP from EBP
    unsigned retoffset;         // offset from start of function to return code
    struct DHandlerInfo handler_info[1];
};

struct DCatchBlock
{
    ClassInfo *type;            // catch type
    unsigned bpoffset;          // EBP offset of catch var
    void *code;                 // catch handler code
};

// Create one of these for each try-catch
struct DCatchInfo
{
    unsigned ncatches;                  // number of catch blocks
    struct DCatchBlock catch_block[1];  // data for each catch block
};

// Macro to make our own exception code
#define MAKE_EXCEPTION_CODE(severity, facility, exception)      \
        (((severity) << 30) | (1 << 29) | (0 << 28) | ((facility) << 16) | (exception))

#define STATUS_DIGITAL_MARS_D_EXCEPTION         MAKE_EXCEPTION_CODE(3,'D',1)

Object *_d_translate_se_to_d_exception(EXCEPTION_RECORD *exception_record);
void __cdecl _d_local_unwind(struct DHandlerTable *handler_table, struct DEstablisherFrame *frame, int stop_index);


/***********************************
 * The frame handler, this is called for each frame that has been registered
 * in the OS except_list.
 * Input:
 *      EAX     the handler table for the frame
 */

EXCEPTION_DISPOSITION _d_framehandler(
            EXCEPTION_RECORD *exception_record,
            struct DEstablisherFrame *frame,
            CONTEXT context,
            void *dispatcher_context)
{
    struct DHandlerTable *handler_table;

    __asm { mov handler_table,EAX }

    if (exception_record->ExceptionFlags & EXCEPTION_UNWIND)
    {
         // Call all the finally blocks in this frame
         _d_local_unwind(handler_table, frame, -1);
    }
    else
    {
        // Jump to catch block if matching one is found

        int ndx,prev_ndx,i;
        struct DHandlerInfo *phi;
        struct DCatchInfo *pci;
        struct DCatchBlock *pcb;
        unsigned ncatches;              // number of catches in the current handler
        Object *pti;
        ClassInfo *ci;

        ci = NULL;                      // only compute it if we need it

        // walk through handler table, checking each handler
        // with an index smaller than the current table_index
        for (ndx = frame->table_index; ndx != -1; ndx = prev_ndx)
        {
            phi = &handler_table->handler_info[ndx];
            prev_ndx = phi->prev_index;
            if (phi->cioffset)
            {
                // this is a catch handler (no finally)
                pci = (struct DCatchInfo *)((char *)handler_table + phi->cioffset);
                ncatches = pci->ncatches;
                for (i = 0; i < ncatches; i++)
                {
                    pcb = &pci->catch_block[i];

                    if (!ci)
                    {
                        // This code must match the translation code
                        if (exception_record->ExceptionCode == STATUS_DIGITAL_MARS_D_EXCEPTION)
                        {
                            //printf("ei[0] = %p\n", exception_record->ExceptionInformation[0]);
                            ci = **(ClassInfo ***)(exception_record->ExceptionInformation[0]);
                        }
                        else
                            ci = &_Class_9Throwable;
                    }

                    if (_d_isbaseof(ci, pcb->type))
                    {
                        // Matched the catch type, so we've found the handler.
                        int regebp;

                        pti = _d_translate_se_to_d_exception(exception_record);

                        // Initialize catch variable
                        regebp = (int)&frame->ebp;              // EBP for this frame
                        *(void **)(regebp + (pcb->bpoffset)) = pti;

                        // Have system call all finally blocks in intervening frames
                        _global_unwind(frame, exception_record);

                        // Call all the finally blocks skipped in this frame
                        _d_local_unwind(handler_table, frame, ndx);

                        frame->table_index = prev_ndx;  // we are out of this handler

                        // Jump to catch block. Does not return.
                        {
                            unsigned catch_esp;
                            fp_t catch_addr;

                            catch_addr = (fp_t)(pcb->code);
                            catch_esp = regebp - handler_table->espoffset - sizeof(fp_t);
                            _asm
                            {
                                mov     EAX,catch_esp
                                mov     ECX,catch_addr
                                mov     [EAX],ECX
                                mov     EBP,regebp
                                mov     ESP,EAX         // reset stack
                                ret                     // jump to catch block
                            }
                        }
                    }
                }
            }
        }
    }
    return ExceptionContinueSearch;
}

/***********************************
 * Exception filter for use in __try..__except block
 * surrounding call to Dmain()
 */

int _d_exception_filter(struct _EXCEPTION_POINTERS *eptrs,
                        int retval,
                        Object **exception_object)
{
    *exception_object = _d_translate_se_to_d_exception(eptrs->ExceptionRecord);
    return retval;
}

/***********************************
 * Throw a D object.
 */

void __stdcall _d_throw(Object *h)
{
    //printf("_d_throw(h = %p, &h = %p)\n", h, &h);
    //printf("\tvptr = %p\n", *(void **)h);
    RaiseException(STATUS_DIGITAL_MARS_D_EXCEPTION,
                   EXCEPTION_NONCONTINUABLE,
                   1, (DWORD *)&h);
}

/***********************************
 * Create an exception object
 */

Object *_d_create_exception_object(ClassInfo *ci, char *msg)
{
    Throwable *exc;

    exc = (Throwable *)_d_newclass(ci);
    // BUG: what if _d_newclass() throws an out of memory exception?

    if (msg)
    {
        exc->msglen = strlen(msg);
        exc->msg = msg;
    }
    return (Object *)exc;
}

/***********************************
 * Converts a Windows Structured Exception code to a D Exception Object.
 */

Object *_d_translate_se_to_d_exception(EXCEPTION_RECORD *exception_record)
{
    Object *pti;

    switch (exception_record->ExceptionCode) {
        case STATUS_DIGITAL_MARS_D_EXCEPTION:
            // Generated D exception
            pti = (Object *)(exception_record->ExceptionInformation[0]);
            break;

        case STATUS_INTEGER_DIVIDE_BY_ZERO:
            pti = _d_create_exception_object(&_Class_5Error, "Integer Divide by Zero");
            break;

        case STATUS_FLOAT_DIVIDE_BY_ZERO:
            pti = _d_create_exception_object(&_Class_5Error, "Float Divide by Zero");
            break;

        case STATUS_ACCESS_VIOLATION:
            pti = _d_create_exception_object(&_Class_5Error, "Access Violation");
            break;

        case STATUS_STACK_OVERFLOW:
            pti = _d_create_exception_object(&_Class_5Error, "Stack Overflow");
            break;

        case STATUS_DATATYPE_MISALIGNMENT:
            pti = _d_create_exception_object(&_Class_5Error, "Datatype Misalignment");
            break;

        case STATUS_ARRAY_BOUNDS_EXCEEDED:
            pti = _d_create_exception_object(&_Class_5Error, "Array Bounds Exceeded");
            break;

        case STATUS_FLOAT_INVALID_OPERATION:
            pti = _d_create_exception_object(&_Class_5Error, "Invalid Floating Point Operation");
            break;

        case STATUS_FLOAT_DENORMAL_OPERAND:
            pti = _d_create_exception_object(&_Class_5Error, "Floating Point Denormal Operand");
            break;

        case STATUS_FLOAT_INEXACT_RESULT:
            pti = _d_create_exception_object(&_Class_5Error, "Floating Point Inexact Result");
            break;

        case STATUS_FLOAT_OVERFLOW:
            pti = _d_create_exception_object(&_Class_5Error, "Floating Point Overflow");
            break;

        case STATUS_FLOAT_UNDERFLOW:
            pti = _d_create_exception_object(&_Class_5Error, "Floating Point Underflow");
            break;

        case STATUS_FLOAT_STACK_CHECK:
            pti = _d_create_exception_object(&_Class_5Error, "Floating Point Stack Check");
            break;

        case STATUS_PRIVILEGED_INSTRUCTION:
            if (*((unsigned char *)(exception_record->ExceptionAddress))==0xF4) { // HLT
                pti = _d_create_exception_object(&_Class_5Error, "assert(0) or HLT instruction");
            } else {
                pti = _d_create_exception_object(&_Class_5Error, "Privileged Instruction");
            }
            break;

        case STATUS_ILLEGAL_INSTRUCTION:
            pti = _d_create_exception_object(&_Class_5Error, "Illegal Instruction");
            break;

        case STATUS_BREAKPOINT:
            pti = _d_create_exception_object(&_Class_5Error, "Breakpoint");
            break;

        case STATUS_IN_PAGE_ERROR:
            pti = _d_create_exception_object(&_Class_5Error, "Win32 In Page Exception");
            break;
/*
        case STATUS_INTEGER_OVERFLOW: // not supported on any x86 processor
        case STATUS_INVALID_DISPOSITION:
        case STATUS_NONCONTINUABLE_EXCEPTION:
        case STATUS_SINGLE_STEP:
		case DBG_CONTROL_C: // only when a debugger is attached
        // In DMC, but not in Microsoft docs
        case STATUS_GUARD_PAGE_VIOLATION:
        case STATUS_INVALID_HANDLE:
*/
        // convert all other exception codes into a Win32Exception
        default:
            pti = _d_create_exception_object(&_Class_5Error, "Win32 Exception");
            break;
    }

    return pti;
}

/**************************************
 * Call finally blocks in the current stack frame until stop_index.
 * This is roughly equivalent to _local_unwind() for C in \src\win32\ehsup.c
 */

void __cdecl _d_local_unwind(struct DHandlerTable *handler_table,
        struct DEstablisherFrame *frame, int stop_index)
{
    struct DHandlerInfo *phi;
    struct DCatchInfo *pci;
    int i;

    // Set up a special exception handler to catch double-fault exceptions.
    __asm
    {
        push    dword ptr -1
        push    dword ptr 0
        push    offset _local_except_handler    // defined in src\win32\ehsup.c
        push    dword ptr fs:_except_list
        mov     FS:_except_list,ESP
    }

    for (i = frame->table_index; i != -1 && i != stop_index; i = phi->prev_index)
    {
        phi = &handler_table->handler_info[i];
        if (phi->finally_code)
        {
            // Note that it is unnecessary to adjust the ESP, as the finally block
            // accesses all items on the stack as relative to EBP.

            DWORD *catch_ebp = &frame->ebp;
            void *blockaddr = phi->finally_code;

            _asm
            {
                push    EBX
                mov     EBX,blockaddr
                push    EBP
                mov     EBP,catch_ebp
                call    EBX
                pop     EBP
                pop     EBX
            }
        }
    }

    _asm
    {
        pop     FS:_except_list
        add     ESP,12
    }
}

/***********************************
 * external version of the unwinder
 */

__declspec(naked) void __cdecl _d_local_unwind2()
{
    __asm
    {
        jmp     _d_local_unwind
    }
}

/***********************************
 * The frame handler, this is called for each frame that has been registered
 * in the OS except_list.
 * Input:
 *      EAX     the handler table for the frame
 */

EXCEPTION_DISPOSITION _d_monitor_handler(
            EXCEPTION_RECORD *exception_record,
            struct DEstablisherFrame *frame,
            CONTEXT context,
            void *dispatcher_context)
{
    if (exception_record->ExceptionFlags & EXCEPTION_UNWIND)
    {
        _d_monitorexit((Object *)frame->table_index);
    }
    else
    {
    }
    return ExceptionContinueSearch;
}

/***********************************
 */

void _d_monitor_prolog(void *x, void *y, Object *h)
{
    __asm
    {
        push    EAX
    }
    //printf("_d_monitor_prolog(x=%p, y=%p, h=%p)\n", x, y, h);
    _d_monitorenter(h);
    __asm
    {
        pop     EAX
    }
}

/***********************************
 */

void _d_monitor_epilog(void *x, void *y, Object *h)
{
    //printf("_d_monitor_epilog(x=%p, y=%p, h=%p)\n", x, y, h);
    __asm
    {
        push    EAX
        push    EDX
    }
    _d_monitorexit(h);
    __asm
    {
        pop     EDX
        pop     EAX
    }
}

#endif

/* ======================== linux =============================== */

#if linux

#include        "mars.h"

extern ClassInfo D6object9Throwable7__ClassZ;
#define _Class_9Throwable D6object9Throwable7__ClassZ;

extern ClassInfo D6object5Error7__ClassZ;
#define _Class_5Error D6object5Error7__ClassZ

typedef int (*fp_t)();   // function pointer in ambient memory model

struct DHandlerInfo
{
    unsigned offset;            // offset from function address to start of guarded section
    int prev_index;             // previous table index
    unsigned cioffset;          // offset to DCatchInfo data from start of table (!=0 if try-catch)
    void *finally_code;         // pointer to finally code to execute
                                // (!=0 if try-finally)
};

// Address of DHandlerTable, searched for by eh_finddata()

struct DHandlerTable
{
    void *fptr;                 // pointer to start of function
    unsigned espoffset;         // offset of ESP from EBP
    unsigned retoffset;         // offset from start of function to return code
    unsigned nhandlers;         // dimension of handler_info[]
    struct DHandlerInfo handler_info[1];
};

struct DCatchBlock
{
    ClassInfo *type;            // catch type
    unsigned bpoffset;          // EBP offset of catch var
    void *code;                 // catch handler code
};

// Create one of these for each try-catch
struct DCatchInfo
{
    unsigned ncatches;                  // number of catch blocks
    struct DCatchBlock catch_block[1];  // data for each catch block
};

// One of these is generated for each function with try-catch or try-finally

struct FuncTable
{
    void *fptr;                 // pointer to start of function
    struct DHandlerTable *handlertable; // eh data for this function
    unsigned size;              // size of function in bytes
};

extern struct FuncTable *table_start;
extern struct FuncTable *table_end;

void terminate()
{
//    _asm
//    {
//      hlt
//    }
}

/*******************************************
 * Given address that is inside a function,
 * figure out which function it is in.
 * Return DHandlerTable if there is one, NULL if not.
 */

struct DHandlerTable *__eh_finddata(void *address)
{
    struct FuncTable *ft;

    for (ft = (struct FuncTable *)table_start;
         ft < (struct FuncTable *)table_end;
         ft++)
    {
        if (ft->fptr <= address &&
            address < (void *)((char *)ft->fptr + ft->size))
        {
            return ft->handlertable;
        }
    }
    return NULL;
}


/******************************
 * Given EBP, find return address to caller, and caller's EBP.
 * Input:
 *   regbp       Value of EBP for current function
 *   *pretaddr   Return address
 * Output:
 *   *pretaddr   return address to caller
 * Returns:
 *   caller's EBP
 */

unsigned __eh_find_caller(unsigned regbp, unsigned *pretaddr)
{
    unsigned bp = *(unsigned *)regbp;

    if (bp)         // if not end of call chain
    {
        // Perform sanity checks on new EBP.
        // If it is screwed up, terminate() hopefully before we do more damage.
        if (bp <= regbp)
            // stack should grow to smaller values
            terminate();

        *pretaddr = *(unsigned *)(regbp + sizeof(int));
    }
    return bp;
}

/***********************************
 * Throw a D object.
 */

void __stdcall _d_throw(Object *h)
{
    unsigned regebp;

    //printf("_d_throw(h = %p, &h = %p)\n", h, &h);
    //printf("\tvptr = %p\n", *(void **)h);

    regebp = _EBP;

    while (1)           // for each function on the stack
    {
        struct DHandlerTable *handler_table;
        struct FuncTable *pfunc;
        struct DHandlerInfo *phi;
        unsigned retaddr;
        unsigned funcoffset;
        unsigned spoff;
        unsigned retoffset;
        int index;
        int dim;
        int ndx;
        int prev_ndx;

        regebp = __eh_find_caller(regebp,&retaddr);
        if (!regebp)
            // if end of call chain
            break;

        handler_table = __eh_finddata((void *)retaddr);   // find static data associated with function
        if (!handler_table)         // if no static data
        {
            continue;
        }
        funcoffset = (unsigned)handler_table->fptr;
        spoff = handler_table->espoffset;
        retoffset = handler_table->retoffset;

#ifdef DEBUG
        printf("retaddr = x%x\n",(unsigned)retaddr);
        printf("regebp=x%04x, funcoffset=x%04x, spoff=x%x, retoffset=x%x\n",
        regebp,funcoffset,spoff,retoffset);
#endif

        // Find start index for retaddr in static data
        dim = handler_table->nhandlers;
        index = -1;
        for (int i = 0; i < dim; i++)
        {
            phi = &handler_table->handler_info[i];

            if ((unsigned)retaddr >= funcoffset + phi->offset)
                index = i;
        }

        // walk through handler table, checking each handler
        // with an index smaller than the current table_index
        for (ndx = index; ndx != -1; ndx = prev_ndx)
        {
            phi = &handler_table->handler_info[ndx];
            prev_ndx = phi->prev_index;
            if (phi->cioffset)
            {
                // this is a catch handler (no finally)
                struct DCatchInfo *pci;
                int ncatches;
                int i;

                pci = (struct DCatchInfo *)((char *)handler_table + phi->cioffset);
                ncatches = pci->ncatches;
                for (i = 0; i < ncatches; i++)
                {
                    struct DCatchBlock *pcb;
                    ClassInfo *ci = **(ClassInfo ***)h;

                    pcb = &pci->catch_block[i];

                    if (_d_isbaseof(ci, pcb->type))
                    {   // Matched the catch type, so we've found the handler.

                        // Initialize catch variable
                        *(void **)(regebp + (pcb->bpoffset)) = h;

                        // Jump to catch block. Does not return.
                        {
                            unsigned catch_esp;
                            fp_t catch_addr;

                            catch_addr = (fp_t)(pcb->code);
                            catch_esp = regebp - handler_table->espoffset - sizeof(fp_t);
                            _asm
                            {
                                mov     EAX,catch_esp
                                mov     ECX,catch_addr
                                mov     [EAX],ECX
                                mov     EBP,regebp
                                mov     ESP,EAX         // reset stack
                                ret                     // jump to catch block
                            }
                        }
                    }
                }
            }
            else if (phi->finally_code)
            {   // Call finally block
                // Note that it is unnecessary to adjust the ESP, as the finally block
                // accesses all items on the stack as relative to EBP.

                void *blockaddr = phi->finally_code;

                _asm
                {
                    push        EBX
                    mov         EBX,blockaddr
                    push        EBP
                    mov         EBP,regebp
                    call        EBX
                    pop         EBP
                    pop         EBX
                }
            }
        }
    }
}


#endif
