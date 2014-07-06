/**
 * This module contains utilities for TypeInfo implementation.
 *
 * Copyright: Copyright Kenji Hara 2014-.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Kenji Hara
 */
module rt.util.typeinfo;

public import rt.util.hash;

template Floating(T)
if (is(T == float) || is(T == double) || is(T == real))
{
  pure nothrow @safe:

    bool equals(T f1, T f2)
    {
        return f1 == f2;
    }

    int compare(T d1, T d2)
    {
        if (d1 != d1 || d2 != d2) // if either are NaN
        {
            if (d1 != d1)
            {
                if (d2 != d2)
                    return 0;
                return -1;
            }
            return 1;
        }
        return (d1 == d2) ? 0 : ((d1 < d2) ? -1 : 1);
    }

    size_t hashOf(T value) @trusted
    {
        static if (is(T == float))  // special case?
            return *cast(uint*)&value;
        else
            return rt.util.hash.hashOf(&value, T.sizeof);
    }
}
template Floating(T)
if (is(T == cfloat) || is(T == cdouble) || is(T == creal))
{
  pure nothrow @safe:

    bool equals(T f1, T f2)
    {
        return f1 == f2;
    }

    int compare(T f1, T f2)
    {
        int result;

        if (f1.re < f2.re)
            result = -1;
        else if (f1.re > f2.re)
            result = 1;
        else if (f1.im < f2.im)
            result = -1;
        else if (f1.im > f2.im)
            result = 1;
        else
            result = 0;
        return result;
    }

    size_t hashOf(T value) @trusted
    {
        return rt.util.hash.hashOf(&value, T.sizeof);
    }
}

template Array(T)
if (is(T ==  float) || is(T ==  double) || is(T ==  real) ||
    is(T == cfloat) || is(T == cdouble) || is(T == creal))
{
  pure nothrow @safe:

    bool equals(T[] s1, T[] s2)
    {
        size_t len = s1.length;
        if (len != s2.length)
            return false;
        for (size_t u = 0; u < len; u++)
        {
            if (!Floating!T.equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    int compare(T[] s1, T[] s2)
    {
        size_t len = s1.length;
        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            if (int c = Floating!T.compare(s1[u], s2[u]))
                return c;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    size_t hashOf(T[] value)
    {
        return rt.util.hash.hashOf(value.ptr, value.length * T.sizeof);
    }
}
