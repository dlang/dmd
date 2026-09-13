## Formal Language Specification

### 1. Declaration syntax

An enum union is a nominal tagged sum type. It may contain:

- unit variants: `case Name`
- positional variants: `case Name(T1, T2, ...)`
- record variants: `case Name { ... }`
- named type variants: `case Name = T`
- bare-type variants: `case T`

```ebnf
EnumUnionDeclaration:
    "enum" "union" [Identifier] "{" EnumUnionMemberList "}"

EnumUnionMemberList:
    EnumUnionMember ("," EnumUnionMember)* ","? [";" MemberDeclarationList]

EnumUnionMember:
    "case" Identifier
  | "case" Identifier "(" ParameterList ")"
  | "case" Identifier "{" StructBody "}"
    | "case" Identifier "=" Type
  | "case" Type
```

The declaration is parsed in the current frontend as a `case`-prefixed variant list. `case` is required for every variant form, including bare types and unit cases.

### 2. Variant forms

#### Unit variants

A unit variant carries no payload and is represented by a distinct tag value.

```d
enum union Traffic
{
    case Red,
    case Yellow,
    case Green,
}
```

This is the canonical zero-byte state form for an enum union.

#### Positional variants

A positional variant holds a payload created from the specified parameter list.

```d
enum union Shape
{
    case Circle(double),
    case Rectangle(double, double),
    case Point,
}
```

The compiler synthesizes a static factory function for each named variant, such as `Shape.Circle(3.5)`.

#### Record variants

A record variant stores a synthesized nested payload struct.

```d
enum union Response
{
    case Success { int code; string payload; },
    case Timeout,
}
```

The declaration introduces a real nested struct and uses that type as the
variant payload. It is equivalent to declaring the struct and then using it as
a bare-type variant:

```d
enum union Response
{
    struct Success { int code; string payload; }
    case Success,
    case Timeout,
}
```

In a `switch` arm, record fields can be bound by name.

#### Named type variants

A named type variant introduces a real nested alias and uses its target type as
the variant payload:

```d
enum union Value
{
    case Bytes = ubyte[],
}
```

This is equivalent to `alias Bytes = ubyte[]; case Bytes`. The alias remains
available as `Value.Bytes` for type use and compile-time reflection.

#### Bare-type variants

A bare-type variant is a single type, not a variant name.

```d
enum union Value
{
    case int,
    case double,
    case string,
}
```

Bare-type variants are supported for a broad set of D types, including pointers, slices, delegates, function pointers, static arrays, `typeof(null)`, and other builtins already accepted by the ordinary implicit conversion rules.

### 3. Null-like no-value variants

The implementation accepts the null-like no-value case in two equivalent forms:

```d
alias None = typeof(null);

enum union Option(T)
{
    case Some(T),
    case None,
}

enum union NullOption(T)
{
    case Some(T),
    case typeof(null),
}
```

A direct `null` literal may initialize a variant whose active state is the no-value variant, and the matching `switch` arm can be either `case None => ...` or `case typeof(null) => ...`.

This is a special case of the general rule that a no-payload enum union case can be constructed from the `typeof(null)` value, because `null` is the canonical empty/none value for that state.

### 4. Construction and implicit conversion

The compiler synthesizes factory functions for named variants and also accepts ordinary implicit conversions for bare-type variants and null-like unit cases.

Examples:

```d
Val v1 = 5;        // bare int case
Val v2 = true;     // bare bool case
Val v3 = 3.14;     // bare double case

Shape s = Shape.Circle(2.0);

Option!int o = null; // valid when the active variant is the null/no-value case
```

The conversion check matches the payload type of a bare variant against the source expression, with the usual D conversion rules applied. Ambiguous conversions are rejected.

A bare-type duplicate is rejected at compile time, as are duplicate named cases.

### 5. Internal representation

Each enum union lowers to a tagged aggregate with:

