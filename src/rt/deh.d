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

/+
enum {
    EXCEPTION_EXECUTE_HANDLER    = 1,
    EXCEPTION_CONTINUE_SEARCH    = 0,
    EXCEPTION_CONTINUE_EXECUTION = -1
}
+/

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

enum EXCEPTION_UNWIND = 6;  // Flag to indicate if the system is unwinding

/* Windows Kernel function to initiate a system unwind.

  Documentation for this function is severely lacking.
  http://www.nynaeve.net/?p=99 states that the MSDN documentation is incorrect,
    and gives a corrected form, but it's for x86_64 only.
  http://www.microsoft.com/msj/0197/exception/exception.aspx says that it was
    undocumented in 1997.
  The pExceptRec is what will be passed to the language specific handler.
  According to MSJ, the targetIp value is unused on Win32.
  The 'valueForEAX' parameter should always be 0.
 */
extern(Windows)
void RtlUnwind(void *targetFrame, void *targetIp, EXCEPTION_RECORD *pExceptRec, void *valueForEAX);

alias int function() fp_t; // function pointer in ambient memory model

extern(C)
{ 
extern __gshared DWORD _except_list; // This is just FS:[0]
}

extern(C)
{
void _d_setUnhandled(Object);
void _d_createTrace(Object);
int _d_isbaseof(ClassInfo b, ClassInfo c);
}

/+

Implementation of Structured Exception Handling in DMD-Windows

Every function which uses exception handling (a 'frame') has a thunk created
for it. This thunk is the 'language-specific handler'.
The thunks are created in the DMD backend, in nteh_framehandler() in nteh.c.
These thunks are of the form:
      MOV     EAX,&scope_table
      JMP     __d_framehandler
FS:[0] contains a singly linked list of all active handlers (they'll all be
thunks). The list is created on the stack. 
At the end of this list is _except_handler3, a function in the DMC library.
Its signature is:

extern(C)
EXCEPTION_DISPOSITION _except_handler3(EXCEPTION_RECORD *eRecord,
    DEstablisherFrame * frame,CONTEXT *context,void *dispatchercontext);

It may be unnecessary. I think it is included for compatibility with MSVC
exceptions?

Documentation of Windows SEH is hard to find. Here is a brief explanation:

When an exception is raised, the OS calls each handler in the FS:[0] list in
turn, looking for a catch block. It continues moving down the list, as long as
each handler indicates that it has not caught the exception. When a handler is
ready to catch the exception, it calls the OS function RtlUnwind.
This calls each function in the FS:[0] list again, this time indicating that it
is a 'unwind' call. All of the intervening finally blocks are run at this time.
The complicated case is a CollidedException, which happens when a finally block
throws an exception. The new exception needs to either replace the old one, or
be chained to the old one.

