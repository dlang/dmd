import dmd.trace_file;
import std.stdio;
import std.file;

bool ArgOneToN(uint arg, uint N)
{
    if (!arg || arg > N)
    {
        writeln("ArgumentError: RangeError: Expected Range [1, ", N, "] (inclusive)");
        return false;
    }
    return true;
}

void main(string[] args)
{

    string[] supportedModes = [
        "Tree", "MemToplist", "TimeToplist", "Header", "PhaseHist", "KindHist", "Symbol", "Kind",
        "Phase", "RandSample" ,"OutputSelfStats", "OutputParentTable", "Parent",
        "ExpensiveTemplateInstances",
    ];

    if (args.length < 3)
    {
        writeln("Invalid invocatoion: ", args);
        writeln("Expected: ", args[0], " traceFile mode {args depending on mode}");
        writeln("Modes are", supportedModes);
        return;
    }

    import std.path : setExtension;

    auto originalFile = args[1];
    auto traceFile = originalFile.setExtension(".trace");
    auto symbolFile = originalFile.setExtension(".symbol");

    auto mode = args[2];

    if (mode != "Header" && !exists(traceFile))
    {
        writeln(`TraceFile: "`, traceFile, `" does not exist.`);
        return;
    }



    TraceFileHeader header;
    void[] fileBytes = read(originalFile);
    if (fileBytes.length < header.sizeof)
    {
        writeln("Tracefile truncated.");
    }

    (cast(void*)&header)[0 .. header.sizeof] = fileBytes[0 .. header.sizeof];

    if (header.magic_number != (*cast(ulong*) "DMDTRACE".ptr))
    {
        writeln("Tracefile does not have the correct magic number.");
        return;
    }

    string[] kinds;
    string[] phases;

    kinds = readStrings(fileBytes, header.offset_kinds, header.n_kinds);
    phases = readStrings(fileBytes, header.offset_phases, header.n_phases);
     
    // writeln("phases:\n    ", phases);
    // writeln("kinds:\n    ", kinds);

    SymbolProfileRecord[] records = readRecords(fileBytes);

    static ulong hashRecord(SymbolProfileRecord r) pure
    {
        ulong hash;
        hash ^= r.begin_mem;
        hash ^= (r.end_mem << 8);
        hash ^= (r.end_ticks << 16);
        hash ^= (r.begin_ticks << 24);
        hash ^= (ulong(r.symbol_id) << 32);
        return hash;
    }

    uint strange_record_count;
    ulong lastBeginTicks;

    if (mode == "Header")
    {
        writeln(structToString(header));
        writeln("kinds=", kinds);
        writeln("phases=", phases);

        // a file with a correct header might not have a symbol table
        // and we don't want to scan for strange records
        // just to show the header
        return ;
     }

    foreach (r; records)
    {
        if (r.begin_ticks <= lastBeginTicks)
        {
            strange_record_count++;
            writeln("Symbol: ", getSymbolName(fileBytes, r), "is proucing a strange record");
        }
        lastBeginTicks = r.begin_ticks;
    }

    if (strange_record_count)
    {
        writeln(strange_record_count, " strange records encounterd");
        return;
    }
    // if we get here records are sorted  by begin_ticks
    // as they should be

    //writeln("records are sorted that's good n_records: ", records.length);

    // now can start establishing parent child relationships;
    import core.stdc.stdlib;

    uint[] parents = (cast(uint*) calloc(records.length, uint.sizeof))[0 .. records.length];
    uint[] depth = (cast(uint*) calloc(records.length, uint.sizeof))[0 .. records.length];
    uint[2][] selfTime = (cast(uint[2]*) calloc(records.length, uint.sizeof * 2))[0
        .. records.length];
    uint[2][] selfMem = (cast(uint[2]*) calloc(records.length, uint.sizeof * 2))[0
        .. records.length];


    {
        ulong parentsFound = 0;
        uint currentDepth = 1;
        stderr.writeln("Looking for parents");
        foreach (i; 0 .. records.length)
        {
            const r = records[i];
            const time = cast(uint)(r.end_ticks - r.begin_ticks);
            const mem = cast(uint)(r.end_mem - r.begin_mem);

            selfTime[i][0] = cast(uint) i;
            selfTime[i][1] = time;
            selfMem[i][0] = cast(uint) i;
            selfMem[i][1] = mem;

            // either our parent is right above us
            if (i && records[i - 1].end_ticks > r.end_ticks)
            {
                parents[i] = cast(uint)(i - 1);
                depth[i] = currentDepth++;
                selfTime[i-1][1] -= time;
                selfMem[i-1][1] -= mem;
                parentsFound++;
            }
            else if (i) // or it's the parent of our parent
            {
                // the indent does not increase now we have to check if we have to pull back or not
                // our indent level is the one of the first record that ended after we ended

                uint currentParent = parents[i - 1];
                while (currentParent)
                {
                    auto p = records[currentParent];
                    if (p.end_ticks > r.end_ticks)
                    {
                        selfTime[currentParent][1] -= time;
                        selfMem[currentParent][1] -= mem;

                        assert(selfTime[currentParent][1] > 1);
                        currentDepth = depth[currentParent] + 1;
                        depth[i] = currentDepth;
                        parentsFound++;
                        break;
                    }
                    currentParent = parents[currentParent];
                }

                //assert(currentParent);
            }
        }
        stderr.writeln("parentsFound: ", parentsFound, " out of ", header.n_records, " tracepoints");
        if (!parentsFound && header.n_records)
        {
            stderr.writeln("No Parents? Something is fishy!");
            return ;
        }
    }



    if (mode == "Tree")
    {
/+
        const char[4096 * 4] indent = '-';
        foreach (i; 0 .. records.length)
        {
            const r = records[i];

            writeln(indent[0 .. depth[i]], ' ', r.end_ticks - r.begin_ticks, "|",
                    selfTime[i], "|", phases[r.phase_id - 1], "|", getSymbolName(fileBytes,
                        r), "|", getSymbolLocation(fileBytes, r), "|",);

        }
+/
        import std.algorithm;

        auto sorted_selfTimes = selfTime.sort!((a, b) => a[1] > b[1]).release;
        writeln("SelfTimes");
        writeln("selftime, kind, symbol_id");
        foreach (st; sorted_selfTimes[0 .. (header.n_records > 2000 ? 2000 : header.n_records)])
        {
            const r = records[st[0]];
            writeln(st[1], "|", kinds[r.kind_id - 1], "|", /*getSymbolLocation(fileBytes, r)*/r.symbol_id);
        }
    }
    else if (mode == "MemToplist")
    {
        import std.algorithm;

        auto sorted_records = records.sort!((a,
                b) => (a.end_mem - a.begin_mem > b.end_mem - b.begin_mem)).release;
        writeln("Toplist");
        writeln("Memory (in Bytes),kind,phase,location,name");
        foreach (r; sorted_records)
        {
            writeln(r.end_mem - r.begin_mem, "|", kinds[r.kind_id - 1], "|", phases[r.phase_id - 1], "|",
                    getSymbolLocation(fileBytes, r), getSymbolName(fileBytes, r));
        }
    }
    else if (mode == "TimeToplist")
    {
        import std.algorithm;

        auto sorted_records = records.sort!((a,
                b) => (a.end_ticks - a.begin_ticks > b.end_ticks - b.begin_ticks)).release;
        writeln("Toplist");
        writeln("Time (in cycles),kind,phase,location,name");
        foreach (r; sorted_records)
        {
            writeln(r.end_ticks - r.begin_ticks, "|", kinds[r.kind_id - 1], "|", phases[r.phase_id - 1], "|",
                    getSymbolLocation(fileBytes, r), "|", getSymbolName(fileBytes, r));
        }
    }

    else if (mode == "PhaseHist")
    {
        static struct SortRecord
        {
            uint phaseId;
            uint freq;
            float absTime = 0;
            float avgTime = 0;
        }

        SortRecord[] sortRecords;
        sortRecords.length = phases.length;

        foreach (i, r; records)
        {
            sortRecords[r.phase_id - 1].absTime += selfTime[i][1];
            sortRecords[r.phase_id - 1].freq++;
        }
        foreach (i; 0 .. header.n_phases)
        {
            sortRecords[i].phaseId = i + 1;
            sortRecords[i].avgTime = sortRecords[i].absTime / double(sortRecords[i].freq);
        }
        import std.algorithm : sort;

        sortRecords.sort!((a, b) => a.absTime > b.absTime);
        writeln(" === Phase Time Distribution : ===");
        writefln(" %-90s %-10s %-13s %-7s ", "phase", "avgTime", "absTime", "freq");
        foreach (sr; sortRecords)
        {
            writefln(" %-90s %-10.2f %-13.0f %-7d ", phases[sr.phaseId - 1],
                    sr.avgTime, sr.absTime, sr.freq);
        }
    }
    else if (mode == "KindHist")
    {
        static struct SortRecord_Kind
        {
            uint kindId;
            uint freq;
            float absTime = 0;
            float avgTime = 0;
        }

        SortRecord_Kind[] sortRecords;
        sortRecords.length = kinds.length;

        foreach (i, r; records)
        {
            sortRecords[r.kind_id - 1].absTime += selfTime[i][1];
            sortRecords[r.kind_id - 1].freq++;
        }
        foreach (i; 0 .. header.n_kinds)
        {
            sortRecords[i].kindId = i + 1;
            sortRecords[i].avgTime = sortRecords[i].absTime / double(sortRecords[i].freq);
        }
        import std.algorithm : sort;

        sortRecords.sort!((a, b) => a.absTime > b.absTime);
        writeln(" === Kind Time Distribution ===");
        writefln(" %-90s %-10s %-13s %-7s ", "kind", "avgTime", "absTime", "freq");
        foreach (sr; sortRecords)
        {
            writefln(" %-90s %-10.2f %-13.0f %-7d ", kinds[sr.kindId - 1],
                    sr.avgTime, sr.absTime, sr.freq);
        }
    }
    else if (mode == "Symbol")
    {
        import std.conv : to;
        uint sNumber = to!uint(args[3]);
        if (sNumber.ArgOneToN(header.n_symbols))
        {
            writeln("{name: ", getSymbolName(fileBytes, sNumber), 
                "\nlocation: " ~ getSymbolLocation(fileBytes, sNumber) ~ "}");
        }

    }
    else if (mode == "Parent")
    {
        import std.conv : to;
        uint sNumber = to!uint(args[3]);
        if (sNumber.ArgOneToN(header.n_records))
        {
            writeln("{parentId: ", parents[sNumber - 1], "}");
        }

    }
    else if (mode == "Phase")
    {
        import std.conv : to;
        uint sNumber = to!uint(args[3]);
        if (sNumber.ArgOneToN(header.n_phases))
        {
            writeln("{phase: " ~ phases[sNumber - 1] ~ "}");
        }
    }
    else if (mode == "Kind")
    {
        import std.conv : to;
        uint sNumber = to!uint(args[3]);
        if (sNumber.ArgOneToN(header.n_kinds))
        {
            writeln("{kind: " ~ kinds[sNumber - 1] ~ "}");
        }
    }
    else if (mode == "RandSample")
    {
        import std.random : randomSample;
        import std.algorithm : map, each;

        randomSample(records, 24).map!(r => structToString(r)).each!writeln;
    }
    else if (mode == "OutputSelfStats")
    {
        void [] selfTimeMem = (cast(void*)selfTime)[0 .. (selfTime.length * selfTime[0].sizeof)];
        std.file.write(traceFile ~ ".st", selfTimeMem);
        void [] selfMemMem = (cast(void*)selfMem)[0 .. (selfMem.length * selfMem[0].sizeof)];
        std.file.write(traceFile ~ ".sm", selfMemMem);
    }
    else if (mode == "OutputParentTable")
    {
        void [] parentsMem = (cast(void*)parents)[0 .. (parents.length * parents[0].sizeof)];
        std.file.write(traceFile ~ ".pt", parentsMem);
    }
    else if (mode == "ExpensiveTemplateInstances")
    {
        import std.algorithm;
        import std.range;
        auto template_instance_kind_idx = kinds.countUntil("TemplateInstance") + 1;
        foreach(rec; 
            records
            .filter!((r) => r.kind_id == template_instance_kind_idx)
            .array
            .sort!((a, b) => a.end_ticks - a.begin_ticks > b.end_ticks - b.begin_ticks))
        {
            writeln(rec.end_ticks - rec.begin_ticks, "|", phases[rec.phase_id - 1], "|",
                getSymbolLocation(fileBytes, rec), "|", getSymbolName(fileBytes, rec));
        }
    }


    else
        writeln("Mode unsupported: ", mode, "\nsupported modes are: ", supportedModes);
}

