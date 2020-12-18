/*
 * Support for rich error messages generation with `assert`
 *
 * This module provides the `_d_assert_fail` hooks which are instantiated
 * by the compiler whenever `-checkaction=context` is used.
 * There are two hooks, one for unary expressions, and one for binary.
 * When used, the compiler will rewrite `assert(a >= b)` as
 * `assert(a >= b, _d_assert_fail!">="(a, b))`.
 * Temporaries will be created to avoid side effects if deemed necessary
 * by the compiler.
 *
 * For more information, refer to the implementation in DMD frontend
 * for `AssertExpression`'s semantic analysis.
 *
 * Copyright: D Language Foundation 2018 - 2020
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/druntime/blob/master/src/core/internal/dassert.d, _dassert.d)
 * Documentation: https://dlang.org/phobos/core_internal_dassert.html
 */
module core.internal.dassert;

/**
 * Generates rich assert error messages for unary expressions
 *
 * The unary expression `assert(!una)` will be turned into
 * `assert(!una, _d_assert_fail!"!"(una))`.
 * This routine simply acts as if the user wrote `assert(una == false)`.
 *
 * Params:
 *   op = Operator that was used in the expression, currently only "!"
 *        is supported.
 *   a  = Result of the expression that was used in `assert` before
 *        its implicit conversion to `bool`.
 *
 * Returns:
 *   A string such as "$a != true" or "$a == true".
 */
string _d_assert_fail(string op, A)(auto ref const scope A a)
{
    string val = miniFormatFakeAttributes(a);
    enum token = op == "!" ? "==" : "!=";
    return combine(val, token, "true");
}

/**
 * Generates rich assert error messages for binary expressions
 *
 * The binary expression `assert(x == y)` will be turned into
 * `assert(x == y, _d_assert_fail!"=="(x, y))`.
 *
 * Params:
 *   comp = Comparison operator that was used in the expression.
 *   a  = Left hand side operand.
 *   b  = Right hand side operand.
 *
 * Returns:
 *   A string such as "$a $comp $b".
 */
string _d_assert_fail(string comp, A, B)(auto ref const scope A a, auto ref const scope B b)
{
    /*
    The program will be terminated after the assertion error message has
    been printed and its not considered part of the "main" program.
    Also, catching an AssertError is Undefined Behavior
    Hence, we can fake purity and @nogc-ness here.
    */

    string valA = miniFormatFakeAttributes(a);
    string valB = miniFormatFakeAttributes(b);
    enum token = invertCompToken(comp);
    return combine(valA, token, valB);
}

/// Combines the supplied arguments into one string "valA token valB"
private string combine(const scope string valA, const scope string token,
const scope string valB) pure nothrow @nogc @safe
{
    const totalLen = valA.length + token.length + valB.length + 2;
    char[] buffer = cast(char[]) pureAlloc(totalLen)[0 .. totalLen];
    // @nogc-concat of "<valA> <comp> <valB>"
    auto n = valA.length;
    buffer[0 .. n] = valA;
    buffer[n++] = ' ';
    buffer[n .. n + token.length] = token;
    n += token.length;
    buffer[n++] = ' ';
    buffer[n .. n + valB.length] = valB;
    return (() @trusted => cast(string) buffer)();
}

// Yields the appropriate printf format token for a type T
// Indended to be used by miniFormat
private template getPrintfFormat(T)
{
    static if (is(T == long))
    {
        enum getPrintfFormat = "%lld";
    }
    else static if (is(T == ulong))
    {
        enum getPrintfFormat = "%llu";
    }
    else static if (__traits(isIntegral, T))
    {
        static if (__traits(isUnsigned, T))
        {
            enum getPrintfFormat = "%u";
        }
        else
        {
            enum getPrintfFormat = "%d";
        }
    }
    else
    {
        static assert(0, "Unknown format");
    }
}

