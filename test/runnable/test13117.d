// PERMUTE_ARGS: -O -release -g
import std.file, std.stdio;

int main()
{
    return 0; //depends on AA implementation
    auto size = thisExePath.getSize();
    writeln(size);
    version (D_LP64)
        enum limit = 1195096;
    else
        enum limit = 1042973;
    return size > limit * 11 / 10;
}
