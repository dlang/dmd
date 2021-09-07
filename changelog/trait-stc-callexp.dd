# Function calls can now be used in `__traits(getParameterStorageClasses)`

Parameter storage classes can now be obtained from function calls as in this
example:

```d
void func(ref float t) {}
float f;
pragma(msg, __traits(getParameterStorageClasses, func(f), 0)); // tuple("ref")
```
