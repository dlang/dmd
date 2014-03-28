// REQUIRED_ARGS: -vgc
/*
TEST_OUTPUT:
---
---
*/

// Tests special cases which do not allocate and shouldn't error
// Statically typed dynamic array literals
int[4] arr = [1,2,3,4];

int testSArray()
{
    int[4] arr = [1,2,3,4];
    auto x = cast(int[4])[1,2,3,4];
    return [1, 2, 3][1];
}

enum int[] enumliteral = [1,2,3,4];

void testArrayLiteral()
{
    void helper(int[] a){}
    int[] allocate2 = [1,2,4];
    int[] e = enumliteral;
    helper([1,2,3]);
}

// String literal concatenation
immutable s1 = "test" ~ "string";
enum s2 = "test" ~ "string";

void testLiteral()
{
    string s3 = "test" ~ "string";
}

//Appending to user defined type is OK
void testAppend()
{
    struct App
    {
        ref App opOpAssign(string op)(in string s)
        {
            return this;
        }
        App opBinary(string op)(in string s) const
        {
            return this;
        }
    }

    App a;
    a ~= "test";
    auto b = a ~ "test";
}

// mixins
mixin(int.stringof ~ " mixInt;");

// CTFE
enum ctfe1 = "test".dup ~ "abcd";

/*
 * Can't test this with -nogc, as -nogc marks the delegate as @nogc (as it should):
 * ------
 * enum n = () { auto a = [1,2,3]; return a[0] + a[1] + a[2]; }();
 * ------
 * Correct test:
 * ------
 * @nogc void func()
 * {
 *     enum n = () { auto a = [1,2,3]; return a[0] + a[1] + a[2]; }();
 * }
 * ------
 */

// Reading .length is OK
void testLength()
{
    int[] arr;
    auto x = arr.length;
}

// scope prevents closure allocation
void closureHelper1(scope void delegate() d) {}
void testClosure()
{
    int a;

    void del1()
    {
        a++;
    }

    closureHelper1(&del1);
}
