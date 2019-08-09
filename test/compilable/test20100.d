// REQUIRED_ARGS: -checkaction=context
/*
TEST_OUTPUT:
---
---
*/
struct STuple {
	bool opEquals(STuple) { return false; }
}

class CTuple {
}

void testStruct() {
	STuple t1;
	assert(t1 == t1);
}

void testClass() {
	CTuple t1 = new CTuple();
	assert(t1 == t1);
}

void main() {
    testStruct();
    testClass();
}
