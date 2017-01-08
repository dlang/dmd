/*
 * REQUIRED_ARGS: -c
 * TEST_OUTPUT:
---
compilable/b11934.d(42): Deprecation: S1().front doesn't return references
compilable/b11934.d(46): Deprecation: S3(0).front doesn't return references
compilable/b11934.d(48): Deprecation: S4().front doesn't return references
---
*/
struct S1
{
    @property bool empty();
    @property int front();
    void popFront();
}

struct S2
{
    @property bool empty();
    @property ref int front();
    void popFront();
}

struct S3
{
    @property bool empty();
    int front;
    void popFront();
}

struct S4
{
    @property bool empty();
    @property int _front();
    void popFront();
    alias _front _front_;
    alias _front_ front;
}

void main()
{
    foreach(ref n; S1()) { }
    foreach(    n; S1()) { }
    foreach(ref n; S2()) { }
    foreach(    n; S2()) { }
    foreach(ref n; S3()) { }
    foreach(    n; S3()) { }
    foreach(ref n; S4()) { }
    foreach(    n; S4()) { }
}
