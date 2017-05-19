/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _target.d)
 */

module ddmd.target;

import ddmd.arraytypes;
import ddmd.cppmangle;
import ddmd.dclass;
import ddmd.dmodule;
import ddmd.dsymbol;
import ddmd.expression;
import ddmd.globals;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.tokens : TOK;
import ddmd.root.ctfloat;
import ddmd.root.outbuffer;

/***********************************************************
 */
struct Target
{
    extern (C++) static __gshared int ptrsize;
    extern (C++) static __gshared int realsize;             // size a real consumes in memory
    extern (C++) static __gshared int realpad;              // 'padding' added to the CPU real size to bring it up to realsize
    extern (C++) static __gshared int realalignsize;        // alignment for reals
    extern (C++) static __gshared bool realislongdouble;    // distinguish between C 'long double' and '__float128'
    extern (C++) static __gshared bool reverseCppOverloads; // with dmc and cl, overloaded functions are grouped and in reverse order
    extern (C++) static __gshared bool cppExceptions;       // set if catching C++ exceptions is supported
    extern (C++) static __gshared int c_longsize;           // size of a C 'long' or 'unsigned long' type
    extern (C++) static __gshared int c_long_doublesize;    // size of a C 'long double'
    extern (C++) static __gshared int classinfosize;        // size of 'ClassInfo'
    extern (C++) static __gshared ulong maxStaticDataSize;  // maximum size of static data

    template FPTypeProperties(T)
    {
        enum : real_t
        {
            max = T.max,
            min_normal = T.min_normal,
            nan = T.nan,
            snan = T.init,
            infinity = T.infinity,
            epsilon = T.epsilon
        }

        enum : long
        {
            dig = T.dig,
            mant_dig = T.mant_dig,
            max_exp = T.max_exp,
            min_exp = T.min_exp,
            max_10_exp = T.max_10_exp,
            min_10_exp = T.min_10_exp
        }
    }

    alias FloatProperties = FPTypeProperties!float;
    alias DoubleProperties = FPTypeProperties!double;
    alias RealProperties = FPTypeProperties!real;

    extern (C++) static void _init()
    {
        // These have default values for 32 bit code, they get
        // adjusted for 64 bit code.
        ptrsize = 4;
        classinfosize = 0x4C; // 76

        /* gcc uses int.max for 32 bit compilations, and long.max for 64 bit ones.
         * Set to int.max for both, because the rest of the compiler cannot handle
         * 2^64-1 without some pervasive rework. The trouble is that much of the
         * front and back end uses 32 bit ints for sizes and offsets. Since C++
         * silently truncates 64 bit ints to 32, finding all these dependencies will be a problem.
         */
        maxStaticDataSize = int.max;

        if (global.params.isLP64)
        {
            ptrsize = 8;
            classinfosize = 0x98; // 152
        }
        if (global.params.isLinux || global.params.isFreeBSD || global.params.isOpenBSD || global.params.isSolaris)
        {
            realsize = 12;
            realpad = 2;
            realalignsize = 4;
            c_longsize = 4;
        }
        else if (global.params.isOSX)
        {
            realsize = 16;
            realpad = 6;
            realalignsize = 16;
            c_longsize = 4;
        }
        else if (global.params.isWindows)
        {
            realsize = 10;
            realpad = 0;
            realalignsize = 2;
            reverseCppOverloads = true;
            c_longsize = 4;
            if (ptrsize == 4)
            {
                /* Optlink cannot deal with individual data chunks
                 * larger than 16Mb
                 */
                maxStaticDataSize = 0x100_0000;  // 16Mb
            }
        }
        else
            assert(0);
        if (global.params.is64bit)
        {
            if (global.params.isLinux || global.params.isFreeBSD || global.params.isSolaris)
            {
                realsize = 16;
                realpad = 6;
                realalignsize = 16;
                c_longsize = 8;
            }
            else if (global.params.isOSX)
            {
                c_longsize = 8;
            }
        }
        realislongdouble = true;
        c_long_doublesize = realsize;
        if (global.params.is64bit && global.params.isWindows)
            c_long_doublesize = 8;

        cppExceptions = global.params.isLinux || global.params.isFreeBSD ||
            global.params.isOSX;
    }

