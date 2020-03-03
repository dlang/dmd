# Validate scanf arguments against format specifiers

sscanf and fscanf are also affected by this change.

Follows the C99 specification 7.19.6.2 for scanf.

Takes a strict view of compatiblity.

Diagnosed incompatibilities are:

1. incompatible sizes which will cause argument misalignment
2. insufficient number of arguments
3. struct arguments
4. array and slice arguments
5. non-standard formats
6. undefined behavior per C99

Per the C Standard, extra arguments are ignored.

No attempt is made to fix the arguments or the format string.

In order to use non-Standard scanf formats, an easy workaround is:

```
scanf("%k\n", value);  // error: non-Standard format k
```
```
const format = "%k\n";
scanf(format.ptr, value);  // no error
```

Most of the errors detected are portability issues. For instance,

```
int i;
scanf("%ld\n", &i);
size_t s;
scanf("%d\n", &s);
ulong u;
scanf("%lld%*c\n", u);
```
should be replaced with:
```
int i;
scanf("%d\n", &i;
size_t s;
scanf("%zd\n", &s);
ulong u;
scanf("%llu%*c\n", u);
```
