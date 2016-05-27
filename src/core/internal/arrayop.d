module core.internal.arrayop;
import core.internal.traits : Filter, Unqual;

version (GNU) version = GNU_OR_LDC;
version (LDC) version = GNU_OR_LDC;

/**
 * Perform array (vector) operations and store the result in `res`.
 * Operand types and operations are passed as template arguments in Reverse
 * Polish Notation (RPN).
 * All slice operands must have the same length as the result slice.
 *
 * Params: res = the slice in which to store the results
 *        args = all other operands
 *        Args = operand types and operations in RPN
 *         T[] = type of result slice
 * Returns: the slice containing the result
 */
T[] arrayOp(T : T[], Args...)(T[] res, Filter!(isType, Args) args) @trusted @nogc pure nothrow
{
    size_t pos;
    static if (vectorizeable!(T[], Args))
    {
        alias vec = .vec!T;
        alias load = .load!(T, vec.length);
        alias store = .store!(T, vec.length);
        alias scalarToVec = .scalarToVec!(T, vec.length);

        auto n = res.length / vec.length;
        enum nScalarInits = scalarIndices!Args.length;
        if (n > 2 * (1 + nScalarInits)) // empirically found cost estimate
        {
            mixin(initScalarVecs!Args);

            do
            {
                mixin(vectorExp!Args ~ ";");
                pos += vec.length;
            }
            while (--n);
        }
    }
    for (; pos < res.length; ++pos)
        mixin(scalarExp!Args ~ ";");

    return res;
}

private:

// SIMD helpers

version (GNU)
    import gcc.builtins;
else version (LDC)
{
    import ldc.simd;
    import ldc.gccbuiltins_x86;
}
else version (DigitalMars)
    import core.simd;
else
    static assert(0, "unimplemented");

template vec(T)
{
    enum regsz = 16; // SSE2
    enum N = regsz / T.sizeof;
    alias vec = __vector(T[N]);
}

void store(T, size_t N)(T* p, in __vector(T[N]) val)
{
    pragma(inline, true);
    alias vec = __vector(T[N]);

    version (LDC)
    {
        storeUnaligned!vec(val, p);
    }
    else version (GNU)
    {
        static if (is(T == float))
            __builtin_ia32_storeups(p, val);
        else static if (is(T == double))
            __builtin_ia32_storeupd(p, val);
        else
            __builtin_ia32_storedqu(cast(char*) p, val);
    }
    else version (DigitalMars)
    {
        static if (is(T == float))
            cast(void) __simd_sto(XMM.STOUPS, *cast(vec*) p, val);
        else static if (is(T == double))
            cast(void) __simd_sto(XMM.STOUPD, *cast(vec*) p, val);
        else
            cast(void) __simd_sto(XMM.STODQU, *cast(vec*) p, val);
    }
}

const(__vector(T[N])) load(T, size_t N)(in T* p)
{
    pragma(inline, true);
    alias vec = __vector(T[N]);

    version (LDC)
    {
        return loadUnaligned!vec(cast(T*) p);
    }
    else version (GNU)
    {
        static if (is(T == float))
            return __builtin_ia32_loadups(p);
        else static if (is(T == double))
            return __builtin_ia32_loadupd(p);
        else
            return __builtin_ia32_loaddqu(cast(const char*) p);
    }
    else version (DigitalMars)
    {
        static if (is(T == float))
            return __simd(XMM.LODUPS, *cast(const vec*) p);
        else static if (is(T == double))
            return __simd(XMM.LODUPD, *cast(const vec*) p);
        else
            return __simd(XMM.LODDQU, *cast(const vec*) p);
    }
}

const(__vector(T[N])) scalarToVec(T, size_t N)(in T a)
{
    pragma(inline, true);
    alias vec = __vector(T[N]);

    vec res = void;
    version (DigitalMars) // Bugzilla 7509
        res.array = [a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a][0 .. N];
    else
        res = a;
    return res;
}

__vector(T[N]) binop(string op, T, size_t N)(in __vector(T[N]) a, in __vector(T[N]) b)
{
    pragma(inline, true);
    return mixin("a " ~ op ~ " b");
}

__vector(T[N]) unaop(string op, T, size_t N)(in __vector(T[N]) a) if (op[0] == 'u')
{
    pragma(inline, true);
    return mixin(op[1 .. $] ~ "a");
}

