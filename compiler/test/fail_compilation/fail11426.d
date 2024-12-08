/*
TEST_OUTPUT:
---
fail_compilation/fail11426.d(23): Error: cannot implicitly convert expression `udarr` of type `uint[]` to `int[]`
    int[1] arr1; arr1 = udarr;  // Error, OK
                        ^
fail_compilation/fail11426.d(24): Error: cannot implicitly convert expression `usarr` of type `uint[1]` to `int[]`
    int[1] arr2; arr2 = usarr;  // Error, OK
                        ^
fail_compilation/fail11426.d(26): Error: cannot implicitly convert expression `udarr` of type `uint[]` to `int[]`
    int[1] arr3 = udarr;    // accepted, BAD!
                  ^
fail_compilation/fail11426.d(27): Error: cannot implicitly convert expression `usarr` of type `uint[1]` to `int[]`
    int[1] arr4 = usarr;    // accepted, BAD!
                  ^
---
*/
void main()
{
    uint[]  udarr;
    uint[1] usarr;

    int[1] arr1; arr1 = udarr;  // Error, OK
    int[1] arr2; arr2 = usarr;  // Error, OK

    int[1] arr3 = udarr;    // accepted, BAD!
    int[1] arr4 = usarr;    // accepted, BAD!
}
