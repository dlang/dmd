/* REQUIRED_ARGS: -O
 * https://issues.dlang.org/show_bug.cgi?id=19813
 */

struct BitArray
{
    import core.bitop : btc, bts, btr, bsf, bt;

    size_t _len;
    size_t* _ptr;
    enum bitsPerSizeT = size_t.sizeof * 8;

    static size_t lenToDim(size_t len) @nogc pure nothrow @safe
    {
        return (len + (bitsPerSizeT-1)) / bitsPerSizeT;
    }

    this(in bool[] ba) nothrow pure
    {
        length = ba.length;
        foreach (i, b; ba)
        {
            if (b)
                bts(_ptr, i);
            else
                btr(_ptr, i);
        }
    }

    @property size_t length(size_t newlen) pure nothrow @system
    {
        if (newlen != _len)
        {
            size_t olddim = lenToDim(_len);
            immutable newdim = lenToDim(newlen);

            if (newdim != olddim)
            {
                // Create a fake array so we can use D's realloc machinery
                auto b = _ptr[0 .. olddim];
                b.length = newdim;                // realloc
                _ptr = b.ptr;
            }

            _len = newlen;
        }
        return _len;
    }

    int opCmp(ref BitArray a2) const @nogc pure nothrow
    {
        const lesser = this._len < a2._len ? &this : &a2;
        immutable fullWords = lesser._len / lesser.bitsPerSizeT;
        immutable endBits = lesser._len % lesser.bitsPerSizeT;
        auto p1 = this._ptr;
        auto p2 = a2._ptr;

        foreach (i; 0 .. fullWords)
        {
            if (p1[i] != p2[i])
            {
                return p1[i] & (size_t(1) << bsf(p1[i] ^ p2[i])) ? 1 : -1;
            }
        }

        if (endBits)
        {
            immutable i = fullWords;
            immutable diff = p1[i] ^ p2[i];
            if (diff)
            {
                immutable index = bsf(diff);
                if (index < endBits)
                {
                    // This gets optimized into OPbtst, and was doing it incorrectly
                    return p1[i] & (size_t(1) << index) ? 1 : -1;
                }
            }
        }

        return -1;
    }
}

int main()
{
    bool[] ba = [1,0,1,0,1];
    bool[] bd = [1,0,1,1,1];

    auto a = BitArray(ba);
    auto d = BitArray(bd);

    assert(a <  d);
    return 0;
}
