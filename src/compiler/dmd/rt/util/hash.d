/**
 * The console module contains a hash implementation.
 *
 * Copyright: Copyright Sean Kelly 2009 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 *
 *          Copyright Sean Kelly 2009 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.util.hash;


version( X86 )
    version = AnyX86;
version( X86_64 )
    version = AnyX86;
version( AnyX86 )
    version = HasUnalignedOps;


hash_t hashOf( const (void)* data, size_t len, hash_t seed = 0 )
{
    version( AnyX86 )
    {
        enum uint m = 0x5bd1e995;
        enum int  r = 24;
        uint h = seed;

        // Mix 4 bytes at a time into the hash.

        while( len >= 4 )
        {
            uint k = *cast(uint*) data;

            k *= m; 
            k ^= k >> r; 
            k *= m; 

            h *= m; 
            h ^= k;

            data += 4;
            len -= 4;
        }

        // Handle the last few bytes of the input array.

        switch( len )
        {
        case 3: h ^= (cast(uint) (cast(ubyte*) data)[2]) << 16;
        case 2: h ^= (cast(uint) (cast(ubyte*) data)[1]) << 8;
        case 1: h ^= (cast(uint) (cast(ubyte*) data)[0]);
                h *= m;
        case 0: break;
        default: assert( false );
        }

        // Do a few final mixes of the hash to ensure the last few
        // bytes are well-incorporated.

        h ^= h >> 13;
        h *= m;
        h ^= h >> 15;

        return h;
    }
    else
    {
        version( HasUnalignedOps )
        {
            static uint get16bits( const void* x )
            {
                return *cast(ushort*) x;
            }
        }
        else
        {
            static uint get16bits( const void* x )
            {
                return ((cast(uint) x[1]) << 8) + (cast(uint) x[0]);
            }
        }
        
        // NOTE: SuperFastHash normally starts with a zero hash value.  The seed
        //       value was incorporated to allow chaining.
        uint hash = seed;
        uint tmp;
        int  rem;

        if( len <= 0 || data is null )
            return 0;

        rem = len & 3;
        len >>= 2;

        for( ; len > 0; len-- )
        {
            hash += get16bits( data );
            tmp   = (get16bits( data + 2 ) << 11) ^ hash;
            hash  = (hash << 16) ^ tmp;
            data += 2 * ushort.sizeof;
            hash += hash >> 11;
        }

        switch( rem )
        {
        case 3: hash += get16bits( data );
                hash ^= hash << 16;
                hash ^= data[ushort.sizeof] << 18;
                hash += hash >> 11;
                break;
        case 2: hash += get16bits( data );
                hash ^= hash << 11;
                hash += hash >> 17;
                break;
        case 1: hash += *data;
                hash ^= hash << 10;
                hash += hash >> 1;
                break;
        }

        /* Force "avalanching" of final 127 bits */
        hash ^= hash << 3;
        hash += hash >> 5;
        hash ^= hash << 4;
        hash += hash >> 17;
        hash ^= hash << 25;
        hash += hash >> 6;

        return hash;
    }
}
