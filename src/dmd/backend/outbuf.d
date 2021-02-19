/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
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
    private ubyte *p;   // current position in buffer

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
        p = buf;
    }

    // Returns: A slice to the data written so far
    extern(D) inout(ubyte)[] opSlice(size_t from, size_t to) inout
        @trusted pure nothrow @nogc
    {
        assert(this.buf, "Attempt to dereference a null pointer");
        assert(from < to, "First index must be smaller than the second one");
        assert(this.length() <= (to - from), "Out of bound access");
        return this.buf[from .. to];
    }

    /// Ditto
    extern(D) inout(ubyte)[] opSlice() inout @trusted pure nothrow @nogc
    {
        return this.buf[0 .. this.p - this.buf];
    }

    extern(D) ubyte[] extractSlice() @safe pure nothrow @nogc
    {
        auto ret = this[];
        this.buf = this.p = this.pend = null;
        return ret;
    }

    /********************
     * Make sure we have at least `nbytes` available for writing,
     * allocate more if necessary.
     * This is the inlinable fast path. Prefer `enlarge` if allocation
     * will always happen.
     */
    void reserve(size_t nbytes)
    {
        // Keep small so it is inlined
        if (pend - p < nbytes)
            enlarge(nbytes);
    }

    // Reserve nbytes in buffer
    void enlarge(size_t nbytes)
    {
        pragma(inline, false);  // do not inline slow path
        const size_t oldlen = pend - buf;
        const size_t used = p - buf;

        size_t len = used + nbytes;
        // No need to reallocate
        if (nbytes < (pend - p))
            return;

        const size_t newlen = oldlen + (oldlen >> 1);   // oldlen * 1.5
        if (len < newlen)
            len = newlen;
        len = (len + 15) & ~15;

        buf = cast(ubyte*) realloc(buf,len);
        if (!buf)
            err_nomem();

        pend = buf + len;
        p = buf + used;
    }


    // Write n zeros; return pointer to start of zeros
    void *writezeros(size_t n)
    {
        reserve(n);
        void *pstart = memset(p,0,n);
        p += n;
        return pstart;
    }

    // Position buffer to accept the specified number of bytes at offset
    void position(size_t offset, size_t nbytes)
    {
        if (offset + nbytes > pend - buf)
        {
            reserve(offset + nbytes - (p - buf));
        }
        p = buf + offset;

        debug assert(buf <= p);
        debug assert(p <= pend);
        debug assert(p + nbytes <= pend);
    }

    // Write an array to the buffer, no reserve check
    void writen(const void *b, size_t len)
    {
        memcpy(p,b,len);
        p += len;
    }

    // Write an array to the buffer.
    extern (D)
    void write(const(void)[] b)
    {
        reserve(b.length);
        memcpy(p, b.ptr, b.length);
        p += b.length;
    }

    void write(const(void)* b, size_t len)
    {
        write(b[0 .. len]);
    }

    /**
     * Writes an 8 bit byte, no reserve check.
     */
    void writeByten(int v)
    {
        *p++ = cast(ubyte)v;
    }

    /**
     * Writes an 8 bit byte.
     */
    void writeByte(int v)
    {
        reserve(1);
        writeByten(v);
    }

    /**
     * Writes a 16 bit value, no reserve check.
     */
    void write16n(int v)
    {
        *(cast(ushort *) p) = cast(ushort)v;
        p += 2;
    }


    /**
     * Writes a 16 bit value.
     */
    void write16(int v)
    {
        reserve(2);
        write16n(v);
    }

    /**
     * Writes a 32 bit int, no reserve check.
     */
    void write32n(int v)
    {
        *cast(int *)p = v;
        p += 4;
    }

    /**
     * Writes a 32 bit int.
     */
    void write32(int v)
    {
        reserve(4);
        write32n(v);
    }

    /**
     * Writes a 64 bit long, no reserve check
     */
    void write64n(long v)
    {
        *cast(long *)p = v;
        p += 8;
    }

    /**
     * Writes a 64 bit long.
     */
    void write64(long v)
    {
        reserve(8);
        write64n(v);
    }

    /**
     * Writes a 32 bit float.
     */
    void writeFloat(float v)
    {
        reserve(float.sizeof);
        *cast(float *)p = v;
        p += float.sizeof;
    }

    /**
     * Writes a 64 bit double.
     */
    void writeDouble(double v)
    {
        reserve(double.sizeof);
        *cast(double *)p = v;
        p += double.sizeof;
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
        memmove(buf + len,buf,p - buf);
        memcpy(buf,b,len);
        p += len;
    }

    /**
     * Bracket buffer contents with c1 and c2.
     */
    void bracket(char c1,char c2)
    {
        reserve(2);
        memmove(buf + 1,buf,p - buf);
        buf[0] = c1;
        p[1] = c2;
        p += 2;
    }

    /**
     * Returns the number of bytes written.
     */
    size_t length() const @safe pure nothrow @nogc
    {
        return p - buf;
    }

    /**
     * Set current size of buffer.
     */

    void setsize(size_t size)
    {
        p = buf + size;
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
