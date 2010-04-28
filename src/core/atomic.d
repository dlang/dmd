/**
* The atomic module is intended to provide some basic support for lock-free
* concurrent programming.  Some common operations are defined, each of which
* may be performed using the specified memory barrier or a less granular
* barrier if the hardware does not support the version requested.  This
* model is based on a design by Alexander Terekhov as outlined in
* <a href=http://groups.google.com/groups?threadm=3E4820EE.6F408B25%40web.de>
* this thread</a>.  Another useful reference for memory ordering on modern
* architectures is <a href=http://www.linuxjournal.com/article/8211>this
* article by Paul McKenney</a>.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2019.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 *
 *          Copyright Sean Kelly 2005 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.atomic;


version( D_InlineAsm_X86 )
{
    version( X86 )
    {
        version = AsmX86;
        version = AsmX86_32;
        enum has64BitCAS = true;
    }
    else version( X86_64 )
    {
        version = AsmX86;
        version = AsmX86_64;
        enum has64BitCAS = true;
    }
}


private
{   
    template NakedType(T: shared(T))  { alias T  NakedType; }
    template NakedType(T: shared(T*)) { alias T* NakedType; }
    template NakedType(T: const(T))   { alias T  NakedType; }
    template NakedType(T: const(T*))  { alias T* NakedType; }
    template NamedType(T: T*)         { alias T  NakedType; }
    template NakedType(T)             { alias T  NakedType; }
}


version( AsmX86 )
{
    // NOTE: Strictly speaking, the x86 supports atomic operations on
    //       unaligned values.  However, this is far slower than the
    //       common case, so such behavior should be prohibited.
    private template atomicValueIsProperlyAligned( T )
    {
        bool atomicValueIsProperlyAligned( size_t addr )
        {
            return addr % T.sizeof == 0;
        }
    }
}


version( ddoc )
{
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
     bool cas(T,V1,V2)( shared(T)* here, const V1 ifThis, const V2 writeThis )
         if( is( NakedType!(V1) == NakedType!(T) ) &&
             is( NakedType!(V2) == NakedType!(T) ) )
     {
         return false;
     }
}
else version( AsmX86_32 )
{
    bool cas(T,V1,V2)( shared(T)* here, const V1 ifThis, const V2 writeThis )
        if( is( NakedType!(V1) == NakedType!(T) ) &&
            is( NakedType!(V2) == NakedType!(T) ) )
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


            asm
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


            asm
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


            asm
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


            asm
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
                cmpxch8b [EDI];
                setz AL;
                pop EBX;
                pop EDI;
            }
        }
        else
        {
            pragma( msg, "Invalid template type specified." );
            static assert( false );
        }
    }
}
else version( AsmX86_64 )
{
    bool cas(T,V1,V2)( shared(T)* here, const V1 ifThis, const V2 writeThis )
        if( is( NakedType!(V1) == NakedType!(T) ) &&
            is( NakedType!(V2) == NakedType!(T) ) )
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


            asm
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


            asm
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


            asm
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

            asm
            {
                mov RDX, writeThis;
                mov RAX, ifThis;
                mov RCX, here;
                lock; // lock always needed to make this op atomic
                cmpxchg [RCX], RDX;
                setz AL;
            }
        }
        else
        {
            pragma( msg, "Invalid template type specified." );
            static assert( false );
        }
    }
}


////////////////////////////////////////////////////////////////////////////////
// Unit Tests
////////////////////////////////////////////////////////////////////////////////


version( unittest )
{
    template testCAS( msyT )
    {
        void testCAS(T)( T val = T.init + 1 )
        {
            T         base;
            shared(T) atom;

            assert( base != val );
            assert( atom == base );
            assert( cas( &atom, base, val ) );
            assert( atom == val );
            assert( !cas( &atom, base, base ) );
            assert( atom == val );
        }
    }
    
    
    void testType(T)( T val = T.init + 1 )
    {
        testCAS!(T)( val );
    }
    
    
    unittest
    {
        testType!(bool)();

        testType!(byte)();
        testType!(ubyte)();

        testType!(short)();
        testType!(ushort)();

        testType!(int)();
        testType!(uint)();

        testType!(int*)();

        static if( has64BitCAS )
        {
            testType!(long)();
            testType!(ulong)();
        }
    }
}
