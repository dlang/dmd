// PLATFORM: osx

extern (Objective-C)
interface A {
	void oneTwo(int a, int b) pure @selector("one:two:");
	void test(int a, int b, int c) @selector("test:::");
	void test2(int a, int b, int c); // implicit selector
}
