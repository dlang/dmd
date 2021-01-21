Deprecated result of __traits(isStaticArray, ...) for enum types

`__traits(isStaticArray, <some enum>)` currently yields true for enums
with static arrays as their base type. This is in violation of the
spec[1] because a named enum creates a distinct type which is implicitly
convertible to it's base type. Hence `__traits(isStaticArray, <enum>)`
should yield `false` as done for an equivalent `is(...)` expression.

The compiler will now issue a deprecation when code depends on the
current behaviour to avoid silent code changes:

```
enum EnumArray : int[2]
{
    a = [ 1, 2 ],
    b = [ 3, 4 ]
}

static assert(__traits(isStaticArray, EnumArray));
```

```
app.d(7): Deprecation: isStaticArray currently yields `true` for enum `EnumArray`
app.d(7):        This will change with version 2.105
```

[1] https://dlang.org/spec/enum.html#named_enums

[2] https://issues.dlang.org/show_bug.cgi?id=21570
