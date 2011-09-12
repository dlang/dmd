
extern(C) int printf(const char* fmt, ...);

/***************************************/

void test1()
{
    char[] a;

    int foo()
    {
        printf("foo\n");
        a ~= "foo";
        return 10;
    }

    foreach (i; 0 .. foo())
    {
        printf("%d\n", i);
        a ~= cast(char)('0' + i);
    }
    assert(a == "foo0123456789");

    foreach_reverse (i; 0 .. foo())
    {
        printf("%d\n", i);
        a ~= cast(char)('0' + i);
    }
    assert(a == "foo0123456789foo9876543210");
}

/***************************************/
// 3187

class Collection
{
    int opApply(int delegate(ref Object) a)
    {
        return 0;
    }
}

Object testForeach(Collection level1, Collection level2)
{
    foreach (first; level1) {
        foreach (second; level2)
            return second;
    }
    return null;
}

void test3187()
{
    testForeach(new Collection, new Collection);
}

/***************************************/
// 5605

struct MyRange
{
    int theOnlyOne;

    @property bool empty() const
    {
        return true;
    }

    @property ref int front()
    {
        return theOnlyOne;
    }

    void popFront()
    {}
}

struct MyCollection
{
    MyRange opSlice() const
    {
        return MyRange();
    }
}

void test5605()
{
    auto coll = MyCollection();

    foreach (i; coll) {            // <-- compilation error
        // ...
    }
}

/***************************************/
// 7004

void func7004(A...)(A args)
{
    foreach (i, e; args){}        // OK
    foreach (uint i, e; args){}   // OK
    foreach (size_t i, e; args){} // NG
}
void test7004()
{
    func7004(1, 3.14);
}

/***************************************/
// 6652

void test6652()
{
    size_t sum;

    foreach (i; 0 .. 10)
        sum += i++; // 0123456789
    assert(sum == 45);

    sum = 0;
    foreach (ref i; 0 .. 10)
        sum += i++; // 02468
    assert(sum == 20);

    sum = 0;
    foreach_reverse (i; 0 .. 10)
        sum += i--; // 9876543210
    assert(sum == 45);

    sum = 0;
    foreach_reverse (ref i; 0 .. 10)
        sum += i--; // 97531
    assert(sum == 25);

    enum ary = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    sum = 0;
    foreach (i, v; ary)
    {
        assert(i == v);
        sum += i++; // 0123456789
    }
    assert(sum == 45);

    sum = 0;
    foreach (ref i, v; ary)
    {
        assert(i == v);
        sum += i++; // 02468
    }
    assert(sum == 20);

    sum = 0;
    foreach_reverse (i, v; ary)
    {
        assert(i == v);
        sum += i--; // 9876543210
    }
    assert(sum == 45);

    sum = 0;
    foreach_reverse (ref i, v; ary)
    {
        assert(i == v);
        sum += i--; // 97531
    }
    assert(sum == 25);

    static struct Iter
    {
        ~this()
        {
            ++_dtorCount;
        }

        bool opCmp(ref const Iter rhs)
        {
            return _pos == rhs._pos;
        }

        void opUnary(string op)() if(op == "++" || op == "--")
        {
            mixin(op ~ q{_pos;});
        }

        size_t _pos;
        static size_t _dtorCount;
    }

    Iter._dtorCount = sum = 0;
    foreach (v; Iter(0) .. Iter(10))
        sum += v._pos++; // 0123456789
    assert(sum == 45 && Iter._dtorCount == 12);

    Iter._dtorCount = sum = 0;
    foreach (ref v; Iter(0) .. Iter(10))
        sum += v._pos++; // 02468
    assert(sum == 20 && Iter._dtorCount == 2);

    // additional dtor calls due to unnecessary postdecrements
    Iter._dtorCount = sum = 0;
    foreach_reverse (v; Iter(0) .. Iter(10))
        sum += v._pos--; // 9876543210
    assert(sum == 45 && Iter._dtorCount >= 12);

    Iter._dtorCount = sum = 0;
    foreach_reverse (ref v; Iter(0) .. Iter(10))
        sum += v._pos--; // 97531
    assert(sum == 25 && Iter._dtorCount >= 2);
}

/***************************************/

int main()
{
    test1();
    test3187();
    test5605();
    test7004();
    test6652();

    printf("Success\n");
    return 0;
}