    /******************************
     * Return memory alignment size of type.
     */
    extern (C++) static uint alignsize(Type type)
    {
        assert(type.isTypeBasic());
        switch (type.ty)
        {
        case Tfloat80:
        case Timaginary80:
        case Tcomplex80:
            return Target.realalignsize;
        case Tcomplex32:
            if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD || global.params.isOpenBSD || global.params.isSolaris)
                return 4;
            break;
        case Tint64:
        case Tuns64:
        case Tfloat64:
        case Timaginary64:
        case Tcomplex64:
            if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD || global.params.isOpenBSD || global.params.isSolaris)
                return global.params.is64bit ? 8 : 4;
            break;
        default:
            break;
        }
        return cast(uint)type.size(Loc());
    }

    /******************************
     * Return field alignment size of type.
     */
    extern (C++) static uint fieldalign(Type type)
    {
        const size = type.alignsize();

        if ((global.params.is64bit || global.params.isOSX) && (size == 16 || size == 32))
            return size;

        return (8 < size) ? 8 : size;
    }

    /***********************************
     * Return size of OS critical section.
     * NOTE: can't use the sizeof() calls directly since cross compiling is
     * supported and would end up using the host sizes rather than the target
     * sizes.
     */
    extern (C++) static uint critsecsize()
    {
        if (global.params.isWindows)
        {
            // sizeof(CRITICAL_SECTION) for Windows.
            return global.params.isLP64 ? 40 : 24;
        }
        else if (global.params.isLinux)
        {
            // sizeof(pthread_mutex_t) for Linux.
            if (global.params.is64bit)
                return global.params.isLP64 ? 40 : 32;
            else
                return global.params.isLP64 ? 40 : 24;
        }
        else if (global.params.isFreeBSD)
        {
            // sizeof(pthread_mutex_t) for FreeBSD.
            return global.params.isLP64 ? 8 : 4;
        }
        else if (global.params.isOpenBSD)
        {
            // sizeof(pthread_mutex_t) for OpenBSD.
            return global.params.isLP64 ? 8 : 4;
        }
        else if (global.params.isOSX)
        {
            // sizeof(pthread_mutex_t) for OSX.
            return global.params.isLP64 ? 64 : 44;
        }
        else if (global.params.isSolaris)
        {
            // sizeof(pthread_mutex_t) for Solaris.
            return 24;
        }
        assert(0);
    }

    /***********************************
     * Returns a Type for the va_list type of the target.
     * NOTE: For Posix/x86_64 this returns the type which will really
     * be used for passing an argument of type va_list.
     */
    extern (C++) static Type va_listType()
    {
        if (global.params.isWindows)
        {
            return Type.tchar.pointerTo();
        }
        else if (global.params.isLinux || global.params.isFreeBSD || global.params.isOpenBSD || global.params.isSolaris || global.params.isOSX)
        {
            if (global.params.is64bit)
            {
                return (new TypeIdentifier(Loc(), Identifier.idPool("__va_list_tag"))).pointerTo();
            }
            else
            {
                return Type.tchar.pointerTo();
            }
        }
        else
        {
            assert(0);
        }
    }

    /**
     * Checks whether the target supports a vector type with total size `sz`
     * (in bytes) and element type `type`.
     *
     * Returns: 0 if the type is supported, or else: 1 if vector types are not
     *     supported on the target at all, 2 if the given size isn't, or 3 if
     *     the element type isn't.
     */
    extern (C++) static int isVectorTypeSupported(int sz, Type type)
    {
        if (!global.params.is64bit && !global.params.isOSX)
            return 1; // not supported
        if (sz != 16 && sz != 32)
            return 2; // wrong size
        switch (type.ty)
        {
        case Tvoid:
        case Tint8:
        case Tuns8:
        case Tint16:
        case Tuns16:
        case Tint32:
        case Tuns32:
        case Tfloat32:
        case Tint64:
        case Tuns64:
        case Tfloat64:
            break;
        default:
            return 3; // wrong base type
        }
        return 0;
    }

    /**
     * Checks whether the target supports operation `op` for vectors of type `type`.
     * For binary ops `t2` is the type of the 2nd operand.
     *
     * Returns:
     *      true if the operation is supported or type is not a vector
     */
    extern (C++) static bool isVectorOpSupported(Type type, TOK op, Type t2 = null)
    {
        import ddmd.tokens;

        if (type.ty != Tvector)
            return true; // not a vector op
        auto tvec = cast(TypeVector) type;

        bool supported;
        switch (op)
        {
        case TOKneg, TOKuadd:
            supported = tvec.isscalar();
            break;

        case TOKlt, TOKgt, TOKle, TOKge, TOKequal, TOKnotequal, TOKidentity, TOKnotidentity:
            supported = false;
            break;

        case TOKshl, TOKshlass, TOKshr, TOKshrass, TOKushr, TOKushrass:
            supported = false;
            break;

        case TOKadd, TOKaddass, TOKmin, TOKminass:
            supported = tvec.isscalar();
            break;

        case TOKmul, TOKmulass:
            // only floats and short[8]/ushort[8] (PMULLW)
            if (tvec.isfloating() || tvec.elementType().size(Loc()) == 2 ||
                // int[4]/uint[4] with SSE4.1 (PMULLD)
                global.params.cpu >= CPU.sse4_1 && tvec.elementType().size(Loc()) == 4)
                supported = true;
            else
                supported = false;
            break;

        case TOKdiv, TOKdivass:
            supported = tvec.isfloating();
            break;

        case TOKmod, TOKmodass:
            supported = false;
            break;

        case TOKand, TOKandass, TOKor, TOKorass, TOKxor, TOKxorass:
            supported = tvec.isintegral();
            break;

        case TOKnot:
            supported = false;
            break;

        case TOKtilde:
            supported = tvec.isintegral();
            break;

        case TOKpow, TOKpowass:
            supported = false;
            break;

        default:
            // import std.stdio : stderr, writeln;
            // stderr.writeln(op);
            assert(0, "unhandled op " ~ Token.toString(op));
        }
        return supported;
    }

    // The maximum size (in bytes) of type accepted by paintAsType.
    enum int paintMaxSize = 64;

    /******************************
     * Encode the given expression, which is assumed to be an rvalue literal
     * as another type for use in CTFE.
     * This corresponds roughly to the idiom *(Type *)&e.
     */
    extern (C++) static Expression paintAsType(Expression e, Type type)
    {
        align(16) ubyte[paintMaxSize] buffer = void;
        const paintSize = (e.type.size() >= type.size()) ? e.type.size() : type.size();
        assert (paintSize <= buffer.length);
        buffer[0 .. cast(size_t) paintSize] = 0;

        paintEncode(e, buffer.ptr);
        return paintDecode(e.loc, type, buffer.ptr);
    }

    /******************************
     * For the given module, perform any post parsing analysis.
     * Certain compiler backends (ie: GDC) have special placeholder
     * modules whose source are empty, but code gets injected
     * immediately after loading.
     */
    extern (C++) static void loadModule(Module m)
    {
    }

    /******************************
     * For the given symbol written to the OutBuffer, apply any
     * target-specific prefixes based on the given linkage.
     */
    extern (C++) static void prefixName(OutBuffer* buf, LINK linkage)
    {
        switch (linkage)
        {
        case LINKcpp:
            if (global.params.isOSX)
                buf.prependbyte('_');
            break;
        default:
            break;
        }
    }

    extern (C++) static const(char)* toCppMangle(Dsymbol s)
    {
        static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
            return toCppMangleItanium(s);
        else static if (TARGET_WINDOS)
            return toCppMangleMSVC(s);
        else
            static assert(0, "fix this");
    }

    extern (C++) static const(char)* cppTypeInfoMangle(ClassDeclaration cd)
    {
        static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
            return cppTypeInfoMangleItanium(cd);
        else static if (TARGET_WINDOS)
            return cppTypeInfoMangleMSVC(cd);
        else
            static assert(0, "fix this");
    }

    /**
     * Return the default system linkage for the target.
     */
    extern (C++) static LINK systemLinkage()
    {
        return global.params.isWindows ? LINKwindows : LINKc;
    }
}

