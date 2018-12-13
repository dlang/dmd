# The Objective-C ABI

There are several Objective-C runtimes and ABIs available:

* Apple/NeXT runtime
  * Legacy ABI, version 0 - The traditional 32-bit ABI *without* support for
    Objective-C 2.0 features. Used on the old PowerPC platform
  * Legacy ABI, version 1 - The traditional 32-bit ABI *with* support for
    Objective-C 2.0 features. Used on macOS 32-bit
  * Modern ABI, version 2 - The modern 64-bit ABI. Used on all other Apple
    platforms
* GNU runtime - used on non-Apple platforms

This document describes the Apple runtime with the modern ABI on macOS x86-64,
as implemented by the Apple LLVM compiler (`9.0.0 (clang-900.0.39.2)`) shipped
with Xcode 9.2. The information in this document has been obtained by reading
documentation provided by Apple, looking at assembly outputs and object dumps
from the LLVM compiler.

Objective-C is a superset of C, therefore any of the language constructs that
also exists in C, like functions, structs and variables use the C ABI of the
platform. This document only describes the ABI of the Objective-C specific
language constructs.

## Messages

The Objective-C model of object-oriented programming is based on message passing
to object instances. Unlike D or C++ where a method is called. The difference
from implementation stand point is that in D and C++ a vtable is used which
is an array of function pointers and the compiler uses an index into that array
to determine which method to call. In Objective-C it's the runtime that is
responsible for finding the correct implementation when a message is sent to an
object. A method is identified by a *selector*, a null terminated string
representing it's name, which maps to a C function pointer that implements the
method.

## Message Expression

In Objective-C, sending a message to an object looks like the following example:

```objective-c
int result = [receiver message];
```

In D it would look like:

```d
int result = receiver.message();
```

The compiler implements this by making a regular C call to the `objc_msgSend`
function in the Objective-C runtime. The signature of `objc_msgSend` looks
something like this:

```objective-c
id objc_msgSend(id self, SEL op, ...);
```

* The first parameter is the receiver (`this`/`self` pointer)
* The second parameter is the name of the method mentioned in the message -
  that is, the method selector
* The last parameter is for all the arguments that the
  implementation expects

The above example would be translated by the compiler to the following:

```c
int result = objc_msgSend(receiver, selector);
```

If the method expects any arguments they're passed after the selector argument:

```c
int result = objc_msgSend(receiver, selector, arg1, arg2);
```

The call to `objc_msgSend` should not be performed as a variadic call but
instead as if the `objc_msgSend` function had the same signature as the method
that should be called, but with the two additional parameter, `self` and `op`,
added first. The implementation of `objc_msgSend` will jump to the method
instead of calling it.

Because of the above, multiple versions of `objc_msgSend` exist. Depending on
the return type of the method that is called, the correct version will to be
used. This depends on the platform C ABI. This is a list of functions for
which return types they're used:

* `objc_msgSend_stret` - Used for structs too large to be returned in
registries
* `objc_msgSend_fpret` - Used for `long double`
* `objc_msgSend_fp2ret` - Used for `_Complex long double`
* `objc_msgSend` - Used for everything else

### Returning a Struct

If a struct is small enough to be returned in registers (according to the
platform C ABI), the regular `objc_msgSend` function is used. If the struct will
not fit in registers, the `objc_msgSend_stret` function is used. The signature of
`objc_msgSend_stret` looks like this:

```objective-c
void objc_msgSend_stret(void * stretAddr, id self, SEL op, ...);
```

In the above signature, `stretAddr` is the address to a struct on the stack of
the caller, which will be the returned value. The compiler calls this function
like:

```objective-c
struct Foo foo;
objc_msgSend_stret(&foo, receiver, selector);
```

### Metaclass

All classes in Objective-C are themselves objects. A class object is an
instance of the class' metaclass. Metaclasses follow their own inheritance
chain. A metaclass inherits from the metaclass of the class' superclass. This
continues all the way up to the root class (which in most cases is the NSObject
class). The metaclass of the root class is an instance of itself.

Below is a diagram of the inheritance and instance relationships between classes
and metaclasses:

<!--
  The diagram below might look broken in a text editor but is rendered properly
  on GitHub.
-->

```
┌──────────┬─────────────────────────┬─────────────────────────┐
│          │                         │                         │
│          │                         │                         │
│  ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│  │              │          │              │          │              │
│  │  NSObject's  │          │    Foo's     │          │    Bar's     │
├─▶│  metaclass   │◀─ ─ ─ ─ ─│  metaclass   │◀ ─ ─ ─ ─ │  metaclass   │
   │              │          │              │          │              │
│  └──────────────┘          └──────────────┘          └──────────────┘
           ▲                         ▲                         ▲
│          │                         │                         │
           │                         │                         │
│          │                         │                         │
           │                         │                         │
│  ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
   │              │          │              │          │              │
│  │   NSObject   │          │     Foo      │          │     Bar      │
 ─▶│              │◀─ ─ ─ ─ ─│              │◀─ ─ ─ ─ ─│              │
   │              │          │              │          │              │
   └──────────────┘          └──────────────┘          └──────────────┘
           ▲                         ▲                         ▲
           │                         │                         │
           │                         │                         │
           │                         │                         │
   ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
   │              │          │              │          │              │
   │ instance of  │          │ instance of  │          │ instance of  │
   │   NSObject   │          │     Foo      │          │     Bar      │
   │              │          │              │          │              │
   └──────────────┘          └──────────────┘          └──────────────┘


   an object ─────────▶ its class
   a class   ─ ─ ─ ─ ─▶ its superclass
```

### Messaging a Class Method

Calling a class method, or a static method, in a language like D or C++ is
basically the same as calling a free function. It's just scoped differently in
the source code and might have a different mangled name.

