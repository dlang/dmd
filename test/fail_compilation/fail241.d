class Foo
{
    public void f() { }
    private void g() { }

    invariant()
    {
        f();  // error, cannot call public member function from invariant
        g();  // ok, g() is not public
    }
}

