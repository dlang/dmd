
import vdc.semantic;
import std.random, std.conv;

struct FalsePointers
{
    string s;
    ubyte[40960] data;
}

FalsePointers* ptrs;

void main(string[] argv)
{
    string fname = argv.length > 1 ? argv[1] : "../../phobos/std/datetime.d";
    size_t nIter = 10;
    if(argv.length > 2)
        nIter = to!size_t(argv[2]);

    // create some random data as false pointer simulation
    version (RANDOMIZE)
        auto rnd = Random(unpredictableSeed);
    else
        auto rnd = Random(2929088778);

    ptrs = new FalsePointers;
    foreach(ref b; ptrs.data)
        b = cast(ubyte) uniform(0, 255, rnd);

    Project prj = new Project;
    foreach(i; 0..nIter)
    {
        prj.addAndParseFile(fname);
    }
}
