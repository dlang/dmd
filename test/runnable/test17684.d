struct IntFieldTest
{
    static int Field;	
    static alias Field this;
}

struct IntPropertyTest
{
    static int Field;
	
	static @property int property()
	{
		return Field;	
	}
	
	static @property void property(int value)
	{
		Field = value;	
	}
	
    static alias property this;
}

struct BoolFieldTest
{
    static bool Field;	
    static alias Field this;
}

struct BoolPropertyTest
{
    static bool Field;
	
	static @property bool property()
	{
		return Field;	
	}
	
	static @property void property(bool value)
	{
		Field = value;	
	}
	
    static alias property this;
}

void main()
{
    // Test `static alias this` to a field of boolean type
    BoolFieldTest = false;
    assert(BoolFieldTest == false);

    bool boolValue = BoolFieldTest;
    assert(boolValue == false);

    BoolFieldTest = !BoolFieldTest;
    assert(BoolFieldTest == true);

    boolValue = BoolFieldTest;
    assert(boolValue == true);

    // Test `static alias this` to a property of boolean type
    BoolPropertyTest = false;
    assert(BoolPropertyTest == false);

    boolValue = BoolPropertyTest;
    assert(boolValue == false);

    BoolPropertyTest = !BoolPropertyTest;
    assert(BoolPropertyTest == true);

    boolValue = BoolPropertyTest;
    assert(boolValue == true);

    // Test `static alias this` to a field of int type
    IntFieldTest = 42;           // test assignment
    assert(IntFieldTest == 42);

    int intValue = IntFieldTest;
    assert(intValue == 42);

    IntFieldTest++;              // test a few unary and binary operators
    assert(IntFieldTest == 43);

    IntFieldTest += 1;
    assert(IntFieldTest == 44);

    IntFieldTest--;
    assert(IntFieldTest == 43);

    IntFieldTest -= 1;
    assert(IntFieldTest == 42);

    assert(~IntFieldTest == ~42);

    // Test `static alias this` to a property of int type
    IntPropertyTest = 42;           // test assignment
    assert(IntPropertyTest == 42);

    intValue = IntPropertyTest;
    assert(intValue == 42);

    // These currently don't work due to https://issues.dlang.org/show_bug.cgi?id=8006
    // IntPropertyTest++;
    // assert(IntPropertyTest == 43);

    // IntPropertyTest += 1;
    // assert(IntPropertyTest == 44);

    // IntPropertyTest--;
    // assert(IntPropertyTest == 43);

    // IntPropertyTest -= 1;
    // assert(IntPropertyTest == 42);

    assert(~IntPropertyTest == ~42);
}
