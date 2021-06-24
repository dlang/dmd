/**
 * Handles target-specific parameters
 *
 * In order to allow for cross compilation, when the compiler produces a binary
 * for a different platform than it is running on, target information needs
 * to be abstracted. This is done in this module, primarily through `Target`.
 *
 * Note:
 * While DMD itself does not support cross-compilation, GDC and LDC do.
 * Hence, this module is (sometimes heavily) modified by them,
 * and contributors should review how their changes affect them.
 *
 * See_Also:
 * - $(LINK2 https://wiki.osdev.org/Target_Triplet, Target Triplets)
 * - $(LINK2 https://github.com/ldc-developers/ldc, LDC repository)
 * - $(LINK2 https://github.com/D-Programming-GDC/gcc, GDC repository)
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/target.d, _target.d)
 * Documentation:  https://dlang.org/phobos/dmd_target.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/target.d
 */

module dmd.target;

import dmd.globals : Param;

enum CPU
{
    x87,
    mmx,
    sse,
    sse2,
    sse3,
    ssse3,
    sse4_1,
    sse4_2,
    avx,                // AVX1 instruction set
    avx2,               // AVX2 instruction set
    avx512,             // AVX-512 instruction set

    // Special values that don't survive past the command line processing
    baseline,           // (default) the minimum capability CPU
    native              // the machine the compiler is being run on
}

Target.OS defaultTargetOS()
{
    version (Windows)
        return Target.OS.Windows;
    else version (linux)
        return Target.OS.linux;
    else version (OSX)
        return Target.OS.OSX;
    else version (FreeBSD)
        return Target.OS.FreeBSD;
    else version (OpenBSD)
        return Target.OS.OpenBSD;
    else version (Solaris)
        return Target.OS.Solaris;
    else version (DragonFlyBSD)
        return Target.OS.DragonFlyBSD;
    else
        static assert(0, "unknown TARGET");
}
////////////////////////////////////////////////////////////////////////////////
/**
 * Describes a back-end target. At present it is incomplete, but in the future
 * it should grow to contain most or all target machine and target O/S specific
 * information.
 *
 * In many cases, calls to sizeof() can't be used directly for getting data type
 * sizes since cross compiling is supported and would end up using the host
 * sizes rather than the target sizes.
 */
