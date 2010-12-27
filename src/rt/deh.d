/**
 * Implementation of exception handling support routines for Windows.
 *
 * Copyright: Copyright Digital Mars 1999 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */
 
/*          Copyright Digital Mars 1999 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.deh;
import core.sys.windows.windows;
//import core.stdc.stdio;

enum EXCEPTION_DISPOSITION {
    ExceptionContinueExecution,
    ExceptionContinueSearch,
    ExceptionNestedException,
    ExceptionCollidedUnwind
}

enum {
    EXCEPTION_EXECUTE_HANDLER    = 1,
    EXCEPTION_CONTINUE_SEARCH    = 0,
    EXCEPTION_CONTINUE_EXECUTION = -1
}

extern(Windows)
{
void RaiseException(DWORD, DWORD, DWORD, void *);
}

// used in EXCEPTION_RECORD
enum : DWORD {
	STATUS_WAIT_0                      = 0,
	STATUS_ABANDONED_WAIT_0            = 0x00000080,
	STATUS_USER_APC                    = 0x000000C0,
	STATUS_TIMEOUT                     = 0x00000102,
	STATUS_PENDING                     = 0x00000103,

	STATUS_SEGMENT_NOTIFICATION        = 0x40000005,
	STATUS_GUARD_PAGE_VIOLATION        = 0x80000001,
	STATUS_DATATYPE_MISALIGNMENT       = 0x80000002,
	STATUS_BREAKPOINT                  = 0x80000003,
	STATUS_SINGLE_STEP                 = 0x80000004,

	STATUS_ACCESS_VIOLATION            = 0xC0000005,
	STATUS_IN_PAGE_ERROR               = 0xC0000006,
	STATUS_INVALID_HANDLE              = 0xC0000008,

	STATUS_NO_MEMORY                   = 0xC0000017,
	STATUS_ILLEGAL_INSTRUCTION         = 0xC000001D,
	STATUS_NONCONTINUABLE_EXCEPTION    = 0xC0000025,
	STATUS_INVALID_DISPOSITION         = 0xC0000026,
	STATUS_ARRAY_BOUNDS_EXCEEDED       = 0xC000008C,
	STATUS_FLOAT_DENORMAL_OPERAND      = 0xC000008D,
	STATUS_FLOAT_DIVIDE_BY_ZERO        = 0xC000008E,
	STATUS_FLOAT_INEXACT_RESULT        = 0xC000008F,
	STATUS_FLOAT_INVALID_OPERATION     = 0xC0000090,
	STATUS_FLOAT_OVERFLOW              = 0xC0000091,
	STATUS_FLOAT_STACK_CHECK           = 0xC0000092,
	STATUS_FLOAT_UNDERFLOW             = 0xC0000093,
	STATUS_INTEGER_DIVIDE_BY_ZERO      = 0xC0000094,
	STATUS_INTEGER_OVERFLOW            = 0xC0000095,
	STATUS_PRIVILEGED_INSTRUCTION      = 0xC0000096,
	STATUS_STACK_OVERFLOW              = 0xC00000FD,
	STATUS_CONTROL_C_EXIT              = 0xC000013A,
	STATUS_DLL_INIT_FAILED             = 0xC0000142,
	STATUS_DLL_INIT_FAILED_LOGOFF      = 0xC000026B,

	CONTROL_C_EXIT                     = STATUS_CONTROL_C_EXIT,

	EXCEPTION_ACCESS_VIOLATION         = STATUS_ACCESS_VIOLATION,
	EXCEPTION_DATATYPE_MISALIGNMENT    = STATUS_DATATYPE_MISALIGNMENT,
	EXCEPTION_BREAKPOINT               = STATUS_BREAKPOINT,
	EXCEPTION_SINGLE_STEP              = STATUS_SINGLE_STEP,
	EXCEPTION_ARRAY_BOUNDS_EXCEEDED    = STATUS_ARRAY_BOUNDS_EXCEEDED,
	EXCEPTION_FLT_DENORMAL_OPERAND     = STATUS_FLOAT_DENORMAL_OPERAND,
	EXCEPTION_FLT_DIVIDE_BY_ZERO       = STATUS_FLOAT_DIVIDE_BY_ZERO,
	EXCEPTION_FLT_INEXACT_RESULT       = STATUS_FLOAT_INEXACT_RESULT,
	EXCEPTION_FLT_INVALID_OPERATION    = STATUS_FLOAT_INVALID_OPERATION,
	EXCEPTION_FLT_OVERFLOW             = STATUS_FLOAT_OVERFLOW,
	EXCEPTION_FLT_STACK_CHECK          = STATUS_FLOAT_STACK_CHECK,
	EXCEPTION_FLT_UNDERFLOW            = STATUS_FLOAT_UNDERFLOW,
	EXCEPTION_INT_DIVIDE_BY_ZERO       = STATUS_INTEGER_DIVIDE_BY_ZERO,
	EXCEPTION_INT_OVERFLOW             = STATUS_INTEGER_OVERFLOW,
	EXCEPTION_PRIV_INSTRUCTION         = STATUS_PRIVILEGED_INSTRUCTION,
	EXCEPTION_IN_PAGE_ERROR            = STATUS_IN_PAGE_ERROR,
	EXCEPTION_ILLEGAL_INSTRUCTION      = STATUS_ILLEGAL_INSTRUCTION,
	EXCEPTION_NONCONTINUABLE_EXCEPTION = STATUS_NONCONTINUABLE_EXCEPTION,
	EXCEPTION_STACK_OVERFLOW           = STATUS_STACK_OVERFLOW,
	EXCEPTION_INVALID_DISPOSITION      = STATUS_INVALID_DISPOSITION,
	EXCEPTION_GUARD_PAGE               = STATUS_GUARD_PAGE_VIOLATION,
	EXCEPTION_INVALID_HANDLE           = STATUS_INVALID_HANDLE
}

enum MAXIMUM_SUPPORTED_EXTENSION = 512;
enum size_t EXCEPTION_MAXIMUM_PARAMETERS = 15;
enum DWORD EXCEPTION_NONCONTINUABLE      =  1;

struct FLOATING_SAVE_AREA {
    DWORD    ControlWord;
    DWORD    StatusWord;
    DWORD    TagWord;
    DWORD    ErrorOffset;
    DWORD    ErrorSelector;
    DWORD    DataOffset;
    DWORD    DataSelector;
    BYTE[80] RegisterArea;
    DWORD    Cr0NpxState;
}

struct CONTEXT {
    DWORD ContextFlags;
    DWORD Dr0;
    DWORD Dr1;
    DWORD Dr2;
    DWORD Dr3;
    DWORD Dr6;
    DWORD Dr7;
    FLOATING_SAVE_AREA FloatSave;
    DWORD SegGs;
    DWORD SegFs;
    DWORD SegEs;
    DWORD SegDs;
    DWORD Edi;
    DWORD Esi;
    DWORD Ebx;
    DWORD Edx;
    DWORD Ecx;
    DWORD Eax;
    DWORD Ebp;
    DWORD Eip;
    DWORD SegCs;
    DWORD EFlags;
    DWORD Esp;
    DWORD SegSs;
    BYTE[MAXIMUM_SUPPORTED_EXTENSION] ExtendedRegisters;
}

alias CONTEXT* PCONTEXT, LPCONTEXT;

struct EXCEPTION_RECORD {
	DWORD ExceptionCode;
	DWORD ExceptionFlags;
	EXCEPTION_RECORD* ExceptionRecord;
	PVOID ExceptionAddress;
	DWORD NumberParameters;
	DWORD[EXCEPTION_MAXIMUM_PARAMETERS] ExceptionInformation;
}
alias EXCEPTION_RECORD* PEXCEPTION_RECORD, LPEXCEPTION_RECORD;

struct EXCEPTION_POINTERS {
	PEXCEPTION_RECORD ExceptionRecord;
	PCONTEXT          ContextRecord;
}
alias EXCEPTION_POINTERS* PEXCEPTION_POINTERS, LPEXCEPTION_POINTERS;


extern(C)
{
/*** From Digital Mars C runtime library ***/
EXCEPTION_DISPOSITION _local_except_handler (EXCEPTION_RECORD *ExceptionRecord,
    void* EstablisherFrame,
        void *ContextRecord,
        void *DispatcherContext
        );
