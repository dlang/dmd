import core.runtime : dmd_coverDestPath, dmd_coverSetMerge;

extern(C) void _d_cover_register2(string, size_t[], uint[], ubyte);
extern(C) void _d_cover_register_boolean(string, size_t[], uint[], ubyte);

void main(string[] args)
{
    enum source = "src/fragment-lines.txt";
    static size_t[3] flagLines = [1], countLines = [7];
    static uint[3] flags = [1], counts = [3, 3, 0];
    dmd_coverDestPath(args[1]);
    dmd_coverSetMerge(true);
    if (args.length == 2)
        _d_cover_register_boolean(source, flagLines[], flags[], 0);
    _d_cover_register2(source, countLines[], counts[], 0);
    if (args.length != 2)
        _d_cover_register_boolean(source, flagLines[], flags[], 0);
}
