Default initialization of `union` field that isn't the first member now triggers an error

The following code has been deprecated since 2.088.0

```
union U
{
    int a;
    long b = 4;
}
```

This is problematic because unions are default initialized to whatever the
initializer for the first field is, any other initializers present are ignored.

The corrective action is to declare the `union` field with the default
initialization as the first field.
