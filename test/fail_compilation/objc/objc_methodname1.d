// PLATFORM: osx

extern (Objective-C)
interface A {
	void test(T)(T a) [+]; // not a valid method name
}
