# Enum unions

An enum union is a tagged union whose value is one of a fixed set of variants. Each variant can carry data, or it can be a unit case with no payload. The compiler tracks the active variant and allows matching on it with a `switch` expression.

## 1. Basic declaration

```d
enum union Shape
{
    case Circle(double),
    case Rectangle(double, double),
    case Point,
}
```

This declares a type that is either:

- a circle with one `double`
- a rectangle with two `double`s
- a point with no payload

Each named case is also a factory function:

```d
Shape s1 = Shape.Circle(3.5);
Shape s2 = Shape.Point;
```

The active variant is stored internally as a tag. The generated field is `.__tag`.

---

## 2. Variant forms

An enum union case can be one of four forms.

### Unit cases

```d
enum union State
{
    case Idle,
    case Running,
    case Stopped,
}
```

These cases carry no payload.

### Bare types

```d
enum union Value
{
    case int,
    case string,
    case bool,
}
```

Each bare case is distinguished by its type. Construction uses the value itself:

```d
Value v1 = 42;
Value v2 = "hello";
Value v3 = true;
```

This is distinct from a named case with a payload or a separate struct type. For example, the enum union case name and the payload type name are not required to be the same thing:

```d
struct Success
{
    int code;
    string msg;
}

enum union Response
{
    case Success,
    case Failure(string),
    case Timeout,
}
```

Here `Success` is the case name, while the struct `Success` is a separate type. The bare-type form is only one of the valid enum-union patterns.

The compiler checks for duplicate bare types and for ambiguous construction when more than one bare case can accept the same value.

### Positional payload variants

```d
enum union Shape
{
    case Circle(double),
    case Rectangle(double, double),
    case Point,
}
```

The constructor parameters match the payload fields.

### Record-style payload variants

```d
enum union Response
{
    case Success { int code; string message; },
    case Failure { string reason; },
    case Timeout,
}
```

The payload is a record-like structure. The compiler synthesizes the corresponding constructor for the case.

---

## 3. Duplicate and ambiguity checks

The compiler rejects invalid declarations.

```d
enum union LatLong
{
    case double,
    case double,
}
```

This is rejected because the bare type appears twice.

```d
enum union BadNames
{
    case A { int x; },
    case A { string s; },
}
```

This is rejected because the case name is duplicated, even when the payloads differ.

```d
enum union Funs
{
    case int function(int),
    case int delegate(int),
}

Funs f = () {};
```

This is rejected because the value could match more than one case.

---

## 4. Methods and trailing members

Enum unions can include member declarations after the case list.

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

int score(ShapeWithMethods s)
{
    return s.area();
}
```

These member functions are members of the union itself. Inside the function, "this" refers to the union itself, and a switch expression is required to determine which invariant is active.
---

## 5. Destructors, invariants, and lifecycle rules

An enum union participates in the same D lifecycle rules as other aggregate types. User-defined destructors and invariant logic are allowed.

The compiler also rejects unsafe payloads.

```d
struct MoveOnly
{
    int x;
    this(return MoveOnly other) { x = other.x; }
}

enum union Bad
{
    case M(MoveOnly),
    case Other(bool),
}
```

This is rejected because the payload has a move constructor but no copy constructor. The enum union stores the payload in a union-like representation, and copying it would not be safe.

The same check applies to disabled copy constructors and disabled postblits.

---

## 6. Matching with `switch` expressions

The primary matching form for enum unions is a `switch` expression.

```d
int score(Shape s)
{
    return switch (s)
    {
        case Circle(r) => cast(int)(r * 2),
        case Rectangle(w, h) => cast(int)(w * h),
        case Point => 1,
    };
}
```

The switch arm pattern binds the currently active payload.

```d
case Circle(r) => ...
case Rectangle(w, h) => ...
case Point => ...
```

A `default` arm is the fallback branch for a `switch` expression. It runs when no earlier pattern matches. It does not bind a value, because it is not a case pattern; it is simply the catch-all branch for the remaining cases.

This is the normal way to inspect an enum union.

---

## 7. Guards

A switch arm may include a guard.

```d
enum union Level
{
    case double,
    case string,
}

string classify(Level v)
{
    return switch (v)
    {
        case double d if (d > 100.0) => "high",
        case double d => "normal",
        default => "other",
    };
}
```

Note that a `default` arm cannot itself have an `if` guard.

---

## 8. Exhaustiveness

A `switch` expression over an enum union must cover every variant unless it contains a `default` arm:

```d
string classifyTraffic(Traffic t)
{
    return switch (t)
    {
        case Red => "stop",
        case Yellow => "caution",
        case Green => "go",
    };
}
```

If a variant is omitted, the compiler reports an error.

```d
string classifyTraffic(Traffic t)
{
    return switch (t)
    {
        case Red => "stop",
        case Yellow => "caution",
    };
}
```

This produces an error stating which variant is missing.

---

## 9. Redundant and unmatched arms

The compiler rejects unreachable cases and invalid pattern names.

```d
string bad(Traffic t)
{
    return switch (t)
    {
        case Red => "stop",
        case Red => "again",
        case Yellow => "caution",
        case Green => "go",
    };
}
```

The second `Red` arm is rejected as redundant.

```d
string bad(Shape s)
{
    return switch (s)
    {
        case Circle(r) => "circle",
        case Square(r) => "square",
        case Point => "point",
    };
}
```

This is rejected because `Square` is not a variant of `Shape`.

## 10. Complete example

```d
enum union Option(T)
{
    case Some(T),
    case None,
}

string describe(Option!string value)
{
    return switch (value)
    {
        case Some(msg) => "value: " ~ msg,
        case None => "empty",
    };
}

void main()
{
    Option!string a = Option!string.Some("hello");
    Option!string b = Option!string.None;

    assert(describe(a) == "value: hello");
    assert(describe(b) == "empty");
}
```

This shows the full pattern: declare the union, construct a value with a case factory, and inspect it with a `switch` expression.

An alternate form is to use the bare type `typeof(null)` for the "none" case:

```d
enum union Option(T)
{
    case Some(T),
    typeof(null),
}

string describe(Option!string value)
{
    return switch (value)
    {
        case Some(n) => "value: " ~ n.to!string(),
        case typeof(null) => "empty",
    };
}

void main()
{
    Option!int n = Option!int.Some(42);
    Option!int m = null;

    assert(describe(n) == "value: 42");
    assert(describe(m) == "empty");
}
```

This uses the same enum-union shape, but the no-value case is represented by the `typeof(null)` alias instead of a distinct unit case name.

---

## 11. Summary

An enum union is a fixed set of tagged variants. The declaration form is D-native, and the common access pattern is a `switch` expression that matches the active case and binds its payload.

The key rules are:

- each case name must be unique
- bare type duplicates are rejected
- ambiguous bare conversions are rejected
- the switch must be exhaustive unless a `default` is present
- unreachable and invalid arms are rejected
- unsafe lifecycle payloads are rejected
