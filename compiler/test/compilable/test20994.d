// https://github.com/dlang/dmd/issues/20994

// Struct with constructor
struct S { this(int x) {} }

void foo(S a = 0) {}    // ok

template Foo(S a = 0) {}

void main()
{
    S a = 0;          // ok
    foo();            // ok
    alias F = Foo!(); // should compile
}

// Struct with opCall
struct T
{
    static T opCall(int x) { T t; return t; }
}

template Bar(T a = 0) {}
alias G = Bar!();

// Array initializer
alias g = f!();
template f(byte[3] a = -1)
{
}
