/*
 * Data collection and report generation for
 *   -profile=gc
 * switch
 */
module rt.profilegc;

private:
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.exception : onOutOfMemoryError;
import core.internal.container.hashtab;

struct Entry { ulong count, size; }

char[] buffer;
HashTab!(const(char)[], Entry) newCounts;

__gshared
{
    HashTab!(const(char)[], Entry) globalNewCounts;
    string logfilename;
}

extern (C) void profilegc_setlogfilename(string name)
{
    logfilename = name;
}

public void accumulate(string file, uint line, string funcname, string type, ulong sz) @nogc nothrow
{
    if (sz == 0) return;

    char[20] lineStr = void;
    auto len = snprintf(lineStr.ptr, lineStr.length, "%u", line);

    auto needed = type.length + 1 + funcname.length + 1 + file.length + 1 + len;
    if (needed > buffer.length)
    {
        auto p = cast(char*)realloc(buffer.ptr, needed);
        if (!p) onOutOfMemoryError();
        buffer = p[0 .. needed];
    }

    memcpy(buffer.ptr, type.ptr, type.length);
    buffer[type.length] = ' ';
    memcpy(&buffer[type.length+1], funcname.ptr, funcname.length);
    buffer[type.length+1+funcname.length] = ' ';
    memcpy(&buffer[type.length+1+funcname.length+1], file.ptr, file.length);
    buffer[type.length+1+funcname.length+1+file.length] = ':';
    memcpy(&buffer[type.length+1+funcname.length+1+file.length+1], lineStr.ptr, len);

    auto key = buffer[0 .. type.length+1+funcname.length+1+file.length+1+len];
    if (auto p = key in newCounts)
    {
        p.count++;
        p.size += sz;
    }
    else
    {
        auto copy = cast(char*)malloc(key.length);
        if (!copy) onOutOfMemoryError();
        memcpy(copy, key.ptr, key.length);
        newCounts[copy[0 .. key.length]] = Entry(1, sz);
    }
}

static ~this()
{
    if (newCounts.length)
    {
        synchronized
        {
            foreach (name, entry; newCounts)
            {
                if (name in globalNewCounts)
                {
                    globalNewCounts[name].count += entry.count;
                    globalNewCounts[name].size += entry.size;
                }
                else
                {
                    globalNewCounts[name] = entry;
                }
                free(name.ptr);
            }
        }
        newCounts.reset();
    }
    free(buffer.ptr);
    buffer = null;
}

shared static ~this()
{
    if (globalNewCounts.length == 0)
        return;

    static struct Result
    {
        const(char)[] name;
        Entry entry;
        
        extern (C) static int cmp(const void* a, const void* b) @nogc nothrow
        {
            auto r1 = cast(Result*)a;
            auto r2 = cast(Result*)b;
            if (r2.entry.size != r1.entry.size)
                return r2.entry.size > r1.entry.size ? 1 : -1;
            if (r2.entry.count != r1.entry.count)
                return r2.entry.count > r1.entry.count ? 1 : -1;
            return strcmp(r1.name.ptr, r2.name.ptr);
        }
    }

    auto counts = (cast(Result*)malloc(globalNewCounts.length * Result.sizeof))[0 .. globalNewCounts.length];
    if (!counts.ptr)
    {
        fprintf(stderr, "profilegc: malloc failed\n");
        return;
    }
    scope(exit) free(counts.ptr);

    size_t i;
    foreach (name, entry; globalNewCounts)
    {
        counts[i].name = name;
        counts[i].entry = entry;
        i++;
    }

    qsort(counts.ptr, counts.length, Result.sizeof, &Result.cmp);

    FILE* fp = logfilename.length ? fopen(logfilename.ptr, "w") : stdout;
    if (!fp)
    {
        fprintf(stderr, "profilegc: failed to open output file\n");
        return;
    }
    scope(exit) if (fp != stdout) fclose(fp);

    fprintf(fp, "Memory Allocation Report\n");
    fprintf(fp, "=======================\n\n");
    fprintf(fp, "%16s | %12s | %-30s | %s\n", "Bytes", "Allocations", "Type", "File:Line");
    fprintf(fp, "-----------------+--------------+--------------------------------+----------------\n");

    foreach (ref c; counts)
    {
        auto colon = c.name.length;
        while (colon > 0 && c.name[colon-1] != ':') colon--;
        
        auto type = colon ? c.name[0 .. colon-1] : c.name;
        auto loc = colon ? c.name[colon .. $] : "";
        
        fprintf(fp, "%16llu | %12llu | %-30.*s | %.*s\n", 
            c.entry.size, c.entry.count,
            cast(int)type.length, type.ptr,
            cast(int)loc.length, loc.ptr);
    }

    ulong totalBytes, totalAllocs;
    foreach (ref c; counts)
    {
        totalBytes += c.entry.size;
        totalAllocs += c.entry.count;
    }

    fprintf(fp, "\nSummary:\n");
    fprintf(fp, "-----------------+--------------\n");
    fprintf(fp, "%16s | %12llu\n", "Total Bytes", totalBytes);
    fprintf(fp, "%16s | %12llu\n", "Total Allocations", totalAllocs);
    fprintf(fp, "=======================\n");

    foreach (name; globalNewCounts.keys)
        free(name.ptr);
    globalNewCounts.reset();
}