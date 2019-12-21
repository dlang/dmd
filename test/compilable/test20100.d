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

// https://issues.dlang.org/show_bug.cgi?id=20331
void testAnonymousFunction()
{
    bool function() check = () => true;
    assert(check());

    bool result = true;
    assert((() => result)());
}

void main() {
    testStruct();
    testClass();
    testAnonymousFunction();
}
