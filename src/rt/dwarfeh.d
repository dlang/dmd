/**
 * Exception handling support for Dwarf-style portable exceptions.
 *
 * Copyright: Copyright (c) 2015-2016 by D Language Foundation
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors: Walter Bright
 * Source: $(DRUNTIMESRC src/rt/_dwarfeh.d)
 */

module rt.dwarfeh;

version (Posix):

import rt.unwind;
import core.stdc.stdio;
import core.stdc.stdlib;

extern (C)
{
    int _d_isbaseof(ClassInfo b, ClassInfo c);
    void _d_createTrace(Object o, void* context);
}

/* High 4 bytes = vendor, low 4 bytes = language
 * For us: "DMD\0D\0\0\0"
 */
enum _Unwind_Exception_Class dmdExceptionClass =
        (cast(_Unwind_Exception_Class)'D' << 56) |
        (cast(_Unwind_Exception_Class)'M' << 48) |
        (cast(_Unwind_Exception_Class)'D' << 40) |
        (cast(_Unwind_Exception_Class)'D' << 24);

/**
 * Wrap the unwinder's data with our own compiler specific struct
 * with our own data.
 */
struct ExceptionHeader
{
    Throwable object;                   // the thrown D object
    _Unwind_Exception exception_object; // the unwinder's data

    // Save info on the handler that was detected
    int handler;                        // which catch
    const(ubyte)* languageSpecificData; // Language Specific Data Area for function enclosing the handler
    _Unwind_Ptr landingPad;             // pointer to catch code

    // Stack other thrown exceptions in current thread through here.
    ExceptionHeader* next;

    static ExceptionHeader* stack;      // thread local stack of chained exceptions

    /* Pre-allocate storage for 1 instance per thread.
     * Use calloc/free for multiple exceptions in flight.
     * Does not use GC
     */
    static ExceptionHeader ehstorage;

    /************
     * Allocate and initialize an ExceptionHeader.
     * Params:
     *  o = thrown object
     * Returns:
     *  allocated and initalized ExceptionHeader
     */
    static ExceptionHeader* create(Throwable o) @nogc
    {
        auto eh = &ehstorage;
        if (eh.object)                  // if in use
        {
            eh = cast(ExceptionHeader*)core.stdc.stdlib.calloc(ExceptionHeader.sizeof, 1);
            if (!eh)
                terminate(__LINE__);              // out of memory while throwing - not much else can be done
        }
        eh.object = o;
        eh.exception_object.exception_class = dmdExceptionClass;
        //printf("create(): %p\n", eh);
        return eh;
    }

    /**********************
     * Free ExceptionHeader that was created by create().
     * Params:
     *  eh = ExceptionHeader to free
     */
    static void free(ExceptionHeader* eh)
    {
        //printf("free(%p)\n", eh);
        /* Smite contents even if subsequently free'd,
         * to ward off dangling pointer bugs.
         */
        *eh = ExceptionHeader.init;
        if (eh != &ehstorage)
            core.stdc.stdlib.free(eh);
    }

    /*************************
     * Push this onto stack of chained exceptions.
     */
    void push()
    {
        next = stack;
        stack = &this;
    }

    /************************
     * Pop and return top of chained exception stack.
     */
    static ExceptionHeader* pop()
    {
        auto eh = stack;
        stack = eh.next;
        return eh;
    }

    /*******************************
     * Convert from pointer to exception_object to pointer to ExceptionHeader
     * that it is embedded inside of.
     * Params:
     *  eo = pointer to exception_object field
     * Returns:
     *  pointer to ExceptionHeader that eo points into.
     */
    static ExceptionHeader* toExceptionHeader(_Unwind_Exception* eo)
    {
        return cast(ExceptionHeader*)(cast(void*)eo - ExceptionHeader.exception_object.offsetof);
    }
}

/*******************************************
 * The first thing a catch handler does is call this.
 * Params:
 *      exceptionObject = value passed to catch handler by unwinder
 * Returns:
 *      object that was caught
 */
