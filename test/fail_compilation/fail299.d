struct Foo {
}

void foo (Foo b, void delegate ()) {
}

void main () {
    foo(Foo(1), (){});
}
