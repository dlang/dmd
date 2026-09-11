// test cases of https://github.com/dlang/dmd/issues/17555

enum all = true; // false to enable __VERSION__ checks

auto tuple(T...)(T t) { return t[0]; }  //replace import std.typecons;

string[string][]       Dict;    //sure ok.
alias string[string][] dict;    //Error

void main()
{
    main1();
    main2();
    main3();
    main4();
    main5();
    main6();
    main7();
    testBugs();
    testInference();
    testInitializer1();
    testInitializer2();
}

void main1()
{
    Dict                   = [["Cow":"moo" ],["Duck":"quack"]];//cool
    Dict                  ~=  ["Dog":"woof"];                  //No prob.

    static if(all || __VERSION__ < 2112)
    assert(Dict==[["Cow":"moo"],["Duck":"quack"],["Dog":"woof"]]);//looks legit
    dict temp              = [["Cow":"moo" ],["Duck":"quack"]];//Error
    string[string][] temp2 = [["Cow":"moo" ],["Duck":"quack"]];//Error

    //And My favorite one of all:
    auto temp3 = [["Cow":"moo"],["Duck":"quack"]];  //Error
    auto temp4 = tuple([["Cow":"moo"]]);//works. Variant as well.
}

string[string][] aa1; // OK
alias string[string][] AA;

void main2() {
    aa1 = [["A": "B" ], ["C": "D"]];                     // OK
    aa1 ~= ["E": "F"];                                   // OK
    static if(all || __VERSION__ < 2112)
        assert(aa1 == [["A": "B"], ["C": "D"], ["E": "F"]]); // OK
    auto a2 = tuple([["A": "B"]]);                       // OK
    AA a3 = [["A": "B" ], ["C": "D"]];                   // error
    string[string][] a4 = [["A": "B" ], ["C": "D"]];     // error
    auto a5 = [["A": "B"], ["C": "D"]];                  // error
}

void main3() {
    static if(all || __VERSION__ > 2111)
        int[char][char] foo1 = ['A': ['B': 1]]; //rejects-valid
    int[char][char] foo2 = cast()['A': ['B': 1]]; //workaround
}

void main4()
{
    { // normal array literal
        int[] a = [1, 2, 3];
        int[3] b = [1, 2, 3];
        static assert(!is(typeof({ int[int] c = [1, 2, 3]; }))); // need key for each element
        auto d = [1, 2, 3];
        static assert(is(typeof(d) == int[])); // default is dynamic array
    }
    { // some keys, no gaps
        int[] a = [1 : 2, 3, 0 : 1];
        int[3] b = [1 : 2, 3, 0 : 1];
        static assert(!is(typeof({ int[int] c = [1 : 2, 3, 0 : 1]; }))); // need key for each element
    static if(all || __VERSION__ > 2113)
    {
        auto d = [1 : 2, 3, 0 : 1];
        static assert(is(typeof(d) == int[])); // default to array when not enough keys
    }
    }
    { // all keys, no gaps
        int[] a = [1 : 2, 2 : 3, 0 : 1];
        int[3] b = [1 : 2, 2 : 3, 0 : 1];
        int[int] c = [1 : 2, 2 : 3, 0 : 1];
        auto d = [1 : 2, 2 : 3, 0 : 1];
        static assert(is(typeof(d) == int[int])); // default to AA when has all keys
    }
    { // some keys, gap
        int[] a = [1 : 2, 3];
        int[3] b = [1 : 2, 3];
        // auto c = [1 : 2, 3];
        // static assert(is(typeof(c) == int[])); // should fill in gaps with int.init
    }
    { // value is AA
    static if(all || __VERSION__ > 2112)
        int[int][int] a = [0 : [0 : 3]];
    static if(all || __VERSION__ > 2113)
        int[][int] b = [0 : [0 : 3]];
    static if(all || __VERSION__ < 2112 || __VERSION__ > 2113)
        int[1][int] c = [0 : [0 : 3]];
    static if(all || __VERSION__ > 2112)
        int[int][] d = [0 : [0 : 3]];
    static if(all || __VERSION__ > 2112)
        int[int][1] e = [0 : [0 : 3]];
        auto f = [0 : [0 : 3]];
        static assert(is(typeof(f) == int[int][int])); // default to AA when has all keys
    }
    { // key is AA
        int[int[int]] a = [[0 : 0] : 0];
        // int[int[]] b = [[0 : 0] : 0];
        // int[int[1]] c = [[0 : 0] : 0];
        auto d = [[0 : 0] : 0];
        static assert(is(typeof(d) == int[int[int]]));
    }
    { // value is array
        int[][int] a = [0 : [2, 3]];
        int[][] b = [0 : [2, 3]];
        int[2][int] c = [0 : [2, 3]];
        int[2][] d = [0 : [2, 3]];
        auto e = [0 : [2, 3]];
        static assert(is(typeof(e) == int[][int]));
    }
    { // key is array
        int[int[]] a = [[2, 3] : 0];
        int[int[2]] b = [[2, 3] : 0];
        auto c = [[2, 3] : 0];
        static assert(is(typeof(c) == int[int[]]));
    }
    { // value has gap
        // int[][int] a = [0 : [1 : 2, 3]];
    static if(all || __VERSION__ < 2112 || __VERSION__ > 2113)
        int[][] b = [0 : [1 : 2, 3]];
        // int[3][int] c = [0 : [1 : 2, 3]];
    static if(all || __VERSION__ < 2112 || __VERSION__ > 2113)
        int[3][] d = [0 : [1 : 2, 3]];
        // auto e = [0 : [1 : 2, 3]];
        // static assert(is(typeof(e) == int[][int]));
    }
    { // key has gap
        // int[int[]] a = [[1 : 2, 3] : 0];
        // int[int[3]] b = [[1 : 2, 3] : 0];
        // auto c = [[1 : 2, 3] : 0];
        // static assert(is(typeof(c) == int[int[]]));
    }
}

