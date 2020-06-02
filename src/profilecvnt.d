import dmd.trace_file;

import std.file;
import std.file : fileWrite = write;
import core.stdc.stdio;
import core.stdc.stdlib;

void main(string[] args)
{
    import core.memory : GC; GC.disable();    

    if (args.length <= 1 || !exists(args[1]))
    {
        fprintf(stderr, ("Usage: " ~ args[0] ~ " <filename>\n\0").ptr);
        return ;
    }
    auto inFile = args[1];

    auto file_bytes = read(inFile);
    auto header = readHeader(file_bytes);


    enum DMDTRACE = 4990904633913527620UL;
    if (header.magic_number != DMDTRACE)
    {
        fprintf(stderr, "This file does not look like a dmd trace\n");
        return ;
    }
    if (header.FileVersion != 2 && header.FileVersion != 3)
    {
        fprintf(stderr, "Currently this tools only converts from {v2, v3} to v1. {DetectedFileVersion: %d}\n",
            header.FileVersion);
        return ;
    }

    fprintf(stderr, "Currently this will only write out a file which contains records ... the symbol table is dropped\n");

    auto size = header.sizeof + (header.n_records * SymbolProfileRecord.sizeof);
    void [] mem = malloc(size)[0 .. size];
    auto newHeader = cast(typeof(header)*)mem;

    newHeader.magic_number = DMDTRACE;
    newHeader.FileVersion = 1;
    newHeader.n_records = header.n_records;
    newHeader.offset_records = header.sizeof;

    newHeader = null;

    auto newSymbols = cast(SymbolProfileRecord*)(mem.ptr + header.sizeof);

    foreach(i, r;readRecords(file_bytes))
    {
        newSymbols[i] = r;
    }

    newSymbols = null;

    printf("Conversion done.\n");
    fileWrite(inFile ~ ".v1", mem);

    free(mem.ptr);

    printf("File written\n");
}
/+
SymbolProfileRecordV2 toV2(SymbolProfileRecord v1, ulong timeBase = 0)
{
    ulong[3] byteField;

    static assert(bitmask_upper_32 == 0x0000_FFFF_FFFF_0000);

    byteField[0] = ((v1.begin_ticks - timeBase) & bitmask_lower_48);
    byteField[0] |= (((v1.end_ticks - timeBase) & bitmask_lower_16) << 48UL);
    byteField[1] = (((v1.end_ticks -  timeBase) & bitmask_upper_32) >> 16UL);
    byteField[1] |= (((v1.begin_mem           ) & bitmask_lower_32) << 32UL);
    byteField[2] = (((v1.begin_mem            ) & bitmask_upper_16) >> 32UL);
    byteField[2] |= (((v1.end_mem             ) & bitmask_lower_48) << 16UL);

    SymbolProfileRecordV2 v2 = {
        begin_ticks_48_end_ticks_48_begin_memomry_48_end_memory_48 : byteField,
        kind_id_9_phase_id_7 : v1.kind_id & ((1 << 9) -1) | cast(ushort)(v1.phase_id << 9),
        symbol_id : v1.symbol_id
    };
    return v2;
}

SymbolProfileRecord toV1(SymbolProfileRecordV2 v2)
{
    ulong timeBase = 0;
    ulong[3] byteField = v2.begin_ticks_48_end_ticks_48_begin_memomry_48_end_memory_48;

    SymbolProfileRecord v1 = {
        begin_ticks : (byteField[0] & bitmask_lower_48),
        end_ticks : (byteField[0] >> 48UL) | ((byteField[1] & bitmask_lower_32) << 16UL),
        begin_mem : (byteField[1] >> 32UL) | ((byteField[2] & bitmask_lower_16) << 32UL),
        end_mem : (byteField[2] >> 16),
        kind_id : v2.kind_id_9_phase_id_7 & ((1 << 9) -1),
        phase_id : cast(ushort)(v2.kind_id_9_phase_id_7 >> 9)
    };
    
    return v1;
}
enum u48_max = uint.max | (ulong(ushort.max) << 32UL);
static assert(() {
    SymbolProfileRecord v1;
    v1.begin_ticks = u48_max;
    v1.end_ticks = u48_max;
    v1.begin_mem = u48_max;
    v1.end_mem = u48_max;
    v1.kind_id = 27;
    v1.phase_id = 96;

    const v2 = v1.toV2();
    const v1_c = v2.toV1();
    return (v1 == v1_c);
} (), "Conversion from ProfileV1 To ProfileV2 or vice versa is broken");
+/
