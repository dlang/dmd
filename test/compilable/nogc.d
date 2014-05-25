// REQUIRED_ARGS: -o-

/***************** Covariance ******************/

class C1
{
    void foo() @nogc;
    void bar();
}

class D1 : C1
{
    override void foo();        // no error
    override void bar() @nogc;  // no error
}

/******************************************/
// 12630

void test12630() @nogc
{
    // All of these declarations should cause no errors.

    static const ex1 = new Exception("invalid");
  //enum         ex2 = new Exception("invalid");

    static const arr1 = [[1,2], [3, 4]];
    enum         arr2 = [[1,2], [3, 4]];

    static const aa1 = [1:1, 2:2];
    enum         aa2 = [1:1, 2:2];

    static const v1 = aa1[1];
    enum         v2 = aa2[1];

    Object o;
    static const del1 = (delete o).sizeof;
    enum         del2 = (delete o).sizeof;

    int[] a;
    static const len1 = (a.length = 1).sizeof;
    enum         len2 = (a.length = 1).sizeof;

    static const cata1 = (a ~= 1).sizeof;
    enum         cata2 = (a ~= 1).sizeof;

    static const cat1 = (a ~ a).sizeof;
    enum         cat2 = (a ~ a).sizeof;
}

