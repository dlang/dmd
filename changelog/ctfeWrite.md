# Add `__ctfeWrite` to write output from CTFE

The special function `__ctfeWrite` can now be used to write custom messages to
`stderr` during CTFE. The function is available in `object.d` and accepts any
value implicitly convertible to `const char[]`.

For example:

```d
int greeting()
{
	__ctfeWrite("Hello from CTFE. Today is ");
	__ctfeWrite(__DATE__);
	return 0;
}

enum forceCTFE = greeting();
```

Compiling his program will generate the following output:

```
Hello from CTFE. Today is <current date>
```
