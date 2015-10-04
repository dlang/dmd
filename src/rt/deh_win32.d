/**
 * Implementation of exception handling support routines for Win32.
 *
 * Copyright: Copyright Digital Mars 1999 - 2013.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright
 * Source: $(DRUNTIMESRC src/rt/deh_win32.d)
 */

module rt.deh_win32;

version (Win32):

import core.sys.windows.windows;
import rt.monitor_;
//import core.stdc.stdio;

version (D_InlineAsm_X86)
{
    version = AsmX86;
}
else version (D_InlineAsm_X86_64)
{
    version = AsmX86;
}

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
/+ Values used by Microsoft for Itanium and Win64 are:
#define EXCEPTION_NONCONTINUABLE   0x0001
#define EXCEPTION_UNWINDING        0x0002
#define EXCEPTION_EXIT_UNWIND      0x0004
#define EXCEPTION_STACK_INVALID    0x0008
#define EXCEPTION_NESTED_CALL      0x0010
#define EXCEPTION_TARGET_UNWIND    0x0020
#define EXCEPTION_COLLIDED_UNWIND  0x0040
#define EXCEPTION_UNWIND           0x0066

@@@ BUG @@@
We don't have any guarantee that this bit will remain available. Unfortunately,
it seems impossible to implement exception handling at all, without relying on
undocumented behaviour in several places.
+/
enum EXCEPTION_COLLATERAL = 0x100; // Flag used to implement TDPL exception chaining

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

extern(C)
{
extern __gshared DWORD _except_list; // This is just FS:[0]
}

extern(C)
{
    int _d_isbaseof(ClassInfo b, ClassInfo c);
    Throwable.TraceInfo _d_traceContext(void* ptr = null);
    void _d_createTrace(Object o, void* context);
}


/+

Implementation of Structured Exception Handling in DMD-Windows

Every function which uses exception handling (a 'frame') has a thunk created
for it. This thunk is the 'language-specific handler'.
The thunks are created in the DMD backend, in nteh_framehandler() in nteh.c.
These thunks are of the form:
      MOV     EAX, &scope_table
      JMP     __d_framehandler
FS:[0] contains a singly linked list of all active handlers (they'll all be
thunks). The list is created on the stack.
At the end of this list is _except_handler3, a function in the DMC library.
It may be unnecessary. I think it is included for compatibility with MSVC
exceptions? The function below is useful for debugging.

extern(C)
EXCEPTION_DISPOSITION _except_handler3(EXCEPTION_RECORD *eRecord,
    DEstablisherFrame * frame,CONTEXT *context,void *dispatchercontext);

// Walk the exception handler chain
void printHandlerChain()
{
    DEstablisherFrame *head;
    asm
    {
        mov EAX, FS:[0];
        mov head, EAX;
    }
    while (head && head != cast(DEstablisherFrame *)~0)
    {
        printf("%p %p ", head, head.handler);
        if (head.handler == &unwindCollisionExceptionHandler)
             printf("UnwindCollisionHandler\n");
        else if (head.handler == &_except_handler3)
            printf("excepthandler3\n");
        else
        {
            ubyte *hnd = cast(ubyte *)head.handler;
            if (hnd[0] == 0xB8 && hnd[5]==0xE9) // mov EAX, xxx; jmp yyy;
            {
                int adr = *cast(int *)(hnd+6);
                printf("thunk: frametable=%x adr=%x ", *cast(int *)(hnd+1), hnd + adr+10);
                if (cast(void *)(hnd + adr + 10) == &_d_framehandler)
                    printf("dframehandler\n");
                else printf("\n");
            } else printf("(unknown)\n");
        }
        head = head.prev;
    }
}

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

extern(C)
{
    alias
    EXCEPTION_DISPOSITION function (
            EXCEPTION_RECORD *exceptionRecord,
            DEstablisherFrame *frame,
            CONTEXT *context,
            void *dispatcherContext) LanguageSpecificHandler;
}


