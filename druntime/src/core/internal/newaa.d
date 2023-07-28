/++
   New Associative array. Much of this code is lifted from the rt/aaA.d module
   in druntime. And so the author is repeated here, along with the copyright.
   Copyright: Copyright Digital Mars 2000 - 2015, Steven Schveighoffer 2022.
   License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
   Authors:   Martin Nowak, Steven Schveighoffer
+/
module core.internal.newaa;

import core.memory;
import core.internal.util.math : min, max;

// grow threshold
private enum GROW_NUM = 4;
private enum GROW_DEN = 5;
// shrink threshold
private enum SHRINK_NUM = 1;
private enum SHRINK_DEN = 8;
// grow factor
private enum GROW_FAC = 4;
// growing the AA doubles it's size, so the shrink threshold must be
// smaller than half the grow threshold to have a hysteresis
static assert(GROW_FAC * SHRINK_NUM * GROW_DEN < GROW_NUM * SHRINK_DEN);
// initial load factor (for literals), mean of both thresholds
private enum INIT_NUM = (GROW_DEN * SHRINK_NUM + GROW_NUM * SHRINK_DEN) / 2;
private enum INIT_DEN = SHRINK_DEN * GROW_DEN;

private enum INIT_NUM_BUCKETS = 8;
// magic hash constants to distinguish empty, deleted, and filled buckets
private enum HASH_EMPTY = 0;
private enum HASH_DELETED = 0x1;
private enum HASH_FILLED_MARK = size_t(1) << 8 * size_t.sizeof - 1;

struct Hash(K, V)
{
    private struct Entry
    {
        /*const*/ K key; // this really should be const, but legacy issues.
        V value;
    }

    private struct Bucket
    {
        private pure nothrow @nogc:
        size_t hash;
        Entry *entry;

        @property bool empty() const
        {
            return hash == HASH_EMPTY;
        }

        @property bool deleted() const
        {
            return hash == HASH_DELETED;
        }

        @property bool filled() const @safe
        {
            return cast(ptrdiff_t) hash < 0;
        }
    }

    private struct Impl
    {
        this(size_t initialSize)
        {
            import core.internal.traits : hasIndirections;

            // these are only for compatibility with druntime AA
            keysz = cast(uint) K.sizeof;
            valsz = cast(uint) V.sizeof;
            buckets = allocBuckets(initialSize);
            firstUsed = cast(uint) buckets.length;
            valoff = cast(uint) Entry.value.offsetof;

            static if (__traits(hasPostblit, K))
                flags |= Flags.keyHasPostblit;

            static if (hasIndirections!Entry)
                flags |= Flags.hasPointers;

            if (!__ctfe)
                entryTI = typeid(Entry);
        }

        Bucket[] buckets;
        uint used;
        uint deleted;
        // these are not used in this implementation, but put here so we can
        // keep the same layout if converted to an AA.
        TypeInfo_Struct entryTI;
        uint firstUsed;
        immutable uint keysz;
        immutable uint valsz;
        immutable uint valoff;
        Flags flags;

        enum Flags : ubyte
        {
            none = 0x0,
            keyHasPostblit = 0x1,
            hasPointers = 0x2,
        }

        @property size_t length() const pure nothrow @nogc
        {
            assert(used >= deleted);
            return used - deleted;
        }

        @property size_t dim() const pure nothrow @nogc @safe
        {
            return buckets.length;
        }

        @property size_t mask() const pure nothrow @nogc
        {
            return dim - 1;
        }

        // find the first slot to insert a value with hash
        inout(Bucket)* findSlotInsert(size_t hash) inout pure nothrow @nogc
        {
            for (size_t i = hash & mask, j = 1;; ++j)
            {
                if (!buckets[i].filled)
                    return &buckets[i];
                i = (i + j) & mask;
            }
        }

