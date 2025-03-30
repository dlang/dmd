# How to interpret failures of this test

The test code in src is built using profiling. Then it checks against the expected output based on the arch/os.

If any of these values are wrong, you will see a diff in the error report, e.g.:

```
diff \
	<(grep -vF 'core.' myprofilegc.log.linux.64.exp) \
	<(grep -vF 'core.' ./generated/linux/debug/64/myprofilegc.log)
2c2
<             464	              1	immutable(char)[][int] D main src/profilegc.d:23
---
>             496	              1	immutable(char)[][int] D main src/profilegc.d:23
```

This means that the line 23 in `src/profilegc.d` allocated 496 bytes, but was expected to allocate 464 bytes.

To accept the difference, edit the file given (in this case `myprofile.log.linux.64.exp`) to record the correct value.

Changes to these expectation files should be accompanied by a comment as to why the number changed. Do not change these numbers without understanding why it changed!