/******************************
 * Private helpers for Target::paintAsType.
 */
// Write the bit patterns representing the value of `e` into `buffer`.
private void paintEncode(Expression e, ubyte* buffer)
{
    ubyte* bp = buffer;
    ArrayLiteralExp arr = null;
    int aLen = 0;
    int ax = 0;
    Expression elem = null;
    int elemSize;

    if (e.type.ty == Tsarray)
    {
        assert (e.op == TOK.TOKarrayliteral);
        arr = cast(ArrayLiteralExp) e;
        aLen = cast(int) arr.elements.dim;
        elemSize = cast(int) (cast(TypeArray) arr.type).next.size();
    }
    else
    {
        elem = e;
        elemSize = cast(int) elem.type.size();
        goto LbasicW;
    }

    while (ax < aLen)
    {
        elem = arr.getElement(ax);
        ++ax;
    LbasicW:
        assert (bp + elemSize <= buffer + Target.paintMaxSize &&
            (cast(size_t) bp) % elemSize == 0 &&
            elemSize == cast(int) elem.type.size());

        if (elem.type.isintegral())
        {
            const value = elem.toInteger();

            final switch (elem.type.ty)
            {
            case Tint8:
            case Tuns8:
                *bp = cast(ubyte) value;
                break;
            case Tint16:
            case Tuns16:
                *(cast(ushort*) bp) = cast(ushort) value;
                break;
            case Tint32:
            case Tuns32:
                *(cast(uint*) bp) = cast(uint) value;
                break;
            case Tint64:
            case Tuns64:
                *(cast(ulong*) bp) = cast(ulong) value;
                break;
            }
        }
        else if (elem.type.isfloating())
        {
            const value = elem.toReal();

            final switch (elem.type.ty)
            {
            case Tfloat32:
                *(cast(float*) bp) = cast(float) value;
                break;
            case Tfloat64:
                *(cast(double*) bp) = cast(double) value;
                break;
            case Tfloat80:
                *(cast(real*) bp) = cast(real) value;
                // Clear the padding area for consistency:
                bp[(Target.realsize - Target.realpad) .. Target.realsize] = 0;
                break;
            }
        }
        else
            assert (0);

        // If host != target endian-ness, swap the byte order for bp[0 .. elemSize] here.
        static if (false)
        {
            const last = elemSize - 1;
            for (size_t x = 0; x <= last; ++x)
                bp[x] = bp[last - x];
        }

        bp += elemSize;
    }
}

