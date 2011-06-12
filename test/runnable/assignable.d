import std.c.stdio;

template TypeTuple(T...){ alias T TypeTuple; }

/***************************************************/
// 2625

struct Pair {
    immutable uint g1;
    uint g2;
}

void test1() {
    Pair[1] stuff;
    static assert(!__traits(compiles, (stuff[0] = Pair(1, 2))));
}

/***************************************************/
// 5327

struct ID
{
    immutable int value;
}

struct Data
{
    ID id;
}
void test2()
{
    Data data = Data(ID(1));
    immutable int* val = &data.id.value;
    static assert(!__traits(compiles, data = Data(ID(2))));
}

/***************************************************/

struct S31A
{
    union
    {
        immutable int field1;
        immutable int field2;
    }

    enum result = false;
}
struct S31B
{
    union
    {
        immutable int field1;
        int field2;
    }

    enum result = true;
}
struct S31C
{
    union
    {
        int field1;
        immutable int field2;
    }

    enum result = true;
}
struct S31D
{
    union
    {
        int field1;
        int field2;
    }

    enum result = true;
}

struct S32A
{
    int dummy0;
    union
    {
        immutable int field1;
        int field2;
    }

    enum result = true;
}
struct S32B
{
    immutable int dummy0;
    union
    {
        immutable int field1;
        int field2;
    }

    enum result = false;
}


struct S32C
{
    union
    {
        immutable int field1;
        int field2;
    }
    int dummy1;

    enum result = true;
}
struct S32D
{
    union
    {
        immutable int field1;
        int field2;
    }
    immutable int dummy1;

    enum result = false;
}

void test3()
{
    foreach (S; TypeTuple!(S31A,S31B,S31C,S31D, S32A,S32B,S32C,S32D))
    {
        S s;
        static assert(__traits(compiles, s = s) == S.result);
    }
}

/***************************************************/

int main()
{
    test1();
    test2();
    test3();

    printf("Success\n");
    return 0;
}