// The layout of DEstablisherFrame is the same for C++

struct DEstablisherFrame
{
    DEstablisherFrame *prev;         // pointer to previous exception list
    LanguageSpecificHandler handler; // pointer to routine for exception handler
    DWORD table_index;               // current index into handler_info[]
    DWORD ebp;                       // this is EBP of routine
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
    DHandlerInfo[1] handler_info;
};

struct DCatchBlock
{
    ClassInfo type;         // catch type
    uint bpoffset;          // EBP offset of catch var
    void *code;             // catch handler code
};

// One of these is created for each try-catch
struct DCatchInfo
{
    uint ncatches;                  // number of catch blocks
    DCatchBlock[1] catch_block;  // data for each catch block
};

// Macro to make our own exception code
template MAKE_EXCEPTION_CODE(int severity, int facility, int exception)
{
    enum int MAKE_EXCEPTION_CODE = (((severity) << 30) | (1 << 29) | (0 << 28) | ((facility) << 16) | (exception));
}
enum int STATUS_DIGITAL_MARS_D_EXCEPTION = MAKE_EXCEPTION_CODE!(3,'D',1);

/* Head of a linked list of all exceptions which are in flight.
 * This is used to implement exception chaining as described in TDPL.
 * Central to making chaining work correctly is that chaining must only occur
 * when a collision occurs (not merely when two exceptions are in flight,
 * because one may be caught before it has any effect on the other).
 *
 * The 'ExceptionRecord' member of the EXCEPTION_RECORD struct is used to
 * store a link to the earlier member on the list.
 * All exceptions which have found their catch handler are linked into this
 * list. The exceptions which collided are marked by setting a bit in the
 * ExceptionFlags. I've called this bit EXCEPTION_COLLATERAL. It has never
 * been used by Microsoft.
 *
 * Every member of the list will either eventually collide with the next earlier
 * exception, having its EXCEPTION_COLLATERAL bit set, or else will be caught.
 * If it is caught, a D exception object is created, containing all of the
 * collateral exceptions.
 *
 * There are many subtleties in this design:
 * (1) The exception records are all on the stack, so it's not possible to
 * modify them very much. In particular, we have very little choice about how
 * unwinding works, so we have to leave all the exception records essentially
 * intact.
 * (2) The length of an exception record is not constant. System exceptions
 * are shorter than D exceptions, for example.
 * (3) System exceptions don't have any space for a pointer to a D object.
 * So we cannot store the collision information in the exception record.
 * (4) it's important that this list is fiber-local.
 */

EXCEPTION_RECORD * inflightExceptionList = null;

/***********************************
 * Switch out inflightExceptionList on fiber context switches.
 */
extern(C) void* _d_eh_swapContext(void* newContext) nothrow
{
    auto old = inflightExceptionList;
    inflightExceptionList = cast(EXCEPTION_RECORD*)newContext;
    return old;
}


/***********************************
 * Find the first non-collateral exception in the list. If the last
 * entry in the list has the EXCEPTION_COLLATERAL bit set, it means
 * that this fragment will collide with the top exception in the
 * inflightException list.
 */
