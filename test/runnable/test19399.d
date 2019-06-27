void boo(bool b) { assert(0); }
void boo(int i) {}

enum Boo : int
{
    a = 1,
    b = 2,
}

void foo(byte v) { assert(0); }
void foo(int v) {}

enum A : int {
    a = 127,
    b = 128, // shh just ignore this
}

void main()
{
    foo(Boo.a); //prints 'bool', should print int
    foo(Boo.b); //prints 'int' correctly

    A v = A.a;
    foo(A.a);  // byte 127
    foo(v);    // int 127 should be byte 127
}