extern(C) Throwable __dmd_begin_catch(_Unwind_Exception* exceptionObject)
{
    ExceptionHeader *eh = ExceptionHeader.toExceptionHeader(exceptionObject);
    //printf("__dmd_begin_catch(%p), object = %p\n", eh, eh.object);

    auto o = eh.object;

    // Pop off of chain
    if (eh != ExceptionHeader.pop())
        terminate(__LINE__);                      // eh should have been at top of stack

    _Unwind_DeleteException(&eh.exception_object);      // done with eh
    return o;
}

/****************************************
 * Called when fibers switch contexts.
 * Params:
 *      newContext = stack to switch to
 * Returns:
 *      previous value of stack
 */
extern(C) void* _d_eh_swapContextDwarf(void* newContext) nothrow
{
    auto old = ExceptionHeader.stack;
    ExceptionHeader.stack = cast(ExceptionHeader*)newContext;
    return old;
}


/*********************
 * Called by D code to throw an exception via
 * ---
 * throw o;
 * ---
 * Params:
 *      o = Object to throw
 * Returns:
 *      doesn't return
 */
extern(C) void _d_throwdwarf(Throwable o)
{
    ExceptionHeader *eh = ExceptionHeader.create(o);

    eh.push();  // add to thrown exception stack
    //printf("_d_throwdwarf: eh = %p, eh.next = %p\n", eh, eh.next);

    /* Called by unwinder when exception object needs destruction by other than our code.
     */
    extern (C) static void exception_cleanup(_Unwind_Reason_Code reason, _Unwind_Exception* eo)
    {
        //printf("exception_cleanup()\n");
        switch (reason)
        {
            case _URC_FATAL_PHASE1_ERROR:       // unknown error code
            case _URC_FATAL_PHASE2_ERROR:       // probably corruption
            default:                            // uh-oh
                terminate(__LINE__);            // C++ calls terminate() instead
                break;

            case _URC_FOREIGN_EXCEPTION_CAUGHT:
            case _URC_NO_REASON:
                auto eh = ExceptionHeader.toExceptionHeader(eo);
                ExceptionHeader.free(eh);
                break;
        }

    }

    eh.exception_object.exception_cleanup = &exception_cleanup;

    _d_createTrace(o, null);

    auto r = _Unwind_RaiseException(&eh.exception_object);

    /* Shouldn't have returned, but if it did:
     */
    switch (r)
    {
        case _URC_END_OF_STACK:
            /* Unwound the stack without encountering a catch clause.
             * In C++, this would mean call uncaught_exception().
             * In D, this should never happen since everything is enclosed
             * by a top-level try/catch.
             */
            fprintf(stderr, "uncaught exception\n");
            terminate(__LINE__);                          // should never happen
            assert(0);

        case _URC_FATAL_PHASE1_ERROR:
            /* Unexpected error, likely some sort of corruption.
             * In C++, terminate() would be called.
             */
            terminate(__LINE__);                          // should never happen
            assert(0);

        case _URC_FATAL_PHASE2_ERROR:
            /* Unexpected error. Program is in an unknown state.
             * In C++, terminate() would be called.
             */
            terminate(__LINE__);                          // should never happen
            assert(0);

        default:
            terminate(__LINE__);                          // should never happen
            assert(0);
    }
}


/*****************************************
 * "personality" function, specific to each language.
 * This one, of course, is specific to DMD.
 * Params:
 *      ver = version must be 1
 *      actions = bitwise OR of the 4 actions _UA_xxx.
 *          _UA_SEARCH_PHASE means return _URC_HANDLER_FOUND if current frame has a handler,
 *              _URC_CONTINUE_UNWIND if not. Cannot be used with _UA_CLEANUP_PHASE.
 *          _UA_CLEANUP_PHASE means perform cleanup for current frame by calling nested functions
 *              and returning _URC_CONTINUE_UNWIND. Or, set up registers and IP for Landing Pad
 *              and return _URC_INSTALL_CONTEXT.
 *          _UA_HANDLER_FRAME means this frame was the one with the handler in Phase 1, and now
 *              it is Phase 2 and the handler must be run.
 *          _UA_FORCE_UNWIND means unwinding the stack for longjmp or thread cancellation. Run
 *              finally clauses, not catch clauses, finallys must end with call to _Uwind_Resume().
 *      exceptionClass = 8 byte value indicating type of thrown exception. If the low 4 bytes
 *          are "C++\0", it's a C++ exception.
 *      exceptionObject = language specific exception information
 *      context = opaque type of unwinder state information
 * Returns:
 *      reason code
 * See_Also:
 *      http://www.ucw.cz/~hubicka/papers/abi/node25.html
 */

