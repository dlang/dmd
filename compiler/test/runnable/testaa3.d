
/***************************************************/

/* Test all aa properties (length, values, keys, opApply(Key, Value), opApply_r(Value),
 * dup, byKey, byValue, rehash, opIndex, opIndexAssign, opIn_r)
 *
 * With all aas: literal, variable, ref parameter, rvalue
 */

int testLiteral()
{
    assert([5 : 4].length == 1);
    assert([5 : 4].values == [4]);
    assert([5 : 4].keys == [5]);
    foreach (k, v; [5 : 4])
        assert(k == 5 && v == 4);
    foreach (v; [5 : 4])
        assert(v == 4);
    assert([5 : 4].dup == [5 : 4]);
    assert([5 : 4].dup);
    if (!__ctfe)
    foreach (k; [5 : 4].byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach (v; [5 : 4].byValue)
        assert(v == 4);
    assert([5 : 4].rehash == [5 : 4]);
    assert([5 : 4][5] == 4);
    assert([5 : 4].get(5, 2) == 4);
    assert([5 : 4].get(1, 2) == 2);
    //assert(([5 : 4][3] = 7) == 7);
    assert(*(5 in [5 : 4]) == 4);
    return 1;
}

int testVar()
{
    auto aa = [5 : 4];
    assert(aa.length == 1);
    assert(aa.values == [4]);
    assert(aa.keys == [5]);
    foreach (k, v; aa)
        assert(k == 5 && v == 4);
    foreach (v; aa)
        assert(v == 4);
    assert(aa.dup == aa);
    assert(aa.dup);
    {
        auto bb = aa.dup();
        assert(bb == aa);
        //assert(aa !is bb);  // issue in ctfeIdentity
        assert(&aa[5] !is &bb[5]);
        bb[5] = 10;
        assert(aa[5] == 4);
        assert(bb[5] == 10);
    }
    if (!__ctfe)
    foreach (k; aa.byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach (v; aa.byValue)
        assert(v == 4);
    assert(aa.rehash == aa);
    assert(aa[5] == 4);
    assert(aa.get(5, 2) == 4);
    assert(aa.get(1, 2) == 2);
    assert(*(5 in aa) == 4);
    assert((aa[3] = 7) == 7);
    return 1;
}

int testVarConst()
{
    const aa = [5 : 4];
    assert(aa.length == 1);
    assert(aa.values == [4]);
    assert(aa.keys == [5]);
    foreach (k, v; aa)
        assert(k == 5 && v == 4);
    foreach (v; aa)
        assert(v == 4);
    //assert(aa.dup == aa);
    assert(aa.dup);
    {
        auto bb = aa.dup();
        //assert(bb == aa);
        //assert(aa !is bb);  // issue in ctfeIdentity
        assert(&aa[5] !is &bb[5]);
    }
    if (!__ctfe)
    foreach (k; aa.byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach (v; aa.byValue)
        assert(v == 4);
    //assert(aa.rehash == aa);
    assert(aa[5] == 4);
    assert(aa.get(5, 2) == 4);
    assert(aa.get(1, 2) == 2);
    assert(*(5 in aa) == 4);
    //assert((aa[3] = 7) == 7);
    return 1;
}

int testVarImmutable()
{
    immutable aa = [5 : 4];
    assert(aa.length == 1);
    assert(aa.values == [4]);
    assert(aa.keys == [5]);
    foreach (k, v; aa)
        assert(k == 5 && v == 4);
    foreach (v; aa)
        assert(v == 4);
    //assert(aa.dup == aa);
    assert(aa.dup);
    {
        auto bb = aa.dup();
        //assert(bb == aa);
        //assert(aa !is bb);  // issue in ctfeIdentity
        assert(&aa[5] !is &bb[5]);
    }
    if (!__ctfe)
    foreach (k; aa.byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach (v; aa.byValue)
        assert(v == 4);
    // assert(aa.rehash == aa);
    assert(aa[5] == 4);
    assert(aa.get(5, 2) == 4);
    assert(aa.get(1, 2) == 2);
    assert(*(5 in aa) == 4);
    //assert((aa[3] = 7) == 7);
    return 1;
}

int testPointer()
{
    auto x = [5 : 4];
    auto aa = &x;
    assert(aa.length == 1);
    assert(aa.values == [4]);
    assert(aa.keys == [5]);
    // foreach (k, v; aa)
    //     assert(k == 5 && v == 4);
    // foreach (v; aa)
    //     assert(v == 4);
    assert(aa.dup == *aa);
    assert(aa.dup);
    {
        auto bb = aa.dup();
        assert(bb == *aa);
        //assert(aa !is bb);  // issue in ctfeIdentity
        assert(&(*aa)[5] !is &bb[5]);
        bb[5] = 10;
        assert((*aa)[5] == 4);
        assert(bb[5] == 10);
    }
    if (!__ctfe)
    foreach (k; aa.byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach (v; aa.byValue)
        assert(v == 4);
    if (!__ctfe)
    assert(aa.rehash == *aa);
    assert((*aa)[5] == 4);
    assert(aa.get(5, 2) == 4);
    assert(aa.get(1, 2) == 2);
    // assert(*(5 in aa) == 4);
    if (!__ctfe)
    assert(((*aa)[3] = 7) == 7);
    return 1;
}

int testPointerConst()
{
    const x = [5 : 4];
    const aa = &x;
    assert(aa.length == 1);
    assert(aa.values == [4]);
    assert(aa.keys == [5]);
    // foreach (k, v; aa)
    //     assert(k == 5 && v == 4);
    // foreach (v; aa)
    //     assert(v == 4);
    // assert(aa.dup == *aa);
    assert(aa.dup);
    {
        auto bb = aa.dup();
        //assert(bb == aa);
        //assert(aa !is bb);  // issue in ctfeIdentity
        assert(&(*aa)[5] !is &bb[5]);
    }
    if (!__ctfe)
    foreach (k; aa.byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach (v; aa.byValue)
        assert(v == 4);
    // assert(aa.rehash == aa);
    assert((*aa)[5] == 4);
    assert(aa.get(5, 2) == 4);
    assert(aa.get(1, 2) == 2);
    // assert(*(5 in aa) == 4);
    // assert(((*aa)[3] = 7) == 7);
    return 1;
}

int testPointerImmutable()
{
    immutable x = [5 : 4];
    auto aa = &x;
    assert(aa.length == 1);
    assert(aa.values == [4]);
    assert(aa.keys == [5]);
    // foreach (k, v; aa)
    //     assert(k == 5 && v == 4);
    // foreach (v; aa)
    //     assert(v == 4);
    // assert(aa.dup == *aa);
    assert(aa.dup);
    {
        auto bb = aa.dup();
        //assert(bb == (*aa));
        //assert(aa !is bb);  // issue in ctfeIdentity
        assert(&(*aa)[5] !is &bb[5]);
    }
    if (!__ctfe)
    foreach (k; aa.byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach (v; aa.byValue)
        assert(v == 4);
    // assert(aa.rehash == aa);
    assert((*aa)[5] == 4);
    assert(aa.get(5, 2) == 4);
    assert(aa.get(1, 2) == 2);
    // assert(*(5 in aa) == 4);
    // assert(((*aa)[3] = 7) == 7);
    return 1;
}

int testRef()
{
    auto aa = [5 : 4];
    return testRefx(aa);
}
int testRefx(ref int[int] aa)
{
    assert(aa.length == 1);
    assert(aa.values == [4]);
    assert(aa.keys == [5]);
    foreach (k, v; aa)
        assert(k == 5 && v == 4);
    foreach (v; aa)
        assert(v == 4);
    assert(aa.dup == aa);
    assert(aa.dup);
    {
        auto bb = aa.dup();
        assert(bb == aa);
        //assert(aa !is bb);  // issue in ctfeIdentity
        assert(&aa[5] !is &bb[5]);
        bb[5] = 10;
        assert(aa[5] == 4);
        assert(bb[5] == 10);
    }
    if (!__ctfe)
    foreach (k; aa.byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach (v; aa.byValue)
        assert(v == 4);
    assert(aa.rehash == aa);
    assert(aa[5] == 4);
    assert(aa.get(5, 2) == 4);
    assert(aa.get(1, 2) == 2);
    assert((aa[3] = 7) == 7);
    assert(*(5 in aa) == 4);
    return 1;
}

int testRet()
{
    assert(testRetx().length == 1);
    assert(testRetx().values == [4]);
    assert(testRetx().keys == [5]);
    foreach (k, v; testRetx())
        assert(k == 5 && v == 4);
    foreach (v; testRetx())
        assert(v == 4);
    assert(testRetx().dup == testRetx());
    assert(testRetx().dup);
    if (!__ctfe)
    foreach (k; testRetx().byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach (v; testRetx().byValue)
        assert(v == 4);
    assert(testRetx().rehash == testRetx());
    assert(testRetx()[5] == 4);
    assert(testRetx().get(5, 2) == 4);
    assert(testRetx().get(1, 2) == 2);
    //assert((testRetx()[3] = 7) == 7);
    assert(*(5 in testRetx()) == 4);
    return 1;
}
int[int] testRetx()
{
    return [5 : 4];
}

void aafunc(int[int] aa) {}

void testTypeinfo()
{
    int[int] a = [ 1:1, 2:4, 3:9, 4:16 ];
    int[int] b = [ 1:1, 2:4, 3:9, 4:16 ];
    assert(a == b);

    hash_t ahash1 = hashOf(a);
    hash_t ahash2 = typeid(a).getHash(&a);
    assert(ahash1 == ahash2);
    hash_t bhash1 = hashOf(a);
    hash_t bhash2 = typeid(a).getHash(&a);
    assert(bhash1 == bhash2);
    assert(ahash1 == bhash1);
    assert(typeid(a).equals(&a, &b));

    string[string] c = [ "1":"one", "2":"two", "3":"three" ];
    hash_t chash1 = hashOf(c);
    hash_t chash2 = typeid(c).getHash(&c);
    assert(chash1 == chash2);
    assert(chash1 != ahash2);
    assert(typeid(c).equals(&c, &c));
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=12214

void test12214() pure nothrow
{
    int[int] aa;
    auto n = aa.length;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=12220
// https://issues.dlang.org/show_bug.cgi?id=12221

void test12220()
{
    short[short] hash;
    short k = hash.get(1, 2);
    assert(k == 2);

    enum Key : short { a = 10 }
    short a = hash.get(Key.a, Key.a);
    assert(a == 10);
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=12403

void test12403()
{
    const(int)[int] m;
    assert(m.get(0, 1) == 1);
}

/***************************************************/
// regressions after converting AA to template
void test21066()
{
    const(int) getValue() { return 0; }
    int[] arr;
    arr = [getValue()]; // works
    int[][string] aa;
    aa["a"] = [getValue()]; // fails: cannot implicitly convert expression `__aaval` of type `const(int)[]` to `int[]`

    string[int[]] aa2;
    aa2[[getValue()]] = "a"; // no problem because key type is automatically const(int)[]
}

void test22354()
{
    int[][][string] aa;  // AA with nested array value type
    int[] elem;
    aa["x"] = null;
    aa["x"] ~= null;     // This append is silently lost!
    assert(aa["x"].length == 1);  // FAILS: length is still 0
}

// https://github.com/dlang/dmd/issues/22406
void testShared()
{
    shared int[int] processes = [1: 1, 2:4, 3:9];

    cast(void)processes.sizeof;
    cast(void)processes.length;
    cast(void)processes.dup;
    cast(void)processes.rehash;
    //cast(void)processes.clear;
    //cast(void)processes.keys;
    //cast(void)processes.values;
    //cast(void)processes.byKey;
    //cast(void)processes.byValue;
    //cast(void)processes.byKeyValue;
    processes.remove(3);
    assert(2 in processes);

    immutable int[int] iprocesses = [1: 1, 2:4, 3:9];

    cast(void)iprocesses.sizeof;
    cast(void)iprocesses.length;
    cast(void)iprocesses.dup;
    //cast(void)iprocesses.rehash;
    //cast(void)iprocesses.clear;
    cast(void)iprocesses.keys;
    cast(void)iprocesses.values;
    cast(void)iprocesses.byKey;
    cast(void)iprocesses.byValue;
    cast(void)iprocesses.byKeyValue;
    //iprocesses.remove(3);
    assert(2 in iprocesses);
}

// https://github.com/dlang/dmd/issues/22556
void test22556()
{
    static struct RefCounted(T)
    {
        this(this) {}
    }
    struct S {}
    alias R = RefCounted!S;
    shared R[string] foo;

    (cast (R[string]) foo).clear; // WORKS
    (cast() foo).clear; // FAILS with 2.112.0, WORKS with 2.111.0
    static assert(!__traits(compiles, foo.clear));
}

/***************************************************/

// https://github.com/dlang/dmd/issues/22567
void test22567()
{
    struct S
    {
        string[string] data;
        alias this = data;
    }

    S[string] foo;
    foo["bar"] = S();
    foo["bar"]["baz"] = "boom";
    assert(foo["bar"]["baz"] == "boom");
}

/***************************************************/

void main()
{
    assert(testLiteral());
    static assert(testLiteral());
    assert(testVar());
    static assert(testVar());
    assert(testVarConst());
    static assert(testVarConst());
    assert(testVarImmutable());
    static assert(testVarImmutable());
    assert(testPointer());
    static assert(testPointer());
    assert(testPointerConst());
    static assert(testPointerConst());
    assert(testPointerImmutable());
    static assert(testPointerImmutable());
    assert(testRef());
    static assert(testRef());
    assert(testRet());
    static assert(testRet());

    testTypeinfo();
    test12220();
    test12403();
    test21066();
    test22354();
    testShared();
    test22567();
    test22556();
}
