struct V3 {
        int x;
        int y;
        int z;
        int w = 30;
}

int fn(V3 v3) {
        return v3.y;
}
int fn2(V3 v3) {
        auto x = V3();
        return x.w + v3.w;

}

static assert(fn(V3(1,20,3)) == 20);
static assert(fn2(V3()) == 60);

bool testCmpAssignment()
{
  uint v = 4;
  bool result = v == 4;
  return result;
}

static assert(testCmpAssignment);

int fun(string s1, string s2, string s3) {
        return cast(int)s2[2];
}
static assert( fun("_funny_","funny_","funny") ==  'n');


bool fn(string s1, string s2)
{
    return s1 == s2;
}

static assert(!fn("LLVM","HHVM"));
static assert(fn("LLVM","LLVM"));


int func(char _c) {
        foreach(_;0 .. 16) {}
//      char _c = s[1];
        int acc;
        switch(_c) {
        //      a = 22 + 44; // unreachable code;
                case 'a' : return 5;
                default : return acc; break;
                case 'd' : goto case 'b';
                case 'b' : return 2; /*+ func(s[1 .. $]);*/
                case 'c' : {
                acc--;{acc++;}{
                        acc++;
                        { goto default; }
                }}
                case 'f' : {
                        goto case 'b';
                }
                case 'e' : break;

        }

return 16;

}
static assert(func('c') == 1);
static assert(func('f') == 2);
static assert(func('e') == 16);

static assert((int _){int a = 1; int b = a++; return a + b;}(1) == 3);
static assert((int b){int a = b; if(a==2) a++; b += a++; return a + b;}(4) == 13);
static assert((int b){int a = b; if(a==2) a++; b += a++; return a + b;}(2) == 9);

static assert((int a){int a4 = a*4; int result; while(a4--) { result++; } return result;}(4) == 16);


uint Sum3Arrays (int[] a1, uint[] a2, uint[] a3)
{
  uint result;
  for(int i; i != cast(int) a1.length; i++)
  {
    result += a1[i];
  }
  for(int i; i < cast(int) a2.length; i++)
  {
    result += a2[i];
  }
  for(int i; i != cast(int) a3.length; i++)
  {
    result += a3[i];
  }

  return result;
}

static assert(Sum3Arrays([2,3],[],[]) == 5);
static assert(Sum3Arrays([2],[],[3]) == 5);
static assert(Sum3Arrays([3],[1],[1]) == 5);

uint ArrayLength(uint[] a)
{
  return cast(uint)a.length;
}

static assert(ArrayLength([1,2,3,4]) == 4);
static assert(ArrayLength(['H','e','l','l','o']) == 5);

uint SecondElement(uint[] a)
{
    return a[1];
}

static assert(SecondElement([1,2,3,4]) == 2);
static assert(SecondElement(['H','e','l','l','o']) == 'e');

uint AddLenghts(uint[] a, uint[] b)
{
    return cast(uint)(a.length + b.length);
}

static assert(AddLenghts([1,2,3,4,5,6,7,8,9,10],[1,2]) == 12);

struct S 
{
 uint u1;
 uint u2;
}

S makeTenTen()
{
  return S(10, 10);
}

S makeS(uint a, uint b)
{
  return S(a, b);
}

uint getu2(S s)
{
  return s.u2;
}

static assert(getu2(S(10, 14)) == 14);
static assert(makeTenTen() == makeS(10, 10));

uint[] itrspary(uint n)
{
  return [1, n, 3];
}

static assert(itrspary(7).length == 3);
static assert(itrspary(7)[0] == 1);
static assert(itrspary(7)[1] == 7);
static assert(itrspary(7)[2] == 3);

int computeFib(int n)
{
    int t = 1;
    int result = 0;

    while(n--)
    {
        result = t - result;
        t = t + result;
    }

   return result;
}

static assert(computeFib(12) == 144);

uint testLabeledContinue()
{
    uint result;
    L: foreach (i; 0 .. 24)
    {
        if (i != 4)
            continue L;
        result += i;
    }
    return result;
}

static assert(testLabeledContinue() == 4);

uint[] arrayLiteralReturn()
{
  return [1,2,3];
}
enum alr = arrayLiteralReturn();
static assert(alr == [1,2,3]);

uint staticArrayLiteralAssign()
{
  uint[10] arr = [1,2,3,4,5,6,7,8,9,10];
  return arr[7];
}

static assert(staticArrayLiteralAssign() == 8);


uint* testBasicPtrReturn(uint v)
{
    return new uint(v + 6);
}


static assert(*testBasicPtrReturn(5) == 11);

uint echo (uint val)
{
    return val;
}