- a synthesized discriminant field, usually named `__tag`
- an anonymous union payload that overlays the storage of all variants
- one synthesized payload field per variant for the active payload storage

The discriminator is an index into the declaration order of the enum union variants.

For example:

```d
enum union Shape
{
    case Circle(double),
    case Rectangle(double, double),
    case Point,
}
```

has tag values corresponding to `0`, `1`, and `2` in declaration order.

### 6. Switch expressions

Switch on an enum union is expression-based and uses fat-arrow arms:

```d
int score = switch (s)
{
    case Circle(r) => cast(int) (r * 2),
    case Rectangle(w, h) => cast(int) (w * h),
    case Point => 1,
};
```

The switch arm pattern may bind payload components or match a bare type arm:

```d
string classify(Value v)
{
    return switch (v)
    {
        case int i => "int",
        case double d => "double",
        case string s => "string",
        default => "other",
    };
}
```

#### Default arm

A `default` arm is a catch-all branch used when no explicit case matches, or when the switch is intentionally not exhaustive.

```d
string classify(Shape s)
{
    return switch (s)
    {
        case Circle(r) => "circle",
        default => "other",
    };
}
```

A `default` arm is also required when an arm uses an `if` guard, because guarded arms do not unconditionally cover their variant.

#### Guarded arms

Guard expressions are allowed on switch arms:

```d
return switch (v)
{
    case double d if (d > 0.0) => "positive",
    case double d => "non-positive",
    default => "other",
};
```

The guard executes with the pattern-bound variables in scope. If a guarded arm is present, the switch must have a `default` arm unless the switch is otherwise exhaustive.

The implementation rejects guard-only redundant cases and invalid pattern matches in the same way it rejects non-exhaustive or unreachable switch arms.

### 7. Exhaustiveness and redundancy checks

The implementation enforces compile-time checking for:

- unhandled variants in non-defaulted switches
- redundant match arms
- switch arms that do not match any enum union variant
- arms with `if` guards but without a `default` arm

If the switch is exhaustive without a `default`, no default arm is required. If not exhaustive, a `default` arm is required.

### 8. Duplicate and ambiguity rules

The implementation rejects:

- duplicate named cases: two `case Name` entries with the same identifier
- duplicate bare types: two `case T` entries with the same type
- ambiguous implicit construction when the source expression could match more than one bare variant
- record/positional patterns that do not match the active variant

### 9. Lifecycle rules

Enum unions obey the lifecycle rules of their payloads.

- If a variant payload has a destructor, the enum union gets a synthesized destructor that dispatches on the active tag.
- If a payload is move-only or otherwise unsafe to copy, the enum union rejects the declaration.
- Copying a union copies the active payload according to the payload’s copy semantics.

This is enforced during semantic analysis to avoid raw bitcopying of payloads that require destruction or special copy semantics.

### 10. Member functions and trailing declarations

After the variant list, an enum union may continue with member declarations after a semicolon:

```d
enum union ShapeWithMethods
{
    case Circle(double),
    case Rectangle(double, double),
    case Point;

    double area()
    {
        return switch (this)
        {
            case Circle(r) => 3.14159 * r * r,
            case Rectangle(w, h) => w * h,
            case Point => 0.0,
        };
    }
}
```

This is supported by the implementation. Member declarations are part of the enum union after the semicolon following the last variant.

### 11. Summary

The implemented model is a D-native tagged sum type with these practical rules:

- every variant is declared with `case`
- bare types, named unit cases, and record/positional payloads are all valid
- `switch` over an enum union matches the active tag and binds payload fields as needed
- `default` is a catch-all branch and is required for guarded arms unless the switch is exhaustive
- duplicate named cases and duplicate bare types are rejected
- `null` can initialize a null-like no-value variant, including `case None` and `case typeof(null)`
- payload lifecycle safety is enforced through the same semantic checks as aggregate destructors and copying