void _global_unwind(void *frame,EXCEPTION_RECORD *eRecord);
}
enum EXCEPTION_UNWIND = 6;  // Flag to indicate if the system is unwinding

alias int function() fp_t; // function pointer in ambient memory model

extern(C)
{ 
extern __gshared DWORD _except_list;
}

extern(C)
{
void _d_setUnhandled(Object);
void _d_createTrace(Object);
int _d_isbaseof(ClassInfo b, ClassInfo c);
}

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
    uint cioffset;              // offset to DCatchInfo data from start of table (!=0 if try-catch)
    void *finally_code;         // pointer to finally code to execute
                                // (!=0 if try-finally)
};

// Address of DHandlerTable is passed in EAX to _d_framehandler()

struct DHandlerTable
{
    void *fptr;                 // pointer to start of function
    uint espoffset;         // offset of ESP from EBP
    uint retoffset;         // offset from start of function to return code
    DHandlerInfo handler_info[1];
};

struct DCatchBlock
{
    ClassInfo type;            // catch type
    uint bpoffset;          // EBP offset of catch var
    void *code;                 // catch handler code
};

// Create one of these for each try-catch
struct DCatchInfo
{
    uint ncatches;                  // number of catch blocks
    DCatchBlock catch_block[1];  // data for each catch block
};

