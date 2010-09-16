
extern (Objective-C)
interface A {
	void oneTwo(int a, int b) pure [one:two:];
	void test(int a, int b, int c) [test:::];
	void test2(int a, int b, int c); // implicit selector
}