Since Objective-C classes are themselves objects, messaging a class method is
implemented exactly the same as messaging an instance method, it's just a
different `this` pointer. The `this` pointer should be a
[`L_OBJC_CLASSLIST_REFERENCES_$_`](#l_objc_classlist_references__) symbol.

## Symbols

### Linkages

#### Internal Linkage

Rename collisions when linking (static functions).

#### Private Linkage

Like [Internal](#internal-linkage), but omit from symbol table.

### `L_OBJC_METH_VAR_NAME_`

For each selector that is used, a symbol is generated in the resulting binary.
The symbol has the name `L_OBJC_METH_VAR_NAME_.<number>`, where `<number>` is an
incrementing number. The selector is stored as a null terminated C string as the
section data.

| Section                                     | Linkage                      | Alignment |
|---------------------------------------------|------------------------------|-----------|
| [`__objc_methname`](#segments-and-sections) | [Private](#private-linkage)  | 1         |

### `L_OBJC_SELECTOR_REFERENCES_`

For each `L_OBJC_METH_VAR_NAME_` symbol that is generated, a corresponding
symbol is generated as well. The symbol has the name
`L_OBJC_SELECTOR_REFERENCES_.<number>`, where `<number>` is an incrementing
number. The section data that is stored is a reference to the corresponding
`L_OBJC_METH_VAR_NAME_`.

| Section                                    | Linkage                      | Alignment |
|--------------------------------------------|------------------------------|-----------|
| [`__objc_selrefs`](#segments-and-sections) | [Private](#private-linkage)  | 8         |

### `L_OBJC_CLASSLIST_REFERENCES_$_`

For each externally defined class that is referenced, a symbol is generated in
the resulting binary. The symbol has the name
`L_OBJC_CLASSLIST_REFERENCES_$_.<number>`, where `<number>` is an incrementing
number. The content of the symbol is a reference to an externally defined
symbol with the name `_OBJC_CLASS_$_<class_name>`, where `<class_name>` is the
name of the class.

| Section                                      | Linkage                      | Alignment |
|----------------------------------------------|------------------------------|-----------|
| [`__objc_classrefs`](#segments-and-sections) | [Private](#private-linkage)  | 8         |

### `L_OBJC_IMAGE_INFO`

For any binary that is built, the `L_OBJC_IMAGE_INFO` symbols is generated. The
section data that is stored corresponds to the following struct:

```d
struct ObjcImageInfo
{
    int version_ = 0;
    int flags = 64;
}
```

#### `version`

Seems to always be fixed.

#### `flags`

Indicates if features like: garbage collector, automatic reference counting
(ARC) or class properties are supported. These features can be enabled/disabled
in the Clang compiler using command line switches. The exact values used, or the
features supported, are not known. The value of `64` is what Clang 9.0 outputs
by default when no switches are specified.

| Section                                      | Linkage                      | Alignment |
|----------------------------------------------|------------------------------|-----------|
| [`__objc_imageinfo`](#segments-and-sections) | [Private](#private-linkage)  | 8         |

## Segments and Sections

The following segments and sections are used to store data in the binary. This
table also includes properties of these sections:

| Section            | Segment   | Type                | Attribute       |  Alignment |
|--------------------|-----------|---------------------|-----------------|------------|
| `__objc_imageinfo` | `__DATA`  | `regular`           | `no_dead_strip` | 0          |
| `__objc_methname`  | `__TEXT`  | `cstring_literals`  |                 | 0          |
| `__objc_classlist` | `__DATA`  | `regular`           | `no_dead_strip` | 8          |
| `__objc_selrefs`   | `__DATA`  | `literal_pointers`  | `no_dead_strip` | 8          |
| `__objc_classrefs` | `__DATA`  | `regular`           | `no_dead_strip` | 8          |

For more information about the different section types and attributes, see
the documentation for [Assembler Directives](https://developer.apple.com/library/content/documentation/DeveloperTools/Reference/Assembler/040-Assembler_Directives/asm_directives.html) from Apple.

## Tools

Here follows a list of useful tools that can/have been used to get the
information available in this document.

### Clang

Shipped with Apple's developer tools, Xcode.

#### Assembly Output

Outputs the assembly code, symbols and their data. Invoke Clang with the `-S`
flag:

```sh
$ ls
main.m
$ clang -S main.m
$ ls
main.m main.s
```

#### LLVM IR Output

Outputs the LLVM IR code, symbols and their data. Invoke Clang with the
`-emit-llvm -S` flags:

```sh
$ ls
main.m
$ clang -emit-llvm -S main.m
$ ls
main.m main.ll
```

### otool

Apple's disassembly and object dump tool. Can pretty print the Objective-C
sections, including visualizing the sections as structs including names of the
fields. Recommended flags: `-rVotv`.

```sh
$ clang -c main.m -o main.o
$ otool -rVotv main.o
```

Shipped with Apple's developer tools, Xcode.

### LLVM Object Reader - llvm-readobj

Object reader/dumper from LLVM.

```sh
$ clang -c main.m -o main.o
$ llvm-readobj -file-headers -s -sd -r -t -macho-segment -macho-dysymtab -macho-indirect-symbols main.o
```

Shipped with the official LLVM/Clang distributions, i.e.
https://releases.llvm.org.

### dumpobj

DigitalMars object dumper.

```sh
$ clang -c main.m -o main.o
$ dumpobj main.o
```

Shipped with DMD.

### Hopper Disassembler

Interactive disassembler for macOS and Linux with a GUI. Can pretty print the
Objective-C sections, including visualizing the sections as structs including
names of the fields.

Third party tool that costs money. A 30 minutes demo session is available but it
can be restarted indefinitely. Available at https://www.hopperapp.com.
