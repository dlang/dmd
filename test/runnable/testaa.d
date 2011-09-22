// PERMUTE_ARGS: -fPIC

/* Test associative arrays */

extern(C) int printf(const char*, ...);
extern(C) int memcmp(const void *s1, const void *s2, size_t n);

import core.memory;  // for GC.collect
import std.random;   // for uniform random numbers

/************************************************/

int nametable[char[]];

void insert(string name, int value)
{
    nametable[name] = value;
}

int retrieve(string name)
{
    return nametable[name];
}

void test1()
{   int v;

    printf("test1.a\n");
    insert("hello", 1);
    printf("test1.b\n");
    insert("world", 2);
    printf("test1.c\n");
    v = retrieve("hello");
    assert(v == 1);
    v = retrieve("world");
    assert(v == 2);
    v = retrieve("world");
    assert(v == 2);

    nametable.rehash;
    v = retrieve("world");
    assert(v == 2);
}

/************************************************/


void test2()
{
    int[string] aa;
    string[] keys;
    int[] values;

    printf("test2()\n");

    /*************/

    assert(aa == null);
    assert(aa.length == 0);

    keys = aa.keys;
    assert(keys.length == 0);

    values = aa.values;
    assert(values.length == 0);

    aa.rehash;
    assert(aa.length == 0);

    /*************/

    aa["hello"] = 3;
    assert(aa["hello"] == 3);
    aa["hello"]++;
    assert(aa["hello"] == 4);

    assert(aa.length == 1);

    keys = aa.keys;
    assert(keys.length == 1);
    assert(memcmp(keys[0].ptr, cast(char*)"hello", 5) == 0);

    values = aa.values;
    assert(values.length == 1);
    assert(values[0] == 4);

    aa.rehash;
    assert(aa.length == 1);
    assert(aa["hello"] == 4);
}

/************************************************/

void test4()
{
    int[const(ubyte)[]] b;
    const(ubyte)[] x;
    b[x] = 3;
    assert(b[x] == 3);
}

/************************************************/

void test5()
{
    int[immutable(short)[]] b;
    immutable(short)[] x;
    b[x] = 3;
    assert(b[x] == 3);
}

/************************************************/

void test6()
{
    int[const(int)[]] b;
    const(int)[] x;
    b[x] = 3;
    assert(b[x] == 3);
}

/************************************************/

void test7()
{
    int[immutable(uint)[]] b;
    immutable(uint)[] x;
    b[x] = 3;
    assert(b[x] == 3);
}

/************************************************/

void test8()
{
    int[immutable(long)[]] b;
    immutable(long)[] x;
    b[x] = 3;
    assert(b[x] == 3);
}

/************************************************/

void test9()
{
    int[immutable(ulong)[]] b;
    immutable(ulong)[] x;
    b[x] = 3;
    assert(b[x] == 3);
}

/************************************************/

class A10 {}
 
int[immutable(A10)[]] foo10;
 
void test10()
{
  auto key = new immutable(A10)[2];

  cast()(key[0]) = new A10();
  foo10[key] = 0;
  assert(key in foo10);
  assert(!(key !in foo10));
}


/************************************************/

struct Value
{
    uint x,y,z,t;
}

struct Key
{
    int a,b,c,d;

    static int hash, cmp, equals;

    size_t toHash() const
    {	hash = 1;
	return a + b + c + d;
    }

    int opCmp(ref const Key s) const
    {	cmp = 1;
	int x;

	x = a - s.a;
	if (x == 0)
	{   x = b - s.b;
	    if (x == 0)
	    {	x = c - s.c;
		if (x == 0)
		    x = d - s.d;
	    }
	}
	return x;
    }

    bool opEquals(ref const Key s) const
    {
	printf("opEquals()\n");
	equals = 1;
	return (a == s.a && b == s.b && c == s.c && d == s.d);
    }
}