// mixin gen

// filter out ops without matching SSE/SIMD instructions (could be composed of several instructions though)
bool vectorizeableOps(E)(string[] ops)
{
    // dfmt off
    return !(
        ops.contains("/", "/=") && __traits(isIntegral, E) ||
        ops.contains("*", "*=") && __traits(isIntegral, E) && E.sizeof != 2 ||
        ops.contains("%", "%=")
    );
    // dfmt on
}

// filter out things like float[] = float[] / size_t[]
enum compatibleVecTypes(E, T : T[]) = is(Unqual!T == Unqual!E); // array elem types must be same (maybe add cvtpi2ps)
enum compatibleVecTypes(E, T) = is(T : E); // scalar must be convertible to target elem type
enum compatibleVecTypes(E, Types...) = compatibleVecTypes!(E, Types[0 .. $ / 2])
        && compatibleVecTypes!(E, Types[$ / 2 .. $]);

template vectorizeable(E : E[], Args...)
{
    static if (is(vec!E))
        enum vectorizeable = vectorizeableOps!E([Filter!(not!isType, Args)])
                && compatibleVecTypes!(E, Filter!(isType, Args));
    else
        enum vectorizeable = false;
}

version (X86_64) unittest
{
    static assert(vectorizeable!(double[], const(double)[], double[], "+", "="));
    static assert(!vectorizeable!(double[], const(ulong)[], double[], "+", "="));
}

bool isUnaryOp(string op)
{
    return op[0] == 'u';
}

bool isBinaryOp(string op)
{
    if (op.length != 1)
        return false;
    switch (op[0])
    {
    case '+', '-', '*', '/', '%', '|', '&', '^':
        return true;
    default:
        return false;
    }
}

bool isBinaryAssignOp(string op)
{
    return op.length == 2 && op[1] == '=' && isBinaryOp(op[0 .. 1]);
}

string scalarExp(Args...)()
{
    string[] stack;
    size_t argsIdx;
    foreach (i, arg; Args)
    {
        static if (is(arg == T[], T))
            stack ~= "args[" ~ argsIdx++.toString ~ "][pos]";
        else static if (is(arg))
            stack ~= "args[" ~ argsIdx++.toString ~ "]";
        else static if (isUnaryOp(arg))
        {
            auto op = arg[0] == 'u' ? arg[1 .. $] : arg;
            stack[$ - 1] = op ~ stack[$ - 1];
        }
        else static if (arg == "=")
        {
            stack[$ - 1] = "res[pos] = cast(T)(" ~ stack[$ - 1] ~ ")";
        }
        else static if (isBinaryAssignOp(arg))
        {
            stack[$ - 1] = "res[pos] " ~ arg ~ " cast(T)(" ~ stack[$ - 1] ~ ")";
        }
        else static if (isBinaryOp(arg))
        {
            stack[$ - 2] = "(cast(T)(" ~ stack[$ - 2] ~ " " ~ arg ~ " " ~ stack[$ - 1] ~ "))";
            stack.length -= 1;
        }
        else
            assert(0, "Unexpected op " ~ arg);
    }
    assert(stack.length == 1);
    return stack[0];
}

size_t[] scalarIndices(Args...)()
{
    size_t[] scalars;
    foreach (i, arg; Args)
    {
        if (is(arg == T[], T))
        {
        }
        else if (is(arg))
            scalars ~= i;
    }
    return scalars;
}

string initScalarVecs(Args...)()
{
    auto scalars = scalarIndices!Args;
    string res;
    foreach (i, aidx; scalars)
        res ~= "immutable vec scalar" ~ i.toString ~ " = scalarToVec(args[" ~ aidx
            .toString ~ "]);\n";
    return res;
}

