/**
 * Contains a bitfield used by the GC.
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, David Friedman, Sean Kelly
 *
 *          Copyright Digital Mars 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.gcbits;


private
{
    import core.bitop;
    import core.stdc.string;
    import core.stdc.stdlib;
    extern (C) void onOutOfMemoryError();
}


version (DigitalMars)
{
    version = bitops;
}
else version (GNU)
{
    // use the unoptimized version
}
else version (D_InlineAsm_X86)
{
    version = Asm86;
}

struct GCBits
{
    const int BITS_PER_WORD = 32;
    const int BITS_SHIFT = 5;
    const int BITS_MASK = 31;

    uint*  data = null;
    size_t nwords = 0;    // allocated words in data[] excluding sentinals
    size_t nbits = 0;     // number of bits in data[] excluding sentinals

    void Dtor()
    {
        if (data)
        {
            free(data);
            data = null;
        }
    }

    invariant()
    {
        if (data)
        {
            assert(nwords * data[0].sizeof * 8 >= nbits);
        }
    }

    void alloc(size_t nbits)
    {
        this.nbits = nbits;
        nwords = (nbits + (BITS_PER_WORD - 1)) >> BITS_SHIFT;
        data = cast(uint*)calloc(nwords + 2, uint.sizeof);
        if (!data)
            onOutOfMemoryError();
    }

    uint test(size_t i)
    in
    {
        assert(i < nbits);
    }
    body
    {
        //return (cast(bit *)(data + 1))[i];
        return data[1 + (i >> BITS_SHIFT)] & (1 << (i & BITS_MASK));
    }

    void set(size_t i)
    in
    {
        assert(i < nbits);
    }
    body
    {
        //(cast(bit *)(data + 1))[i] = 1;
        data[1 + (i >> BITS_SHIFT)] |= (1 << (i & BITS_MASK));
    }

    void clear(size_t i)
    in
    {
        assert(i < nbits);
    }
    body
    {
        //(cast(bit *)(data + 1))[i] = 0;
        data[1 + (i >> BITS_SHIFT)] &= ~(1 << (i & BITS_MASK));
    }

    uint testClear(size_t i)
    {
        version (bitops)
        {
            return std.intrinsic.btr(data + 1, i);
        }
        else version (Asm86)
        {
            asm
            {
                naked                   ;
                mov     EAX,data[EAX]   ;
                mov     ECX,i-4[ESP]    ;
                btr     4[EAX],ECX      ;
                sbb     EAX,EAX         ;
                ret     4               ;
            }
        }
        else
        {   uint result;

            //result = (cast(bit *)(data + 1))[i];
            //(cast(bit *)(data + 1))[i] = 0;

            uint* p = &data[1 + (i >> BITS_SHIFT)];
            uint  mask = (1 << (i & BITS_MASK));
            result = *p & mask;
            *p &= ~mask;
            return result;
        }
    }

    void zero()
    {
        memset(data + 1, 0, nwords * uint.sizeof);
    }

    void copy(GCBits *f)
    in
    {
        assert(nwords == f.nwords);
    }
    body
    {
        memcpy(data + 1, f.data + 1, nwords * uint.sizeof);
    }

    uint* base()
    in
    {
        assert(data);
    }
    body
    {
        return data + 1;
    }
}

unittest
{
    GCBits b;

    b.alloc(786);
    assert(b.test(123) == 0);
    assert(b.testClear(123) == 0);
    b.set(123);
    assert(b.test(123) != 0);
    assert(b.testClear(123) != 0);
    assert(b.test(123) == 0);

    b.set(785);
    b.set(0);
    assert(b.test(785) != 0);
    assert(b.test(0) != 0);
    b.zero();
    assert(b.test(785) == 0);
    assert(b.test(0) == 0);

    GCBits b2;
    b2.alloc(786);
    b2.set(38);
    b.copy(&b2);
    assert(b.test(38) != 0);
    b2.Dtor();

    b.Dtor();
}
