# Added support for `extern(D)` declarations from another module (`extern(D, pkg.mod)`)

`extern(D)` symbols were previously assumed to be in the same module, which was of limited use.
Multiple projects (including druntime itself) worked around that limitation by using
`pragma(mangle)` on symbols, along with `core.demangle : mangle`.

This release adds proper support for `extern(D)` symbols defined in another module,
by allowing one to specify the module name as an optional second argument:
```
module awesomelib.awesomemod;

extern(D, secretlib.secretmodule) void initializeDLL();
```

Note that the functionality was previously possible by using header (`.di`) files,
however it required adding a new file to one's project, and wasn't as convenient
to use as other `extern` (C, C++, Objective-C) declarations.
