/**

Compilation time tracing, --ftime-trace.
The time trace profile is output in the Chrome Trace Event Format, described
here: https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview

This file is originally from LDC (the LLVM D compiler).

Copyright: Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
Authors:   Johan Engelen, Max Haughton
License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/common/timetrace.d, common/_timetrace.d)
Documentation: https://dlang.org/phobos/dmd_common_timetrace.html
Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/common/timetrace.d
 */
module dmd.common.timetrace;
import dmd.globals;
import dmd.root.array;
import dmd.root.file;
import dmd.common.outbuffer;
import dmd.root.string : toDString;

// Thread local profiler instance (multithread currently not supported because compiler is single-threaded)
TimeTraceProfiler* timeTraceProfiler = null;

// processName pointer is captured
extern(C++)
void initializeTimeTrace(uint timeGranularity, uint memoryGranularity, const(char)* processName)
{
    assert(timeTraceProfiler is null, "Double initialization of timeTraceProfiler");
    timeTraceProfiler = new TimeTraceProfiler(timeGranularity, memoryGranularity, processName);
}

extern(C++)
void deinitializeTimeTrace()
{
    if (timeTraceProfilerEnabled())
    {
        object.destroy(timeTraceProfiler);
        timeTraceProfiler = null;
    }
}

pragma(inline, true)
extern(C++)
bool timeTraceProfilerEnabled()
{
    version (LDC)
    {
        import ldc.intrinsics: llvm_expect;
        return llvm_expect(timeTraceProfiler !is null, false);
    }
    else
    {
        return timeTraceProfiler !is null;
    }
}

const(char)[] getTimeTraceProfileFilename(const(char)* filename_cstr)
{
    const(char)[] filename;
    if (filename_cstr)
    {
        filename = filename_cstr.toDString();
    }
    if (filename.length == 0)
    {
        if (global.params.objfiles.length)
        {
            filename = global.params.objfiles[0].toDString() ~ ".time-trace";
        }
        else
        {
            filename = "out.time-trace";
        }
    }
    return filename;
}

extern (C++) void fatal();
extern (C++) void error(const ref Loc loc, const(char)* format, ...);
extern(C++)
void writeTimeTraceProfile(const(char)* filename_cstr)
{
    if (!timeTraceProfiler)
        return;

    const filename = getTimeTraceProfileFilename(filename_cstr);

    OutBuffer buf;
    timeTraceProfiler.writeToBuffer(&buf);
    if (filename == "-")
    {
        // Write to stdout
        import core.stdc.stdio : fwrite, stdout;
        size_t n = fwrite(buf[].ptr, 1, buf.length, stdout);
        if (n != buf.length)
        {
            error(Loc.initial, "Error writing --ftime-trace profile to stdout");
            fatal();
        }
    }
    else if (!File.write(filename, buf[]))
    {
        error(Loc.initial, "Error writing --ftime-trace profile: could not open '%*.s'", cast(int) filename.length, filename.ptr);
        fatal();
    }
}

// Pointers should not be stored, string copies must be made.
extern(C++)
void timeTraceProfilerBegin(const(char)* name_ptr, const(char)* detail_ptr, Loc loc)
{
    import dmd.root.rmem : xarraydup;
    import core.stdc.string : strdup;

    assert(timeTraceProfiler);

    // `loc` contains a pointer to a string, so we need to duplicate that string too.
    if (loc.filename)
        loc.filename = strdup(loc.filename);

    timeTraceProfiler.beginScope(xarraydup(name_ptr.toDString()),
                                 xarraydup(detail_ptr.toDString()), loc);
}

extern(C++)
void timeTraceProfilerEnd()
{
    assert(timeTraceProfiler);
    timeTraceProfiler.endScope();
}



struct TimeTraceProfiler
{
    import core.time;
    alias long TimeTicks;

    TimeTicks timeGranularity;
    uint memoryGranularity;
    const(char)[] processName;
    const(char)[] pidtid_string = `"pid":101,"tid":101`;

    TimeTicks beginningOfTime;
    Array!CounterEvent counterEvents;
    Array!DurationEvent durationEvents;
    Array!DurationEvent durationStack;

