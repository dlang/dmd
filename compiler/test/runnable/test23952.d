// https://github.com/dlang/dmd/issues/23952

import core.stdc.string;

extern(C++):
class A
{
    this(int number = 42, const char *filename = __FILE__.ptr, int line = __LINE__)
    {
        this.number = number;
        this.filename = filename;
        this.line = line;
    }
    ~this(){}

    int number;
    const char *filename;
    int line;
}

class B : A
{
}

class C : A
{
    this(int number = 10)
    {
        super(number);
    }
}

void main()
{
    int startLine = __LINE__;
    auto a = new A();
    assert(a.number == 42);
    assert(strcmp(a.filename, __FILE__.ptr) == 0);
    assert(a.line == startLine + 1);

    startLine = __LINE__;
    a = new A(5);
    assert(a.number == 5);
    assert(strcmp(a.filename, __FILE__.ptr) == 0);
    assert(a.line == startLine + 1);

    auto b = new B();
    startLine = __LINE__;
    assert(b.number == 42);
    assert(strcmp(b.filename, __FILE__.ptr) == 0);
    assert(b.line == 8); // Line of constructor declaration, because it is called internally.

    auto c = new C();
    startLine = __LINE__;
    assert(c.number == 10);
    assert(strcmp(c.filename, __FILE__.ptr) == 0);
    assert(c.line == 29); // Line of super call in C.this.

    c = new C(20);
    startLine = __LINE__;
    assert(c.number == 20);
    assert(strcmp(c.filename, __FILE__.ptr) == 0);
    assert(c.line == 29); // Line of super call in C.this.
}
