/**
 * WASM utility functions
 */

module dmd.backend.wasm.util;

import dmd.common.outbuffer;

// Note: outbuffer already contains members writesLEB128 and writeuLEB128

/// Emit a 5-byte padded ULEB128 (fixed-width, allowing linker relocation patching)
void writeuLEB128_5(ref OutBuffer buf, uint v) nothrow @safe
{
    buf.writeByte((v & 0x7F) | 0x80);
    buf.writeByte(((v >> 7) & 0x7F) | 0x80);
    buf.writeByte(((v >> 14) & 0x7F) | 0x80);
    buf.writeByte(((v >> 21) & 0x7F) | 0x80);
    buf.writeByte((v >> 28) & 0x0F);
}

/// Returns: number of bytes needed for ULEB128 encoding of v
uint ulebSize(uint v) nothrow
{
    uint n = 0;
    do
    {
        n++;
        v >>= 7;
    }
    while (v);
    return n;
}

/// Returns: number of bytes needed for signed LEB128 encoding of v.
uint slebSize(long v) nothrow
{
    uint n = 0;
    bool more = true;
    while (more)
    {
        const byte b = cast(byte)(v & 0x7F);
        v >>= 7;
        if ((v == 0 && (b & 0x40) == 0) || (v == -1 && (b & 0x40) != 0))
            more = false;
        n++;
    }
    return n;
}

/**
 * Read an unsigned LEB128 value from `code` at `pos`, advancing `pos` past it.
 * Params:
 *      code = bytes to read from
 *      pos = read position, updated to just after the encoded value
 * Returns: the decoded value, 0 when `pos` is at the end of `code`
 */
ulong readuLEB128(const(ubyte)[] code, ref size_t pos) nothrow @safe
{
    ulong v;
    uint shift;
    while (pos < code.length)
    {
        const ubyte b = code[pos++];
        v |= cast(ulong)(b & 0x7F) << shift;
        shift += 7;
        if (!(b & 0x80))
            break;
    }
    return v;
}

/**
 * Read a signed LEB128 value from `code` at `pos`, advancing `pos` past it.
 * Params:
 *      code = bytes to read from
 *      pos = read position, updated to just after the encoded value
 * Returns: the sign extended value, 0 when `pos` is at the end of `code`
 */
long readsLEB128(const(ubyte)[] code, ref size_t pos) nothrow @safe
{
    long v;
    uint shift;
    ubyte b;
    while (pos < code.length)
    {
        b = code[pos++];
        v |= cast(long)(b & 0x7F) << shift;
        shift += 7;
        if (!(b & 0x80))
            break;
    }
    if (shift < 64 && (b & 0x40))
        v |= -(1L << shift);
    return v;
}
