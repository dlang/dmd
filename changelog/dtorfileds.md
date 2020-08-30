# -preview=dtorfields is now enabled by default

This preview ensures that partially constructed objects are properly destroyed
when an exception is thrown inside of an constructor. It was introduced in
2.075 and is now enabled by default.

Note that code will fail to compile if a constructor with strict attributes
may call a less qualified destructor:

```d
struct Array
{
    int[] _payload;
    ~this()
    {
        import core.stdc.stdlib : free;
        free(_payload.ptr);
    }
}

class Scanner
{
    Array arr;
    this() @safe {} // Might call arr.~this()
}
```

Such code should either make the constructor `nothrow` s.t. the destructor
will never be called, or adjust the field destructors.
