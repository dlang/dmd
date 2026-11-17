import core.runtime : dmd_coverDestPath;

extern(C) void _d_cover_register2(string, size_t[], uint[], ubyte);

void main(string[] args)
{
    dmd_coverDestPath(args[1]);
    enum source = "src/duplicate-lines.txt";
    string other = args[2] == "alias" ? "src/./duplicate-lines.txt" : source;
    static size_t[3] firstLines = [5], secondLines = [3];
    static uint[3] first = [2, 0, 0], second = [3, 3, 0];
    const length = args[2] == "stale" ? 2 : 3;

    if (args[2] == "empty")
    {
        _d_cover_register2(source, null, null, 0);
        _d_cover_register2(source, null, null, 0);
        return;
    }

    if (args[3] == "forward")
    {
        _d_cover_register2(source, null, null, 0);
        _d_cover_register2(source, firstLines[], first[], 0);
    }
    _d_cover_register2(other, secondLines[0 .. length], second[0 .. length], 0);
    if (args[3] == "reverse")
    {
        _d_cover_register2(source, firstLines[], first[], 0);
        _d_cover_register2(source, null, null, 0);
    }
}
