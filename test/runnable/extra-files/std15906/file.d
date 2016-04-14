module std15906.file;

struct RefCounted(T)
{
    struct RefCountedStore
    {
        struct Impl
        {
            T _payload;
        }

        Impl* _store;
    }
    RefCountedStore _refCounted;

    inout(T) refCountedPayload() inout
    {
        return _refCounted._store._payload;
    }
    alias refCountedPayload this;
}

struct DirEntry {}

struct DirIteratorImpl {}

struct DirIterator
{
    RefCounted!(DirIteratorImpl) impl;
}

auto dirEntries(string)
{
    import std15906.algo;
    bool f(DirEntry de) { return true; }
    return filter!f(DirIterator());
}