extern (C) _Unwind_Reason_Code __dmd_personality_v0(int ver, _Unwind_Action actions,
               _Unwind_Exception_Class exceptionClass, _Unwind_Exception* exceptionObject,
               _Unwind_Context* context)
{
    //printf("__dmd_personality_v0(actions = x%x, eo = %p, context = %p)\n", cast(int)actions, exceptionObject, context);
    //printf("exceptionClass = x%08lx\n", exceptionClass);
    if (ver != 1)
      return _URC_FATAL_PHASE1_ERROR;
    assert(context);

    const(ubyte)* language_specific_data;
    int handler;
    _Unwind_Ptr landing_pad;

    //for (auto ehx = eh; ehx; ehx = ehx.next)
        //printf(" eh: %p next=%014p lsda=%p '%.*s'\n", ehx, ehx.next, ehx.languageSpecificData, ehx.object.msg.length, ehx.object.msg.ptr);

    language_specific_data = cast(const(ubyte)*)_Unwind_GetLanguageSpecificData(context);
    //printf("lsda = %p\n", language_specific_data);

    auto Start = _Unwind_GetRegionStart(context);

    /* Get instruction pointer (ip) at start of instruction that threw
     */
    version (CRuntime_Glibc)
    {
        int ip_before_insn;
        // The instruction pointer must not be decremented when unwinding from a
        // signal handler frame (asynchronous exception, also see
        // etc.linux.memoryerror). So use _Unwind_GetIPInfo where available.
        auto ip = _Unwind_GetIPInfo(context, &ip_before_insn);
        if (!ip_before_insn)
            --ip;
    }
    else
    {
        auto ip = _Unwind_GetIP(context);
        --ip;
    }
    //printf("ip = x%x\n", cast(int)(ip - Start));
    //printf("\tStart = %p, ipoff = %p, lsda = %p\n", Start, ip - Start, language_specific_data);

    auto result = scanLSDA(language_specific_data, ip - Start, exceptionClass,
        (actions & _UA_FORCE_UNWIND) != 0,          // don't catch when forced unwinding
        (actions & _UA_SEARCH_PHASE) != 0,          // search phase is looking for handlers
        exceptionObject,
        landing_pad,
        handler);
    landing_pad += Start;

    final switch (result)
    {
        case LsdaResult.notFound:
            fprintf(stderr, "not found\n");
            terminate(__LINE__);
            assert(0);

        case LsdaResult.foreign:
            terminate(__LINE__);
            assert(0);

        case LsdaResult.corrupt:
            fprintf(stderr, "LSDA is corrupt\n");
            terminate(__LINE__);
            assert(0);

        case LsdaResult.noAction:
            //printf("  no action\n");
            return _URC_CONTINUE_UNWIND;

        case LsdaResult.cleanup:
            //printf("  cleanup\n");
            if (actions & _UA_SEARCH_PHASE)
            {
                return _URC_CONTINUE_UNWIND;
            }
            break;

        case LsdaResult.handler:
            //printf("  handler\n");
            //printf("   eh.lsda = %p, lsda = %p\n", eh.languageSpecificData, language_specific_data);
            assert(!(actions & _UA_FORCE_UNWIND));
            if (actions & _UA_SEARCH_PHASE)
            {
                if (exceptionClass == dmdExceptionClass)
                {
                    auto eh = ExceptionHeader.toExceptionHeader(exceptionObject);
                    eh.handler = handler;
                    eh.languageSpecificData = language_specific_data;
                    eh.landingPad = landing_pad;
                }
                return _URC_HANDLER_FOUND;
            }
            break;
    }

    //printf("  lsda = %p, landing_pad = %p, handler = %d\n", language_specific_data, landing_pad, handler);
    //printf( '%.*s' next = %p\n", eh.object.msg.length, eh.object.msg.ptr, eh.next);

    // Figure out what to do when there are multiple exceptions in flight
    if (exceptionClass == dmdExceptionClass)
    {
        auto eh = ExceptionHeader.toExceptionHeader(exceptionObject);
        auto currentLsd = language_specific_data;
        bool bypassed = false;
        while (eh.next)
        {
            ExceptionHeader* ehn = eh.next;

            Error e = cast(Error)eh.object;
            if (e !is null && !cast(Error)ehn.object)
            {
                /* eh is an Error, ehn is not. Skip ehn.
                 */
                //printf("bypass\n");
                currentLsd = ehn.languageSpecificData;

                // Continuing to construct the bypassed chain
                eh = ehn;
                bypassed = true;
                continue;
            }

            // Don't combine when the exceptions are from different functions
            if (currentLsd != ehn.languageSpecificData)
            {
                //printf("break: %p %p\n", currentLsd, ehn.languageSpecificData);
                break;
            }

            else
            {
                //printf("chain\n");
                // Append eh's object to ehn's object chain
                Throwable n = ehn.object;
                while (n.next)
                    n = n.next;
                n.next = eh.object;

                // Replace our exception object with in-flight one
                eh.object = ehn.object;
                if (ehn.handler != handler && !bypassed)
                {
                    handler = ehn.handler;

                    eh.handler = handler;
                    eh.languageSpecificData = language_specific_data;
                    eh.landingPad = landing_pad;
                }
            }

            // Remove ehn from threaded chain
            eh.next = ehn.next;
            //printf("delete %p\n", ehn);
            _Unwind_DeleteException(&ehn.exception_object); // discard ehn
        }
        if (bypassed)
        {
            eh = ExceptionHeader.toExceptionHeader(exceptionObject);
            Error e = cast(Error)eh.object;
            auto ehn = eh.next;
            e.bypassedException = ehn.object;
            eh.next = ehn.next;
            _Unwind_DeleteException(&ehn.exception_object);
        }
    }

    // Set up registers and jump to cleanup or handler
    int reg0 = 0;       // EAX/RAX is __exception_object
    int reg1 = (size_t.sizeof == 4) ? 2 : 1;       // EDX/RDX is __handler
    _Unwind_SetGR(context, reg0, cast(_Unwind_Ptr)exceptionObject);
    _Unwind_SetGR(context, reg1, handler);
    _Unwind_SetIP(context, landing_pad);

    return _URC_INSTALL_CONTEXT;
}

