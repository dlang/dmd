Initialization of `immutable` global data from `static this` now triggers an error

The following code has been deprecated since 2.087.0.

```
module foo;
immutable int bar;
static this()
{
    bar = 42;
}
```

This is problematic because module constructors (`static this`) run each time a
thread is spawned, and `immutable` data is implicitly `shared`, which led to
`immutable` value being overriden every time a new thread was spawned.

The corrective action for any code that still does this is to use `shared
static this` over `static this`, as the former is only run once per process.
