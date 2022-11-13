/*
TEST_OUTPUT:
---
compilable/diag20916.d(32): Deprecation: `alias fb this` is deprecated
compilable/diag20916.d(37):        instantiated from here: `jump2!(Foo)`
compilable/diag20916.d(42):        instantiated from here: `jump1!(Foo)`
compilable/diag20916.d(32): Deprecation: function `diag20916.FooBar.toString` is deprecated
compilable/diag20916.d(37):        instantiated from here: `jump2!(Foo)`
compilable/diag20916.d(42):        instantiated from here: `jump1!(Foo)`
compilable/diag20916.d(32): Deprecation: template `diag20916.Bar.toString()()` is deprecated
compilable/diag20916.d(37):        instantiated from here: `jump2!(Bar)`
compilable/diag20916.d(43):        instantiated from here: `jump1!(Bar)`
compilable/diag20916.d(21): Deprecation: variable `diag20916.Something.something` is deprecated
compilable/diag20916.d(24):        instantiated from here: `nestedCheck!(Something)`
---
 */

#line 1
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

template nestedCheck(T)
{
    enum nestedCheck = T.something.init == 0;
}

struct Constraint (T) if(nestedCheck!T)
{
    T value;
}
struct Something { deprecated int something; }

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
    Constraint!Something c1;
}
