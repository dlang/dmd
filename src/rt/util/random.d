/**
 * Random number generators for internal usage.
 *
 * Copyright: Copyright Digital Mars 2014.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */
module rt.util.random;

struct Rand48
{
    private ulong rng_state;

@safe @nogc nothrow:

    void defaultSeed() @trusted
    {
        version(D_InlineAsm_X86_64)
        {
            // RDTSC takes around 22 clock cycles.
            ulong result = void; // Workaround for LDC issue #950, cannot access struct members in DMD asm.
            asm @nogc nothrow
            {
                rdtsc;
                // RAX: low 32 bits are low bits of timestamp, high 32 bits are 0.
                // RDX: low 32 bits are high bits of timestamp, high 32 bits are 0.
                // We combine these into a 48 bit value instead of a full 64 bits
                // because `front` and `popFront` only make use of the bottom 48
                // bits of `rng_state`.
                shl RDX, 16;
                xor RDX, RAX;
                mov result, RDX;
            }
            rng_state = result;
            popFront();
        }
        //else version(D_InlineAsm_X86)
        //{
        //    // We don't use `rdtsc` with version(D_InlineAsm_X86) because
        //    // some x86 processors don't support `rdtsc` and because on
        //    // x86 (but not x86-64) Linux `prctl` can disable a process's
        //    // ability to use `rdtsc`.
        //    static assert(0);
        //}
        else version(Windows)
        {
            // QueryPerformanceCounter takes about 1/4 the time of ctime.time.
            import core.sys.windows.winbase : QueryPerformanceCounter;
            QueryPerformanceCounter(cast(long*) &rng_state);
            popFront();
        }
        else version(OSX)
        {
            // mach_absolute_time is much faster than ctime.time.
            import core.time : mach_absolute_time;
            rng_state = mach_absolute_time();
            popFront();
        }
        else
        {
            // Fallback to libc timestamp in seconds.
            import ctime = core.stdc.time : time;
            seed((cast(uint) ctime.time(null)));
        }
    }

pure:

    void seed(uint seedval)
    {
        rng_state = cast(ulong)seedval << 16 | 0x330e;
        popFront();
    }

    auto opCall()
    {
        auto result = front;
        popFront();
        return result;
    }

    @property uint front()
    {
        return cast(uint)(rng_state >> 16);
    }

    void popFront()
    {
        immutable ulong a = 25214903917;
        immutable ulong c = 11;
        immutable ulong m_mask = (1uL << 48uL) - 1;
        rng_state = (a*rng_state+c) & m_mask;
    }

    enum empty = false;
}