string vectorExp(Args...)()
{
    size_t scalarsIdx, argsIdx;
    string[] stack;
    foreach (i, arg; Args)
    {
        static if (is(arg == T[], T))
            stack ~= "load(&args[" ~ argsIdx++.toString ~ "][pos])";
        else static if (is(arg))
        {
            ++argsIdx;
            stack ~= "scalar" ~ scalarsIdx++.toString;
        }
        else static if (isUnaryOp(arg))
        {
            auto op = arg[0] == 'u' ? arg[1 .. $] : arg;
            stack[$ - 1] = "unaop!\"" ~ arg ~ "\"(" ~ stack[$ - 1] ~ ")";
        }
        else static if (arg == "=")
        {
            stack[$ - 1] = "store(&res[pos], " ~ stack[$ - 1] ~ ")";
        }
        else static if (isBinaryAssignOp(arg))
        {
            stack[$ - 1] = "store(&res[pos], binop!\"" ~ arg[0 .. $ - 1]
                ~ "\"(load(&res[pos]), " ~ stack[$ - 1] ~ "))";
        }
        else static if (isBinaryOp(arg))
        {
            stack[$ - 2] = "binop!\"" ~ arg ~ "\"(" ~ stack[$ - 2] ~ ", " ~ stack[$ - 1] ~ ")";
            stack.length -= 1;
        }
        else
            assert(0, "Unexpected op " ~ arg);
    }
    assert(stack.length == 1);
    return stack[0];
}

// other helpers

enum isType(T) = true;
enum isType(alias a) = false;
template not(alias tmlp)
{
    enum not(Args...) = !tmlp!Args;
}

string toString(size_t num)
{
    import core.internal.string : unsignedToTempString;

    char[20] buf = void;
    return unsignedToTempString(num, buf).idup;
}

bool contains(T)(in T[] ary, in T[] vals...)
{
    foreach (v1; ary)
        foreach (v2; vals)
            if (v1 == v2)
                return true;
    return false;
}

// tests

version (unittest) template TT(T...)
{
    alias TT = T;
}

version (unittest) template _arrayOp(Args...)
{
    alias _arrayOp = arrayOp!Args;
}

unittest
{
    static void check(string op, TA, TB, T, size_t N)(TA a, TB b, in ref T[N] exp)
    {
        T[N] res;
        _arrayOp!(T[], TA, TB, op, "=")(res[], a, b);
        foreach (i; 0 .. N)
            assert(res[i] == exp[i]);
    }

    static void check2(string unaOp, string binOp, TA, TB, T, size_t N)(TA a, TB b, in ref T[N] exp)
    {
        T[N] res;
        _arrayOp!(T[], TA, TB, unaOp, binOp, "=")(res[], a, b);
        foreach (i; 0 .. N)
            assert(res[i] == exp[i]);
    }

    static void test(T, string op, size_t N = 16)(T a, T b, T exp)
    {
        T[N] va = a, vb = b, vexp = exp;

        check!op(va[], vb[], vexp);
        check!op(va[], b, vexp);
        check!op(a, vb[], vexp);
    }

    static void test2(T, string unaOp, string binOp, size_t N = 16)(T a, T b, T exp)
    {
        T[N] va = a, vb = b, vexp = exp;

        check2!(unaOp, binOp)(va[], vb[], vexp);
        check2!(unaOp, binOp)(va[], b, vexp);
        check2!(unaOp, binOp)(a, vb[], vexp);
    }

    alias UINTS = TT!(ubyte, ushort, uint, ulong);
    alias INTS = TT!(byte, short, int, long);
    alias FLOATS = TT!(float, double);

    foreach (T; TT!(UINTS, INTS, FLOATS))
    {
        test!(T, "+")(1, 2, 3);
        test!(T, "-")(3, 2, 1);

        test2!(T, "u-", "+")(3, 2, 1);
    }

    foreach (T; TT!(UINTS, INTS))
    {
        test!(T, "|")(1, 2, 3);
        test!(T, "&")(3, 1, 1);
        test!(T, "^")(3, 1, 2);

        test2!(T, "u~", "+")(3, cast(T)~2, 5);
    }

    foreach (T; TT!(INTS, FLOATS))
    {
        test!(T, "-")(1, 2, -1);
        test2!(T, "u-", "+")(-3, -2, -1);
        test2!(T, "u-", "*")(-3, -2, -6);
    }

    foreach (T; TT!(UINTS, INTS, FLOATS))
    {
        test!(T, "*")(2, 3, 6);
        test!(T, "/")(8, 4, 2);
        test!(T, "%")(8, 6, 2);
    }
}

// test rewrite of v op= exp to v = v op exp
unittest
{
    byte[32] c;
    arrayOp!(byte[], byte, "+=")(c[], cast(byte) 6);
    foreach (v; c)
        assert(v == 6);
}
