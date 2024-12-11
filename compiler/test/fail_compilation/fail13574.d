/*
TEST_OUTPUT:
---
fail_compilation/fail13574.d(25): Error: cannot modify operator `$`
    foo[0 .. $ = 2]; // assigns to the temporary dollar variable
             ^
fail_compilation/fail13574.d(31): Error: cannot modify operator `$`
    auto y = arr[0 .. $ = 2]; // should also be disallowed
                      ^
---
*/

struct Foo
{
    void opSlice(size_t a, size_t b) {  }
    alias opDollar = length;
    size_t length;
}

void main()
{
    Foo foo;
    foo[0 .. foo.length = 1];
    assert(foo.length == 1);
    foo[0 .. $ = 2]; // assigns to the temporary dollar variable
    //assert(foo.length == 2);

    int[] arr = [1,2,3];
    auto x = arr[0 .. arr.length = 1];
    assert(arr.length == 1);
    auto y = arr[0 .. $ = 2]; // should also be disallowed
    //assert(arr.length == 2);
}
