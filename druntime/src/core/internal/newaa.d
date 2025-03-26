/**
 * template implementation of associative arrays.
 *
 * Copyright: Copyright Digital Mars 2000 - 2015, Steven Schveighoffer 2022.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Nowak, Steven Schveighoffer, Rainer Schuetze
 *
 * Source: $(DRUNTIMESRC core/internal/_newaa.d)
 *
 * derived from rt/aaA.d
 */
module core.internal.newaa;

/// AA version for debuggers, bump whenever changing the layout
immutable int _aaVersion = 1;

import core.memory : GC;
import core.internal.util.math : min, max;
import core.internal.traits : substInout;

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

/// AA wrapper
struct AA(K, V)
{
    Impl!(K,V)* impl;
    alias impl this;

    private @property bool empty() const pure nothrow @nogc @safe
    {
        return impl is null || !impl.length;
    }
}

ref _refAA(V, K)(ref inout V[K] aa) @trusted
{
    return *(cast(AA!(substInout!K, substInout!V)*)&aa);
}

auto _toAA(T : V[K], V, K)(inout ref T aa) @trusted
{
    inout(V[K]) aai = aa;
    return *(cast(AA!(substInout!K, substInout!V)*)&aai);
}

static struct Entry(K, V)
{
    K key;
    V value;
}

static hash_t wrap_hashOf(K)(scope ref const K key) { return hashOf(key); }
enum pure_hashOf(K) = cast(hash_t function(scope ref const K key) pure nothrow @nogc @safe) &wrap_hashOf!K;

private struct Impl(K, V)
{
private:
    alias Bucket = .Bucket!(K, V);

    this(size_t sz /* = INIT_NUM_BUCKETS */) nothrow
    {
        buckets = allocBuckets!(K, V)(sz);
        firstUsed = cast(uint) buckets.length;

        // only for binary compatibility
        entryTI = typeid(Entry!(K, V));
        hashFn = delegate size_t (scope ref const K key) nothrow pure @nogc @safe {
            return pure_hashOf!K(key);
        };

        keysz = cast(uint) K.sizeof;
        valsz = cast(uint) V.sizeof;
        valoff = cast(uint) talign(keysz, V.alignof);

        enum flags = () {
            import core.internal.traits;
            Impl.Flags flags;
            static if (__traits(hasPostblit, K))
                flags |= flags.keyHasPostblit;
            static if (hasIndirections!K || hasIndirections!V)
                flags |= flags.hasPointers;
            return flags;
        } ();
    }

    Bucket[] buckets;
    uint used;
    uint deleted;
    const(TypeInfo) entryTI; // only for binary compatibility
    uint firstUsed;
    immutable uint keysz;    // only for binary compatibility
    immutable uint valsz;    // only for binary compatibility
    immutable uint valoff;   // only for binary compatibility
    Flags flags;             // only for binary compatibility
    size_t delegate(scope ref const K) nothrow pure @nogc @safe hashFn;

    enum Flags : ubyte
    {
        none = 0x0,
        keyHasPostblit = 0x1,
        hasPointers = 0x2,
    }

    @property size_t length() const pure nothrow @nogc @safe
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
    size_t findSlotInsert(size_t hash) inout pure nothrow @nogc
    {
        for (size_t i = hash & mask, j = 1;; ++j)
        {
            if (!buckets[i].filled)
                return i;
            i = (i + j) & mask;
        }
    }

    // lookup a key
    inout(Bucket)* findSlotLookup(size_t hash, ref const K key) inout
    {
        for (size_t i = hash & mask, j = 1;; ++j)
        {
            if (buckets[i].hash == hash && buckets[i].entry && key == cast(const K)(buckets[i].entry.key))
                return &buckets[i];
            else if (buckets[i].empty)
                return null;
            i = (i + j) & mask;
        }
    }

    void grow() pure nothrow
    {
        // If there are so many deleted entries, that growing would push us
        // below the shrink threshold, we just purge deleted entries instead.
        if (length * SHRINK_DEN < GROW_FAC * dim * SHRINK_NUM)
            resize(dim);
        else
            resize(GROW_FAC * dim);
    }

    void shrink() pure nothrow
    {
        if (dim > INIT_NUM_BUCKETS)
            resize(dim / GROW_FAC);
    }

