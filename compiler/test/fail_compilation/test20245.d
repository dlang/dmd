/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test20245.d(41): Error: reference to local variable `x` assigned to non-scope parameter `ptr` calling `escape`
    escape(&x);
           ^
fail_compilation/test20245.d(42): Error: copying `&x` into allocated memory escapes a reference to parameter `x`
    auto b = [&x];
              ^
fail_compilation/test20245.d(43): Error: scope variable `a` may not be returned
    return a;
           ^
fail_compilation/test20245.d(47): Error: cannot take address of `scope` variable `x` since `scope` applies to first indirection only
    int** a = &x;
          ^
fail_compilation/test20245.d(53): Error: reference to local variable `x` assigned to non-scope parameter `ptr` calling `escape`
    escape(&x);
           ^
fail_compilation/test20245.d(54): Error: copying `&x` into allocated memory escapes a reference to parameter `x`
    auto b = [&x];
              ^
fail_compilation/test20245.d(70): Error: reference to local variable `price` assigned to non-scope `this.minPrice`
        minPrice = &price; // Should not compile.
                 ^
fail_compilation/test20245.d(89): Error: reference to local variable `this.content[]` calling non-scope member function `Exception.this()`
        throw new Exception(content[]);
                                   ^
fail_compilation/test20245.d(109): Error: reference to local variable `this` assigned to non-scope parameter `content` calling `listUp`
        listUp(&content);
               ^
fail_compilation/test20245.d(102):        which is not `scope` because of `charPtr = content`
auto listUp(const(char)* content) {charPtr = content;}
                                           ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=20245
@safe int* foo(ref int x) {
    int* a = &x;
    escape(&x);
    auto b = [&x];
    return a;
}

@safe int** foo(ref scope int* x) {
    int** a = &x;
    return a;
}

@safe int* foo(return ref int x) {
    int* a = &x;
    escape(&x);
    auto b = [&x];
    return a;
}

int* gPtr;
@safe void escape(int* ptr)
{
    gPtr = ptr;
}

// https://issues.dlang.org/show_bug.cgi?id=21212
class MinPointerRecorder
{
    int* minPrice;
    void update(ref int price) @safe
    {
        minPrice = &price; // Should not compile.
    }
}

void main() @safe
{
    auto r = new MinPointerRecorder;
    () { int mp = 42; r.update(mp); } ();
    () { ulong[1000] stomp = 13; } ();
    auto x = *r.minPrice; // "13"
}

// https://issues.dlang.org/show_bug.cgi?id=22782
struct DontDoThis
{
    immutable char[12] content;
    @safe this(char ch)
    {
        content[] = ch;
        throw new Exception(content[]);
    }
}

void main1() @safe
{
    DontDoThis('a');
}

// https://issues.dlang.org/show_bug.cgi?id=22783
const(char)* charPtr;

// argument is not, or should not be scope
auto listUp(const(char)* content) {charPtr = content;}

struct DontDoThis2
{
    char content;
    @safe escape()
    {
        listUp(&content);
    }
}
