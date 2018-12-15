import core.stdcpp.string_view;

unittest
{
    string_view str = string_view("Hello");

    assert(str.size == 5);
    assert(str.length == 5);
    assert(str.empty == false);

    assert(sumOfElements_val(str) == 1500);
    assert(sumOfElements_ref(str) == 500);

    string_view str2 = string_view();
    assert(str2.size == 0);
    assert(str2.length == 0);
    assert(str2.empty == true);
    assert(str2[] == []);
}


extern(C++):

// test the ABI for calls to C++
int sumOfElements_val(string_view);
int sumOfElements_ref(ref const(string_view));

// test the ABI for calls from C++
int fromC_val(string_view str)
{
    assert(str[] == "Hello");
    assert(str.front == 'H');
    assert(str.back == 'o');
    assert(str.at(2) == 'l');

    int r;
    foreach (e; str)
        r += e;

    assert(r == 500);
    return r;
}

int fromC_ref(ref const(string_view) str)
{
    int r;
    foreach (e; str)
        r += e;
    return r;
}