    struct CounterEvent
    {
        size_t memoryInUse;
        ulong allocatedMemory;
        size_t numberOfGCCollections;
        TimeTicks timepoint;
    }
    struct DurationEvent
    {
        const(char)[] name;
        const(char)[] details;
        Loc loc;
        TimeTicks timeBegin;
        TimeTicks timeDuration;
    }

    @disable this();
    @disable this(this);

    this(uint timeGranularity_usecs, uint memoryGranularity, const(char)* processName)
    {
        this.timeGranularity = timeGranularity_usecs * (MonoTime.ticksPerSecond() / 1_000_000);
        this.memoryGranularity = memoryGranularity;
        this.processName = processName.toDString();
        this.beginningOfTime = getTimeTicks();
    }

    TimeTicks getTimeTicks()
    {
        return MonoTime.currTime().ticks();
    }

    void beginScope(const(char)[] name, const(char)[] details, Loc loc)
    {
        DurationEvent event;
        event.name = name;
        event.details = details;
        event.loc = loc;
        event.timeBegin = getTimeTicks();
        durationStack.push(event);

        //counterEvents.push(generateCounterEvent(event.timeBegin));
    }

    void endScope()
    {
        TimeTicks timeEnd = getTimeTicks();

        DurationEvent event = durationStack.pop();
        event.timeDuration = timeEnd - event.timeBegin;
        if (event.timeDuration >= timeGranularity)
        {
            // Event passes the logging threshold
            event.timeBegin -= beginningOfTime;
            durationEvents.push(event);
            counterEvents.push(generateCounterEvent(timeEnd-beginningOfTime));
        }
    }

    CounterEvent generateCounterEvent(TimeTicks timepoint)
    {
        static import dmd.root.rmem;
        CounterEvent counters;
        if (dmd.root.rmem.mem.isGCEnabled)
        {
            static if (__VERSION__ >= 2085)
            {
                import core.memory : GC;
                auto stats = GC.stats();
                auto profileStats = GC.profileStats();

                counters.allocatedMemory = stats.usedSize + stats.freeSize;
                counters.memoryInUse = stats.usedSize;
                counters.numberOfGCCollections = profileStats.numCollections;
            }
        }
        else
        {
            counters.allocatedMemory = dmd.root.rmem.heapTotal;
            counters.memoryInUse = dmd.root.rmem.heapTotal - dmd.root.rmem.heapleft;
        }
        counters.timepoint = timepoint;
        return counters;
    }

    void writeToBuffer(OutBuffer* buf)
    {
        writePrologue(buf);
        writeEvents(buf);
        writeEpilogue(buf);
    }

    void writePrologue(OutBuffer* buf)
    {
        // Time is to be output in microseconds
        long timescale = MonoTime.ticksPerSecond() / 1_000_000;

        buf.write("{\n\"beginningOfTime\":");
        buf.print(beginningOfTime / timescale);
        buf.write(",\n\"traceEvents\": [\n");
    }

    void writeEpilogue(OutBuffer* buf)
    {
        buf.write("]\n}\n");
    }

    void writeEvents(OutBuffer* buf)
    {
        writeMetadataEvents(buf);
        writeCounterEvents(buf);
        writeDurationEvents(buf);
        // Remove the trailing comma (and newline!) to obtain valid JSON.
        if ((*buf)[buf.length()-2] == ',')
        {
            buf.setsize(buf.length()-2);
            buf.writeByte('\n');
        }
    }

    void writeMetadataEvents(OutBuffer* buf)
    {
        // {"ph":"M","ts":0,"args":{"name":"bin/ldc2"},"name":"thread_name","pid":0,"tid":0},

        buf.write(`{"ph":"M","ts":0,"args":{"name":"`);
        buf.write(processName);
        buf.write(`"},"name":"process_name",`);
        buf.write(pidtid_string);
        buf.write("},\n");
        buf.write(`{"ph":"M","ts":0,"args":{"name":"`);
        buf.write(processName);
        buf.write(`"},"cat":"","name":"thread_name",`);
        buf.write(pidtid_string);
        buf.write("},\n");
    }