    void resize(size_t ndim) pure nothrow
    {
        auto obuckets = buckets;
        buckets = allocBuckets!(K, V)(ndim);

        foreach (ref b; obuckets[firstUsed .. $])
            if (b.filled)
                buckets[findSlotInsert(b.hash)] = b;

        firstUsed = 0;
        used -= deleted;
        deleted = 0;
        obuckets.length = 0; // safe to free b/c impossible to reference, but doesn't really free
    }

    void clear() pure nothrow @trusted
    {
        import core.stdc.string : memset;
        // clear all data, but don't change bucket array length
        memset(&buckets[firstUsed], 0, (buckets.length - firstUsed) * Bucket.sizeof);
        deleted = used = 0;
        firstUsed = cast(uint) dim;
    }
}

//==============================================================================
// Bucket
//------------------------------------------------------------------------------

private struct Bucket(K, V)
{
private pure nothrow @nogc:
    size_t hash;
    Entry!(K, V)* entry;

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

private Bucket!(K, V)[] allocBuckets(K, V)(size_t dim) @trusted pure nothrow
{
    return new Bucket!(K, V)[dim]; // could allocate with BlkAttr.NO_INTERIOR
}

//==============================================================================
// Helper functions
//------------------------------------------------------------------------------

private size_t talign(size_t tsize, size_t algn) @safe pure nothrow @nogc
{
    immutable mask = algn - 1;
    assert(!(mask & algn));
    return (tsize + mask) & ~mask;
}

// mix hash to "fix" bad hash functions
private size_t mix(size_t h) @safe pure nothrow @nogc
{
    // final mix function of MurmurHash2
    enum m = 0x5bd1e995;
    h ^= h >> 13;
    h *= m;
    h ^= h >> 15;
    return h;
}

private size_t calcHash(K, V, K2)(auto ref const K2 key, Impl!(K, V)* impl)
{
    static if (is(K2 == K))
        alias k2 = key;
    else
        K k2 = key;
    hash_t hash = impl.hashFn(k2);
    // highest bit is set to distinguish empty/deleted from filled buckets
    return mix(hash) | HASH_FILLED_MARK;
}

private size_t nextpow2(const size_t n) pure nothrow @nogc @safe
{
    import core.bitop : bsr;

    if (!n)
        return 1;

    const isPowerOf2 = !((n - 1) & n);
    return 1 << (bsr(n) + !isPowerOf2);
}

pure nothrow @nogc unittest
{
    //                            0, 1, 2, 3, 4, 5, 6, 7, 8,  9
    foreach (const n, const pow2; [1, 1, 2, 4, 4, 8, 8, 8, 8, 16])
        assert(nextpow2(n) == pow2);
}

//==============================================================================
// API Implementation
//------------------------------------------------------------------------------

/** Allocate associative array data.
 * Called for `new SomeAA` expression.
 * Returns:
 *      A new associative array.
 */
V[K] _d_aaNew(K, V)()
{
    AA!(K, V) aa;
    aa.impl = new Impl!(K,V)(INIT_NUM_BUCKETS);
    return *cast(V[K]*)&aa;
}

/// Determine number of entries in associative array.
size_t _aaLen(K, V)(scope const AA!(K, V) aa)
{
    return aa ? aa.length : 0;
}

/******************************
 * Lookup key in aa.
 * Called only from implementation of (aa[key]) expressions when value is mutable.
 * Params:
 *      paa = associative array opaque pointer
 *      key = reference to the key value
 * Returns:
 *      if key was in the aa, a mutable pointer to the existing value.
 *      If key was not in the aa, a mutable pointer to newly inserted value which
 *      is set to all zeros
 */
V* _aaGetY(K, V)(scope ref AA!(K, V) aa, ref const K key)
{
    bool found;
    return _aaGetX(aa, key, found);
}

/******************************
 * Lookup key in aa.
 * Called only from implementation of require
 * Params:
 *      paa = associative array opaque pointer
 *      key = reference to the key value
 *      found = true if the value was found
 * Returns:
 *      if key was in the aa, a mutable pointer to the existing value.
 *      If key was not in the aa, a mutable pointer to newly inserted value which
 *      is set to all zeros
 */
V* _aaGetX(K, V)(scope ref AA!(K, V) aa, ref const K key, out bool found)
{
    // lazily alloc implementation
    if (aa is null)
    {
        aa.impl = new Impl!(K, V)(INIT_NUM_BUCKETS);
    }

    // get hash and bucket for key
    immutable hash = calcHash(key, aa.impl);

    // found a value => return it
    if (auto p = aa.findSlotLookup(hash, key))
    {
        found = true;
        return &p.entry.value;
    }

    auto pi = aa.findSlotInsert(hash);
    if (aa.buckets[pi].deleted)
        --aa.deleted;
    // check load factor and possibly grow
    else if (++aa.used * GROW_DEN > aa.dim * GROW_NUM)
    {
        aa.grow();
        pi = aa.findSlotInsert(hash);
        assert(aa.buckets[pi].empty);
    }

    // update search cache and allocate entry
    aa.firstUsed = min(aa.firstUsed, cast(uint)pi);
    ref p = aa.buckets[pi];
    p.hash = hash;
    p.entry = new Entry!(K, V)(key);
    return &p.entry.value;
}

/******************************
 * Lookup key in aa.
 * Called only from implementation of (aa[key]) expressions when value is not mutable.
 * Params:
 *      aa = associative array opaque pointer
 *      pkey = pointer to the key value
 * Returns:
 *      pointer to value if present, null otherwise
 */
inout(V)* _aaGetRvalueX(K, V)(inout AA!(K, V) aa, scope ref const K pkey)
{
    return _aaInX(aa, key);
}

/***********************************
 * Creates a new associative array of the same size and copies the contents of
 * the associative array into it.
 * Params:
 *      a =     The associative array.
 */
V[K] _aaDup(T : V[K], K, V)(T a)
{
    auto aa = _toAA(a);
    immutable len = _aaLen(aa);
    if (len == 0)
        return null;

    auto impl = new Impl!(K, V)(aa.dim);
    // copy the entries
    bool sameHash = aa.hashFn == impl.hashFn; // can be different if coming from template/rt
    foreach (b; aa.buckets[aa.firstUsed .. $])
    {
        if (!b.filled)
            continue;
        hash_t hash = sameHash ? b.hash : calcHash(b.entry.key, impl);
        auto pi = impl.findSlotInsert(hash);
        auto p = &impl.buckets[pi];
        p.hash = hash;
        p.entry = new Entry!(K, V)(b.entry.key, b.entry.value);
        impl.firstUsed = min(impl.firstUsed, cast(uint)pi);
    }
    return () @trusted { return *cast(V[K]*)&impl; }();
}

/******************************
 * Lookup key in aa.
 * Called only from implementation of (key in aa) expressions.
 * Params:
 *      aa = associative array opaque pointer
 *      key = reference to the key value
 * Returns:
 *      pointer to value if present, null otherwise
 */
auto _d_aaIn(K, V, K2)(inout V[K] a, auto ref const K2 key)
{
    auto aa = _toAA(a);
    if (aa.empty)
        return null;

    static if (is(K2 == K))
        alias k2 = key;
    else
        ref K k2 = ref () @trusted { return *cast(K*)&key; } ();// assume the compiler has checked compatibility

    immutable hash = calcHash(k2, aa.impl);
    if (auto p = aa.findSlotLookup(hash, k2))
        return &p.entry.value;
    return null;
}

// fake purity for backward compatibility with runtime hooks
private extern(C) enum pure_inFinalizer = cast(bool function() pure nothrow @nogc @safe) &(GC.inFinalizer);

/// Delete entry scope const AA, return true if it was present
auto _d_aaDel(K, V)(inout V[K] a, auto ref const K key)
{
    auto aa = _toAA(a);
    if (aa.empty)
        return false;

    immutable hash = calcHash(key, aa.impl);
    if (auto p = aa.findSlotLookup(hash, key))
    {
        // clear entry
        p.hash = HASH_DELETED;
        p.entry = null;

        ++aa.deleted;
        // `shrink` reallocates, and allocating from a finalizer leads to
        // InvalidMemoryError: https://issues.dlang.org/show_bug.cgi?id=21442
        if (aa.length * SHRINK_DEN < aa.dim * SHRINK_NUM && !pure_inFinalizer())
            aa.shrink();

        return true;
    }
    return false;
}

/// Remove all elements from AA.
void _aaClear(K, V)(AA!(K, V) aa)
{
    if (!aa.empty)
    {
        aa.clear();
    }
}

/// Rehash AA
AA!(K, V) _aaRehash(K, V)(AA!(K, V) aa)
{
    if (!aa.empty)
        aa.resize(nextpow2(INIT_DEN * aa.length / INIT_NUM));
    return aa;
}

/// Return a GC allocated array of all values
V[] _aaValues(K, V)(AA!(K, V) aa)
{
    if (aa.empty)
        return null;

    V[] res;
    foreach (b; aa.buckets[aa.firstUsed .. $])
    {
        if (!b.filled)
            continue;
        res ~= b.entry.value;
    }
    return res;
}

/// Return a GC allocated array of all keys
K[] _aaKeys(K, V)(AA!(K, V) aa)
{
    if (aa.empty)
        return null;

    K[] res;
    foreach (b; aa.buckets[aa.firstUsed .. $])
    {
        if (!b.filled)
            continue;
        res ~= b.entry.key;
    }
    return res;
}

// opApply callbacks are extern(D)
extern (D) alias dg_t(V) = int delegate(V*);
extern (D) alias dg2_t(K, V) = int delegate(K*, V*);

/// foreach opApply over all values
int _aaApply(K, V)(AA!(K, V) aa, dg_t!V dg)
{
    if (aa.empty)
        return 0;

    foreach (b; aa.buckets)
    {
        if (!b.filled)
            continue;
        if (auto res = dg(&b.entry.value))
            return res;
    }
    return 0;
}

/// foreach opApply over all key/value pairs
int _aaApply2(K, V)(AA!(K, V) aa, dg2_t!(K, V) dg)
{
    if (aa.empty)
        return 0;

    foreach (b; aa.buckets)
    {
        if (!b.filled)
            continue;
        if (auto res = dg(&b.entry.key, &b.entry.value))
            return res;
    }
    return 0;
}

/** Construct an associative array of type ti from corresponding keys and values.
 * Called for an AA literal `[k1:v1, k2:v2]`.
 * Params:
 *      keys = array of keys
 *      vals = array of values
 * Returns:
 *      A new associative array opaque pointer, or null if `keys` is empty.
 */
Impl!(K, V)* _d_assocarrayliteralTX(K, V)(K[] keys, V[] vals)
{
    assert(keys.length == vals.length);

    immutable length = keys.length;

    if (!length)
        return null;

    auto aa = new Impl!(K, V)(nextpow2(INIT_DEN * length / INIT_NUM));

    foreach (i; 0 .. length)
    {
        immutable hash = calcHash(keys[i], aa);

        auto p = aa.findSlotLookup(hash, keys[i]);
        assert(p is null, "duplicate entries in associative array literal");
        auto pi = aa.findSlotInsert(hash);
        p = &aa.buckets[pi];
        p.hash = hash;
        p.entry = new Entry!(K, V)(keys[i], vals[i]); // todo: move key, no postblit?
        aa.firstUsed = min(aa.firstUsed, cast(uint)pi);
    }
    aa.used = cast(uint) length;
    return aa;
}

/// compares 2 AAs for equality
bool _d_aaEqual(K, V)(scope const V[K] a1, scope const V[K] a2)
{
    auto aa1 = _toAA(a1);
    auto aa2 = _toAA(a2);

    if (aa1 is aa2)
        return true;

    immutable len = _aaLen(aa1);
    if (len != _aaLen(aa2))
        return false;

    if (!len) // both empty
        return true;

    bool sameHash = aa1.hashFn == aa2.hashFn; // can be different if coming from template/rt
    // compare the entries
    foreach (b1; aa1.buckets[aa1.firstUsed .. $])
    {
        if (!b1.filled)
            continue;
        hash_t hash = sameHash ? b1.hash : calcHash(b1.entry.key, aa2);
        auto pb2 = aa2.findSlotLookup(hash, b1.entry.key);
        if (pb2 is null || b1.entry.value != pb2.entry.value)
            return false;
    }
    return true;
}

/// compute a hash
hash_t _aaGetHash(K, V)(scope const AA!(K, V)* paa) nothrow
{
    const AA aa = *paa;

    if (aa.empty)
        return 0;

    size_t h;
    foreach (b; aa.buckets)
    {
        // use addition here, so that hash is independent of element order
        if (b.filled)
            h += hashOf(hashOf(b.entry.value), hashOf(b.entry.key));
    }

    return h;
}

/**
 * _aaRange implements a ForwardRange
 */
struct AARange(K, V)
{
    alias Key = substInout!K;
    alias Value = substInout!V;

