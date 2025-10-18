//https://issues.dlang.org/show_bug.cgi?id=24078

shared static this()
{
    assert(["c"] ~ "a" ~ "b" == ["c", "a", "b"]);
}
