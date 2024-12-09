/++
https://issues.dlang.org/show_bug.cgi?id=22516

TEST_OUTPUT:
---
fail_compilation/ice22516.d(20): Error: undefined identifier `X`
    X x;
      ^
---
+/

struct Data
{
    void function() eval;

}

struct Builtins
{
    X x;

    Data myData = { (){} };
}
