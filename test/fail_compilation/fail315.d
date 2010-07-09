void foo(S...)(S u) {
    alias typeof(mixin("{ return a[1;}()"))  z;
}

void main() {
   foo!()(0);
}
