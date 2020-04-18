/**
 * D header file for C99.
 *
 * $(C_HEADER_DESCRIPTION pubs.opengroup.org/onlinepubs/009695399/basedefs/_stdarg.h.html, _stdarg.h)
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Hauke Duden
 * Standards: ISO/IEC 9899:1999 (E)
 * Source: $(DRUNTIMESRC core/stdc/_stdarg.d)
 */

module core.stdc.stdarg;

@system:
//@nogc:    // Not yet, need to make TypeInfo's member functions @nogc first
nothrow:

T alignUp(size_t alignment = size_t.sizeof, T)(T base) pure
{
    enum mask = alignment - 1;
    static assert(alignment > 0 && (alignment & mask) == 0, "alignment must be a power of 2");
    auto b = cast(size_t) base;
    b = (b + mask) & ~mask;
    return cast(T) b;
}

unittest
{
    assert(1.alignUp == size_t.sizeof);
    assert(31.alignUp!16 == 32);
    assert(32.alignUp!16 == 32);
    assert(33.alignUp!16 == 48);
    assert((-9).alignUp!8 == -8);
}

version (X86)
{
    /*********************
     * The argument pointer type.
     */
    alias char* va_list;

    /**********
     * Initialize ap.
     * For 32 bit code, parmn should be the last named parameter.
     * For 64 bit code, parmn should be __va_argsave.
     */
    void va_start(T)(out va_list ap, ref T parmn)
    {
        ap = cast(va_list) ((cast(void*) &parmn) + T.sizeof.alignUp);
    }

    /************
     * Retrieve and return the next value that is type T.
     * Should use the other va_arg instead, as this won't work for 64 bit code.
     */
    T va_arg(T)(ref va_list ap)
    {
        T arg = *cast(T*) ap;
        ap += T.sizeof.alignUp;
        return arg;
    }

    /************
     * Retrieve and return the next value that is type T.
     * This is the preferred version.
     */
    void va_arg(T)(ref va_list ap, ref T parmn)
    {
        parmn = *cast(T*) ap;
        ap += T.sizeof.alignUp;
    }

    /*************
     * Retrieve and store through parmn the next value that is of TypeInfo ti.
     * Used when the static type is not known.
     */
    void va_arg()(ref va_list ap, TypeInfo ti, void* parmn)
    {
        // Wait until everyone updates to get TypeInfo.talign
        //auto talign = ti.talign;
        //auto p = cast(void*)(cast(size_t)ap + talign - 1) & ~(talign - 1);
        auto p = ap;
        auto tsize = ti.tsize;
        ap = cast(va_list) (p + tsize.alignUp);
        parmn[0..tsize] = p[0..tsize];
    }

    /***********************
     * End use of ap.
     */
    void va_end(va_list ap)
    {
    }

    ///
    void va_copy(out va_list dest, va_list src)
    {
        dest = src;
    }
}
else version (Windows) // Win64
{   /* Win64 is characterized by all arguments fitting into a register size.
     * Smaller ones are padded out to register size, and larger ones are passed by
     * reference.
     */

    /*********************
     * The argument pointer type.
     */
    alias char* va_list;

    /**********
     * Initialize ap.
     * parmn should be the last named parameter.
     */
    void va_start(T)(out va_list ap, ref T parmn); // Compiler intrinsic

    /************
     * Retrieve and return the next value that is type T.
     */
    T va_arg(T)(ref va_list ap)
    {
        static if (T.sizeof > size_t.sizeof)
            T arg = **cast(T**) ap;
        else
            T arg = *cast(T*) ap;
        ap += size_t.sizeof;
        return arg;
    }

    /************
     * Retrieve and return the next value that is type T.
     * This is the preferred version.
     */
    void va_arg(T)(ref va_list ap, ref T parmn)
    {
        static if (T.sizeof > size_t.sizeof)
            parmn = **cast(T**) ap;
        else
            parmn = *cast(T*) ap;
        ap += size_t.sizeof;
    }

    /*************
     * Retrieve and store through parmn the next value that is of TypeInfo ti.
     * Used when the static type is not known.
     */
    void va_arg()(ref va_list ap, TypeInfo ti, void* parmn)
    {
        // Wait until everyone updates to get TypeInfo.talign
        //auto talign = ti.talign;
        //auto p = cast(void*)(cast(size_t)ap + talign - 1) & ~(talign - 1);
        auto p = ap;
        auto tsize = ti.tsize;
        ap = cast(va_list) (p + size_t.sizeof);
        void* q = (tsize > size_t.sizeof) ? *cast(void**) p : p;
        parmn[0..tsize] = q[0..tsize];
    }

    /***********************
     * End use of ap.
     */
    void va_end(va_list ap)
    {
    }

    ///
    void va_copy(out va_list dest, va_list src)
    {
        dest = src;
    }
}
else version (X86_64)
{
    public import core.internal.vararg.sysv_x64 : va_list, va_arg, __va_list, __va_list_tag;

    align(16) struct __va_argsave_t
    {
        size_t[6] regs;   // RDI,RSI,RDX,RCX,R8,R9
        real[8] fpregs;   // XMM0..XMM7
        __va_list va;
    }

    ///
    void va_start(T)(out va_list ap, ref T parmn); // Compiler intrinsic

    ///
    T va_arg(T)(va_list ap)
    {   T a;
        va_arg(ap, a);
        return a;
    }

    ///
    void va_end(va_list ap)
    {
    }

    import core.stdc.stdlib : alloca;

    ///
    void va_copy(out va_list dest, va_list src, void* storage = alloca(__va_list_tag.sizeof))
    {
        // Instead of copying the pointers, and aliasing the source va_list,
        // the default argument alloca will allocate storage in the caller's
        // stack frame.  This is still not correct (it should be allocated in
        // the place where the va_list variable is declared) but most of the
        // time the caller's stack frame _is_ the place where the va_list is
        // allocated, so in most cases this will now work.
        dest = cast(va_list) storage;
        *dest = *src;
    }
}
else
{
    static assert(false, "Unsupported platform");
}
