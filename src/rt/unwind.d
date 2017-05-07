/**
 * Written in the D programming language.
 * Equivalent to unwind.h
 *
 * See_Also:
 *      Itanium C++ ABI: Exception Handling ($Revision: 1.22 $)
 * Source: $(DRUNTIMESRC src/rt/_unwind.d)
 */

module rt.unwind;

import core.stdc.stdint;

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

alias int _Unwind_Action;
enum _Unwind_Action _UA_SEARCH_PHASE  = 1;
enum _Unwind_Action _UA_CLEANUP_PHASE = 2;
enum _Unwind_Action _UA_HANDLER_FRAME = 4;
enum _Unwind_Action _UA_FORCE_UNWIND  = 8;
enum _Unwind_Action _UA_END_OF_STACK  = 16;

alias _Unwind_Exception_Cleanup_Fn = void function(
        _Unwind_Reason_Code reason,
        _Unwind_Exception *exc);

version (X86_64)
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
