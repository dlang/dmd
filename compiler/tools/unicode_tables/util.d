/**
Utilities for working with Unicode ranges.

Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
Authors:     $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole
License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module unicode_tables.util;

struct ValueRange
{
    dchar start, end;
@safe:

    this(dchar index)
    {
        this.start = index;
        this.end = index;
    }

    this(dchar start, dchar end)
    {
        assert(end >= start);

        this.start = start;
        this.end = end;
    }

    bool isSingle() const
    {
        return start == end;
    }

    bool within(dchar index) const
    {
        return start <= index && end >= index;
    }

    uint count() const
    {
        return end + 1 - start;
    }

    int opCmp(const ValueRange other) const {
        return this.start < other.start ? -1 : (this.start > other.start ? 1 : 0);
    }

    int opApply(scope int delegate(dchar) @safe del) const
    {
        int result;

        foreach (dchar index; start .. end + 1)
        {
            result = del(index);
            if (result)
                return result;
        }

        return result;
    }
}

struct ValueRanges
{
    ValueRange[] ranges;

@safe:

    void add(ValueRange toAdd)
    {
        if (ranges.length > 0 && (ranges[$ - 1].end >= toAdd.start || ranges[$ - 1].end + 1 == toAdd.start))
        {
            ranges[$ - 1].end = toAdd.end;
        }
        else
        {
            ranges ~= toAdd;
        }
    }

    ValueRanges not(const ref ValueRanges butNotThis) const
    {
        ValueRanges ret;

        foreach (toAdd; this)
        {
            if (butNotThis.within(toAdd))
                continue;
            ret.add(ValueRange(toAdd));
        }

        return ret;
    }

    ValueRanges merge(const ref ValueRanges andThis) const
    {
        import std.algorithm : sort;
        ValueRanges ret;

        auto sorted = sort((this.ranges ~ andThis.ranges).dup);

        foreach(range; sorted) {
            ret.add(range);
        }

        return ret;
    }

    bool within(dchar index) const
    {
        foreach (range; ranges)
        {
            if (range.within(index))
                return true;
        }

        return false;
    }

    uint count() const
    {
        uint ret;

        foreach (range; ranges)
        {
            ret += range.count;
        }

        return ret;
    }

    int opApply(scope int delegate(dchar) @safe del) const
    {
        int result;

        foreach (range; ranges)
        {
            result = range.opApply(del);
            if (result)
                return result;
        }

        return result;
    }
}
