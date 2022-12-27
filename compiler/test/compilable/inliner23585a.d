// COMPILED_IMPORTS: extra-files/inliner23585b.d
// REQUIRED_ARGS: -os=windows -m32 -inline -O

// https://issues.dlang.org/show_bug.cgi?id=23585

void f()
{
    import std.file : exists;
    exists("");
}
