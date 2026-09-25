## Formal Language Specification

### 1. Declaration syntax

An enum union is a nominal tagged sum type. It may contain:

- unit variants: `case Name()`
- positional variants: `case Name(T1, T2, ...)`
- record variants: `case Name { ... }`
- named type variants: `case Name = T`
- bare-type variants: `case T`

```ebnf
EnumUnionDeclaration:
    "enum" "union" [Identifier [TemplateParameterList]] "{" EnumUnionBody "}"

EnumUnionBody:
    EnumUnionCaseDeclaration* [MemberDeclarationList]

EnumUnionCaseDeclaration:
    UDA* "case" EnumUnionCase ("," EnumUnionCase)* [";"]

EnumUnionCase:
        Identifier "(" [ParameterList] ")"
  | Identifier "{" StructBody "}"
  | Identifier "=" Type
  | Type
```

The declaration is parsed in the current frontend as a `case`-prefixed variant list terminated with semicolons. Multiple cases may appear in a single declaration separated by commas (e.g. `case Some(T), None();`). The trailing semicolon or comma on the final case immediately preceding the closing `}` is optional and can be omitted. `case` is required for every variant form, including bare types and unit cases. Empty parentheses distinguish a named unit variant from a bare identifier type. User-defined attributes may precede a case declaration. An enum union may contain at most 256 variants because its discriminator is a `ubyte`.

### 2. Variant forms

#### Unit variants

A unit variant carries no payload and is represented by a distinct tag value.

```d
enum union Traffic
{
    case Red();
    case Yellow();
    case Green();
}
```

This is the canonical zero-byte state form for an enum union. The empty
parentheses are required; `case Red;` denotes a bare type named `Red`.

#### Positional variants

A positional variant holds a payload created from the specified parameter list.

```d
enum union Shape
{
    case Circle(double);
    case Rectangle(double, double);
    case Point();
}
```

The compiler synthesizes a static factory function for each named variant, such as `Shape.Circle(3.5)`.

#### Record variants

A record variant stores a synthesized nested payload struct.

```d
enum union Response
{
    case Success { int code; string payload; };
    case Timeout();
}
```

The declaration introduces a real nested struct and uses that type as the
variant payload. It is equivalent to declaring the struct and then using it as
a bare-type variant:

```d
enum union Response
{
    struct Success { int code; string payload; }
    case Success;
    case Timeout();
}
```

Here `case Success;` is a bare-type variant whose payload type is the nested
`Success` struct. It is not unit-variant shorthand.

In a `switch` arm, record fields can be bound by name.

#### Named type variants

A named type variant introduces a real nested alias and uses its target type as
the variant payload:

```d
enum union Value
{
    case Bytes = ubyte[];
}
```

This is equivalent to `alias Bytes = ubyte[]; case Bytes;`. The alias remains
available as `Value.Bytes` for type use and compile-time reflection.

#### Bare-type variants

A bare-type variant is a single type, not a variant name.

```d
enum union Value
{
    case int;
    case double;
    case string;
}
```

Bare-type variants are supported for a broad set of D types, including pointers, slices, delegates, function pointers, static arrays, `typeof(null)`, and other builtins already accepted by the ordinary implicit conversion rules.

### 3. Null-like no-value variants

The implementation accepts the null-like no-value case in two equivalent forms:

```d
alias None = typeof(null);

enum union Option(T)
{
    case Some(T);
    case None;
}

enum union NullOption(T)
{
    case Some(T);
    case typeof(null);
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

### 5. Compile-time reflection

Enum unions support these reflection operations:

- `is(T == enum union)` identifies an enum-union type.
- `__traits(allVariants, T)` returns the variants in declaration order.
- `__traits(hasVariant, T, key)` tests whether `T` has the named variant given
    by a string key or the unnamed bare variant given by a type key.
- `__traits(getVariant, T, key)` returns that variant symbol or bare type and
    reports an error if it does not exist.
- `__traits(getTag, T, V)` returns the discriminator value for `V`.
- `__traits(variantParams, V)` returns the declared parameter or field types
  for tuple and inline struct variants, and an empty tuple for other variant kinds.
- `__traits(variantParamNames, V)` returns the corresponding parameter or field
  names as strings, and an empty tuple for other variant kinds.
- `__traits(variantKind, V)` returns `"unit"`, `"tuple"`, `"struct"`, `"alias"`, or `"bare"`.
- `__traits(variantDeclarationOf, V [, name])` may appear after `case` in an
    enum-union body to copy a variant declaration. The optional string renames
    the copied variant; an empty string preserves its original form.

The argument `V` is a variant element produced by `__traits(allVariants, T)`.
`"struct"` specifically denotes an inline record variant such as
`case User { int id; }`. A bare variant such as `case ExternalStruct` returns
`"bare"`, even when its externally declared payload type is itself a struct.

### 6. Internal representation

Each enum union lowers to a tagged aggregate with:

- synthesized discriminant storage
- an anonymous union payload that overlays the storage of all variants
- one synthesized payload field per variant for the active payload storage

The discriminator is an index into the declaration order of the enum union variants. It is exposed as the read-only `.__tag` property; assigning to it is invalid.

For example:

```d
enum union Shape
{
    case Circle(double);
    case Rectangle(double, double);
    case Point();
}
```

Its tag values follow declaration order. Programs should compare `value.__tag`
with `__traits(getTag, Shape, Shape.Point)`, rather than hard-code a numeric tag.

### 7. Switch expressions

Switch on an enum union is expression-based and uses fat-arrow arms:

```d
int score = switch (s)
{
    case Circle(r) => cast(int) (r * 2),
    case Rectangle(w, h) => cast(int) (w * h),
    case Point() => 1,
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

Payload positions are binding patterns, not value expressions. They may contain
identifiers, discards, rest patterns, or recursively nested tuple bindings:

```d
return switch (value)
{
    case Wrapped((left, right)) => left + right,
    case Record { point: (x, y), ... } => x + y,
    case Pair(first, ...) => first,
};
```

Tuple patterns use the same recursive shape as unpack declarations, but are
part of switch-expression syntax and do not depend on the tuple-declaration
preview switch. Literals and arbitrary expressions are not payload patterns.
Bind the payload and place value predicates in an `if` guard instead:

```d
case Number(number) if (number == 42) => "answer",
```

#### Result type

All arm actions other than those of type `noreturn` must currently have the same
type. That type is the type of the switch expression. The implementation does
not currently compute a least upper bound or insert common-type conversions for
different arm types.

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

#### Static foreach and static if in switch expressions

Switch expressions support `static foreach` and `static if` constructs directly within their body, enabling programmatic generation of `case` arms at compile time without string mixins:

```d
enum union DynamicNumber
{
    case long;
    case float;
    case double;
    case error(string);
}

DynamicNumber sum(DynamicNumber a, DynamicNumber b) @safe
{
    enum isBare(alias V) = __traits(variantKind, V) == "bare";
    alias NumericVariants = Filter!(isBare, __traits(allVariants, DynamicNumber));

    return switch (a)
    {
        case error(msg) => a,
        static foreach (V1; NumericVariants)
            case V1 v1 => switch (b)
            {
                case error(msg) => b,
                static foreach (V2; NumericVariants)
                    case V2 v2 => DynamicNumber(v1 + v2)
            }
    };
}
```

Key rules:
- **Scoping:** Each unrolled iteration creates an iteration scope. Loop indices, elements, and type aliases are available within the unrolled arm and any enclosed expressions or nested switch expressions.
- **Syntax:** Both single-arm bodies (`static foreach (...) case ... => ...`) and braced block bodies (`static foreach (...) { case ... => ..., }`) are permitted.
- **Delimiters:** Elements unrolled by `static foreach` do not require explicit comma separators between iterations. When a `static foreach` or `static if` block directly precedes the closing `}`, trailing commas or semicolons are optional.
- **Exhaustiveness and Diagnostics:** Compile-time conditionals and iterations are expanded before exhaustiveness, redundancy, and decision-tree checking. Duplicated arms generated across iterations are flagged as redundant, and unhandled variants are reported as non-exhaustive.

### 8. Exhaustiveness and redundancy checks

The implementation enforces compile-time checking for:

- unhandled variants in non-defaulted switches
- redundant match arms
- switch arms that do not match any enum union variant
- arms with `if` guards but without a `default` arm

If the switch is exhaustive without a `default`, no default arm is required. If not exhaustive, a `default` arm is required.

### 9. Duplicate and ambiguity rules

The implementation rejects:

- duplicate named cases: two `case Name(...)` entries with the same identifier
- duplicate bare types: two `case T` entries with the same type
- ambiguous implicit construction when the source expression could match more than one bare variant
- record/positional patterns that do not match the active variant

### 10. Lifecycle rules

Enum unions obey the lifecycle rules of their payloads.

- If a variant payload has a destructor, the enum union gets a synthesized destructor that dispatches on the active tag.
- If a payload is move-only or otherwise unsafe to copy, the enum union rejects the declaration.
- Copying a union copies the active payload according to the payload’s copy semantics.

This is enforced during semantic analysis to avoid raw bitcopying of payloads that require destruction or special copy semantics.

### 11. Member functions and trailing declarations

Alongside or following the variant list, an enum union may declare member functions and other declarations:

```d
enum union ShapeWithMethods
{
    case Circle(double);
    case Rectangle(double, double);
    case Point();

    double area()
    {
        return switch (this)
        {
            case Circle(r) => 3.14159 * r * r,
            case Rectangle(w, h) => w * h,
            case Point() => 0.0,
        };
    }
}
```

Member declarations are part of the enum union aggregate. Member functions can use `switch (this)` to dispatch on the active variant.

### 12. Summary

The implemented model is a D-native tagged sum type with these practical rules:

- every variant is declared with `case`
- bare types, named unit cases, and record/positional payloads are all valid
- `switch` over an enum union matches the active tag and binds payload fields as needed
- `default` is a catch-all branch and is required for guarded arms unless the switch is exhaustive
- duplicate named cases and duplicate bare types are rejected
- `null` can initialize a null-like no-value bare-type variant, including `case None` when `None` aliases `typeof(null)`, and `case typeof(null)`
- payload lifecycle safety is enforced through the same semantic checks as aggregate destructors and copying
