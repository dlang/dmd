/*
 * Data collection and report generation for
 *   -profile=gc
 * switch
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Andrei Alexandrescu and Walter Bright
 * Source: $(DRUNTIMESRC src/rt/_profilegc.d)
 */

module rt.profilegc;

private:

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import core.exception : onOutOfMemoryError;

struct Entry { size_t count, size; }

char[] buffer;
Entry[string] newCounts;

__gshared
{
    Entry[string] globalNewCounts;
    string logfilename = "profilegc.log";
}

/****
 * Set file name for output.
 * A file name of "" means write results to stdout.
 * Params:
 *      name = file name
 */

extern (C) void profilegc_setlogfilename(string name)
{
    logfilename = name;
}



public void accumulate(string file, uint line, string funcname, string type, size_t sz)
{
    char[3 * line.sizeof + 1] buf;
    auto buflen = snprintf(buf.ptr, buf.length, "%u", line);

    auto length = type.length + 1 + funcname.length + 1 + file.length + 1 + buflen;
    if (length > buffer.length)
    {
        // Enlarge buffer[] so it is big enough
        auto p = cast(char*)realloc(buffer.ptr, length);
        if (!p)
            onOutOfMemoryError();
        buffer = p[0 .. length];
    }

    // "type funcname file:line"
    buffer[0 .. type.length] = type[];
    buffer[type.length] = ' ';
    buffer[type.length + 1 ..
           type.length + 1 + funcname.length] = funcname[];
    buffer[type.length + 1 + funcname.length] = ' ';
    buffer[type.length + 1 + funcname.length + 1 ..
           type.length + 1 + funcname.length + 1 + file.length] = file[];
    buffer[type.length + 1 + funcname.length + 1 + file.length] = ':';
    buffer[type.length + 1 + funcname.length + 1 + file.length + 1 ..
           type.length + 1 + funcname.length + 1 + file.length + 1 + buflen] = buf[0 .. buflen];

    if (auto pcount = cast(string)buffer[0 .. length] in newCounts)
    { // existing entry
        pcount.count++;
        pcount.size += sz;
    }
    else
        newCounts[buffer[0..length].idup] = Entry(1, sz); // new entry
}

// Merge thread local newCounts into globalNewCounts
static ~this()
{
    if (newCounts.length)
    {
        synchronized
        {
            if (globalNewCounts.length)
            {
                // Merge
                foreach (name, entry; newCounts)
                {
                    globalNewCounts[name].count += entry.count;
                    globalNewCounts[name].size += entry.size;
                }
            }
            else
                // Assign
                globalNewCounts = newCounts;
        }
        newCounts = null;
    }
    free(buffer.ptr);
    buffer = null;
}

// Write report to stderr
shared static ~this()
{
    static struct Result
    {
        string name;
        Entry entry;

        // qsort() comparator to sort by count field
        extern (C) static int qsort_cmp(const void *r1, const void *r2)
        {
            auto result1 = cast(Result*)r1;
            auto result2 = cast(Result*)r2;
            ptrdiff_t cmp = result2.entry.size - result1.entry.size;
            if (cmp) return cmp < 0 ? -1 : 1;
            cmp = result2.entry.count - result1.entry.count;
            return cmp < 0 ? -1 : (cmp > 0 ? 1 : 0);
        }
    }

    Result[] counts = new Result[globalNewCounts.length];

    size_t i;
    foreach (name, entry; globalNewCounts)
    {
        counts[i].name = name;
        counts[i].entry = entry;
        ++i;
    }

    if (counts.length)
    {
        qsort(counts.ptr, counts.length, Result.sizeof, &Result.qsort_cmp);

        FILE* fp = logfilename.length == 0 ? stdout : fopen(logfilename.ptr, "w");
        if (fp)
        {
            fprintf(fp, "bytes allocated, allocations, type, function, file:line\n");
            foreach (ref c; counts)
            {
                fprintf(fp, "%15llu\t%15llu\t%8.*s\n",
                    cast(ulong)c.entry.size, cast(ulong)c.entry.count,
                    c.name.length, c.name.ptr);
            }
            if (logfilename.length)
                fclose(fp);
        }
        else
            fprintf(stderr, "cannot write profilegc log file '%.*s'", logfilename.length, logfilename.ptr);
    }
}