struct NoPrint
{
}

string structToString(T)(auto ref T _struct, int indent = 1)
{
    char[] result;

    result ~= T.stringof ~ " (\n";

    foreach (i, e; _struct.tupleof)
    {
        bool skip = false;

        foreach (attrib; __traits(getAttributes, _struct.tupleof[i]))
        {
            static if (is(attrib == NoPrint))
                skip = true;
        }

        if (!skip)
        {
            foreach(_;0 .. indent)
            {
                result ~= "\t";
            }
            alias type = typeof(_struct.tupleof[i]);
            const fieldName = _struct.tupleof[i].stringof["_struct.".length .. $];

            result ~= "" ~ fieldName ~ " : ";

            static if (is(type == enum))
            {
                result ~= enumToString(e);
            }
            else static if (is(type : ulong))
            {
                result ~= itos64(e);
            }
            else
            {
                pragma(msg, type);
                import std.conv : to;

                result ~= to!string(e);
            }
            result ~= ",\n";
        }
    }

    result[$ - 2] = '\n';
    result[$ - 1] = ')';
    return cast(string) result;
}

const(uint) fastLog10(const uint val) pure nothrow @nogc @safe
{
    return (val < 10) ? 0 : (val < 100) ? 1 : (val < 1000) ? 2 : (val < 10000)
        ? 3 : (val < 100000) ? 4 : (val < 1000000) ? 5 : (val < 10000000)
        ? 6 : (val < 100000000) ? 7 : (val < 1000000000) ? 8 : 9;
}

