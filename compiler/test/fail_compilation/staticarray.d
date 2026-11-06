/*
TEST_OUTPUT:
---
fail_compilation\staticarray.d(35): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(36): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(37): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(38): Error: cannot infer static array length from `$` in this type position; only direct static array declarations can infer `$` from an initializer
fail_compilation\staticarray.d(39): Error: cannot infer static array length from `$` in this type position; only direct static array declarations can infer `$` from an initializer
fail_compilation\staticarray.d(40): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(44): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(42): Error: struct `staticarray.ForwardRef1` circular or forward reference
fail_compilation\staticarray.d(48): Error: struct `staticarray.ForwardRef2` no size because of forward reference
fail_compilation\staticarray.d(48): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(53): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(51): Error: struct `staticarray.ForwardRef3` circular or forward reference
fail_compilation\staticarray.d(58): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(56): Error: struct `staticarray.ForwardRef4` circular or forward reference
fail_compilation\staticarray.d(65): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(62): Error: struct `staticarray.ForwardRef5` circular or forward reference
fail_compilation\staticarray.d(70): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(68): Error: struct `staticarray.ForwardRef6` circular or forward reference
fail_compilation\staticarray.d(75): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(73): Error: struct `staticarray.ForwardRef7` circular or forward reference
fail_compilation\staticarray.d(81): Error: struct `staticarray.ForwardRef8` no size because of forward reference
fail_compilation\staticarray.d(81): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation\staticarray.d(84): Error: array index 3 initialized twice
fail_compilation\staticarray.d(84): Error: cannot infer static array element type for `auto[$]`, provide an array initializer
fail_compilation\staticarray.d(85): Error: array index 4294901760 not supported
fail_compilation\staticarray.d(85): Error: cannot infer static array element type for `auto[$]`, provide an array initializer
fail_compilation\staticarray.d(86): Error: array initializer has 4 elements, but array length is 3
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

auto[$] arr7 = [ 0, 3:3, 2:2, 4 ];
auto[$] arr8 = [ 0, 3:3, 0xffff_0000:99 ];
int[3] arr9 = [ 0, 3:3 ];
