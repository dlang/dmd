import std.stdio;

struct A {
     int a = 3;

     this( int var ) {
         a += var;
     }

     ~this() {
         writeln("A down ", a);
     }
}

struct B {
     A a = A(2);

     this( int var ) {
         a = A(var+1);
         throw new Exception("An exception");
     }
}

void main()
{
     try {
         auto b = B(2);
     } catch( Exception ex ) {
     }
writeln(B.init);
}
