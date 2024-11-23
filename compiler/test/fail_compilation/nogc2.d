// REQUIRED_ARGS: -o-

/***************** CatExp *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc2.d(60): Error: cannot use operator `~` in `@nogc` function `nogc2.testCat`
    int[] a1 = a ~ a;
               ^
fail_compilation/nogc2.d(61): Error: cannot use operator `~` in `@nogc` function `nogc2.testCat`
    int[] a2 = a ~ 1;
               ^
fail_compilation/nogc2.d(62): Error: cannot use operator `~` in `@nogc` function `nogc2.testCat`
    int[] a3 = 1 ~ a;
               ^
fail_compilation/nogc2.d(64): Error: cannot use operator `~` in `@nogc` function `nogc2.testCat`
    string s1 = s ~ s;
                ^
fail_compilation/nogc2.d(65): Error: cannot use operator `~` in `@nogc` function `nogc2.testCat`
    string s2 = s ~ "a";
                ^
fail_compilation/nogc2.d(66): Error: cannot use operator `~` in `@nogc` function `nogc2.testCat`
    string s3 = "a" ~ s;
                ^
fail_compilation/nogc2.d(67): Error: cannot use operator `~` in `@nogc` function `nogc2.testCat`
    string s4 = s ~ 'c';
                ^
fail_compilation/nogc2.d(68): Error: cannot use operator `~` in `@nogc` function `nogc2.testCat`
    string s5 = 'c' ~ s;
                ^
fail_compilation/nogc2.d(79): Error: cannot use operator `~=` in `@nogc` function `nogc2.testCatAssign`
    a ~= 1;
      ^
fail_compilation/nogc2.d(81): Error: cannot use operator `~=` in `@nogc` function `nogc2.testCatAssign`
    s ~= "a";
      ^
fail_compilation/nogc2.d(82): Error: cannot use operator `~=` in `@nogc` function `nogc2.testCatAssign`
    s ~= 'c';
      ^
fail_compilation/nogc2.d(94): Error: array literal in `@nogc` function `nogc2.testArray` may cause a GC allocation
    auto a = [p, p, barA()];
             ^
fail_compilation/nogc2.d(95): Error: array literal in `@nogc` function `nogc2.testArray` may cause a GC allocation
    a = arrLiteral;
        ^
fail_compilation/nogc2.d(104): Error: associative array literal in `@nogc` function `nogc2.testAssocArray` may cause a GC allocation
    auto aa = [1:1, 2:3, 4:5];
              ^
fail_compilation/nogc2.d(105): Error: associative array literal in `@nogc` function `nogc2.testAssocArray` may cause a GC allocation
    aa = aaLiteral;
         ^
fail_compilation/nogc2.d(112): Error: assigning an associative array element in `@nogc` function `nogc2.testIndex` may cause a GC allocation
    aa[1] = 0;
      ^
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

    string s6 = "a" ~ "b";      // no error
    string s7 = "a" ~ 'c';      // no error
    string s8 = 'c' ~ "b";      // no error
}

/***************** CatAssignExp *******************/

@nogc void testCatAssign(int[] a, string s)
{
    a ~= 1;

    s ~= "a";
    s ~= 'c';
}

/***************** ArrayLiteralExp *******************/

@nogc int* barA();

@nogc void testArray()
{
    enum arrLiteral = [null, null];

    int* p;
    auto a = [p, p, barA()];
    a = arrLiteral;
}

/***************** AssocArrayLiteralExp *******************/

@nogc void testAssocArray()
{
    enum aaLiteral = [10: 100];

    auto aa = [1:1, 2:3, 4:5];
    aa = aaLiteral;
}

/***************** IndexExp *******************/

@nogc void testIndex(int[int] aa)
{
    aa[1] = 0;
    int n = aa[1];
}
