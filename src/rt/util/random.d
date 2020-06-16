/**
 * Random number generators for internal usage.
 *
 * Copyright: Copyright Digital Mars 2014.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */
module rt.util.random;

struct Rand
{
    private ulong rng_state;

@safe @nogc nothrow:
pure:

    auto opCall()
    {
        auto result = front;
        popFront();
        return result;
    }

    @property uint front()
    {
        return cast(uint)(rng_state >> 32);
    }

    void popFront()
    {
        immutable ulong a = 2862933555777941757;
        immutable ulong c = 1;
        rng_state = a * rng_state + c;
    }

    enum empty = false;
}
