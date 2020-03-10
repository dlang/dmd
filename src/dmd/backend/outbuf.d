/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/outbuf.d, backend/outbuf.d)
 * Documentation: https://dlang.org/phobos/dmd_backend_outbuf.html
 */

module dmd.backend.outbuf;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

// Output buffer

// (This used to be called OutBuffer, renamed to avoid name conflicts with Mars.)

extern (C++):

private nothrow void err_nomem();

struct Outbuffer
{
    ubyte *buf;         // the buffer itself
    ubyte *pend;        // pointer past the end of the buffer
    private size_t off; // current position in buffer

  nothrow:
    this(size_t initialSize)
    {
        reserve(initialSize);
    }

    //~this() { dtor(); }

    void dtor()
    {
        if (auto slice = this.extractSlice())
            free(slice.ptr);
    }

    void reset()
    {
        off = 0;
    }

    // Returns: A slice to the data written so far
    extern(D) inout(ubyte)[] opSlice(size_t from, size_t to) inout
        @trusted pure nothrow @nogc
    {
        assert(this.buf, "Attempt to dereference a null pointer");
        assert(from < to, "First index must be <= to second one");
        assert(this.length() <= (to - from), "Out of bound access");
        return this.buf[from .. to];
    }

    /// Ditto
    extern(D) inout(ubyte)[] opSlice() inout @trusted pure nothrow @nogc
    {
        return this.buf[0 .. this.off];
    }

    extern(D) ubyte[] extractSlice() @safe pure nothrow @nogc
    {
        auto ret = this[];
        this.buf = this.pend = null;
        this.off = 0;
        return ret;
    }

    // Make sure we have at least `nbyte` available for writting
    void reserve(size_t nbytes)
    {
        const size_t oldlen = pend - buf;

        size_t len = off + nbytes;
        // No need to reallocate
        if (len < oldlen)
            return;

        const size_t newlen = oldlen + (oldlen >> 1);   // oldlen * 1.5
        if (len < newlen)
            len = newlen;
        len = (len + 15) & ~15;

        buf = cast(ubyte*) realloc(buf,len);
        if (!buf)
            err_nomem();

        pend = buf + len;
    }


    // Write n zeros; return pointer to start of zeros
    void *writezeros(size_t n)
    {
        reserve(n);
        void *pstart = memset(buf + off, 0, n);
        off += n;
        return pstart;
    }

    // Position buffer to accept the specified number of bytes at offset
    void position(size_t offset, size_t nbytes)
    {
        if (offset + nbytes > pend - buf)
        {
            reserve(offset + nbytes - off);
        }
        off = offset;

        debug assert(buf <= pend);
        debug assert(off + nbytes <= (buf - pend));
    }

    // Write an array to the buffer, no reserve check
    void writen(const void *b, size_t len)
    {
        memcpy(buf + off, b, len);
        off += len;
    }

    // Write an array to the buffer.
    extern (D)
    void write(const(void)[] b)
    {
        reserve(b.length);
        memcpy(buf + off, b.ptr, b.length);
        off += b.length;
    }

    void write(const(void)* b, size_t len)
    {
        write(b[0 .. len]);
    }

    /**
     * Writes an 8 bit byte, no reserve check.
     */
    void writeByten(ubyte v)
    {
        buf[off++] = v;
    }

    /**
     * Writes an 8 bit byte.
     */
    void writeByte(int v)
    {
        reserve(1);
        buf[off++] = cast(ubyte)v;
    }

    /**
     * Writes a 16 bit little-end short, no reserve check.
     */
    void writeWordn(int v)
    {
        version (LittleEndian)
        {
            *cast(ushort *)(buf + off) = cast(ushort)v;
        }
        else
        {
            buf[off] = v;
            buf[off + 1] = v >> 8;
        }
        off += 2;
    }


    /**
     * Writes a 16 bit little-end short.
     */
    void writeWord(int v)
    {
        reserve(2);
        writeWordn(v);
    }


    /**
     * Writes a 16 bit big-end short.
     */
    void writeShort(int v)
    {
        reserve(2);
        buf[off] = cast(ubyte)(v >> 8);
        buf[off + 1] = cast(ubyte)v;
        off += 2;
    }

    /**
     * Writes a 32 bit int.
     */
    void write32(int v)
    {
        reserve(4);
        *cast(int *)(buf + off) = v;
        off += 4;
    }

    /**
     * Writes a 64 bit long.
     */
    void write64(long v)
    {
        reserve(8);
        *cast(long *)(buf + off) = v;
        off += 8;
    }


    /**
     * Writes a 32 bit float.
     */
    void writeFloat(float v)
    {
        reserve(float.sizeof);
        *cast(float *)(buf + off) = v;
        off += float.sizeof;
    }

    /**
     * Writes a 64 bit double.
     */
    void writeDouble(double v)
    {
        reserve(double.sizeof);
        *cast(double *)(buf + off) = v;
        off += double.sizeof;
    }

    /**
     * Writes a String as a sequence of bytes.
     */
    void write(const(char)* s)
    {
        write(s[0 .. strlen(s)]);
    }

    /**
     * Writes a 0 terminated String
     */
    void writeString(const(char)* s)
    {
        write(s[0 .. strlen(s)+1]);
    }

    /// Ditto
    extern(D) void writeString(const(char)[] s)
    {
        write(s);
        writeByte(0);
    }

    /// Disembiguation for `string`
    extern(D) void writeString(string s)
    {
        writeString(cast(const(char)[])(s));
    }

    /**
     * Inserts string at beginning of buffer.
     */
    void prependBytes(const(char)* s)
    {
        prepend(s, strlen(s));
    }

    /**
     * Inserts bytes at beginning of buffer.
     */
    void prepend(const(void)* b, size_t len)
    {
        reserve(len);
        memmove(buf + len, buf, off);
        memcpy(buf,b,len);
        off += len;
    }

    /**
     * Bracket buffer contents with c1 and c2.
     */
    void bracket(char c1,char c2)
    {
        reserve(2);
        memmove(buf + 1, buf, off);
        buf[0] = c1;
        buf[off + 1] = c2;
        off += 2;
    }

    /**
     * Returns the number of bytes written.
     */
    size_t length() const @safe pure nothrow @nogc
    {
        return off;
    }

    /**
     * Set current size of buffer.
     */

    void setsize(size_t size)
    {
        off = size;
        //debug assert(buf <= p);
        //debug assert(p <= pend);
    }

    void writesLEB128(int value)
    {
        while (1)
        {
            ubyte b = value & 0x7F;

            value >>= 7;            // arithmetic right shift
            if (value == 0 && !(b & 0x40) ||
                value == -1 && (b & 0x40))
            {
                 writeByte(b);
                 break;
            }
            writeByte(b | 0x80);
        }
    }

    void writeuLEB128(uint value)
    {
        do
        {
            ubyte b = value & 0x7F;

            value >>= 7;
            if (value)
                b |= 0x80;
            writeByte(b);
        } while (value);
    }
}
