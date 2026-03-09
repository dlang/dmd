enum MyEnum { VALUE_A, VALUE_B, VALUE_C }

struct Data { 
    int x, y; 
}

struct Nested {
    Data info;
    MyEnum status;
}

void checkEnum(MyEnum m) {
    assert(m == MyEnum.VALUE_B);
}

void checkStruct(Data d) {
    assert(d.x == 10 && d.y == 20);
}

void main() {
    Data data = $(1, 2);
    assert(data.x == 1);
    assert(data.y == 2);

    MyEnum myenum = $.VALUE_A;
    assert(myenum == MyEnum.VALUE_A);

    checkEnum($.VALUE_B);
    checkStruct($(10, 20));

    Nested n = $($(100, 200), $.VALUE_C);
    assert(n.info.x == 100);
    assert(n.status == MyEnum.VALUE_C);

    int[] pointerBitmap = [10, 20, 30, 40, 50];
    
    int[] slice = pointerBitmap[1 .. $]; 
    assert(slice.length == 4);
    assert(slice[0] == 20);
    
    assert(slice[$ - 1] == 50);

}
