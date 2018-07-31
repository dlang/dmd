// EXTRA_OBJC_SOURCES

extern (Objective-C)
interface A
{
    void oneTwo(int a, int b) pure @selector("one:two:");
    void test(int a, int b, int c) @selector("test:::");
}
