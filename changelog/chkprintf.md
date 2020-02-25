# Validate printf arguments against format specifiers

Follows the C99 specification 7.19.6.1 for printf.

Takes a generous, rather than strict, view of compatiblity.
For example, an unsigned value can be formatted with a signed specifier.

Diagnosed incompatibilities are:

1. incompatible sizes which will cause argument misalignment
2. deferencing arguments that are not pointers
3. insufficient number of arguments
4. struct arguments
5. array and slice arguments
6. non-pointer arguments to `s` specifier
7. non-standard formats
8. undefined behavior per C99

Per the C Standard, extra arguments are ignored.

No attempt is made to fix the arguments or the format string.

In order to use non-Standard printf formats, an easy workaround is:

```
printf("%k\n", value);  // error: non-Standard format k
```
```
const format = "%k\n";
printf(format, value):  // no error
```

Most of the errors detected are portability issues. For instance,

```
string s;
printf("%.*s\n", s.length, s.ptr);
printf("%d\n", s.sizeof);
long i;
printf("%ld\n", i);
```
should be replaced with:
```
string s;
printf("%.*s\n", cast(int) s.length, s.ptr);
printf("%zd\n", s.sizeof);
long i;
printf("%lld\n", i);
```

