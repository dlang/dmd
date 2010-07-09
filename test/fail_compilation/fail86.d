template Foo(TYPE) {}

void main() {
	alias Foo!(int) Foo;
}