const(uint) fastLog10(const uint val) pure nothrow @nogc {
    return      (val < 10) ? 0 :
                (val < 100) ? 1 :
                (val < 1000) ? 2 :
                (val < 10000) ? 3 :
                (val < 100000) ? 4 :
                (val < 1000000) ? 5 :
                (val < 10000000) ? 6 :
                (val < 100000000) ? 7 :
                (val < 1000000000) ? 8 : 9;
}

/*@unique*/ static immutable uint[10] fastPow10tbl = [
        1,
        10,
        100,
        1000,
        10000,
        100000,
        1000000,
        10000000,
        100000000,
        1000000000,
] ;

static assert(fastLog10(fastPow10tbl[2]) == 2);
static assert(fastLog10(fastPow10tbl[3]) == 3);
static assert(fastLog10(1000) == 3);

static assert(echo(fastPow10tbl[1]) == 10);

version(linux)
{
import core.time;
import core.sys.linux.time;

auto _posixClock(ClockType clockType)
    {
            with(ClockType) final switch(clockType)
            {
            case bootTime: return CLOCK_BOOTTIME;
            case coarse: return CLOCK_MONOTONIC_COARSE;
            case normal: return CLOCK_MONOTONIC;
            case precise: return CLOCK_MONOTONIC;
            case processCPUTime: return CLOCK_PROCESS_CPUTIME_ID;
            case raw: return CLOCK_MONOTONIC_RAW;
            case threadCPUTime: return CLOCK_THREAD_CPUTIME_ID;
            case second: assert(0);
            }
}

static assert(_posixClock(ClockType.bootTime) == CLOCK_BOOTTIME);
}
uint rfn(uint n)
{
  if (n > 2) return n + rfn(n-1) + rfn(n-2);
  return 1;
}

static assert(rfn(26) == 681961);

uint caller(uint n)
 {
   return callee(n, 2);
 }

 uint callee(uint a, uint b)
 {
   return a*b;
 }

 static assert(caller(3) == 6);
 static assert(caller(24) == 48);

uint testPtrArg()
{
  uint x = 7;
  testPtrParam(&x);
  return x;
}

void testPtrParam(uint* x)
{
    *x = 12;
    return ; // actually needed right now
}

static assert(testPtrArg() == 12);


struct iota_range
{
  int current;
  int end;
  int step;

  uint front()
  {
     return current;
  }

  void popFront()
  {
    current += step;
    return ;
  }

  bool empty()
  {
    return current > end;
  }

  this(uint end) pure
  {
    this(end, 0, 1);
  }

  this(uint end, uint begin) pure
  {
    this(end, begin, 1);
  }

  this(uint end, uint begin, uint step) pure
  {
    assert(step != 0, "cannot have a step of 0");
    this.step = step;
    this.current = begin;
    this.end = end;
  }

}

auto Iota(int end)
{
  return iota_range(end);
}

uint testThisCall(uint end)
{
  uint result;

  foreach(n;Iota(end))
  {
    result += n;
  }

  return result;
}


static assert(testThisCall(12) == 78);

/// test order of evaluation
uint[4] tooe()
{
  uint[4] array = [1,2,3,4];
  uint i = 1;
  array[i++] = array[i++] + i; // should be array[1] = array[2] + 3;
  return array;
}

enum tooeArray = tooe();
static assert(tooeArray == [1,6,3,4]);

uint testSwitchNestedWhile(uint a)
{
    final switch(a)
    {
        case 1 : {

            while(a < 20)
            {
                a++;
                if (a == 17) break;
            }
                return a;
        }
        case 2 : return 12;
    }

    return 1;
}
static assert(testSwitchNestedWhile(1) == 17);
static assert(testSwitchNestedWhile(2) == 12);

int[] testFnPtr_filterBy(int[] arr , bool function(int) fn)
{
    int[] result;
    uint resultLength;

    result.length = arr.length;
    foreach(i;0 .. arr.length)
    {
        auto e = arr[i];
        bool r = true;
        r = fn(e);
        if(r)
        {
            result[resultLength++] = e;
        }
    }

   int[] filterResult;
   filterResult.length = resultLength;

   foreach(i; 0 .. resultLength)
   {
     filterResult[i] = result[i];
   }

  return filterResult;
}


bool isDiv2(int e)
{
  bool result_;
  result_ = (e % 2 == 0);
  return result_;
}

bool isNotDiv2(int e)
{
  bool result_;
  result_ = (e % 2 != 0);
  return result_;
}

int[] testFnPtr_run(int[] arr, bool div2)
{
  return testFnPtr_filterBy(arr, div2 ? &isDiv2 : &isNotDiv2);
}