void test11()
{
    Value[Key] table;

    Value* p;
    Value v;
    Value r;
    Key k;

    v.x = 7;
    v.y = 8;
    v.z = 9;
    v.t = 10;

    k.a = 1;
    k.b = 2;
    k.c = 3;
    k.d = 4;

    p = k in table;
    assert(!p);

    table[k] = v;
    p = k in table;
    assert(p);

    table.rehash;
    p = k in table;
    assert(p);

    r = table[k];
    assert(v == r);

    table.remove(k);
    assert(!(k in table));

    printf("Key.hash = %d\n", Key.hash);
    assert(Key.hash == 1);
    printf("Key.cmp = %d\n", Key.cmp);
    assert(Key.cmp == 1);
//    assert(Key.equals == 1);
}


/************************************************/

struct S12
{
    byte number;
    char[] description;
    char[] font_face;
    byte font_size;
    ushort flags;
    int colour_back;
    int colour_fore;
    byte charset;
}

void test12()
{
    S12[] x;
    printf("size %d\n",S12.sizeof);
    printf("align %d\n",S12.alignof);
    printf("offset %d\n",S12.description.offsetof);

    for (int i=0;i<3;i++) {
        S12 s;
        s.font_face="font face".dup;
        x ~= s;
    }

/* works fine
    S12 s;
    s.font_face="font face".dup;
    x ~= s;
    s.font_face="font face".dup;
    x ~= s;
    s.font_face="font face".dup;
    x ~= s;
    s.font_face="font face".dup;
    x ~= s;
*/
    GC.collect();
    printf("%.*s\n",x[0].font_face.length,x[0].font_face.ptr);
    printf("%.*s\n",x[1].font_face.length,x[1].font_face.ptr);
}


/************************************************/

void test13()
{
	int[string] array;
	array["eins"]=1;
	array["zwei"]=2;
	array["drei"]=3;

	assert(array.length==3);
	
	int[string] rehashed=array.rehash;
	assert(rehashed is array);

	string[] key = array.keys;
	assert(key.length==3);
	
	bool have[3];

	assert(!have[0]);
	assert(!have[1]);
	assert(!have[2]);

	foreach(string value; key){
		switch(value){
			case "eins":{
				have[0]=true;
				break;
			}case "zwei":{
				have[1]=true;
				break;
			}case "drei":{
				have[2]=true;
				break;
			}default:{
				assert(0);
			}
		}
	}	

	assert(have[0]);
	assert(have[1]);
	assert(have[2]);
}

/************************************************/

void test14()
{
    int[char[]] aa;

    aa["hello"] = 3;
    assert(aa["hello"] == 3);
    assert("hello" in aa);
    //delete aa["hello"];
    aa.remove("hello");
    assert(!("hello" in aa));
}

/************************************************/

class SomeClass
{
	this(char value)
	{
	    printf("class created\n");
	    _value = value;
	}

	~this()
	{
	    printf("class killed (%d)\n", _value);
	}

	char value()
	{
	    return _value;
	}

	private
	{
	    char _value;
	}
}

char[] allChars = [ 'a', 'b', 'c', 'e', 'z', 'q', 'x' ];

SomeClass[char] _chars;
	
void _realLoad()
{
    printf("Loading...\n");
    foreach(char ch; allChars)
    {
	_chars[ch] = new SomeClass(ch);
    }
}



void test15()
{
    _realLoad();
    int j;
    
    for (int i = 0; i < 10000; i++)
    {
	foreach(char ch; allChars)
	{
	    SomeClass obj = _chars[ch];
	    j += obj.value;
	}
	GC.collect();
    }
    printf("j = %d\n", j);
    assert(j == 7500000);
}


/************************************************/

void test16()
{
    int[int] aa;

    Random gen;
    for (int i = 0; i < 50000; i++)
    {
	int key = uniform(0, int.max, gen);
	int value = uniform(0, int.max, gen);

	aa[key] = value;
    }

    int[] keys = aa.keys;
    assert(keys.length == aa.length);

    int j;
    foreach (k; keys)
    {
	assert(k in aa);
	j += aa[k];
    }
    printf("test16 = %d\n", j);

    int m;
    foreach (k, v; aa)
    {
	assert(k in aa);
	assert(aa[k] == v);
	m += v;
    }
    assert(j == m);

    m = 0;
    foreach (v; aa)
    {
	m += v;
    }
    assert(j == m);

    int[] values = aa.values;
    assert(values.length == aa.length);

    foreach(k; keys)
    {
	aa.remove(k);
    }
    assert(aa.length == 0);

    for (int i = 0; i < 1000; i++)
    {
	int key2 = uniform(0, int.max, gen);
	int value2 = uniform(0, int.max, gen);

	aa[key2] = value2;
    }
    foreach(k; aa)
    {
	if (k < 1000)
	    break;
    }
    foreach(k, v; aa)
    {
	if (k < 1000)
	    break;
    }
}

