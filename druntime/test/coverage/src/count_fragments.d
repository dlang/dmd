import core.runtime : dmd_coverDestPath;

extern(C) void _d_cover_register2(string, size_t[], uint[], ubyte);

void main(string[] args)
{
    dmd_coverDestPath(args[1]);
    static size_t[3] firstLines = [5], secondLines = [3];
    static uint[3] first = [2, 0, 0], second = [3, 3, 0];
    _d_cover_register2("src/./count-lines.txt", firstLines[], first[], 0);
    auto length = args.length == 2 ? 3 : 2;
    _d_cover_register2("src/count-lines.txt", secondLines[0 .. length],
        second[0 .. length], 0);
}
