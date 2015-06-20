// PERMUTE_ARGS: -O -release -g
import std.file, std.stdio;

int main()
{
    auto size = thisExePath.getSize();
    writeln(size);
    version (D_LP64)
        enum limit = 1328520;
    else
        enum limit = 1253540;
    return size > limit * 11 / 10;
}
