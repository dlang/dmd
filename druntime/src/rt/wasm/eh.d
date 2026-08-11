/**
 * Exception handling for WebAssembly using the exnref proposal.
 *
 * `throw` statements lower to `_d_throwc`, which pins the object (the
 * in-flight exception reference lives in host state the GC cannot scan)
 * and executes the wasm `throw` instruction via `core.wasm.throwException`.
 * Catch dispatch calls `_d_eh_wasm_match` per catch clause; a match unpins
 * the object and enters the handler.
 *
 * Because a match unpins, a still-pinned exception means one is being unwound,
 * which is what `_d_throwc` uses to chain collateral exceptions.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module rt.wasm.eh;

import core.wasm : throwException;
import core.internal.cast_ : areClassInfosEqual;

extern (C):

private __gshared Throwable[16] inFlight;
private __gshared size_t inFlightDepth;

/**
 * Throw `o` as a wasm exception.
 *
 * Params:
 *      o = the object to throw
 */
noreturn _d_throwc(Throwable o) @trusted
{
    if (o !is null)
    {
        // Collateral exception: `o` is thrown while unwinding an earlier one,
        // i.e. from a `finally` body. Only the innermost pending exception is
        // tracked, so chains deeper than one level are not reconstructed.
        if (inFlightDepth > 0 && inFlight[inFlightDepth - 1] !is null)
        {
            o = Throwable.chainTogether(inFlight[--inFlightDepth], o);
            inFlight[inFlightDepth] = null;
        }
        if (inFlightDepth < inFlight.length)
            inFlight[inFlightDepth++] = o;
        const rc = o.refcount();
        if (rc) // non-zero means it's a refcounted (-preview=dip1008) Throwable
            o.refcount() = rc + 1;
    }
    throwException(cast(void*) o);
}

/**
 * Test whether the caught object `o` matches a catch clause of type `ci`.
 * On a match the object is unpinned from the in-flight root stack.
 *
 * Params:
 *      o  = the caught object
 *      ci = the catch clause's class
 * Returns:
 *      true if `o` is an instance of `ci` (directly or via a base class)
 */
bool _d_eh_wasm_match(Object o, TypeInfo_Class ci) nothrow @nogc @trusted
{
    if (o is null)
        return false;
    for (TypeInfo_Class oc = typeid(o); oc !is null; oc = oc.base)
    {
        if (areClassInfosEqual(oc, ci))
        {
            if (inFlightDepth > 0 && inFlight[inFlightDepth - 1] is o)
                inFlight[--inFlightDepth] = null;
            return true;
        }
    }
    return false;
}
