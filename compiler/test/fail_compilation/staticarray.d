/*
TEST_OUTPUT:
---
fail_compilation/staticarray.d(11): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(12): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(13): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(16): Error: variable `staticarray.ForwardRef.arr` recursive initialization of field
---
*/

int[$] arr1;
int[$] arr2 = void;
int[$][1] arr3 = 1;
struct ForwardRef
{
    ForwardRef*[$] arr = [new ForwardRef()];
}
