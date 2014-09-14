// PLATFORM: osx

extern (Objective-C)
interface A {
	void test(T)(T a) [test:]; // selector defined for template
}