/*************************************************
 * Look at the chain of inflight exceptions and pick the class type that'll
 * be looked for in catch clauses.
 * Params:
 *      exceptionObject = language specific exception information
 * Returns:
 *      class type to look for
 */
ClassInfo getClassInfo(_Unwind_Exception* exceptionObject)
{
    ExceptionHeader* eh = ExceptionHeader.toExceptionHeader(exceptionObject);
    Throwable ehobject = eh.object;
    //printf("start: %p '%.*s'\n", ehobject, ehobject.classinfo.info.name.length, ehobject.classinfo.info.name.ptr);
    for (ExceptionHeader* ehn = eh.next; ehn; ehn = ehn.next)
    {
        //printf("ehn =   %p '%.*s'\n", ehn.object, cast(int)ehn.object.classinfo.info.name.length, ehn.object.classinfo.info.name.ptr);
        Error e = cast(Error)ehobject;
        if (e is null || (cast(Error)ehn.object) !is null)
            ehobject = ehn.object;
    }
    //printf("end  : %p\n", ehobject);
    return ehobject.classinfo;
}

/******************************
 * Decode Unsigned LEB128.
 * Params:
 *      p = pointer to data pointer, *p is updated
 *      to point past decoded value
 * Returns:
 *      decoded value
 * See_Also:
 *      https://en.wikipedia.org/wiki/LEB128
 */
_uleb128_t uLEB128(const(ubyte)** p)
{
    auto q = *p;
    _uleb128_t result = 0;
    uint shift = 0;
    while (1)
    {
        ubyte b = *q++;
        result |= cast(_uleb128_t)(b & 0x7F) << shift;
        if ((b & 0x80) == 0)
            break;
        shift += 7;
    }
    *p = q;
    return result;
}

