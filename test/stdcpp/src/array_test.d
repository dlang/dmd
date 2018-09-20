import core.stdcpp.array;

extern (C++) int test_array()
{
    array!(int, 5) arr;
    arr[] = [0, 2, 3, 4, 5];
    ++arr.front;

    assert(arr.size == 5);
    assert(arr.length == 5);
    assert(arr.max_size == 5);
    assert(arr.empty == false);
    assert(arr.front == 1);

    assert(sumOfElements_val(arr)[0] == 160);
    assert(sumOfElements_ref(arr)[0] == 15);

    array!(int, 0) arr2;
    assert(arr2.size == 0);
    assert(arr2.length == 0);
    assert(arr2.max_size == 0);
    assert(arr2.empty == true);
    assert(arr2[] == []);

    return 0;
}


extern(C++):

// test the ABI for calls to C++
array!(int, 5) sumOfElements_val(array!(int, 5) arr);
ref array!(int, 5) sumOfElements_ref(return ref array!(int, 5) arr);

// test the ABI for calls from C++
array!(int, 5) fromC_val(array!(int, 5) arr)
{
    assert(arr[] == [1, 2, 3, 4, 5]);
    assert(arr.front == 1);
    assert(arr.back == 5);
    assert(arr.at(2) == 3);

    arr.fill(2);

    int r;
    foreach (e; arr)
        r += e;

    assert(r == 10);

    arr[] = r;
    return arr;
}

ref array!(int, 5) fromC_ref(return ref array!(int, 5) arr)
{
    int r;
    foreach (e; arr)
        r += e;
    arr[] = r;
    return arr;
}
