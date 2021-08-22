# Accessing C Declarations From D Via ImportC Compiler

One of D's best features is easy integration with C code.
There's almost a one-to-one mapping between C and a subset
of D code (known as DasBetterC). D and C code can call each
other directly.

But D cannot read C code directly. In particular, the interface
to most C code comes in the form of a .h (or "header") file.
To access the declarations in the .h file and make them
available to D code, the C declarations in the .h file must somehow
be translated into D.
Although hand translating the .h files to D is not difficult,
it is tedious, annoying, and definitely a barrier to using D
with existing C code.

Why can't the
D compiler simply read the .h file and extract its declarations?
Why doesn't it "just work"?
D has had great success with integrating documentation
generation into the language, as well as unit testing. Despite the
existence of many documentation generators and testing frameworks,
the simplicity of it being built in and "just working" is transformative.

## The C Preprocessor

Is its own language that is completely distinct from the C language
itself. It has its own grammar, its own tokens, and its own rules.
The C compiler is not even aware of the existence of the preprocessor.
(The two can be integrated, but that doesn't change the fact
that the two semantically know nothing about each other.)
The preprocessor is different enough from D that there's no hope
of translating preprocessor directives to D in anything but the most
superficial manner, any more than the preprocessor directives can
be replaced with C.

## Previous Solutions

### htod by Walter Bright

[htod](https://dlang.org/htod.html) converts a C .h file
to a D source file, suitable for importing into D code.
htod is built from the front end of the Digital Mars C and C++ compiler.
It works just like a C or C++ compiler except that its output is source
code for a D module rather than object code.

### DStep by Jacob Carlborg

[DStep code](https://code.dlang.org/packages/dstep)

[DStep Article](https://dlang.org/blog/2019/04/22/dstep-1-0-0/)

From the Article: "DStep is a tool for automatically generating D
bindings for C and Objective-C libraries. This is implemented by
processing C or Objective-C header files and outputting D modules.
DStep uses the Clang compiler as a library (libclang) to process the header files."

### dpp by Átila Neves

[dpp code](https://code.dlang.org/packages/dpp/0.2.1)

[dpp Article](https://dlang.org/blog/2019/04/08/project-highlight-dpp/)

From the Article: "dpp is a compiler wrapper that will parse a D source
file with the .dpp extension and expand in place any #include directives
it encounters, translating all of the C or C++ symbols to D, and then
pass the result to a D compiler (DMD by default)."

Like DStep, dpp relies on libclang.

## Introducing ImportC, an ISO C11 Compiler

Here is the next step:

* Forget about the C preprocessor.
* Overlook C++.
* Put a real ISO C11 compiler in the D front end.
* Call it ImportC to distinguish this unique capability.

In detail:

1. Compile C code directly, but *only* C code that has already been run through
the C preprocessor. To import stdio.h into a D program,
the build script would be:

     gcc -E -P stdio.h >stdio.c

and in the D source file:

     import stdio;  // reads stdio.c and compiles it

With gcc doing all the preprocessor work, it becomes 100% behavior compatible.

2. A C compiler front end, stripped of its integrated preprocessor, is a simple
beast. It could be compiled directly into dmd's internal data structure types.

3. The D part of dmd will have no idea it originated as C code. It would be
just another import. There is no change whatsoever to D.

### Using ImportC As A C Compiler

Instead of importing C code, dmd can be used to compile C code like a
standalone C compiler.

Create the file hello.c:

```
int printf(const char*, ...);

int main()
{
    printf("hello world\n");
}
```

Compile and run it:

```
dmd hello.c
./hello
hello world!
```

For C code using C includes you can preprocess the C source with a C
preprocessor. Create the file testcode.c:

```
#include <stdint.h>

uint32_t someCodeInC(uint32_t a, uint32_t b)
{
    return a + b;
}
```

Preprocess the C code with the C preprocessor:
```
gcc -E -P testcode.c >testcode.i
```

Create D file d_main.d:
```
import std.stdio;
import testcode;

void main()
{
    writeln("Result of someCodeInC(3,4) = ", someCodeInC(3, 4) );
}
```

Compile and run it:
```
dmd d_main.d testcode.i
./d_main
Result of someCodeInC(3,4) = 7
```

The '.i' file extension can be used instead of '.c'. This makes it clear, that
preprocessed imtermediate C code is in use. The '.i' files can be created by
some generator script or a Makefile.

## Implementation Details

### User Experience

* Error messages are spare and utilitarian.

* Recovering after encountering an error is not well developed.
Only the first error message is likely to be on point.

* Pretty-printing code is done in D syntax, not C. Also,
differing precedence for Relational/Equality expressions.

* No warnings are emitted. ImportC doesn't care about coding style,
best practices or suspicious constructs. If ISO C says it's good, it passes.

* If the ImportC code corrupts memory, overflows buffers, etc.,
it will still compile. Use DasBetterC for a better way.

* Symbolic debugging support is there.


### Variance From ISO C11

* Doesn't have a C Preprocessor.
The C code must be run through a preprocessor before
it can be processed by ImportC. Incorporating this into your build system
is advisable.

* Tag symbols are part of the global symbol table, not the special tag
symbol table like they are supposed to reside in.

* Octal literals are not supported.

* Integer literal suffixes are not correct.

* Multiple chars in char literal are not supported.

* `_Atomic` as type qualifier is ignored.

* `_Atomic` as type specifier is ignored.

* `_Alignof` is ignored.

* `_Generic` is not implemented.

* `const` is transitive, as in D. A pointer to a const pointer to a mutable
value can be declared, but it'll be treated as a pointer to a const pointer
to a const value.

* { initializer-list } is not implemented.

* ( type-name ) { initializer-list } is not implemented.

* Complex numbers are not implemented.

* Forward referencing works in ImportC. All global symbols are visible
during semantic processing,
not just the ones lexically prior to the piece of code it is working on.

* Semantics applied after C parsing are D semantics, not C semantics,
although they are very close. For example, implicitly converting an
`int` to a `char` will pass C without complaint, but the D semantic
pass will issue an error.

### Implementation Defined Behavior

The C11 Standard allows for many instances of
implementation defined behavior.

* `volatile`, `restrict`, `register`, `_Noreturn` are accepted and ignored

* `char` is unsigned

* `inline` is ignored, as the D compiler inlines what it feels like inlining.

* `long double` matches what the host C compiler does, which is not necessarily
the same as D's `real` type.


### Extensions

Using a D compiler for semantic processing offers many temptations to add in
better D semantics. Inventing yet another new dialect of C is not the point
of ImportC. However, some things are useful:

* Compile Time Function Execution

This works. It comes in handy for writing test cases for ImportC using
`_Static_assert`. It also means that the D compiler can execute the ImportC
functions in imports just like it can for D.

### Unimplemented Extensions

* Much of C code makes use of extensions provided by the host C compiler.
None of these are implemented.

* Alternative keywords are not implemented. You can define the alternate
  keywords as macros to remove or replace them with standard keywords.

```
#define __attribute __attribute__
#define __asm       asm
#define __asm__     asm
#define __const     const
#define __const__   const
#define __inline    inline
#define __inline__  inline
#define __extension__

#include <stdlib.h>
```

## Future Directions

### C Preprocessor

Some means of incorporating this may be practical. For now, use cpp,
warp or spp.

Translation of C macros to D needs to be done, as htod, DStep and dpp all
do this.

### ImportC++ ?

No. Use dpp.

### ImportObjective-C ?

No. Use DStep.
