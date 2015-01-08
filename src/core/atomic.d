/**
 * The atomic module provides basic support for lock-free
 * concurrent programming.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2010.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly, Alex Rønne Petersen
 * Source:    $(DRUNTIMESRC core/_atomic.d)
 */

/*          Copyright Sean Kelly 2005 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.atomic;

version( D_InlineAsm_X86 )
{
    version = AsmX86;
    version = AsmX86_32;
    enum has64BitCAS = true;
    enum has128BitCAS = false;
}
else version( D_InlineAsm_X86_64 )
{
    version = AsmX86;
    version = AsmX86_64;
    enum has64BitCAS = true;
    enum has128BitCAS = true;
}
else
{
    enum has64BitCAS = false;
    enum has128BitCAS = false;
}

private
{
    template HeadUnshared(T)
    {
        static if( is( T U : shared(U*) ) )
            alias shared(U)* HeadUnshared;
        else
            alias T HeadUnshared;
    }
}


version( AsmX86 )
{
    // NOTE: Strictly speaking, the x86 supports atomic operations on
    //       unaligned values.  However, this is far slower than the
    //       common case, so such behavior should be prohibited.
    private bool atomicValueIsProperlyAligned(T)( size_t addr ) pure nothrow
    {
        return addr % T.sizeof == 0;
    }
}


version( CoreDdoc )
{
    /**
     * Performs the binary operation 'op' on val using 'mod' as the modifier.
     *
     * Params:
     *  val = The target variable.
     *  mod = The modifier to apply.
     *
     * Returns:
     *  The result of the operation.
     */
    HeadUnshared!(T) atomicOp(string op, T, V1)( ref shared T val, V1 mod ) pure nothrow @nogc
        if( __traits( compiles, mixin( "*cast(T*)&val" ~ op ~ "mod" ) ) )
    {
        return HeadUnshared!(T).init;
    }


    /**
     * Stores 'writeThis' to the memory referenced by 'here' if the value
     * referenced by 'here' is equal to 'ifThis'.  This operation is both
     * lock-free and atomic.
     *
     * Params:
     *  here      = The address of the destination variable.
     *  writeThis = The value to store.
     *  ifThis    = The comparison value.
     *
     * Returns:
     *  true if the store occurred, false if not.
     */
    bool cas(T,V1,V2)( shared(T)* here, const V1 ifThis, const V2 writeThis ) nothrow
        if( !is(T == class) && !is(T U : U*) && __traits( compiles, { *here = writeThis; } ) );

    /// Ditto
    bool cas(T,V1,V2)( shared(T)* here, const shared(V1) ifThis, shared(V2) writeThis ) nothrow
        if( is(T == class) && __traits( compiles, { *here = writeThis; } ) );

    /// Ditto
    bool cas(T,V1,V2)( shared(T)* here, const shared(V1)* ifThis, shared(V2)* writeThis ) nothrow
        if( is(T U : U*) && __traits( compiles, { *here = writeThis; } ) );

    /**
     * Loads 'val' from memory and returns it.  The memory barrier specified
     * by 'ms' is applied to the operation, which is fully sequenced by
     * default.
     *
     * Params:
     *  val = The target variable.
     *
     * Returns:
     *  The value of 'val'.
     */
    HeadUnshared!(T) atomicLoad(MemoryOrder ms = MemoryOrder.seq,T)( ref const shared T val ) pure nothrow @nogc
    {
        return HeadUnshared!(T).init;
    }


    /**
     * Writes 'newval' into 'val'.  The memory barrier specified by 'ms' is
     * applied to the operation, which is fully sequenced by default.
     *
     * Params:
     *  val    = The target variable.
     *  newval = The value to store.
     */
    void atomicStore(MemoryOrder ms = MemoryOrder.seq,T,V1)( ref shared T val, V1 newval ) pure nothrow @nogc
        if( __traits( compiles, { val = newval; } ) )
    {

    }


    /**
     * Specifies the memory ordering semantics of an atomic operation.
     */
    enum MemoryOrder
    {
        raw,    /// Not sequenced.
        acq,    /// Hoist-load + hoist-store barrier.
        rel,    /// Sink-load + sink-store barrier.
        seq,    /// Fully sequenced (acquire + release).
    }

    deprecated("Please use MemoryOrder instead.")
    alias MemoryOrder msync;

    /**
     * Inserts a full load/store memory fence (on platforms that need it). This ensures
     * that all loads and stores before a call to this function are executed before any
     * loads and stores after the call.
     */
    void atomicFence() nothrow @nogc;
}
else version( AsmX86_32 )
{
    HeadUnshared!(T) atomicOp(string op, T, V1)( ref shared T val, V1 mod ) pure nothrow @nogc
        if( __traits( compiles, mixin( "*cast(T*)&val" ~ op ~ "mod" ) ) )
    in
    {
        // NOTE: 32 bit x86 systems support 8 byte CAS, which only requires
        //       4 byte alignment, so use size_t as the align type here.
        static if( T.sizeof > size_t.sizeof )
            assert( atomicValueIsProperlyAligned!(size_t)( cast(size_t) &val ) );
        else
            assert( atomicValueIsProperlyAligned!(T)( cast(size_t) &val ) );
    }
    body
    {
        // binary operators
        //
        // +    -   *   /   %   ^^  &
        // |    ^   <<  >>  >>> ~   in
        // ==   !=  <   <=  >   >=
        static if( op == "+"  || op == "-"  || op == "*"  || op == "/"   ||
                   op == "%"  || op == "^^" || op == "&"  || op == "|"   ||
                   op == "^"  || op == "<<" || op == ">>" || op == ">>>" ||
                   op == "~"  || // skip "in"
                   op == "==" || op == "!=" || op == "<"  || op == "<="  ||
                   op == ">"  || op == ">=" )
        {
            HeadUnshared!(T) get = atomicLoad!(MemoryOrder.raw)( val );
            mixin( "return get " ~ op ~ " mod;" );
        }
        else
        // assignment operators
        //
        // +=   -=  *=  /=  %=  ^^= &=
        // |=   ^=  <<= >>= >>>=    ~=
        static if( op == "+=" || op == "-="  || op == "*="  || op == "/=" ||
                   op == "%=" || op == "^^=" || op == "&="  || op == "|=" ||
                   op == "^=" || op == "<<=" || op == ">>=" || op == ">>>=" ) // skip "~="
        {
            HeadUnshared!(T) get, set;

            do
            {
                get = set = atomicLoad!(MemoryOrder.raw)( val );
                mixin( "set " ~ op ~ " mod;" );
            } while( !cas( &val, get, set ) );
            return set;
        }
        else
        {
            static assert( false, "Operation not supported." );
        }
    }

    bool cas(T,V1,V2)( shared(T)* here, const V1 ifThis, const V2 writeThis ) nothrow
        if( !is(T == class) && !is(T U : U*) && __traits( compiles, { *here = writeThis; } ) )
    {
        return casImpl(here, ifThis, writeThis);
    }

    bool cas(T,V1,V2)( shared(T)* here, const shared(V1) ifThis, shared(V2) writeThis ) nothrow
        if( is(T == class) && __traits( compiles, { *here = writeThis; } ) )
    {
        return casImpl(here, ifThis, writeThis);
    }

    bool cas(T,V1,V2)( shared(T)* here, const shared(V1)* ifThis, shared(V2)* writeThis ) nothrow
        if( is(T U : U*) && __traits( compiles, { *here = writeThis; } ) )
    {
        return casImpl(here, ifThis, writeThis);
    }

    private bool casImpl(T,V1,V2)( shared(T)* here, V1 ifThis, V2 writeThis ) nothrow
    in
    {
        // NOTE: 32 bit x86 systems support 8 byte CAS, which only requires
        //       4 byte alignment, so use size_t as the align type here.
        static if( T.sizeof > size_t.sizeof )
            assert( atomicValueIsProperlyAligned!(size_t)( cast(size_t) here ) );
        else
            assert( atomicValueIsProperlyAligned!(T)( cast(size_t) here ) );
    }
    body
    {
        static if( T.sizeof == byte.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 1 Byte CAS
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                mov DL, writeThis;
                mov AL, ifThis;
                mov ECX, here;
                lock; // lock always needed to make this op atomic
                cmpxchg [ECX], DL;
                setz AL;
            }
        }
        else static if( T.sizeof == short.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 2 Byte CAS
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                mov DX, writeThis;
                mov AX, ifThis;
                mov ECX, here;
                lock; // lock always needed to make this op atomic
                cmpxchg [ECX], DX;
                setz AL;
            }
        }
        else static if( T.sizeof == int.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 4 Byte CAS
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                mov EDX, writeThis;
                mov EAX, ifThis;
                mov ECX, here;
                lock; // lock always needed to make this op atomic
                cmpxchg [ECX], EDX;
                setz AL;
            }
        }
        else static if( T.sizeof == long.sizeof && has64BitCAS )
        {

            //////////////////////////////////////////////////////////////////
            // 8 Byte CAS on a 32-Bit Processor
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                push EDI;
                push EBX;
                lea EDI, writeThis;
                mov EBX, [EDI];
                mov ECX, 4[EDI];
                lea EDI, ifThis;
                mov EAX, [EDI];
                mov EDX, 4[EDI];
                mov EDI, here;
                lock; // lock always needed to make this op atomic
                cmpxchg8b [EDI];
                setz AL;
                pop EBX;
                pop EDI;

            }

        }
        else
        {
            static assert( false, "Invalid template type specified." );
        }
    }


    enum MemoryOrder
    {
        raw,
        acq,
        rel,
        seq,
    }

    deprecated("Please use MemoryOrder instead.")
    alias MemoryOrder msync;


    private
    {
        template isHoistOp(MemoryOrder ms)
        {
            enum bool isHoistOp = ms == MemoryOrder.acq ||
                                  ms == MemoryOrder.seq;
        }


        template isSinkOp(MemoryOrder ms)
        {
            enum bool isSinkOp = ms == MemoryOrder.rel ||
                                 ms == MemoryOrder.seq;
        }


        // NOTE: x86 loads implicitly have acquire semantics so a memory
        //       barrier is only necessary on releases.
        template needsLoadBarrier( MemoryOrder ms )
        {
            enum bool needsLoadBarrier = ms == MemoryOrder.seq ||
                                               isSinkOp!(ms);
        }


        // NOTE: x86 stores implicitly have release semantics so a memory
        //       barrier is only necessary on acquires.
        template needsStoreBarrier( MemoryOrder ms )
        {
            enum bool needsStoreBarrier = ms == MemoryOrder.seq ||
                                                isHoistOp!(ms);
        }
    }


    HeadUnshared!(T) atomicLoad(MemoryOrder ms = MemoryOrder.seq, T)( ref const shared T val ) pure nothrow @nogc
    if(!__traits(isFloating, T))
    {
        static if (!__traits(isPOD, T))
        {
            static assert( false, "argument to atomicLoad() must be POD" );
        }
        else static if( T.sizeof == byte.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 1 Byte Load
            //////////////////////////////////////////////////////////////////

            static if( needsLoadBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov DL, 0;
                    mov AL, 0;
                    mov ECX, val;
                    lock; // lock always needed to make this op atomic
                    cmpxchg [ECX], DL;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov EAX, val;
                    mov AL, [EAX];
                }
            }
        }
        else static if( T.sizeof == short.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 2 Byte Load
            //////////////////////////////////////////////////////////////////

            static if( needsLoadBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov DX, 0;
                    mov AX, 0;
                    mov ECX, val;
                    lock; // lock always needed to make this op atomic
                    cmpxchg [ECX], DX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov EAX, val;
                    mov AX, [EAX];
                }
            }
        }
        else static if( T.sizeof == int.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 4 Byte Load
            //////////////////////////////////////////////////////////////////

            static if( needsLoadBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov EDX, 0;
                    mov EAX, 0;
                    mov ECX, val;
                    lock; // lock always needed to make this op atomic
                    cmpxchg [ECX], EDX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov EAX, val;
                    mov EAX, [EAX];
                }
            }
        }
        else static if( T.sizeof == long.sizeof && has64BitCAS )
        {
            //////////////////////////////////////////////////////////////////
            // 8 Byte Load on a 32-Bit Processor
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                push EDI;
                push EBX;
                mov EBX, 0;
                mov ECX, 0;
                mov EAX, 0;
                mov EDX, 0;
                mov EDI, val;
                lock; // lock always needed to make this op atomic
                cmpxchg8b [EDI];
                pop EBX;
                pop EDI;
            }
        }
        else
        {
            static assert( false, "Invalid template type specified." );
        }
    }

    void atomicStore(MemoryOrder ms = MemoryOrder.seq, T, V1)( ref shared T val, V1 newval ) pure nothrow @nogc
        if( __traits( compiles, { val = newval; } ) )
    {
        static if( T.sizeof == byte.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 1 Byte Store
            //////////////////////////////////////////////////////////////////

            static if( needsStoreBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov EAX, val;
                    mov DL, newval;
                    lock;
                    xchg [EAX], DL;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov EAX, val;
                    mov DL, newval;
                    mov [EAX], DL;
                }
            }
        }
        else static if( T.sizeof == short.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 2 Byte Store
            //////////////////////////////////////////////////////////////////

            static if( needsStoreBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov EAX, val;
                    mov DX, newval;
                    lock;
                    xchg [EAX], DX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov EAX, val;
                    mov DX, newval;
                    mov [EAX], DX;
                }
            }
        }
        else static if( T.sizeof == int.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 4 Byte Store
            //////////////////////////////////////////////////////////////////

            static if( needsStoreBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov EAX, val;
                    mov EDX, newval;
                    lock;
                    xchg [EAX], EDX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov EAX, val;
                    mov EDX, newval;
                    mov [EAX], EDX;
                }
            }
        }
        else static if( T.sizeof == long.sizeof && has64BitCAS )
        {
            //////////////////////////////////////////////////////////////////
            // 8 Byte Store on a 32-Bit Processor
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                push EDI;
                push EBX;
                lea EDI, newval;
                mov EBX, [EDI];
                mov ECX, 4[EDI];
                mov EDI, val;
                mov EAX, [EDI];
                mov EDX, 4[EDI];
            L1: lock; // lock always needed to make this op atomic
                cmpxchg8b [EDI];
                jne L1;
                pop EBX;
                pop EDI;
            }
        }
        else
        {
            static assert( false, "Invalid template type specified." );
        }
    }


    void atomicFence() nothrow
    {
        import core.cpuid;

        asm pure nothrow @nogc
        {
            naked;

            call sse2;
            test AL, AL;
            jne Lcpuid;

            // Fast path: We have SSE2, so just use mfence.
            mfence;
            jmp Lend;

        Lcpuid:

            // Slow path: We use cpuid to serialize. This is
            // significantly slower than mfence, but is the
            // only serialization facility we have available
            // on older non-SSE2 chips.
            push EBX;

            mov EAX, 0;
            cpuid;

            pop EBX;

        Lend:

            ret;
        }
    }
}
else version( AsmX86_64 )
{
    HeadUnshared!(T) atomicOp(string op, T, V1)( ref shared T val, V1 mod ) pure nothrow @nogc
        if( __traits( compiles, mixin( "*cast(T*)&val" ~ op ~ "mod" ) ) )
    in
    {
        // NOTE: 32 bit x86 systems support 8 byte CAS, which only requires
        //       4 byte alignment, so use size_t as the align type here.
        static if( T.sizeof > size_t.sizeof )
            assert( atomicValueIsProperlyAligned!(size_t)( cast(size_t) &val ) );
        else
            assert( atomicValueIsProperlyAligned!(T)( cast(size_t) &val ) );
    }
    body
    {
        // binary operators
        //
        // +    -   *   /   %   ^^  &
        // |    ^   <<  >>  >>> ~   in
        // ==   !=  <   <=  >   >=
        static if( op == "+"  || op == "-"  || op == "*"  || op == "/"   ||
                   op == "%"  || op == "^^" || op == "&"  || op == "|"   ||
                   op == "^"  || op == "<<" || op == ">>" || op == ">>>" ||
                   op == "~"  || // skip "in"
                   op == "==" || op == "!=" || op == "<"  || op == "<="  ||
                   op == ">"  || op == ">=" )
        {
            HeadUnshared!(T) get = atomicLoad!(MemoryOrder.raw)( val );
            mixin( "return get " ~ op ~ " mod;" );
        }
        else
        // assignment operators
        //
        // +=   -=  *=  /=  %=  ^^= &=
        // |=   ^=  <<= >>= >>>=    ~=
        static if( op == "+=" || op == "-="  || op == "*="  || op == "/=" ||
                   op == "%=" || op == "^^=" || op == "&="  || op == "|=" ||
                   op == "^=" || op == "<<=" || op == ">>=" || op == ">>>=" ) // skip "~="
        {
            HeadUnshared!(T) get, set;

            do
            {
                get = set = atomicLoad!(MemoryOrder.raw)( val );
                mixin( "set " ~ op ~ " mod;" );
            } while( !cas( &val, get, set ) );
            return set;
        }
        else
        {
            static assert( false, "Operation not supported." );
        }
    }


    bool cas(T,V1,V2)( shared(T)* here, const V1 ifThis, const V2 writeThis ) nothrow
        if( !is(T == class) && !is(T U : U*) &&  __traits( compiles, { *here = writeThis; } ) )
    {
        return casImpl(here, ifThis, writeThis);
    }

    bool cas(T,V1,V2)( shared(T)* here, const shared(V1) ifThis, shared(V2) writeThis ) nothrow
        if( is(T == class) && __traits( compiles, { *here = writeThis; } ) )
    {
        return casImpl(here, ifThis, writeThis);
    }

    bool cas(T,V1,V2)( shared(T)* here, const shared(V1)* ifThis, shared(V2)* writeThis ) nothrow
        if( is(T U : U*) && __traits( compiles, { *here = writeThis; } ) )
    {
        return casImpl(here, ifThis, writeThis);
    }

    private bool casImpl(T,V1,V2)( shared(T)* here, V1 ifThis, V2 writeThis ) nothrow
    in
    {
        // NOTE: 32 bit x86 systems support 8 byte CAS, which only requires
        //       4 byte alignment, so use size_t as the align type here.
        static if( T.sizeof > size_t.sizeof )
            assert( atomicValueIsProperlyAligned!(size_t)( cast(size_t) here ) );
        else
            assert( atomicValueIsProperlyAligned!(T)( cast(size_t) here ) );
    }
    body
    {
        static if( T.sizeof == byte.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 1 Byte CAS
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                mov DL, writeThis;
                mov AL, ifThis;
                mov RCX, here;
                lock; // lock always needed to make this op atomic
                cmpxchg [RCX], DL;
                setz AL;
            }
        }
        else static if( T.sizeof == short.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 2 Byte CAS
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                mov DX, writeThis;
                mov AX, ifThis;
                mov RCX, here;
                lock; // lock always needed to make this op atomic
                cmpxchg [RCX], DX;
                setz AL;
            }
        }
        else static if( T.sizeof == int.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 4 Byte CAS
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                mov EDX, writeThis;
                mov EAX, ifThis;
                mov RCX, here;
                lock; // lock always needed to make this op atomic
                cmpxchg [RCX], EDX;
                setz AL;
            }
        }
        else static if( T.sizeof == long.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 8 Byte CAS on a 64-Bit Processor
            //////////////////////////////////////////////////////////////////

            asm pure nothrow @nogc
            {
                mov RDX, writeThis;
                mov RAX, ifThis;
                mov RCX, here;
                lock; // lock always needed to make this op atomic
                cmpxchg [RCX], RDX;
                setz AL;
            }
        }
        else static if( T.sizeof == long.sizeof*2 && has128BitCAS)
        {
            //////////////////////////////////////////////////////////////////
            // 16 Byte CAS on a 64-Bit Processor
            //////////////////////////////////////////////////////////////////
            version(Win64){
                //Windows 64 calling convention uses different registers.
                //DMD appears to reverse the register order.
                asm pure nothrow @nogc
                {
                    push RDI;
                    push RBX;
                    mov R9, writeThis;
                    mov R10, ifThis;
                    mov R11, here;

                    mov RDI, R9;
                    mov RBX, [RDI];
                    mov RCX, 8[RDI];

                    mov RDI, R10;
                    mov RAX, [RDI];
                    mov RDX, 8[RDI];

                    mov RDI, R11;
                    lock;
                    cmpxchg16b [RDI];
                    setz AL;
                    pop RBX;
                    pop RDI;
                }

            }else{

                asm pure nothrow @nogc
                {
                    push RDI;
                    push RBX;
                    lea RDI, writeThis;
                    mov RBX, [RDI];
                    mov RCX, 8[RDI];
                    lea RDI, ifThis;
                    mov RAX, [RDI];
                    mov RDX, 8[RDI];
                    mov RDI, here;
                    lock; // lock always needed to make this op atomic
                    cmpxchg16b [RDI];
                    setz AL;
                    pop RBX;
                    pop RDI;
                }
            }
        }
        else
        {
            static assert( false, "Invalid template type specified." );
        }
    }


    enum MemoryOrder
    {
        raw,
        acq,
        rel,
        seq,
    }

    deprecated("Please use MemoryOrder instead.")
    alias MemoryOrder msync;


    private
    {
        template isHoistOp(MemoryOrder ms)
        {
            enum bool isHoistOp = ms == MemoryOrder.acq ||
                                  ms == MemoryOrder.seq;
        }


        template isSinkOp(MemoryOrder ms)
        {
            enum bool isSinkOp = ms == MemoryOrder.rel ||
                                 ms == MemoryOrder.seq;
        }


        // NOTE: x86 loads implicitly have acquire semantics so a memory
        //       barrier is only necessary on releases.
        template needsLoadBarrier( MemoryOrder ms )
        {
            enum bool needsLoadBarrier = ms == MemoryOrder.seq ||
                                               isSinkOp!(ms);
        }


        // NOTE: x86 stores implicitly have release semantics so a memory
        //       barrier is only necessary on acquires.
        template needsStoreBarrier( MemoryOrder ms )
        {
            enum bool needsStoreBarrier = ms == MemoryOrder.seq ||
                                                isHoistOp!(ms);
        }
    }


    HeadUnshared!(T) atomicLoad(MemoryOrder ms = MemoryOrder.seq, T)( ref const shared T val ) pure nothrow @nogc
    if(!__traits(isFloating, T)) {
        static if( T.sizeof == byte.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 1 Byte Load
            //////////////////////////////////////////////////////////////////

            static if( needsLoadBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov DL, 0;
                    mov AL, 0;
                    mov RCX, val;
                    lock; // lock always needed to make this op atomic
                    cmpxchg [RCX], DL;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov AL, [RAX];
                }
            }
        }
        else static if( T.sizeof == short.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 2 Byte Load
            //////////////////////////////////////////////////////////////////

            static if( needsLoadBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov DX, 0;
                    mov AX, 0;
                    mov RCX, val;
                    lock; // lock always needed to make this op atomic
                    cmpxchg [RCX], DX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov AX, [RAX];
                }
            }
        }
        else static if( T.sizeof == int.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 4 Byte Load
            //////////////////////////////////////////////////////////////////

            static if( needsLoadBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov EDX, 0;
                    mov EAX, 0;
                    mov RCX, val;
                    lock; // lock always needed to make this op atomic
                    cmpxchg [RCX], EDX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov EAX, [RAX];
                }
            }
        }
        else static if( T.sizeof == long.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 8 Byte Load
            //////////////////////////////////////////////////////////////////

            static if( needsLoadBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov RDX, 0;
                    mov RAX, 0;
                    mov RCX, val;
                    lock; // lock always needed to make this op atomic
                    cmpxchg [RCX], RDX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov RAX, [RAX];
                }
            }
        }
        else static if( T.sizeof == long.sizeof*2 && has128BitCAS )
        {
            //////////////////////////////////////////////////////////////////
            // 16 Byte Load on a 64-Bit Processor
            //////////////////////////////////////////////////////////////////
            version(Win64){
                size_t[2] retVal;
                asm pure nothrow @nogc
                {
                    push RDI;
                    push RBX;
                    mov RDI, val;
                    mov RBX, 0;
                    mov RCX, 0;
                    mov RAX, 0;
                    mov RDX, 0;
                    lock; // lock always needed to make this op atomic
                    cmpxchg16b [RDI];
                    lea RDI, retVal;
                    mov [RDI], RAX;
                    mov 8[RDI], RDX;
                    pop RBX;
                    pop RDI;
                }
                return cast(typeof(return)) retVal;
            }else{
                asm pure nothrow @nogc
                {
                    push RDI;
                    push RBX;
                    mov RBX, 0;
                    mov RCX, 0;
                    mov RAX, 0;
                    mov RDX, 0;
                    mov RDI, val;
                    lock; // lock always needed to make this op atomic
                    cmpxchg16b [RDI];
                    pop RBX;
                    pop RDI;
                }
            }
        }
        else
        {
            static assert( false, "Invalid template type specified." );
        }
    }


    void atomicStore(MemoryOrder ms = MemoryOrder.seq, T, V1)( ref shared T val, V1 newval ) pure nothrow @nogc
        if( __traits( compiles, { val = newval; } ) )
    {
        static if( T.sizeof == byte.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 1 Byte Store
            //////////////////////////////////////////////////////////////////

            static if( needsStoreBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov DL, newval;
                    lock;
                    xchg [RAX], DL;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov DL, newval;
                    mov [RAX], DL;
                }
            }
        }
        else static if( T.sizeof == short.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 2 Byte Store
            //////////////////////////////////////////////////////////////////

            static if( needsStoreBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov DX, newval;
                    lock;
                    xchg [RAX], DX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov DX, newval;
                    mov [RAX], DX;
                }
            }
        }
        else static if( T.sizeof == int.sizeof )
        {
            //////////////////////////////////////////////////////////////////
            // 4 Byte Store
            //////////////////////////////////////////////////////////////////

            static if( needsStoreBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov EDX, newval;
                    lock;
                    xchg [RAX], EDX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov EDX, newval;
                    mov [RAX], EDX;
                }
            }
        }
        else static if( T.sizeof == long.sizeof && has64BitCAS )
        {
            //////////////////////////////////////////////////////////////////
            // 8 Byte Store on a 64-Bit Processor
            //////////////////////////////////////////////////////////////////

            static if( needsStoreBarrier!(ms) )
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov RDX, newval;
                    lock;
                    xchg [RAX], RDX;
                }
            }
            else
            {
                asm pure nothrow @nogc
                {
                    mov RAX, val;
                    mov RDX, newval;
                    mov [RAX], RDX;
                }
            }
        }
        else static if( T.sizeof == long.sizeof*2 && has128BitCAS )
        {
            //////////////////////////////////////////////////////////////////
            // 16 Byte Store on a 64-Bit Processor
            //////////////////////////////////////////////////////////////////
            version(Win64){
                asm pure nothrow @nogc
                {
                    push RDI;
                    push RBX;
                    mov R9, val;
                    mov R10, newval;

                    mov RDI, R10;
                    mov RBX, [RDI];
                    mov RCX, 8[RDI];

                    mov RDI, R9;
                    mov RAX, [RDI];
                    mov RDX, 8[RDI];

                    L1: lock; // lock always needed to make this op atomic
                    cmpxchg16b [RDI];
                    jne L1;
                    pop RBX;
                    pop RDI;
                }
            }else{
                asm pure nothrow @nogc
                {
                    push RDI;
                    push RBX;
                    lea RDI, newval;
                    mov RBX, [RDI];
                    mov RCX, 8[RDI];
                    mov RDI, val;
                    mov RAX, [RDI];
                    mov RDX, 8[RDI];
                    L1: lock; // lock always needed to make this op atomic
                    cmpxchg16b [RDI];
                    jne L1;
                    pop RBX;
                    pop RDI;
                }
            }
        }
        else
        {
            static assert( false, "Invalid template type specified." );
        }
    }


    void atomicFence() nothrow @nogc
    {
        // SSE2 is always present in 64-bit x86 chips.
        asm nothrow @nogc
        {
            naked;

            mfence;
            ret;
        }
    }
}