// Macro to make our own exception code
template MAKE_EXCEPTION_CODE(int severity, int facility, int exception){
        enum int MAKE_EXCEPTION_CODE = (((severity) << 30) | (1 << 29) | (0 << 28) | ((facility) << 16) | (exception));
}
enum int STATUS_DIGITAL_MARS_D_EXCEPTION = MAKE_EXCEPTION_CODE!(3,'D',1);


/***********************************
 * The frame handler, this is called for each frame that has been registered
 * in the OS except_list.
 * Input:
 *      EAX     the handler table for the frame
 */
extern(C)
EXCEPTION_DISPOSITION _d_framehandler(
            EXCEPTION_RECORD *exception_record,
            DEstablisherFrame *frame,
            CONTEXT *context,
            void *dispatcher_context)
{
    DHandlerTable *handler_table;

    asm { mov handler_table,EAX; }

    if (exception_record.ExceptionFlags & EXCEPTION_UNWIND)
    {
         // Call all the finally blocks in this frame
         _d_local_unwind(handler_table, frame, -1);
    }
    else
    {
        // Jump to catch block if matching one is found
        int ndx,prev_ndx,i;
        DHandlerInfo *phi;
        DCatchInfo *pci;
        DCatchBlock *pcb;
        uint ncatches;              // number of catches in the current handler
        Object pti;
        ClassInfo ci;

        ci = null;                      // only compute it if we need it

        // walk through handler table, checking each handler
        // with an index smaller than the current table_index
        for (ndx = frame.table_index; ndx != -1; ndx = prev_ndx)
        {
            phi = &handler_table.handler_info[ndx];
            prev_ndx = phi.prev_index;
            if (phi.cioffset)
            {
                // this is a catch handler (no finally)
                pci = cast(DCatchInfo *)(cast(ubyte *)handler_table + phi.cioffset);
                ncatches = pci.ncatches;
                for (i = 0; i < ncatches; i++)
                {
                    pcb = &pci.catch_block[i];

                    if (!ci)
                    {
                        // This code must match the translation code
                        if (exception_record.ExceptionCode == STATUS_DIGITAL_MARS_D_EXCEPTION)
                        {
                            // printf("ei[0] = %p\n", exception_record.ExceptionInformation[0]);
                            ci = (**(cast(ClassInfo **)(exception_record.ExceptionInformation[0])));
                        }
                        else
                            ci = Throwable.typeinfo;
                    }
                    if (_d_isbaseof(ci, pcb.type))
                    {
                        // Matched the catch type, so we've found the handler.
                        int regebp;

                        pti = _d_translate_se_to_d_exception(exception_record);

                        // Initialize catch variable
                        regebp = cast(int)&frame.ebp;              // EBP for this frame
                        *cast(Object *)(regebp + (pcb.bpoffset)) = pti;

                        _d_setUnhandled(pti);

                        // Have system call all finally blocks in intervening frames
                        _global_unwind(frame, exception_record);

                        // Call all the finally blocks skipped in this frame
                        _d_local_unwind(handler_table, frame, ndx);

                        _d_setUnhandled(null);

                        frame.table_index = prev_ndx;  // we are out of this handler

                        // Jump to catch block. Does not return.
                        {
                            uint catch_esp;
                            fp_t catch_addr;

                            catch_addr = cast(fp_t)(pcb.code);
                            catch_esp = regebp - handler_table.espoffset - fp_t.sizeof;
                            asm
                            {
                                mov     EAX,catch_esp;
                                mov     ECX,catch_addr;
                                mov     [EAX],ECX;
                                mov     EBP,regebp;
                                mov     ESP,EAX;         // reset stack
                                ret;                     // jump to catch block
                            }
                        }
                    }
                }
            }
        }
    }
    return EXCEPTION_DISPOSITION.ExceptionContinueSearch;
}

