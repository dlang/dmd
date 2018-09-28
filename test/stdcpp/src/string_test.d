module test.stdcpp.string;

import core.stdcpp.string;

alias std_string = basic_string!char;
alias std_wstring = basic_string!wchar;

unittest
{
    version(Windows)
    {
        std_string str = std_string("Hello");

        assert(str.size == 5);
        assert(str.length == 5);
        assert(str.empty == false);

        assert(sumOfElements_val(str) == 1500);
        assert(sumOfElements_ref(str) == 500);

        std_string str2 = std_string(Default);
        assert(str2.size == 0);
        assert(str2.length == 0);
        assert(str2.empty == true);
        assert(str2[] == []);

        // test local instantiations...
        // there's no basic_string<char16_t> instantiation in C++
        std_wstring str3 = std_wstring("Hello"w);

        assert(str3.size == 5);
        assert(str3.length == 5);
        assert(str3.empty == false);
    }
    else
    {
        pragma(msg, "std.string implementation not yet done for linux - gcc/clang");
    }
}


extern(C++):

// test the ABI for calls to C++
int sumOfElements_val(std_string);
int sumOfElements_ref(ref const(std_string));

// test the ABI for calls from C++
int fromC_val(std_string str)
{
    assert(str[] == "Hello");
    assert(str.front == 'H');
    assert(str.back == 'o');
    assert(str.at(2) == 'l');

//    str.fill(2);

    int r;
    foreach (e; str[])
        r += e;

    assert(r == 500);
    return r;
}

int fromC_ref(ref const(std_string) str)
{
    int r;
    foreach (e; str[])
        r += e;
    return r;
}
