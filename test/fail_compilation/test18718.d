/*
TEST_OUTPUT:
---
fail_compilation/test18718.d(15): Error: Maximal recursion depth hit
fail_compilation/test18718.d(11): Error: mixin `test18718.World.BuildStuff!()` error instantiating
---
*/

// https://issues.dlang.org/show_bug.cgi?id=18718
struct World {
	mixin BuildStuff;
}

template BuildStuff() {
	static foreach(elem; __traits(allMembers, typeof(this))) {

	}
}
