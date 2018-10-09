// https://issues.dlang.org/show_bug.cgi?id=5380

class A
{
}

class B
{
    A a;
    alias a this;
}

class C : B
{
}

void main()
{
    A a = new C; // error
}
