/**
 * Memory helper functions
 *
 * Copyright: Copyright Digital Mars 2015.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */
module rt.util.mem;

// inlinable version of memset suited for clearing small memory blocks
void fastshortclear(void* dest, size_t size)
{
    while (size >= 8)
    {
        *cast(ulong*)dest = 0;
        dest += 8;
        size -= 8;
    }
    if (size & 4)
    {
        *cast(uint*)dest = 0;
        dest += 4;
    }
    if (size & 2)
    {
        *cast(ushort*)dest = 0;
        dest += 2;
    }
    if (size & 1)
        *cast(ubyte*)dest = 0;
}

// inlinable version of memcpy suited for copying small memory blocks
void fastshortcopy(void* dest, const(void)* src, size_t size)
{
    while (size >= 8)
    {
        *cast(ulong*)dest = *cast(ulong*)src;
        dest += 8;
        src += 8;
        size -= 8;
    }
    if (size & 4)
    {
        *cast(uint*)dest = *cast(uint*)src;
        dest += 4;
        src += 4;
    }
    if (size & 2)
    {
        *cast(ushort*)dest = *cast(ushort*)src;
        dest += 2;
        src += 2;
    }
    if (size & 1)
        *cast(ubyte*)dest = *cast(ubyte*)src;
}
