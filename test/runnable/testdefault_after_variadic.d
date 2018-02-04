/*
PERMUTE_ARGS:
*/

import std.typecons : tuple;
import std.conv : text;

void fun0(U, T...)(U gold, int b_gold, T a, int b)
{
    assert(tuple(a) == gold);
    assert(b == b_gold);
}

void fun(U, T...)(U gold, T a, int b = 1)
{
    assert(tuple(a) == gold);
    assert(b == 1);
}

void fun2(U, V, T...)(U gold, V gold2, T a, string file = __FILE__, int line = __LINE__)
{
    assert(tuple(a) == gold);
    assert(tuple(file, line) == gold2);
}

// 
void fun3(int[] gold, int[] a...)
{
    assert(gold == a);
}

/+
NOTE: this is disallowed by the parser:

void fun4(int[] gold, int[] a ..., int b = 1)
{
    assert(gold==a);
    assert(b==1);
}
+/

// Example in changelog
string log(T...)(T a, string file = __FILE__, int line = __LINE__)
{
    return text(file, ":", line, " ", a);
}

void foo_error(T...)(T a, string b = "bar") if (T.length == 1)
{
}

void main()
{
    fun0(tuple(10), 7, 10, 7);

    fun(tuple());
    fun(tuple(10), 10);
    fun(tuple(10, 11), 10, 11);

    fun2(tuple(10), tuple(__FILE__, __LINE__), 10);

    fun3([1, 2, 3], 1, 2, 3);
    // fun4([1,2,3], 1,2,3);

    assert(log(10, "abc") == text(__FILE__, ":", __LINE__, " 10abc"));

    // these should not compile, by design
    assert(!__traits(compiles, foo_error(1, "baz")));
}