/******************************
 * Decode Signed LEB128.
 * Params:
 *      p = pointer to data pointer, *p is updated
 *      to point past decoded value
 * Returns:
 *      decoded value
 * See_Also:
 *      https://en.wikipedia.org/wiki/LEB128
 */
_sleb128_t sLEB128(const(ubyte)** p)
{
    auto q = *p;
    ubyte b;

    _sleb128_t result = 0;
    uint shift = 0;
    while (1)
    {
        b = *q++;
        result |= cast(_sleb128_t)(b & 0x7F) << shift;
        shift += 7;
        if ((b & 0x80) == 0)
            break;
    }
    if (shift < result.sizeof * 8 && (b & 0x40))
        result |= -(cast(_sleb128_t)1 << shift);
    *p = q;
    return result;
}

enum
{
        DW_EH_PE_FORMAT_MASK    = 0x0F,
        DW_EH_PE_APPL_MASK      = 0x70,
        DW_EH_PE_indirect       = 0x80,

        DW_EH_PE_omit           = 0xFF,
        DW_EH_PE_ptr            = 0x00,
        DW_EH_PE_uleb128        = 0x01,
        DW_EH_PE_udata2         = 0x02,
        DW_EH_PE_udata4         = 0x03,
        DW_EH_PE_udata8         = 0x04,
        DW_EH_PE_sleb128        = 0x09,
        DW_EH_PE_sdata2         = 0x0A,
        DW_EH_PE_sdata4         = 0x0B,
        DW_EH_PE_sdata8         = 0x0C,

        DW_EH_PE_absptr         = 0x00,
        DW_EH_PE_pcrel          = 0x10,
        DW_EH_PE_textrel        = 0x20,
        DW_EH_PE_datarel        = 0x30,
        DW_EH_PE_funcrel        = 0x40,
        DW_EH_PE_aligned        = 0x50,
}


/**************************************************
 * Read and extract information from the LSDA (aka gcc_except_table section).
 * The dmd Call Site Table is structurally different from other implementations. It
 * is organized as nested ranges, and one ip can map to multiple ranges. The most
 * nested candidate is selected when searched. Other implementations have one candidate
 * per ip.
 * Params:
 *      lsda = pointer to LSDA table
 *      ip = offset from start of function at which exception happened
 *      exceptionClass = which language threw the exception
 *      cleanupsOnly = only look for cleanups
 *      preferHandler = if a handler encloses a cleanup, prefer the handler
 *      exceptionObject = language specific exception information
 *      landingPad = set to landing pad
 *      handler = set to index of which catch clause was matched
 * Returns:
 *      LsdaResult
 * See_Also:
 *      http://reverseengineering.stackexchange.com/questions/6311/how-to-recover-the-exception-info-from-gcc-except-table-and-eh-handle-sections
 *      http://www.airs.com/blog/archives/464
 *      https://anarcheuz.github.io/2015/02/15/ELF%20internals%20part%202%20-%20exception%20handling/
 */

