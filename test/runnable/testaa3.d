
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
    foreach(k, v; [5 : 4])
        assert(k == 5 && v == 4);
    foreach(v; [5 : 4])
        assert(v == 4);
    assert([5 : 4].dup == [5 : 4]);
    assert([5 : 4].dup);
    if (!__ctfe)
    foreach(k; [5 : 4].byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach(v; [5 : 4].byValue)
        assert(v == 4);
    assert([5 : 4].rehash == [5 : 4]);
    assert([5 : 4][5] == 4);
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
    foreach(k, v; aa)
        assert(k == 5 && v == 4);
    foreach(v; aa)
        assert(v == 4);
    assert(aa.dup == aa);
    assert(aa.dup);
    if (!__ctfe)
    foreach(k; aa.byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach(v; aa.byValue)
        assert(v == 4);
    // assert(aa.rehash == aa);
    assert(aa[5] == 4);
    assert(*(5 in aa) == 4);
    assert((aa[3] = 7) == 7);
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
    foreach(k, v; aa)
        assert(k == 5 && v == 4);
    foreach(v; aa)
        assert(v == 4);
    assert(aa.dup == aa);
    assert(aa.dup);
    if (!__ctfe)
    foreach(k; aa.byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach(v; aa.byValue)
        assert(v == 4);
    // assert(aa.rehash == aa);
    assert(aa[5] == 4);
    assert((aa[3] = 7) == 7);
    assert(*(5 in aa) == 4);
    return 1;
}

int testRet()
{
    assert(testRetx().length == 1);
    assert(testRetx().values == [4]);
    assert(testRetx().keys == [5]);
    foreach(k, v; testRetx())
        assert(k == 5 && v == 4);
    foreach(v; testRetx())
        assert(v == 4);
    assert(testRetx().dup == testRetx());
    assert(testRetx().dup);
    if (!__ctfe)
    foreach(k; testRetx().byKey)
        assert(k == 5);
    if (!__ctfe)
    foreach(v; testRetx().byValue)
        assert(v == 4);
    assert(testRetx().rehash == testRetx());
    assert(testRetx()[5] == 4);
    //assert((testRetx()[3] = 7) == 7);
    assert(*(5 in testRetx()) == 4);
    return 1;
}
int[int] testRetx()
{
    return [5 : 4];
}

void aafunc(int[int] aa) {}

void main()
{
    assert(testLiteral());
    static assert(testLiteral());
    assert(testVar());
    static assert(testVar());
    assert(testRef());
    static assert(testRef());
    assert(testRet());
    static assert(testRet());
}
