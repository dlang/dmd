import core.runtime : dmd_coverDestPath, dmd_coverSetMerge;

extern(C) void _d_cover_register2(string, size_t[], uint[], ubyte);
extern(C) void _d_cover_register_boolean(string, size_t[], uint[], ubyte);

void main(string[] args)
{
    enum source = "src/boolean-lines.txt";
    static size_t[5] flagLines = [0b11101], countLines = [0b00110];
    static uint[5] first = [1, 0, 0, 0, 1], second = [1, 0, 0, 0, 0];
    static uint[5] counts = [0, 3, 2, 0, 0];
    dmd_coverDestPath(args[1]);
    dmd_coverSetMerge(args[3] == "merge");
    if (args[3] == "merge")
        first[4] = 0; // The saved report supplies the hit on the last line.
    if (args[2] == "single")
    {
        _d_cover_register_boolean(source, flagLines[], first[], 0);
        return;
    }
    if (args[2] == "forward")
        _d_cover_register2(source, countLines[], counts[], 0);
    _d_cover_register_boolean(source, flagLines[], first[], 0);
    _d_cover_register_boolean(source, flagLines[], second[], 0);
    if (args[2] == "reverse")
        _d_cover_register2(source, countLines[], counts[], 0);
}