LsdaResult scanLSDA(const(ubyte)* lsda, _Unwind_Ptr ip, _Unwind_Exception_Class exceptionClass,
        bool cleanupsOnly,
        bool preferHandler,
        _Unwind_Exception* exceptionObject,
        out _Unwind_Ptr landingPad, out int handler)
{
    auto p = lsda;
    if (!p)
        return LsdaResult.noAction;

    _Unwind_Ptr dw_pe_value(ubyte pe)
    {
        _Unwind_Ptr value = void;
        switch (pe)
        {
            case DW_EH_PE_uleb128:  value = cast(_Unwind_Ptr) uLEB128(&p);             break;
            case DW_EH_PE_udata2:   value = cast(_Unwind_Ptr) *cast(ushort*)p; p += 2; break;
            case DW_EH_PE_udata4:   value = cast(_Unwind_Ptr) *cast(uint*)p;   p += 4; break;
            case DW_EH_PE_udata8:   value = cast(_Unwind_Ptr) *cast(ulong*)p;  p += 8; break;
            case DW_EH_PE_sleb128:  value = cast(_Unwind_Ptr) sLEB128(&p);             break;
            case DW_EH_PE_sdata2:   value = cast(_Unwind_Ptr) *cast(short*)p;  p += 2; break;
            case DW_EH_PE_sdata4:   value = cast(_Unwind_Ptr) *cast(int*)p;    p += 4; break;
            case DW_EH_PE_sdata8:   value = cast(_Unwind_Ptr) *cast(long*)p;   p += 8; break;
            case DW_EH_PE_ptr:      if (size_t.sizeof == 8)
                                        goto case DW_EH_PE_udata8;
                                    else
                                        goto case DW_EH_PE_udata4;
            default:
                terminate(__LINE__);
        }
        return value;
    }

    ubyte LPstart = *p++;

    _Unwind_Ptr LPbase = 0;
    if (LPstart != DW_EH_PE_omit)
    {
        LPbase = dw_pe_value(LPstart);
    }

    ubyte TType = *p++;
    _Unwind_Ptr TTbase = 0;
    _Unwind_Ptr TToffset = 0;
    if (TType != DW_EH_PE_omit)
    {
        TTbase = uLEB128(&p);
        TToffset = (p - lsda) + TTbase;
    }
    ///*printf("  TType = "); print_dw_pe(TType);*/ printf(" TTbase = x%08llx\n", TTbase);

    ubyte CallSiteFormat = *p++;

    _Unwind_Ptr CallSiteTableSize = dw_pe_value(DW_EH_PE_uleb128);
    ///*printf("  CallSiteFormat = "); print_dw_pe(CallSiteFormat);*/ printf(" CallSiteTableSize = x%08llx\n", CallSiteTableSize);

    //printf("  Call Site Table\n");
    _Unwind_Ptr ipoffset = ip - LPbase;
    //printf("ipoffset = x%x\n", cast(int)ipoffset);
    bool noAction = false;
    auto tt = lsda + TToffset;
    const(ubyte)* pActionTable = p + CallSiteTableSize;
    while (1)
    {
        if (p >= pActionTable)
        {
            if (p == pActionTable)
                break;
            fprintf(stderr, "no Call Site Table\n");

            return LsdaResult.corrupt;
        }

        _Unwind_Ptr CallSiteStart = dw_pe_value(CallSiteFormat);
        _Unwind_Ptr CallSiteRange = dw_pe_value(CallSiteFormat);
        _Unwind_Ptr LandingPad    = dw_pe_value(CallSiteFormat);
        _uleb128_t ActionRecordPtr = uLEB128(&p);

        //printf(" XT: start = x%x, range = x%x, landing pad = x%x, action = x%x\n",
                //cast(int)CallSiteStart, cast(int)CallSiteRange, cast(int)LandingPad, cast(int)ActionRecordPtr);

        if (ipoffset < CallSiteStart)
            break;

        // The most nested entry will be the last one that ip is in
        if (ipoffset < CallSiteStart + CallSiteRange)
        {
            //printf("\tmatch\n");
            if (ActionRecordPtr)                // if saw a catch
            {
                if (cleanupsOnly)
                    continue;                   // ignore catch

                auto h = actionTableLookup(exceptionObject, cast(uint)ActionRecordPtr, pActionTable, tt, TType, exceptionClass);
                if (h < 0)
                {
                    fprintf(stderr, "negative handler\n");
                    return LsdaResult.corrupt;
                }
                if (h == 0)
                    continue;                   // ignore

                // The catch is good
                noAction = false;
                landingPad = LandingPad;
                handler = h;
            }
            else if (LandingPad)                // if saw a cleanup
            {
                if (preferHandler && handler)   // enclosing handler overrides cleanup
                    continue;                   // keep looking
                noAction = false;
                landingPad = LandingPad;
                handler = 0;                    // cleanup hides the handler
            }
            else                                // take no action
                noAction = true;
        }
    }

    if (noAction)
    {
        assert(!landingPad && !handler);
        return LsdaResult.noAction;
    }

    if (landingPad)
        return handler ? LsdaResult.handler : LsdaResult.cleanup;

    return LsdaResult.notFound;
}

/********************************************
 * Look up classType in Action Table.
 * Params:
 *      exceptionObject = language specific exception information
 *      actionRecordPtr = starting index in Action Table + 1
 *      pActionTable = pointer to start of Action Table
 *      tt = pointer past end of Type Table
 *      TType = encoding of entries in Type Table
 *      exceptionClass = which language threw the exception
 * Returns:
 *      >=1 means the handler index of the classType
 *      0 means classType is not in the Action Table
 *      <0 means corrupt
 */