static assert(testFnPtr_run([3,4,5], true) == [4]);
static assert(testFnPtr_run([3,4,5], false) == [3,5]);

uint testRefCall(uint[] arr)
{
        uint sum;
        foreach(uint i;0 .. cast(uint)arr.length)
        {    
                addToSum(sum, arr[i]);
        }  
        return sum; 
} 

void addToSum(ref uint sum, uint element)
{
        sum = sum + element; // works now as well
        return ; 
}

static assert([1,2,3,4,5].testRefCall == 15);

static immutable uint[] OneToTen = [1,2,3,4,5,6,7,8,9,10];

const(uint[]) SliceOf1to10(uint lwr, uint upr) {
    return OneToTen[lwr .. upr];
}

static assert(SliceOf1to10(2,8) == [3u, 4u, 5u, 6u, 7u, 8u]);

string slice(string s, uint lwr, uint upr)
{
    return s[lwr .. upr];
}

static assert(slice("Hello World", 6, 11) == "World");

uint sum(string s)
{
    uint sum;
    foreach(i, char c; s)
    {
        sum += c;
    }
    return sum;
}

static assert(sum("newCTFE") == 620);

const(uint)[] testConcat()
{
    return SliceOf1to10(0,4) ~ SliceOf1to10(7,9);
}

static immutable testConcatResult = testConcat();

static assert(testConcatResult == [1,2,3,4,8,9]);

string strcat(string s1, string s2)
{
    return s1 ~ s2;
}

static assert(strcat("hello","world") == "helloworld");
static assert(strcat(null, null) is null);

uint[3] testCommaExp(uint a)
{
  uint b = 1;

  uint r = (a++, a++, b++);
  return [a, r, b];
}

static assert(testCommaExp(2) == [4, 1, 2]);

struct R
{
  int[] s1;
  int[] s2;
}


R returnSlices(int[] s1, int[] s2)
{
    return R(s1[], s2[]);
}
static assert(returnSlices([1,2,3], [4,5,6,7]) == R([1,2,3], [4,5,6,7]));


R returnSlicedSlices(int[] s1, int[] s2)
{
    return R(s1[], s2[1 .. $-1]);
}
static assert(returnSlicedSlices([1,2,3], [4,5,6,7]) == R([1,2,3],[5,6]));

uint[] assignSlice(uint from, uint to, uint[] stuff)
{
    uint[] slice;
    slice.length = to + 4;
    foreach (uint i; 0 .. to + 4)
    {
        slice[i] = i + 1;
    }

    slice[from .. to] = stuff[];
    return slice;
}
static immutable as = assignSlice(1, 4, [9, 8, 7]);

static assert(as == [1, 9, 8, 7, 5, 6, 7, 8]);


float fmaddf(float a, float b, float c)
{
    float result;
    result = b + a * c;
    return result;
}

static assert(fmaddf(0x1.acccccp+2f, 0x1.166666p+3f, 0x1.4cccccp+0f) == 0x1.168f5cp+4f);
static assert(fmaddf(0x1.acccccp+2f, 0x1.166666p+3f, -0x1.4cccccp+0f) == -0x1.47a8p-7f);

struct SMinMax {
    long l;
    ulong u;
    long v;
}

SMinMax makeSMin()
{
  SMinMax s;
  s.l = long.min;
  s.u = ulong.min;
  return s;
}

SMinMax makeSMax()
{
  SMinMax s;
  s.l = long.max;
  s.u = ulong.max;
  return s;
}

static assert(makeSMax.u == ulong.max);
static assert(makeSMax.l == long.max);

static assert(makeSMin.u == ulong.min);
static assert(makeSMin.l == long.min);

static assert(() { return ulong(ushort.max | ulong(ushort.max) << 32); }() == 281470681808895LU);


int[] fold (int[4][3] a)
{
  int[] result;
  result.length = 4 * 3;
  int pos;
  foreach (i; 0 .. 3)
  {
    foreach (j; 0 .. 4)
    {
      result[pos++] = a[i][j];
    }
  }
  return result;
}

static assert (fold ([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]]) ==
              [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);


struct NA
{
    string name;
    uint age;
}

NA[] make5(string name)
{
    NA[] result;

    foreach(i; 1 .. 6)
    {
        string nameN = name ~ [cast(immutable char)('0' + (i % 10))];
        result ~= [NA(nameN , i-1)];
    }
    return result;
}

static assert (make5("Tony") == [NA("Tony1", 0u), NA("Tony2", 1u), NA("Tony3", 2u), NA("Tony4", 3u), NA("Tony5", 4u)]);


static assert(!__traits(newCTFEGaveUp));