        // lookup a key
        inout(Bucket)* findSlotLookupOrInsert(size_t hash, in K key) inout
        {
            for (size_t i = hash & mask, j = 1;; ++j)
            {
                if ((buckets[i].hash == hash && buckets[i].entry.key == key) ||
                    buckets[i].empty)
                    return &buckets[i];
                i = (i + j) & mask;
            }
        }

        void grow()
        {
            // If there are so many deleted entries, that growing would push us
            // below the shrink threshold, we just purge deleted entries instead.
            if (length * SHRINK_DEN < GROW_FAC * dim * SHRINK_NUM)
                resize(dim);
            else
                resize(GROW_FAC * dim);
        }

        void shrink()
        {
            if (dim > INIT_NUM_BUCKETS)
                resize(dim / GROW_FAC);
        }

        void resize(size_t ndim) pure nothrow
        {
            auto obuckets = buckets;
            buckets = allocBuckets(ndim);

            foreach (ref b; obuckets[firstUsed .. $])
                if (b.filled)
                    *findSlotInsert(b.hash) = b;

            firstUsed = 0;
            used -= deleted;
            deleted = 0;
            if (!__ctfe)
                GC.free(obuckets.ptr); // safe to free b/c impossible to reference
        }

        void clear() pure nothrow
        {
            import core.stdc.string : memset;
            // clear all data, but don't change bucket array length
            memset(&buckets[firstUsed], 0, (buckets.length - firstUsed) * Bucket.sizeof);
            deleted = used = 0;
            firstUsed = cast(uint) dim;
        }

        static Bucket[] allocBuckets(size_t dim) @trusted pure nothrow
        {
            enum attr = GC.BlkAttr.NO_INTERIOR;
            immutable sz = dim * Bucket.sizeof;
            if (__ctfe)
                return new Bucket[sz];
            else
                return (cast(Bucket*) GC.calloc(sz, attr))[0 .. dim];
        }
    }

    private Impl* aa;

    size_t length() const pure nothrow @nogc {
        return aa ? aa.length : 0;
    }

    ref V opIndexAssign(V value, const K key)
    {
        if (!aa)
            aa = new Impl(INIT_NUM_BUCKETS);
        auto h = calcHash(key);
        auto location = aa.findSlotLookupOrInsert(h, key);
        assert(location !is null);
        if (location.empty)
        {
            if (location.deleted)
                --aa.deleted;
            else if (++aa.used * GROW_DEN > aa.dim * GROW_NUM)
            {
                aa.grow();
                location = aa.findSlotInsert(h);
            }

            aa.firstUsed = min(aa.firstUsed, cast(uint)(location - aa.buckets.ptr));
            location.hash = h;
            location.entry = new Entry(key, value);
        }
        else
        {
            location.entry.value = value;
        }
        return location.entry.value;
    }

    ref V opIndex(const K key, string file = __FILE__, size_t line = __LINE__) @safe
    {
        import core.exception;
        // todo, throw range error
        if (auto v = key in this)
            return *v;
        throw new RangeError(file, line);
    }

    V* opBinaryRight(string s : "in")(const K key) @safe
    {
        if (!aa)
            return null;
        auto h = calcHash(key);
        auto loc = aa.findSlotLookupOrInsert(h, key);
        if (loc.empty)
            return null;
        return &loc.entry.value;
    }

    size_t toHash() scope const nothrow
    {
        if (length == 0)
            return 0;

        size_t h;
        foreach (b; aa.buckets)
        {
            if (b.filled)
                h += hashOf(hashOf(b.entry.value), hashOf(b.entry.key));
        }

        return h;
    }

    private struct KVRange
    {
        Impl *impl;
        size_t idx;

        this(Impl *impl, size_t idx)
        {
            this.impl = impl;
            this.idx = idx;
            if (impl && impl.buckets[idx].empty)
                popFront();
        }

