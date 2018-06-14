// https://issues.dlang.org/show_bug.cgi?id=17864

struct A { int a; }
void g()
{
    shared A a;
    A b;
    a=b; //converts
    assert(a==b); //fail
}
