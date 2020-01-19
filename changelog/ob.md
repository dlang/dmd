# Prototype Ownership/Borrowing System for Pointers

An Ownership/Borrowing (aka OB) system for pointers can guarantee that
dereferenced pointers are pointing to a valid memory object.


## Scope of Prototype OB System

This is a prototype OB system adapted to D. It is initially for pointers
only, not dynamic arrays, class references, refs, or pointer fields
of aggregates. Adding support for such adds complexity,
but does not change the nature of it, hence it is deferred to later.
RAII objects can safely manage their own memory, so are not covered
by OB. Whether a pointer is allocates memory using the GC or some other
storage allocator is immaterial to OB, they are not distinguished and are
handled identically.

The system is only active in functions annotated with the `@live` attribute.
It is applied after semantic processing is done as purely a check
for violations of the OB rules. No new syntax is added. No change is made
to the code generated.
If `@live` functions
call non-`@live` functions, those called functions are expected to present
an `@live` compatible interface, although it is not checked.

The OB system will detect as errors:

* dereferencing pointers that are in an invalid state
* more than one active pointer to a mutable memory object

It will not detect attempts to dereference `null` pointers or possibly
`null` pointers. This is unworkable because there is no current method
of annotating a type as a non-`null` pointer.


## Core OB Principle

The OB design follows from the following principle:

For each memory object, there can exist either exactly one mutating pointer
to it, or multiple non-mutating (read-only) pointers.


## Design

The single mutating pointer is called the "owner" of the memory object.
It transitively owns the memory object and all memory objects accessible
from it (i.e. the memory object graph). Since it is the sole pointer to
that memory object, it can safely
manage the memory (change its shape, allocate, free and resize) without
pulling the rug out from under any other pointers (mutating or not)
that may point to it.

If there are multiple read-only pointers to the memory object graph,
they can safely read from it without being concerned about the memory
object graph being changed underfoot.

The rest of the design is concerned with how pointers become owners,
read only pointers, and invalid pointers, and how the Core OB Principle
is maintained at all times.


### Tracked Pointers

The only pointers that are tracked are those declared in the `@live` function
as `this`, function parameters or local variables. Variables from other
functions are not tracked, even `@live` ones, as the analysis of interactions
with other functions depends
entirely on that function signature, not its internals.
Parameters that are const are not tracked.


### Pointer States

Each pointer is in one of the following states:

1. Undefined

The pointer is in an invalid state. Dereferencing such a pointer is
an error.

2. Owner

The owner is the sole pointer to a memory object graph.
An Owner pointer normally does not have a `scope` attribute.
If a pointer with the `scope` attribute is initialized
with an expression not derived from a tracked pointer, it is an Owner.

If an Owner pointer is assigned to another Owner pointer, the
former enters the Undefined state.


3. Borrowed

A Borrowed pointer is one that temporarily becomes the sole pointer
to a memory object graph. It enters that state via assignment
from an owner pointer, and the owner then enters the Lent state
until after the last use of the borrowed pointer.

A Borrowed pointer must have the `scope` attribute and must
be a pointer to mutable.

4. Lent

A Lent pointer loaned out its value to a Borrowed pointer. While
in the Lent state the pointer cannot have its value read or written
to.
A Lent pointer must not be `scope` and must be a pointer to mutable.

5. Readonly

A Readonly pointer acquires its value from an Owner. Afterwards,
the Owner enters the View state.
A Readonly pointer must have the `scope` attribute and also
must not be a pointer to mutable.

6. View

A View pointer can be used to read, but not write, from the memory object.
More Readonly pointers can be copied from it. It returns to the Owner
state after the last use of all Readonly pointers copied from it.
A Lent pointer must not be `scope` and must be a pointer to mutable,
even though it cannot mutate what it points to while it is in the
View state.

### Lifetimes

The lifetime of a Borrowed or Readonly pointer value starts when it is
initialized or assigned a value, and ends when it is assigned a
new value or the last read of the value.

This is also known as *Non-Lexical Lifetimes*.


### Pointer State Transitions

A pointer changes its state when one of these operations is done to it:

1. storage is allocated for it (such as a local variable on the stack),
which places the pointer in the Undefined state

2. initialization (treated as assignment)

3. assignment - the source and target pointers change state based on what
states they are in and their types and storage classes

4. passed to an `out` function parameter (changes state after the function returns),
treated the same as initialization

5. passed by `ref` to a function parameter, treated as an assignment to a Borrow or a Readonly
depending on the storage class and type of the parameter

6. returned from a function

7. it is passed by value to a function parameter, which is
treated as an assignment to that parameter.

8. it is implicitly passed by ref as a closure variable to a nested function

9. the address of the pointer is taken, which is treated as assignment to whoever
receives the address

10. the address of any part of the memory object graph is taken, which is
treated as assignment to whoever receives that address

11. a pointer value is read from any part of the memory object graph,
which is treated as assignment to whoever receives that pointer

12. merging of control flow reconciles the state of each variable based on the
states they have from each edge

## Limitations

Being a prototype, there are a lot of aspects not dealt with yet, and
won't be until the prototype shows that it is a good design.

### Bugs

Expect lots of bugs. Please report them to bugzilla and tag with the "ob"
keyword. It's not necessary to report the other limitations that are enumerated here.

### Only Raw Pointers are Tracked

Wrapping a pointer in a struct will cause it to be overlooked.
Compound pointers (slices and delegates) are not tracked.

### Class References and Associative Array References are not Tracked

They are presumed to be managed by the garbage collector.

### Borrowing and Reading from Non-Owner Pointers

Owners are tracked for leaks, not other pointers.

```
@live void uhoh()
{
    scope p = malloc();
    scope const pc = malloc();
} // dangling pointers p and pc are not detected on exit

```
It doesn't seem to make much sense to have such pointers as
`scope`, perhaps this can be resolved by making such an error.

### Pointers Read/Written by Nested Functions

They're not tracked.

```
@live void ohno()
{
    auto p = malloc();

    void sneaky() { free(p); }

    sneaky();
    free(p);  // double free not detected
}
```

### Memory Model Transitivity Not Checked

```
struct S { int* s; }

@live void whoops()
{
    auto p = cast(S*)malloc(S.sizeof);
    scope b = p;    // borrows `p`
    scope c = p.s;  // not recognized as borrowing `p`
}
```

### Exceptions

The analysis assumes no exceptions are thrown.

```
@live void leaky()
{
    auto p = malloc();
    pitcher();  // throws exception, p leaks
    free(p);
}
```

One solution is to use `scope(exit)`:

```
@live void waterTight()
{
    auto p = malloc();
    scope(exit) free(p);
    pitcher();
}
```

or use RAII objects or call only `nothrow` functions.

### Lazy Parameters

These are not considered.

### Quadratic Behavior

The analysis exhibits quadratic behavior, so keeping the `@live` functions
smallish will help.

### Mixing Memory Pools

Conflation of different memory pools:

```
void* xmalloc(size_t);
void xfree(void*);

void* ymalloc(size_t);
void yfree(void*);

auto p = xmalloc(20);
yfree(p);  // should call xfree() instead
```
is not detected.

This can be mitigated by using type-specific pools:

```
U* umalloc();
void ufree(U*);

V* vmalloc();
void vfree(V*);

auto p = umalloc();
vfree(p);  // type mismatch
```

and perhaps disabling implicit conversions to `void*` in `@live` functions.

