// PLATFORM: osx

extern (Objective-C)
interface A {
	void test(int a, int b, int c) @selector("test:"); // non-matching number of colon
}
