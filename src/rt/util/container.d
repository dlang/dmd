/**
 * Basic containers for internal usage.
 *
 * Copyright: Copyright Martin Nowak 2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/util/_container.d)
 */
module rt.util.container;

import core.stdc.stdlib : free, malloc, realloc;

private void* xrealloc(void* ptr, size_t sz)
{
    import core.exception;

    if (!sz) return .free(ptr), null;
    if (auto nptr = .realloc(ptr, sz)) return nptr;
    .free(ptr), onOutOfMemoryError();
    assert(0);
}

private void destroy(T)(ref T t) if (is(T == struct))
{
    object.destroy(t);
}

private void destroy(T)(ref T t) if (!is(T == struct))
{
    t = T.init;
}

private void initialize(T)(ref T t) if (is(T == struct))
{
    import core.stdc.string;
    if(auto p = typeid(T).init().ptr)
        memcpy(&t, p, T.sizeof);
    else
        memset(&t, 0, T.sizeof);
}

private void initialize(T)(ref T t) if (!is(T == struct))
{
    t = T.init;
}

struct Array(T)
{
    @disable this(this);

    ~this()
    {
        reset();
    }

    void reset()
    {
        length = 0;
    }

    @property size_t length() const
    {
        return _length;
    }

    @property void length(size_t nlength)
    {
        if (nlength < length)
            foreach (ref val; _ptr[nlength .. length]) destroy(val);
        _ptr = cast(T*)xrealloc(_ptr, nlength * T.sizeof);
        if (nlength > length)
            foreach (ref val; _ptr[length .. nlength]) initialize(val);
        _length = nlength;
    }

    @property bool empty() const
    {
        return !length;
    }

    @property ref inout(T) front() inout
    in { assert(!empty); }
    body
    {
        return _ptr[0];
    }

    @property ref inout(T) back() inout
    in { assert(!empty); }
    body
    {
        return _ptr[_length - 1];
    }

    ref inout(T) opIndex(size_t idx) inout
    in { assert(idx < length); }
    body
    {
        return _ptr[idx];
    }

    inout(T)[] opSlice() inout
    {
        return _ptr[0 .. _length];
    }

    inout(T)[] opSlice(size_t a, size_t b) inout
    in { assert(a < b && b <= length); }
    body
    {
        return _ptr[a .. b];
    }

    alias length opDollar;

    void insertBack()(auto ref T val)
    {
        length = length + 1;
        back = val;
    }

    void popBack()
    {
        length = length - 1;
    }

private:
    T* _ptr;
    size_t _length;
}

unittest
{
    Array!size_t ary;

    assert(ary[] == []);
    ary.insertBack(5);
    assert(ary[] == [5]);
    assert(ary[$-1] == 5);
    ary.popBack();
    assert(ary[] == []);
    ary.insertBack(0);
    ary.insertBack(1);
    assert(ary[] == [0, 1]);
    assert(ary[0 .. 1] == [0]);
    assert(ary[1 .. 2] == [1]);
    assert(ary[$ - 2 .. $] == [0, 1]);
    size_t idx;
    foreach (val; ary) assert(idx++ == val);
    foreach_reverse (val; ary) assert(--idx == val);
    foreach (i, val; ary) assert(i == val);
    foreach_reverse (i, val; ary) assert(i == val);

    assert(!ary.empty);
    ary.reset();
    assert(ary.empty);
    ary.insertBack(0);
    assert(!ary.empty);
    destroy(ary);
    assert(ary.empty);

    // not copyable
    static assert(!__traits(compiles, { Array!size_t ary2 = ary; }));
    Array!size_t ary2;
    static assert(!__traits(compiles, ary = ary2));
    static void foo(Array!size_t copy) {}
    static assert(!__traits(compiles, foo(ary)));
}


version (unittest) struct RC
{
    this(size_t* cnt) { ++*(_cnt = cnt); }
    ~this() { if (_cnt) --*_cnt; }
    this(this) { if (_cnt) ++*_cnt; }
    size_t* _cnt;
}

unittest
{
    Array!RC ary;

    size_t cnt;
    assert(cnt == 0);
    ary.insertBack(RC(&cnt));
    assert(cnt == 1);
    ary.insertBack(ary.front);
    assert(cnt == 2);
    ary.popBack();
    assert(cnt == 1);
    ary.popBack();
    assert(cnt == 0);
}

struct HashTab(Key, Value)
{
    static struct Node
    {
        Key _key;
        Value _value;
        Node* _next;
    }

    @disable this(this);

    ~this()
    {
        reset();
    }

    void reset()
    {
        foreach (p; _buckets)
        {
            while (p !is null)
            {
                auto pn = p._next;
                destroy(*p);
                .free(p);
                p = pn;
            }
        }
        _buckets.reset();
        _length = 0;
    }

    @property size_t length() const
    {
        return _length;
    }

    @property bool empty() const
    {
        return !_length;
    }

