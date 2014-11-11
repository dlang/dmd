// PLATFORM: osx

extern (Objective-C)
interface A {
	void test(T)(T a) @selector("test:"); // selector defined for template
}

void test ()
{
    A a;
    a.test(3);
}