void main5() {
    int[][int] aa1;
    aa1 = [1: [2, 3], 4: []]; // OK
    int[int][int] aa2;
    aa2 = [1: [2: 3], 4: null ]; // error
}

void testBugs()
{
    {
        int[ ] da = [1:2, 3];   // OK
        int[3] sa = [1:2, 3];   // OK
        int[int] aa = [0:3];    // OK
    }
    {
    static if(all || __VERSION__ > 2113)
        int[ ][int] daa = [0:[1:2, 3]]; // NG, but should be OK
    static if(all || __VERSION__ > 2113)
        int[3][int] saa = [0:[1:2, 3]]; // NG, but should be OK
    static if(all || __VERSION__ > 2113)
        int[int][int] aaa = [0:[0:3]];  // NG, but should be OK
    }
}

void testInitializer1()
{
    // Bare array literal
    {
        int[]    a = [1, 2, 3];
        int[3]   b = [1, 2, 3];
      static assert(!is(typeof({
        int[int] c = [1, 2, 3]; // need key for each element
      })));
    }

    // Sparse array initializer is allowed only for (s)array.
    {
        int[]    a = [1:2, 3, 0:1];
        int[3]   b = [1:2, 3, 0:1];
      static assert(!is(typeof({
        int[int] c = [1:2, 3, 0:1]; // need key for each element
      })));
    }

    // Indexed array initializer
    {
        int[]    a = [1:2, 2:3, 0:1];
        int[3]   b = [1:2, 2:3, 0:1];
        int[int] c = [1:2, 2:3, 0:1];
    }
}

void testInitializer2()
{
    // value is array (== indexed array initializer)
    {
        int[][int]  a = [0:[2, 3]];
        int[][]     b = [0:[2, 3]];
        int[2][int] c = [0:[2, 3]];
        int[2][]    d = [0:[2, 3]];
    }

    // value has gap (== sparse array initializer)
    {
    static if(all || __VERSION__ > 2113)
        int[][int]  a = [0:[1:2, 3]];
    static if(all || __VERSION__ < 2112 || __VERSION__ > 2113)
        int[][]     b = [0:[1:2, 3]];
    static if(all || __VERSION__ > 2113)
        int[3][int] c = [0:[1:2, 3]];
    static if(all || __VERSION__ < 2112 || __VERSION__ > 2113)
        int[3][]    d = [0:[1:2, 3]];
    }

    // value is AA (== indexed array initializer)
    {
    static if(all || __VERSION__ > 2113)
        int[int][int] a = [0:[0:3]];
    static if(all || __VERSION__ < 2112 || __VERSION__ > 2113)
        int[][int]    b = [0:[0:3]];
    static if(all || __VERSION__ < 2112 || __VERSION__ > 2113)
        int[1][int]   c = [0:[0:3]];
    static if(all || __VERSION__ > 2113)
        int[int][]    d = [0:[0:3]];
    static if(all || __VERSION__ > 2112)
        int[int][1]   e = [0:[0:3]];
    }

    // key is array (== array literal expression == AssignExp)
    {
        int[int[]]  a = [[2, 3]:0];
        int[int[2]] b = [[2, 3]:0];
    }

    // key is AA (currently not supported in grammar)
    {
        int[int[int]] a = [[0:0]:0];
      //int[int[]]    b = [[0:0]:0];    // [0:0] is not AssignExp
      //int[int[1]]   c = [[0:0]:0];    // [0:0] is not AssignExp
    }

    // key has gap (currently not supported in grammar)
    {
      //int[int[]]  a = [[1:2, 3]:0]; // Error: `key:value` expected for associative array literal
      //int[int[3]] b = [[1:2, 3]:0];
    }
}

void testInference()
{
    // bare array initializer to array literal
    {
        auto a = [1, 2, 3];
        static assert(is(typeof(a) == int[]));
    }

    // sparse array initializer to array literal
    // (gap is not important)
    static if(all || __VERSION__ > 2113)
    {{
      auto a = [1:2, 3, 0:1];
      static assert(is(typeof(a) == int[]));
    }}
    static if((all || __VERSION__ > 2113) && false) // crashes
    {{
      auto a2 = [1:2, 3];
      static assert(is(typeof(a2) == int[]));
    }}

    // indexed array literal to associative array literal
    {
        auto a = [1:2, 2:3, 0:1];
        static assert(is(typeof(a) == int[int]));
    }
}

void foo(int[] a) {}
void bar(int[int] aa) {}
void main6() {
    int[] a = [1:2, 3:4, 5:6];
    int[int] aa = [1:2, 3:4, 5:6];
    foo(a);
    bar(aa);
    // foo([1:2, 3:4, 5:6]); // error (not an initializer)
    bar([1:2, 3:4, 5:6]); // OK
}

void main7() {
    enum Foo { A }
    int[]     a1 = [Foo.A: 10]; // OK
    // int[] a2; a2 = [Foo.A: 10]; // Error (not an initializer)
}