/************************************************/

void dummy17()
{
}

int bb17[string];

int foo17()
{
	foreach(string s, int i; bb17)
	{
		dummy17();
	}

	bb17["a"] = 1;

	foreach(int b; bb17)
	{
		try{
			throw new Error("foo");
		}catch(Error e){
			assert(e);
			return 0;
		}catch{
			assert(0);
		}
		assert(0);
	}

	assert(0);
}

void test17()
{
    int i = foo17();
    printf("foo17 = %d\n", i);
    assert(i == 0);
}

/************************************************/

void test18() 
{
    int[uint] aa;

    aa[1236448822] = 0;
    aa[2716102924] = 1;
    aa[ 315901071] = 2;

    aa.remove(1236448822);
    printf("%d\n", aa[2716102924]);
    assert(aa[2716102924] == 1);
}


/************************************************/

void test19()
{
    immutable(char[5])[int] aa = ([3:"hello", 4:"betty"]);

    assert(aa[3] == "hello");
    assert(aa[4] == "betty");

    auto keys = aa.keys;
    printf("%d\n", keys[0]);
    printf("%d\n", keys[1]);

    auto vs = aa.values;
    printf("%.*s\n", vs[0].length, vs[0].ptr);
    printf("%.*s\n", vs[1].length, vs[1].ptr);

    string aavalue_typeid = typeid(typeof(aa.values)).toString();
    printf("%.*s\n", aavalue_typeid.length, aavalue_typeid.ptr);

    printf("%.*s\n", aa[3].length, aa[3].ptr);
    printf("%.*s\n", aa[4].length, aa[4].ptr);
}

/************************************************/

void test20()
{
    string[int] aa = ([3:"hello", 4:"betty"]);

    assert(aa[3] == "hello");
    assert(aa[4] == "betty");

    auto keys = aa.keys;
    printf("%d\n", keys[0]);
    printf("%d\n", keys[1]);

    auto values = aa.values;
    printf("%.*s\n", values[0].length, values[0].ptr);
    printf("%.*s\n", values[1].length, values[1].ptr);

    string aavalue_typeid = typeid(typeof(aa.values)).toString();
    printf("%.*s\n", aavalue_typeid.length, aavalue_typeid.ptr);

    printf("%.*s\n", aa[3].length, aa[3].ptr);
    printf("%.*s\n", aa[4].length, aa[4].ptr);
}

/************************************************/

void test21()
{
    ushort[20] key = 23;
    int[ushort[20]] aa;
    aa[key] = 42;
    auto x = aa[key];
    assert(x == 42);
    printf("foo\n");
}

/************************************************/

void test22()
{
    int[string] stopWords = [ "abc"[]:1 ];
    assert("abc"[] in stopWords);
}

/************************************************/

void test23()
{
    uint[char[]][] fractal;
    fractal.length = 10;
}

/************************************************/

void test24()
{
    int[string] x;
    char[] y;
    if (y in x)
    {
	int z = x[y];
    }
}

/************************************************/

void test25()
{
    string[string] aa;
    foreach (k,v; aa)
    {
    }
}

/************************************************/

class Tag
{
    string[string] attr;
}

void foo26(const(Tag) tag_)
{
    foreach(k,v;tag_.attr) { }
}

void test26()
{
}

/************************************************/

void test27()
{
    int[int] s;
    s = s.init;
}

/************************************************/

