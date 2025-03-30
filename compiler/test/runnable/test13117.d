// PERMUTE_ARGS: -O -release -g
import std.file, std.stdio;

int main()
{
    auto size = thisExePath.getSize();
    writeln(size);
    version (D_LP64)
        enum limit = 1_906_432;
    else
        enum limit = 1_900_000;
    return size > limit * 13 / 10;
}