int actionTableLookup(_Unwind_Exception* exceptionObject, uint actionRecordPtr, const(ubyte)* pActionTable,
                      const(ubyte)* tt, ubyte TType, _Unwind_Exception_Class exceptionClass)
{
    //printf("actionTableLookup(catchType = %p, actionRecordPtr = %d, pActionTable = %p, tt = %p)\n",
        //catchType, actionRecordPtr, pActionTable, tt);
    assert(pActionTable < tt);

    ClassInfo thrownType;
    if (exceptionClass == dmdExceptionClass)
    {
        thrownType = getClassInfo(exceptionObject);
    }

    for (auto ap = pActionTable + actionRecordPtr - 1; 1; )
    {
        assert(pActionTable <= ap && ap < tt);

        auto TypeFilter = sLEB128(&ap);
        auto apn = ap;
        auto NextRecordPtr = sLEB128(&ap);

        //printf(" at: TypeFilter = %d, NextRecordPtr = %d\n", cast(int)TypeFilter, cast(int)NextRecordPtr);

        if (TypeFilter <= 0)                    // should never happen with DMD generated tables
        {
            fprintf(stderr, "TypeFilter = %d\n", cast(int)TypeFilter);
            return -1;                          // corrupt
        }

        /* TypeFilter is negative index from TToffset,
         * which is where the ClassInfo is stored
         */
        _Unwind_Ptr entry;
        const(ubyte)* tt2;
        switch (TType & DW_EH_PE_FORMAT_MASK)
        {
            case DW_EH_PE_udata2:   entry = cast(_Unwind_Ptr) *cast(ushort*)(tt2 = tt - TypeFilter * 2); break;
            case DW_EH_PE_udata4:   entry = cast(_Unwind_Ptr) *cast(uint*)  (tt2 = tt - TypeFilter * 4); break;
            case DW_EH_PE_udata8:   entry = cast(_Unwind_Ptr) *cast(ulong*) (tt2 = tt - TypeFilter * 8); break;
            case DW_EH_PE_sdata2:   entry = cast(_Unwind_Ptr) *cast(short*) (tt2 = tt - TypeFilter * 2); break;
            case DW_EH_PE_sdata4:   entry = cast(_Unwind_Ptr) *cast(int*)   (tt2 = tt - TypeFilter * 4); break;
            case DW_EH_PE_sdata8:   entry = cast(_Unwind_Ptr) *cast(long*)  (tt2 = tt - TypeFilter * 8); break;
            case DW_EH_PE_ptr:      if (size_t.sizeof == 8)
                                        goto case DW_EH_PE_udata8;
                                    else
                                        goto case DW_EH_PE_udata4;
            default:
                fprintf(stderr, "TType = x%x\n", TType);
                return -1;      // corrupt
        }
        if (!entry)             // the 'catch all' type
            return -1;          // corrupt: should never happen with DMD, which explicitly uses Throwable

        switch (TType & DW_EH_PE_APPL_MASK)
        {
            case DW_EH_PE_absptr:
                break;

            case DW_EH_PE_pcrel:
                entry += cast(_Unwind_Ptr)tt2;
                break;

            default:
                return -1;
        }
        if (TType & DW_EH_PE_indirect)
            entry = *cast(_Unwind_Ptr*)entry;

        ClassInfo ci = cast(ClassInfo)cast(void*)(entry);
        if (ci.classinfo is __cpp_type_info_ptr.classinfo)
        {
            if (exceptionClass == cppExceptionClass || exceptionClass == cppExceptionClass1)
            {
                // sti is catch clause type_info
                auto sti = cast(CppTypeInfo)((cast(__cpp_type_info_ptr)cast(void*)ci).ptr);
                auto p = getCppPtrToThrownObject(exceptionObject, sti);
                if (p) // if found
                {
                    auto eh = CppExceptionHeader.toExceptionHeader(exceptionObject);
                    eh.thrownPtr = p;                   // for __cxa_begin_catch()
                    return cast(int)TypeFilter;
                }
            }
        }
        else if (exceptionClass == dmdExceptionClass && _d_isbaseof(thrownType, ci))
            return cast(int)TypeFilter; // found it

        if (!NextRecordPtr)
            return 0;                   // catch not found

        ap = apn + NextRecordPtr;
    }
    terminate(__LINE__);
    assert(0);
}