void test28()
{
    auto a1 = [ 1:10.0, 2:20, 3:15 ];
    auto a2 = [ 1:10.0, 2:20, 3:15 ];
    assert(a1 !is a2);
    assert(a1 == a2);
    a2[7] = 23;
    assert(a1 != a2);
    a2.remove(7);
    assert(a1 == a2);
    a1.rehash;
    assert(a1 == a2);
    a2[2] = 18;
    assert(a1 != a2);
}

/************************************************/

void test29()
{
    auto gammaFunc = [-1.5:2.363, -0.5:-3.545, 0.5:1.772];

    // write all keys
    foreach (k; gammaFunc.byKey()) {
       printf("%f\n", k); 
    }

    // write all values
    foreach (v; gammaFunc.byValue()) {
       printf("%f\n", v); 
    }
}

/************************************************/

string toString(int value)
{
    char[] result = new char[12];

    uint ndigits = 0;
    do
    {
        const c = cast(char) ((value % 10) + '0');
        value /= 10;
        ndigits++;
        result[$ - ndigits] = c;
    }
    while (value);
    return cast(string) result[$ - ndigits .. $];
}

void test30()
{
    int[string] aa;
    for(int i = 0; i < 100000; i++)
    {
        string s = toString(i);
        aa[s] = i;
    }
}

/************************************************/

void test31()
{
    int[int] test;
    test[0] = 0;
    test[1] = 1;
    test[2] = 2;

    bool flag = false;
    foreach( k, v; test){
        //printf("loop: %d %d\n", k, v);
        assert(!flag);
        flag = true;
        break;
    }
}

/************************************************/

void test32()
{
    uint[ushort] aa;
    aa[1] = 1;
    aa[2] = 2;
    aa[3] = 3;
    aa[4] = 4;
    aa[5] = 5;
    foreach(v; aa)
    {
	printf("%x\n", v);
	assert(v >= 1 && v <= 5);
    }
}

/************************************************/

template ICE3996(T : V[K], K, V) {}

struct Bug3996 {}

static assert(!is( ICE3996!(Bug3996) ));

/************************************************/

void bug4826c(T)(int[int] value, T x) {}

void test34()
{
   AssociativeArray!(int, int) z;
   bug4826c(z,1);
}

/************************************************/
// 5131

struct ICE35 {
    ICE35 opAssign(int x) { return this; }
};

void test35() {
    ICE35[string] a;
    a["ICE?"] = 1;
}

/************************************************/
// 6433

void test36() {
    int[int] aa;
    static assert(aa.sizeof != 0);
    static assert(aa.alignof != 0);
    static assert(is(typeof(aa.init) == int[int]));
    static assert(typeof(aa).mangleof == "Hii");
    static assert(typeof(aa).stringof == "int[int]");
    static struct AA { int[int] aa; }
    static assert(AA.aa.offsetof == 0);

    aa = aa.init;
    aa[0] = 1;
    assert(aa.length == 1 && aa[0] == 1);
}

/************************************************/

int main()
{
printf("before test 1\n");   test1();
printf("before test 2\n");   test2();
printf("before test 4\n");   test4();
printf("before test 5\n");   test5();
printf("before test 6\n");   test6();
printf("before test 7\n");   test7();
printf("before test 8\n");   test8();
printf("before test 9\n");   test9();
printf("before test 10\n");   test10();
printf("before test 11\n");   test11();
printf("before test 12\n");   test12();
printf("before test 13\n");   test13();
printf("before test 14\n");   test14();
printf("before test 15\n");   test15();
printf("before test 16\n");   test16();
printf("before test 17\n");   test17();
printf("before test 18\n");   test18();
printf("before test 19\n");   test19();
printf("before test 20\n");   test20();
printf("before test 21\n");   test21();
printf("before test 22\n");   test22();
printf("before test 23\n");   test23();
printf("before test 24\n");   test24();
printf("before test 25\n");   test25();
printf("before test 26\n");   test26();
printf("before test 27\n");   test27();
printf("before test 28\n");   test28();
printf("before test 29\n");   test29();
printf("before test 30\n");   test30();
printf("before test 31\n");   test31();
printf("before test 32\n");   test32();

    test34();
    test35();
    test36();

    printf("Success\n");
    return 0;
}