/***********************************
 * Exception filter for use in __try..__except block
 * surrounding call to Dmain()
 */

int _d_exception_filter(EXCEPTION_POINTERS *eptrs,
                        int retval,
                        Object *exception_object)
{
    *exception_object = _d_translate_se_to_d_exception(eptrs.ExceptionRecord);
    return retval;
}

/***********************************
 * Throw a D object.
 */
extern(C)
void _d_throwc(Object h)
{
    //printf("_d_throw(h = %p, &h = %p)\n", h, &h);
    //printf("\tvptr = %p\n", *(void **)h);
    _d_createTrace(h);
    //_d_setUnhandled(h);
    RaiseException(STATUS_DIGITAL_MARS_D_EXCEPTION,
                   EXCEPTION_NONCONTINUABLE,
                   1, cast(void *)&h);
}

/***********************************
 * Converts a Windows Structured Exception code to a D Exception Object.
 */

Object _d_translate_se_to_d_exception(EXCEPTION_RECORD *exception_record)
{
    Object pti;
   // BUG: what if _d_newclass() throws an out of memory exception?

    switch (exception_record.ExceptionCode) {
        case STATUS_DIGITAL_MARS_D_EXCEPTION:
            // Generated D exception
            pti = cast(Object)cast(void *)(exception_record.ExceptionInformation[0]);
            break;

        case STATUS_INTEGER_DIVIDE_BY_ZERO:
            pti = new Error("Integer Divide by Zero");
            break;

        case STATUS_FLOAT_DIVIDE_BY_ZERO:
            pti = new Error("Float Divide by Zero");
            break;

        case STATUS_ACCESS_VIOLATION:
            pti = new Error("Access Violation");
            break;

        case STATUS_STACK_OVERFLOW:
            pti = new Error("Stack Overflow");
            break;

        case STATUS_DATATYPE_MISALIGNMENT:
            pti = new Error("Datatype Misalignment");
            break;

        case STATUS_ARRAY_BOUNDS_EXCEEDED:
            pti = new Error("Array Bounds Exceeded");
            break;

        case STATUS_FLOAT_INVALID_OPERATION:
            pti = new Error("Invalid Floating Point Operation");
            break;

        case STATUS_FLOAT_DENORMAL_OPERAND:
            pti = new Error("Floating Point Denormal Operand");
            break;

        case STATUS_FLOAT_INEXACT_RESULT:
            pti = new Error("Floating Point Inexact Result");
            break;

        case STATUS_FLOAT_OVERFLOW:
            pti = new Error("Floating Point Overflow");
            break;

        case STATUS_FLOAT_UNDERFLOW:
            pti = new Error("Floating Point Underflow");
            break;

        case STATUS_FLOAT_STACK_CHECK:
            pti = new Error("Floating Point Stack Check");
            break;

        case STATUS_PRIVILEGED_INSTRUCTION:
            if (*(cast(ubyte *)(exception_record.ExceptionAddress))==0xF4) { // HLT
                pti = new Error("assert(0) or HLT instruction");
            } else {
                pti = new Error("Privileged Instruction");
            }
            break;

        case STATUS_ILLEGAL_INSTRUCTION:
            pti = new Error("Illegal Instruction");
            break;

        case STATUS_BREAKPOINT:
            pti = new Error("Breakpoint");
            break;

        case STATUS_IN_PAGE_ERROR:
            pti = new Error("Win32 In Page Exception");
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
            pti = new Error("Win32 Exception");
            break;
    }
    _d_createTrace(pti);
    return pti;
}

