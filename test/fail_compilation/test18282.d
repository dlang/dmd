/* REQUIRED_ARGS: -dip1000
   TEST_OUTPUT:
---
fail_compilation/test18282.d(25): Error: scope variable `aa` may not be returned
fail_compilation/test18282.d(34): Error: returning `& i` escapes a reference to local variable `i`
fail_compilation/test18282.d(35): Error: returning `& i` escapes a reference to local variable `i`
fail_compilation/test18282.d(36): Error: scope variable `staa` may not be returned
fail_compilation/test18282.d(44): Error: returning `S2000(& i)` escapes a reference to local variable `i`
fail_compilation/test18282.d(53): Error: returning `& i` escapes a reference to local variable `i`
fail_compilation/test18282.d(53): Error: returning `& c` escapes a reference to local variable `c`
---
 */

// https://issues.dlang.org/show_bug.cgi?id=18282

string* f() @safe
{
    scope string*[] ls;
    return ls[0];
}

int* g() @safe
{
    scope int*[3] aa;
    return aa[0];
}

@safe:

auto bar1()
{
    int i = void;
    int*[1] staa = [ &i ];
    auto    dyna = [ &i ];
    int*[ ] dynb = [ &i ];
    return staa[0];
}

struct S2000 { int* p; }

S2000 bar2()
{
    int i;
    S2000[] arr = [ S2000(&i) ];
    return arr[0];
}


void bar2()
{
    int i;
    char c;
    char*[int*] aa = [ &i : &c ];
}