EXCEPTION_RECORD *skipCollateralExceptions(EXCEPTION_RECORD *n)
{
    while ( n.ExceptionRecord && n.ExceptionFlags & EXCEPTION_COLLATERAL )
    {
        n = n.ExceptionRecord;
    }
    return n;
}


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
         _d_local_unwind(handlerTable, frame, -1, &unwindCollisionExceptionHandler);
    }
    else
    {
        // Jump to catch block if matching one is found
        int ndx,prev_ndx;
        DHandlerInfo *phi;
        DCatchInfo *pci;
        DCatchBlock *pcb;
        uint ncatches;              // number of catches in the current handler

        /* The Master or Boss exception controls which catch() clause will
         * catch the exception. If all collateral exceptions are derived from
         * Exception, the boss is the first exception thrown. Otherwise,
         * the first Error is the boss.
         * But, if an Error (or non-Exception Throwable) is thrown as a collateral
         * exception, it will take priority over an Exception.
         */
        EXCEPTION_RECORD * master = null; // The Master exception.
        ClassInfo masterClassInfo;       // Class info of the Master exception.

        masterClassInfo = null;           // only compute it if we need it

        // walk through handler table, checking each handler
        // with an index smaller than the current table_index
        for (ndx = frame.table_index; ndx != -1; ndx = prev_ndx)
        {
            phi = &handlerTable.handler_info.ptr[ndx];
            prev_ndx = phi.prev_index;
            if (phi.cioffset)
            {
                // this is a catch handler (no finally)
                pci = cast(DCatchInfo *)(cast(ubyte *)handlerTable + phi.cioffset);
                ncatches = pci.ncatches;

                foreach (i; 0..ncatches)
                {
                    pcb = &pci.catch_block.ptr[i];
                    int match = 0;
                    EXCEPTION_RECORD * er = exceptionRecord;
                    // We need to check all the collateral exceptions.
                    for(;;)
                    {
                        if (er.ExceptionCode == STATUS_DIGITAL_MARS_D_EXCEPTION)
                        {
                            // printf("ei[0] = %p\n", er.ExceptionInformation[0]);
                            ClassInfo ci = (**(cast(ClassInfo **)(er.ExceptionInformation[0])));
                            // If we've reached the oldest exception without
                            // finding an Error, this one must be the master.
                            if (!master && !(er.ExceptionFlags & EXCEPTION_COLLATERAL))
                            {
                                master = er;
                                masterClassInfo = ci;
                                break;
                            }
                            if (_d_isbaseof(ci, typeid(Error)))
                            {   // It's derived from Error. This _may_ be the master.
                                master = er;
                                masterClassInfo = ci;
                            } // Else it's a collateral Exception
                        }
                        else
                        {   // Non-D exception. It will become an Error.
                            masterClassInfo = typeid(Error);
                            master = er;
                        }
                        // End the loop if this was the original exception
                        if (! (er.ExceptionFlags & EXCEPTION_COLLATERAL))
                            break;

                        // Now get the next collateral exception.
                        if (er.ExceptionRecord)
                            er = er.ExceptionRecord;
                        else // It is collateral for an existing exception chain
                             // for which we've already found the catch{}. It is
                             // possible that the new collateral makes the old catch
                             // invalid.
                            er = inflightExceptionList;
                    }
                    if (_d_isbaseof(masterClassInfo, pcb.type))
                    {
                        // Matched the catch type, so we've found the catch
                        // handler for this exception.
                        // BEWARE: We don't yet know if the catch handler will
                        // actually be executed. If there's an unwind collision,
                        // this call may be abandoned: the calls to
                        // _global_unwind and _local_unwind may never return,
                        // and the contents of the local variables will be lost.

                        // We need to add this exception to the list of in-flight
                        // exceptions, in case something collides with it.
                        EXCEPTION_RECORD * originalException = skipCollateralExceptions(exceptionRecord);
                        if (originalException.ExceptionRecord is null
                            && !(exceptionRecord is inflightExceptionList))
                        {
                            originalException.ExceptionRecord = inflightExceptionList;
                        }
                        inflightExceptionList = exceptionRecord;

                        // Have system call all finally blocks in intervening frames
                        _d_global_unwind(frame, exceptionRecord);

                        // Call all the finally blocks skipped in this frame
                        _d_local_unwind(handlerTable, frame, ndx, &searchCollisionExceptionHandler);


                        frame.table_index = prev_ndx;  // we are out of this handler

                        // Now create the D exception from the SEH exception record chain.
                        EXCEPTION_RECORD * z = exceptionRecord;
                        Throwable prev = null;
                        Error masterError = null;
                        Throwable pti;

                        for(;;)
                        {
                            Throwable w = _d_translate_se_to_d_exception(z, context);
                            if (z == master && (z.ExceptionFlags & EXCEPTION_COLLATERAL))
                            {   // if it is a short-circuit master, save it
                                masterError = cast(Error)w;
                            }
                            Throwable a = w;
                            while (a.next)
                                a = a.next;
                            a.next = prev;
                            prev = w;
                            if (!(z.ExceptionFlags & EXCEPTION_COLLATERAL))
                                break;
                            z = z.ExceptionRecord;
                        }
                        // Reached the end. Now add the Master, if any.
                        if (masterError)
                        {
                            masterError.bypassedException = prev;
                            pti = masterError;
                        }
                        else
                        {
                            pti = prev;
                        }
                        // Pop the exception from the list of in-flight exceptions
                        inflightExceptionList = z.ExceptionRecord;

                        int regebp;
                        // Initialize catch variable
                        regebp = cast(int)&frame.ebp;              // EBP for this frame
                        *cast(Object *)(regebp + (pcb.bpoffset)) = pti;

                        // Jump to catch block. Does not return.
                        {
                            uint catch_esp;
                            alias void function() fp_t; // generic function pointer
                            fp_t catch_addr = cast(fp_t)(pcb.code);
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
    *exceptionObject = _d_translate_se_to_d_exception(eptrs.ExceptionRecord, eptrs.ContextRecord);
    return retval;
}

/***********************************
 * Throw a D object.
 */

private void throwImpl(Object h)
{
    // @@@ TODO @@@ Signature should change: h will always be a Throwable.
    //printf("_d_throw(h = %p, &h = %p)\n", h, &h);
    //printf("\tvptr = %p\n", *(void **)h);
    _d_createTrace(h, null);
    RaiseException(STATUS_DIGITAL_MARS_D_EXCEPTION,
                   EXCEPTION_NONCONTINUABLE,
                   1, cast(void *)&h);
}

extern(C) void _d_throwc(Object h)
{
    // set up a stack frame for trace unwinding
    version (AsmX86)
    {
        asm
        {
            naked;
            enter 0, 0;
        }
        version (D_InlineAsm_X86)
            asm { mov EAX, [EBP+8]; }
        asm
        {
            call throwImpl;
            leave;
            ret;
        }
    }
    else
    {
        throwImpl(h);
    }
}

/***********************************
 * Converts a Windows Structured Exception code to a D Throwable Object.
 */

Throwable _d_translate_se_to_d_exception(EXCEPTION_RECORD *exceptionRecord, CONTEXT* context)
{
    Throwable pti;
   // BUG: what if _d_newclass() throws an out of memory exception?

    switch (exceptionRecord.ExceptionCode) {
        case STATUS_DIGITAL_MARS_D_EXCEPTION:
            // Generated D exception
            pti = cast(Throwable)cast(void *)(exceptionRecord.ExceptionInformation[0]);
            break;

        case STATUS_INTEGER_DIVIDE_BY_ZERO:
            pti = new Error("Integer Divide by Zero");
            break;

        case STATUS_INTEGER_OVERFLOW: // eg, int.min % -1
            pti = new Error("Integer Overflow");
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
    _d_createTrace(pti, context);
    return pti;
}

/*
These next two functions are necessary for dealing with collided exceptions:
when an exception has been thrown during unwinding. This happens for example
when a throw statement was encountered inside a finally clause.

'frame' is the stack pointer giving the state we were in, when we made
the call to RtlUnwind.
When we return ExceptionCollidedUnwind, the OS initiates a new SEARCH
phase, using the new exception, and it begins this search from the frame we
provide in the 'dispatcherContext' output parameter.
We change the target frame pointer, by changing dispatcherContext. After this, we'll be
back at the start of a SEARCH phase, so we need cancel all existing operations.
There are two types of possible collisions.
(1) collision during a local unwind. That is, localunwind was called during the
SEARCH phase (without going through an additional call to RtlUnwind).
We need to cancel the original search pass, so we'll restart from 'frame'.
(2) collision during a global unwind. That is, localunwind was called from the UNWIND phase.
We need to cancel the unwind pass, AND we need to cancel the search pass that initiated it.
So, we need to restart from 'frame.prev'.
*/

extern (C)
EXCEPTION_DISPOSITION searchCollisionExceptionHandler(
            EXCEPTION_RECORD *exceptionRecord,
            DEstablisherFrame *frame,
            CONTEXT *context,
            void *dispatcherContext)
{
    if (!(exceptionRecord.ExceptionFlags & EXCEPTION_UNWIND))
    {
        // Mark this as a collateral exception
        EXCEPTION_RECORD * n = skipCollateralExceptions(exceptionRecord);
        n.ExceptionFlags |= EXCEPTION_COLLATERAL;

        return EXCEPTION_DISPOSITION.ExceptionContinueSearch;
    }

    // An exception has been thrown during unwinding.
    // It happened during the SEARCH phase.
    // We need to cancel the original search pass, so we'll restart from 'frame'.
    *(cast(void **)dispatcherContext) = frame;
    return EXCEPTION_DISPOSITION.ExceptionCollidedUnwind;
}

extern(C)
EXCEPTION_DISPOSITION unwindCollisionExceptionHandler(
            EXCEPTION_RECORD *exceptionRecord,
            DEstablisherFrame *frame,
            CONTEXT *context,
            void *dispatcherContext)
{
    if (!(exceptionRecord.ExceptionFlags & EXCEPTION_UNWIND))
    {
        // Mark this as a collateral exception
        EXCEPTION_RECORD * n = skipCollateralExceptions(exceptionRecord);
        n.ExceptionFlags |= EXCEPTION_COLLATERAL;
        return EXCEPTION_DISPOSITION.ExceptionContinueSearch;
    }
    // An exception has been thrown during unwinding.
    // It happened during the UNWIND phase.
    // We need to cancel the unwind pass, AND we need to cancel the search
    // pass that initiated the unwind. So, we need to restart from 'frame.prev'.
    *(cast(void **)dispatcherContext) = frame.prev;
    return EXCEPTION_DISPOSITION.ExceptionCollidedUnwind;
}

/**************************************
 * Call finally blocks in the current stack frame until stop_index.
 * This is roughly equivalent to _local_unwind() for C in \src\win32\ehsup.c
 */
extern(C)
void _d_local_unwind(DHandlerTable *handler_table,
        DEstablisherFrame *frame, int stop_index, LanguageSpecificHandler collisionHandler)
{
    DHandlerInfo *phi;
    DCatchInfo *pci;
    int i;
    // Set up a special exception handler to catch double-fault exceptions.
    asm
    {
        push    dword ptr -1;
        push    dword ptr 0;
        push    collisionHandler;
        push    dword ptr FS:_except_list;
        mov     FS:_except_list,ESP;
    }
    for (i = frame.table_index; i != -1 && i != stop_index; i = phi.prev_index)
    {
        phi = &handler_table.handler_info.ptr[i];
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
        pop     EDI;
        pop     ESI;
        pop     EBX;
        pop ECX;
        mov     ESP,EBP;
        pop EBP;
        ret;
    }
}

/***********************************
 * external version of the unwinder
 * This is used for 'goto' or 'return', to run any finally blocks
 * which were skipped.
 */
extern(C)
void _d_local_unwind2()
{
    asm
    {
        naked;
        jmp     _d_localUnwindForGoto;
    }
}

extern(C)
void _d_localUnwindForGoto(DHandlerTable *handler_table,
        DEstablisherFrame *frame, int stop_index)
{
    _d_local_unwind(handler_table, frame, stop_index, &searchCollisionExceptionHandler);
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