/**************************************
 * Call finally blocks in the current stack frame until stop_index.
 * This is roughly equivalent to _local_unwind() for C in \src\win32\ehsup.c
 */
extern(C)
void _d_local_unwind(DHandlerTable *handler_table,
        DEstablisherFrame *frame, int stop_index)
{
    DHandlerInfo *phi;
    DCatchInfo *pci;
    int i;
    // Set up a special exception handler to catch double-fault exceptions.
    asm
    {
        push    dword ptr -1;
        push    dword ptr 0;
        push    offset _local_except_handler;    // defined in src\win32\ehsup.c
        push    dword ptr FS:_except_list;
        mov     FS:_except_list,ESP;
    }
    for (i = frame.table_index; i != -1 && i != stop_index; i = phi.prev_index)
    {
        phi = &handler_table.handler_info[i];
        if (phi.finally_code)
        {
            // Note that it is unnecessary to adjust the ESP, as the finally block
            // accesses all items on the stack as relative to EBP.

            DWORD *catch_ebp = &frame.ebp;
            void *blockaddr = phi.finally_code;

            asm
            {
                push    EBX;
                mov     EBX,blockaddr;
                push    EBP;
                mov     EBP,catch_ebp;
                call    EBX;
                pop     EBP;
                pop     EBX;
            }
        }
    }

    asm
    {
        pop     FS:_except_list;
        add     ESP,12;
    }
}

/***********************************
 * external version of the unwinder
 */
extern(C)
void _d_local_unwind2()
{
    asm
    {
        naked;
        jmp     _d_local_unwind;
    }
}

/***********************************
 * The frame handler, this is called for each frame that has been registered
 * in the OS except_list.
 * Input:
 *      EAX     the handler table for the frame
 */

extern(C)
EXCEPTION_DISPOSITION _d_monitor_handler(
            EXCEPTION_RECORD *exception_record,
            DEstablisherFrame *frame,
            CONTEXT *context,
            void *dispatcher_context)
{
    if (exception_record.ExceptionFlags & EXCEPTION_UNWIND)
    {
        _d_monitorexit(cast(Object)cast(void *)frame.table_index);
    }
    else
    {
    }
    return EXCEPTION_DISPOSITION.ExceptionContinueSearch;
}

/***********************************
 */
extern(C)
void _d_monitor_prolog(void *x, void *y, Object h)
{
    asm
    {
        push    EAX;
    }
    //printf("_d_monitor_prolog(x=%p, y=%p, h=%p)\n", x, y, h);
    _d_monitorenter(h);
    asm
    {
        pop     EAX;
    }
}

/***********************************
 */
extern(C)
void _d_monitor_epilog(void *x, void *y, Object h)
{
    //printf("_d_monitor_epilog(x=%p, y=%p, h=%p)\n", x, y, h);
    asm
    {
        push    EAX;
        push    EDX;
    }
    _d_monitorexit(h);
    asm
    {
        pop     EDX;
        pop     EAX;
    }
}