The other complexity comes from the fact that a single function may have
multiple try/catch/finally blocks. Hence, there's a 'handler table' created for
each function which uses exceptions.
+/

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
template MAKE_EXCEPTION_CODE(int severity, int facility, int exception)
{
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
            EXCEPTION_RECORD *exceptionRecord,
            DEstablisherFrame *frame,
            CONTEXT *context,
            void *dispatcherContext)
{
    DHandlerTable *handlerTable;

    asm { mov handlerTable,EAX; }

    if (exceptionRecord.ExceptionFlags & EXCEPTION_UNWIND)
    {
         // Call all the finally blocks in this frame
         _d_local_unwind(handlerTable, frame, -1);
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
            phi = &handlerTable.handler_info[ndx];
            prev_ndx = phi.prev_index;
            if (phi.cioffset)
            {
                // this is a catch handler (no finally)
                pci = cast(DCatchInfo *)(cast(ubyte *)handlerTable + phi.cioffset);
                ncatches = pci.ncatches;
                for (i = 0; i < ncatches; i++)
                {
                    pcb = &pci.catch_block[i];

                    if (!ci)
                    {
                        // This code must match the translation code
                        if (exceptionRecord.ExceptionCode == STATUS_DIGITAL_MARS_D_EXCEPTION)
                        {
                            // printf("ei[0] = %p\n", exceptionRecord.ExceptionInformation[0]);
                            ci = (**(cast(ClassInfo **)(exceptionRecord.ExceptionInformation[0])));
                        }
                        else
                            ci = Throwable.typeinfo;
                    }
                    if (_d_isbaseof(ci, pcb.type))
                    {
                        // Matched the catch type, so we've found the handler.
                        int regebp;

                        pti = _d_translate_se_to_d_exception(exceptionRecord);

                        // Initialize catch variable
                        regebp = cast(int)&frame.ebp;              // EBP for this frame
                        *cast(Object *)(regebp + (pcb.bpoffset)) = pti;

                        _d_setUnhandled(pti);

                        // Have system call all finally blocks in intervening frames
                        _d_global_unwind(frame, exceptionRecord);

                        // Call all the finally blocks skipped in this frame
                        _d_local_unwind(handlerTable, frame, ndx);

                        _d_setUnhandled(null);

                        frame.table_index = prev_ndx;  // we are out of this handler

                        // Jump to catch block. Does not return.
                        {
                            uint catch_esp;
                            fp_t catch_addr;

                            catch_addr = cast(fp_t)(pcb.code);
                            catch_esp = regebp - handlerTable.espoffset - fp_t.sizeof;
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
                        Object *exceptionObject)
{
    *exceptionObject = _d_translate_se_to_d_exception(eptrs.ExceptionRecord);
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

Object _d_translate_se_to_d_exception(EXCEPTION_RECORD *exceptionRecord)
{
    Object pti;
   // BUG: what if _d_newclass() throws an out of memory exception?

    switch (exceptionRecord.ExceptionCode) {
        case STATUS_DIGITAL_MARS_D_EXCEPTION:
            // Generated D exception
            pti = cast(Object)cast(void *)(exceptionRecord.ExceptionInformation[0]);
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
            if (*(cast(ubyte *)(exceptionRecord.ExceptionAddress))==0xF4) { // HLT
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

/+
  These next two functions are necessary for dealing with collided exceptions:
  when an exception has been thrown during unwinding. This happens for example
  when a throw statement was encountered inside a finally clause.
+/

extern(C)
EXCEPTION_DISPOSITION unwindCollisionExceptionHandler(
            EXCEPTION_RECORD *exceptionRecord,
            DEstablisherFrame *frame,
            CONTEXT *context,
            void *dispatcherContext)
{
    if (!(exceptionRecord.ExceptionFlags & EXCEPTION_UNWIND)) 
        return EXCEPTION_DISPOSITION.ExceptionContinueSearch;
    // An exception has been thrown during unwinding (eg, a throw statement
    //   was encountered inside a finally clause).
    //  The target for unwinding needs to change. 
    // Based on the code for RtlUnwind in http://www.microsoft.com/msj/0197/exception/exception.aspx,
    // the dispatcherContext is used to set the EXCEPTION_REGISTRATION to be used from now on.
    *(cast(DEstablisherFrame **)dispatcherContext) = frame;
    return EXCEPTION_DISPOSITION.ExceptionCollidedUnwind;
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
        push    offset unwindCollisionExceptionHandler;
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

/+ According to http://www.microsoft.com/msj/0197/exception/exception.aspx, 
global unwind is just a thin wrapper around RtlUnwind.
__global_unwind(void * pRegistFrame)
 {
     _RtlUnwind( pRegistFrame,
                 &__ret_label,
                 0, 0 );
     __ret_label:
  }
Apparently Win32 doesn't use the return address anyway.

This code seems to be calling RtlUnwind( pFrame, &__retlabel, eRecord, 0);
+/
extern(C)
int _d_global_unwind(DEstablisherFrame *pFrame, EXCEPTION_RECORD *eRecord)
{
    asm {
        naked;
        push EBP;
        mov EBP,ESP;
        push ECX;
        push EBX;
        push ESI;
        push EDI;
        push EBP;
        push 0;
        push dword ptr 12[EBP]; //eRecord
        call __system_unwind;
        jmp __unwind_exit;
 __system_unwind:
        push dword ptr 8[EBP]; // pFrame
        call RtlUnwind;
 __unwind_exit:
        pop EBP;
        pop	EDI;
        pop	ESI;
        pop	EBX;
        pop ECX;
        mov	ESP,EBP;
        pop EBP;
        ret;
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
            EXCEPTION_RECORD *exceptionRecord,
            DEstablisherFrame *frame,
            CONTEXT *context,
            void *dispatcherContext)
{
    if (exceptionRecord.ExceptionFlags & EXCEPTION_UNWIND)
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
