/**
COMPILE_SEPARATELY:
EXTRA_SOURCES: imports/string_literal_merge_imp.d
*/

// https://issues.dlang.org/show_bug.cgi?id=24286

extern(C) string getHello();

extern(C) int main()
{
    assert(getHello.ptr == "hello".ptr);
    return 0;
}