    void writeCounterEvents(OutBuffer* buf)
    {
        // {"ph":"C","name":"ctr","ts":111,"args": {"Allocated_Memory_bytes":  0, "hello":  0}},

        // Time is to be output in microseconds
        long timescale = MonoTime.ticksPerSecond() / 1_000_000;

        foreach (const ref event; counterEvents)
        {
            buf.write(`{"ph":"C","name":"ctr","ts":`);
            buf.print(event.timepoint / timescale);
            buf.write(`,"args": {"memoryInUse_bytes":`);
            buf.print(event.memoryInUse);
            buf.write(`,"allocatedMemory_bytes":`);
            buf.print(event.allocatedMemory);
            buf.write(`,"GC collections":`);
            buf.print(event.numberOfGCCollections);
            buf.write("},");
            buf.write(pidtid_string);
            buf.write("},\n");
        }
    }

    void writeDurationEvents(OutBuffer* buf)
    {
        // {"ph":"X","name": "Sema1: somename","ts":111,"dur":222,"loc":"filename.d:123","args": {"detail": "something", "loc":"filename.d:123"},"pid":0,"tid":0}

        void writeLocation(Loc loc)
        {
            if (loc.filename)
            {
                writeEscapeJSONString(buf, loc.filename.toDString());
                if (loc.linnum)
                {
                    buf.writeByte(':');
                    buf.print(loc.linnum);
                }
            }
            else
            {
                buf.write(`<no file>`);
            }
        }

        // Time is to be output in microseconds
        long timescale = MonoTime.ticksPerSecond() / 1_000_000;

        foreach (event; durationEvents)
        {
            buf.write(`{"ph":"X","name": "`);
            writeEscapeJSONString(buf, event.name);
            buf.write(`","ts":`);
            buf.print(event.timeBegin / timescale);
            buf.write(`,"dur":`);
            buf.print(event.timeDuration / timescale);
            buf.write(`,"loc":"`);
            writeLocation(event.loc);
            buf.write(`","args":{"detail": "`);
            writeEscapeJSONString(buf, event.details);
            // Also output loc data in the "args" field so it shows in trace viewers that do not support the "loc" variable
            buf.write(`","loc":"`);
            writeLocation(event.loc);
            buf.write(`"},`);
            buf.write(pidtid_string);
            buf.write("},\n");
        }
    }
}


/// RAII helper class to call the begin and end functions of the time trace
/// profiler.  When the object is constructed, it begins the section; and when
/// it is destroyed, it stops it.
struct TimeTraceScope
{
    @disable this();
    @disable this(this);

    this(lazy string name, Loc loc = Loc())
    {
        if (timeTraceProfilerEnabled())
        {
            assert(timeTraceProfiler);
            // `loc` contains a pointer to a string, so we need to duplicate that too.
            import core.stdc.string : strdup;
            if (loc.filename)
                loc.filename = strdup(loc.filename);
            timeTraceProfiler.beginScope(name.dup, "", loc);
        }
    }
    this(lazy string name, lazy string detail, Loc loc = Loc())
    {
        if (timeTraceProfilerEnabled())
        {
            assert(timeTraceProfiler);
            // `loc` contains a pointer to a string, so we need to duplicate that too.
            import core.stdc.string : strdup;
            if (loc.filename)
                loc.filename = strdup(loc.filename);
            timeTraceProfiler.beginScope(name.dup, detail.dup, loc);
        }
    }

    ~this()
    {
        if (timeTraceProfilerEnabled())
            timeTraceProfilerEnd();
    }
}


private void writeEscapeJSONString(OutBuffer* buf, const(char[]) str)
{
    foreach (char c; str)
    {
        switch (c)
        {
        case '\n':
            buf.writestring("\\n");
            break;
        case '\r':
            buf.writestring("\\r");
            break;
        case '\t':
            buf.writestring("\\t");
            break;
        case '\"':
            buf.writestring("\\\"");
            break;
        case '\\':
            buf.writestring("\\\\");
            break;
        case '\b':
            buf.writestring("\\b");
            break;
        case '\f':
            buf.writestring("\\f");
            break;
        default:
            if (c < 0x20)
                buf.printf("\\u%04x", c);
            else
            {
                // Note that UTF-8 chars pass through here just fine
                buf.writeByte(c);
            }
            break;
        }
    }
}


