// PLATFORM: osx

extern (Objective-C)
interface I {
	void class_() @selector("class");
	void doForEach(int a, int b) @selector("do:foreach:");
	void doThis(int a, int b, int c) @selector("do:this:with:");
}