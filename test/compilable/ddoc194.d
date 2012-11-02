// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 194

module ddoc194;


///
class Foo(T)
{
    /// don't document
    private void foo() { }

    ///
    pure void a() { }

    ///
    static void b() { }

    ///
    @property void c(int) { }

    ///
    final void d() { }

    ///
    abstract void e() { }

    ///
    void f() const { }

    ///
    void g() immutable { }

    ///
    synchronized void h() { }
}

///
struct Bar(T)
{
    /// don't document
    private void foo() { }

    ///
    pure void a() { }

    ///
    static void b() { }

    ///
    @property void c(int) { }

    ///
    final void d() { }

    /// semantically invalid, but documentable
    abstract void e() { }

    ///
    void f() const { }

    ///
    void g() immutable{ }

    ///
    synchronized void h() { }
}

/// todo note1: attribute before templated class doesn't have effect until instantiation.
/// But abstract will be picked up if any methods are abstract.
abstract class AbsFoo(T)
{
    ///
    pure void a() { }
}

/// ditto note1
synchronized class SyncFoo(T)
{
    ///
    pure void a() { }
}

///
template Temp(T)
{
    ///
    pure void a() { }

    ///
    synchronized void b() { }

    /// ditto note1
    synchronized class FooC(X)
    {
        ///
        pure void a() { }
    }

    /// ditto note1
    abstract class BarC(X)
    {
        ///
        pure void a() { }
    }
}

void main() { }
