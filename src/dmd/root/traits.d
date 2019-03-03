/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/traits.d, _traits.d)
 * Documentation:  https://dlang.org/phobos/dmd_traits.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/traits.d
 */
module dmd.root.traits;

/// Evaluates to `true` if `T` is an aggregate type, otherwise `false`.
enum isAggregateType(T) =
    is(T == union) ||
    is(T == class) ||
    is(T == struct) ||
    is(T == interface);

///
@safe unittest
{
    class C;
    union U;
    struct S;
    interface I;

    static assert( isAggregateType!C);
    static assert( isAggregateType!U);
    static assert( isAggregateType!S);
    static assert( isAggregateType!I);
    static assert(!isAggregateType!void);
    static assert(!isAggregateType!string);
    static assert(!isAggregateType!(int[]));
    static assert(!isAggregateType!(C[string]));
    static assert(!isAggregateType!(void delegate(int)));
}