enum LsdaResult
{
    notFound,   // ip was not found in the LSDA - an exception shouldn't have happened
    foreign,    // found a result we cannot handle
    corrupt,    // the tables are corrupt
    noAction,   // found, but no action needed (i.e. no cleanup nor handler)
    cleanup,    // cleanup found (i.e. finally or destructor)
    handler,    // handler found (i.e. a catch)
}

void terminate(uint line) @nogc
{
    printf("dwarfeh(%u) fatal error\n", line);
    abort();     // unceremoniously exit
}


/****************************** C++ Support *****************************/

enum _Unwind_Exception_Class cppExceptionClass =
        (cast(_Unwind_Exception_Class)'G' << 56) |
        (cast(_Unwind_Exception_Class)'N' << 48) |
        (cast(_Unwind_Exception_Class)'U' << 40) |
        (cast(_Unwind_Exception_Class)'C' << 32) |
        (cast(_Unwind_Exception_Class)'C' << 24) |
        (cast(_Unwind_Exception_Class)'+' << 16) |
        (cast(_Unwind_Exception_Class)'+' <<  8) |
        (cast(_Unwind_Exception_Class)0 <<  0);

enum _Unwind_Exception_Class cppExceptionClass1 = cppExceptionClass + 1;


/*****************************************
 * Get Pointer to Thrown Object if type of thrown object is implicitly
 * convertible to the catch type.
 * Params:
 *      exceptionObject = language specific exception information
 *      sti = type of catch clause
 * Returns:
 *      null if not caught, pointer to thrown object if caught
 */
void* getCppPtrToThrownObject(_Unwind_Exception* exceptionObject, CppTypeInfo sti)
{
    void* p;    // pointer to thrown object
    if (exceptionObject.exception_class & 1)
        p = CppExceptionHeader.toExceptionHeader(exceptionObject).ptr;
    else
        p = cast(void*)(exceptionObject + 1);           // thrown object is immediately after it

    const tt = (cast(CppExceptionHeader*)p - 1).typeinfo;

    if (tt.__is_pointer_p())
        p = *cast(void**)p;

    // Pointer adjustment may be necessary due to multiple inheritance
    return (sti is tt || sti.__do_catch(tt, &p, 1)) ? p : null;
}

extern (C++)
{
    /**
     * Access C++ std::type_info's virtual functions from D,
     * being careful to not require linking with libstd++
     * or interfere with core.stdcpp.typeinfo.
     * So, give it a different name.
     */
    interface CppTypeInfo // map to C++ std::type_info's virtual functions
    {
        void dtor1();                           // consume destructor slot in vtbl[]
        void dtor2();                           // consume destructor slot in vtbl[]
        bool __is_pointer_p() const;
        bool __is_function_p() const;
        bool __do_catch(const CppTypeInfo, void**, uint) const;
        bool __do_upcast(const void*, void**) const;
    }
}

/// The C++ version of D's ExceptionHeader wrapper
struct CppExceptionHeader
{
    union
    {
        CppTypeInfo typeinfo;                   // type that was thrown
        void* ptr;                              // pointer to real exception
    }
    void* p1;                                   // unreferenced placeholders...
    void* p2;
    void* p3;
    void* p4;
    int i1;
    int i2;
    const(ubyte)* p5;
    const(ubyte)* p6;
    _Unwind_Ptr p7;
    void* thrownPtr;                            // pointer to thrown object
    _Unwind_Exception exception_object;         // the unwinder's data

    /*******************************
     * Convert from pointer to exception_object field to pointer to CppExceptionHeader
     * that it is embedded inside of.
     * Params:
     *  eo = pointer to exception_object field
     * Returns:
     *  pointer to CppExceptionHeader that eo points into.
     */
    static CppExceptionHeader* toExceptionHeader(_Unwind_Exception* eo)
    {
        return cast(CppExceptionHeader*)(eo + 1) - 1;
    }
}

