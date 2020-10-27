/*
TEST_OUTPUT:
---
compilable/diag20916.d(36): Deprecation: `alias fb this` is deprecated
compilable/diag20916.d(41):        instantiated from here: `jump2!(Foo)`
compilable/diag20916.d(46):        instantiated from here: `jump1!(Foo)`
compilable/diag20916.d(36): Deprecation: function `diag20916.FooBar.toString` is deprecated
compilable/diag20916.d(41):        instantiated from here: `jump2!(Foo)`
compilable/diag20916.d(46):        instantiated from here: `jump1!(Foo)`
compilable/diag20916.d(36): Deprecation: function `diag20916.Bar.toString!().toString` is deprecated
compilable/diag20916.d(41):        instantiated from here: `jump2!(Bar)`
compilable/diag20916.d(47):        instantiated from here: `jump1!(Bar)`
---
 */

struct FooBar
{
    deprecated string toString() const { return "42"; }
    int value = 42;
}

struct Foo
{
    FooBar fb;
    deprecated alias fb this;
}

struct Bar
{
    deprecated string toString()() const { return "42"; }
    int value = 42;
}

void jump2(T) (T value)
{
    assert(value.toString() == "42");
}

void jump1(T) (T value)
{
    jump2(value);
}

void main ()
{
    jump1(Foo.init);
    jump1(Bar.init);
}
