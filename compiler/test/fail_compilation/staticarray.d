/*
TEST_OUTPUT:
---
fail_compilation/staticarray.d(24): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(25): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(26): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(29): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(27): Error: struct `staticarray.ForwardRef1` circular or forward reference
fail_compilation/staticarray.d(38): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(36): Error: struct `staticarray.ForwardRef3` circular or forward reference
fail_compilation/staticarray.d(43): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(41): Error: struct `staticarray.ForwardRef4` circular or forward reference
fail_compilation/staticarray.d(50): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(47): Error: struct `staticarray.ForwardRef5` circular or forward reference
fail_compilation/staticarray.d(55): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(53): Error: struct `staticarray.ForwardRef6` circular or forward reference
fail_compilation/staticarray.d(60): Error: cannot infer static array length from `$`, provide an initializer
fail_compilation/staticarray.d(58): Error: struct `staticarray.ForwardRef7` circular or forward reference
fail_compilation/staticarray.d(66): Error: struct `staticarray.ForwardRef8` cannot have field `arr` with static array of same struct type
fail_compilation/staticarray.d(33): Error: variable `staticarray.ForwardRef2.arr` recursive initialization of field
---
*/

int[$] arr1;
int[$] arr2 = void;
int[$][1] arr3 = 1;
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
