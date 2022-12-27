// https://issues.dlang.org/show_bug.cgi?id=23585

void f()
{
    import std.file : exists;
    exists("");
}
