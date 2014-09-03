// REQUIRED_ARGS: -inline
// PERMUTE_ARGS: -O -release -g
import std.file, std.stdio;

int main()
{
    auto size = thisExePath.getSize();
    writeln(size);
    version (D_LP64)
        enum limit = 2023652;
    else
        enum limit = 1763328;
    return size > limit * 11 / 10;
}
