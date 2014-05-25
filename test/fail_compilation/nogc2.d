// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

/***************** CatExp *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc2.d(24): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(25): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(26): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(28): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(29): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(30): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(31): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(32): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(34): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(35): Error: cannot use operator ~ in @nogc function testCat
fail_compilation/nogc2.d(36): Error: cannot use operator ~ in @nogc function testCat
---
*/
@nogc void testCat(int[] a, string s)
{
    int[] a1 = a ~ a;
    int[] a2 = a ~ 1;
    int[] a3 = 1 ~ a;

    string s1 = s ~ s;
    string s2 = s ~ "a";
    string s3 = "a" ~ s;
    string s4 = s ~ 'c';
    string s5 = 'c' ~ s;

    string s6 = "a" ~ "b";      // should not be error
    string s7 = "a" ~ 'c';      // should not be error
    string s8 = 'c' ~ "b";      // should not be error
}

/***************** CatAssignExp *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc2.d(51): Error: cannot use operator ~= in @nogc function testCatAssign
fail_compilation/nogc2.d(53): Error: cannot use operator ~= in @nogc function testCatAssign
fail_compilation/nogc2.d(54): Error: cannot use operator ~= in @nogc function testCatAssign
---
*/
@nogc void testCatAssign(int[] a, string s)
{
    a ~= 1;

    s ~= "a";
    s ~= 'c';
}

/***************** ArrayLiteralExp *******************/

@nogc int* barA();

/*
TEST_OUTPUT:
---
fail_compilation/nogc2.d(73): Error: array literals in @nogc function testArray may cause GC allocation
---
*/

@nogc void testArray()
{
    enum arrLiteral = [null, null];

    int* p;
    auto a = [p, p, barA()];
    a = arrLiteral; // should be error
}

/***************** AssocArrayLiteralExp *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc2.d(90): Error: associative array literal in @nogc function testAssocArray may cause GC allocation
---
*/

@nogc void testAssocArray()
{
    enum aaLiteral = [10: 100];

    auto aa = [1:1, 2:3, 4:5];
    aa = aaLiteral; // should be error
}

/***************** IndexExp *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc2.d(105): Error: indexing an associative array in @nogc function testIndex may cause gc allocation
fail_compilation/nogc2.d(106): Error: indexing an associative array in @nogc function testIndex may cause gc allocation
---
*/
@nogc void testIndex(int[int] aa)
{
    aa[1] = 0;
    int n = aa[1];
}
