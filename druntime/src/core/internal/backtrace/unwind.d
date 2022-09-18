/**
 * Binding for libunwind/libgc's `unwind.h`
 *
 * Those bindings expose the `_Unwind_*` symbols used by druntime
 * to do exception handling.
 *
 * See_Also:
 *      Itanium C++ ABI: Exception Handling ($Revision: 1.22 $)
 * Source: $(DRUNTIMESRC core/internal/backtrace/_unwind.d)
 */
module core.internal.backtrace.unwind;

import core.stdc.stdint;

version (ARM)
{
    version (iOS) {} else version = ARM_EABI_UNWINDER;
}
version (X86)    version = X86_Any;
version (X86_64) version = X86_Any;

extern (C):

alias uintptr_t _Unwind_Word;
alias intptr_t _Unwind_Sword;
alias uintptr_t _Unwind_Ptr;
alias uintptr_t _Unwind_Internal_Ptr;

alias ulong _Unwind_Exception_Class;

alias uintptr_t _uleb128_t;
alias intptr_t _sleb128_t;

alias int _Unwind_Reason_Code;
enum
{
    _URC_NO_REASON = 0,
    _URC_FOREIGN_EXCEPTION_CAUGHT = 1,
    _URC_FATAL_PHASE2_ERROR = 2,
    _URC_FATAL_PHASE1_ERROR = 3,
    _URC_NORMAL_STOP = 4,
    _URC_END_OF_STACK = 5,
    _URC_HANDLER_FOUND = 6,
    _URC_INSTALL_CONTEXT = 7,
    _URC_CONTINUE_UNWIND = 8
}
version (ARM_EABI_UNWINDER)
    enum _URC_FAILURE = 9;

alias int _Unwind_Action;
enum _Unwind_Action _UA_SEARCH_PHASE  = 1;
enum _Unwind_Action _UA_CLEANUP_PHASE = 2;
enum _Unwind_Action _UA_HANDLER_FRAME = 4;
enum _Unwind_Action _UA_FORCE_UNWIND  = 8;
enum _Unwind_Action _UA_END_OF_STACK  = 16;

alias _Unwind_Exception_Cleanup_Fn = void function(
        _Unwind_Reason_Code reason,
        _Unwind_Exception *exc);

version (ARM_EABI_UNWINDER)
{
    align(8) struct _Unwind_Control_Block
    {
        ulong exception_class;
        void function(_Unwind_Reason_Code, _Unwind_Control_Block *) exception_cleanup;

        /* Unwinder cache, private fields for the unwinder's use */
        struct unwinder_cache_t
        {
            uint reserved1; /* init reserved1 to 0, then don't touch */
            uint reserved2;
            uint reserved3;
            uint reserved4;
            uint reserved5;
        }
        unwinder_cache_t unwinder_cache;

        /* Propagation barrier cache (valid after phase 1): */
        struct barrier_cache_t
        {
            uint sp;
            uint[5] bitpattern;
        }
        barrier_cache_t barrier_cache;

        /* Cleanup cache (preserved over cleanup): */
        struct cleanup_cache_t
        {
            uint[4] bitpattern;
        }
        cleanup_cache_t cleanup_cache;

        /* Pr cache (for pr's benefit): */
        struct pr_cache_t
        {
            uint fnstart; /* function start address */
            void* ehtp; /* pointer to EHT entry header word */
            uint additional;
            uint reserved1;
        }
        pr_cache_t pr_cache;
    }

    alias _Unwind_Exception = _Unwind_Control_Block;
}
else version (X86_Any)
{
    align(16) struct _Unwind_Exception
    {
        _Unwind_Exception_Class exception_class;
        _Unwind_Exception_Cleanup_Fn exception_cleanup;
        _Unwind_Word private_1;
        _Unwind_Word private_2;
    }
}
else
{
    align(8) struct _Unwind_Exception
    {
        _Unwind_Exception_Class exception_class;
        _Unwind_Exception_Cleanup_Fn exception_cleanup;
        _Unwind_Word private_1;
        _Unwind_Word private_2;
    }
}

struct _Unwind_Context;

_Unwind_Reason_Code _Unwind_RaiseException(_Unwind_Exception *exception_object);

alias _Unwind_Stop_Fn = _Unwind_Reason_Code function(
        int _version,
        _Unwind_Action actions,
        _Unwind_Exception_Class exceptionClass,
        _Unwind_Exception* exceptionObject,
        _Unwind_Context* context,
        void* stop_parameter);

_Unwind_Reason_Code _Unwind_ForcedUnwind(
        _Unwind_Exception* exception_object,
        _Unwind_Stop_Fn stop,
        void* stop_parameter);

alias _Unwind_Trace_Fn = _Unwind_Reason_Code function(_Unwind_Context*, void*);

void _Unwind_DeleteException(_Unwind_Exception* exception_object);
void _Unwind_Resume(_Unwind_Exception* exception_object);
_Unwind_Reason_Code _Unwind_Resume_or_Rethrow(_Unwind_Exception* exception_object);
_Unwind_Reason_Code _Unwind_Backtrace(_Unwind_Trace_Fn, void*);

version (ARM_EABI_UNWINDER)
{
    _Unwind_Reason_Code __gnu_unwind_frame(_Unwind_Exception* exception_object, _Unwind_Context* context);
    void _Unwind_Complete(_Unwind_Exception* exception_object);
}

_Unwind_Word _Unwind_GetGR(_Unwind_Context* context, int index);
void _Unwind_SetGR(_Unwind_Context* context, int index, _Unwind_Word new_value);
_Unwind_Ptr _Unwind_GetIP(_Unwind_Context* context);
_Unwind_Ptr _Unwind_GetIPInfo(_Unwind_Context* context, int*);
void _Unwind_SetIP(_Unwind_Context* context, _Unwind_Ptr new_value);
_Unwind_Word _Unwind_GetCFA(_Unwind_Context*);
_Unwind_Word _Unwind_GetBSP(_Unwind_Context*);
void* _Unwind_GetLanguageSpecificData(_Unwind_Context*);
_Unwind_Ptr _Unwind_GetRegionStart(_Unwind_Context* context);
void* _Unwind_FindEnclosingFunction(void* pc);

version (X68_64)
{
    _Unwind_Ptr _Unwind_GetDataRelBase(_Unwind_Context* context)
    {
        return _Unwind_GetGR(context, 1);
    }

    _Unwind_Ptr _Unwind_GetTextRelBase(_Unwind_Context* context)
    {
        assert(0);
    }
}
else
{
    _Unwind_Ptr _Unwind_GetDataRelBase(_Unwind_Context* context);
    _Unwind_Ptr _Unwind_GetTextRelBase(_Unwind_Context* context);
}


alias _Unwind_Personality_Fn = _Unwind_Reason_Code function(
        int _version,
        _Unwind_Action actions,
        _Unwind_Exception_Class exceptionClass,
        _Unwind_Exception* exceptionObject,
        _Unwind_Context* context);

struct SjLj_Function_Context;
void _Unwind_SjLj_Register(SjLj_Function_Context *);
void _Unwind_SjLj_Unregister(SjLj_Function_Context *);
_Unwind_Reason_Code _Unwind_SjLj_RaiseException(_Unwind_Exception*);
_Unwind_Reason_Code _Unwind_SjLj_ForcedUnwind(_Unwind_Exception , _Unwind_Stop_Fn, void*);
void _Unwind_SjLj_Resume(_Unwind_Exception*);
_Unwind_Reason_Code _Unwind_SjLj_Resume_or_Rethrow(_Unwind_Exception*);
