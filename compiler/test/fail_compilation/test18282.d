/* REQUIRED_ARGS: -preview=dip1000
   TEST_OUTPUT:
---
fail_compilation/test18282.d(51): Error: scope variable `aa` may not be returned
    return aa[0];
             ^
fail_compilation/test18282.d(60): Error: copying `& i` into allocated memory escapes a reference to local variable `i`
    auto    dyna = [ &i ];
                     ^
fail_compilation/test18282.d(61): Error: copying `& i` into allocated memory escapes a reference to local variable `i`
    int*[ ] dynb = [ &i ];
                     ^
fail_compilation/test18282.d(62): Error: scope variable `staa` may not be returned
    return staa[0];
               ^
fail_compilation/test18282.d(70): Error: copying `S2000(& i)` into allocated memory escapes a reference to local variable `i`
    S2000[] arr = [ S2000(&i) ];
                         ^
fail_compilation/test18282.d(79): Error: copying `& i` into allocated memory escapes a reference to local variable `i`
    char*[int*] aa = [ &i : &c ];
                       ^
fail_compilation/test18282.d(79): Error: copying `& c` into allocated memory escapes a reference to local variable `c`
    char*[int*] aa = [ &i : &c ];
                            ^
fail_compilation/test18282.d(91): Error: copying `& foo` into allocated memory escapes a reference to local variable `foo`
    ls = ls ~ &foo;
              ^
fail_compilation/test18282.d(92): Error: copying `& foo` into allocated memory escapes a reference to local variable `foo`
    ls = &foo ~ ls;
         ^
fail_compilation/test18282.d(93): Error: copying `& foo` into allocated memory escapes a reference to local variable `foo`
    ls ~= &foo;
          ^
fail_compilation/test18282.d(100): Error: copying `&this` into allocated memory escapes a reference to parameter `this`
        arr ~= &this;
               ^
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


void bar3()
{
    int i;
    char c;
    char*[int*] aa = [ &i : &c ];
}


// Line 1000 starts here

// https://issues.dlang.org/show_bug.cgi?id=18282

void test18282() @safe
{
    string foo = "foo";
    scope string*[] ls;
    ls = ls ~ &foo;
    ls = &foo ~ ls;
    ls ~= &foo;
}

struct S
{
    auto fun()
    {
        arr ~= &this;
    }

    S*[] arr;
}
