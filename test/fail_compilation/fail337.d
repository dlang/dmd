template bar() {
   static assert(0);
}

template foo(int N) {
  static if (N>0) {
     static if (N&1) alias foo!(N-3) foo;
     else alias foo!(N-1) foo;
  } else alias bar!() foo; 
}

template baz(int M) {
   static if (M<50) {
     alias foo!(M*4) baz;
   } else alias baz!(M-1) baz;
}

void main() {
  int x = baz!(300);
}
