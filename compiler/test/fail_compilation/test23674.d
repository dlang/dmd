// https://issues.dlang.org/show_bug.cgi?id=23674

/*
TEST_OUTPUT:
---
fail_compilation/test23674.d(18): Error: array index 2 is out of bounds `arr[0 .. 2]`
    assert(arr[2] == arr[3]);
           ^
fail_compilation/test23674.d(18): Error: array index 3 is out of bounds `arr[0 .. 2]`
    assert(arr[2] == arr[3]);
                     ^
---
*/

void main()
{
    string[2] arr;
    assert(arr[2] == arr[3]);
}