/*@unique*/
static immutable fastPow10tbl = [
    1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000,
];

string itos(const uint val) pure @trusted nothrow
{
    immutable length = fastLog10(val) + 1;
    char[] result;
    result.length = length;

    foreach (i; 0 .. length)
    {
        immutable _val = val / fastPow10tbl[i];
        result[length - i - 1] = cast(char)((_val % 10) + '0');
    }

    return cast(string) result;
}

static assert(mixin(uint.max.itos) == uint.max);

string itos64(const ulong val) pure @trusted nothrow
{
    if (val <= uint.max)
        return itos(val & uint.max);

    uint lw = val & uint.max;
    uint hi = val >> 32;

    auto lwString = itos(lw);
    auto hiString = itos(hi);

    return cast(string) "((" ~ hiString ~ "<< 32)" ~ "|" ~ lwString ~ ")";
}

string enumToString(E)(E v)
{
    static assert(is(E == enum), "emumToString is only meant for enums");
    string result;

Switch:
    switch (v)
    {
        foreach (m; __traits(allMembers, E))
        {
    case mixin("E." ~ m):
            result = m;
            break Switch;
        }

    default:
        {
            result = "cast(" ~ E.stringof ~ ")";
            uint val = v;
            enum headLength = cast(uint)(E.stringof.length + "cast()".length);
            uint log10Val = (val < 10) ? 0 : (val < 100) ? 1 : (val < 1000)
                ? 2 : (val < 10000) ? 3 : (val < 100000) ? 4 : (val < 1000000)
                ? 5 : (val < 10000000) ? 6 : (val < 100000000) ? 7 : (val < 1000000000) ? 8 : 9;
            result.length += log10Val + 1;
            for (uint i; i != log10Val + 1; i++)
            {
                cast(char) result[headLength + log10Val - i] = cast(char)('0' + (val % 10));
                val /= 10;
            }
        }
    }

    return result;
}

enum hexString = (ulong value) {
    const wasZero = !value;
    static immutable NibbleRep = "0123456789abcdef";
    char[] resultBuffer;
    resultBuffer.length = 18; // ulong.sizeof * 2 + "0x".length
    resultBuffer[] = '0';
    int p;
    for (ubyte currentNibble = value & 0xF; value; currentNibble = ((value >>>= 4) & 0xF))
    {
        resultBuffer[17 - p++] = NibbleRep[currentNibble];
    }
    resultBuffer[17 - wasZero - p++] = 'x';
    return cast(string) resultBuffer[17 - p - wasZero .. 18];
};