    Impl!(Key, Value)* impl;
    size_t idx;
    alias impl this;
}

AARange!(K, V) _aaRange(K, V)(return scope AA!(K, V) aa)
{
    if (!aa)
        return AARange!(K, V)();

    foreach (i; aa.firstUsed .. aa.dim)
    {
        if (aa.buckets[i].filled)
            return AARange!(K, V)(aa, i);
    }
    return AARange!(K, V)(aa, aa.dim);
}

bool _aaRangeEmpty(K, V)(AARange!(K, V) r)
{
    return r.impl is null || r.idx >= r.dim;
}

K* _aaRangeFrontKey(K, V)(AARange!(K, V) r)
{
    assert(!_aaRangeEmpty(r));
    if (r.idx >= r.dim)
        return null;
    auto entry = r.buckets[r.idx].entry;
    return entry is null ? null : &r.buckets[r.idx].entry.key;
}

V* _aaRangeFrontValue(K, V)(AARange!(K, V) r)
{
    assert(!_aaRangeEmpty(r));
    if (r.idx >= r.dim)
        return null;

    auto entry = r.buckets[r.idx].entry;
    return entry is null ? null : &r.buckets[r.idx].entry.value;
}

void _aaRangePopFront(K, V)(ref AARange!(K, V) r)
{
    if (r.idx >= r.dim) return;
    for (++r.idx; r.idx < r.dim; ++r.idx)
    {
        if (r.buckets[r.idx].filled)
            break;
    }
}

// test postblit for AA literals
unittest
{
    static struct T
    {
        ubyte field;
        static size_t postblit, dtor;
        this(this)
        {
            ++postblit;
        }

        ~this()
        {
            ++dtor;
        }
    }

    T t;
    auto aa1 = [0 : t, 1 : t];
    assert(T.dtor == 0 && T.postblit == 2);
    aa1[0] = t;
    assert(T.dtor == 1 && T.postblit == 3);

    T.dtor = 0;
    T.postblit = 0;

    auto aa2 = [0 : t, 1 : t, 0 : t]; // literal with duplicate key => value overwritten
    assert(T.dtor == 1 && T.postblit == 3);

    T.dtor = 0;
    T.postblit = 0;

    auto aa3 = [t : 0];
    assert(T.dtor == 0 && T.postblit == 1);
    aa3[t] = 1;
    assert(T.dtor == 0 && T.postblit == 1);
    aa3.remove(t);
    assert(T.dtor == 0 && T.postblit == 1);
    aa3[t] = 2;
    assert(T.dtor == 0 && T.postblit == 2);

    // dtor will be called by GC finalizers
    aa1 = null;
    aa2 = null;
    aa3 = null;
    auto dtor1 = typeid(TypeInfo_AssociativeArray.Entry!(int, T)).xdtor;
    GC.runFinalizers((cast(char*)dtor1)[0 .. 1]);
    auto dtor2 = typeid(TypeInfo_AssociativeArray.Entry!(T, int)).xdtor;
    GC.runFinalizers((cast(char*)dtor2)[0 .. 1]);
    assert(T.dtor == 6 && T.postblit == 2);
}

// create a binary-compatible AA structure that can be used directly as an
// associative array.
// NOTE: this must only be called during CTFE
AA!(K, V) makeAA(K, V)(V[K] src) @trusted
{
    assert(__ctfe, "makeAA Must only be called at compile time");
    assert(src.length <= uint.max);
    immutable srclen = cast(uint) src.length;
    if (srclen == 0)
        return AA!(K, V).init;

    size_t dim = nextpow2(INIT_DEN * srclen / INIT_NUM);
    auto impl = new Impl!(K, V)(dim);
    auto aa = AA!(K, V)(impl);
    foreach (k, ref v; src)
    {
        immutable hash = calcHash(k, impl);
        auto pi = aa.findSlotInsert(hash);
        auto p = &aa.buckets[pi];
        p.hash = hash;
        p.entry = new Entry!(K, V)(k, v);
    }
    aa.used = srclen;
    return aa;
}

unittest
{
    static struct Foo
    {
        ubyte x;
        double d;
    }
    static int[Foo] utaa = [Foo(1, 2.0) : 5];
    auto k = Foo(1, 2.0);
    // verify that getHash doesn't match hashOf for Foo
    assert(typeid(Foo).getHash(&k) != hashOf(k));
    assert(utaa[Foo(1, 2.0)] == 5);
}
