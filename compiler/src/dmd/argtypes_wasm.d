/**
 * Break down a D type into basic types for the WebAssembly ABI.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/argtypes_wasm.d, _argtypes_wasm.d)
 * Documentation:  https://dlang.org/phobos/dmd_argtypes_wasm.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/argtypes_wasm.d
 */

module dmd.argtypes_wasm;

import dmd.astenums;
import dmd.mtype;
import dmd.typesem;
import dmd.target : target;

/****************************************************
 * Break down a D type into basic types for WebAssembly ABI.
 *
 * Params:
 *      t = type to break down
 * Returns:
 *      For non-aggregate types or small aggregates: returns the type itself
 *      For large aggregates: returns empty (pass by reference)
 */
TypeTuple toArgTypes_wasm(Type t)
{
    if (t == Type.terror)
        return new TypeTuple(t);

    Type tb = t.toBasetype();

    // void and zero-sized types are not passed
    if (tb.ty == Tvoid || t.size() == 0)
        return null;

    // Scalars and 128-bit vectors are single values (a vector maps to a wasm
    // v128 passed/returned by value, like LDC's -O0 SIMD ABI)
    if (tb.isTypeBasic() || tb.isTypePointer() || tb.ty == Tvector ||
        tb.ty == Tclass || tb.ty == Taarray || tb.ty == Tnull || tb.ty == Tfunction)
        return new TypeTuple(t);

    // Aggregates (slices, delegates, structs, static arrays) are passed by
    // reference. Returning empty makes Target.isReturnOnStack() route the
    // return through a hidden sret pointer instead of packing it into a value
    return TypeTuple.empty;
}
