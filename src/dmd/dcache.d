/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/dcache.d, _dcache.d)
 *
 * Dcache - an implementation if a distributed cache over memory-mapped file.
 * It doesn't try to be smart and has most basic interface in the way of get/put,
 * both operations are synchronious and "atomic" by using a simple spin-lock.
 * 
 * Key is assumed to be a strong hash (e.g. MD5) of some object and its first bits are used directly.
 *
 * Intended use
 *
 * Allow DMD instances (and frontends on its base) to share CTFE computation results and such,
 * importantly a key must reflect the state of all dependent entities such as contents of files.
 *
 * TODOs:
 * - eviction policy (e.g. time based expiration)
 * - sizing policy (is 128 Mb enough for everybody?)
 * - better hash map algorithm (it's really dumb)
 * - better block management (does a linear pass to clean up entries ATM)
 */
module dmd.dcache;

import core.sys.posix.sys.mman;
import core.sys.posix.fcntl;
import core.sys.posix.semaphore;
import core.sys.posix.time;
import core.sys.posix.unistd;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.atomic;

version(Posix)
{
    struct DCache
    {
        /// Load the cache identified by 'keyspace'
        void initialize(const(char)[] keyspace)
        {
            char[512] buf;
            const(char)* home = getenv("HOME");
            if (home == null) home = "/tmp";
            snprintf(buf.ptr, buf.length-1, "%s/.cache", home);
            mkdir(buf.ptr, S_IRWXU | S_IRWXG | S_IRWXO);
            snprintf(buf.ptr, buf.length-1, "%s/.cache/dcache-%s", home, keyspace.ptr);
            printf("Using DCache at %s\n", buf.ptr);
            fd = open(buf.ptr, O_CREAT | O_RDWR, S_IRWXU);
            if (fd < 0) perror("Failed to open DCache mapping");
            if (posix_fallocate(fd, 0, DATA_SIZE + TOC_SIZE + META_SIZE) < 0) perror("Failed to fallocate DCache mapping");
            
            mapping = mapRange(META_SIZE + DATA_SIZE + TOC_SIZE, fd);
            owner = cast(shared(pid_t)*)mapping.ptr;
            nextAlloc = cast(uint*)(mapping.ptr + CACHE_LINE);
            toc = cast(TocEntry[])mapping[META_SIZE .. META_SIZE + TOC_SIZE];
            data = cast(Data*)(mapping.ptr + META_SIZE + TOC_SIZE);
            if (toc.length & (toc.length-1)) abort();
            ourPid = getpid();
            // Lock before modification of shared data
            {
                lock();
                scope(exit) unlock();
                // If first entry is all zeros - new mapping
                if (data.occupied == 0 && data.keySize == 0)
                {
                    data.keySize = DATA_SIZE - Data.sizeof;
                    foreach (ref t; toc) t.index = uint.max;
                }
            }
        }

        /// Clean the cache
        void clear()
        {
            lock();
            scope(exit) unlock();
            (cast(ubyte[])mapping)[]  = 0;
            data.keySize = DATA_SIZE - Data.sizeof;
            foreach (ref t; toc) t.index = uint.max;
        }

        static struct TocEntry
        {
            uint hash32;
            uint index; // == uint.max if empty
            bool empty(){ return index == uint.max; }
        }
        static assert(TocEntry.sizeof == 8);

        static struct Data
        {
            uint occupied; // 0 - free block, 1 - occupied
            uint keySize;
            uint valueSize;
            // ubyte[keySize] - key
            // ubyte[valueSize] - data
            ubyte[] key()
            {
                assert(occupied);
                assert(keySize > 0);
                ubyte* k = cast(ubyte*)&this + Data.sizeof;
                return k[0..keySize];
            }

            ubyte[] value()
            {
                assert(occupied);
                assert(valueSize > 0);
                ubyte* v = key.ptr + keySize;
                return v[0..valueSize];
            }

            uint fullSize(){ return cast(uint)(Data.sizeof + keySize + valueSize); }
        }
        static assert(Data.sizeof == 12);

        const(ubyte)[] get(const(ubyte)[] key)
        {
            uint h = first32bits(key);
            size_t offset = h & (toc.length-1);
            lock();
            scope(exit) unlock();
            for (;;)
            {
                if (toc[offset].empty) return null;
                if (toc[offset].hash32 == h)
                {
                    auto p = blockAt(toc[offset].index);
                    if (p.occupied && p.key == key)
                    {
                        return p.value;
                    }
                }
                offset = (offset + 1) & (toc.length-1);
            }
        }

        bool put(const(ubyte)[] key, const(ubyte)[] value)
        {
            uint h = first32bits(key);
            size_t offset = h & (toc.length-1);
            uint itemSize = cast(uint)(Data.sizeof + key.length + value.length);
            lock();
            scope(exit) unlock();
            for (;;)
            {
                if (toc[offset].empty)
                {
                    Data* target = blockAt(*nextAlloc);
                    // Can't split a chunk if < itemSize + Data.sizeof
                    while (target != dataEnd && (target.occupied || target.fullSize < itemSize + Data.sizeof))
                    {
                        target = next(target);
                    }
                    if (target == dataEnd) return false; // TODO: GC blocks
                    toc[offset].hash32 = h;
                    toc[offset].index = indexOfBlock(target);
                    uint blockSize = target.fullSize;
                    target.occupied = 1;
                    target.keySize = cast(uint)key.length;
                    target.valueSize = cast(uint)value.length;
                    target.key[] = cast(ubyte[])key[];
                    target.value[] = cast(ubyte[])value[];
                    auto tail = next(target);
                    tail.occupied = 0;
                    tail.keySize = cast(uint)(blockSize - itemSize - Data.sizeof);
                    tail.valueSize = 0;
                    *nextAlloc = indexOfBlock(tail);
                    return true;
                }
                offset = (offset + 1) & (toc.length-1);
            }
        }

    private:

        Data* blockAt(uint index)
        {
            return cast(Data*)(cast(ubyte*)data + index);
        }

        uint indexOfBlock(Data* block)
        {
            return cast(uint)(cast(ubyte*)block - cast(ubyte*)data);
        }

        static Data* next(Data* block)
        {
            return cast(Data*)(cast(ubyte*)block + block.fullSize);
        }

        void printToc()
        {
            printf("--- DCache TOC ---\n");
            foreach(entry; toc)
            {
                if (!entry.empty)
                    printf("hash: %x index: %d\n", entry.hash32, entry.index);
            }
            printf("------------------\n");
        }

        void printBlocks()
        {
            Data* p = data;
            printf("--- DCache Blocks ---\n");
            while(p != dataEnd)
            {
                printf("offset = %d occupied = %d keySize = %d valueSize = %d full = %d\n",
                    indexOfBlock(p), p.occupied, p.keySize, p.valueSize, p.fullSize);
                p = next(p);
            }
            printf("---------------------\n");
        }

        static void[] mapRange(size_t size, int fd)
        {
            void * p = mmap(null, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
            if (p == MAP_FAILED)
            {
                perror("Failed to mmap");
                abort();
            }
            return p[0..size];
        }

        static uint first32bits(const(ubyte)[] key)
        {
            return *cast(uint*)key.ptr;
        }

        void lock()
        {
            timespec timeout = timespec(0, 1_000_000); // 1M of nanoseconds - a millisecond
            for (;;)
            {
                shared pid_t old = atomicLoad(*owner);
                if (old != 0)
                {
                    // Use null signal to check presense of process
                    if (kill(old, 0) >= 0)
                    {
                        // somebody is alive and has pid written to lock - wait
                        nanosleep(&timeout, &timeout);
                    }
                    else
                    {
                        // nobody by this pid - likely that process crashed
                        // if we couldn't set it to 0 from old, somebody else did
                        cas(owner, old, 0);
                    }
                }
                else if (cas(owner, old, ourPid)) return;
            }
        }

        void unlock()
        {
            // we hold the lock, so no races
            *owner = 0;
        }

        Data* dataEnd(){ return cast(Data*)(cast(void*)data + DATA_SIZE); }

        void[] mapping;
        int fd; // file descriptor of shared memory mapping
        shared(pid_t)* owner; // owner of a lock, points to shared memory
        uint* nextAlloc; // last allocated block to avoid linear scan
        pid_t ourPid; // pid of this process
        TocEntry[] toc; // table of contents, fixed-size open-addressing hash map
        Data* data; // First block of data, linked list
        enum {
            Mb = 2^^20,
            META_SIZE = 4096, // no less than a page
            TOC_SIZE = 2*Mb,
            DATA_SIZE = 128*Mb,
            CACHE_LINE = 128
        }
    }
}
else
{
    struct DCache
    {
        void initialize(string keyspace) {}
        void clear(){}
        string get(const(ubyte)[] key){ return null; }
        bool put(const(ubyte)[] key, const(ubyte)[] value){ return false; }
    }
}

// Global (per thread) instance
DCache dcache;
bool cachedSemantics;

version(unittest)
auto bytes(const(char)[] str){ return cast(const(ubyte)[])str; }

version(Posix)
unittest
{
    DCache testcache;
    testcache.initialize("test-cache");
    testcache.clear();
    string[] keys = ["1", "2", "3", "4", "5", "6", "7", "8"];
    foreach(_; 0..10)
    {
        foreach(k; keys)
        {
            assert(testcache.put(k.bytes, ("0123456789-" ~ k).bytes));
            assert(testcache.get(k.bytes) == ("0123456789-" ~ k).bytes);
        }
    }
}

// Process crash tolerance test
version(Posix)
unittest
{
    DCache testcache;
    testcache.initialize("test-cache");
    testcache.clear();
    // pick a waaaay out of range pid - would trigger as crashed process
    atomicStore(*testcache.owner, pid_t.max);
    testcache.put("test-pid-check".bytes, "is passing".bytes);
    assert(*testcache.owner == 0);
    assert(testcache.get("test-pid-check".bytes) == "is passing".bytes);
}

version(unittest) static DCache testcache;
// Multiple writers test
version(Posix)
unittest
{
    import core.thread;
    enum iters = 1000;
    void writer(int id)
    {
        testcache.initialize("test-cache");
        foreach(i; 0..iters)
        {
            char[80] key, value;
            int klen = sprintf(key.ptr, "%d:%d", id, i);
            int vlen = sprintf(value.ptr, "%d:%d-value", id, i);
            testcache.put(key[0..klen].bytes, value[0..vlen].bytes);
        }
    }
    auto threads = [
        new Thread(() => writer(1)),
        new Thread(() => writer(2)),
        new Thread(() => writer(3)),
        new Thread(() => writer(4)),
        new Thread(() => writer(5)),
        new Thread(() => writer(6))
    ];
    foreach (t; threads) t.start();
    foreach (t; threads) t.join();
    
    testcache.initialize("test-cache");

    foreach (i; 0..iters)
    foreach (id; 1..5)
    {
        char[80] key, value;
        int klen = sprintf(key.ptr, "%d:%d", id, i);
        int vlen = sprintf(value.ptr, "%d:%d-value", id, i);
        const cached = testcache.get(key[0..klen].bytes);
        assert(cached !is null);
        assert(cached == value[0..vlen]);
    }
}