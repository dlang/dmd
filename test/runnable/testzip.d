// PERMUTE_ARGS:
// EXECUTE_ARGS: runnable/extra-files/testzip.zip ${RESULTS_DIR}/runnable/testzip-out.zip
// POST_SCRIPT: runnable/extra-files/testzip-postscript.sh

import core.stdc.stdio;
import std.conv;
import std.stdio;
import std.file;
import std.datetime;
import std.zip;
import std.zlib;

int main(string[] args)
{
    byte[] buffer;
    std.zip.ZipArchive zr;
    string zipname;
    string outzipname;
    ubyte[] data;

    testzlib();
    testzlib2();
    if (args.length > 1)
	zipname = args[1];
    else
	zipname = "test.zip";
    if (args.length > 2)
        outzipname = args[2];
    else
        outzipname = "foo.zip";
    buffer = cast(byte[])std.file.read(zipname);
    zr = new std.zip.ZipArchive(cast(void[])buffer);
    printf("comment = '%.*s'\n", zr.comment.length, zr.comment.ptr);
    writeln(zr.toString());

    foreach (ArchiveMember de; zr.directory)
    {
	writeln(de.toString());
	auto s = DosFileTimeToSysTime(de.time).toString();
	printf("date = '%.*s'\n", s.length, s.ptr);

	arrayPrint(de.compressedData);

	data = zr.expand(de);
	printf("data = '%.*s'\n", data.length, data.ptr);
    }

    printf("**Success**\n");

    zr = new std.zip.ZipArchive();
    ArchiveMember am = new ArchiveMember();
    am.compressionMethod = 8;
    am.name = "foo.bar";
    //am.extra = cast(ubyte[])"ExTrA";
    am.expandedData = cast(ubyte[])"We all live in a yellow submarine, a yellow submarine";
    zr.addMember(am);
    void[] data2 = zr.build();
    std.file.write(outzipname, cast(byte[])data2);

    return 0;
}

void arrayPrint(ubyte[] array)
{
    //printf("array %p,%d\n", (void*)array, array.length);
    for (int i = 0; i < array.length; i++)
    {
	printf("%02x ", array[i]);
	if (((i + 1) & 15) == 0)
	    printf("\n");
    }
    printf("\n\n");
}

/******************************************/

void testzlib()
{
    ubyte[] src = cast(ubyte[])
"the quick brown fox jumps over the lazy dog\r
the quick brown fox jumps over the lazy dog\r
";
    ubyte[] dst;

    arrayPrint(src);
    dst = cast(ubyte[])std.zlib.compress(cast(void[])src);
    arrayPrint(dst);
    src = cast(ubyte[])std.zlib.uncompress(cast(void[])dst);
    arrayPrint(src);
}

/******************************************/

void testzlib2()
{
        static ubyte [] buf = [1,2,3,4,5,0,7,8,9];

        auto ar = new ZipArchive;

        auto am = new ArchiveMember;  // 10
        am.name = "buf";
        am.expandedData = buf;
        am.compressionMethod = 8;
        am.time = SysTimeToDosFileTime(Clock.currTime());
        ar.addMember (am);            // 15

        auto zip1 = ar.build ();

        ar = new ZipArchive (zip1);
} 