extern (C++) struct Target
{
    import dmd.dscope : Scope;
    import dmd.expression : Expression;
    import dmd.func : FuncDeclaration;
    import dmd.globals : LINK, Loc, d_int64;
    import dmd.astenums : TY;
    import dmd.mtype : Type, TypeFunction, TypeTuple;
    import dmd.root.ctfloat : real_t;
    import dmd.statement : Statement;

    /// Bit decoding of the Target.OS
    enum OS : ubyte
    {
        /* These are mutually exclusive; one and only one is set.
         * Match spelling and casing of corresponding version identifiers
         */
        Freestanding = 0,
        linux        = 1,
        Windows      = 2,
        OSX          = 4,
        OpenBSD      = 8,
        FreeBSD      = 0x10,
        Solaris      = 0x20,
        DragonFlyBSD = 0x40,

        // Combination masks
        all = linux | Windows | OSX | OpenBSD | FreeBSD | Solaris | DragonFlyBSD,
        Posix = linux | OSX | OpenBSD | FreeBSD | Solaris | DragonFlyBSD,
    }

    OS os = defaultTargetOS();
    ubyte osMajor;

    // D ABI
    ubyte ptrsize;            /// size of a pointer in bytes
    ubyte realsize;           /// size a real consumes in memory
    ubyte realpad;            /// padding added to the CPU real size to bring it up to realsize
    ubyte realalignsize;      /// alignment for reals
    ubyte classinfosize;      /// size of `ClassInfo`
    ulong maxStaticDataSize;  /// maximum size of static data

    /// C ABI
    TargetC c;

    /// C++ ABI
    TargetCPP cpp;

    /// Objective-C ABI
    TargetObjC objc;

    /// Architecture name
    const(char)[] architectureName;
    CPU cpu = CPU.baseline; // CPU instruction set to target
    bool is64bit = (size_t.sizeof == 8);  // generate 64 bit code for x86_64; true by default for 64 bit dmd
    bool isLP64;            // pointers are 64 bits

    // Environmental
    const(char)[] obj_ext;    /// extension for object files
    const(char)[] lib_ext;    /// extension for static library files
    const(char)[] dll_ext;    /// extension for dynamic library files
    bool run_noext;           /// allow -run sources without extensions
    bool mscoff = false;      // for Win32: write MsCoff object files instead of OMF
    /**
     * Values representing all properties for floating point types
     */
    extern (C++) struct FPTypeProperties(T)
    {
        real_t max;                         /// largest representable value that's not infinity
        real_t min_normal;                  /// smallest representable normalized value that's not 0
        real_t nan;                         /// NaN value
        real_t infinity;                    /// infinity value
        real_t epsilon;                     /// smallest increment to the value 1

        d_int64 dig = T.dig;                /// number of decimal digits of precision
        d_int64 mant_dig = T.mant_dig;      /// number of bits in mantissa
        d_int64 max_exp = T.max_exp;        /// maximum int value such that 2$(SUPERSCRIPT `max_exp-1`) is representable
        d_int64 min_exp = T.min_exp;        /// minimum int value such that 2$(SUPERSCRIPT `min_exp-1`) is representable as a normalized value
        d_int64 max_10_exp = T.max_10_exp;  /// maximum int value such that 10$(SUPERSCRIPT `max_10_exp` is representable)
        d_int64 min_10_exp = T.min_10_exp;  /// minimum int value such that 10$(SUPERSCRIPT `min_10_exp`) is representable as a normalized value

        extern (D) void initialize()
        {
            max = T.max;
            min_normal = T.min_normal;
            nan = T.nan;
            infinity = T.infinity;
            epsilon = T.epsilon;
        }
    }

    FPTypeProperties!float FloatProperties;     ///
    FPTypeProperties!double DoubleProperties;   ///
    FPTypeProperties!real_t RealProperties;     ///

    private Type tvalist; // cached lazy result of va_listType()

    private const(Param)* params;  // cached reference to global.params

    /**
     * Initialize the Target
     */
    extern (C++) void _init(ref const Param params)
    {
        // is64bit, mscoff and cpu are initialized in parseCommandLine

        this.params = &params;

        FloatProperties.initialize();
        DoubleProperties.initialize();
        RealProperties.initialize();

        isLP64 = is64bit;

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

        if (isLP64)
        {
            ptrsize = 8;
            classinfosize = 0x98; // 152
        }
        if (os & (Target.OS.linux | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.DragonFlyBSD | Target.OS.Solaris))
        {
            realsize = 12;
            realpad = 2;
            realalignsize = 4;
        }
        else if (os == Target.OS.OSX)
        {
            realsize = 16;
            realpad = 6;
            realalignsize = 16;
        }
        else if (os == Target.OS.Windows)
        {
            realsize = 10;
            realpad = 0;
            realalignsize = 2;
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
        if (is64bit)
        {
            if (os & (Target.OS.linux | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.DragonFlyBSD | Target.OS.Solaris))
            {
                realsize = 16;
                realpad = 6;
                realalignsize = 16;
            }
            else if (os == OS.Windows)
            {
                mscoff = true;
            }
        }

        c.initialize(params, this);
        cpp.initialize(params, this);
        objc.initialize(params, this);

        if (is64bit)
            architectureName = "X86_64";
        else
            architectureName = "X86";

        if (os == Target.OS.Windows)
        {
            obj_ext = "obj";
            lib_ext = "lib";
            dll_ext = "dll";
            run_noext = false;
        }
        else if (os & (Target.OS.linux | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.DragonFlyBSD | Target.OS.Solaris | Target.OS.OSX))
        {
            obj_ext = "o";
            lib_ext = "a";
            if (os == Target.OS.OSX)
                dll_ext = "dylib";
            else
                dll_ext = "so";
            run_noext = true;
        }
        else
            assert(0, "unknown environment");
    }

    /**
     * Determine the instruction set to be used
     */
    void setCPU()
    {
        if(!isXmmSupported())
        {
            cpu = CPU.x87;   // cannot support other instruction sets
            return;
        }
        switch (cpu)
        {
            case CPU.baseline:
                cpu = CPU.sse2;
                break;

            case CPU.native:
            {
                import core.cpuid;
                cpu = core.cpuid.avx2 ? CPU.avx2 :
                      core.cpuid.avx  ? CPU.avx  :
                                        CPU.sse2;
                break;
            }
            default:
                break;
        }
    }

    void setTriple(const ref Triple triple)
    {
        cpu     = triple.cpu;
        is64bit = triple.is64bit;
        isLP64  = triple.isLP64;
        os      = triple.os;
        osMajor = triple.osMajor;
        c.runtime   = triple.cenv;
        cpp.runtime = triple.cppenv;
    }
    /**
     * Add predefined global identifiers that are determied by the target
     */
    void addPredefinedGlobalIdentifiers() const
    {
        import dmd.cond : VersionCondition;

        alias predef = VersionCondition.addPredefinedGlobalIdent;
        if (cpu >= CPU.sse2)
        {
            predef("D_SIMD");
            if (cpu >= CPU.avx)
                predef("D_AVX");
            if (cpu >= CPU.avx2)
                predef("D_AVX2");
        }
        if (os & OS.Posix)
            predef("Posix");
        if (os & (OS.linux | OS.FreeBSD | OS.OpenBSD | OS.DragonFlyBSD | OS.Solaris))
            predef("ELFv1");
        switch (os)
        {
            case OS.Freestanding: { predef("FreeStanding"); break; }
            case OS.linux:        { predef("linux");        break; }
            case OS.Windows:      { predef("Windows");      break; }
            case OS.OpenBSD:      { predef("OpenBSD");      break; }
            case OS.DragonFlyBSD: { predef("DragonFlyBSD"); break; }
            case OS.Solaris:      { predef("Solaris");      break; }
            case OS.OSX:
            {
                predef("OSX");
                // For legacy compatibility
                predef("darwin");
                break;
            }
            case OS.FreeBSD:
            {
                predef("FreeBSD");
                switch (osMajor)
                {
                    case 10: predef("FreeBSD_10");  break;
                    case 11: predef("FreeBSD_11"); break;
                    case 12: predef("FreeBSD_12"); break;
                    default: predef("FreeBSD_11"); break;
                }
                break;
            }
            default: assert(0);
        }
        c.addRuntimePredefinedGlobalIdent();
        cpp.addRuntimePredefinedGlobalIdent();
        if (is64bit)
        {
            VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86_64");
            VersionCondition.addPredefinedGlobalIdent("X86_64");
            if (os & OS.Windows)
            {
                VersionCondition.addPredefinedGlobalIdent("Win64");
            }
        }
        else
        {
            VersionCondition.addPredefinedGlobalIdent("D_InlineAsm"); //legacy
            VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86");
            VersionCondition.addPredefinedGlobalIdent("X86");
            if (os == OS.Windows)
            {
                VersionCondition.addPredefinedGlobalIdent("Win32");
            }
        }
        if (isLP64)
            VersionCondition.addPredefinedGlobalIdent("D_LP64");
        else if (is64bit)
            VersionCondition.addPredefinedGlobalIdent("X32");
    }
    /**
     * Deinitializes the global state of the compiler.
     *
     * This can be used to restore the state set by `_init` to its original
     * state.
     */
    void deinitialize()
    {
        this = this.init;
    }

    /**
     * Requested target memory alignment size of the given type.
     * Params:
     *      type = type to inspect
     * Returns:
     *      alignment in bytes
     */
    extern (C++) uint alignsize(Type type)
    {
        assert(type.isTypeBasic());
        switch (type.ty)
        {
        case TY.Tfloat80:
        case TY.Timaginary80:
        case TY.Tcomplex80:
            return target.realalignsize;
        case TY.Tcomplex32:
            if (os & Target.OS.Posix)
                return 4;
            break;
        case TY.Tint64:
        case TY.Tuns64:
        case TY.Tfloat64:
        case TY.Timaginary64:
        case TY.Tcomplex64:
            if (os & Target.OS.Posix)
                return is64bit ? 8 : 4;
            break;
        default:
            break;
        }
        return cast(uint)type.size(Loc.initial);
    }

    /**
     * Requested target field alignment size of the given type.
     * Params:
     *      type = type to inspect
     * Returns:
     *      alignment in bytes
     */
    extern (C++) uint fieldalign(Type type)
    {
        const size = type.alignsize();

        if ((is64bit || os == Target.OS.OSX) && (size == 16 || size == 32))
            return size;

        return (8 < size) ? 8 : size;
    }

    /**
     * Type for the `va_list` type for the target; e.g., required for `_argptr`
     * declarations.
     * NOTE: For Posix/x86_64 this returns the type which will really
     * be used for passing an argument of type va_list.
     * Returns:
     *      `Type` that represents `va_list`.
     */
    extern (C++) Type va_listType(const ref Loc loc, Scope* sc)
    {
        if (tvalist)
            return tvalist;

        if (os == Target.OS.Windows)
        {
            tvalist = Type.tchar.pointerTo();
        }
        else if (os & Target.OS.Posix)
        {
            if (is64bit)
            {
                import dmd.identifier : Identifier;
                import dmd.mtype : TypeIdentifier;
                import dmd.typesem : typeSemantic;
                tvalist = new TypeIdentifier(Loc.initial, Identifier.idPool("__va_list_tag")).pointerTo();
                tvalist = typeSemantic(tvalist, loc, sc);
            }
            else
            {
                tvalist = Type.tchar.pointerTo();
            }
        }
        else
        {
            assert(0);
        }

        return tvalist;
    }

    /**
     * Checks whether the target supports a vector type.
     * Params:
     *      sz   = vector type size in bytes
     *      type = vector element type
     * Returns:
     *      0   vector type is supported,
     *      1   vector type is not supported on the target at all
     *      2   vector element type is not supported
     *      3   vector size is not supported
     */
    extern (C++) int isVectorTypeSupported(int sz, Type type)
    {
        if (!isXmmSupported())
            return 1; // not supported

        switch (type.ty)
        {
        case TY.Tvoid:
        case TY.Tint8:
        case TY.Tuns8:
        case TY.Tint16:
        case TY.Tuns16:
        case TY.Tint32:
        case TY.Tuns32:
        case TY.Tfloat32:
        case TY.Tint64:
        case TY.Tuns64:
        case TY.Tfloat64:
            break;
        default:
            return 2; // wrong base type
        }

        // Whether a vector is really supported depends on the CPU being targeted.
        if (sz == 16)
        {
            switch (type.ty)
            {
            case TY.Tint32:
            case TY.Tuns32:
            case TY.Tfloat32:
                if (cpu < CPU.sse)
                    return 3; // no SSE vector support
                break;

            case TY.Tvoid:
            case TY.Tint8:
            case TY.Tuns8:
            case TY.Tint16:
            case TY.Tuns16:
            case TY.Tint64:
            case TY.Tuns64:
            case TY.Tfloat64:
                if (cpu < CPU.sse2)
                    return 3; // no SSE2 vector support
                break;

            default:
                assert(0);
            }
        }
        else if (sz == 32)
        {
            if (cpu < CPU.avx)
                return 3; // no AVX vector support
        }
        else
            return 3; // wrong size

        return 0;
    }

    /**
     * Checks whether the target supports the given operation for vectors.
     * Params:
     *      type = target type of operation
     *      op   = the unary or binary op being done on the `type`
     *      t2   = type of second operand if `op` is a binary operation
     * Returns:
     *      true if the operation is supported or type is not a vector
     */
    extern (C++) bool isVectorOpSupported(Type type, uint op, Type t2 = null)
    {
        import dmd.tokens : TOK, Token;

        auto tvec = type.isTypeVector();
        if (tvec is null)
            return true; // not a vector op
        const vecsize = cast(int)tvec.basetype.size();
        const elemty = cast(int)tvec.elementType().ty;

        // Only operations on these sizes are supported (see isVectorTypeSupported)
        if (vecsize != 16 && vecsize != 32)
            return false;

        bool supported = false;
        switch (op)
        {
        case TOK.uadd:
            // Expression is a no-op, supported everywhere.
            supported = tvec.isscalar();
            break;

        case TOK.negate:
            if (vecsize == 16)
            {
                // float[4] negate needs SSE support ({V}SUBPS)
                if (elemty == TY.Tfloat32 && cpu >= CPU.sse)
                    supported = true;
                // double[2] negate needs SSE2 support ({V}SUBPD)
                else if (elemty == TY.Tfloat64 && cpu >= CPU.sse2)
                    supported = true;
                // (u)byte[16]/short[8]/int[4]/long[2] negate needs SSE2 support ({V}PSUB[BWDQ])
                else if (tvec.isintegral() && cpu >= CPU.sse2)
                    supported = true;
            }
            else if (vecsize == 32)
            {
                // float[8]/double[4] negate needs AVX support (VSUBP[SD])
                if (tvec.isfloating() && cpu >= CPU.avx)
                    supported = true;
                // (u)byte[32]/short[16]/int[8]/long[4] negate needs AVX2 support (VPSUB[BWDQ])
                else if (tvec.isintegral() && cpu >= CPU.avx2)
                    supported = true;
            }
            break;

        case TOK.lessThan, TOK.greaterThan, TOK.lessOrEqual, TOK.greaterOrEqual, TOK.equal, TOK.notEqual, TOK.identity, TOK.notIdentity:
            supported = false;
            break;

        case TOK.leftShift, TOK.leftShiftAssign, TOK.rightShift, TOK.rightShiftAssign, TOK.unsignedRightShift, TOK.unsignedRightShiftAssign:
            supported = false;
            break;

        case TOK.add, TOK.addAssign, TOK.min, TOK.minAssign:
            if (vecsize == 16)
            {
                // float[4] add/sub needs SSE support ({V}ADDPS, {V}SUBPS)
                if (elemty == TY.Tfloat32 && cpu >= CPU.sse)
                    supported = true;
                // double[2] add/sub needs SSE2 support ({V}ADDPD, {V}SUBPD)
                else if (elemty == TY.Tfloat64 && cpu >= CPU.sse2)
                    supported = true;
                // (u)byte[16]/short[8]/int[4]/long[2] add/sub needs SSE2 support ({V}PADD[BWDQ], {V}PSUB[BWDQ])
                else if (tvec.isintegral() && cpu >= CPU.sse2)
                    supported = true;
            }
            else if (vecsize == 32)
            {
                // float[8]/double[4] add/sub needs AVX support (VADDP[SD], VSUBP[SD])
                if (tvec.isfloating() && cpu >= CPU.avx)
                    supported = true;
                // (u)byte[32]/short[16]/int[8]/long[4] add/sub needs AVX2 support (VPADD[BWDQ], VPSUB[BWDQ])
                else if (tvec.isintegral() && cpu >= CPU.avx2)
                    supported = true;
            }
            break;

        case TOK.mul, TOK.mulAssign:
            if (vecsize == 16)
            {
                // float[4] multiply needs SSE support ({V}MULPS)
                if (elemty == TY.Tfloat32 && cpu >= CPU.sse)
                    supported = true;
                // double[2] multiply needs SSE2 support ({V}MULPD)
                else if (elemty == TY.Tfloat64 && cpu >= CPU.sse2)
                    supported = true;
                // (u)short[8] multiply needs SSE2 support ({V}PMULLW)
                else if ((elemty == TY.Tint16 || elemty == TY.Tuns16) && cpu >= CPU.sse2)
                    supported = true;
                // (u)int[4] multiply needs SSE4.1 support ({V}PMULLD)
                else if ((elemty == TY.Tint32 || elemty == TY.Tuns32) && cpu >= CPU.sse4_1)
                    supported = true;
            }
            else if (vecsize == 32)
            {
                // float[8]/double[4] multiply needs AVX support (VMULP[SD])
                if (tvec.isfloating() && cpu >= CPU.avx)
                    supported = true;
                // (u)short[16] multiply needs AVX2 support (VPMULLW)
                else if ((elemty == TY.Tint16 || elemty == TY.Tuns16) && cpu >= CPU.avx2)
                    supported = true;
                // (u)int[8] multiply needs AVX2 support (VPMULLD)
                else if ((elemty == TY.Tint32 || elemty == TY.Tuns32) && cpu >= CPU.avx2)
                    supported = true;
            }
            break;

        case TOK.div, TOK.divAssign:
            if (vecsize == 16)
            {
                // float[4] divide needs SSE support ({V}DIVPS)
                if (elemty == TY.Tfloat32 && cpu >= CPU.sse)
                    supported = true;
                // double[2] divide needs SSE2 support ({V}DIVPD)
                else if (elemty == TY.Tfloat64 && cpu >= CPU.sse2)
                    supported = true;
            }
            else if (vecsize == 32)
            {
                // float[8]/double[4] multiply needs AVX support (VDIVP[SD])
                if (tvec.isfloating() && cpu >= CPU.avx)
                    supported = true;
            }
            break;

        case TOK.mod, TOK.modAssign:
            supported = false;
            break;

        case TOK.and, TOK.andAssign, TOK.or, TOK.orAssign, TOK.xor, TOK.xorAssign:
            // (u)byte[16]/short[8]/int[4]/long[2] bitwise ops needs SSE2 support ({V}PAND, {V}POR, {V}PXOR)
            if (vecsize == 16 && tvec.isintegral() && cpu >= CPU.sse2)
                supported = true;
            // (u)byte[32]/short[16]/int[8]/long[4] bitwise ops needs AVX2 support (VPAND, VPOR, VPXOR)
            else if (vecsize == 32 && tvec.isintegral() && cpu >= CPU.avx2)
                supported = true;
            break;

        case TOK.not:
            supported = false;
            break;

        case TOK.tilde:
            // (u)byte[16]/short[8]/int[4]/long[2] logical exclusive needs SSE2 support ({V}PXOR)
            if (vecsize == 16 && tvec.isintegral() && cpu >= CPU.sse2)
                supported = true;
            // (u)byte[32]/short[16]/int[8]/long[4] logical exclusive needs AVX2 support (VPXOR)
            else if (vecsize == 32 && tvec.isintegral() && cpu >= CPU.avx2)
                supported = true;
            break;

        case TOK.pow, TOK.powAssign:
            supported = false;
            break;

        default:
            // import std.stdio : stderr, writeln;
            // stderr.writeln(op);
            assert(0, "unhandled op " ~ Token.toString(cast(TOK)op));
        }
        return supported;
    }

    /**
     * Default system linkage for the target.
     * Returns:
     *      `LINK` to use for `extern(System)`
     */
    extern (C++) LINK systemLinkage()
    {
        return os == Target.OS.Windows ? LINK.windows : LINK.c;
    }

    /**
     * Describes how an argument type is passed to a function on target.
     * Params:
     *      t = type to break down
     * Returns:
     *      tuple of types if type is passed in one or more registers
     *      empty tuple if type is always passed on the stack
     *      null if the type is a `void` or argtypes aren't supported by the target
     */
    extern (C++) TypeTuple toArgTypes(Type t)
    {
        import dmd.argtypes_x86 : toArgTypes_x86;
        import dmd.argtypes_sysv_x64 : toArgTypes_sysv_x64;
        if (is64bit)
        {
            // no argTypes for Win64 yet
            return isPOSIX ? toArgTypes_sysv_x64(t) : null;
        }
        return toArgTypes_x86(t);
    }

    /**
     * Determine return style of function - whether in registers or
     * through a hidden pointer to the caller's stack.
     * Params:
     *   tf = function type to check
     *   needsThis = true if the function type is for a non-static member function
     * Returns:
     *   true if return value from function is on the stack
     */
    extern (C++) bool isReturnOnStack(TypeFunction tf, bool needsThis)
    {
        import dmd.id : Id;
        import dmd.argtypes_sysv_x64 : toArgTypes_sysv_x64;

        if (tf.isref)
        {
            //printf("  ref false\n");
            return false;                 // returns a pointer
        }

        Type tn = tf.next;
        if (auto te = tn.isTypeEnum())
        {
            if (te.sym.isSpecial())
            {
                // Special enums with target-specific return style
                if (te.sym.ident == Id.__c_complex_float)
                    tn = Type.tcomplex32.castMod(tn.mod);
                else if (te.sym.ident == Id.__c_complex_double)
                    tn = Type.tcomplex64.castMod(tn.mod);
                else if (te.sym.ident == Id.__c_complex_real)
                    tn = Type.tcomplex80.castMod(tn.mod);
            }
        }
        tn = tn.toBasetype();
        //printf("tn = %s\n", tn.toChars());
        const sz = tn.size();
        Type tns = tn;

        if (os == Target.OS.Windows && is64bit)
        {
            // http://msdn.microsoft.com/en-us/library/7572ztz4.aspx
            if (tns.ty == TY.Tcomplex32)
                return true;
            if (tns.isscalar())
                return false;

            tns = tns.baseElemOf();
            if (auto ts = tns.isTypeStruct())
            {
                auto sd = ts.sym;
                if (tf.linkage == LINK.cpp && needsThis)
                    return true;
                if (!sd.isPOD() || sz > 8)
                    return true;
                if (sd.fields.dim == 0)
                    return true;
            }
            if (sz <= 16 && !(sz & (sz - 1)))
                return false;
            return true;
        }
        else if (os == Target.OS.Windows && mscoff)
        {
            Type tb = tns.baseElemOf();
            if (tb.ty == TY.Tstruct)
            {
                if (tf.linkage == LINK.cpp && needsThis)
                    return true;
            }
        }
        else if (is64bit && isPOSIX)
        {
            TypeTuple tt = toArgTypes_sysv_x64(tn);
            if (!tt)
                return false; // void
            else
                return !tt.arguments.dim;
        }

    Lagain:
        if (tns.ty == TY.Tsarray)
        {
            tns = tns.baseElemOf();
            if (tns.ty != TY.Tstruct)
            {
    L2:
                if (os == Target.OS.linux && tf.linkage != LINK.d && !is64bit)
                {
                                                    // 32 bit C/C++ structs always on stack
                }
                else
                {
                    switch (sz)
                    {
                        case 1:
                        case 2:
                        case 4:
                        case 8:
                            //printf("  sarray false\n");
                            return false; // return small structs in regs
                                                // (not 3 byte structs!)
                        default:
                            break;
                    }
                }
                //printf("  sarray true\n");
                return true;
            }
        }

        if (auto ts = tns.isTypeStruct())
        {
            auto sd = ts.sym;
            if (os == Target.OS.linux && tf.linkage != LINK.d && !is64bit)
            {
                //printf("  2 true\n");
                return true;            // 32 bit C/C++ structs always on stack
            }
            if (os == Target.OS.Windows && tf.linkage == LINK.cpp && !is64bit &&
                     sd.isPOD() && sd.ctor)
            {
                // win32 returns otherwise POD structs with ctors via memory
                return true;
            }
            if (sd.numArgTypes() == 1)
            {
                tns = sd.argType(0);
                if (tns.ty != TY.Tstruct)
                    goto L2;
                goto Lagain;
            }
            else if (is64bit && sd.numArgTypes() == 0)
                return true;
            else if (sd.isPOD())
            {
                switch (sz)
                {
                    case 1:
                    case 2:
                    case 4:
                    case 8:
                        //printf("  3 false\n");
                        return false;     // return small structs in regs
                                            // (not 3 byte structs!)
                    case 16:
                        if (os & Target.OS.Posix && is64bit)
                           return false;
                        break;

                    default:
                        break;
                }
            }
            //printf("  3 true\n");
            return true;
        }
        else if (os & Target.OS.Posix &&
                 (tf.linkage == LINK.c || tf.linkage == LINK.cpp) &&
                 tns.iscomplex())
        {
            if (tns.ty == TY.Tcomplex32)
                return false;     // in EDX:EAX, not ST1:ST0
            else
                return true;
        }
        else if (os == Target.OS.Windows &&
                 !is64bit &&
                 tf.linkage == LINK.cpp &&
                 tf.isfloating())
        {
            /* See DMC++ function exp2_retmethod()
             * https://github.com/DigitalMars/Compiler/blob/master/dm/src/dmc/dexp2.d#L149
             */
            return true;
        }
        else
        {
            //assert(sz <= 16);
            //printf("  4 false\n");
            return false;
        }
    }

    /***
     * Determine the size a value of type `t` will be when it
     * is passed on the function parameter stack.
     * Params:
     *  loc = location to use for error messages
     *  t = type of parameter
     * Returns:
     *  size used on parameter stack
     */
    extern (C++) ulong parameterSize(const ref Loc loc, Type t)
    {
        if (!is64bit &&
            (os & (Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.OSX)))
        {
            /* These platforms use clang, which regards a struct
             * with size 0 as being of size 0 on the parameter stack,
             * even while sizeof(struct) is 1.
             * It's an ABI incompatibility with gcc.
             */
            if (auto ts = t.isTypeStruct())
            {
                if (ts.sym.hasNoFields)
                    return 0;
            }
        }
        const sz = t.size(loc);
        return is64bit ? (sz + 7) & ~7 : (sz + 3) & ~3;
    }

    /**
     * Decides whether an `in` parameter of the specified POD type is to be
     * passed by reference or by value. To be used with `-preview=in` only!
     * Params:
     *  t = type of the `in` parameter, must be a POD
     * Returns:
     *  `true` if the `in` parameter is to be passed by reference
     */
    extern (C++) bool preferPassByRef(Type t)
    {
        const size = t.size();
        if (is64bit)
        {
            if (os == Target.OS.Windows)
            {
                // Win64 special case: by-value for slices and delegates due to
                // high number of usages in druntime/Phobos (compiled without
                // -preview=in but supposed to link against -preview=in code)
                const ty = t.toBasetype().ty;
                if (ty == TY.Tarray || ty == TY.Tdelegate)
                    return false;

                // If size is larger than 8 or not a power-of-2, the Win64 ABI
                // would require a hidden reference anyway.
                return size > 8
                    || (size > 0 && (size & (size - 1)) != 0);
            }
            else // SysV x86_64 ABI
            {
                // Prefer a ref if the POD cannot be passed in registers, i.e.,
                // would be passed on the stack, *and* the size is > 16.
                if (size <= 16)
                    return false;

                TypeTuple getArgTypes()
                {
                    import dmd.astenums : Sizeok;
                    if (auto ts = t.toBasetype().isTypeStruct())
                    {
                        auto sd = ts.sym;
                        assert(sd.sizeok == Sizeok.done);
                        return sd.argTypes;
                    }
                    return toArgTypes(t);
                }

                TypeTuple argTypes = getArgTypes();
                assert(argTypes !is null, "size == 0 should already be handled");
                return argTypes.arguments.length == 0; // cannot be passed in registers
            }
        }
        else // 32-bit x86 ABI
        {
            // Prefer a ref if the size is > 2 machine words.
            return size > 8;
        }
    }

    // this guarantees `getTargetInfo` and `allTargetInfos` remain in sync
    private enum TargetInfoKeys
    {
        cppRuntimeLibrary,
        cppStd,
        floatAbi,
        objectFormat,
    }

    /**
     * Get targetInfo by key
     * Params:
     *  name = name of targetInfo to get
     *  loc = location to use for error messages
     * Returns:
     *  Expression for the requested targetInfo
     */
    extern (C++) Expression getTargetInfo(const(char)* name, const ref Loc loc)
    {
        import dmd.expression : IntegerExp, StringExp;
        import dmd.root.string : toDString;

        StringExp stringExp(const(char)[] sval)
        {
            return new StringExp(loc, sval);
        }

        switch (name.toDString) with (TargetInfoKeys)
        {
            case objectFormat.stringof:
                if (os == Target.OS.Windows)
                    return stringExp(mscoff ? "coff" : "omf");
                else if (os == Target.OS.OSX)
                    return stringExp("macho");
                else
                    return stringExp("elf");
            case floatAbi.stringof:
                return stringExp("hard");
            case cppRuntimeLibrary.stringof:
                if (os == Target.OS.Windows)
                {
                    if (mscoff)
                        return stringExp(params.mscrtlib);
                    return stringExp("snn");
                }
                return stringExp("");
            case cppStd.stringof:
                return new IntegerExp(params.cplusplus);

            default:
                return null;
        }
    }

    /**
     * Params:
     *  tf = type of function being called
     * Returns: `true` if the callee invokes destructors for arguments.
     */
    extern (C++) bool isCalleeDestroyingArgs(TypeFunction tf)
    {
        // On windows, the callee destroys arguments always regardless of function linkage,
        // and regardless of whether the caller or callee cleans the stack.
        return os == Target.OS.Windows ||
               // C++ on non-Windows platforms has the caller destroying the arguments
               tf.linkage != LINK.cpp;
    }

    /**
     * Returns true if the implementation for object monitors is always defined
     * in the D runtime library (rt/monitor_.d).
     * Params:
     *      fd = function with `synchronized` storage class.
     *      fbody = entire function body of `fd`
     * Returns:
     *      `false` if the target backend handles synchronizing monitors.
     */
    extern (C++) bool libraryObjectMonitors(FuncDeclaration fd, Statement fbody)
    {
        if (!is64bit && os == Target.OS.Windows && !fd.isStatic() && !fbody.usesEH() && !params.trace)
        {
            /* The back end uses the "jmonitor" hack for syncing;
             * no need to do the sync in the library.
             */
            return false;
        }
        return true;
    }

    ////////////////////////////////////////////////////////////////////////////
    /* All functions after this point are extern (D), as they are only relevant
     * for targets of DMD, and should not be used in front-end code.
     */

    /******************
     * Returns:
     *  true if xmm usage is supported
     */
    extern (D) bool isXmmSupported()
    {
        return is64bit || os == Target.OS.OSX;
    }

    /**
     * Returns:
     *  true if generating code for POSIX
     */
    extern (D) @property bool isPOSIX() scope const nothrow @nogc
    out(result) { assert(result || os == Target.OS.Windows); }
    do
    {
        return (os & Target.OS.Posix) != 0;
    }
}

////////////////////////////////////////////////////////////////////////////////
/**
 * Functions and variables specific to interfacing with extern(C) ABI.
 */
struct TargetC
{
    enum Runtime : ubyte
    {
        Unspecified,
        Bionic,
        DigitalMars,
        Glibc,
        Microsoft,
        Musl,
        Newlib,
        UClibc,
        WASI,
    }

    ubyte longsize;           /// size of a C `long` or `unsigned long` type
    ubyte long_doublesize;    /// size of a C `long double`
    ubyte wchar_tsize;        /// size of a C `wchar_t` type
    Runtime runtime;          /// vendor of the C runtime to link against

    extern (D) void initialize(ref const Param params, ref const Target target)
    {
        const os = target.os;
        if (os & (Target.OS.linux | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.DragonFlyBSD | Target.OS.Solaris))
            longsize = 4;
        else if (os == Target.OS.OSX)
            longsize = 4;
        else if (os == Target.OS.Windows)
            longsize = 4;
        else
            assert(0);
        if (target.is64bit)
        {
            if (os & (Target.OS.linux | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.DragonFlyBSD | Target.OS.Solaris))
                longsize = 8;
            else if (os == Target.OS.OSX)
                longsize = 8;
        }
        if (target.is64bit && os == Target.OS.Windows)
            long_doublesize = 8;
        else
            long_doublesize = target.realsize;
        if (os == Target.OS.Windows)
            wchar_tsize = 2;
        else
            wchar_tsize = 4;

        if (os == Target.OS.Windows)
            runtime = target.mscoff ? Runtime.Microsoft : Runtime.DigitalMars;
        else if (os == Target.OS.linux)
        {
            // Note: This is overridden later by `-target=<triple>` if supplied.
            // For now, choose the sensible default.
            version (CRuntime_Musl)
                runtime = Runtime.Musl;
            else
                runtime = Runtime.Glibc;
        }
    }

    void addRuntimePredefinedGlobalIdent() const
    {
        import dmd.cond : VersionCondition;

        alias predef = VersionCondition.addPredefinedGlobalIdent;
        with (Runtime) switch (runtime)
        {
        default:
        case Unspecified: return;
        case Bionic:      return predef("CRuntime_Bionic");
        case DigitalMars: return predef("CRuntime_DigitalMars");
        case Glibc:       return predef("CRuntime_Glibc");
        case Microsoft:   return predef("CRuntime_Microsoft");
        case Musl:        return predef("CRuntime_Musl");
        case Newlib:      return predef("CRuntime_Newlib");
        case UClibc:      return predef("CRuntime_UClibc");
        case WASI:        return predef("CRuntime_WASI");
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
/**
 * Functions and variables specific to interface with extern(C++) ABI.
 */
struct TargetCPP
{
    import dmd.dsymbol : Dsymbol;
    import dmd.dclass : ClassDeclaration;
    import dmd.func : FuncDeclaration;
    import dmd.mtype : Parameter, Type;

    enum Runtime : ubyte
    {
        Unspecified,
        Clang,
        DigitalMars,
        Gcc,
        Microsoft,
        Sun
    }
    bool reverseOverloads;    /// set if overloaded functions are grouped and in reverse order (such as in dmc and cl)
    bool exceptions;          /// set if catching C++ exceptions is supported
    bool twoDtorInVtable;     /// target C++ ABI puts deleting and non-deleting destructor into vtable
    bool wrapDtorInExternD;   /// set if C++ dtors require a D wrapper to be callable from runtime
    Runtime runtime;          /// vendor of the C++ runtime to link against

    extern (D) void initialize(ref const Param params, ref const Target target)
    {
        const os = target.os;
        if (os & (Target.OS.linux | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.DragonFlyBSD | Target.OS.Solaris))
            twoDtorInVtable = true;
        else if (os == Target.OS.OSX)
            twoDtorInVtable = true;
        else if (os == Target.OS.Windows)
            reverseOverloads = true;
        else
            assert(0);
        exceptions = (os & Target.OS.Posix) != 0;
        if (os == Target.OS.Windows)
            runtime = target.mscoff ? Runtime.Microsoft : Runtime.DigitalMars;
        else if (os & (Target.OS.linux | Target.OS.DragonFlyBSD))
            runtime = Runtime.Gcc;
        else if (os & (Target.OS.OSX | Target.OS.FreeBSD | Target.OS.OpenBSD))
            runtime = Runtime.Clang;
        else if (os == Target.OS.Solaris)
            runtime = Runtime.Sun;
        else
            assert(0);
        // C++ and D ABI incompatible on all (?) x86 32-bit platforms
        wrapDtorInExternD = !target.is64bit;
    }

    /**
     * Mangle the given symbol for C++ ABI.
     * Params:
     *      s = declaration with C++ linkage
     * Returns:
     *      string mangling of symbol
     */
    extern (C++) const(char)* toMangle(Dsymbol s)
    {
        import dmd.cppmangle : toCppMangleItanium;
        import dmd.cppmanglewin : toCppMangleMSVC;

        if (target.os & (Target.OS.linux | Target.OS.OSX | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.Solaris | Target.OS.DragonFlyBSD))
            return toCppMangleItanium(s);
        if (target.os == Target.OS.Windows)
            return toCppMangleMSVC(s);
        else
            assert(0, "fix this");
    }

    /**
     * Get RTTI mangling of the given class declaration for C++ ABI.
     * Params:
     *      cd = class with C++ linkage
     * Returns:
     *      string mangling of C++ typeinfo
     */
    extern (C++) const(char)* typeInfoMangle(ClassDeclaration cd)
    {
        import dmd.cppmangle : cppTypeInfoMangleItanium;
        import dmd.cppmanglewin : cppTypeInfoMangleMSVC;

        if (target.os & (Target.OS.linux | Target.OS.OSX | Target.OS.FreeBSD | Target.OS.OpenBSD | Target.OS.Solaris | Target.OS.DragonFlyBSD))
            return cppTypeInfoMangleItanium(cd);
        if (target.os == Target.OS.Windows)
            return cppTypeInfoMangleMSVC(cd);
        else
            assert(0, "fix this");
    }

    /**
     * Get mangle name of a this-adjusting thunk to the given function
     * declaration for C++ ABI.
     * Params:
     *      fd = function with C++ linkage
     *      offset = call offset to the vptr
     * Returns:
     *      string mangling of C++ thunk, or null if unhandled
     */
    extern (C++) const(char)* thunkMangle(FuncDeclaration fd, int offset)
    {
        return null;
    }

    /**
     * Gets vendor-specific type mangling for C++ ABI.
     * Params:
     *      t = type to inspect
     * Returns:
     *      string if type is mangled specially on target
     *      null if unhandled
     */
    extern (C++) const(char)* typeMangle(Type t)
    {
        return null;
    }

    /**
     * Get the type that will really be used for passing the given argument
     * to an `extern(C++)` function.
     * Params:
     *      p = parameter to be passed.
     * Returns:
     *      `Type` to use for parameter `p`.
     */
    extern (C++) Type parameterType(Parameter p)
    {
        import dmd.astenums : STC;
        import dmd.globals : LINK;
        import dmd.mtype : ParameterList, TypeDelegate, TypeFunction;
        import dmd.typesem : merge;

        Type t = p.type.merge2();
        if (p.isReference())
            t = t.referenceTo();
        else if (p.storageClass & STC.lazy_)
        {
            // Mangle as delegate
            auto tf = new TypeFunction(ParameterList(), t, LINK.d);
            auto td = new TypeDelegate(tf);
            t = td.merge();
        }
        return t;
    }

    /**
     * Checks whether type is a vendor-specific fundamental type.
     * Params:
     *      t = type to inspect
     *      isFundamental = where to store result
     * Returns:
     *      true if isFundamental was set by function
     */
    extern (C++) bool fundamentalType(const Type t, ref bool isFundamental)
    {
        return false;
    }

    /**
     * Get the starting offset position for fields of an `extern(C++)` class
     * that is derived from the given base class.
     * Params:
     *      baseClass = base class with C++ linkage
     * Returns:
     *      starting offset to lay out derived class fields
     */
    extern (C++) uint derivedClassOffset(ClassDeclaration baseClass)
    {
        // MSVC adds padding between base and derived fields if required.
        if (target.os == Target.OS.Windows)
            return (baseClass.structsize + baseClass.alignsize - 1) & ~(baseClass.alignsize - 1);
        else
            return baseClass.structsize;
    }

    void addRuntimePredefinedGlobalIdent() const
    {
        import dmd.cond : VersionCondition;

        alias predef = VersionCondition.addPredefinedGlobalIdent;
        with (Runtime) switch (runtime)
        {
        default:
        case Unspecified: return;
        case Clang:       return predef("CppRuntime_Clang");
        case DigitalMars: return predef("CppRuntime_DigitalMars");
        case Gcc:         return predef("CppRuntime_Gcc");
        case Microsoft:   return predef("CppRuntime_Microsoft");
        case Sun:         return predef("CppRuntime_Sun");
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
/**
 * Functions and variables specific to interface with extern(Objective-C) ABI.
 */
struct TargetObjC
{
    bool supported;     /// set if compiler can interface with Objective-C

    extern (D) void initialize(ref const Param params, ref const Target target)
    {
        if (target.os == Target.OS.OSX && target.is64bit)
            supported = true;
    }
}

/**
 Sets CPU Operating System, and optionally C/C++ runtime environment from the given triple
 e.g.
    x86_64+avx2-apple-darwin20.3.0
    x86-unknown-linux-musl-clang
    x64-windows-msvc
    x64-pc-windows-msvc
 */
struct Triple
{
    private const(char)[] source;
    CPU               cpu;
    bool              is64bit;
    bool              isLP64;
    Target.OS         os;
    ubyte             osMajor;
    TargetC.Runtime   cenv;
    TargetCPP.Runtime cppenv;

    this(const(char)* _triple)
    {
        import dmd.root.string : toDString, toCStringThen;
        const(char)[] triple = _triple.toDString();
        const(char)[] next()
        {
            size_t i = 0;
            const tmp = triple;
            while (triple.length && triple[0] != '-')
            {
                triple = triple[1 .. $];
                ++i;
            }
            if (triple.length && triple[0] == '-')
            {
                triple = triple[1 .. $];
            }
            return tmp[0 .. i];
        }

        parseArch(next);
        const(char)[] vendorOrOS = next();
        const(char)[] _os;
        if (tryParseVendor(vendorOrOS))
            _os = next();
        else
            _os = vendorOrOS;
        os = parseOS(_os, osMajor);

        const(char)[] _cenv = next();
        if (_cenv.length)
            cenv = parseCEnv(_cenv);
        else if (this.os == Target.OS.Windows)
            cenv = TargetC.Runtime.Microsoft;
        const(char)[] _cppenv = next();
        if (_cppenv.length)
            cppenv = parseCPPEnv(_cppenv);
        else if (this.os == Target.OS.Windows)
            cppenv = TargetCPP.Runtime.Microsoft;
    }
    private extern(D):

    void unknown(const(char)[] unk, const(char)* what)
    {
        import dmd.errors : error;
        import dmd.root.string : toCStringThen;
        import dmd.globals : Loc;
        unk.toCStringThen!(p => error(Loc.initial,"unknown %s `%s` for `-target`", what, p.ptr));
    }

    void parseArch(const(char)[] arch)
    {
        bool matches(const(char)[] str)
        {
            import dmd.root.string : startsWith;
            if (!arch.ptr.startsWith(str))
                return false;
            arch = arch[str.length-1 .. $-1];
            return true;
        }

        if (matches("x86_64"))
            is64bit = true;
        else if (matches("x86"))
            is64bit = false;
        else if (matches("x64"))
            is64bit = true;
        else if (matches("x32"))
        {
            is64bit = true;
            isLP64 = false;
        }
        else
            return unknown(arch, "architecture");

        if (!arch.length)
            return;

        switch (arch)
        {
            case "+sse2": cpu = CPU.sse2; break;
            case "+avx":  cpu = CPU.avx;  break;
            case "+avx2": cpu = CPU.avx2; break;
            default:
                unknown(arch, "architecture feature");
        }
    }

    // try parsing vendor if present
    bool tryParseVendor(const(char)[] vendor)
    {
        switch (vendor)
        {
            case "unknown": return true;
            case "apple":   return true;
            case "pc":      return true;
            case "amd":     return true;
            default:        return false;
        }
    }

    Target.OS parseOS(const(char)[] _os, out ubyte _osMajor)
    {
        bool matches(const(char)[] str)
        {
            import dmd.root.string : startsWith;
            if (!_os.ptr.startsWith(str))
                return false;
            _os = _os[str.length .. $];
            return true;
        }
        if (_os == "freestanding")
            return Target.OS.Freestanding;
        Target.OS os;
        _osMajor = 0;
        if (matches("darwin"))
            os = Target.OS.OSX;
        else if (matches("dragonfly"))
            os =  Target.OS.DragonFlyBSD;
        else if (matches("freebsd"))
            os =  Target.OS.FreeBSD;
        else if (matches("openbsd"))
            os =  Target.OS.OpenBSD;
        else if (matches("linux"))
            os =  Target.OS.linux;
        else if (matches("windows"))
            os =  Target.OS.Windows;
        else
        {
            unknown(_os, "operating system");
            return Target.OS.Freestanding;
        }
        while (_os.length)
        {
            if (!('0' < _os[0] && _os[0] < '9'))
                break;
            osMajor *= 10;
            osMajor = cast(ubyte)((_os[0] - '0') + osMajor);
            _os = _os[1 .. $];
        }
        return os;
    }

    TargetC.Runtime parseCEnv(const(char)[] cenv)
    {
        with (TargetC.Runtime) switch (cenv)
        {
            case "musl":         return Musl;
            case "msvc":         return Microsoft;
            case "bionic":       return Bionic;
            case "digital_mars": return DigitalMars;
            case "newlib":       return Newlib;
            case "uclibc":       return UClibc;
            case "glibc":        return Glibc;
            default:
            {
                unknown(cenv, "C runtime environment");
                return Unspecified;
            }
        }
    }

    TargetCPP.Runtime parseCPPEnv(const(char)[] cppenv)
    {
        with (TargetCPP.Runtime) switch (cppenv)
        {
            case "clang":        return Clang;
            case "gcc":          return Gcc;
            case "msvc":         return Microsoft;
            case "sun":          return Sun;
            case "digital_mars": return DigitalMars;
            default:
            {
                unknown(cppenv, "C++ runtime environment");
                return Unspecified;
            }
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
extern (C++) __gshared Target target;