// This is an ABI adapter that works on all architectures.  It type puns
// floats and doubles to ints and longs, atomically loads them, then puns
// them back.  This is necessary so that they get returned in floating
// point instead of integer registers.
HeadUnshared!(T) atomicLoad(MemoryOrder ms = MemoryOrder.seq, T)( ref const shared T val ) pure nothrow @nogc
if(__traits(isFloating, T))
{
    static if(T.sizeof == int.sizeof)
    {
        static assert(is(T : float));
        auto ptr = cast(const shared int*) &val;
        auto asInt = atomicLoad!(ms)(*ptr);
        return *(cast(typeof(return)*) &asInt);
    }
    else static if(T.sizeof == long.sizeof)
    {
        static assert(is(T : double));
        auto ptr = cast(const shared long*) &val;
        auto asLong = atomicLoad!(ms)(*ptr);
        return *(cast(typeof(return)*) &asLong);
    }
    else
    {
        static assert(0, "Cannot atomically load 80-bit reals.");
    }
}

////////////////////////////////////////////////////////////////////////////////
// Unit Tests
////////////////////////////////////////////////////////////////////////////////


version( unittest )
{
    void testCAS(T)( T val ) pure nothrow
    in
    {
        assert(val !is T.init);
    }
    body
    {
        T         base;
        shared(T) atom;

        assert( base !is val, T.stringof );
        assert( atom is base, T.stringof );

        assert( cas( &atom, base, val ), T.stringof );
        assert( atom is val, T.stringof );
        assert( !cas( &atom, base, base ), T.stringof );
        assert( atom is val, T.stringof );
    }

    void testLoadStore(MemoryOrder ms = MemoryOrder.seq, T)( T val = T.init + 1 ) pure nothrow
    {
        T         base = cast(T) 0;
        shared(T) atom = cast(T) 0;

        assert( base !is val );
        assert( atom is base );
        atomicStore!(ms)( atom, val );
        base = atomicLoad!(ms)( atom );

        assert( base is val, T.stringof );
        assert( atom is val );
    }


    void testType(T)( T val = T.init + 1 ) pure nothrow
    {
        testCAS!(T)( val );
        testLoadStore!(MemoryOrder.seq, T)( val );
        testLoadStore!(MemoryOrder.raw, T)( val );
    }


    //@@@BUG@@@ http://d.puremagic.com/issues/show_bug.cgi?id=8081
    /+pure nothrow+/ unittest
    {
        testType!(bool)();

        testType!(byte)();
        testType!(ubyte)();

        testType!(short)();
        testType!(ushort)();

        testType!(int)();
        testType!(uint)();

        testType!(shared int*)();

        static class Klass {}
        testCAS!(shared Klass)( new shared(Klass) );

        testType!(float)(1.0f);
        testType!(double)(1.0);

        static if( has64BitCAS )
        {
            testType!(long)();
            testType!(ulong)();
        }

        static if (has128BitCAS)
        {
            struct DoubleValue
            {
                long value1;
                long value2;
            }

            align(16) shared DoubleValue a;
            atomicStore(a, DoubleValue(1,2));
            assert(a.value1 == 1 && a.value2 ==2);

            while(!cas(&a, DoubleValue(1,2), DoubleValue(3,4))){}
            assert(a.value1 == 3 && a.value2 ==4);

            align(16) DoubleValue b = atomicLoad(a);
            assert(b.value1 == 3 && b.value2 ==4);
        }

        shared(size_t) i;

        atomicOp!"+="( i, cast(size_t) 1 );
        assert( i == 1 );

        atomicOp!"-="( i, cast(size_t) 1 );
        assert( i == 0 );

        shared float f = 0;
        atomicOp!"+="( f, 1 );
        assert( f == 1 );

        shared double d = 0;
        atomicOp!"+="( d, 1 );
        assert( d == 1 );
    }

    //@@@BUG@@@ http://d.puremagic.com/issues/show_bug.cgi?id=8081
    /+pure nothrow+/ unittest
    {
        static struct S { int val; }
        auto s = shared(S)(1);

        shared(S*) ptr;

        // head unshared
        shared(S)* ifThis = null;
        shared(S)* writeThis = &s;
        assert(ptr is null);
        assert(cas(&ptr, ifThis, writeThis));
        assert(ptr is writeThis);

        // head shared
        shared(S*) ifThis2 = writeThis;
        shared(S*) writeThis2 = null;
        assert(cas(&ptr, ifThis2, writeThis2));
        assert(ptr is null);

        // head unshared target doesn't want atomic CAS
        shared(S)* ptr2;
        static assert(!__traits(compiles, cas(&ptr2, ifThis, writeThis)));
        static assert(!__traits(compiles, cas(&ptr2, ifThis2, writeThis2)));
    }

    unittest
    {
        import core.thread;

        // Use heap memory to ensure an optimizing
        // compiler doesn't put things in registers.
        uint* x = new uint();
        bool* f = new bool();
        uint* r = new uint();

        auto thr = new Thread(()
        {
            while (!*f)
            {
            }

            atomicFence();

            *r = *x;
        });

        thr.start();

        *x = 42;

        atomicFence();

        *f = true;

        atomicFence();

        thr.join();

        assert(*r == 42);
    }
}
