// https://issues.dlang.org/show_bug.cgi?id=19463

void test() @nogc
{
    throw new Exception("wat");
}
