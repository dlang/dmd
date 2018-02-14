// ARG_SETS: -debug; -o-
// https://issues.dlang.org/show_bug.cgi?id=16492

void mayCallGC();

void test() @nogc pure
{
    debug new int(1);
    debug
    {
        mayCallGC();
        auto b = [1, 2, 3];
        b ~= 4;
    }
}