// Reinterpret `buffer` as though it was of `type` and copy the value into a new Expression.
private Expression paintDecode(Loc loc, Type type, ubyte* buffer)
{
    ubyte* bp = buffer;
    Expressions* arr;
    int aLen;
    int ax = 0;
    Expression elem = null;
    Type elemType;

    if (type.ty == Tsarray)
    {
        arr = new Expressions();
        aLen = cast(int) (cast(TypeSArray) type).dim.toInteger();
        arr.setDim(aLen);
        elemType = (cast(TypeSArray) type).next;
    }
    else
    {
        arr = null;
        aLen = 1;
        elemType = type;
    }

    int elemSize = cast(int) elemType.size();
    bool asInt = elemType.isintegral();
    assert (asInt || elemType.isfloating());

    while (ax < aLen)
    {
        assert (bp + elemSize <= buffer + Target.paintMaxSize &&
            (cast(size_t) bp) % elemSize == 0);

        // If host != target endian-ness, swap the byte order for bp[0 .. elemSize] here.
        static if (false)
        {
            const last = elemSize - 1;
            for (size_t x = 0; x <= last; ++x)
                bp[x] = bp[last - x];
        }

        if (asInt)
        {
            dinteger_t value;

            final switch (elemType.ty)
            {
            case Tint8:
            case Tuns8:
                value = *bp;
                break;
            case Tint16:
            case Tuns16:
                value = *(cast(ushort*) bp);
                break;
            case Tint32:
            case Tuns32:
                value = *(cast(uint*) bp);
                break;
            case Tint64:
            case Tuns64:
                value = *(cast(ulong*) bp);
                break;
            }

            elem = new IntegerExp(loc, value, elemType);
        }
        else
        {
            real_t value;

            final switch (elemType.ty)
            {
            case Tfloat32:
                value = *(cast(float*) bp);
                break;
            case Tfloat64:
                value = *(cast(double*) bp);
                break;
            case Tfloat80:
                value = *(cast(real*) bp);
                break;
            }

            elem = new RealExp(loc, value, elemType);
        }

        if (arr == null)
            return elem;

        bp += elemSize;
        (*arr)[ax] = elem;
        ++ax;
    }

    auto ret = new ArrayLiteralExp(loc, arr);
    ret.type = type;
    ret.ownedByCtfe = OWNEDctfe;
    return ret;
}