        pure nothrow @nogc @safe:
        @property bool empty() { return impl is null || idx >= impl.dim; }
        @property ref Entry front()
        {
            assert(!empty);
            return *impl.buckets[idx].entry;
        }
        void popFront()
        {
            assert(!empty);
            for (++idx; idx < impl.dim; ++idx)
            {
                if (impl.buckets[idx].filled)
                    break;
            }
        }
        auto save() { return this; }
    }

    auto opAssign(OK, OV)(OV[OK] other) {
        void buildManually()
        {
            aa = null;
            foreach (k, v; other)
                this[k] = v;
        }
        static if (is(OK == K) && is(OV == V))
        {
            if (__ctfe)
            {
                // build it manually
                buildManually();
            }
            else
            {
                // we can get away with a reinterpret cast
                aa = (() @trusted => *cast(Impl**)&other)();
            }
        }
        else
        {
            buildManually();
        }
        return this;
    }

    auto opAssign(OK, OV)(Hash!(K, V) other)
    {
        static if (is(OK == K) && is(OV == V))
        {
            aa = other.aa;
        }
        else
        {
            // build manually
            aa = null;
            foreach (e; other[])
                this[e.key] = e.value;
        }
    }

    @property auto byKeyValue() pure nothrow @nogc
    {
        return KVRange(aa, 0);
    }

    alias opSlice = byKeyValue;

    this(OK, OV)(OV[OK] other)
    {
        opAssign(other);
    }

    this(OK, OV)(Hash!(OK, OV) other)
    {
        opAssign(other);
    }

    void clear() pure nothrow
    {
        if (length > 0)
            aa.clear();
    }

    bool remove(const K key)
    {
        if (!aa)
            return false;
        auto h = calcHash(key);
        auto loc = aa.findSlotLookupOrInsert(h, key);
        if (!loc.empty)
        {
            loc.hash = HASH_DELETED;
            loc.entry = null;
            ++aa.deleted;

            if (aa.length * SHRINK_DEN < aa.dim * SHRINK_NUM && (__ctfe || !GC.inFinalizer()))
                aa.shrink();
            return true;
        }
        return false;
    }
}

private size_t mix(size_t h) @safe pure nothrow @nogc
{
    // final mix function of MurmurHash2
    enum m = 0x5bd1e995;
    h ^= h >> 13;
    h *= m;
    h ^= h >> 15;
    return h;
}

private size_t calcHash(K)(in K pkey)
{
    immutable hash = hashOf(pkey);
    // highest bit is set to distinguish empty/deleted from filled buckets
    return mix(hash) | HASH_FILLED_MARK;
}

auto asAA(K, V)(Hash!(K, V) hash) @trusted
{
    if (hash.aa)
    {
        // shore up any differences in implementation, unless we are running at
        // compile time.
        if (__ctfe)
        {
            // need to build the AA from the hash
            V[K] result;
            foreach (e; hash[])
            {
                result[e.key] = e.value;
            }
            return result;
        }
        if (hash.aa.entryTI is null)
            // needs to be set
            hash.aa.entryTI = typeid(hash.Entry);

        // use a reinterpret cast.
        return *cast(V[K]*)&hash;
    }
    return V[K].init;
}

Hash!(K, V) asHash(K, V)(V[K] aa)
{
    Hash!(K, V) h = aa;
    return h;
}

unittest {
    auto buildAAAtCompiletime()
    {
        Hash!(string, int) h = ["hello": 5];
        //h["hello"] = 5;
        return h;
    }
    static h = buildAAAtCompiletime();
    auto aa = h.asAA;
    h["there"] = 4;
    aa["D is the best"] = 3;

    aa = null;
    aa["one"] = 1;
    aa["two"] = 2;
    aa["three"] = 3;
    h = aa;
    h = h; // ensure assignment works.
    Hash!(string, int) h2 = h; // ensure construction works;
    h.remove("one");
    import core.exception;
    // assertThrown!RangeError(h2["four"]);
}
