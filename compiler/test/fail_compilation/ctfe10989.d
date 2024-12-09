/*
TEST_OUTPUT:
---
fail_compilation/ctfe10989.d(26): Error: uncaught CTFE exception `object.Exception("abc"c)`
    throw new Exception(['a', 'b', 'c']);
          ^
fail_compilation/ctfe10989.d(29):        called from here: `throwing()`
static assert(throwing());
                      ^
fail_compilation/ctfe10989.d(29):        while evaluating: `static assert(throwing())`
static assert(throwing());
^
fail_compilation/ctfe10989.d(40): Error: uncaught CTFE exception `object.Exception("abc"c)`
    throw new Exception(cast(string)arr);
          ^
fail_compilation/ctfe10989.d(43):        called from here: `throwing2()`
static assert(throwing2());
                       ^
fail_compilation/ctfe10989.d(43):        while evaluating: `static assert(throwing2())`
static assert(throwing2());
^
---
*/
int throwing()
{
    throw new Exception(['a', 'b', 'c']);
    return 0;
}
static assert(throwing());

int throwing2()
{
    string msg = "abc";

    char[] arr;
    arr.length = msg.length;
    arr = arr[0 .. $];
    arr[] = msg;

    throw new Exception(cast(string)arr);
    return 0;
}
static assert(throwing2());
