// PLATFORM: osx

interface A {
	void oneTwo(int a, int b) @selector("one:two:"); // selector attached in non-Objective-C interface
}
