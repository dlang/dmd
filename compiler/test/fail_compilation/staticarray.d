/*
TEST_OUTPUT:
---
fail_compilation/staticarray.d(27): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(28): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(29): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(30): Error: cannot infer static array length from `$` in this type position; only direct static array declarations can infer `$` from an initializer
fail_compilation/staticarray.d(31): Error: cannot infer static array length from `$` in this type position; only direct static array declarations can infer `$` from an initializer
fail_compilation/staticarray.d(32): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(36): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(34): Error: struct `staticarray.ForwardRef1` circular or forward reference
fail_compilation/staticarray.d(45): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(43): Error: struct `staticarray.ForwardRef3` circular or forward reference
fail_compilation/staticarray.d(50): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(48): Error: struct `staticarray.ForwardRef4` circular or forward reference
fail_compilation/staticarray.d(57): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(54): Error: struct `staticarray.ForwardRef5` circular or forward reference
fail_compilation/staticarray.d(62): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(60): Error: struct `staticarray.ForwardRef6` circular or forward reference
fail_compilation/staticarray.d(67): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(65): Error: struct `staticarray.ForwardRef7` circular or forward reference
fail_compilation/staticarray.d(73): Error: struct `staticarray.ForwardRef8` cannot have field `arr` with static array of same struct type
fail_compilation/staticarray.d(40): Error: variable `staticarray.ForwardRef2.arr` recursive initialization of field
---
*/

int[$] arr1;
int[$] arr2 = void;
int[$][1] arr3 = 1;
int[$]* arr4 = [1, 2];
auto[$]* arr5 = [1, 2];
auto[$] arr6;

struct ForwardRef1
{
    ForwardRef1[$] arr = new ForwardRef1();
}
struct ForwardRef2
{
    ForwardRef2*[$] arr = [new ForwardRef2()];
}

struct ForwardRef3
{
    ForwardRef3[$] arr = ForwardRef3.init;
}

struct ForwardRef4
{
    ForwardRef4[$] arr = make();
    static ForwardRef4 make() { return ForwardRef4.init; }
}

struct ForwardRef5
{
    enum bool flag = true;
    ForwardRef5[$] arr = flag ? ForwardRef5.init : ForwardRef5.init;
}

struct ForwardRef6
{
    ForwardRef6[$] arr = (0, ForwardRef6.init);
}

struct ForwardRef7
{
    ForwardRef7[$] arr = make();
    static ForwardRef7[] make() { return [ForwardRef7.init]; }
}

struct ForwardRef8
{
    ForwardRef8[$][$] arr = [[ForwardRef8.init]];
}
