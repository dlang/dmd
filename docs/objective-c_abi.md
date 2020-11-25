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
the documentation provided by Apple, looking at assembly outputs and object dumps
from the LLVM compiler.

Objective-C is a superset of C, therefore any of the language constructs that
also exist in C, like functions, structs, and variables use the C ABI of the
platform. This document only describes the ABI of the Objective-C specific
language constructs.

## Messages

The Objective-C model of object-oriented programming is based on message passing
to object instances. Unlike D or C++ where a method is called. The difference
from an implementation standpoint is that in D and C++ a vtable is used which
is an array of function pointers and the compiler uses an index into that array
to determine which method to call. In Objective-C, it's the runtime that is
responsible for finding the correct implementation when a message is sent to an
object. A method is identified by a *selector*, a null-terminated string
representing its name, which maps to a C function pointer that implements the
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
instead, as if the `objc_msgSend` function had the same signature as the method
that should be called but with the two additional parameters, `self` and `op`,
added first. The implementation of `objc_msgSend` will jump to the method
instead of calling it.

Because of the above, multiple versions of `objc_msgSend` exist. Depending on
the return type of the method that is called, the correct version will be
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

### Super Calls

Making a super call is similar to making a regular call to an instance method.
Instead of the `objc_msgSend` family of functions, the `objc_msgSendSuper`
family is used. There are two functions available:

* `objc_msgSendSuper_stret` - Used for structs too large to be returned in
registries
* `objc_msgSendSuper` - For everything else

The signature of `objc_msgSendSuper` is:

```c
id objc_msgSend(struct objc_super* super, SEL op, ...);
```

And for `objc_msgSendSuper_stret`:

```c
id objc_msgSend(void* stretAddr, struct objc_super* super, SEL op, ...);
```

The `objc_super` struct looks as follows:

```c
struct objc_super
{
    id receiver;
    Class super_class;
}
```