    void remove(in Key key)
    in { assert(key in this); }
    body
    {
        immutable hash = hashOf(key) & mask;
        auto pp = &_buckets[hash];
        while (*pp)
        {
            auto p = *pp;
            if (p._key == key)
            {
                *pp = p._next;
                destroy(*p);
                .free(p);
                if (--_length < _buckets.length && _length >= 4)
                    shrink();
                return;
            }
            else
            {
                pp = &p._next;
            }
        }
        assert(0);
    }

    ref inout(Value) opIndex(Key key) inout
    {
        return *opIn_r(key);
    }

    void opIndexAssign(Value value, Key key)
    {
        *get(key) = value;
    }

    inout(Value)* opIn_r(in Key key) inout
    {
        if (_buckets.length)
        {
            immutable hash = hashOf(key) & mask;
            for (inout(Node)* p = _buckets[hash]; p !is null; p = p._next)
            {
                if (p._key == key)
                    return &p._value;
            }
        }
        return null;
    }

    int opApply(scope int delegate(ref Key, ref Value) dg)
    {
        foreach (p; _buckets)
        {
            while (p !is null)
            {
                if (auto res = dg(p._key, p._value))
                    return res;
                p = p._next;
            }
        }
        return 0;
    }

private:

    Value* get(Key key)
    {
        if (auto p = opIn_r(key))
            return p;

        if (!_buckets.length)
            _buckets.length = 4;

        immutable hash = hashOf(key) & mask;
        auto p = cast(Node*).malloc(Node.sizeof);
        initialize(*p);
        p._key = key;
        p._next = _buckets[hash];
        _buckets[hash] = p;
        if (++_length >= 2 * _buckets.length)
            grow();
        return &p._value;
    }

    static hash_t hashOf(in ref Key key)
    {
        import rt.util.hash : hashOf;
        static if (is(Key U : U[]))
            return hashOf(cast(const ubyte*)key.ptr, key.length * key[0].sizeof);
        else
            return hashOf(cast(const ubyte*)&key, Key.sizeof);
    }

    @property hash_t mask() const
    {
        return _buckets.length - 1;
    }

    void grow()
    in
    {
        assert(_buckets.length);
    }
    body
    {
        immutable ocnt = _buckets.length;
        immutable nmask = 2 * ocnt - 1;
        _buckets.length = 2 * ocnt;
        for (size_t i = 0; i < ocnt; ++i)
        {
            auto pp = &_buckets[i];
            while (*pp)
            {
                auto p = *pp;

                immutable nidx = hashOf(p._key) & nmask;
                if (nidx != i)
                {
                    *pp = p._next;
                    p._next = _buckets[nidx];
                    _buckets[nidx] = p;
                }
                else
                {
                    pp = &p._next;
                }
            }
        }
    }

    void shrink()
    in
    {
        assert(_buckets.length >= 2);
    }
    body
    {
        immutable ocnt = _buckets.length;
        immutable ncnt = ocnt >> 1;
        immutable nmask = ncnt - 1;

        for (size_t i = ncnt; i < ocnt; ++i)
        {
            if (auto tail = _buckets[i])
            {
                immutable nidx = i & nmask;
                auto pp = &_buckets[nidx];
                while (*pp)
                    pp = &(*pp)._next;
                *pp = tail;
                _buckets[i] = null;
            }
        }
        _buckets.length = ncnt;
    }

    Array!(Node*) _buckets;
    size_t _length;
}

unittest
{
    HashTab!(int, int) tab;

    foreach(i; 0 .. 100)
        tab[i] = 100 - i;

    foreach(i; 0 .. 100)
        assert(tab[i] == 100 - i);

    foreach (k, v; tab)
        assert(v == 100 - k);

    foreach(i; 0 .. 50)
        tab.remove(2 * i);

    assert(tab.length == 50);

    foreach(i; 0 .. 50)
        assert(tab[2 * i + 1] == 100 - 2 * i - 1);

    assert(tab.length == 50);

    tab.reset();
    assert(tab.empty);
    tab[0] = 0;
    assert(!tab.empty);
    destroy(tab);
    assert(tab.empty);

    // not copyable
    static assert(!__traits(compiles, { HashTab!(int, int) tab2 = tab; }));
    HashTab!(int, int) tab2;
    static assert(!__traits(compiles, tab = tab2));
    static void foo(HashTab!(int, int) copy) {}
    static assert(!__traits(compiles, foo(tab)));
}

unittest
{
    HashTab!(string, size_t) tab;

    tab["foo"] = 0;
    assert(tab["foo"] == 0);
    ++tab["foo"];
    assert(tab["foo"] == 1);
    tab["foo"]++;
    assert(tab["foo"] == 2);

    auto s = "fo";
    s ~= "o";
    assert(tab[s] == 2);
    assert(tab.length == 1);
    tab[s] -= 2;
    assert(tab[s] == 0);
    tab["foo"] = 12;
    assert(tab[s] == 12);

    tab.remove("foo");
    assert(tab.empty);
}

unittest
{
    HashTab!(size_t, RC) tab;

    size_t cnt;
    assert(cnt == 0);
    tab[0] = RC(&cnt);
    assert(cnt == 1);
    tab[1] = tab[0];
    assert(cnt == 2);
    tab.remove(0);
    assert(cnt == 1);
    tab.remove(1);
    assert(cnt == 0);
}
