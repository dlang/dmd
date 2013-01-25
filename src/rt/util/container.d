/**
 * Basic containers for internal usage.
 *
 * Copyright: Copyright Martin Nowak 2013.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/util/_container.d)
 */
module rt.util.container;

private void* xrealloc(void* ptr, size_t sz)
{
    import core.stdc.stdlib, core.exception;

    if (!sz) return free(ptr), null;
    if (auto nptr = realloc(ptr, sz)) return nptr;
    free(ptr), onOutOfMemoryError();
    assert(0);
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
        static if (is(T == struct))
            if (nlength < length)
                foreach (ref val; _ptr[nlength .. length]) destroy(val);
        _ptr = cast(T*)xrealloc(_ptr, nlength * T.sizeof);
        static if (is(T == struct))
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

    @property ref inout(T) opIndex(size_t idx) inout
    in { assert(idx < length); }
    body
    {
        return _ptr[idx];
    }

    @property inout(T)[] opSlice() inout
    {
        return _ptr[0 .. _length];
    }

    @property inout(T)[] opSlice(size_t a, size_t b) inout
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
    static if (is(T == struct))
    {
        void initialize(ref T t)
        {
            import core.stdc.string;
            if(auto p = typeid(T).init().ptr)
                memcpy(&t, p, T.sizeof);
            else
                memset(&t, 0, T.sizeof);
        }
    }

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

unittest
{
    static struct RC
    {
        this(size_t* cnt) { ++*(_cnt = cnt); }
        ~this() { if (_cnt) --*_cnt; }
        this(this) { if (_cnt) ++*_cnt; }
        size_t* _cnt;
    }

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