/**
Minimalistic formatting for use in _d_assert_fail to keep the compilation
overhead small and avoid the use of Phobos.
*/
private string miniFormat(V)(const scope ref V v)
{
    import core.internal.traits: isAggregateType;
    import core.stdc.stdio : sprintf;
    import core.stdc.string : strlen;

    static if (is(V == shared T, T))
    {
        // Use atomics to avoid race conditions whenever possible
        static if (__traits(compiles, atomicLoad(v)))
        {
            T tmp = cast(T) atomicLoad(v);
            return miniFormat(tmp);
        }
        else
        {   // Fall back to a simple cast - we're violating the type system anyways
            return miniFormat(*cast(T*) &v);
        }
    }
    else static if (is(V == bool))
    {
        return v ? "true" : "false";
    }
    else static if (__traits(isIntegral, V))
    {
        static if (is(V == char))
        {
            // Avoid invalid code points
            if (v < 0x7F)
                return ['\'', v, '\''];

            uint tmp = v;
            return "cast(char) " ~ miniFormat(tmp);
        }
        else static if (is(V == wchar) || is(V == dchar))
        {
            import core.internal.utf: isValidDchar, toUTF8;

            // Avoid invalid code points
            if (isValidDchar(v))
                return toUTF8(['\'', v, '\'']);

            uint tmp = v;
            return "cast(" ~ V.stringof ~ ") " ~ miniFormat(tmp);
        }
        else
        {
            enum printfFormat = getPrintfFormat!V;
            char[20] val;
            const len = sprintf(&val[0], printfFormat, v);
            return val.idup[0 .. len];
        }
    }
    else static if (__traits(isFloating, V))
    {
        import core.stdc.config : LD = c_long_double;

        char[60] val;
        int len;
        static if (is(V == float) || is(V == double))
            len = sprintf(&val[0], "%g", v);
        else static if (is(V == real))
            len = sprintf(&val[0], "%Lg", cast(LD) v);
        else static if (is(V == cfloat) || is(V == cdouble))
            len = sprintf(&val[0], "%g + %gi", v.re, v.im);
        else static if (is(V == creal))
            len = sprintf(&val[0], "%Lg + %Lgi", cast(LD) v.re, cast(LD) v.im);
        else static if (is(V == ifloat) || is(V == idouble))
            len = sprintf(&val[0], "%gi", v);
        else // ireal
        {
            static assert(is(V == ireal));
            static if (is(LD == real))
                alias R = ireal;
            else
                alias R = idouble;
            len = sprintf(&val[0], "%Lgi", cast(R) v);
        }
        return val.idup[0 .. len];
    }
    // special-handling for void-arrays
    else static if (is(V == typeof(null)))
    {
        return "`null`";
    }
    else static if (is(V == U*, U))
    {
        // Format as ulong because not all sprintf implementations
        // prepend a 0x for pointers
        char[20] val;
        const len = sprintf(&val[0], "0x%llX", cast(ulong) v);
        return val.idup[0 .. len];
    }
    // toString() isn't always const, e.g. classes inheriting from Object
    else static if (__traits(compiles, { string s = V.init.toString(); }))
    {
        // Object references / struct pointers may be null
        static if (is(V == class) || is(V == interface))
        {
            if (v is null)
                return "`null`";
        }

        // Prefer const overload of toString
        static if (__traits(compiles, { string s = v.toString(); }))
            return v.toString();
        else
            return (cast() v).toString();
    }
    // Static arrays or slices (but not aggregates with `alias this`)
    else static if (is(V : U[], U) && !isAggregateType!V)
    {
        import core.internal.traits: Unqual;
        alias E = Unqual!U;

        // special-handling for void-arrays
        static if (is(E == void))
        {
            const bytes = cast(byte[]) v;
            return miniFormat(bytes);
        }
        // anything string-like
        else static if (is(E == char) || is(E == dchar) || is(E == wchar))
        {
            const s = `"` ~ v ~ `"`;

            // v could be a char[], dchar[] or wchar[]
            static if (is(typeof(s) : const char[]))
                return cast(immutable) s;
            else
            {
                import core.internal.utf: toUTF8;
                return toUTF8(s);
            }
        }
        else
        {
            string msg = "[";
            foreach (i, ref el; v)
            {
                if (i > 0)
                    msg ~= ", ";

                // don't fully print big arrays
                if (i >= 30)
                {
                    msg ~= "...";
                    break;
                }
                msg ~= miniFormat(el);
            }
            msg ~= "]";
            return msg;
        }
    }
    else static if (is(V : Val[K], K, Val))
    {
        size_t i;
        string msg = "[";
        foreach (k, ref val; v)
        {
            if (i > 0)
                msg ~= ", ";
            // don't fully print big AAs
            if (i++ >= 30)
            {
                msg ~= "...";
                break;
            }
            msg ~= miniFormat(k) ~ ": " ~ miniFormat(val);
        }
        msg ~= "]";
        return msg;
    }
    else static if (is(V == struct))
    {
        string msg = V.stringof ~ "(";
        foreach (i, ref field; v.tupleof)
        {
            if (i > 0)
                msg ~= ", ";
            msg ~= miniFormat(field);
        }
        msg ~= ")";
        return msg;
    }
    else
    {
        return V.stringof;
    }
}

// This should be a local import in miniFormat but fails with a cyclic dependency error
// core.thread.osthread -> core.time -> object -> core.internal.array.capacity
// -> core.atomic -> core.thread -> core.thread.osthread
import core.atomic : atomicLoad;

// Inverts a comparison token for use in _d_assert_fail
private string invertCompToken(string comp)
{
    switch (comp)
    {
        case "==":
            return "!=";
        case "!=":
            return "==";
        case "<":
            return ">=";
        case "<=":
            return ">";
        case ">":
            return "<=";
        case ">=":
            return "<";
        case "is":
            return "!is";
        case "!is":
            return "is";
        case "in":
            return "!in";
        case "!in":
            return "in";
        default:
            assert(0, "Invalid comparison operator: " ~ comp);
    }
}

private auto assumeFakeAttributes(T)(T t) @trusted
{
    import core.internal.traits : Parameters, ReturnType;
    alias RT = ReturnType!T;
    alias P = Parameters!T;
    alias type = RT function(P) nothrow @nogc @safe pure;
    return cast(type) t;
}

private string miniFormatFakeAttributes(T)(const scope ref T t)
{
    alias miniT = miniFormat!T;
    return assumeFakeAttributes(&miniT)(t);
}

private auto pureAlloc(size_t t)
{
    static auto alloc(size_t len)
    {
        return new ubyte[len];
    }
    return assumeFakeAttributes(&alloc)(t);
}
