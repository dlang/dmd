Initialization of `immutable` global data from `static this` is deprecated

Prior to this release, the following code was possible:

```
module foo;
immutable int bar;
static this()
{
    bar = 42;
}
```

However, module constructors (`static this`) run each time a thread is
spawned, and `immutable` data is implicitly `shared`, which led to
`immutable` value being overriden every time a new thread was spawned.
The simple fix for this is to use `shared static this` over `static this`,
as the former is only run once per process.