Where `receiver` is the `this` pointer and `super_class` is the super class to
call. `super_class` should be a
[`L_OBJC_CLASSLIST_REFERENCES_$_`](#l_objc_classlist_references__) symbol.

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

## Instance Variables

To solve the fragile base class problem instance variables are accessed with an
offset through a symbol generated in the binary. The compiler outputs the symbol
containing a static offset and, if there's a need, at load time the offset will
be updated to reflect the new offset if a base class has a different layout at
runtime.

The symbol has the name `_OBJC_IVAR_$_<class_name>.<ivar_name>` symbol,
where `<class_name>` is the name of the class the instance variable belongs to
and `<ivar_name>` is the name of the instance variable.

## Symbols

### Linkages

#### External Linkage

Externally visible function.

#### Internal Linkage

Rename collisions when linking (static functions).

#### Private Linkage

Like [Internal](#internal-linkage), but omit from the symbol table.

### `L_OBJC_METH_VAR_NAME_`

For each selector that is used, a symbol is generated in the resulting binary.
The symbol has the name `L_OBJC_METH_VAR_NAME_.<number>`, where `<number>` is an
incrementing number. The selector is stored as a null-terminated C string as the
section data.

| Section                                     | Linkage                      | Alignment |
|---------------------------------------------|------------------------------|-----------|
| [`__objc_methname`](#segments-and-sections) | [Private](#private-linkage)  | 1         |

### `L_OBJC_METH_VAR_TYPE_`

For each method that is defined, a symbol is generated in the resulting binary.
The symbol has the name `L_OBJC_METH_VAR_TYPE_.<number>`, where `<number>` is an
incrementing number. The section data contains the return type and the parameter
types encoded as a null-terminated C string as according to the [Type Encoding](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100)
documentation provided by Apple.

| Section                                     | Linkage                      | Alignment |
|---------------------------------------------|------------------------------|-----------|
| [`__objc_methtype`](#segments-and-sections) | [Private](#private-linkage)  | 1         |

### `l_OBJC_$_INSTANCE_METHODS_`/`l_OBJC_$_CLASS_METHODS_`

For each class that is defined and contains at least one class (static)
method, a symbol is generated in the resulting binary. The symbol has the name
`l_OBJC_$_CLASS_METHODS_<class_name>`, where `<class_name>` is the name of the
class. For each class that is defined and contains at least one instance method,
a symbol is generated with the name `l_OBJC_$_INSTANCE_METHODS_<class_name>`,
where `<class_name>` is the name of the class. The section data that is stored
corresponds to the following structs:

```d
struct __method_list_t
{
  int entsize;
  int count;
  _objc_method first;
}
```

```d
struct _objc_method
{
  char* name;
  char* types;
  void* imp;
}
```

#### `__method_list_t`
#####  `entsize`

The size of `_objc_method` in bytes, always `24`.

##### `count`

The number of methods in the list.

##### `first`

The first method.

#### `_objc_method`
##### `name`

The name of the method. This is stored as a reference to the
`L_OBJC_METH_VAR_NAME_.<number>` symbol, where `<number>` is an incrementing
number.

##### `types`

The type encoding of the method. This is stored as a reference to the
`L_OBJC_METH_VAR_TYPE_.<number>` symbol, where `<number>` is an incrementing
number.

##### `imp`

The actual method implementation. The address to the function that is the method
implementation.

| Section                                  | Linkage                      | Alignment |
|------------------------------------------|------------------------------|-----------|
| [`__objc_const`](#segments-and-sections) | [Private](#private-linkage)  | 8         |

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

For any binary that is built, the `L_OBJC_IMAGE_INFO` symbols are generated. The
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

Indicates if features like garbage collector, automatic reference counting
(ARC) or class properties are supported. These features can be enabled/disabled
in the Clang compiler using command line switches. The exact values used, or the
features supported, are not known. The value of `64` is what Clang 9.0 outputs
by default when no switches are specified.

| Section                                      | Linkage                      | Alignment |
|----------------------------------------------|------------------------------|-----------|
| [`__objc_imageinfo`](#segments-and-sections) | [Private](#private-linkage)  | 8         |

### `L_OBJC_CLASS_NAME_`

For each class defined, a symbol is generated in the resulting binary. The
symbol has the name `L_OBJC_CLASS_NAME_.<number>`, where `<number>` is an
incrementing number. The name of the class is stored as a null-terminated C
string as the section data.

| Section                                      | Linkage                      | Alignment |
|----------------------------------------------|------------------------------|-----------|
| [`__objc_classname`](#segments-and-sections) | [Private](#private-linkage)  | 8         |

### `l_OBJC_CLASS_RO_$_`/`l_OBJC_METACLASS_RO_$_`

For each class defined, two symbols are generated in the resulting binary. One
symbols with the name `l_OBJC_CLASS_RO_$_<class_name>` and one with the name
`l_OBJC_METACLASS_RO_$_<class_name>`, where `<class_name>` is the name of the
class. The first symbol is for the class and the second symbol is for the
metaclass. The section data that is stored corresponds to the following struct:

```d
struct _class_ro_t
{
    int flags;
    int instanceStart = 40;
    int instanceSize = 40;
    byte* reserved;
    byte* ivarLayout;
    char* name;
    __method_list_t* baseMethods;
    _objc_protocol_list* baseProtocols;
    _ivar_list_t* ivars;
    byte* weakIvarLayout;
    _prop_list_t* baseProperties;
}
```

#### `flags`

A bit field indicating if the class is a regular class, metaclass or root class.
Possible flags:

* regular class: `0`
* metaclass: `0x00001`
* root class: `0x00002`

#### `instanceStart`

The start of the instance, in bytes. For a metaclass, this is always `40`. For a
class without instance variables it's the size of the class declaration.
Otherwise, it's the offset of the first instance variable.

#### `instanceSize`

The size of an instance of this class, in bytes. For a metaclass, this is always
`40`.

#### `reserved`

Currently not used. Reserved for future use.

#### `ivarLayout`

Unknown. Seems to be `null`.

#### `name`

The name of the class. This is stored as a reference to the
`L_OBJC_CLASS_NAME_<class_name>` symbol, where `<class_name>` is the name of the
class.

#### `baseMethods`

A list of the class (static) methods this class contains. This is stored as a
reference to the `l_OBJC_$_CLASS_METHODS_<class_name>` symbol, where
`<class_name>` is the name of the class. If the class doesn't contain any class
methods, `null` is stored instead.

#### `baseProtocols`

A list of the protocols this class implements.

#### `ivars`

A list of the instance variables this class contains. This is stored as a
reference to the `l_OBJC_$_INSTANCE_VARIABLES_<class_name>`, where
`<class_name>` is the name of the class. For a metaclass or if the class doesn't
have any instance variables, this will be `null`.

#### `weakIvarLayout`

Unknown. Seems to be `null`.

#### `baseProperties`

A list of the properties this class contains.

| Section                                  | Linkage                      | Alignment |
|------------------------------------------|------------------------------|-----------|
| [`__objc_const`](#segments-and-sections) | [Private](#private-linkage)  | 8         |

### `_OBJC_CLASS_$_`/`_OBJC_METACLASS_$_`

For each class defined, two symbols are generated in the resulting binary. One
symbol with the name `_OBJC_CLASS_$_<class_name>` and one with the name
`_OBJC_METACLASS_$_<class_name>`, where `<class_name>` is the name of the
class. The first symbol is for the class and the second symbol is for the
metaclass. The section data that is stored corresponds to the following struct:

```d
struct _class_t
{
    _class_t* isa;
    _class_t* superclass;
    _objc_cache* cache;
    void* vtable;
    _class_ro_t* data;
}
```

#### `isa`

Pointer to the metaclass. This is stored as a reference to the
`_OBJC_METACLASS_$_<class_name>` symbol, where `<class_name>` is the name of the
class.

#### `superclass`

Pointer to the base class. This is stored as a reference to the
`_OBJC_CLASS_$_<class_name>` symbol, where `<class_name>` is the name of the
base class. Or a reference to the `_OBJC_METACLASS_$_<class_name>`, if this is a
metaclass. If this class is a root class this will be `null`.

#### `cache`

Unknown. Usually a pointer to an empty cache object. This is stored as a
reference to the externally defined `__objc_empty_cache` symbol.

#### `vtable`

Pointer to the vtable. For some selectors, as an optimization, a vtable can be
used when calling the method, instead of the regular implementation. This
applies to around 20 selectors that are very common to call but unlikely for
these methods to be overridden.

#### `data`

A pointer to the class implementation. This is stored as a reference to the
`l_OBJC_CLASS_RO_$_<class_name>` symbol, where `<class_name>` is the name of the
class. Or a reference to the `l_OBJC_METACLASS_RO_$_<class_name>` symbol, if
this class is metaclass.

| Section                                 | Linkage                        | Alignment |
|-----------------------------------------|--------------------------------|-----------|
| [`__objc_data`](#segments-and-sections) | [External](#external-linkage)  | 8         |

### `L_OBJC_LABEL_CLASS_$`

Contains a list of `_class_t` pointers for each class that is defined. This is
stored as a reference to the `_OBJC_CLASS_$_<class_name>` symbol, where
`<class_name>` is the name of the class.

| Section                                      | Linkage                      | Alignment |
|----------------------------------------------|------------------------------|-----------|
| [`__objc_classlist`](#segments-and-sections) | [Private](#private-linkage)  | 8         |

### `l_OBJC_$_INSTANCE_VARIABLES_`

For each class that is defined and contains at least one instance variable,
a symbol is generated in the resulting binary. The symbol has the name
`l_OBJC_$_INSTANCE_VARIABLES_<class_name>` where `<class_name>` is the name of
the class. The section data that is stored corresponds to the following struct:

```d
struct _ivar_list_t
{
    int entsize;
    int count;
    _ivar_t[count] list;
}

struct _ivar_t
{
    long* offset;
    char* name;
    char* type;
    int alignment;
    int size;
}
```

#### `_ivar_list_t`

##### `entsize`

The size of `_ivar_t` in bytes, always 32.

##### `count`

The number of instance variables in the list.

##### `list`

The list of instance variables.

#### `_ivar_t`

##### `offset`

Offset to the instance variable. This is stored as a reference to the
`_OBJC_IVAR_$_<class_name>.<ivar_name>` symbol, where `<class_name>` is the name
of the class and `<ivar_name>` is the name of the instance variable.

##### `name`

The name of the instance variable. This is store as a reference to the
`L_OBJC_METH_VAR_NAME_.<number>` symbol, where `<number>` is an incrementing
number.

##### `type`

The type of the instance variable. This is store as a reference to the
`L_OBJC_METH_VAR_TYPE_.<number>` symbol, where `<number>` is an incrementing
number.

##### `alignment`

The alignment of the instance variable.

##### `size`

The size of the instance variable.

| Section                                  | Linkage                      | Alignment |
|------------------------------------------|------------------------------|-----------|
| [`__objc_const`](#segments-and-sections) | [Private](#private-linkage)  | 8         |

## Segments and Sections

The following segments and sections are used to store data in the binary. This
table also includes properties of these sections:

| Section            | Segment  | Type               | Attribute       | Alignment |
|--------------------|----------|--------------------|-----------------|-----------|
| `__objc_imageinfo` | `__DATA` | `regular`          | `no_dead_strip` | 0         |
| `__objc_methname`  | `__TEXT` | `cstring_literals` |                 | 0         |
| `__objc_classlist` | `__DATA` | `regular`          | `no_dead_strip` | 8         |
| `__objc_selrefs`   | `__DATA` | `literal_pointers` | `no_dead_strip` | 8         |
| `__objc_classrefs` | `__DATA` | `regular`          | `no_dead_strip` | 8         |
| `__objc_classname` | `__TEXT` | `cstring_literals` |                 | 0         |
| `__objc_const`     | `__DATA` | `regular`          |                 | 8         |
| `__objc_data`      | `__DATA` | `regular`          |                 | 8         |
| `__objc_methtype`  | `__TEXT` | `cstring_literals` |                 | 0        |

For more information about the different section types and attributes, see
the documentation for [Assembler Directives](https://developer.apple.com/library/content/documentation/DeveloperTools/Reference/Assembler/040-Assembler_Directives/asm_directives.html) from Apple.

## Tools

Here follows a list of useful tools that can/have been used to get the
information available in this document.

### Clang

Shipped with Apple's developer tools, Xcode.

#### Assembly Output

Outputs the assembly code, symbols, and their data. Invoke Clang with the `-S`
flag:

```sh
$ ls
main.m
$ clang -S main.m
$ ls
main.m main.s
```

#### LLVM IR Output

Outputs the LLVM IR code, symbols, and their data. Invoke Clang with the
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

A third-party tool that costs money. A 30 minutes demo session is available but it
can be restarted indefinitely. Available at https://www.hopperapp.com.
